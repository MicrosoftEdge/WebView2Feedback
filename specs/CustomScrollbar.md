Custom ScrollBar Style
===

# Background
Developers would like to be able to set the ScrollBar to Windows fluent overlay style and 
match the Windows theme. Some customers have used browser flags but they change names and behavior and are not reliable. Thus we want
to provide an extendable API that allows developers to set ScrollBar style. Currently, 
only Windows fluent overlay are supported, adding new styles in the future will not introduce
any breaking changes.

# Examples
## WinRT and .NET   
```c#
// Create WebView Environment with option
async void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.ScrollBarStyle = ScrollBarStyle.FluentOverlay;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(options: options);
    webview.EnsureCoreWebView2Async(environment);
}
```

## Win32 C++
```cpp
void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    COREWEBVIEW2_SCROLLBAR_STYLE style = COREWEBVIEW2_SCROLLBAR_STYLE_FLUENT_OVERLAY;
    CHECK_FAILURE(options->put_ScrollBarStyle(style));

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
  /// Browser default ScrollBar style
  COREWEBVIEW2_SCROLLBAR_STYLE_DEFAULT,
  /// Window style fluent overlay scroll bar
  /// Please see [Fluent UI](https://developer.microsoft.com/en-us/fluentui#/)
  /// for more details on fluent UI.
  COREWEBVIEW2_SCROLLBAR_STYLE_FLUENT_OVERLAY
} COREWEBVIEW2_SCROLLBAR_STYLE;

/// Additional options used to create WebView2 Environment.
[uuid(9c8ac95a-6b5f-4efb-b5f6-98bb33469759), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions7 : ICoreWebView2EnvironmentOptions6 { 
  /// Get the ScrollBar style being set on the WebView2 Environment.
  [propget] HRESULT ScrollBarStyle([out, retval] COREWEBVIEW2_SCROLLBAR_STYLE* value);
  /// Set ScrollBar style to be used. The default is `COREWEBVIEW2_SCROLLBAR_STYLE_DEFAULT`
  /// which specifies the default browser ScrollBar style.
  /// CSS styles that modify the ScrollBar applied on top of native ScrollBar styling 
  /// that is selected with `ScrollBarStyle`.
  [propput] HRESULT ScrollBarStyle([in] COREWEBVIEW2_SCROLLBAR_STYLE value);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{

    enum ScrollBarStyle
    {
        Default = 0,
        FluentOverlay = 1,
    };
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions7")]
        {
            // Set ScrollBar style
            ScrollBarStyle ScrollBarStyle { get; set; };
        }
    }

    // ...
}
```