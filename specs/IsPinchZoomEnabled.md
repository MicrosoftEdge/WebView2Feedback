# Background

There are two types of zoom in Chromium: Browser Zoom and Pinch-Zoom:
- Browser zoom is what you get by using Ctrl + +(plus) or – (minus) or Ctrl + Mousewheel. 
- Pinch-zoom is activated by using a pinch gesture on a touchscreen. 

Currently, the first type of zoom control is supported in WebView2 and modifying it has no effect on pinch zoom. 

In response to customer requests to be able to change the current functionality of pinch zoon in WebView2: Disable/Enanle pinch zoom, the WebView2 team has introduced Pinch Zoom API which allows users to change setting to disable/enable pinch zoom.

In this document we describe the new setting. We'd appreciate your feedback.


# Description
The default value for IsPinchZoomEnabled is true.
When this setting is set to false, it disables pinch zoom in WebView.


# Examples
```cpp
void SettingsComponent::TogglePinchZooomEnabled()
{
    BOOL enabled;
    CHECK_FAILURE(coreWebView2Settings->get_IsPinchZoomEnabled(&enabled));
    CHECK_FAILURE(coreWebView2Settings->put_IsPinchZoomEnabled(enabled ? FALSE : TRUE));
}
```

```c#
privagte WebView2 _webView;
void TogglePinchZoomEnabled()
{
    var coreWebView2Settings = webView.CoreWebView2.Settings;
    coreWebView2Settings.IsPinchZoomEnabled = !coreWebView2Settings.IsPinchZoomEnabled;
}
```
# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```cpp
[uuid(B625A89E-368F-43F5-BCBA-39AA6234CCF8), object, pointer_default(unique)]
interface ICoreWebView2StagingSettings : IUnknown {
  /// The IsPinchZoomEnabled property is used to prevent the default
  /// pinch zoom control from working in webview. Defaults to TRUE.
  /// When disabled, user will not be able to pinch zoom.
  ///
  /// \snippet SettingsComponent.cpp DisablePinchZoom
  [propget] HRESULT IsPinchZoomEnabled([out, retval] BOOL* enabled);
  /// Set the IsPinchZoomEnabled property
  [propput] HRESULT IsPinchZoomEnabled([in] BOOL enabled);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
        /// 
        public bool IsPinchZoomEnabled { get; set};

    }
}

```
