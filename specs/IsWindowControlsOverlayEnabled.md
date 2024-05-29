WebView2 Window Controls
===

# Background
The goal of this API is to provide devs with a cleaner way to build apps where
the entire Window UI is rendered by WebView2. Till now, it hasn't been possible 
for the window/caption control buttons (minimize, maximize, restore, close) to 
be rendered and controlled by the browser process. This API allows devs to tell
WebView2 that it should render its own window control buttons.

# Description
`IsWindowControlsOverlayEnabled` defaults to `FALSE`. Disabling/Enabling 
`IsWindowControlsOverlayEnabled` takes effect after the next navigation.

# Examples

## Win32 C++
```cpp 
void AppWindow::InitializeWebView()   
{

CreateCoreWebView2EnvironmentWithOptions(
    browserExecutableFolder, 
    userDataFolder, 
    corewebview2environmentoptions,
    Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
        this, 
        [this](HRESULT result, ICoreWebView2Environment* environment) -> {
            CHECK_FAILURE(hr);

            CHECK_FAILURE(m_webViewEnvironment->CreateCoreWebView2Controller(
            mainwindowhwnd, 
            Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        this, 
                        &AppWindow::OnCreateCoreWebView2ControllerCompleted).Get()));
        }).Get());
}

HRESULT AppWindow::OnCreateCoreWebView2ControllerCompleted(
    HRESULT result, ICoreWebView2Controller* controller)
{
    CHECK_FAILURE(hr);

    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(controller->get_CoreWebView2(&coreWebView2));

    wil::com_ptr<ICoreWebView2Settings> m_settings;
    CHECK_FAILURE(coreWebView2->get_Settings(&m_settings));

    wil::com_ptr<ICoreWebView2Settings12> coreWebView2Settings12;
    coreWebView2Settings12 = m_settings.try_query<ICoreWebView2Settings12>();
    CHECK_FEATURE_RETURN(coreWebView2Settings12);
    CHECK_FAILURE(coreWebView2Settings12->IsWindowControlsOverlayEnabled(true));
}
```
## .NET C#
```c#
// WebView2 control is defined in the xaml
// <wv2:WebView2 x:Name="webView" Source="https://www.microsoft.com/"/>
public MainWindow() 
{
    InitializeComponent();
    this.webView2Control.CoreWebView2InitializationCompleted 
    += WebView2InitializationCompleted;
}

private void WebView2InitializationCompleted(
    object sender, 
    CoreWebView2InitializationCompletedEventArgs e)
{
    if (!e.IsSuccess)
    {
    MessageBox.Show($"WebView2 creation failed with exception = {e.InitializationException}");

    return;
    }

    SetWindowControlsOverlaySupport(true);
}

private void SetWindowControlsOverlaySupport(bool enabled)
{
    var coreWebView2Settings = this.webView2Control.CoreWebView2.Settings;
    coreWebView2Settings.IsWindowControlsOverlayEnabled = enabled;
}
```

# API Details
## Win32 C++
```cpp
[uuid(436CA5E2-2D50-43C7-9735-E760F299439E), object, pointer_default(unique)]
interface ICoreWebView2Settings12 : ICoreWebView2Settings11 {
  /// Gets the `IsWindowControlsOverlayEnabled` property.
  [propget] HRESULT IsWindowControlsOverlayEnabled([out, retval] BOOL* value);


  /// The `IsWindowControlsOverlayEnabled` property allows devs to opt in/out of using
  /// the WV2 custom caption controls. Defaults to `FALSE`.
  /// 
  /// When this property is `TRUE`, WV2 will draw it's own caption controls on the
  /// top right corner of the window.
  /// 
  [propput] HRESULT IsWindowControlsOverlayEnabled([in] BOOL value);
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
            Boolean IsWindowControlsOverlayEnabled { get; set; };
        }
    }
}
```



# Appendix
To provide your app users with the best experience, it is important to handle webview 
initialization errors appropriatly. Provide your users with a way to close the window
or restart the App.
