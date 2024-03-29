# Background

To improve the developer experience for customizing non-client regions, WebView2 is 
working to support using DOM elements as non-client regions. We currently have limited 
support for custom title bars aka draggable regions and are working on building out support 
for caption controls and resize regions. 

For security and flexibility, we want developers to be able to enable or disable all 
custom non-client functionality per WebView. Non-client functionality will affect that 
app window’s size and position so it’s important that developers can definitively 
toggle access. This can be achieved in a limited way using a feature flag, but feature 
flags are applied per WebView2 environment, thus, an API on the WebView2 to enable/disable 
non-client support via a setting is the better solution.

# Description
`IsNonClientRegionSupportEnabled` defaults to `FALSE`. Disabling/Enabling 
`IsNonClientRegionSupportEnabled` takes effect after the next navigation. Currently, draggable 
regions is the only non-client experience we have implemented. Eventually, this setting will 
expand to enable other non-client functionality, such as resize and caption controls. 

When the setting is set to `TRUE`, then the following non-client region support for only the top 
level document will be enabled:  
* Web pages will be able to use the `app-region` CSS style. 
* Draggable Regions declared with the CSS style `app-region: drag` will support title bar 
functionality, for example, the dragging of the app window, the title bar context menu upon 
right click, and the maximizing/restoring of the window size upon double click of the html 
element. 

When set to `FALSE`, then all non-client region support will be disabled.  
* Web pages will not be able to use the `app-region` CSS style. 

# Examples
This example enables non-client region support for all pages on www.microsoft.com. 
Pages on other origins will not have non-client region support enabled. 

## Win32 C++
```cpp 
ScenarioNonClientRegionSupport::ScenarioNonClientRegionSupport(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    
    CHECK_FAILURE(m_webView->add_NavigationStarting(
        Callback<ICoreWebView2NavigationStartingEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT
            {
                static const PCWSTR allowedHostName = L"www.microsoft.com";
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_Uri(&uri));
                wil::unique_bstr domain = GetDomainOfUri(uri.get());
                
                wil::com_ptr<ICoreWebView2Settings> m_settings;
                CHECK_FAILURE(m_webView->get_Settings(&m_settings));
                wil::com_ptr<ICoreWebView2Settings12> coreWebView2Settings12;
                coreWebView2Settings12 = m_settings.try_query<ICoreWebView2Settings12>();
                CHECK_FEATURE_RETURN(coreWebView2Settings12);
                
                bool trusted = _wcsicmp(domain.get(), allowedHostName) == 0;
                // This change will take affect after this navitation event completes
                CHECK_FAILURE(coreWebView2Settings12->put_IsNonClientRegionSupportEnabled(trusted));
                
                return S_OK;
            })
            .Get(),
        &m_navigationStartingToken));
}
```
## .NET C#
```c#
// WebView2 control is defined in the xaml
// <wv2:WebView2 x:Name="webView" Source="https://www.microsoft.com/"/>
public MainWindow() 
{
    InitializeComponent();
    webView.NavigationStarting += SetNonClientRegionSupport;
}

private void SetNonClientRegionSupport(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs args)
{
    var coreWebView2Settings = webView.CoreWebView2.Settings;
    var urlCompareExample = "www.microsoft.com";
    var uri = new Uri(args.Uri);

    bool trusted = String.Equals(uri.Host, urlCompareExample, StringComparison.OrdinalIgnoreCase);
    coreWebView2Settings.IsNonClientRegionSupportEnabled = trusted
}
```

## Declaring Non-client App Regions
The value of the app-region CSS property can be used to indicate which HTML elements are treated as non-client regions.
* Draggable regions can be controlled through the values `drag` or `no-drag`. 
    * `app-region: drag` will support [draggable region functionality](#description) for the html element.
    * `app-region: no-drag` will unmark the html element as a drag region, reverting it to all it's default behaviors. 
    The app-region CSS property inherits. The initial value is no-drag
```html
<!DOCTYPE html>
<body>
    <div style="app-region:drag">
        Drag Region
        <div style="app-region:no-drag">No-drag Region</div>
    </div>
</body>
<html>
```

# Remarks
If the feature flag (`msWebView2EnableDraggableRegions`) is used to enable the CSS style `app-region`'s
values `drag` and `no-drag`, draggable region support will remain enabled 
even if the `IsNonClientRegionSupportEnabled` setting is `FALSE`. 
* Note: The feature flag is experimental and should not be used in production.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++
```cpp

[uuid(436CA5E2-2D50-43C7-9735-E760F299439E), object, pointer_default(unique)]
interface ICoreWebView2Settings12 : ICoreWebView2Settings11 {
  /// The `IsNonClientRegionSupportEnabled` property enables web pages to use the 
  /// `app-region` CSS style. Changing the `IsNonClientRegionSupportEnabled` property
  /// take effect at the completion of the NavigationStarting event for the next 
  /// top-level navigation. Defaults to `FALSE`.
  /// 
  /// When this property is `TRUE`, then all the following non-client region support 
  /// will be enabled:
  /// 1. Draggable Regions will be enabled and treated as a window's title bar. 
  /// Draggable Regions are regions on a webpage that are exposed through the css
  /// attribute `app-region` with the value `drag`. When set to 
  /// `drag`, these regions will be treated like the window's title bar, supporting 
  /// dragging of the entire WebView and its host app window, the title bar context menu
  /// upon right click, and the maximizing to fill the window and restoring the window size
  /// upon double click of the html element. 
  ///
  /// When set to `FALSE`, values of the `app-region` CSS style will be ignored. The only 
  /// exception is `app-region: drag` when the feature flag (msWebView2EnableDraggableRegions) 
  /// is enabled. 
  [propget] HRESULT IsNonClientRegionSupportEnabled([out, retval] BOOL* value);
  /// Set the IsNonClientRegionSupportEnabled property
  [propput] HRESULT IsNonClientRegionSupportEnabled([in] BOOL value);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings12")]
        {
            Boolean IsNonClientRegionSupportEnabled { get; set; };
        }
    }
}
```

# Appendix
We considered implementing the APIs in the ControllerOptions class, which would establish 
whether non-client regions would be supported for the life of the webview at creation. To 
provide greater flexibility of use, we decided to implement it as a setting.
