Web Notification APIs
===

# Background

The WebView2 team is adding support for web notifications including
non-persistent notifications and persistent notifications. A non-persistent
notification is a notification without an associated service worker
registration. A persistent notification is a notification with an associated
service worker registration.

You should be able to handle notification permission requests, and
further listen to `NotificationReceived` events to optionally handle the
notifications themselves. The `NotificationReceived` events are raised on
`CorebWebView2` and `CoreWebView2Profile` object respectively for non-persistent
and persistent notifications respectively.

The `NotificationReceived` event on `CoreWebView2` and `CoreWebView2Profile` let
you intercept the web non-persistent and persistent notifications. The host can
use the `Notification` property on the `NotificationReceivedEventArgs` to
construct an notification matching the look and feel of the host app. The host
can also use such information to decide to show or not show a particular
notification. The host can `GetDeferral` or set the `Handled` property on the
`NotificationReceivedEventArgs` to handle the event at a later time or let
WebView2 know if the notification has been handled. By default, if the
`NotificationReceived` event is not handled by the host, the web notification
will be displayed using the default notification UI provided by WebView2
Runtime.

# Examples

## Handle PermissionRequested event

This can be achieved with the existing `PermissionRequested` events.
`PermissionRequested` event used to not be raised for
`PermissionKind.Notification`. Now, `PermissionRequested` events are raised for
`PermissionKind.Notification`, and `PermissionState` needs to be set `Allow`
explicitly to allow such permission requests. `PermissionState.Default` for
`PermissionKind.Notification` is considered denied.

### C# Sample
```csharp
IDictionary<(string, CoreWebView2PermissionKind, bool), bool> _cachedPermissions = 
    new Dictionary<(string, CoreWebView2PermissionKind, bool), bool>();
...
void WebView_PermissionRequested(object sender, CoreWebView2PermissionRequestedEventArgs args)
{
    CoreWebView2Deferral deferral = args.GetDeferral();
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        using (deferral)
        {
            (string, CoreWebView2PermissionKind, bool) cachedKey = (args.Uri, args.PermissionKind, args.IsUserInitiated);
            if (_cachedPermissions.ContainsKey(cachedKey))
            {
                args.State = _cachedPermissions[cachedKey]
                    ? CoreWebView2PermissionState.Allow
                    : CoreWebView2PermissionState.Deny;
            }
            else
            {
                string message = "An iframe has requested device permission for ";
                message += NameOfPermissionKind(args.PermissionKind) + " to the website at ";
                message += args.Uri + ".\n\nDo you want to grant permission?\n";
                message += args.IsUserInitiated ? "This request came from a user gesture." : "This request did not come from a user gesture.";
                var selection = MessageBox.Show(
                    message, "Permission Request", MessageBoxButton.YesNoCancel);
                switch (selection)
                {
                    case MessageBoxResult.Yes:
                        args.State = CoreWebView2PermissionState.Allow;
                        _cachedPermissions[cachedKey] = true;
                        break;
                    case MessageBoxResult.No:
                        args.State = CoreWebView2PermissionState.Deny;
                        _cachedPermissions[cachedKey] = false;
                        break;
                    case MessageBoxResult.Cancel:
                        args.State = CoreWebView2PermissionState.Default;
                        break;
                }
            }
        }
    }, null);
}
```

