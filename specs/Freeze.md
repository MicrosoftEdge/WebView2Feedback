# Background
Edge browser has a sleeping tab feature which reduces resource usage when the tab is in the background. We are introducing WebView2 APIs
to access this feature so that invisible WebView can use less resources. We'd appreciate your feedback.


# Description
You may call the `TryFeezeAsync` API to have the WebView2 consume less memory. This is useful when your Win32 app becomes invisible, or when your Universal Windows Platform app is suspended, during the suspended event handler before completing the suspended event.

# Examples
## .Net, WinRT
```c#
async protected void OnSuspending(object sender, SuspendingEventArgs args)
{
    SuspendingDeferral deferral = args.SuspendingOperation.GetDeferral();
    // Set webView.Visibility to false first.
    // WebView2 must be invisible for TryFreezeAsync to succeed.
    webView.Visibility = false;
    await webView.CoreWebView2.TryFreezeAsync();
    deferral.Complete();
}
async protected void OnSuspending(object sender, Object args)
{
    // Making a WebView2 visible will automatically unfreeze it
    // But you can also explicitly call Unfreeze without making a WebView2 visible to unfreeze it.
    webView.CoreWebView2.Unfreeze();
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
            Freeze();
        }
        else if (wParam == SC_RESTORE)
        {
            // When the app window is restored, show the webview
            // (unless the user has toggle visibility off).
            if (m_isVisible)
            {
                Unfreeze();
                m_controller->put_IsVisible(TRUE);
            }
        }
    }
}

void ViewComponent::Freeze()
{
    HRESULT hr = webView->TryFreeze(
        Callback<ICoreWebView2StagingTryFreezeCompletedHandler>(
            [](HRESULT errorCode, BOOL isSuccessful) -> HRESULT {
                std::wstringstream formattedMessage;
                formattedMessage << "TryFreeze result (0x" << std::hex << errorCode
                                 << ") " << (isSuccessful ? "succeeded" : "failed");
                MessageBox(nullptr, formattedMessage.str().c_str(), nullptr, MB_OK);
                return S_OK;
            })
            .Get());
    if (FAILED(hr))
        ShowFailure(hr, L"Call to TryFreeze failed");
}

void ViewComponent::Unfreeze()
{
    wil::com_ptr<ICoreWebView2Staging2> webView;
    webView = m_webView.query<ICoreWebView2Staging2>();
    webView->Unfreeze();
}
```

# Remarks
The CoreWebView2Controller must be invisible when the API is called. Otherwise, the
API fails with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.   
Freezing is similar to putting a tab to sleep in the Edge browser. Freezing pauses
WebView script timers and animations, minimizes CPU usage for the associated
browser renderer process and allows the operating system to reuse the memory that was
used by the renderer process for other processes.   
Note that the freeze is best effort and considered completed successfully once the request
is sent to browser renderer process. If there is a running script, the script will continue
to run and the renderer process will be frozen after that script is done.
See [Sleeping Tabs FAQ](https://techcommunity.microsoft.com/t5/articles/sleeping-tabs-faq/m-p/1705434)
for conditions that might prevent WebView from being frozen. In those situations,
The TryFreeze operation will fail and the completed handler will be invoked with isSuccessful as false.   
The WebView will be automatically unfrozen when it becomes visible. Therefore, the app normally doesn't have to call Unfreeze.
The app can call `Unfreeze` and then `TryFreeze` periodically for an invisibile WebView so that the invisible WebView can sync up with
latest data and the page ready to show fresh content when it becomes visible.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```IDL
interface ICoreWebView2_2 : ICoreWebView2 {

  /// An app may call the `TryFeezeAsync` API to have the WebView2 consume less memory.
  /// This is useful when a Win32 app becomes invisible, or when a Universal Windows
  /// Platform app is suspended, during the suspended event handler before completing
  /// the suspended event.
  /// The CoreWebView2Controller must be invisible when the API is called. Otherwise, the
  /// API fails with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// Freezing is similar to putting a tab to sleep in the Edge browser. Freezing pauses
  /// WebView script timers and animations, minimizes CPU usage for the associated
  /// browser renderer process and allows the operating system to reuse the memory that was
  /// used by the renderer process for other processes.
  /// Note that the freeze is best effort and considered completed successfully once the request
  /// is sent to browser renderer process. If there is a running script, the script will continue
  /// to run and the renderer process will be frozen after that script is done.
  /// See [Sleeping Tabs FAQ](https://techcommunity.microsoft.com/t5/articles/sleeping-tabs-faq/m-p/1705434)
  /// for conditions that might prevent WebView from being frozen. In those situations,
  /// The TryFreeze operation will fail and the completed handler will be invoked with isSuccessful as false.
  /// The WebView will be automatically unfrozen when it becomes visible. Therefore, the
  /// app normally doesn't have to call Unfreeze.
  /// The app can call `Unfreeze` and then `TryFreeze` periodically for an invisibile WebView so that
  /// the invisible WebView can sync up with latest data and the page ready to show fresh content
  /// when it becomes visible.
  HRESULT TryFreeze([in] ICoreWebView2StagingTryFreezeCompletedHandler* handler);

  /// Unfreeze the WebView so that it would resume activities on the web page.
  /// This API can be called while the WebView2 controller is invisible.
  /// The app can interact with the WebView immediately after unfreeze.
  /// WebView will be automatically unfrozen when it becomes visible.
  HRESULT Unfreeze();
}

/// The caller implements this interface to receive the TryFreeze result.
[uuid(00F206A7-9D17-4605-91F6-4E8E4DE192E3), object, pointer_default(unique)]
interface ICoreWebView2StagingTryFreezeCompletedHandler : IUnknown {

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
        public Task<bool> TryFreezeAsync();
        public void Unfreeze();
    }
}
```
