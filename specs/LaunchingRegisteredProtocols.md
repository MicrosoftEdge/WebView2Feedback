# Background

We are exposing an event that will be raised when an attempt to launch an external protocol is made. The host will be given the option to cancel the launch, hide the dialog, as well as disable the checkbox that, if selected, will give permissions to always allow the launch.

# Description

This event will be raised before the external protocol launch occurs. Currently a dialog is displayed in which the user can click `Open` or `Cancel`. If the request is made from a [trustworthy origin](https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-origin) a checkmark box will be displayed that will allow the user to always allow this external protocol from this origin. The `NavigationStarting`, `NavigationCompleted`, `SourceChanged`, `ContentLoading`, and `HistoryChanged` events will not be raised when a request is made to launch an external protocol.

The `LaunchingExternalProtocol` event will be raised on either `CoreWebView2` or `CoreWebView2Frame` depending on if the launch request is originating from the main frame or a non-main frame. In the case of a nested iframe requesting the external protocol launch, the event will be raised from the top level iframe.
# Examples

## Win32 C++
    
```cpp 

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
EventRegistrationToken m_launchingExternalProtocolToken = {};
EventRegistrationToken m_frameLaunchingExternalProtocolToken = {};
EventRegistrationToken m_frameCreatedToken = {};

void RegisterLaunchingExternalProtocolHandler()
{
    auto webView5 = m_webView.try_query<ICoreWebView2_5>();
    if (webView5)
    {
        CHECK_FAILURE(webView5->add_LaunchingExternalProtocol(
            Callback<ICoreWebView2LaunchingExternalProtocolEventHandler>(
                [this](
                    ICoreWebView2* sender,
                    ICoreWebView2LaunchingExternalProtocolEventArgs* args) {
                        wil::unique_cotaskmem_string uri;
                        CHECK_FAILURE(args->get_Uri(&uri));
                        if (wcsicmp(uri.get(), L"calculator://") == 0)
                        {
                            CHECK_FAILURE(args->put_Handled(TRUE));
                            // If this matches our desired protocol, then suppress the dialog.
                        }
                        else
                        {
                            // Otherwise allow the dialog, and let the user to decide
                            // whether or not to allow the protocol to launch.
                        }
                    return S_OK;
                })
                .Get(),
            &m_launchingExternalProtocolToken));

        // Note that FrameCreated will only ever be raised for top level iframes.
        // Any launching external protocol requests from nested iframes 
        // will be raised from the top level frame.
        CHECK_FAILURE(webView5->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webViewFrame;
                    CHECK_FAILURE(args->get_Frame(&webViewFrame));

                    auto webViewFrame3 = webViewFrame.try_query<ICoreWebView2Frame3>();
                    if (webViewFrame3)
                    {
                        CHECK_FAILURE(webViewFrame3->add_LaunchingExternalProtocol(
                        Callback<ICoreWebView2FrameLaunchingExternalProtocolEventHandler>(
                            [this](
                                ICoreWebView2Frame* sender,
                                ICoreWebView2LaunchingExternalProtocolEventArgs* args) {
                                    wil::unique_cotaskmem_string uri;
                                    CHECK_FAILURE(args->get_Uri(&uri));
                                    if (wcsicmp(uri.get(), L"calculator://") == 0)
                                    {
                                        // If this matches our desired protocol, then suppress the
                                        // dialog.
                                        CHECK_FAILURE(args->put_Handled(TRUE));
                                    }
                                    else
                                    {
                                        // Otherwise revoke permissions previously granted to this protocol 
                                        // from this origin as well as disable the always open checkbox.
                                        CHECK_FAILURE(args->put_DisableAlwaysOpenCheckbox(TRUE));
                                    }
                                    return S_OK;
                            })
                            .Get(),
                        &m_frameLaunchingExternalProtocolToken));
                    }
                    return S_OK;
            }).Get(),
            &m_frameCreatedToken));
    }
}
    
```

## .NET and WinRT

```c #
private WebView2 webView;
void RegisterLaunchingExternalProtocolHandler() 
{
    webView.CoreWebView2.LaunchingExternalProtocol += (CoreWebView2 sender, CoreWebView2LaunchingExternalProtocolEventArgs e) {
        if (e.Uri == "calculator:///") 
        {
            // If this matches our desired protocol, then suppress the popup dialog.
            e.Handled = true;
        }
        else 
        {
            // Otherwise allow the dialog, and let the user to decide 
            // whether or not to allow the protocol to launch.
        }
    };

    webView.CoreWebView2.FrameCreated += (CoreWebView2Frame sender, CoreWebView2FrameCreatedEventArgs args) =>
    {
        // Apply the same logic as above to non-main frame raising the event.
        args.Frame.LaunchingExternalProtocol += (LaunchingExternalProtocolSender, LaunchingExternalProtocolArgs) =>
        {
            if (LaunchingExternalProtocolArgs.Uri == "calculator:///") 
            {
                // If this matches our desired protocol, then suppress the dialog.
                LaunchingExternalProtocolArgs.Handled = true;
            }
            else 
            {
                // Otherwise revoke permissions previously granted to this protocol 
                // from this origin as well as disable the always open checkbox.
                LaunchingExternalProtocolArgs.DisableAlwaysOpenCheckbox = true;
            }
        };
    };
}

```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
    
