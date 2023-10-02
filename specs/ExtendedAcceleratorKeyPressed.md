# Background
WebView2 has `ICoreWebView2AcceleratorKeyPressedEventArgs`  for the `AcceleratorKeyPressed` event. We has been asked extend this API so that developers can indicate that they would like an existing browser accelerator key to be disabled as a browser accelerator.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending the `ICoreWebView2AcceleratorKeyPressedEventArgs` to allow developers to enable/disable the browser from handling accelerator keys with `AllowBrowserHandle` property. 

# Examples
## C++: Get name of window

``` cpp
    EventRegistrationToken m_acceleratorKeyPressedStagingToken = {};

    wil::com_ptr<ICoreWebView2Controller> m_controller;
    wil::com_ptr<ICoreWebView2> m_webView;
    wil::com_ptr<ICoreWebView2Settings3> m_settings3;

  {
        wil::com_ptr<ICoreWebView2Settings> settings;
        CHECK_FAILURE(m_webView->get_Settings(&settings));
        m_settings3 = settings.try_query<ICoreWebView2Settings3>();
        if (m_setting3) {
            // Disable all browser accelerator keys
            CHECK_FAILURE(m_settings3->put_AreBrowserAcceleratorKeysEnabled(FALSE));
            // Register a handler for the AcceleratorKeyPressed event.
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

                            CHECK_FAILURE(args->QueryInterface(IID_PPV_ARGS(&args2)));
                            if (key == VK_F7)
                            {
                                // Allow the browser to process F7 key
                                CHECK_FAILURE(args2->put_AllowBrowserHandle(TRUE));
                            }
                        }
                        return S_OK;
                    })
                    .Get(),
                &m_acceleratorKeyPressedStagingToken));

        }
    }
```

## C#: Get name of window
```c#
    CoreWebView2Settings _webViewSettings = webView.CoreWebView2.Settings;
    // All browser accelerator keys are disabled with this setting
    _webViewSettings.AreBrowserAcceleratorKeysEnabled = false;

    webView.CoreWebView2.AcceleratorKeyPressed += WebView2Controller_AcceleratorKeyPressed;

    void WebView2Controller_AcceleratorKeyPressed(object sender, CoreWebView2AcceleratorKeyPressedEventArgs e)
    {
        switch (e.KeyEventKind)
        {
            case CoreWebView2KeyEventKind.KeyDown:
            case CoreWebView2KeyEventKind.SystemKeyDown:
                {
                    Keys keyData = (Keys)(e.VirtualKey);
                    // Allow the browser to process F7 key
                    if(e.VirtualKey == Key.F7) {
                        e.AllowBrowserHandle = true;
                    }
                    break;
                }
            
        }
    }

```

# Remarks
By default, `AreBrowserAcceleratorKeyEnabled` is `TRUE` and default value for `AllowBrowserHandle` is `TRUE`. When developers set `AreBrowserAcceleratorKeyEnabled` to `FALSE` this will also change the default value for `AllowBrowserHandle` to `FALSE`. If developers want specific keys to be handled by the browser after changing the `AreBrowserAcceleratorKeyEnabled` settings to `FALSE`, they need to enable them by setting `event_args->put_ AllowBrowserHandle(TRUE)`. This option will give the event arg higher priority over the settings when the browser decide whether to handle the keys.  

# API Details
## C++
```
/// This is This is a continuation of the ICoreWebView2AcceleratorKeyPressedEventArgs interface.
[uuid(45238725-3774-4cfe-931f-7985a1b5866f), object, pointer_default(unique)]
interface ICoreWebView2AcceleratorKeyPressedEventArgs2 : ICoreWebView2AcceleratorKeyPressedEventArgs {
  /// These APIs allow devs to enable/disable the browser from handling specific accelerator keys.
  /// By default, `AreBrowserAcceleratorKeyEnabled` is `TRUE` and `AllowBrowserHandle` is `TRUE`.
  /// When devs set `AreBrowserAcceleratorKeyEnabled` to `FALSE` this will override and the
  /// default value for `AllowBrowserHandle` will be `FALSE` and prevent the browser to handle
  /// accelerator keys. If users want specific keys to be handled by the browser after changing
  /// the settings to `FALSE`, they need to enable them by setting `AllowBrowserHandle` to `TRUE`.
  /// This option will give the event arg higher priority over the `AreBrowserAcceleratorKeyEnabled`
  /// settings when we handle the keys.
  ///
  /// \snippet ScenarioAcceleratorKeyPressed.cpp
  /// Gets the `AllowBrowserHandle` property.
  [propget] HRESULT AllowBrowserHandle([out, retval] BOOL* allowed);

  /// Sets the `AllowBrowserHandle` property.
  [propput] HRESULT AllowBrowserHandle([in] BOOL allowed);
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2AcceleratorKeyPressedEventArgs
    {
        Boolean AllowBrowserHandle { get; set; };
    }

}
```
