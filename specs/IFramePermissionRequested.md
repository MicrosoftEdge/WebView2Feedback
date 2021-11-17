# Background
The WebView2 team has been asked to provide support for handling permission
requests that come from iframes. These permission requests occur when content
within the iframe are requesting access to priveleged resources. The permission
request types that we support are: Microphone, Camera, Geolocation,
Notifications, Other Sensors, and Clipboard Read.

We currently have a [PermissionRequested](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs?view=webview2-1.0.1020.30)
event on our `CoreWebView2` which is raised for any permission requests
(either from webview or iframes). However, our customers do not have a way to
determine whether the request has come from the webview or an iframe and
handle these cases seperately. As such, we plan to expand our
`CoreWebView2Frame` API to include the `PermissionRequested` event.

A current limitation of our `CoreWebView2Frame` API is that it only supports top
level iframes. Any nested iframes will not have a `CoreWebView2Frame`
associated with them.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2Frame` to include the `PermissionRequested`
event. This event will be raised whenever the iframe corresponding to the
CoreWebView2Frame or any of its descendant iframes requests permission to
priveleged resources.

Additionally, we propose extending `CoreWebView2PermissionRequestedEventArgs`
to include a `Handled` property.

To maintain backwards compatibility, by default we plan to raise
`PermissionRequested` on both `CoreWebView2Frame` and `CoreWebView2`. The
`CoreWebView2Frame` event handlers will be invoked first,
before the `CoreWebView2` event handlers. If `Handled` is set true as part of
the `CoreWebView2Frame` event handlers, then the `PermissionRequested` event
will not be raised on the `CoreWebView2`, and its event handlers will not be
invoked.

In the case of a nested iframe requesting permission, we will raise the event
off of the top level iframe.

# Examples
## C++: Registering IFrame Permission Requested Handler
``` cpp
AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webview;
std::map<std::tuple<std::wstring, COREWEBVIEW2_PERMISSION_KIND, BOOL>, bool>
    m_cachedPermissions;

EventRegistrationToken m_frameCreatedToken = {};
EventRegistrationToken m_permissionRequestedToken = {};

