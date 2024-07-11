Critical Update Available
===

# Background
As WebView2 developers, we often have to author ECS (experimentation and configuration service - 
used to perform A/B testing or remotely disable features) configurations to toggle feature flags. 
However, once these payloads are received, there is no way to restart the WebView2 and apply the
payload. The purpose of this API is to detect such critical payloads and inform the end developer
so they may restart their app or their WebView2 or other appropriate action.

# Examples
## WinRT and .NET   
```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.Environment.RestartRequested += WebView_RestartRequested;
    }
}

void WebView_RestartRequested(CoreWebView2Environment sender, object e)
{
    // Depending on your app experience, you may or may not
    // want to prompt user to restart the app.
    RestartIfSelectedByUser();
}
```

## Win32 C++
```cpp
wil::com_ptr<ICoreWebView2Environment> m_webViewEnvironment;
void CoreWebView2InitializationCompleted() {
    auto env10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
    if (env10) {
        CHECK_FAILURE(env10->add_RestartRequested(
            Callback<ICoreWebView2RestartRequestedEventHandler>(
                [this](ICoreWebView2Environment* sender, IUnknown* args) -> HRESULT
                {
                    // Depending on your app experience, you may or may not
                    // want to prompt user to restart the app.
                    RestartIfSelectedByUser();
                    return S_OK;
                })
                .Get(),
            nullptr));
    }
}
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++

```IDL
interface ICoreWebView2Environment10;
interface ICoreWebView2RestartRequestedEventHandler;

[uuid(62cb67c6-b6a9-4209-8a12-72ca093b9547), object, pointer_default(unique)]
interface ICoreWebView2RestartRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Environment* sender, [in] IUnknown* args);
}

[uuid(ef7632ec-d86e-46dd-9d59-e6ffb5c87878), object, pointer_default(unique)]
interface ICoreWebView2Environment10 : IUnknown {
  /// Add an event handler for the `RestartRequested` event.
  /// `RestartRequested` event is raised when there is an urgent need to 
  /// restart the WebView2 process in order to enable or disable 
  /// features that are causing WebView2 reliability or performance to drop critically.
  /// `RestartRequested` gives you the awareness of these necessary WebView2 restarts,
  /// allowing you to resolve issues faster than waiting for your end users to restart the app.
  /// Depending on your app you may want to prompt your end users in some way to give
  /// them a chance to save their state before you restart the WebView2.
  /// 
  /// For apps with multiple processes that host WebView2s that share the same user data folder you
  /// need to make sure all WebView2 instances are closed and the associated WebView2 Runtime
  /// browser process exits. See `BrowserProcessExited` for more details.
  // MSOWNERS: xiaqu@microsoft.com
  HRESULT add_RestartRequested(
      [in] ICoreWebView2RestartRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_RestartRequested`.
  // MSOWNERS: xiaqu@microsoft.com
  HRESULT remove_RestartRequested(
      [in] EventRegistrationToken token);
}
```
s
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        // ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, Object> RestartRequested;
    }
}
```