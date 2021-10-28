Additional Allowed Frame Ancestors for iframes
===

# Background
Due to potential  [Clickjacking](https://en.wikipedia.org/wiki/Clickjacking) attack, a lot of sites only allow themselves to be embedded in certain trusted ancestor iframes and pages. The main way to specify this ancestor requirement for sites are http header [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options) and [Content-Security-Policy frame-ancestors directive](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors).

However, there are application scenarios that require embedding these sites in the app's UI that is authored as an HTML page.
`<webview>` HTML element was provided for these embedding scenarios in previous solutions like Electron and JavaScript UWP apps.

For WebView2, we are providing a native API for these embedding scenarios. Developers can use it to provide additional allowed frame ancestors as if the site sent these as part of the Content-Security-Policy frame-ancestors directive. The result is that an ancestor is allowed if it is allowed by the site's original policies or by this additional allowed frame ancestors.
  
# Conceptual pages (How To)

To embed other sites in an trusted page with modified allowed frame ancestors
- Listen to FrameNavigationStarting event of CoreWebView2.
- Set AdditionalAllowedFrameAncestors property of the NavigationStartingEventArgs to a list additional allowed frame ancestors using the same syntax for the source list of [Content-Security-Policy frame-ancestors directive](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors). Basically, it is a space delimited list. All source syntax of Content-Security-Policy frame-ancestors directive are supported.

The list should normally only contain the origin of the top page.
If you are embedding other sites through nested iframes and the origins of some of the intermediate iframes are different from the origin of the top page and those origins might not be allowed by the site's original policies, the list should also include those origins. As an example, if you owns the content on `https://example.com` and `https://www.example.com` and uses them on top page and some intermediate iframes, you should set the list as `https://example.com https://www.example.com`.

You should only add an origin to the list if it is fully trusted. When possible, you should try to limit the usage of the API to the targetted app scenarios. For example, you can use an iframe with a specific name attribute to embed sites (something like `<iframe name="my_site_embedding_frame">`) and then detect the embedding scenario is active when the trusted page is navigated to and the embedding iframe is created.

# Examples
## Win32 C++
```cpp
const std::wstring myTrustedSite = L"https://example.com/";
const std::wstring siteToEmbed = L"https://www.microsoft.com/";

bool AreSitesSame(PCWSTR url1, PCWSTR url2)
{
    wil::com_ptr<IUri> uri1;
    CHECK_FAILURE(CreateUri(url1, Uri_CREATE_CANONICALIZE, 0, &uri1));
    DWORD scheme1 = -1;
    DWORD port1 = 0;
    wil::unique_bstr host1;
    CHECK_FAILURE(uri1->GetScheme(&scheme1));
    CHECK_FAILURE(uri1->GetHost(&host1));
    CHECK_FAILURE(uri1->GetPort(&port1));
    wil::com_ptr<IUri> uri2;
    CHECK_FAILURE(CreateUri(url2, Uri_CREATE_CANONICALIZE, 0, &uri2));
    DWORD scheme2 = -1;
    DWORD port2 = 0;
    wil::unique_bstr host2;
    CHECK_FAILURE(uri2->GetScheme(&scheme2));
    CHECK_FAILURE(uri2->GetHost(&host2));
    CHECK_FAILURE(uri2->GetPort(&port2));
    return (scheme1 == scheme2) && (port1 == port2) && (wcscmp(host1.get(), host2.get()) == 0);
}

// App specific logic to decide whether the page is fully trusted.
bool IsAppContentUri(PCWSTR pageUrl)
{
    return AreSitesSame(pageUrl, myTrustedSite.c_str());
}

// App specific logic to decide whether a site is the one it wants to embed.
bool IsTargetSite(PCWSTR siteUrl)
{
    return AreSitesSame(siteUrl, siteToEmbed.c_str());
}

void MyApp::HandleEmbeddedSites()
{
    // Set up the event listeners. The code will take effect when the site embedding page is navigated to
    // and the embedding iframe navigates to the site that we want to embed.

    // This part is trying to scope the API usage to the specific scenario where we are embedding a site.
    // The result is recorded in m_embeddingSite.
    CHECK_FAILURE(m_webview->add_FrameCreated(
        Callback<ICoreWebView2FrameCreatedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                -> HRESULT 
            {
                wil::unique_cotaskmem_string pageUrl;
                CHECK_FAILURE(m_webView->get_Source(&pageUrl));
                // IsAppContentUri verifies that pageUrl is app's content.
                if (IsAppContentUri(pageUrl.get()))
                {
                    // We are on trusted pages. Now check whether it is the iframe we plan
                    // to embed other sites.
                    // We know that our trusted page is using <iframe name="my_site_embedding_frame">
                    // element to embed other sites.
                    const std::wstring siteEmbeddingFrameName = L"my_site_embedding_frame";
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    wil::unique_cotaskmem_string frameName;
                    CHECK_FAILURE(webviewFrame->get_Name(&frameName));
                    if (siteEmbeddingFrameName == frameName.get())
                    {
                      // We are embedding sites.
                      m_embeddingSite = true;
                      CHECK_FAILURE(webviewFrame->add_Destroyed(
                          Microsoft::WRL::Callback<
                              ICoreWebView2FrameDestroyedEventHandler>(
                              [this](ICoreWebView2Frame* sender,
                                     IUnknown* args) -> HRESULT {
                                m_embeddingSite = false;
                                return S_OK;
                              })
                              .Get(),
                          nullptr));
                    }
                }
                return S_OK;
            })
            .Get(),
        nullptr));

    // Using FrameNavigationStarting event instead of NavigationStarting event of CoreWebViewFrame
    // to cover all possible nested iframes inside the embedded site as CoreWebViewFrame
    // object currently only support first level iframes in the top page.
    CHECK_FAILURE(m_webview->add_FrameNavigationStarting(
        Microsoft::WRL::Callback<ICoreWebView2NavigationStartingEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT
            {
              if (m_embeddingSite)
              {
                  wil::unique_cotaskmem_string navigationTargetUri;
                  CHECK_FAILURE(args->get_Uri(&navigationTargetUri));
                  if (IsTargetSite(navigationTargetUri.get()))
                  {
                    wil::com_ptr<
                      ICoreWebView2NavigationStartingEventArgs2>
                      navigationStartArgs;
                    if (SUCCEEDED(args->QueryInterface(
                          IID_PPV_ARGS(&navigationStartArgs))))
                      {
                        navigationStartArgs
                          ->put_AdditionalAllowedFrameAncestors(
                              myTrustedSite.c_str());
                      }
                  }
              }
              return S_OK;
            })
            .Get(),
        nullptr));
}
```
## WinRT and .NET    
```c#
  const string myTrustedSite = "https://example.com/";
  const string siteToEmbed = "https://www.microsoft.com";
  private bool AreSitesSame(string url1, string url2)
  {
      auto uri1 = new Uri(url1);
      auto uri2 = new Uri(url2);
      return (uri1.SchemeName == uri2.SchemeName) && (uri1.Host == uri2.Host) && (uri1.Port == uri2.Port);
  }
  private bool IsAppContentUri(string pageUrl)
  {
      // App specific logic to decide whether the page is fully trusted.
      return AreSitesSame(pageUrl, myTrustedSite);
  }

  private bool IsTargetSite(string siteUrl)
  {
      // App specific logic to decide whether the site is the one it wants to embed.
      return AreSitesSame(siteUrl, siteToEmbed);
  }

  // This part is trying to scope the API usage to the specific scenario where we are embedding a site.
  // The result is recorded in m_embeddingSite.
  private void CoreWebView2_FrameCreated(CoreWebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2FrameCreatedEventArgs args)
  {
      // We know that our trusted page is using <iframe name="my_site_embedding_frame"> element to embed other sites.
      // We are embedding sites when we are on trusted pages and the embedding iframe is created.
      const string siteEmbeddingFrameName = "my_site_embedding_frame";
      if (IsAppContentUri(sender.Source) && (args.Frame.Name == siteEmbeddingFrameName))
      {
          m_embeddingSite = true;
          args.Frame.Destroyed += CoreWebView2_SiteEmbeddingFrameDestroyed;
      }
  }
  private void CoreWebView2_SiteEmbeddingFrameDestroyed(CoreWebView2Frame sender, Object args)
  {
      m_embeddingSite = false;
  }

  // Using FrameNavigationStarting event instead of NavigationStarting event of CoreWebViewFrame
  // to cover all possible nested iframes inside the embedded site as CoreWebViewFrame
  // object currently only support first level iframes in the top page.
  private void CoreWebView2_FrameNavigationStarting(CoreWebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationStartingEventArgs args)
  {
      if (m_embeddingSite && IsTargetSite(args.Uri))
      {
          args.AdditionalAllowedFrameAncestors = myTrustedSite;
      }
  }
  private void HandleEmbeddedSites()
  {
      // Set up the event listeners. The code will take effect when the site embedding page is navigated to
      // and the embedding iframe navigates to the site that we want to embed.
      webView.FrameCreated += CoreWebView2_FrameCreated;
      webView.FrameNavigationStarting += CoreWebView2_FrameNavigationStarting;
  }
```

# API Details
## Win32 C++
```
interface ICoreWebView2NavigationStartingEventArgs_2 : ICoreWebView2NavigationStartingEventArgs
{

  /// Get additional allowed frame ancestors set by the app.
  [propget] HRESULT AdditionalAllowedFrameAncestors([out, retval] LPWSTR* value);

  /// The app may set this property to allow a frame to be embedded by additional ancestors besides what is allowed by
  /// http header [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
  /// and [Content-Security-Policy frame-ancestors directive](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors).
  /// If set, a frame ancestor is allowed if it is allowed by the additional allowed frame
  /// ancestoers or original http header from the site.
  /// Whether an ancestor is allowed by the additional allowed frame ancestoers is done the same way as if the site provided
  /// it as the source list of the Content-Security-Policy frame-ancestors directive.
  /// For example, if `https://example.com` and `https://www.example.com` are the origins of the top
  /// page and intemediate iframes that embed a nested site-embedding iframe, and you fully trust
  /// those origins, you should set this property to `https://example.com https://www.example.com`.
  /// This property gives the app the ability to use iframe to embed sites that otherwise
  /// could not be embedded in an iframe in trusted app pages.
  /// This could potentially subject the embedded sites to [Clickjacking](https://en.wikipedia.org/wiki/Clickjacking)
  /// attack from the code running in the embedding web page. Therefore, you should only
  /// set this property with origins of fully trusted embedding page and any intermediate iframes.
  /// Whenever possible, you should use the list of specific origins of the top and intermediate
  /// frames instead of wildcard characters for this property.
  /// This API is to provide limited support for app scenarios that used to be supported by
  /// `<webview>` element in other solutions like JavaScript UWP apps and Electron.
  /// You should limit the usage of this property to trusted pages, and specific navigation
  /// target url, by checking the `Source` of the WebView2, and `Uri` of the event args.
  ///
  /// This property is ignored for top level document navigation.
  ///
  [propput] HRESULT AdditionalAllowedFrameAncestors([in] LPCWSTR value);

}
```
## WinRT and .NET
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2NavigationStartingEventArgs
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NavigationStartingEventArgs2")]
        {
            String AdditionalAllowedFrameAncestors { get; set; };
        }
    }
}
```