// Example Use Case - an app may want to specify that all iframes should
// create a message box to prompt the user for approval on a permission request.
// The approval state could be cached so that future requests are automatically
// handled if they have been requested previously.
void RegisterIFramePermissionRequestedHandler()
{
    auto webview4 = m_webview.try_query<ICoreWebView2_4>();
    if (webview4)
    {
        // Note that FrameCreated will only ever be raised for top level iframes.
        // However, any permission requests from nested iframes will be raised
        // from the top level frame.
        CHECK_FAILURE(webview4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));

                    auto webviewFrame2 = webviewFrame.try_query<ICoreWebView2Frame2>();
                    if (webviewFrame2)
                    {
                        CHECK_FAILURE(webviewFrame2->add_PermissionRequested(
                            Callback<ICoreWebView2FramePermissionRequestedEventHandler>(
                                [this](ICoreWebView2Frame* sender,
                                   ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT
                                {
                                    // We avoid potential reentrancy from running a message loop
                                    // in the permission requested event handler by showing the
                                    // dialog via lambda run asynchronously outside of this event
                                    // handler.
                                    auto showDialog = [this, args]
                                    {
                                        COREWEBVIEW2_PERMISSION_KIND kind =
                                            COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
                                        BOOL userInitiated = FALSE;
                                        wil::unique_cotaskmem_string uri;

                                        CHECK_FAILURE(args->get_PermissionKind(&kind));
                                        CHECK_FAILURE(args->get_IsUserInitiated(&userInitiated));
                                        CHECK_FAILURE(args->get_Uri(&uri));

                                        auto cachedKey = std::make_tuple(
                                            std::wstring(uri.get()), kind, userInitiated);

                                        auto cachedPermission =
                                            m_cachedPermissions.find(cachedKey);
                                        if (cachedPermission != m_cachedPermissions.end())
                                        {
                                            bool allow = cachedPermission->second;
                                            if (allow)
                                            {
                                                CHECK_FAILURE(args->put_State(
                                                    COREWEBVIEW2_PERMISSION_STATE_ALLOW));
                                            }
                                            else
                                            {
                                                CHECK_FAILURE(args->put_State(
                                                    COREWEBVIEW2_PERMISSION_STATE_DENY));
                                            }

                                            PutHandled(args);
                                            return S_OK;
                                        }

                                        std::wstring message =
                                            L"An iframe has requested device permission for ";
                                        message += NameOfPermissionKind(kind);
                                        message += L" to the website at ";
                                        message += uri.get();
                                        message += L"?\n\n";
                                        message += L"Do you want to grant permission?\n";
                                        message +=
                                            (userInitiated
                                                ? L"This request came from a user gesture."
                                                : L"This request did not come from a user "
                                                L"gesture.");

                                        int response = MessageBox(
                                            nullptr, message.c_str(), L"Permission Request",
                                            MB_YESNOCANCEL | MB_ICONWARNING);

                                        COREWEBVIEW2_PERMISSION_STATE state =
                                            COREWEBVIEW2_PERMISSION_STATE_DEFAULT;

                                        if (response == IDYES)
                                        {
                                            m_cachedPermissions.insert_or_assign(cachedKey, true);
                                            state = COREWEBVIEW2_PERMISSION_STATE_ALLOW;
                                        }
                                        else if (response == IDNO)
                                        {
                                            m_cachedPermissions.insert_or_assign(cachedKey, false);
                                            state = COREWEBVIEW2_PERMISSION_STATE_DENY;
                                        }

                                        CHECK_FAILURE(args->put_State(state));

                                        PutHandled(args);
                                        return S_OK;
                                    };

                                    // Obtain a deferral for the event so that the CoreWebView2
                                    // doesn't examine the properties we set on the event args until
                                    // after we call the Complete method asynchronously later.
                                    wil::com_ptr<ICoreWebView2Deferral> deferral;
                                    CHECK_FAILURE(args->GetDeferral(&deferral));

                                    m_appWindow->RunAsync([deferral, showDialog]()
                                    {
                                        showDialog();
                                        CHECK_FAILURE(deferral->Complete());
                                    });

                                    return S_OK;
                            }).Get(),
                            &m_PermissionRequestedToken));
                    }
                    return S_OK;
            }).Get(),
            &m_FrameCreatedToken));
    }
}

static PCWSTR NameOfPermissionKind(COREWEBVIEW2_PERMISSION_KIND kind)
{
    switch (kind)
    {
        case COREWEBVIEW2_PERMISSION_KIND_MICROPHONE:
            return L"Microphone";
        case COREWEBVIEW2_PERMISSION_KIND_CAMERA:
            return L"Camera";
        case COREWEBVIEW2_PERMISSION_KIND_GEOLOCATION:
            return L"Geolocation";
        case COREWEBVIEW2_PERMISSION_KIND_NOTIFICATIONS:
            return L"Notifications";
        case COREWEBVIEW2_PERMISSION_KIND_OTHER_SENSORS:
            return L"Generic Sensors";
        case COREWEBVIEW2_PERMISSION_KIND_CLIPBOARD_READ:
            return L"Clipboard Read";
        default:
            return L"Unknown resources";
    }
}

static void PutHandled(ICoreWebView2PermissionRequestedEventArgs* args)
{
    // In the case of an iframe requesting permission, the default behavior is
    // to first raise the PermissionRequested event off of the CoreWebView2Frame
    // and invoke it's handlers, and then raise the event off the CoreWebView2
    // and invoke it's handlers. However, If we set Handled to true on the
    // CoreWebView2Frame event handler, then we will not raise the
    // PermissionRequested event off the CoreWebView2.
    wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs2> args2;
    CHECK_FAILURE(args->QueryInterface(IID_PPV_ARGS(&args2)));
    if (args2)
    {
        CHECK_FAILURE(args2->put_Handled(true));
    }
}
```

## C#: Registering IFrame Permission Requested Handler
```c#
private WebView2 m_webview;
Dictionary<Tuple<string, CoreWebView2PermissionKind, bool>, bool> m_cachedPermissions;

