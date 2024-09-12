WebView2 Window Controls
===

# Background
This API allows you to Enable and configure The Webview2 Window Controls overlay.
The Overlay is a region on the top right/left of the webview window which contains 
the caption buttons (minimize, maximize, restore, close). Enabing the Overlay allows
for custom app title bars rendered completly inside the webview window.
The overlay Settings lives on the controller object.

This API is designed to be used in addition with the other non-client region APIs 
and features. These include `app-region: drag`, and `IsNonClientRegionSupportEnabled`.
# Examples

## Win32 C++
```cpp 
AppWindow::AppWindow() {
    m_mainWindow = CreateWindowExW(
        WS_EX_CONTROLPARENT, 
        GetWindowClass(),
        L""
        WS_POPUPWINDOW, 
        0,0, 800, 800, 
        nullptr, nullptr, 
        g_hInstance, nullptr);
}

void  AppWindow::OnCreateWebview2ControllerCompleted(HRESULT hr, ICoreWebview2Controller* controller) 
{
    wil::com_ptr<ICoreWebView2Controller5> controller5;
    CHECK_FAILURE(controller->QueryInterface(&controller5));

    wil::com_ptr<ICoreWebView2WindowControlsOverlaySettings> wco_config;
    CHECK_FAILURE(controller5->get_WindowControlsOverlaySettings(&wco_config));

    wco_config->put_IsEnabled(true);
    COREWEBVIEW2_COLOR color {1, 0, 0, 225};
    wco_config->put_TitleBarColor(color);
}
```
## .NET C#
```c#
// WebView2 control is defined in the xaml
// <wv2:WebView2 x:Name="webView" Source="https://www.microsoft.com/"/>
public MainWindow() 
{
    InitializeComponent();
    m_AppWindow.TitleBar.ExtendsContentIntoTitleBar = true;

    CoreWebView2WindowControlsOverlaySettings config = _coreWebView2Controller.WindowControlsOverlaySettings;
    config.IsEnabled = true; 
    config.color = Color.FromARGB(0, 0, 255);
}
```

# API Details
## Win32 C++
```cpp
/// Controller API used to configure the window controls overlay.
/// To provide your app users with the best experience, it is important to handle webview 
/// initialization errors appropriatly. Provide your users with a way to close the window
/// or restart the App.
[uuid(101e36ca-7f75-5105-b9be-fea2ba61a2fd), object, pointer_default(unique)]
interface ICoreWebView2Controller5 : IUnknown {
  /// Gets the `WindowControlsOverlaySettings` object.
  [propget] HRESULT WindowControlsOverlaySettings([out, retval] ICoreWebView2WindowControlsOverlaySettings** value);
}

/// This is the ICoreWebView2WindowControlsOverlaySettings
[uuid(c9f7378b-8dbb-5445-bacb-08a3fdf032f0), object, pointer_default(unique)]
interface ICoreWebView2WindowControlsOverlaySettings : IUnknown {
    /// Gets the `Height` property.
  [propget] HRESULT Height([out, retval] UINT32* value);


  /// The `Height` property in pixels, allows you to set the height of the overlay and
  /// title bar area. Defaults to 48px. 
  /// 
  [propput] HRESULT Height([in] UINT32 value);


  /// Gets the `IsEnabled` property.
  [propget] HRESULT IsEnabled([out, retval] BOOL* value);


  /// The `IsEnabled` property allows you to opt in to using
  /// the WebView2 window controls overlay. Defaults to `FALSE`.
  /// 
  /// When this property is `TRUE`, WebView2 will draw its own minimize, maximize,
  /// and close buttons on the top right corner of the Webview2. 
  /// 
  /// When using this you should configure your app window to not display its default
  /// window control buttons. You are responsible for creating a title bar for your app
  /// by using the available space to the left of the controls overlay. In doing so, 
  /// you can utilize the [IsNonClientRegionSupportEnabled](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2settings9?view=webview2-1.0.2739.15)
  /// API to enable draggable regions for your custom title bar.
  /// 
  /// The Overlay buttons will sit on top of the HTML content, and will prevent mouse interactions
  /// with any elements directly below it, so you should avoid placing content there. 
  /// To that end, there are four CSS environment vairables defined to help you 
  /// get the dimensions of the available titlebar area to the left of the overlay.
  /// Similarly the navigator object wil contain a  WindowControlsOverlay property
  /// which can be used to get the titlebar area as a rect, and listen for changes
  /// to the size of that area.
  /// 
  [propput] HRESULT IsEnabled([in] BOOL value);

  /// Gets the `TitleBarColor` property.
  [propget] HRESULT TitleBarColor([out, retval] COREWEBVIEW2_COLOR* value);

  /// The `TitleBarColor` property allows you to set a background color
  /// for the overlay. Based on the background color you choose, Webview2 
  ///will automatically calculate a foreground and hover color that will
  /// provide you the best contrast while maintaining accessibility.
  /// Defaults to #f3f3f3
  [propput] HRESULT TitleBarColor([in] COREWEBVIEW2_COLOR value);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Controller
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Controller")]
        {
            CoreWebView2WindowControlsOverlaySettings WindowControlsOverlaySettings { get; };
        }
    }

    runtimeclass CoreWebView2WindowControlsOverlaySettings
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2WindowControlsOverlaySettings")]
        {
            Boolean IsEnabled { get; set; };
            UInt32 Height { get; set; };
            System.Drawing.Color TitleBarColor { get; set; }
        }
    }
}
```
