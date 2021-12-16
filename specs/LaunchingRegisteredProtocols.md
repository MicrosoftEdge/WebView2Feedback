# Background

We are exposing an event that will fire when an attempt to launch a registered protocol is made. The host will be given the option to cancel the launch, handle the popup dialog to hide the dialog, as well as revoke permissions that have been previously given to the origin launching the protocol. 

# Description

This event will fire before the registered protocol launch occurs. Currently a popup dialog is displayed in which the user can click `Open` or `Cancel`. If the request is made from a trustworthy origin a checkmark box will be displayed that will allow the user to always allow this registered protocol from this origin. The `NavigationStarting`, `NavigationCompleted, `SourceChanged`, `ContentLoading`, and `HistoryChanged` events will not fire when a request is made to launch a registered protocol. 

There are two events associated with the registered protocol launch - one for the main frame, and one for non-main frame(s). In the case in which the launch request is made from a non-main frame, the frame will raise a `LaunchingRegisteredProtocol` event as well as `CoreWebView2.FrameLaunchingRegisteredProtocol` event. 
# Examples

## Win32 C++
    
```cpp 

CHECK_FAILURE(m_webView->add_LaunchingRegisteredProtocol(
    Callback<ICoreWebView2LaunchingRegisteredProtocolEventHandler>(
        [this](
            ICoreWebView2* sender,
            ICoreWebView2LaunchingRegisteredProtocolEventArgs* args) {
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_Uri(&uri));
                if (wcscmp(uri.get(), L"calculator://") == 0)
                {
                    CHECK_FAILURE(args->put_Handled(TRUE));
                    // If this matches our desired protocol, then suppress the
                    // popup dialog.
                }
                else
                {
                    CHECK_FAILURE(args->put_Handled(FALSE));
                    // Otherwise allow the popup dialog, and allow the user to decide
                    // whether or not to allow the protocol to launch.
                }
            return S_OK;
        })
        .Get(),
    &m_launchingRegisteredProtocolToken));

CHECK_FAILURE(frame->add_LaunchingRegisteredProtocol(
    Callback<ICoreWebView2FrameLaunchingRegisteredProtocolEventHandler>(
        [this](
            ICoreWebView2Frame* sender,
            ICoreWebView2LaunchingRegisteredProtocolEventArgs* args) {
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_Uri(&uri));
                if (wcscmp(uri.get(), L"calculator://") == 0)
                {
                    // If this matches our desired protocol, then suppress the
                    // popup dialog.
                    CHECK_FAILURE(args->put_Handled(TRUE));
                }
                else
                {
                    // Otherwise revoke permissions previously granted to this protocol 
                    // from this origin. This will trigger the dialog to appear to allow the user
                    // to confirm or deny the protocol launch.
                    CHECK_FAILURE(args->put_RevokeProtocolPermissionsPerOrigin(TRUE));
                }
                return S_OK;
        })
        .Get(),
    &m_frameLaunchingRegisteredProtocolToken));
    
``` 

## .NET and WinRT

```c #

