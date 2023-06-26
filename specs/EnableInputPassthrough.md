# Background
WebView2 .NET developers often encounter issues where certain default events are not raised in the WebView2 .NET control. This issue occurs because user inputs are directly delivered to the browser, and the host application does not receive the corresponding messages. This causes some default event handling API of .NET control not to work, such as PreProcessMessage and ProcessCmdKey in WinForms. It also prevents some keys from reaching Key Event realated APIs such as OnKeyDown and ToolStripMenuItem. In order to solve this type of issue, we provide an api which allows user inputs pass through the browser to the host app.

# Description
`EnableInputPassthrough` allows user input to pass through the browser and allows inputs received in the host app process. The messages can be received by Win32 API ::GetMessage() or ::PeekMessage(). This provides the host app a chance to handle the message before dispatching to the WebView2 HWND.
Different from visual hosting, user inputs are dispatched to the HWND owned by CoreWebView2Controller using EnableInputPassthrough, it is not required for developers to send user inputs from the app to the WebView2 control. It is not expected to use EnableInputPassthrough together with visual hosting.

# Examples
## Win32 C++
```cpp
HRESULT AppWindow::CreateControllerWithInputPassthrough()
{
      //! [CreateControllerWithOptions]
    auto webViewEnvironment10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
    if (!webViewEnvironment10)
    {
        FeatureNotAvailable();
        return S_OK;
    }

    wil::com_ptr<ICoreWebView2ControllerOptions> options;
    // The validation of parameters occurs when setting the properties.
    HRESULT hr = webViewEnvironment4->CreateCoreWebView2ControllerOptions(options.GetAddressOf());
    if (hr == E_INVALIDARG)
    {
        ShowFailure(hr, L"Unable to create WebView2 due to an invalid profile name.");
        CloseAppWindow();
        return S_OK;
    }
    CHECK_FAILURE(hr);

    wil::com_ptr<ICoreWebView2ControllerOptions3> webView2ControllerOptions3;
    if (SUCCEEDED(options->QueryInterface(IID_PPV_ARGS(&webView2ControllerOptions3))))
    {
        CHECK_FAILURE(webView2ControllerOptions3->put_EnableInputPassthrough(TRUE));
    }

    CHECK_FAILURE(webViewEnvironment10->CreateCoreWebView2ControllerWithOptions(
        m_mainWindow, options.get(),
        Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
            this, &AppWindow::OnCreateCoreWebView2ControllerCompleted)
            .Get()));

    return S_OK;
}
```

### .NET, WinRT
```c#
CoreWebView2Environment _webViewEnvironment;
WebViewCreationOptions _creationOptions;
public CreateWebView2Controller(IntPtr parentWindow)
{
    CoreWebView2ControllerOptions controllerOptions = new CoreWebView2ControllerOptions();
    controllerOptions.EnableInputPassthrough = _creationOptions.EnableInputPassthrough;

    CoreWebView2Controller controller = null;

    if (_creationOptions.entry == WebViewCreateEntry.CREATE_WITH_OPTION)
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow, options);
    }
    else
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow);
    }

    //...
}
```

# API Details
## Win32 C++
```IDL
interface ICoreWebView2StagingControllerOptions;

interface ICoreWebView2StagingControllerOptions : IUnknown {
  /// `EnableInputPassthrough` property is to enable/disable input passing through
  /// the app before being delivered to the WebView2.
  [propget] HRESULT EnableInputPassthrough([out, retval] BOOL* value);
  /// Sets the `EnableInputPassthrough` property.
  [propput] HRESULT EnableInputPassthrough([in] BOOL value);
}
```

## .NET, WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ControllerOptions;
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2;
    runtimeclass CoreWebView2Profile;

    runtimeclass CoreWebView2ControllerOptions
    {
        // ...

        Boolean EnableInputPassthrough { get; set; };
    }
}
```