### C++ Sample
```cpp
...
{
CHECK_FAILURE(m_webView->add_PermissionRequested(
    Callback<ICoreWebView2PermissionRequestedEventHandler>(
        this, &SettingsComponent::OnPermissionRequested)
        .Get(),
    &m_permissionRequestedToken));
}
...
HRESULT SettingsComponent::OnPermissionRequested(
    ICoreWebView2* sender, ICoreWebView2PermissionRequestedEventArgs* args)
{
    // Obtain a deferral for the event so that the CoreWebView2
    // doesn't examine the properties we set on the event args until
    // after we call the Complete method asynchronously later.
    wil::com_ptr<ICoreWebView2Deferral> deferral;
    CHECK_FAILURE(args->GetDeferral(&deferral));

    // Do the rest asynchronously, to avoid calling MessageBox in an event handler.
    m_appWindow->RunAsync([this, deferral, args] {
        COREWEBVIEW2_PERMISSION_KIND kind = COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
        BOOL userInitiated = FALSE;
        wil::unique_cotaskmem_string uri;
        CHECK_FAILURE(args->get_PermissionKind(&kind));
        CHECK_FAILURE(args->get_IsUserInitiated(&userInitiated));
        CHECK_FAILURE(args->get_Uri(&uri));

        COREWEBVIEW2_PERMISSION_STATE state;

        auto cached_key = std::make_tuple(std::wstring(uri.get()), kind, userInitiated);
        auto cached_permission = m_cached_permissions.find(cached_key);
        if (cached_permission != m_cached_permissions.end())
        {
            state =
                (cached_permission->second ? COREWEBVIEW2_PERMISSION_STATE_ALLOW
                                           : COREWEBVIEW2_PERMISSION_STATE_DENY);
        }
        else
        {
            std::wstring message = L"An iframe has requested device permission for ";
            message += SettingsComponent::NameOfPermissionKind(kind);
            message += L" to the website at ";
            message += uri.get();
            message += L"?\n\n";
            message += L"Do you want to grant permission?\n";
            message +=
                (userInitiated ? L"This request came from a user gesture."
                               : L"This request did not come from a user gesture.");

            int response = MessageBox(
                nullptr, message.c_str(), L"Permission Request",
                MB_YESNOCANCEL | MB_ICONWARNING);
            switch (response)
            {
            case IDYES:
                m_cached_permissions[cached_key] = true;
                state = COREWEBVIEW2_PERMISSION_STATE_ALLOW;
                break;
            case IDNO:
                m_cached_permissions[cached_key] = false;
                state = COREWEBVIEW2_PERMISSION_STATE_DENY;
                break;
            default:
                state = COREWEBVIEW2_PERMISSION_STATE_DEFAULT;
                break;
            }
        }

        CHECK_FAILURE(args->put_State(state));
        CHECK_FAILURE(deferral->Complete());
    });
    return S_OK;
}

```

## Filter Notifications from a specific doamin and send local toast

