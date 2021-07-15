# Background
Some WebView2 apps want to continue to run scripts while inactive and therefore cannot make usage of `TrySuspend` and `Resume` APIs to reduce resource consumption.
We are introducing WebView2 API to reduce memory usage only for this type of inactive WebViews.

# Description
You may call the `SetMemoryUsageLevel` API to have the WebView2 consume less memory and going back to normal usage. This is useful when your Win32 app becomes invisible, 
but still wants to have script running or monitoring requests from network.

# Examples
## .NET, WinRT
```c#
async protected void OnBecomingInactive()
{
    webView.CoreWebView2.SetMemoryUsageLevel(CoreWebView2MemoryUsageLevel.Idle);
}
async protected void OnBecomingActive()
{
    webView.CoreWebView2.SetMemoryUsageLevel(CoreWebView2MemoryUsageLevel.Normal);
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
    HRESULT hr = webView->SetMemoryUsageLevel(COREWEBVIEW2_MEMORY_USAGE_LEVEL_IDLE);
    if (FAILED(hr))
        ShowFailure(hr, L"Failed to set SetMemoryUsageLevel to idle");
}

void ViewComponent::OnBecomingActive()
{
    HRESULT hr = webView->SetMemoryUsageLevel(COREWEBVIEW2_MEMORY_USAGE_LEVEL_NORMAL);
    if (FAILED(hr))
        ShowFailure(hr, L"Failed to set SetMemoryUsageLevel to normal");
}

```

# Remarks
See [API Details](#api-details) section below for more details.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```IDL
/// Specifies memory usage level of WebView.
[v1_enum]
typedef enum COREWEBVIEW2_MEMORY_USAGE_LEVEL {
    /// Specifies normal memory usage level.
    COREWEBVIEW2_MEMORY_USAGE_LEVEL_NORMAL,

    /// Specifies idle memory usage level.
    /// Used for inactivate WebView for reduced memory consumption.
    COREWEBVIEW2_MEMORY_USAGE_LEVEL_IDLE,

} COREWEBVIEW2_MEMORY_USAGE_LEVEL;

interface ICoreWebView2_6 : ICoreWebView2 {

  /// An app may call the `SetMemoryUsageLevel` API to indicate desired memory
  /// comsumption level of WebView. Scripts will not be impacted and continue to run.
  /// This is useful for inactive apps that still want to run scripts and/or keep
  /// network connections alive and therefore could not call `TrySuspend` and `Resume`
  /// to reduce memory consumption.
  /// These apps can set memory usage level to `COREWEBVIEW2_MEMORY_USAGE_LEVEL_IDLE` when
  /// the app becomes inactive, and set back to `COREWEBVIEW2_MEMORY_USAGE_LEVEL_NORMAL` when
  /// the app becomes active.
  /// It is not neccesary to set CoreWebView2Controller's IsVisible property to false when calling the API.
  /// It is a best effort operation to change memory usage level, and the API will return before the operation completes.
  /// Setting the level to `COREWEBVIEW2_MEMORY_USAGE_LEVEL_IDLE` could potentially cause
  /// memory for some WebView browser processes to be swapped out to disk when needed. Therefore,
  /// it is important for the app to set the level back to `COREWEBVIEW2_MEMORY_USAGE_LEVEL_NORMAL`
  /// when the app becomes active again to have smoothy user experience.
  /// Setting memory usage level back to normal will not happen automatically.
  HRESULT SetMemoryUsageLevel([in] COREWEBVIEW2_MEMORY_USAGE_LEVEL level);
}

```

## .NET WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public void SetMemoryUsageLevel(CoreWebView2MemoryUsageLevel level);
    }
}
```
