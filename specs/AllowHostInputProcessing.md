# Background
WebView2 .NET developers often encounter issues where certain default events are not raised in the WebView2 .NET control. 
This issue occurs because user inputs are directly delivered to the browser, and the host application does not receive the corresponding messages. 
This causes some default event handling API of .NET control not to work, such as PreProcessMessage and ProcessCmdKey in WinForms.
It also prevents some keys from reaching Key Event realated APIs such as OnKeyDown and ToolStripMenuItem.
In order to solve this type of issue, we provide an api which allows user inputs pass through the browser to the host app.

# Description
`AllowHostInputProcessing` allows user input messages to pass through the browser window to be received by an app process window.
The messages can be received by Win32 API ::GetMessage() or ::PeekMessage(). This provides the host app a chance to handle the message before dispatching to the WebView2 HWND.
If the host app does not handle input, it is forwarded to the browser process on the user's behalf. This API does not introduce any requirement for the developer to forward all input as is the case with visual hosting. This API should not be used with visual hosting, and has no effect when using  CreateCoreWebView2CompositionControllerWithOptions to create the controller.

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
    CHECK_FAILURE(webViewEnvironment4->CreateCoreWebView2ControllerOptions(options.GetAddressOf()));

    wil::com_ptr<ICoreWebView2ControllerOptions3> webView2ControllerOptions3;
    if (SUCCEEDED(options->QueryInterface(IID_PPV_ARGS(&webView2ControllerOptions3))))
    {
        CHECK_FAILURE(webView2ControllerOptions3->put_AllowHostInputProcessing(TRUE));
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
    controllerOptions.AllowHostInputProcessing = _creationOptions.AllowHostInputProcessing;

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
  /// `AllowHostInputProcessing` property is to enable/disable input passing through
  /// the app before being delivered to the WebView2. This property is only applicable
  /// to windowed hosting.
  /// By default the value is `FALSE`.
  [propget] HRESULT AllowHostInputProcessing([out, retval] BOOL* value);
  /// Sets the `AllowHostInputProcessing` property.
  /// Setting this property has no effect when using visual hosting.
  [propput] HRESULT AllowHostInputProcessing([in] BOOL value);
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

        Boolean AllowHostInputProcessing { get; set; };
    }
}
```