// Example Use Case - an app may want to specify that all iframes should
// create a message box to prompt the user for approval on a permission request.
// The approval state could be cached so that future requests are automatically
// handled if they have been requested previously.
void RegisterIFramePermissionRequestedHandler()
{
    m_webview.CoreWebView2.FrameCreated += (sender, frameCreatedArgs) =>
    {
        // Checking for runtime support of CoreWebView2Frame.PermissionRequested
        try
        {
            frameCreatedArgs.Frame.PermissionRequested += (frameSender, permissionArgs) =>
            {
                // Developer can obtain a deferral for the event so that the CoreWebView2
                // doesn't examine the properties we set on the event args until
                // after the deferral completes asynchronously.
                CoreWebView2Deferral deferral = args.GetDeferral();

                // We avoid potential reentrancy from running a message loop
                // in the permission requested event handler by showing the
                // dialog asynchronously.
                System.Threading.SynchronizationContext.Current.Post((_) =>
                {
                    using (deferral)
                    {
                        var cachedKey = Tuple.Create(permissionArgs.Uri,
                            permissionArgs.PermissionKind, permissionArgs.IsUserInitiated);

                        if (m_cachedPermissions.TryGetValue(cachedKey, out value))
                        {
                            permissionArgs.State = value 
                                                        ? CoreWebView2PermissionState.Allow 
                                                        : CoreWebView2PermissionState.Deny;
                            
                            PutHandled(permissionArgs);
                            return;
                        }

                        string message = "An iframe has requested device permission for ";
                        message += NameOfPermissionKind(permissionArgs.PermissionKind);
                        message += " to the website at ";
                        message += permissionArgs.Uri;
                        message += "\n\n";
                        message += "Do you want to grant permission?\n";
                        message +=
                            (permissionArgs.IsUserInitiated
                                ? "This request came from a user gesture."
                                : "This request did not come from a user gesture.");

                        var selection = MessageBox.Show(message, "iframe PermissionRequest",
                            MessageBoxButton.YesNoCancel);

                        permissionArgs.State = CoreWebView2PermissionState.Default;

                        if (selection == MessageBoxResult.Yes)
                        {
                            permissionArgs.State = CoreWebView2PermissionState.Allow;
                            m_cachedPermissions[cachedKey] = true;
                        }
                        else if (selection == MessageBoxResult.No)
                        {
                            permissionArgs.State = CoreWebView2PermissionState.Deny;
                            m_cachedPermissions[cachedKey] = false;
                        }

                        PutHandled(permissionArgs);
                    }
                }, null);
            };
        }
        catch (NotImplementedException exception)
        {
            // If the runtime support is not there we probably want this
            // to be a no-op.
        }
    };
}

string NameOfPermissionKind(CoreWebView2PermissionKind kind)
{
    switch (kind)
    {
        case CoreWebView2PermissionKind.Microphone:
            return "Microphone";
        case CoreWebView2PermissionKind.Camera:
            return "Camera";
        case CoreWebView2PermissionKind.Geolocation:
            return "Geolocation";
        case CoreWebView2PermissionKind.Notifications:
            return "Notifications";
        case CoreWebView2PermissionKind.OtherSensors:
            return "Generic Sensors";
        case CoreWebView2PermissionKind.ClipboardRead:
            return "Clipboard Read";
        default:
            return "Unknown resources";
    }
}

void PutHandled(CoreWebView2PermissionEventArgs args)
{
    // In the case of an iframe requesting permission, the default behavior is
    // to first raise the PermissionRequested event off of the CoreWebView2Frame
    // and invoke it's handlers, and then raise the event off the CoreWebView2
    // and invoke it's handlers. However, If we set Handled to true on the
    // CoreWebView2Frame event handler, then we will not raise the
    // PermissionRequested event off the CoreWebView2.
    // 
    // NotImplementedException could be thrown if underlying runtime did not
    // implement Handled. However, we only run this code after checking if
    // CoreWebView2Frame.PermissionRequested exists, and both exist together,
    // so it would not be a problem.
    args.Handled = true;
}
```

# API Details
## C++
```
interface ICoreWebView2Frame2;
interface ICoreWebView2FramePermissionRequestedEventHandler;
interface ICoreWebView2FramePermissionRequestedEventArgs2;

