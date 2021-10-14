Additional Allowed Frame Ancestors for iframes
===

# Background
Due to potential  [Clickjacking](https://en.wikipedia.org/wiki/Clickjacking) attack, a lot of sites only allow them to be hosted in certain trusted ancestor iframes and top page.
However, there are application scenarios that require hosting these sites in the app's UI that is authored as the HTML page.
`<webview>` HTML element was provided for these hosting scenarios in previous solutions like Electron and JavaScript UWP apps.
For WebView2, we are providing a native API for these hosting scenarios.
  
# Conceptual pages (How To)

To host other sites in an trusted page
- Listen to FrameNavigationStarting event of CoreWebView2 or NavigationStarting event of CoreWebView2Frame object.
- Set AdditionalAllowedFrameAncestors property of the NavigationStartingEventArgs to a list of trusted origins that is hosting the site.

The list should normally only contain the origin of the current trusted top page.
If you are hosting other sites through nested iframes and the origins of some of the iframes are different from the origin of the top page, the list should also include those origins.

You should only add an origin to the list if it is fully trusted. You should limit the usage of the API to the targetted iframes whenever possible.

# Examples
## Win32 C++
```cpp
  const std::wstring myTrustedSite = L"example.com/";
  const std::wstring siteToHost = L"www.microsoft.com/";

  bool IsAppContentUri(const std::wstring& pageUrl)
  {
      // App specific logic to decide whether the page is fully trusted.
      wil::com_ptr<IUri> uri;
      CHECK_FAILURE(CreateUri(pageUrl.c_str(), Uri_CREATE_CANONICALIZE, 0, &uri));
      DWORD scheme = (DWORD)URL_SCHEME_INVALID;
      wil::unique_bstr host;
      CHECK_FAILURE(uri->GetScheme(&scheme));
      CHECK_FAILURE(uri->GetHost(&host));
      return (dwScheme == URL_SCHEME_HTTPS) && (host.get() == myTrustedSite);
  }

  bool IsTargetSite(const std::wstring& siteUrl)
  {
      // App specific logic to decide whether the site is the one it wants to host.
      wil::com_ptr<IUri> uri;
      CHECK_FAILURE(CreateUri(siteUrl.c_str(), Uri_CREATE_CANONICALIZE, 0, &uri));
      DWORD scheme = (DWORD)URL_SCHEME_INVALID;
      wil::unique_bstr host;
      CHECK_FAILURE(uri->GetScheme(&scheme));
      CHECK_FAILURE(uri->GetHost(&host));
      return (dwScheme == URL_SCHEME_HTTPS) && (host.get() == siteToHost);
  }

 void HandleHostedSites()
 {
    wil::com_ptr<ICoreWebView2_4> webview2_4 = m_webView.try_query<ICoreWebView2_4>();
    if (webview2_4)
    {
        CHECK_FAILURE(webview2_4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                    -> HRESULT {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    wil::unique_cotaskmem_string pageUrl;
                    CHECK_FAILURE(m_webView->get_Source(&pageUrl));
                    // IsAppContentUri verifies that pageUrl is app's content.
                    if (IsAppContentUri(pageUrl.get()))
                    {
                        // We are on trusted pages. Now check whether it is the iframe we plan
                        // to host other sites.
                        const std::wstring siteHostingFrameName = L"my_site_hosting_frame";
                        wil::unique_cotaskmem_string frameName;
                        CHECK_FAILURE(webviewFrame->get_Name(&frameName));
                        if (siteHostingFrameName == frameName.get())
                        {
                            wil::com_ptr<ICoreWebView2ExperimentalFrame> frameExperimental =
                                webviewFrame.try_query<ICoreWebView2ExperimentalFrame>();
                            if (frameExperimental)
                            {
                                frameExperimental->add_NavigationStarting(
                                    Microsoft::WRL::Callback<
                                        ICoreWebView2ExperimentalFrameNavigationStartingEventHandler>(
                                        [](
                                            ICoreWebView2Frame* sender,
                                            ICoreWebView2NavigationStartingEventArgs* args)
                                            -> HRESULT
                                        {
                                            wil::unique_cotaskmem_string navigationTargetUri;
                                            CHECK_FAILURE(args->get_Uri(&navigationTargetUri));
                                            wil::com_ptr<
                                                ICoreWebView2NavigationStartingEventArgs_2>
                                                nav_start_args;
                                            // If the feature is supported and it is the site we
                                            // want to host, then allow sites to be hosted by app's page.
                                            if (SUCCEEDED(args->QueryInterface(
                                                    IID_PPV_ARGS(&nav_start_args))) &&
                                                IsTargetSite(navigationTargetUri.get()))
                                            {
                                                nav_start_args
                                                    ->put_AdditionalAllowedFrameAncestors(
                                                        myTrustedSite);
                                            }
                                            return S_OK;
                                        })
                                        .Get(),
                                    nullptr);
                            }
                        }
                    }
                    return S_OK;
                })
                .Get(),
            nullptr));
    }
}
```
## WinRT and .NET    
```c#
  const string myTrustedSite = "example.com/";
  const string siteToHost = "www.microsoft.com"; 
  private bool IsAppContentUri(string pageUrl)
  {
      // App specific logic to decide whether the page is fully trusted.
      auto uri = new Uri(pageUrl);
      return uri.SchemeName == "https" && uri.Host == myTrustedSite;
  }

  private bool IsTargetSite(string uri)
  {
      // App specific logic to decide whether the site is the one it wants to host.
      auto uri = new Uri(pageUrl);
      return uri.SchemeName == "https" && uri.Host == siteToHost;
  }

  private void CoreWebView2_FrameCreated(CoreWebView2 sender, Microsoft.Web.WebView2.Core.CoreWebView2FrameCreatedEventArgs args)
  {
      // my_site_hosting_frame is the name attribute on the iframe element that we used in the web page to host the site.
      const string siteHostingFrameName = "my_site_hosting_frame";

      if (IsAppContentUri(sender.Source) && (args.Frame.Name == siteHostingFrameName))
      {
          args.Frame.NavigationStarting += (CoreWebView2Frame navStartingSender, CoreWebView2NavigationStartingEventArgs navStartingArgs) =>
          {
              if (IsTargetSite(navStartingArgs.Uri))
              {
                  args.AdditionalAllowedFrameAncestors = myTrustedSite;
              }
          };
      }
  }
```

# API Details
## Win32 C++
```
interface ICoreWebView2NavigationStartingEventArgs_2 : ICoreWebView2NavigationStartingEventArgs
{

  /// Get additional allowed frame ancestors set by the host app.
  [propget] HRESULT AdditionalAllowedFrameAncestors([out, retval] LPWSTR* value);

  /// The host may set this property to allow a frame to be hosted by certain additional ancestors besides what is allowed by
  /// http header [X-Frame-Options](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options)
  /// and [Content-Security-Policy frame-ancestors directive](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors).
  /// If set, a frame ancestor is allowed if it is allowed by the additional allowed frame ancestoers or original http header from the site.
  /// Whether an ancestor is allowed by the additional allowed frame ancestoers is done the same way as if the site provided
  /// it as the source list of the Content-Security-Policy frame-ancestors directive.
  /// This property gives the app the ability to use iframe to host sites that otherwise
  /// could not be hosted in an iframe in trusted app pages.
  /// This could potentially subject the hosted sites to [Clickjacking](https://en.wikipedia.org/wiki/Clickjacking)
  /// attack from the code running in the hosting web page. Therefore, you should only
  /// set this property with origins of fully trusted hosting page and any intermediate iframes.
  /// Whenever possible, you should use the list of specific origins of the top and intermediate
  /// frames instead of wildcard characters for this property.
  /// This API is to provide limited support for app scenarios that used to be supported by
  /// `<webview>` element in other solutions like JavaScript UWP apps and Electron.
  /// You should limit the usage of this property to trusted pages, and if possible, to specific iframe and
  /// specific navigation target url, by checking the `Source` of the WebView2, the `Name`
  /// of the ICoreWebView2Frame and `Uri` of the event args.
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

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NavigationStartingEventArgs_2")]
        {
            String AdditionalAllowedFrameAncestors { get; set; };
        }
    }
}
```