void WebView_LaunchingRegisteredProtocol(object target, CoreWebView2LaunchingRegisteredProtocolEventArgs e)
{
    if (e.Uri == "calculator:///") 
    {
        // If this matches our desired protocol, then suppress the popup dialog.
        e.Handled = true;
    }
    else 
    {
        // Otherwise allow the popup dialog, and allow the user to decide 
        // whether or not to allow the protocol to launch.
        e.Handled = false;
    }
    webView.CoreWebView2.FrameCreated += (sender, args) =>
    {
        // Apply the same logic as above to non-main frame raising the event.
        args.Frame.LaunchingRegisteredProtocol += (frameSender, LaunchingRegisteredProtocolArgs) =>
        {
            if (LaunchingRegisteredProtocolArgs.Uri == "calculator:///") 
            {
                // If this matches our desired protocol, then suppress the popup dialog.
                e.Handled = true;
            }
            else 
            {
                // Otherwise revoke permissions previously granted to this protocol 
                // from this origin. This will trigger the dialog to appear to allow the user
                // to confirm or deny the protocol launch.
                e.RevokeProtocolPermissionsPerOrigin = true;
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
  /// Add an event handler for the `RegisteredProtocol` event.
  /// The RegisteredProtocol event fires when a launch request is made to a protocol
  /// that is registered with the Windows OS. The host has the option to
  /// handle this event by suppressing the popup dialog that gives the user
  /// the option to allow the app launch as well as programatically cancel the
  /// app launch. The host also is given the opportunity to revoke previous permissions 
  /// given to this origin and protocol to be launched automatically.
  /// The `NavigationStarting`, `NavigationCompleted, `SourceChanged`,
  /// `ContentLoading`, and `HistoryChanged` events will not fire, regardless
  /// of whether the `Cancel` or `Handled` property is set to `TRUE` or
  /// `FALSE`. This behavior holds true for the frame navigation events as
  /// well.
  HRESULT add_LaunchingRegisteredProtocol(
      [in] ICoreWebView2LaunchingRegisteredProtocolEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with
  /// `add_LaunchingRegisteredProtocol`.
  HRESULT remove_LaunchingRegisteredProtocol(
      [in] EventRegistrationToken token);
}

// This is the ICoreWebView2Frame3 interface.
[uuid(fe1d3718-fe8d-48ab-8594-9e3fff6755ac), object, pointer_default(unique)] 
interface ICoreWebView2Frame3 : IUnknown {
  /// Add an event handler for the `FrameRegisteredProtocol` event.
  /// A frame will raise a `LaunchingRegisteredProtocol` event and
  /// a `CoreWebView2.FrameLaunchingRegisteredProtocol` event. All of the
  /// `FrameLaunchingRegisteredProtocol` event handlers for the current 
  /// frame will be run before the `LaunchingRegisteredProtocol` event handlers. 
  /// All of the event handlers share a common `LaunchingRegisteredProtocolEventArgs` 
  /// object. Whichever event handler is last to change the 
  /// `LaunchingRegisteredProtocolEventArgs.Cancel` property will
  /// decide if the frame protocol request launch will be cancelled. 
  /// Whichever event handler is last to change the
  /// `LaunchingRegisteredProtocolEventArgs.Handled` property will decide if
  /// the dialog will be suppressed. Whichever event handler is last to change the 
  /// `LaunchingRegisteredProtocolEventArgs.RevokeProtocolPermissionsPerOrigin` 
  /// property will determine if the permissions for that origin per protocol
  /// will be revoked. 

  HRESULT add_LaunchingRegisteredProtocol(
      [in] ICoreWebView2FrameLaunchingRegisteredProtocolEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_LaunchingRegisteredProtocol`.
  HRESULT remove_LaunchingRegisteredProtocol(
      [in] EventRegistrationToken token);
}

/// Receives `LaunchingRegisteredProtocol` events for main frame.
[uuid(e5fea648-79c9-47aa-8314-f471fe627649), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingRegisteredProtocolEventHandler: IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2LaunchingRegisteredProtocolEventArgs* args);
}

/// Receives `LaunchingRegisteredProtocol` events for non-main frame.
[uuid(a898c12c-f949-474c-913b-428770cfc177), object, pointer_default(unique)] 
interface ICoreWebView2FrameLaunchingRegisteredProtocolEventHandler: IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2LaunchingRegisteredProtocolEventArgs* args);
}

/// Event args for `LaunchingRegisteredProtocol` event.
[uuid(fc43b557-9713-4a67-af8d-a76ef3a206e8), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingRegisteredProtocolEventArgs: IUnknown {
  /// The uri of the requested protocol.

  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The host may set this flag to cancel the protocol launch.  If set to
  /// `TRUE`, the protocol will not be launched. If cancelled, the
  /// dialog is not displayed regardless of the `Handled` property.

  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property.

  [propput] HRESULT Cancel([in] BOOL cancel);

  /// The host may set this flag to `TRUE` to hide the dialog.
  /// The protocol request will continue as normal if it is not
  /// cancelled, although there will be no default UI shown. By default the
  /// value is `FALSE` and the default registered protocol dialog is shown.

  [propget] HRESULT Handled([out, retval] BOOL* handled);

  /// Sets the `Handled` property.

  [propput] HRESULT Handled([in] BOOL handled);

  /// The host may set this flag to `TRUE` to revoke previous permissions given
  /// to this protocol/origin. In the case in which the registered protocol
  /// launch is being requested from a trustworthy origin, the dialog
  /// prompt (if not handled) will display a checkbox that gives the user the option to
  /// always allow this origin to open links of this type in the associated app.
  /// Once checked by the user, this protocol for this origin will be launched automatically
  /// without displaying the dialog prompt.
  /// If the `Cancel` property is set to `TRUE` while this property is set to
  /// `TRUE` the registered protocol will not be launched in this instance. If `Handled` is set  
  /// to `TRUE` the dialog prompt will still be disabled regardless of this property, but the 
  /// permissions will be revoked in the future if this property is set to `TRUE`. 

  [propget] HRESULT RevokeProtocolPermissionsPerOrigin(
      [out, retval] BOOL* revokeProtocolPermissionsPerOrigin);

  /// Sets the `RevokeProtocolPermissionsPerOrigin` property.
  [propput] HRESULT RevokeProtocolPermissionsPerOrigin([in] BOOL revokeProtocolPermissionsPerOrigin);
}

``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2LaunchingRegisteredProtocolEventArgs;
    
    runtimeclass CoreWebView2LaunchingRegisteredProtocolEventArgs
    {
        // CoreWebView2LaunchingRegisteredProtocolEventArgs members
        String Uri { get; };
        Boolean Cancel { get; set; };
        Boolean Handled {get; set; };
        Boolean RevokeProtocolPermissionsPerOrigin {get; set; };
    }

    runtimeclass CoreWebView2
    {
        // CoreWebView2 
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2LaunchingRegisteredProtocolEventArgs> LaunchingRegisteredProtocolEventArgs;
    }

    runtimeclass CoreWebView2Frame
    {
        //CoreWebView2Frame
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2LaunchingRegisteredProtocolEventArgs> LaunchingRegisteredProtocolEventArgs;
    }
}
```
