# Background

Swiping navigation on touch screen includes: 
1. Swipe left/right (swipe horizontally) to navigate to previous/next page in navigation history. 
1. Pull to refresh (swipe vertically) the current page.

In response to customer requests, the WebView2 team has introduced this Swipe Navigation API which allows developers to disable or enable the the ability of end users to use swiping gesture to navigate in WebView via a setting.

In this document we describe the new setting. We'd appreciate your feedback.

# Description
The default value for `IsSwipeNavigationEnabled` is `TRUE`.
When this setting is set to `FALSE`, it disables the ability of the end users to use swiping gesture on touch input enabled devices to trigger navigations such as swipe left/right to go back/forward or pull to refresh current page.
Disabling/Enabling `IsSwipeNavigationEnabled` does not take effect until the next navigation.


# Examples
```cpp
wil::com_ptr<ICoreWebView2> webView;
void SettingsComponent::ToggleSwipeNavigationEnabled()
{
    // Get webView's current settings
    wil::com_ptr<ICoreWebView2Settings> coreWebView2Settings;
    CHECK_FAILURE(webView->get_Settings(&coreWebView2Settings));

    wil::com_ptr<ICoreWebView2Settings6> coreWebView2Settings6;
    coreWebView2Settings6 = coreWebView2Settings.try_query<ICoreWebView2Settings6>();
    if(coreWebView2Settings6) 
    {
        BOOL enabled;
        CHECK_FAILURE(coreWebView2Settings6->get_IsSwipeNavigationEnabled(&enabled));
        CHECK_FAILURE(coreWebView2Settings6->put_IsSwipeNavigationEnabled(enabled ? FALSE : TRUE));
    }
}
```

```c#
private WebView2 _webView;
void ToggleSwipeNavigationEnabled()
{
    var coreWebView2Settings = _webView.CoreWebView2.Settings;
    coreWebView2Settings.IsSwipeNavigationEnabled = !coreWebView2Settings.IsSwipeNavigationEnabled;
}
```

# Remarks
This API only affects the decision whether to trigger navigations of the main html page when end users perform overscrolling motions by swiping and has no effect on the scrolling interaction used to explore the web content shown in WebView2 or the CSS overscroll-behavior property.

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```cpp
[uuid(45b1f964-f703-47ac-a19a-b589dd0c5559), object, pointer_default(unique)]
interface ICoreWebView2Settings6 : ICoreWebView2Settings5 {
  /// The `IsSwipeNavigationEnabled` property enables or disables the ability of the
  /// end user to use swiping gesture on touch input enabled devices to
  /// navigate in WebView2. It defaults to `TRUE`.
  ///
  /// When this property is TRUE, then all configured navigation gestures are enabled: 
  /// 1. Swiping left and right to navigate forward and backward is always configured.
  /// 2. Swiping down to refresh is off by default and not exposed via our API currently, 
  /// it requires the --pull-to-refresh option to be included in the additional browser 
  /// arguments to be configured. (See put_AdditionalBrowserArguments.)
  ///
  /// When set to `FALSE`, the end user cannot swipe to navigate or pull to refresh.
  /// This API only affects the overscrolling navigation functionality and has no
  /// effect on the scrolling interaction used to explore the web content shown
  /// in WebView2.
  ///
  /// Disabling/Enabling IsSwipeNavigationEnabled takes effect after the
  /// next navigation.
  ///
  /// \snippet SettingsComponent.cpp ToggleSwipeNavigationEnabled
  [propget] HRESULT IsSwipeNavigationEnabled([out, retval] BOOL* enabled);
  /// Set the `IsSwipeNavigationEnabled` property
  [propput] HRESULT IsSwipeNavigationEnabled([in] BOOL enabled);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
     
        public bool IsSwipeNavigationEnabled { get; set; };

    }
}

```
