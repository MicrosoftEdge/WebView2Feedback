# Background

There are two types of zoom in Chromium: Browser Zoom and Pinch-Zoom:
- Browser zoom, referred to as “Page Zoom” or “Zoom” more generally, is what we get by using Ctrl + +(plus) or – (minus) or Ctrl + Mousewheel. This changes the size of a CSS pixel relative to a device independent pixel and so it will cause page layout to change. End developers can programmatically change browser Zoom properties including [IsZoomControlEnabled](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2settings?view=webview2-1.0.774.44#get_iszoomcontrolenabled) and [ZoomFactor](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2controller?view=webview2-1.0.774.44#get_zoomfactor). Setting ZoomFactor property causes the layout to change and enables scroll bar which lets users interact with the zoomed in content using mouse.
- Pinch-zoom, referred to as “Page Scale” zoom, is performed as a post-rendering step, it changes the page scale factor property and scales the surface the web page is rendered onto when user perfoms a pinch zooming action. It does not change the layout but rather changes the viewport and clips the web content, the content outside of the viewport isn't visible onscreen and users can't reach this content using mouse.

Currently, the first type of zoom control is supported in WebView2 and modifying it has no effect on page scale zoom. 

In response to customer requests to be able to change the current functionality of page scale zoom in WebView2, the WebView2 team has introduced this Pinch Zoom API which allows end developers to disable or enable page scale zoom control via a setting.

In this document we describe the new setting. We'd appreciate your feedback.


# Description
The default value for `IsPinchZoomEnabled` is `true`.
When this setting is set to `false`, it disables the ability of the end users to use pinching motions on touch input enabled devices to scale the web content in the WebView2 and users cannot pinch zoom.
Disabling/Enabling `IsPinchZoomEnabled` does not take effect until the next navigation, it only affects the end user's ability to use pinch motions and does not change the page scale factor.


# Examples
```cpp
wil::com_ptr<ICoreWebView2> webView;
void SettingsComponent::TogglePinchZooomEnabled()
{
    // Get webView's current settings
    wil::com_ptr<ICoreWebView2Settings> coreWebView2Settings;
    CHECK_FAILURE(webView->get_Settings(&coreWebView2Settings));
    wil::com_ptr<ICoreWebView2Settings4> coreWebView2Settings4;
    coreWebView2Settings4 = coreWebView2Settings.try_query<ICoreWebView2Settings4>();
    if(coreWebView2Settings4) 
    {
        BOOL enabled;
        CHECK_FAILURE(coreWebView2Settings4->get_IsPinchZoomEnabled(&enabled));
        CHECK_FAILURE(coreWebView2Settings4->put_IsPinchZoomEnabled(enabled ? FALSE : TRUE));
    }
}
```

```c#
private WebView2 _webView;
void TogglePinchZoomEnabled()
{
    var coreWebView2Settings = _webView.CoreWebView2.Settings;
    coreWebView2Settings.IsPinchZoomEnabled = !coreWebView2Settings.IsPinchZoomEnabled;
}
```

# Remarks
When `IsPinchZoomEnabled` is set to `false`, pinch zooming is disabled in WebView. This however doesn't modify the underlying page scale factor of page scale zoom.

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```cpp
[uuid(B625A89E-368F-43F5-BCBA-39AA6234CCF8), object, pointer_default(unique)]
interface ICoreWebView2Settings4 : ICoreWebView2Settings3 {
  /// The IsPinchZoomEnabled property enables or disables the ability of 
  /// the end user to use a pinching motion on touch input enabled devices
  /// to scale the web content in the WebView2. It defaults to TRUE.
  /// When set to FALSE, the end user cannot pinch zoom.
  /// This API only affects the Page Scale zoom and has no effect on the
  /// existing browser zoom properties (IsZoomControlEnabled and ZoomFactor)
  /// or other end user mechanisms for zooming.
  ///
  /// \snippet SettingsComponent.cpp TogglePinchZooomEnabled
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
        public bool IsPinchZoomEnabled { get; set; };

    }
}

```