Learn more about sending a local toast [Send a local toast notification from a C# app - Windows apps | Microsoft Learn](https://learn.microsoft.com/windows/apps/design/shell/tiles-and-notifications/send-local-toast?tabs=uwp).

### C# Sample
```csharp
using Microsoft.Toolkit.Uwp.Notifications;
...
void WebView_NotificationReceived(object sender, CoreWebView2NotificationReceivedEventArgs args)
{
    CoreWebView2Deferral deferral = args.GetDeferral();
    args.Handled = true;
    var notification = args.Notification;

    // Show notification with local MessageBox
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        string message = "Received notification from " + args.Uri + " with body " + notification.Body;
        MessageBox.Show(message);
    }

    // Requires Microsoft.Toolkit.Uwp.Notifications NuGet package version 7.0 or greater
    var toastContent = new ToastContentBuilder()
        .AddArgument("conversationId", m_id)
        .AddText("Notification sent from " + args.Uri +":\n")
        .AddText(notification.Body);
    toastContent.Show();
    // See
    // https://learn.microsoft.com/windows/apps/design/shell/tiles-and-notifications/send-local-toast?tabs=uwp
    // for how to handle toast activation.

    // Call ReportShown after showing the toast notification to raise
    // the DOM notification.show event.
    // args.Handled has been set to true before we call Report... methods.
    notification.ReportShown();

    // During the toast notification activation handling, we may call
    // ReportClicked and/or ReportClose accordingly.
    notification.ReportClosed();
}
```

### C++ Sample

`Microsoft.Toolkit.Uwp.Notifications ` package does not work with non-UWP Win32
app. Hence in the sample code we use native MessageBox and handle notifications
accordingly.

```cpp
...
{
    //! [NotificationReceived]
    // Register a handler for the NotificationReceived event.
    CHECK_FAILURE(m_webView2_17->add_NotificationReceived(
        Callback<ICoreWebView2NotificationReceivedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2NotificationReceivedEventArgs* args) -> HRESULT
            {
                // Setting Handled to TRUE so the the default notification UI will not be
                // shown by WebView2 as we are handling the notification ourselves.
                // Block notifications from specific origins and return directly without showing notifications. 
                CHECK_FAILURE(args->put_Handled(TRUE));
                wil::unique_cotaskmem_string origin;
                CHECK_FAILURE(args->get_SenderOrigin(&origin));
                if (ShouldBlockOrigin(origin.get()))
                {
                    return S_OK;
                }

                wil::com_ptr<ICoreWebView2Notification> notification;
                CHECK_FAILURE(args->get_Notification(&notification));
    
                ShowNotification(notification);
                return S_OK;
            })
            .Get(),
        &m_notificationReceivedToken));
    //! [NotificationReceived]
    }
...
//! [OnNotificationReceived]
void SettingsComponent::ShowNotification(
    ICoreWebView2Notification* notification)
{
    AppWindow* appWindow = m_appWindow;

    appWindow->RunAsync(
        [this, notification]
        {

            wil::unique_cotaskmem_string origin;
            CHECK_FAILURE(eventArgs->get_SenderOrigin(&origin));
            wil::unique_cotaskmem_string title;
            CHECK_FAILURE(notification->get_Title(&title));
            wil::unique_cotaskmem_string body;
            CHECK_FAILURE(notification->get_Body(&body));

            std::wstring message =
                L"The page from " + std::wstring(origin.get()) + L" sends you an
                notification:\n\n";
            message += body.get();
            notification->ReportShown();
            int response = MessageBox(nullptr, message.c_str(), title.get(), MB_OKCANCEL);
            (response == IDOK) ? notification->ReportClicked() : notification->ReportClosed();
        });
}
//! [OnNotificationReceived]
```

# API Details

```cpp
/// Specifies the text direction of the notification.
[v1_enum]
typedef enum COREWEBVIEW2_TEXT_DIRECTION_KINDS {
  /// Indicates that the notification text direction adopts the browser's language setting behavior.
  COREWEBVIEW2_TEXT_DIRECTION_KINDS_DEFAULT,

  /// Indicates that the notification text is left-to-right.
  COREWEBVIEW2_TEXT_DIRECTION_KINDS_LEFT_TO_RIGHT,

  /// Indicates that the notification text is right-to-left.
  COREWEBVIEW2_TEXT_DIRECTION_KINDS_RIGHT_TO_LEFT,
} COREWEBVIEW2_TEXT_DIRECTION_KINDS;

/// This is the ICoreWebView2Profile3 interface that manages WebView2 Web
/// Notification functionality.
[uuid(51B49A68-BA2D-4188-821E-B13339CD96EE), object, pointer_default(unique)]
interface ICoreWebView2Profile3 : IUnknown {
  /// Add an event handler for the `NotificationReceived` event for persistent
  /// notifications.
  ///
  /// If a deferral is not taken on the event args, the subsequent scripts are
  /// blocked until the event handler returns. If a deferral is taken, the
  /// scripts are blocked until the deferral is completed.
  HRESULT add_NotificationReceived(
      [in] ICoreWebView2ProfileNotificationReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_NotificationReceived`.
  HRESULT remove_NotificationReceived([in] EventRegistrationToken token);
}