/// This is an extension of the ICoreWebView2Frame interface.
[uuid(3ed01620-13fc-4c2c-9eb9-62fccd689093), object, pointer_default(unique)]
interface ICoreWebView2Frame2 : ICoreWebView2Frame {
  /// Add an event handler for the `PermissionRequested` event.
  /// `PermissionRequested` is raised when content in an iframe any of its
  /// descendant iframes requests permission to priveleged resources.
  ///
  /// This relates to the `PermissionRequested` event on the `CoreWebView2`.
  /// Both these events will be raised in the case of an iframe requesting
  /// permission. The `CoreWebView2Frame`'s event handlers will be invoked
  /// before the event handlers on the `CoreWebView2`. If the `Handled` property
  /// of the `PermissionRequestedEventArgs` is set to TRUE within the
  /// `CoreWebView2Frame` event handler, then the event will not be
  /// raised on the `CoreWebView2`, and it's event handlers will not be invoked.
  ///
  /// In the case of nested iframes, the 'PermissionRequested' event will
  /// be raised from the top level iframe.
  ///
  /// If a deferral is not taken on the event args, the subsequent scripts are
  /// blocked until the event handler returns.  If a deferral is taken, the
  /// scripts are blocked until the deferral is completed.
  ///
  /// \snippet ScenarioIFrameDevicePermission.cpp PermissionRequested
  HRESULT add_PermissionRequested(
      [in] ICoreWebView2FramePermissionRequestedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_PermissionRequested`
  HRESULT remove_PermissionRequested(
      [in] EventRegistrationToken token);
}

/// Receives `PermissionRequested` events.
[uuid(603ea097-c805-43fb-aa35-80949c1e4b26), object, pointer_default(unique)]
interface ICoreWebView2FramePermissionRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2PermissionRequestedEventArgs* args);
}

/// This is a continuation of the `ICoreWebView2PermissionRequestedEventArgs` interface.
[uuid(d52ce9b5-c603-4c33-9887-c06c77b54b3c), object, pointer_default(unique)]
interface ICoreWebView2PermissionRequestedEventArgs2: ICoreWebView2PermissionRequestedEventArgs {
  /// By default, both the `PermissionRequested` event handlers on the
  /// `CoreWebView2Frame' and the `CoreWebView2` will be invoked, with the
  /// `CoreWebView2Frame' event handlers invoked first. The host may
  /// set this flag to `TRUE` within the `CoreWebView2Frame' event handlers
  /// to prevent the remaining `CoreWebView2` event handlers from being invoked.
  [propget] HRESULT Handled([out, retval] BOOL* handled);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL handled);
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2PermissionRequestedEventArgs
    {

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2PermissionRequestedEventArgs2")]
        {
            // ICoreWebView2PermissionRequestedEventArgs2 members
            [doc_string("The host may set this flag to `TRUE` to prevent the `PermissionRequested` event from firing on the CoreWebView2 as well.\nBy default, both the `PermissionRequested` on the CoreWebView2Frame and CoreWebView2 will be raised.")]
            Boolean Handled { get; set; };
        }

    }

    runtimeclass CoreWebView2Frame
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame2")]
        {
            // ICoreWebView2Frame2 members
            [doc_string("PermissionRequested is raised when content in an iframe or any of its descendant iframes requests permission to access some priveleged resources.\nIf a deferral is not taken on the event args, the subsequent scripts are blocked until the event handler returns. If a deferral is taken, the scripts are blocked until the deferral is completed.")]
            event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2PermissionRequestedEventArgs> PermissionRequested;
        }

}
```
