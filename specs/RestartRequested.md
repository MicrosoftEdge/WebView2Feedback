Restart Requested
===

# Background
There are often times when WebView2 needs to be restarted to apply certain updates or change 
configuration. The purpose of this API is to detect whether such a restart is requested and 
to provide the urgency of the restart. WebView2 developers can listen to this event for version 
updates, version downgrades, or important configuration changes to determine if they need to 
prompt the user for a restart to apply those updates.

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

void WebView_RestartRequested(CoreWebView2Environment sender, CoreWebView2RestartRequestedEventArgs e)
{
    if (e.Priority <= CoreWebView2RestartRequestedPriority.Normal) 
    {
        // Depending on your app experience, you should remind the user
        // to restart on normal cadence.
        RemindToRestartForUpdate();
    }
    else
    {
        // Depending on your app experience, you should prompt
        // the user to save their current state and restart or otherwise more urgently restart the WebView2.
        RestartIfSelectedByUser();
    }
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
                [this](ICoreWebView2Environment* sender, ICoreWebView2RestartRequestedEventArgs* args) -> HRESULT
                {
                    COREWEBVIEW2_RESTART_REQUESTED_PRIORITY priority;
                    CHECK_FAILURE(args->get_Priority(&priority));
                    if (priority <= COREWEBVIEW2_RESTART_REQUESTED_PRIORITY_NORMAL) 
                    {
                        // Depending on your app experience, you should remind user
                        // to restart on normal cadence.
                        RemindToRestartForUpdate();
                    }
                    else
                    {
                        // Depending on your app experience, you should prompt
                        // user to save their current state and restart.
                        RestartIfSelectedByUser();
                    }
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
interface ICoreWebView2RestartRequestedEventArgs;

/// Specifies the restart requested priority from 
/// `ICoreWebView2RestartRequestedEventArgs` interface.
[v1_enum]
typedef enum COREWEBVIEW2_RESTART_REQUESTED_PRIORITY {
  /// Developer should remind user to restart.
  COREWEBVIEW2_RESTART_REQUESTED_PRIORITY_NORMAL = 1000,
  /// Developer should prompt user to restart as soon as possible. 
  COREWEBVIEW2_RESTART_REQUESTED_PRIORITY_HIGH = 2000,
} COREWEBVIEW2_RESTART_REQUESTED_PRIORITY;

[uuid(62cb67c6-b6a9-4209-8a12-72ca093b9547), object, pointer_default(unique)]
interface ICoreWebView2RestartRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Environment* sender,
      [in] ICoreWebView2RestartRequestedEventArgs* args);
}

/// Event args for the `RestartRequested` event.
[uuid(6dbfe971-a69e-4338-9b6e-b0ec9f12424f), object, pointer_default(unique)]
interface ICoreWebView2RestartRequestedEventArgs : IUnknown {
  /// Get the restart requested priority.
  [propget] HRESULT Priority([out, retval] COREWEBVIEW2_RESTART_REQUESTED_PRIORITY* value);
}

[uuid(ef7632ec-d86e-46dd-9d59-e6ffb5c87878), object, pointer_default(unique)]
interface ICoreWebView2Environment10 : IUnknown {
  /// Add an event handler for the `RestartRequested` event.
  /// `RestartRequested` event is raised when there is a need to restart WebView2 process
  /// in order to apply certain beneifical updates.
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
}
```
s
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2RestartRequestedPriority
    {
        Normal = 1000,
        High = 2000,
    };

    runtimeclass CoreWebView2RestartRequestedEventArgs
    {
        CoreWebView2RestartRequestedPriority Priority { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, CoreWebView2RestartRequestedEventArgs> RestartRequested;
    }
}
```