/// This is the ICoreWebView2_17 interface that manages WebView2 Web
/// Notification functionality.
[uuid(AA02BF32-E098-4F16-99F6-3FC182A1EC30), object, pointer_default(unique)]
interface ICoreWebView2_17 : ICoreWebView2_16 {
  /// Add an event handler for the `NotificationReceived` event for
  /// non-persistent notifications.
  ///
  /// If a deferral is not taken on the event args, the subsequent scripts are
  /// blocked until the event handler returns. If a deferral is taken, the
  /// scripts are blocked until the deferral is completed.
  HRESULT add_NotificationReceived(
      [in] ICoreWebView2NotificationReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_NotificationReceived`.
  HRESULT remove_NotificationReceived(
      [in] EventRegistrationToken token);
}

/// An event handler for the `NotificationReceived` event.
[uuid(4E0C46D6-B06F-4FFC-A11B-14C6A9B19BA5), object, pointer_default(unique)]
interface ICoreWebView2NotificationReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2NotificationReceivedEventArgs* args);
}

/// An event handler for the `NotificationReceived` event for persistent notifications.
[uuid(4843DC48-C1EF-4B0F-872E-F7AA6BC80175), object, pointer_default(unique)]
interface ICoreWebView2ProfileNotificationReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Profile* sender,
      [in] ICoreWebView2NotificationReceivedEventArgs* args);
}

/// Event args for the `NotificationReceived` event.
/// \snippet SettingsComponent.cpp NotificationReceived
/// \snippet SettingsComponent.cpp OnNotificationReceived
[uuid(5E8983CA-19A0-4140-BF2E-D7B9B707DDCC), object, pointer_default(unique)]
interface ICoreWebView2NotificationReceivedEventArgs : IUnknown {
  /// The origin of the web content that sends the notification, such as
  /// `https://example.com/` or `https://www.example.com/`.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT SenderOrigin([out, retval] LPWSTR* value);

  /// The notification that was received. You can access the
  /// properties on the Notification object to show their own notification. 
  [propget] HRESULT Notification([out, retval] ICoreWebView2Notification** value);
  
  /// Sets whether the `NotificationReceived` event is handled by the host after
  /// the event handler completes or if there is a deferral then after the
  /// deferral is completed.
  ///
  /// If `Handled` is set to TRUE then WebView will not display the notification
  /// with the default UI, and the host will be responsible for handling the
  /// notification and for letting the web content know that the notification
  /// has been displayed, clicked, or closed. You should set `Handled` to `TRUE`
  /// before you call `ReportShown`, `ReportClicked`, `ReportClickedWithAction`
  /// and `ReportClosed`, otherwise they will fail with `E_ABORT`. If after the
  /// event handler or deferral completes `Handled` is set to FALSE then WebView
  /// will display the default notification UI. Note that you cannot un-handle
  /// this event once you have set `Handled` to be `TRUE`. The default value is
  /// FALSE.
  [propput] HRESULT Handled([in] BOOL value);

  /// Gets whether the `NotificationReceived` event is handled by host.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

/// An event handler for the `CloseRequested` event.
[uuid(6A0B4DE9-8CBE-4211-BAEF-AC037B1A72DE), object, pointer_default(unique)]
interface ICoreWebView2NotificationCloseRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Notification* sender,
      [in] IUnknown* args);
}

/// This is the notification for interacting with the notification.
[uuid(07DD3067-2B86-47F6-AB96-D74825C2DA41), object, pointer_default(unique)]
interface ICoreWebView2NotificationAction : IUnknown {
  /// A string identifying a user action to be displayed on the notification.
  /// This corresponds to the
  /// [action](https://developer.mozilla.org/docs/Web/API/Notification/actions)
  /// member of a notification action object.
  [propget] HRESULT Action([out, retval] LPWSTR* value);

  /// A string containing action text to be shown to the user.
  /// This corresponds to the
  /// [title](https://developer.mozilla.org/docs/Web/API/Notification/actions)
  /// member of a notification action object.
  [propget] HRESULT Title([out, retval] LPWSTR* value);

  /// A string containing the URI of an icon to display with the action.
  /// This corresponds to the
  /// [icon](https://developer.mozilla.org/docs/Web/API/Notification/actions)
  /// member of a notification action object.
  [propget] HRESULT IconUri([out, retval] LPWSTR* value);
}