```IDL
// This is the ICoreWebView2_11 interface.
[uuid(cc39bea3-d6d8-471b-919f-da253e2fbf03), object, pointer_default(unique)] 
interface ICoreWebView2_11 : IUnknown {
  /// Add an event handler for the `LaunchingExternalProtocol` event.
  /// The `LaunchingExternalProtocol` event is raised when a launch request is made to a
  /// protocol that is registered with the OS. The host has the option to
  /// handle this event by suppressing the popup dialog that gives the user
  /// the option to allow the protocol launch. The host also has the option to
  /// programatically cancel the protocol launch.
  /// The host also is given the opportunity to disable the always open checkbox 
  /// which also revokes previous permissions given to this protocol/origin.
  /// The `NavigationStarting`, `NavigationCompleted, `SourceChanged`,
  /// `ContentLoading`, and `HistoryChanged` events will not be raised, regardless
  /// of whether the `Cancel` or `Handled` property is set to `TRUE` or
  /// `FALSE`. This behavior holds true for the frame navigation events as
  /// well.
  HRESULT add_LaunchingExternalProtocol(
      [in] ICoreWebView2LaunchingExternalProtocolEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with
  /// `add_LaunchingExternalProtocol`.
  HRESULT remove_LaunchingExternalProtocol(
      [in] EventRegistrationToken token);
}

// This is the ICoreWebView2Frame3 interface.
[uuid(fe1d3718-fe8d-48ab-8594-9e3fff6755ac), object, pointer_default(unique)] 
interface ICoreWebView2Frame3 : IUnknown {
  /// Add an event handler for the `LaunchingExternalProtocol` event.
  /// A frame will raise a `LaunchingExternalProtocol` event when any non-main
  /// frames attempt to launch an external protocol. This event aligns with the 
  /// event raised on the `CoreWebView2` interface. 

  HRESULT add_LaunchingExternalProtocol(
      [in] ICoreWebView2FrameLaunchingExternalProtocolEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_LaunchingExternalProtocol`.
  HRESULT remove_LaunchingExternalProtocol(
      [in] EventRegistrationToken token);
}

/// Receives `LaunchingExternalProtocol` events for main frame.
[uuid(e5fea648-79c9-47aa-8314-f471fe627649), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalProtocolEventHandler: IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2LaunchingExternalProtocolEventArgs* args);
}

/// Receives `LaunchingExternalProtocol` events for non-main frame.
[uuid(a898c12c-f949-474c-913b-428770cfc177), object, pointer_default(unique)] 
interface ICoreWebView2FrameLaunchingExternalProtocolEventHandler: IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2LaunchingExternalProtocolEventArgs* args);
}

/// Event args for `LaunchingExternalProtocol` event.
[uuid(fc43b557-9713-4a67-af8d-a76ef3a206e8), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalProtocolEventArgs: IUnknown {
  /// The uri of the requested protocol.

  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The host may set this flag to cancel the protocol launch.  If set to
  /// `TRUE`, the protocol will not be launched. If cancelled, the
  /// dialog is not displayed regardless of the `Handled` property.

  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property. The default value is `FALSE`.

  [propput] HRESULT Cancel([in] BOOL cancel);

  /// The host may set this flag to `TRUE` to hide the dialog.
  /// The protocol request will continue as normal if it is not
  /// cancelled, although there will be no default UI shown. The default
  /// value is `FALSE` and the default external protocol dialog is shown.

  [propget] HRESULT Handled([out, retval] BOOL* handled);

  /// Sets the `Handled` property. The default value is `FALSE`.

  [propput] HRESULT Handled([in] BOOL handled);

  /// The host may set this flag to `TRUE` to disable the always open checkbox. 
  /// This will also revoke previous permissions given to this protocol/origin.
  /// The always open checkbox is displayed only when the 
  /// launch is being requested from a trustworthy origin and gives the user the option to
  /// always allow this origin to open links of this type in the associated app.
  /// See [trustworthy origin]
  /// (https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-origin) 
  /// for more information regarding trustworthy origins. See [always open checkbox]
  /// (https://docs.microsoft.com/en-us/DeployEdge/microsoft-edge-policies#externalprotocoldialogshowalwaysopencheckbox)
  /// for more information regarding the always open checkbox.
  /// Permissions will be revoked in the future if this property is set to `TRUE` regardless of the 
  /// values of the `Cancel` or `Handled` properties. 
  /// The default value is `FALSE`.

  [propget] HRESULT DisableAlwaysOpenCheckbox(
      [out, retval] BOOL* disableAlwaysOpenCheckbox);

  /// Sets the `DisableAlwaysOpenCheckbox` property.
  [propput] HRESULT DisableAlwaysOpenCheckbox([in] BOOL disableAlwaysOpenCheckbox);
}

``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2LaunchingExternalProtocolEventArgs;
    
    runtimeclass CoreWebView2LaunchingExternalProtocolEventArgs
    {
        // CoreWebView2LaunchingExternalProtocolEventArgs members
        String Uri { get; };
        Boolean Cancel { get; set; };
        Boolean Handled {get; set; };
        Boolean DisableAlwaysOpenCheckbox {get; set; };
    }

    runtimeclass CoreWebView2
    {
        // CoreWebView2 
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2LaunchingExternalProtocolEventArgs> LaunchingExternalProtocol;
    }

    runtimeclass CoreWebView2Frame
    {
        //CoreWebView2Frame
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2LaunchingExternalProtocolEventArgs> LaunchingExternalProtocol;
    }
}
```
