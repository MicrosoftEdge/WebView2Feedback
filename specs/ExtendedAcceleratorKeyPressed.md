# Background
WebView2 has `ICoreWebView2AcceleratorKeyPressedEventArgs` for the 
`CoreWebView2Controller.AcceleratorKeyPressed` event. We have been asked to extend this API so
that developers can indicate that theywould like an existing browser accelerator key to be 
disabled as a browser accelerator.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending the `ICoreWebView2AcceleratorKeyPressedEventArgs` to allow developers
to enable/disable the browser from handling accelerator keys with `AllowBrowserAcceleratorHandling` 
property. 

# Examples
## C++

``` cpp
    EventRegistrationToken m_acceleratorKeyPressedToken = {};

    wil::com_ptr<ICoreWebView2Controller> m_controller;
    wil::com_ptr<ICoreWebView2> m_webView;
    wil::com_ptr<ICoreWebView2Settings3> m_settings3;

  {
        wil::com_ptr<ICoreWebView2Settings> settings;
        CHECK_FAILURE(m_webView->get_Settings(&settings));
        m_settings3 = settings.try_query<ICoreWebView2Settings3>();
        if (m_setting3) 
        {
            // Disable all browser accelerator keys. The default value for the 
            // `AllowBrowserAcceleratorHandling` property is set to the current value of this 
            // setting. Changing this setting to `false` will change the default setting for 
            // AllowBrowserAcceleratorHandling to `false`.
            CHECK_FAILURE(m_settings3->put_AreBrowserAcceleratorKeysEnabled(FALSE));
            // Register a handler for the CoreWebView2Controller.AcceleratorKeyPressed event.
            CHECK_FAILURE(m_controller->add_AcceleratorKeyPressed(
                Callback<ICoreWebView2AcceleratorKeyPressedEventHandler>(
                    [this](
                        ICoreWebView2Controller* sender,
                        ICoreWebView2AcceleratorKeyPressedEventArgs* args) -> HRESULT
                    {
                        COREWEBVIEW2_KEY_EVENT_KIND kind;
                        CHECK_FAILURE(args->get_KeyEventKind(&kind));
                        // We only care about key down events.
                        if (kind == COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN ||
                            kind == COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN)
                        {
                            UINT key;
                            CHECK_FAILURE(args->get_VirtualKey(&key));

                            wil::com_ptr<ICoreWebView2AcceleratorKeyPressedEventArgs2>
                                args2;

                            args->QueryInterface(IID_PPV_ARGS(&args2));
                            if (args) 
                            {
                                if (key == VK_F7)
                                {
                                    // Allow the browser to process F7 key
                                    CHECK_FAILURE(args2->put_AllowBrowserAcceleratorHandling(TRUE));
                                }
                            }
                        }
                        return S_OK;
                    })
                    .Get(),
                &m_acceleratorKeyPressedToken));

        }
    }
```

## C#
```c#
    CoreWebView2Settings _webViewSettings = webView.CoreWebView2.Settings;
    // All browser accelerator keys are disabled with this setting. The default value for the 
    // `AllowBrowserAcceleratorHandling`property is set to the current value of this setting. 
    // Changing this setting to `false` will change the default setting for 
    // AllowBrowserAcceleratorHandling to `false`
    _webViewSettings.AreBrowserAcceleratorKeysEnabled = false;

    webView.CoreWebView2.AcceleratorKeyPressed += WebView2Controller_AcceleratorKeyPressed;

    void WebView2Controller_AcceleratorKeyPressed(object sender, CoreWebView2AcceleratorKeyPressedEventArgs e)
    {
        switch (e.KeyEventKind)
        {
            case CoreWebView2KeyEventKind.KeyDown:
            case CoreWebView2KeyEventKind.SystemKeyDown:
                {
                    // Allow the browser to process F7 key
                    if (e.VirtualKey == Key.F7) 
                    {
                        e.AllowBrowserAcceleratorHandling = true;
                    }
                    break;
                }
            
        }
    }

```