/// A collection of notification actions.
[uuid(89D8907E-18C7-458B-A970-F91F645E4C43), object, pointer_default(unique)]
interface ICoreWebView2NotificationActionCollectionView : IUnknown {
  /// The number of notification actions contained in the
  /// ICoreWebView2NotificationActionCollectionView.
  [propget] HRESULT Count([out, retval] UINT* value);

  /// Gets the notification action at the given index.
  HRESULT GetValueAtIndex([in] UINT index,
                          [out, retval] ICoreWebView2NotificationAction** value);
}

/// A collection of unsigned long integers.
[uuid(974A91F8-A309-4376-BC70-7537D686533B), object, pointer_default(unique)]
interface ICoreWebView2UnsignedLongCollection : IUnknown {
  /// The number of unsigned long integers contained in the
  /// ICoreWebView2UnsignedLongCollection.
  [propget] HRESULT Count([out, retval] UINT* value);

  /// Gets the unsigned long integer at the given index.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] UINT64* value);
}

/// The caller implements this interface to receive the result of reporting a notification clicked.
[uuid(1013C0D5-5F0C-4BF8-BA52-9D76AFA20E83), object, pointer_default(unique)]
interface ICoreWebView2NotificationReportClickedCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode);
}

/// The caller implements this interface to receive the result of reporting a notification closed.
[uuid(D8B63F74-1D78-4B4C-ACA9-7CB63FDFD74C), object, pointer_default(unique)]
interface ICoreWebView2NotificationReportClosedCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode);
}

