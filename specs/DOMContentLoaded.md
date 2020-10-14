# Background

In response to consumers' requests for an event similar to the old [WebView DOMContentLoaded](https://docs.microsoft.com/en-us/microsoft-edge/hosting/webview#mswebviewdomcontentloaded), the WebView2 team has introduced DOMContentLoaded API which indicates that the main DOM elements have finished loading.
In this document we describe the new API. We'd appreciate your feedback.

# Description
We propose adding DOMContentLoaded to CoreWebView2. This allows the developer to have an event that fires when the DOM is loaded after the WebView2 navigates to a page.

# Examples
## Win32 C++
```
ScenarioDOMContentLoaded::ScenarioDOMContentLoaded(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [DOMContentLoaded]
    // Register a handler for the DOMContentLoaded event.
    // Event is raised when the DOM content is loaded
    CHECK_FAILURE(m_webView->add_DOMContentLoaded(
        Callback<ICoreWebView2DOMContentLoadedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2DOMContentLoadedEventArgs* args)
                -> HRESULT {
                m_webView->ExecuteScript(
                    LR"~(
                    let content=document.createElement("h2");
                    content.style.color='blue';
                    content.textContent="This text was added by the host app";
                    document.body.appendChild(content);
                    )~",
                    Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                        [](HRESULT error, PCWSTR result) -> HRESULT { return S_OK; })
                        .Get());
                return S_OK;
            })
            .Get(),
        &m_DOMContentLoadedToken));
    //! [DOMContentLoaded]
```

## C#
```
webView.CoreWebView2.DOMContentLoaded += (object sender, CoreWebView2DOMContentLoadedEventArgs arg) =>
{
    _ = webView.ExecuteScriptAsync("let " +
                              "content=document.createElement(\"h2\");content.style.color=" +
                              "'blue';content.textContent= \"This text was added by the " +
                              "host app\";document.body.appendChild(content);");
};
webView.NavigateToString(@"<!DOCTYPE html><h1>DOMContentLoaded sample page</h1><h2>The content below will be added after DOM content is loaded </h2>");

```

# API Notes

See [API Details](#api-details) section below for API reference.
# API Details

## Win32 C++

```IDL
interface ICoreWebView2_2;
interface ICoreWebView2DOMContentLoadedEventArgs;
interface ICoreWebView2DOMContentLoadedEventHandler;

[uuid(9810c82b-8483-4f1c-b2f4-6244f1010c05), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
  /// Add an event handler for the DOMContentLoaded event.
  /// DOMContentLoaded is raised when the initial html document has been parsed.
  /// This aligns with the the document's DOMContentLoaded event in html
  ///
  /// \snippet ScenarioDOMContentLoaded-Staging.cpp
  HRESULT add_DOMContentLoaded(
      [in] ICoreWebView2StagingDOMContentLoadedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_DOMContentLoaded.
  HRESULT remove_DOMContentLoaded(
      [in] EventRegistrationToken token);
}

/// Event args for the DOMContentLoaded event.
[uuid(E8BA4206-D6F8-42F1-9A6D-43C8A99C1F39), object, pointer_default(unique)]
interface ICoreWebView2DOMContentLoadedEventArgs : IUnknown {
  /// The ID of the navigation which corresponds to other navigation ID properties on other navigation events.
  [propget] HRESULT NavigationId([out, retval] UINT64* navigationId);
}

/// The caller implements this interface to receive the DOMContentLoaded
/// event.
[uuid(1E649181-785D-40B2-B4AE-AFACD3C6B8DD), object, pointer_default(unique)]
interface ICoreWebView2DOMContentLoadedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2DOMContentLoadedEventArgs* args);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DOMContentLoadedEventArgs;

    runtimeclass CoreWebView2DOMContentLoadedEventArgs
    {
        // CoreWebView2DOMContentLoadedEventArgs
        UInt64 NavigationId { get; };
    }

    runtimeclass CoreWebView2
    {
        // CoreWebView2
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DOMContentLoadedEventArgs> DOMContentLoaded;
    }


}
```
