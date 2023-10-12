Custom Scrollbar 
===

# Background
Developers would like to be able to set the scrollbar to Windows overlay style and match the Windows theme, but browser flags keep changing and are not reliable. Thus we want to provide an extendable API that's allow developers to define a scrollbar style in their app.

# Examples
## WinRT and .NET   
```c#
/// Create WebView Environment with option
async void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.CustomScrollbarStyle = COREWEBVIEW2_SCROLLBAR_WIN_FLUENT_OVERLAY_STYLE;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(options: options);
    webview.EnsureCoreWebView2Async(environment);
}
```

## Win32 C++
```cpp
void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    COREWEBVIEW2_SCROLLBAR_STYLE style = COREWEBVIEW2_SCROLLBAR_WIN_FLUENT_OVERLAY_STYLE;
    CHECK_FAILURE(options->SetCustomScrollbarStyle(styles));

    // ... other option properties

    // ... CreateCoreWebView2EnvironmentWithOptions
}
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++

```IDL
interface ICoreWebView2EnvironmentOptions7;

[v1_enum]
typedef enum COREWEBVIEW2_SCROLLBAR_STYLE {
  /// Browser default style
  COREWEBVIEW2_SCROLLBAR_BROWSER_DEFAULT,
  /// Window Style fluent overlay scroll bar
  COREWEBVIEW2_SCROLLBAR_STYLE_WINDOWS_FLUENT_OVERLAY
} COREWEBVIEW2_SCROLLBAR_STYLE;

/// Additional options used to create WebView2 Environment.
[uuid(9c8ac95a-6b5f-4efb-b5f6-98bb33469759), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions7 : ICoreWebView2EnvironmentOptions6 
  /// Customzied scrollbar style being set on the WebView2 Environment
  HRESULT GetCustomScrollbarStyle([out] COREWEBVIEW2_SCROLLBAR_STYLE* value);
  
  /// Set the custom scrollbar style to be used. Default to be `COREWEBVIEW2_SCROLLBAR_BROWSER_DEFAULT`
  /// that matches the default browser scrollbar style.
  HRESULT SetCustomScrollbarStyle([in] COREWEBVIEW2_SCROLLBAR_STYLE value);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{

    enum CoreWebView2CustomScrollbarStyle
    {
        Default = 0,
        WindowOverlay = 1,
    };
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions7")]
        {
            // Set custom scrollbar style
            CoreWebView2CustomScrollbarStyle CustomScrollbarStyle { get; set; };
        }
    }

    // ...
}
```