Critical Update Available
===

# Background
As WebView2 developers, we often have to author ECS (experimentation and configuration service - used to perform A/B testing or remotely disable features) configurations to toggle feature flags. However, once 
these payloads are received, there is no way to restart the WebView2 and apply the payload. The 
purpose of this API is to detect such critical payloads and inform the end developer so they may
restart their app or their WebView2 or other appropriate action.

# Examples
## WinRT and .NET   
```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.Environment.CriticalRestartRequired += WebView_CriticalRestartRequired;
    }
}

void WebView_CriticalRestartRequired(object sender, object e)
{
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        // Depending on your app experience, you may or may not
        // want to prompt user to restart the app.
        RestartIfSelectedByUser();
    }, null);
}
```

## Win32 C++
```cpp
    wil::com_ptr<ICoreWebView2Environment> m_webViewEnvironment;
    auto env10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
    CHECK_FAILURE(env10->add_CriticalRestartRequired(
        Callback<ICoreWebView2CriticalRestartRequiredEventHandler>(
            [this](ICoreWebView2Environment* sender, IUnknown* args) -> HRESULT
            {
                // Depending on your app experience, you may or may not
                // want to prompt user to restart the app.
                RestartIfSelectedByUser();
                return S_OK;
            })
            .Get(),
        nullptr));
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++

```IDL
interface ICoreWebView2Environment10;
interface ICoreWebView2CriticalRestartRequiredEventHandler;

[uuid(62cb67c6-b6a9-4209-8a12-72ca093b9547), object, pointer_default(unique)]
interface ICoreWebView2CriticalRestartRequiredEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Environment* sender, [in] IUnknown* args);
}

[uuid(ef7632ec-d86e-46dd-9d59-e6ffb5c87878), object, pointer_default(unique)]
interface ICoreWebView2Environment10 : IUnknown {
  /// Add an event handler for the `CriticalRestartRequired` event.
  /// `CriticalRestartRequired` event is raised when there is an urgent need to prompt the user 
  /// to restart the WebView2 process to apply a particular configuration. The configuration 
  /// is authored to include special attribute to indicate a payload as critical.
  /// WebView2 team will author critical kill switch when there is a need to enable/disable 
  /// certain features that’s causing WebView2 reliability or performance drop that’s impacting customers.
  /// `CriticalRestartRequired` will give developer the ability to prompt user for restart,
  /// thus resolve in faster resolution time.
  /// 
  /// Critical Update is only applying payload; thus, version is not important. But for apps 
  /// created from the same user data folder that shared the same browser process, developers
  /// need to make sure the WebView2 instance is closed to apply the new payload.
  /// Developer can refer to`BrowserProcessExited`for more details.
  // MSOWNERS: xiaqu@microsoft.com
  HRESULT add_CriticalRestartRequired(
      [in] ICoreWebView2CriticalRestartRequiredvEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_CriticalRestartRequired`.
  // MSOWNERS: xiaqu@microsoft.com
  HRESULT remove_CriticalRestartRequired(
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
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, Object> CriticalRestartRequired;
    }
}
```