CoreWebView2ControllerOptions.DefaultBackgroundColor
===
# Background
Previously, there was a fix to address an issue where the background color controller property was applied too late, causing a disruptive white flash during the WebView2 loading process.

This fix required using an environment variable. However, this workaround was not meant to be a long-term solution. Therefore, we need to add this setting to `ICoreWebView2ControllerOptions` to apply the color early in the loading process.

# Description

This interface extends the `ICoreWebView2ControllerOptions`  to expose the `DefaultBackgroundColor` property as an option.
The `CoreWebView2ControllerOptions.DefaultBackgroundColor` API  allows users to set the  `DefaultBackgroundColor` property at initialization.

This is particularly useful when setting it using the existing [`CoreWebView2Controller.DefaultBackgroundColor API`](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2controller.defaultbackgroundcolor?view=webview2-dotnet-1.0.2792.45) applies the color too late.




# Examples

## Win32 C++
```cpp
 HRESULT AppWindow::CreateControllerWithOptions()
{
    wil::com_ptr<ICoreWebView2ControllerOptions> options;
    HRESULT hr = m_environment->CreateCoreWebView2ControllerOptions(&options);

    wil::com_ptr<ICoreWebView2StagingControllerOptions> stagingOptions;
    auto result = options->QueryInterface(IID_PPV_ARGS(&stagingOptions));

    if (SUCCEEDED(result))
    {
        COREWEBVIEW2_COLOR wvColor{255, 223, 225, 225};
        stagingOptions->put_DefaultBackgroundColor(wvColor);

        m_environment->CreateCoreWebView2Controller(
            m_mainWindow, options.Get(),
            Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                this, &AppWindow::OnCreateCoreWebView2ControllerCompleted).Get());
    }

}
```





# API Details

## Win32 C++
 ```cpp
/// This interface extends the ICoreWebView2ControllerOptions interface to expose the DefaultBackgroundColor property.
/// It is encouraged to transition away from the environment variable and use this API solution to apply the property.

[uuid(df9cb70b-8d87-5bca-ae4b-6f23285e8d94), object, pointer_default(unique)]
interface ICoreWebView2ControllerOptions4 : IUnknown {
  
  /// This API allows users to initialize the `DefaultBackgroundColor` early,
  /// preventing a white flash that can happen while WebView2 is loading when
  /// the background color is set to something other than white. With early
  /// initialization, the color remains consistent from the start. After
  /// initialization, `ICoreWebView2Controller2::get_DefaultBackgroundColor`
  /// will return the value set using this API. For additional details, see
  /// `ICoreWebView2Controller2::put_DefaultBackgroundColor`.

  [propget] HRESULT DefaultBackgroundColor([out, retval] COREWEBVIEW2_COLOR* value);
  [propput] HRESULT DefaultBackgroundColor([in] COREWEBVIEW2_COLOR value);

}
```

```cpp
interface CoreWebView2ControllerOptions4
{
    // ..
    Windows.UI.Color DefaultBackgroundColor { get; set; };
}
```
