WebView2 Window Controls
===

# Background
This API allows you to enable and configure the Webview2 Window Controls Overlay.
The Overlay is a region on the top right/left of the webview window which contains 
the caption buttons (minimize, maximize, restore, close). Enabling the Overlay allows
for custom app title bars rendered completely inside the webview window.

This API is designed to be used in addition with the other non-client region APIs 
and features. These include `app-region: drag`, and `IsNonClientRegionSupportEnabled`.

# Conceptual pages (How To)
Here is a concept doc on the window controls overlay: https://wicg.github.io/window-controls-overlay/#concepts. 
This was written for the PWA counterpart  for this feature. From the perspective of
HTML & Javascript layers, everything there applies in Webview2 as well.

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

    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(m_controller->get_CoreWebView2(&coreWebView2));

    wil::com_ptr<ICoreWebView2> coreWebView2_28;
    CHECK_FAILURE(coreWebView2->QueryInterface(&coreWebView2_28));

    wil::com_ptr<ICoreWebView2WindowControlsOverlay> windowControlsOverlay;
    CHECK_FAILURE(coreWebView2_28->get_WindowControlsOverlay(&windowControlsOverlay));

    CHECK_FAILURE(windowControlsOverlay->put_IsVisible(true));
    COREWEBVIEW2_COLOR color {1, 0, 0, 225};
    CHECK_FAILURE(windowControlsOverlay->put_BackgroundColor(color));
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

    CoreWebView2WindowControlsOverlay config = Webview2.CoreWebView2.WindowControlsOverlay;
    config.IsVisible = true; 
    config.Color = Color.FromARGB(0, 0, 255);
}
```

# API Details
## Win32 C++
```cpp
/// Controller API used to configure the window controls overlay.
/// To provide your app users with the best experience, it is important to handle webview 
/// initialization errors appropriately. Provide your users with a way to close the window
/// or restart the App.
[uuid(101e36ca-7f75-5105-b9be-fea2ba61a2fd), object, pointer_default(unique)]
interface ICoreWebView2_28 : IUnknown {
  /// Gets the `WindowControlsOverlay` object.
  [propget] HRESULT WindowControlsOverlay([out, retval] ICoreWebView2WindowControlsOverlay** value);
}

/// This is the ICoreWebView2WindowControlsOverlay
[uuid(c9f7378b-8dbb-5445-bacb-08a3fdf032f0), object, pointer_default(unique)]
interface ICoreWebView2WindowControlsOverlay : IUnknown {
    /// Gets the `Height` property.
  [propget] HRESULT Height([out, retval] UINT32* value);


  /// The `Height` property in raw screen pixels, allows you to set the height of the overlay and
  /// title bar area. Defaults to 48px. There is no minimum height restriction for this API,
  /// so it is up to the developer to make sure that the height of your window controls overlay
  /// is enough that users can see and interact with it. We recommend using GetSystemMetrics(SM_CYCAPTION)
  // as your minimum height.
  /// 
  [propput] HRESULT Height([in] UINT32 value);


  /// Gets the `IsVisible` property.
  [propget] HRESULT IsVisible([out, retval] BOOL* value);


  /// The `IsVisible` property allows you to opt in to using
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
  /// The Overlay buttons will cover the HTML content, and will prevent mouse interactions
  /// with any elements directly below it, so you should avoid placing content there. 
  /// To that end, there are four [CSS environment variables](https://developer.mozilla.org/en-US/docs/Web/API/Window_Controls_Overlay_API#css_environment_variables) 
  /// titlebar-area-x, titlebar-area-y, titlebar-area-width, titlebar-area-height defined to help you 
  /// get the dimensions of the available titlebar area to the left of the overlay.
  /// Similarly the navigator object will contain a [WindowControlsOverlay property](https://developer.mozilla.org/en-US/docs/Web/API/WindowControlsOverlay)
  /// which can be used to get the titlebar area as a rect, and listen for changes
  /// to the size of that area.
  ///
  [propput] HRESULT IsVisible([in] BOOL value);

  /// Gets the `BackgroundColor` property.
  [propget] HRESULT BackgroundColor([out, retval] COREWEBVIEW2_COLOR* value);

  /// The `BackgroundColor` property allows you to set a background color
  /// for the overlay. Based on the background color you choose, Webview2 
  /// will automatically calculate a foreground and hover color.
  /// Defaults to #f3f3f3. This API supports transparency.
  [propput] HRESULT BackgroundColor([in] COREWEBVIEW2_COLOR value);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_28")]
        {
            CoreWebView2WindowControlsOverlay WindowControlsOverlay { get; };
        }
    }

    runtimeclass CoreWebView2WindowControlsOverlay
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2WindowControlsOverlay")]
        {
            Boolean IsVisible { get; set; };
            UInt32 Height { get; set; };
            Windows.UI.Color BackgroundColor { get; set; }
        }
    }
}
```

