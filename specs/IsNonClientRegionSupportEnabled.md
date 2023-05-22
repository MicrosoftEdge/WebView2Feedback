# Background

To improve the developer experience for customizing non-client regions, WebView2 is working to support using DOM elements as nonclient regions. We currently have limited support for title bar aka draggable regions, and are working on building out support for caption control and resize regions. 

For security and flexibility, we want developers to be able to enable or disable all custom nonclient functionality per WebView. Nonclient functionality will affect that app window's size and position so it's important that developers can definitively toggle access. This can be achieved in a limited way using a feature flag, but feature flags are applied per WebView2 environment, thus, an API on the WebView2 to enable/disable nonclient support via a setting is the better solution.

# Description
`IsNonClientRegionSupportEnabled` defaults to `false`. Disabling/Enabling `IsNonClientRegionSupportEnabled` takes effect after the next navigation.  

When the setting is set to `true`, then the following non-client region support will be enabled: 
* Draggable Regions will support dragging of the app and webview, the title bar context menu upon right click, and the maximizing to fill the window and restoring the window size upon double click of the html element.

When set to `false`, then all non-client region support will be disabled. 
* Web pages will not be able to use the `app-region` CSS style.

# Examples
```cpp
wil::com_ptr<ICoreWebView2> webView;
void SettingsComponent::ToggleNonClientRegionSupportEnabled()
{
    // Get webView's current settings
    wil::com_ptr<ICoreWebView2Settings> coreWebView2Settings;
    CHECK_FAILURE(webView->get_Settings(&coreWebView2Settings));
    wil::com_ptr<ICoreWebView2Settings9> coreWebView2Settings9;
    coreWebView2Settings9 = coreWebView2Settings.try_query<ICoreWebView2Settings9>();
    if (coreWebView2Settings9)
    {
        BOOL enabled;
        CHECK_FAILURE(coreWebView2Settings9->get_IsNonClientRegionSupportEnabled(&enabled));
        CHECK_FAILURE(coreWebView2Settings9->put_IsNonClientRegionSupportEnabled(enabled ? FALSE : TRUE));
    }
}
```
```c#
private WebView2 _webView;
void ToggleNonClientRegionSupportEnabled()
{
    var coreWebView2Settings = _webView.CoreWebView2.Settings;
    coreWebView2Settings.IsNonClientRegionSupportEnabled = !coreWebView2Settings.IsNonClientRegionSupportEnabled;
}
```

# Remarks
If the flag is used to enable draggable regions in additional browser arguments, draggable region support will remain enabled even if `IsNonClientRegionSupportEnabled` setting is `false`.

# API Notes
See [API Details](#api-details) section below for API reference.

## Declaring Non-client App Regions
Non-client regions are HTML elements that are marked with the css style `app-region`.
* Draggable regions can be declared through the values `drag` or `no-drag`.  

# API Details
```cpp
/// This is the ICoreWebView2Settings Staging interface.
[uuid(436CA5E2-2D50-43C7-9735-E760F299439E), object, pointer_default(unique)]
interface ICoreWebView2Settings9 : ICoreWebView2Settings8 {
  /// `IsNonClientRegionSupportEnabled` property enables web pages to use the 
  /// `app-region` CSS style. Disabling/Enabling the `IsNonClientRegionSupportEnabled`
  /// takes effect after the next navigation. Defaults to `FALSE`.
  /// 
  /// When this property is `TRUE`, then all the following non-client region support 
  /// will be enabled:
  /// 1. Draggable Regions will be enabled and treated as a window's title bar. 
  /// Draggable Regions are non-client regions on a webpage that are exposed through the css
  /// attribute `app-region` and can take the values `drag` or `no-drag`. When set to 
  /// `drag`, these regions will be treated like the window's title bar, supporting 
  /// dragging of the entire WebView and its host app window, the title bar context menu
  /// upon right click, and the maximizing to fill the window and restoring the window size
  /// upon double click of the html element. 
  /// Draggable region support will be enabled if either the `IsNonClientRegionSupportEnabled`
  /// property or the flag is used in additional browser arguments (See put_AdditionalBrowserArguments).
  ///
  /// When set to `FALSE`, then all non-client region support will be disabled. Web
  /// pages will not be able to use the `app-region` CSS style.
  [propget] HRESULT IsNonClientRegionSupportEnabled([out, retval] BOOL* enabled);
  /// Set the IsNonClientRegionSupportEnabled property
  [propput] HRESULT IsNonClientRegionSupportEnabled([in] BOOL enabled);
}
```

# Appendix
We considered implementing the APIs in the ControllerOptions class, which would establish whether non-client regions would be supported for the life of the webview at creation. To provide greater flexibility of use, we decided to implement it as a setting.