/// This is the ICoreWebView2Notification that represents a [HTML Notification
/// object](https://developer.mozilla.org/docs/Web/API/Notification).
[uuid(E3F43572-2930-42EB-BD90-CAC16DE6D942), object, pointer_default(unique)]
interface ICoreWebView2Notification : IUnknown {
  /// Add an event handler for the `CloseRequested` event.
  /// This event is raised when the notification is closed by the web code, such as 
  /// through `notification.close()`.
  HRESULT add_CloseRequested(
      [in] ICoreWebView2NotificationCloseRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_CloseRequested`.
  HRESULT remove_CloseRequested(
      [in] EventRegistrationToken token);

  /// The host may run this to report the notification has been displayed and it
  /// will cause the [show](https://developer.mozilla.org/docs/Web/API/Notification/show_event)
  /// event to be raised for non-persistent notifications.
  /// You should only run this if you are handling the `NotificationReceived`
  /// event. Returns `E_ABORT` if `Handled` is `FALSE` when this is called.
  HRESULT ReportShown();

  /// The host may run this to report the notification has been clicked, and it
  /// will cause the
  /// [click](https://developer.mozilla.org/docs/Web/API/Notification/click_event)
  /// event to be raised for non-persistent notifications and the
  /// [notificationclick](https://developer.mozilla.org/docs/Web/API/ServiceWorkerGlobalScope/notificationclick_event)
  /// event for persistent notifications. Use `ReportClickedWithAction` to specify an
  /// action to activate a persistent notification.
  /// You should only run this if you are handling the `NotificationReceived`
  /// event. Returns `E_ABORT` if `Handled` is `FALSE` or `ReportShown` has not
  /// been run when this is called.
  HRESULT ReportClicked([in] ICoreWebView2NotificationReportClickedCompletedHandler* handler);

  /// The host may run this to report the persistent notification has been
  /// activated with a given action, and it will cause the
  /// [notificationclick](https://developer.mozilla.org/docs/Web/API/ServiceWorkerGlobalScope/notificationclick_event)
  /// event to be raised. The action index corresponds to the index in
  /// NotificationActionCollectionView. You should only run this if you are
  /// handling the `NotificationReceived` event. Returns `E_ABORT` if `Handled`
  /// is `FALSE` or `ReportShown` has not been run when this is called. Returns
  /// `E_INVALIDARG` if an invalid action index is provided. Use `ReportClicked`
  /// to activate an non-persistent notification.
  HRESULT ReportClickedWithAction([in] UINT actionIndex, [in] ICoreWebView2NotificationReportClickedCompletedHandler* handler);

  /// The host may run this to report the notification was dismissed, and it
  /// will cause the
  /// [close](https://developer.mozilla.org/docs/Web/API/Notification/close_event)
  /// event to be raised for non-persistent notifications and the
  /// [notificationclose](https://developer.mozilla.org/docs/Web/API/ServiceWorkerGlobalScope/notificationclose_event)
  /// event for persistent notifications. You should only run this if you are
  /// handling the `NotificationReceived` event. Returns `E_ABORT` if `Handled`
  /// is `FALSE` or `ReportShown` has not been run when this is called.
  HRESULT ReportClosed([in] ICoreWebView2NotificationReportClosedCompletedHandler* handler);

  /// A string representing the body text of the notification.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Body([out, retval] LPWSTR* value);

  /// Returns a JSON string representing the notification data.
  /// [Notification.data](https://developer.mozilla.org/docs/Web/API/Notification/data)
  /// DOM API is arbitrary data the notification sender wants associated with
  /// the notification and can be of any data type.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT DataAsJson([out, retval] LPWSTR* value);

  /// If the notification data is a string
  /// type, this method returns the value of that string.  If the notification data
  /// is some other kind of JavaScript type this method fails with `E_INVALIDARG`.
  /// [Notification.data](https://developer.mozilla.org/docs/Web/API/Notification/data)
  /// DOM API is arbitrary data the notification sender wants associated with
  /// the notification and can be of any data type.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  HRESULT TryGetDataAsString([out, retval] LPWSTR* value);

  /// The text direction in which to display the notification.
  /// This corresponds to
  /// [Notification.dir](https://developer.mozilla.org/docs/Web/API/Notification/dir)
  /// DOM API.
  /// The default value is `COREWEBVIEW2_TEXT_DIRECTION_KINDS_DEFAULT`.
  [propget] HRESULT Direction([out, retval] COREWEBVIEW2_TEXT_DIRECTION_KINDS* value);

  /// The notification's language, as intended to be specified using a string
  /// representing a language tag according to
  /// [BCP47](https://datatracker.ietf.org/doc/html/rfc5646). Note that no
  /// validation is performed on this property and it can be any string the
  /// notification sender specifies.
  /// This corresponds to
  /// [Notification.lang](https://developer.mozilla.org/docs/Web/API/Notification/lang)
  /// DOM API.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Language([out, retval] LPWSTR* value);

  /// A string representing an identifying tag for the notification.
  /// This corresponds to
  /// [Notification.tag](https://developer.mozilla.org/docs/Web/API/Notification/tag)
  /// DOM API.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Tag([out, retval] LPWSTR* value);

  /// A string containing the URI of an icon to be displayed in the
  /// notification.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT IconUri([out, retval] LPWSTR* value);

  /// The title of the notification.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Title([out, retval] LPWSTR* value);


  /// The actions available for users to choose from for interacting with the
  /// notification. An empty NotificationActionCollectionView is returned if no
  /// notification actions are specified. Note that actions are only applicable
  /// for persistent notifications according to the web standard, and an empty
  /// NotificationActionCollectionView will always be returned for
  /// non-persistent notifications.
  [propget] HRESULT Actions([out, retval] ICoreWebView2NotificationActionCollectionView** value);

  /// A string containing the URI of the image used to represent the
  /// notification when there isn't enough space to display the notification
  /// itself.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT BadgeUri([out, retval] LPWSTR* value);

  /// A string containing the URI of an image to be displayed in the
  /// notification.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT BodyImageUri([out, retval] LPWSTR* value);

  /// Specifies whether the user should be notified after a new notification
  /// replaces an old one.
  /// This corresponds to
  /// [Notification.renotify](https://developer.mozilla.org/docs/Web/API/Notification/renotify)
  /// DOM API.
  /// The default value is `FALSE`.
  [propget] HRESULT ShouldRenotify([out, retval] BOOL* value);

  /// A boolean value indicating that a notification should remain active until
  /// the user clicks or dismisses it, rather than closing automatically.
  /// This corresponds to
  /// [Notification.requireInteraction](https://developer.mozilla.org/docs/Web/API/Notification/requireInteraction)
  /// DOM API.
  /// The default value is `FALSE`.
  [propget] HRESULT RequiresInteraction([out, retval] BOOL* value);

  /// Specifies whether the notification should be silent — i.e., no sounds or
  /// vibrations should be issued, regardless of the device settings.
  /// This corresponds to
  /// [Notification.silent](https://developer.mozilla.org/docs/Web/API/Notification/silent)
  /// DOM API.
  /// The default value is `FALSE`.
  [propget] HRESULT IsSilent([out, retval] BOOL* value);

  /// Specifies the time at which a notification is created or applicable (past,
  /// present, or future) as the number of milliseconds since the UNIX epoch.
  [propget] HRESULT Timestamp([out, retval] double* value);

  /// Specifies a vibration pattern for devices with vibration hardware to emit.
  /// The vibration pattern can be represented by an array of integers
  /// describing a pattern of vibrations and pauses. See [Vibration
  /// API](https://developer.mozilla.org/docs/Web/API/Vibration_API) for more
  /// information.
  /// This corresponds to
  /// [Notification.vibrate](https://developer.mozilla.org/docs/Web/API/Notification/vibrate)
  /// DOM API.
  /// An empty UnsignedLongCollection is returned if no vibration patterns are
  /// specified.
  [propget] HRESULT VibrationPattern([out, retval] ICoreWebView2UnsignedLongCollection** value);
}
```

```csharp
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2TextDirectionKinds
    {
        Default = 0,
        LeftToRight = 1,
        RightToLeft = 2,
    };
    runtimeclass CoreWebView2NotificationAction
    {
        // ICoreWebView2NotificationAction members
        String Action { get; };
        String Title { get; };
        String IconUri { get; };
    }
    runtimeclass CoreWebView2Profile
    {
        ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile3")]
        {
            // ICoreWebView2Profile3 members
            event Windows.Foundation.TypedEventHandler<CoreWebView2Profile, CoreWebView2NotificationReceivedEventArgs> NotificationReceived;
        }
        ...
    }
    runtimeclass CoreWebView2
    {
        ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_17")]
        {
            // ICoreWebView2_17 members
            event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2NotificationReceivedEventArgs> NotificationReceived;
        }
        ...
    }
    runtimeclass CoreWebView2NotificationReceivedEventArgs
    {
        // ICoreWebView2NotificationReceivedEventArgs members
        String Uri { get; };
        CoreWebView2Notification Notification { get; };
        Boolean Handled { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2Notification
    {
        // ICoreWebView2Notification members
        String Body { get; };
        CoreWebView2NotificationDirectionKinds Direction { get; };
        String Language { get; };
        String Tag { get; };
        String IconUri { get; };
        String Title { get; };
        IVectorView<CoreWebView2NotificationAction> Actions { get; };
        String BadgeUri { get; };
        String ImageUri { get; };
        Boolean Renotify { get; };
        Boolean RequireInteraction { get; };
        Boolean Silent { get; };
        Double Timestamp { get; };
        IVectorView<UInt64> Vibrate { get; };
        String DataAsJson { get; };
        String TryGetDataAsString();

        event Windows.Foundation.TypedEventHandler<CoreWebView2Notification, Object> CloseRequested;

        void ReportShown();
        Windows.Foundation.IAsyncAction ReportClickedAsync();
        Windows.Foundation.IAsyncAction ReportClickedAsync(UInt32 actionIndex);
        Windows.Foundation.IAsyncAction ReportClosedAsync();
    }
}
```
