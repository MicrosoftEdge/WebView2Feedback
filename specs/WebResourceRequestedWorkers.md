WebResourceRequested events for workers
===

# Background
Currently [WebResourceRequested events](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/iwebview2webview5?view=webview2-0.8.355#add_webresourcerequested) are raised only for main page HTTP requests. We are extending [AddWebResourceRequestedFilter](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/iwebview2webview5?view=webview2-0.8.355#addwebresourcerequestedfilter) API to allow you additionally to subscribe to events raised from Service or Shared workers and fixing oop iframes events as part of the main page.

# Examples
Subscribe to WebResourceRequested event for service workers and override the image in request with the local one

.Net
```c#
webView.CoreWebView2.AddWebResourceRequestedFilter("*.jpg", CoreWebView2WebResourceContext.All, CoreWebView2WebResourceRequestSource.ServiceWorker);
webView.CoreWebView2.WebResourceRequested += (sender, args) =>
{
    if (args.RequestSource == CoreWebView2WebResourceRequestSource.ServiceWorker &&
        args.ResourceContext == CoreWebView2WebResourceContext.Image)
    {
        Stream fileStream = new FileStream("new_image.jpg", FileMode.Open, FileAccess.Read, FileShare.Read);
        CoreWebView2WebResourceResponse overriddenResponse =
            webView.CoreWebView2.Environment.CreateWebResourceResponse(fileStream, 200, "OK", "Content-Type: image/jpeg");
        args.Response = overriddenResponse;
    }
};
webView.CoreWebView2.Navigate("https://www.url.com/");
```

C++
```cpp
m_webviewEventSource->AddWebResourceRequestedFilterWithRequestSource(
            L"*.jpg", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
            COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER);
m_webviewEventSource->add_WebResourceRequested(
        Callback<ICoreWebView2WebResourceRequestedEventHandler>(
            [this, file_path](ICoreWebView2* webview, ICoreWebView2WebResourceRequestedEventArgs* args)
                -> HRESULT {
                wil::com_ptr<ICoreWebView2WebResourceRequestedEventArgs2>
                    webResourceRequestArgs;
                if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&webResourceRequestArgs))))
                {
                    COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE requestSource =
                        COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_ALL;
                    webResourceRequestArgs->get_RequestSource(&requestSource);
                    COREWEBVIEW2_WEB_RESOURCE_CONTEXT context;
                    args->get_ResourceContext(&context);
                    if (requestSource ==
                            COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER &&
                        context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE)
                    {
                        Microsoft::WRL::ComPtr<IStream> response_stream;
                        Microsoft::WRL::ComPtr<ICoreWebView2_2> webview2;
                        Microsoft::WRL::ComPtr<ICoreWebView2Environment> environment;
                        CHECK_FAILURE(m_webviewEventSource->QueryInterface(IID_PPV_ARGS(&webview2)));
                        CHECK_FAILURE(webview2->get_Environment(&environment));
                        CHECK_FAILURE(SHCreateStreamOnFileEx(
                            file_path, STGM_READ, FILE_ATTRIBUTE_NORMAL,
                            FALSE, nullptr, &response_stream));
                        Microsoft::WRL::ComPtr<ICoreWebView2WebResourceResponse> response;
                        CHECK_FAILURE(environment->CreateWebResourceResponse(
                            response_stream.Get(), 200, L"OK", L"Content-Type: image/jpeg",
                            &response));
                        args->put_Response(response.Get());
                    }
                }
                return S_OK;
            })
            .Get(),
        &m_webResourceRequestedToken);
```

# API Details
## IDL
```c#
/// Specifies the source of `WebResourceRequested` event.
[v1_enum]
typedef enum COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE {
  /// Indicates that web resource is requested from main page including dedicated workers and iframes.
  COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_DOCUMENT = 1,

  /// Indicates that web resource is requested from shared worker.
  COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SHARED_WORKER = 2,

  /// Indicates that web resource is requested from service worker.
  COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER = 4,

  /// Indicates that web resource is requested from any supported source.
  COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_ALL = 0XFFFFFFFF
} COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE;
cpp_quote("DEFINE_ENUM_FLAG_OPERATORS(COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE);")

[uuid(1cc6a402-3724-4e4a-9099-8cf60f2f93a1), object, pointer_default(unique)]
interface ICoreWebView2_16: ICoreWebView2_15 {
  /// A web resource request with a resource context that matches this
  /// filter's resource context, an URI that matches this filter's URI
  /// wildcard string for corresponding request source will be raised via
  /// the `WebResourceRequested` event. To receive all raised events filters have
  /// to be added before main page navigation.
  ///
  /// The `uri` parameter value is a wildcard string matched against the URI
  /// of the web resource request. This is a glob style
  /// wildcard string in which a `*` matches zero or more characters and a `?`
  /// matches exactly one character.
  /// These wildcard characters can be escaped using a backslash just before
  /// the wildcard character in order to represent the literal `*` or `?`.
  ///
  /// The matching occurs over the URI as a whole string and not limiting
  /// wildcard matches to particular parts of the URI.
  /// The wildcard filter is compared to the URI after the URI has been
  /// normalized, any URI fragment has been removed, and non-ASCII hostnames
  /// have been converted to punycode.
  ///
  /// Specifying a `nullptr` for the uri is equivalent to an empty string which
  /// matches no URIs.
  ///
  /// For more information about resource context filters, navigate to
  /// [COREWEBVIEW2_WEB_RESOURCE_CONTEXT].
  ///
  /// The `requestSource` is a mask of one or more `COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE`. OR
  /// operation(s) can be applied to multiple `COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE` to
  /// create a mask representing those data types. API returns `E_INVALIDARG` if `requestSource` equals to zero.
  /// For more information about request source, navigate to
  /// [COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE].
  ///
  /// Because service worker runs separately from any one HTML document its WebResourceRequested
  /// will be raised for all CoreWebView2s that have appropriate filters added in the
  /// corresponding CoreWebView2Environment.
  /// You should only add a WebResourceRequested filter for
  /// COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER on
  /// one CoreWebView2 to avoid handling the same WebResourceRequested
  /// event multiple times.
  ///
  /// | URI Filter String | Request URI | Match | Notes |
  /// | ---- | ---- | ---- | ---- |
  /// | `*` | `https://contoso.com/a/b/c` | Yes | A single * will match all URIs |
  /// | `*://contoso.com/*` | `https://contoso.com/a/b/c` | Yes | Matches everything in contoso.com across all schemes |
  /// | `*://contoso.com/*` | `https://example.com/?https://contoso.com/` | Yes | But also matches a URI with just the same text anywhere in the URI |
  /// | `example` | `https://contoso.com/example` | No | The filter does not perform partial matches |
  /// | `*example` | `https://contoso.com/example` | Yes | The filter matches across URI parts  |
  /// | `*example` | `https://contoso.com/path/?example` | Yes | The filter matches across URI parts |
  /// | `*example` | `https://contoso.com/path/?query#example` | No | The filter is matched against the URI with no fragment |
  /// | `*example` | `https://example` | No | The URI is normalized before filter matching so the actual URI used for comparison is `https://example.com/` |
  /// | `*example/` | `https://example` | Yes | Just like above, but this time the filter ends with a / just like the normalized URI |
  /// | `https://xn--qei.example/` | `https://&#x2764;.example/` | Yes | Non-ASCII hostnames are normalized to punycode before wildcard comparison |
  /// | `https://&#x2764;.example/` | `https://xn--qei.example/` | No | Non-ASCII hostnames are normalized to punycode before wildcard comparison |
  HRESULT AddWebResourceRequestedFilterWithRequestSource(
    [in] LPCWSTR const uri,
    [in] COREWEBVIEW2_WEB_RESOURCE_CONTEXT const resourceContext,
    [in] COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE const requestSource);

  /// Removes a matching WebResource filter that was previously added for the
  /// `WebResourceRequested` event.  If the same filter was added multiple
  /// times, then it must be removed as many times as it was added for the
  /// removal to be effective.  Returns `E_INVALIDARG` for a filter that was
  /// never added.
  HRESULT RemoveWebResourceRequestedFilterWithRequestSource(
      [in] LPCWSTR const uri,
      [in] COREWEBVIEW2_WEB_RESOURCE_CONTEXT const resourceContext,
      [in] COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE const requestSource);
 }

/// Event args for the `WebResourceRequested` event.
[uuid(572f38f9-c317-4b6c-8dd2-c8b894779bbb), object, pointer_default(unique)]
interface ICoreWebView2WebResourceRequestedEventArgs : IUnknown {
  /// The web resource request source.
  [propget] HRESULT RequestSource(
  [out, retval] COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE* requestSource);
}
```

## .NET and WinRT
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    [flags]
    enum CoreWebView2WebResourceRequestSource
    {
        Document = 0x00000001,
        SharedWorker = 0x00000002,
        ServiceWorker = 0x00000004,
        All = 0xFFFFFFFF,
    };

    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_Manual")]
    {
        void AddWebResourceRequestedFilter(
                String uri,
                CoreWebView2WebResourceContext ResourceContext,
                CoreWebView2WebResourceRequestSource RequestSource);

        void RemoveWebResourceRequestedFilter(
                String uri,
                CoreWebView2WebResourceContext ResourceContext,
                CoreWebView2WebResourceRequestSource RequestSource);
    }

    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingWebResourceRequestedEventArgs")]
    {
        // ICoreWebView2StagingWebResourceRequestedEventArgs members
        CoreWebView2WebResourceRequestSource RequestSource { get; };
    }
}
```
