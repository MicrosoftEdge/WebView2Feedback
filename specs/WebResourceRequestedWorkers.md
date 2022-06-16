WebResourceRequested events for workers
===

# Background
Currently [WebResourceRequested events](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/iwebview2webview5?view=webview2-0.8.355#add_webresourcerequested) are raised only for main page HTTP requests. We are extending [AddWebResourceRequestedFilter](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/iwebview2webview5?view=webview2-0.8.355#addwebresourcerequestedfilter) API to allow you additionally to subscribe to events raised from Service or Shared workers and fixing oop iframes events as part of the main page.

# Examples
Subscribe to WebResourceRequested event for service workers

.Net
```c#
Controller.CoreWebView2.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All, CoreWebView2WebResourceRequestSource.ServiceWorker);
Controller.CoreWebView2.WebResourceRequested += (sender, e) =>
{
    string message =  "{" + WebResourceRequestedToJsonString(e.Request, e.RequestSource);
    message += WebViewPropertiesToJsonString(sender) + "}";
    PostEventMessage(message);
};
```

C++
```cpp
m_webviewEventSource->AddWebResourceRequestedFilterWithRequestSource(
            L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
            COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER);
m_webviewEventSource->add_WebResourceRequested(
        Callback<ICoreWebView2WebResourceRequestedEventHandler>(
            [this](ICoreWebView2* webview, ICoreWebView2WebResourceRequestedEventArgs* args)
                -> HRESULT {
                wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest;
                CHECK_FAILURE(args->get_Request(&webResourceRequest));
                std::wstring source;
                wil::com_ptr<ICoreWebView2WebResourceRequestedEventArgs2>
                    webResourceRequestArgs;
                if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&webResourceRequestArgs))))
                {
                    COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE requestSource =
                        COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_ALL;
                    webResourceRequestArgs->get_RequestSource(&requestSource);
                    if (requestSource != COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_ALL)
                    {
                        source =
                            L", \"source\": " + WebRequestSourceToString(requestSource);
                    }
                }
                std::wstring message = L"{" + WebResourceRequestedToJsonString(webResourceRequest.get(), source);
                message += WebViewPropertiesToJsonString(m_webviewEventSource.get());
                message += L"}";
                PostEventMessage(message);
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
  COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_DOCUMENTS = 1,

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
  /// Extends AddWebResourceRequestedFilter to support events from shared
  /// and service workers. To receive all raised events filters have to be added
  /// before main page navigation.
  /// Because service worker runs separately from any one HTML document its WebResourceRequested
  /// will be raised for all CoreWebView2s that have appropriate filters added in the
  /// corresponding CoreWebView2Environment.
  /// You should only add a WebResourceRequested filter for
  /// COREWEBVIEW2_WEB_RESOURCE_REQUEST_SOURCE_SERVICE_WORKER on
  /// one CoreWebView2 to avoid handling the same WebResourceRequested
  /// event multiple times.
  ///
  /// For more information about web resource requested filters, navigate to
  /// AddWebResourceRequestedFilter.
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
    void AddWebResourceRequestedFilter(String uri, CoreWebView2WebResourceContext ResourceContext);
    void RemoveWebResourceRequestedFilter(String uri, CoreWebView2WebResourceContext ResourceContext);

    [flags]
    enum CoreWebView2WebResourceRequestSource
    {
        Documents = 0x00000001,
        SharedWorker = 0x00000002,
        ServiceWorker = 0x00000004,
        All = 0xFFFFFFFF,
    };

    runtimeclass CoreWebView2
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

    runtimeclass CoreWebView2WebResourceRequestedEventArgs
    {
        CoreWebView2WebResourceRequestSource RequestSource { get; };
    }
}
```