# Remarks
By default, `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` is `TRUE` and default value for
`AllowBrowserAcceleratorHandling` is `TRUE`. When developers set  
`CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` to `FALSE` this will also change the default 
value for `AllowBrowserAcceleratorHandling` to `FALSE`. If developers want specific keys to be handled 
by the browser after changing the `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` settings to 
`FALSE`, they need to enable them by setting `event_args->put_ AllowBrowserAcceleratorHandling(TRUE)`. 
This option will give the event arg higher priority over the settings when the browser decide whether 
to handle the keys.  

# API Details
## C++
```
/// This is a continuation of the ICoreWebView2AcceleratorKeyPressedEventArgs interface.
[uuid(45238725-3774-4cfe-931f-7985a1b5866f), object, pointer_default(unique)]
interface ICoreWebView2AcceleratorKeyPressedEventArgs2 : ICoreWebView2AcceleratorKeyPressedEventArgs {
  /// This property allows developers to enable or disable the browser from handling a specific 
  /// browser accelerator key such as Ctrl+P or F3, etc.
  ///
  /// Browser accelerator keys are the keys/key combinations that access features specific to 
  /// a web browser, including but not limited to:
  ///  - Ctrl-F and F3 for Find on Page
  ///  - Ctrl-P for Print
  ///  - Ctrl-R and F5 for Reload
  ///  - Ctrl-Plus and Ctrl-Minus for zooming
  ///  - Ctrl-Shift-C and F12 for DevTools
  ///  - Special keys for browser functions, such as Back, Forward, and Search
  ///
  /// This property does not disable accelerator keys related to movement and text editing,
  /// such as:
  ///  - Home, End, Page Up, and Page Down
  ///  - Ctrl-X, Ctrl-C, Ctrl-V
  ///  - Ctrl-A for Select All
  ///  - Ctrl-Z for Undo
  ///
  /// The exsiting `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` API is a convenience setting 
  /// for developers to disable all the browser accelerator keys together. This setting sets the default 
  /// value for the `AllowBrowserAcceleratorHandling` property. 
  /// By default, `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` is `TRUE` and  
  /// `AllowBrowserAcceleratorHandling` is `TRUE`. 
  /// When developers change `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` setting to `FALSE`,  
  /// this will change default value for `AllowBrowserAcceleratorHandling` to `FALSE`. 
  /// If developers want specific keys to be handled by the browser after changing the 
  /// `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` setting to `FALSE`, they need to enable  
  /// these keys by setting `AllowBrowserAcceleratorHandling` to `TRUE`.
  /// This API will give the event arg higher priority over the  
  /// `CoreWebView2Settings.AreBrowserAcceleratorKeysEnabled` setting when we handle the keys.
  ///
  /// For browser accelerator keys, when an accelerator key is pressed, the propagation and 
  /// processing order is: 
  /// - A CoreWebView2Controller.AcceleratorKeyPressed event is raised
  /// - WebView2 browser feature accelerator key handling
  /// - Web Content Handling: If the key combination isn't reserved for browser actions, 
  /// the key event propagates to the web content, where JavaScript event listeners can 
  /// capture and respond to it.
  /// 
  /// `ICoreWebView2AcceleratorKeyPressedEventArgs` has a `Handled` property, that developers
  /// can use to marked a key as handled. When the key is marked as handled anywhere along
  /// the path, the event propagtion stops, and web content will not receive the key.
  /// With `AllowBrowserAcceleratorHandling` property, when developers mark 
  /// `AllowBrowserAcceleratorHandling` as `FALSE`, the browser will skip the WebView2 
  /// browser feature accelerator key handling process, but the event propagation    
  /// continues, and web content will receive the key combination. 

  /// \snippet ScenarioAcceleratorKeyPressed.cpp
  /// Gets the `AllowBrowserAcceleratorHandling` property.
  [propget] HRESULT AllowBrowserAcceleratorHandling([out, retval] BOOL* value);

  /// Sets the `AllowBrowserAcceleratorHandling` property.
  [propput] HRESULT AllowBrowserAcceleratorHandling([in] BOOL value);
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2AcceleratorKeyPressedEventArgs
    {
        Boolean AllowBrowserAcceleratorHandling { get; set; };
    }

}
```
