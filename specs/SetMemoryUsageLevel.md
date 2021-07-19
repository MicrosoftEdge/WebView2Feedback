# Background
Some WebView2 apps want to continue to run scripts while inactive and therefore cannot make usage of `TrySuspend` and `Resume` APIs to reduce resource consumption.
We are introducing WebView2 API to reduce memory usage only for this type of inactive WebViews.

# Description
You may set the `MemoryUsageTargetLevel` property to have the WebView2 consume less memory and going back to normal usage. This is useful when your Win32 app becomes invisible, 
but still wants to have script running or monitoring requests from network.

# Examples
## .NET, WinRT
```c#
async protected void OnBecomingInactive()
{
    // CanSuspendWebView() uses app specific logic to check whether the current web contents in the WebView2 can be suspended.
    if (CanSuspendWebView())
    {
        await webView.CoreWebView2.TrySuspendAsync();
    }
    else
    {
        webView.CoreWebView2.MemoryUsageTargetLevel = CoreWebView2MemoryUsageTargetLevel.Low;
    }
}
async protected void OnBecomingActive()
{
    if (webView.CoreWebView2.IsSuspended)
    {
        webView.CoreWebView2.Resume();
    }
    else if (webView.CoreWebView2.MemoryUsageTargetLevel == CoreWebView2MemoryUsageTargetLevel.Low)
    {
        webView.CoreWebView2.MemoryUsageTargetLevel = CoreWebView2MemoryUsageTargetLevel.Normal;
    }
}
```
## Win32 C++
```cpp
bool ViewComponent::HandleWindowMessage(
    HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam, LRESULT* result)
{
    if (message == WM_SYSCOMMAND)
    {
        if (wParam == SC_MINIMIZE)
        {
            OnBecomingInactive();
        }
        else if (wParam == SC_RESTORE)
        {
            OnBecomingActive();
        }
    }
}

void ViewComponent::OnBecomingInactive()
{
    // CanSuspendWebView() uses app specific logic to check whether the current web contents in the WebView2 can be suspended.
    if (CanSuspendWebView())
    {
        CHECK_FAILURE(m_webView->TrySuspend(nullptr));
    }
    else
    {
        CHECK_FAILURE(m_webView->put_MemoryUsageTargetLevel(COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW);
    }
}

void ViewComponent::OnBecomingActive()
{
  BOOL isSuspended = FALSE;
  CHECK_FAILURE(m_webview->get_IsSuspended(&isSuspended));
  if (isSuspended)
  {
     CHECK_FAILURE(m_webView->Resume());
  }
  else
  {
     COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL memoryUsageTargetLevel = COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW;
     CHECK_FAILURE(m_webview->get_MemoryUsageTargetLevel(&memoryUsageTargetLevel));
     if (memoryUsageTargetLevel == COREWEBVIEW2_MEMORY_USAGE_LEVEL_LOW)
     {
         CHECK_FAILURE(m_webView->put_MemoryUsageTargetLevel(COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_NORMAL));
     }
  }
}
```

# Remarks
See [API Details](#api-details) section below for more details.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```IDL
/// Specifies memory usage target level of WebView.
[v1_enum]
typedef enum COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL
{
    /// Specifies normal memory usage target level.
    COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_NORMAL,

    /// Specifies low memory usage target level.
    /// Used for inactivate WebView for reduced memory consumption.
    COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW,

} COREWEBVIEW2_MEMORY_USAGE_LEVEL;

interface ICoreWebView2_6 : ICoreWebView2
{

  /// `MemoryUsageTargetLevel` indicates desired memory comsumption level of WebView.
  HRESULT get_MemoryUsageTargetLevel([in] COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL* level);
  
  /// An app may set `MemoryUsageTargetLevel` to indicate desired memory
  /// comsumption level of WebView. Scripts will not be impacted and continue to run.
  /// This is useful for inactive apps that still want to run scripts and/or keep
  /// network connections alive and therefore could not call `TrySuspend` and `Resume`
  /// to reduce memory consumption.
  /// These apps can set memory usage target level to `COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW` when
  /// the app becomes inactive, and set back to `COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_NORMAL` when
  /// the app becomes active.
  /// It is not neccesary to set CoreWebView2Controller's IsVisible property to false when calling the API.
  /// It is a best effort operation to change memory usage level, and the API will return before the operation completes.
  /// Setting the level to `COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW` could potentially cause
  /// memory for some WebView browser processes to be swapped out to disk when needed. Therefore,
  /// it is important for the app to set the level back to `COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_NORMAL`
  /// when the app becomes active again to have a smooth user experience.
  /// Setting memory usage level back to normal will not happen automatically.
  /// An app should choose to use either the combination of `TrySuspend` and `Resume` or the combination
  /// of setting MemoryUsageTargetLevel to low and normal. It is not advisable to mix them.
  /// The TrySuspend and Resume methods will change the MemoryUsageTargetLevel.
  /// TrySuspend will automatically set MemoryUsageTargetLevel to low while Resume on suspended WebView
  /// will automatically set MemoryUsageTargetLevel to normal.
  /// Calling `Resume` when the WebView is not suspended would not change MemoryUsageTargetLevel.
  /// Setting MemoryUsageTargetLevel to normal on suspended WebView will auto resume WebView.
  HRESULT put_MemoryUsageTargetLevel([in] COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL level);
}

```

## .NET WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2MemoryUsageTargetLevel
    {
        /// 
        Normal = 0,
        /// 
        Low = 1,
    }
    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public CoreWebView2MemoryUsageTargetLevel MemoryUsageTargetLevel { get; set; };
    }
}
```
