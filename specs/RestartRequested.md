Restart Requested
===

# Background
There are often times when WebView2 need to be restarted to apply certain update, the purpose of 
this API is to detect whether a restart is requested from WebView2 base on different priority levels.
WebView2 developers can listen to this event for version update, version downgrade or important
feature flag update to determine the need to prompt user for restart to apply those updates.

# Examples
## WinRT and .NET   
```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.Environment.RestartPriorityLevel = CoreWebView2RestartPriorityLevel.Critical;
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
        CHECK_FAILURE(env10->put_RestartPriorityLevel(COREWEBVIEW2_RESTART_PRIORITY_LEVEL_CRITICAL));
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

/// The restart prioirty level can be set by the `RestartPriorityLevel` property.
/// The default value is `COREWEBVIEW2_RESTART_PRIORITY_LEVEL_BEST_EFFORT`.
[v1_enum]
typedef enum COREWEBVIEW2_RESTART_PRIORITY_LEVEL {
  /// Dveloper should prompt user to restart on best effort.
  COREWEBVIEW2_RESTART_PRIORITY_LEVEL_BEST_EFFORT,
  /// Developer should prompt user to restart as soon as possible. 
  c,
} COREWEBVIEW2_RESTART_PRIORITY_LEVEL;

[uuid(62cb67c6-b6a9-4209-8a12-72ca093b9547), object, pointer_default(unique)]
interface ICoreWebView2RestartRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Environment* sender, [in] IUnknown* args);
}

[uuid(ef7632ec-d86e-46dd-9d59-e6ffb5c87878), object, pointer_default(unique)]
interface ICoreWebView2Environment10 : IUnknown {
  /// Add an event handler for the `RestartRequested` event.
  /// `RestartRequested` event is raised when there is a need to restart WebView2 process
  /// in order to apply certain beneifical updates.
  /// Those updates can be the following cases:
  /// 1. New runtime version available.
  /// 2. Older runtime version available (downgradge due to severe bug).
  /// 3. Features being enabled/disabled that causing WebView2 reliability or performance 
  ///    to drop dramatically. 
  /// 
  /// `RestartRequested` is raised base on priority level. `RestartPriorityLevel` is used
  /// to determine the urgences on rasing such event.
  /// `COREWEBVIEW2_RESTART_PRIORITY_LEVEL_BEST_EFFORT`:
  ///   - Event rasied only on new runtime version available.
  ///   - Developer can notify user to restart on normal cadence.
  /// `COREWEBVIEW2_RESTART_PRIORITY_LEVEL_CRITICAL`: 
  ///   - Event raised for downgraded runtime version and feature enabled/disabled.
  ///   - Developer should notify user to restart as soon as possible. 
  /// 
  /// `RestartRequested` gives developers the awareness of these necessary WebView2 restarts,
  /// allowing developers to resolve issues faster than waiting for end users to restart the app.
  /// Developer might want to give end users the ability to save their state before restarting.
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

  /// Get the restart priority level.
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT RestartPriorityLevel(
      [out, retval] COREWEBVIEW2_RESTART_PRIORITY_LEVEL* value);

  /// Set the restart priority level. 
  /// The default value is `COREWEBVIEW2_RESTART_PRIORITY_LEVEL_BEST_EFFORT`.
  // MSOWNERS: xiaqu@microsoft.com
  [propput] HRESULT RestartPriorityLevel(
      [in] COREWEBVIEW2_RESTART_PRIORITY_LEVEL value);
}
```
s
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2RestartPriorityLevel
    {
        BestEffort = 0,
        Critical = 1,
    };

    runtimeclass CoreWebView2Environment
    {
        // ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, Object> RestartRequested;

        // Set restart priority level
        CoreWebView2RestartPriorityLevel RestartPriorityLevel { get; set; };
    }
}
```