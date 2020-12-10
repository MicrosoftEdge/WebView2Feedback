# Background
Edge browser has a sleeping tab feature which reduces resource usage when the tab is in the background. We are introducing WebView2 APIs
to access this feature so that invisible WebView can use less resources. We'd appreciate your feedback.


# Description
You may call the `TrySuspendAsync` API to have the WebView2 consume less memory. This is useful when your Win32 app becomes invisible, or when your Universal Windows Platform app is being suspended, during the suspended event handler before completing the suspended event.

# Examples
## .Net, WinRT
```c#
async protected void OnSuspending(object sender, SuspendingEventArgs args)
{
    SuspendingDeferral deferral = args.SuspendingOperation.GetDeferral();
    // Ensure that CoreWebView2Controller is invisible, it must be invisible for TrySuspendAsync to succeed.
    // webView here is WinUI WebView2 control.
    // For WPF and Winforms WebView2 control, do webView.Visibility = false;
    webView.Visibility = Visibility.Collapsed;
    await webView.CoreWebView2.TrySuspendAsync();
    deferral.Complete();
}
async protected void OnResuming(object sender, Object args)
{
    // Making a WebView2 visible will automatically resume it
    // But you can also explicitly call Resume without making a WebView2 visible to resume it.
    webView.CoreWebView2.Resume();
    webView.Visibility = true;
}
```
## Win32 C++
As unfreeze is very fast and automatically happens when WebView becomes visible, the app can generaly immediately call `TryFreeze` when a WebView becomes invisible.
```cpp
bool ViewComponent::HandleWindowMessage(
    HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam, LRESULT* result)
{
    if (message == WM_SYSCOMMAND)
    {
        if (wParam == SC_MINIMIZE)
        {
            // Hide the webview when the app window is minimized, and freeze it.
            m_controller->put_IsVisible(FALSE);
            Suspend();
        }
        else if (wParam == SC_RESTORE)
        {
            // When the app window is restored, show the webview
            // (unless the user has toggle visibility off).
            if (m_isVisible)
            {
                Resume();
                m_controller->put_IsVisible(TRUE);
            }
        }
    }
}

void ViewComponent::Suspend()
{
    HRESULT hr = webView->TrySuspend(
        Callback<ICoreWebView2StagingTrySuspendCompletedHandler>(
            [](HRESULT errorCode, BOOL isSuccessful) -> HRESULT {
                std::wstringstream formattedMessage;
                formattedMessage << "TrySuspend result (0x" << std::hex << errorCode
                                 << ") " << (isSuccessful ? "succeeded" : "failed");
                MessageBox(nullptr, formattedMessage.str().c_str(), nullptr, MB_OK);
                return S_OK;
            })
            .Get());
    if (FAILED(hr))
        ShowFailure(hr, L"Call to TrySuspend failed");
}

void ViewComponent::Resume()
{
    wil::com_ptr<ICoreWebView2Staging2> webView;
    webView = m_webView.query<ICoreWebView2Staging2>();
    webView->Resume();
}
```

# Remarks
The CoreWebView2Controller's IsVisible property must be false when the API is called. Otherwise, the
API fails with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.   
Suspending is similar to putting a tab to sleep in the Edge browser. Suspending pauses
WebView script timers and animations, minimizes CPU usage for the associated
browser renderer process and allows the operating system to reuse the memory that was
used by the renderer process for other processes.   
Note that the Suspend is best effort and considered completed successfully once the request
is sent to browser renderer process. If there is a running script, the script will continue
to run and the renderer process will be suspended after that script is done.
See [Sleeping Tabs FAQ](https://techcommunity.microsoft.com/t5/articles/sleeping-tabs-faq/m-p/1705434)
for conditions that might prevent WebView from being suspended. In those situations,
The the completed handler will be invoked with isSuccessful as false and errorCode as S_OK.   
The WebView will be automatically resumed when it becomes visible. Therefore, the
app normally does not have to call Resume.
The app can call `Resume` and then `TrySuspend` periodically for an invisible WebView so that
the invisible WebView can sync up with latest data and the page ready to show fresh content
when it becomes visible.   
When WebView is suspended, While WebView properties can still be accessed, WebView methods are generally not accessible.
After `TrySuspend` is called and until WebView is resumed or `TrySuspend` resulted in not being successfully suspended,
calling WebView methods will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```IDL
interface ICoreWebView2_2 : ICoreWebView2 {

  /// An app may call the `TrySuspend` API to have the WebView2 consume less memory.
  /// This is useful when a Win32 app becomes invisible, or when a Universal Windows
  /// Platform app is being suspended, during the suspended event handler before completing
  /// the suspended event.
  /// The CoreWebView2Controller's IsVisible property must be false when the API is called.
  /// Otherwise, the API fails with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// Suspending is similar to putting a tab to sleep in the Edge browser. Suspending pauses
  /// WebView script timers and animations, minimizes CPU usage for the associated
  /// browser renderer process and allows the operating system to reuse the memory that was
  /// used by the renderer process for other processes.
  /// Note that the Suspend is best effort and considered completed successfully once the request
  /// is sent to browser renderer process. If there is a running script, the script will continue
  /// to run and the renderer process will be suspended after that script is done.
  /// See [Sleeping Tabs FAQ](https://techcommunity.microsoft.com/t5/articles/sleeping-tabs-faq/m-p/1705434)
  /// for conditions that might prevent WebView from being suspended. In those situations,
  /// The the completed handler will be invoked with isSuccessful as false and errorCode as S_OK.
  /// The WebView will be automatically resumed when it becomes visible. Therefore, the
  /// app normally does not have to call Resume.
  /// The app can call `Resume` and then `TrySuspend` periodically for an invisible WebView so that
  /// the invisible WebView can sync up with latest data and the page ready to show fresh content
  /// when it becomes visible.
  /// When WebView is suspended, while WebView properties can still be accessed, WebView methods are
  /// generally not accessible. After `TrySuspend` is called and until WebView is resumed or `TrySuspend`
  /// resulted in not being successfully suspended, calling WebView methods will fail with
  /// `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  HRESULT TrySuspend([in] ICoreWebView2StagingTrySuspendCompletedHandler* handler);

  /// Resume the WebView so that it would resume activities on the web page.
  /// This API can be called while the WebView2 controller is invisible.
  /// The app can interact with the WebView immediately after Resume.
  /// WebView will be automatically resumed when it becomes visible.
  ///
  /// \snippet ViewComponent.cpp ToggleIsVisibleOnMinimize
  ///
  /// \snippet ViewComponent.cpp Resume
  ///
  HRESULT Resume();

  /// `TRUE` when WebView is suspended.
  [propget] HRESULT IsSuspended([out, retval] BOOL* isSuspended);
}

/// The caller implements this interface to receive the TryFreeze result.
interface ICoreWebView2StagingTrySuspendCompletedHandler : IUnknown {

  /// Provide the result of the TrySuspend operation.
  /// See [Sleeping Tabs FAQ](https://techcommunity.microsoft.com/t5/articles/sleeping-tabs-faq/m-p/1705434)
  /// for conditions that might prevent WebView from being suspended. In those situations,
  /// isSuccessful will be false and errorCode is S_OK.
  HRESULT Invoke([in] HRESULT errorCode, [in] BOOL isSuccessful);

}
```
## .Net WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public Task<bool> TrySuspendAsync();
        public void Resume();
        public bool IsSuspended { get; }
    }
}
```
