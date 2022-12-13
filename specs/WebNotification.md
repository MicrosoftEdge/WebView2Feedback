Web Notification APIs
===

# Background

The WebView2 team is adding support for Web notifications. End developers should
be able to handle notification permission requests, and further listen to
`NotificationReceived` events to optionally handle the notifications themselves.
The `NotificationReceived` events are raised on `CorebWebView2` and
`CoreWebView2Profile` object respectively for non-persistent and persistent
notifications respectively.

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
`PermissionRequested` event used to not be raised for `PermissionKind.Notification`.
Now, `PermissionRequested` events are raised for `PermissionKind.Notification`, and `PermissionState` needs to be set `Allow` explicitly to allow such permission requests. `PermissionState.Default` for `PermissionKind.Notification` is considered denied.

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
                        break;
                    case MessageBoxResult.No:
                        args.State = CoreWebView2PermissionState.Deny;
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
    var notification = args.Notification;

    // Show notification with local MessageBox
    string message = "Received notification from " + args.Uri + " with body " + notification.Body;
    MessageBox.Show(message);

    // Requires Microsoft.Toolkit.Uwp.Notifications NuGet package version 7.0 or greater
    var toastContent = new ToastContentBuilder()
        .AddArgument("conversationId", m_id)
        .AddText("Notification sent from " + args.Uri +":\n")
        .AddText(notification.Body);
    toastContent.Show();
    // See
    // https://learn.microsoft.com/windows/apps/design/shell/tiles-and-notifications/send-local-toast?tabs=uwp
    // for how to handle toast activation

    notification.Show();
    notification.Close();
    args.Handled = true;
}
```

### C++ Sample
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
                // Block notifications from specific URIs and set Handled to
                // false so the the default notification UI will not be
                // shown by WebView2 either.
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_Uri(&uri);
                if (ShouldBlockUri(uri.get()))
                {
                    CHECK_FAILURE(args->put_Handled(FALSE));
                }
                ShowNotification(args);
                return S_OK;
            })
            .Get(),
        &m_notificationReceivedToken));
    //! [NotificationReceived]
    }
...
//! [OnNotificationReceived]
void SettingsComponent::ShowNotification(
    ICoreWebView2NotificationReceivedEventArgs* args)
{
    AppWindow* appWindow = m_appWindow;

    // Obtain a deferral for the event so that the CoreWebView2
    // does not examine the properties we set on the event args and
    // after we call the Complete method asynchronously later.
    wil::com_ptr<ICoreWebView2Deferral> deferral;
    CHECK_FAILURE(args->GetDeferral(&deferral));

    wil::com_ptr<ICoreWebView2NotificationReceivedEventArgs> eventArgs = args;

    appWindow->RunAsync(
        [this, eventArgs, deferral]
        {
            wil::com_ptr<ICoreWebView2Notification> notification;
            CHECK_FAILURE(eventArgs->get_Notification(&notification));

            wil::unique_cotaskmem_string uri;
            CHECK_FAILURE(eventArgs->get_Uri(&uri));
            wil::unique_cotaskmem_string title;
            CHECK_FAILURE(notification->get_Title(&title));
            wil::unique_cotaskmem_string body;
            CHECK_FAILURE(notification->get_Body(&body));

            std::wstring message =
                L"The page at " + std::wstring(uri.get()) + L" sends you an
                notification:\n\n";
            message += body.get();
            notification->Show();
            int response = MessageBox(nullptr, message.c_str(), title.get(), MB_OKCANCEL);
            (response == IDOK) ? notification->Click() : notification->Close();

            deferral->Complete();
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
  HRESULT add_NotificationReceived(
      [in] ICoreWebView2PersistentNotificationReceivedEventHandler* eventHandler,
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
interface ICoreWebView2PersistentNotificationReceivedEventHandler : IUnknown {
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
  /// The origin of the web content that sends the notification.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Uri([out, retval] LPWSTR* value);

  /// The notification that was received. End developers can access the
  /// properties on the Notification object to show their own notification. 
  [propget] HRESULT Notification([out, retval] ICoreWebView2Notification** value);
  
  /// Sets whether the `NotificationReceived` event is handled by the host after
  /// the event handler completes or if there is a deferral then after the
  /// deferral is completed.
  ///
  /// If `Handled` is set to TRUE then WebView will not display the notification
  /// with the default UI, and the host will be responsible for handling the
  /// notification and for letting the web content know that the notification has been
  /// displayed, clicked, or closed. If after the event handler or deferral
  /// completes `Handled` is set to FALSE then WebView will display the default
  /// notification UI. Note that if `Show` has been called on the `Notification`
  /// object, WebView will not display the default notification regardless of
  /// the Handled property. The default value is FALSE.
  [propput] HRESULT Handled([in] BOOL value);

  /// Gets whether the `NotificationReceived` event is handled by host.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

/// An event handler for the `Closed` event.
[uuid(6A0B4DE9-8CBE-4211-BAEF-AC037B1A72DE), object, pointer_default(unique)]
interface ICoreWebView2NotificationClosedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Notification* sender,
      [in] IUnknown* args);
}

/// This is the notification for interacting with the notification.
[uuid(07DD3067-2B86-47F6-AB96-D74825C2DA41), object, pointer_default(unique)]
interface ICoreWebView2NotificationAction : IUnknown {
  /// A string identifying a user action to be displayed on the notification.
  [propget] HRESULT Action([out, retval] LPWSTR* value);

  /// A string containing action text to be shown to the user.
  [propget] HRESULT Title([out, retval] LPWSTR* value);

  /// A string containing the URI of an icon to display with the action.
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

/// This is the ICoreWebView2Notification that represents a [HTML Notification
/// object](https://developer.mozilla.org/docs/Web/API/Notification).
[uuid(E3F43572-2930-42EB-BD90-CAC16DE6D942), object, pointer_default(unique)]
interface ICoreWebView2Notification : IUnknown {
  /// Add an event handler for the `Closed` event.
  /// This event is raised when the notification is closed by the web code.
  HRESULT add_Closed(
      [in] ICoreWebView2NotificationClosedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_Closed`.
  HRESULT remove_Closed(
      [in] EventRegistrationToken token);

  /// The host may run this to report the notification has been displayed.
  /// The NotificationReceived event is considered handled regardless of the
  /// Handled property of the NotifificationReceivedEventArgs if the host has
  /// run Show().
  HRESULT Show();

  /// The host may run this to report the notification has been clicked. Use
  /// `ClickWithAction` to specify an action to activate a persistent
  /// notification. This will no-op if `Show` is not run or `Close` has been
  /// run.
  HRESULT Click();

  /// The host may run this to report the persistent notification has been
  /// activated with a given action. The action index corresponds to the index
  /// in NotificationActionCollectionView. This returns `E_INVALIDARG` if an invalid
  /// action index is provided. Use `Click` to activate an non-persistent
  /// notification. This will no-op if `Show` is not run or `Close` has been
  /// run.
  HRESULT ClickWithAction([in] UINT actionIndex);

  /// The host may run this to report the notification was dismissed.
  /// This will no-op if `Show` is not run or `Click` has been run.
  HRESULT Close();

  /// The body string of the notification as specified in the constructor's
  /// options parameter.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Body([out, retval] LPWSTR* value);

  /// Returns an IDataObject that represents a structured clone of the
  /// notification's data.
  /// Returns `null` if the optional Notification property does not exist.
  [propget] HRESULT Data([out, retval] IDataObject** value);

  /// The text direction of the notification as specified in the constructor's
  /// options parameter.
  /// The default value is `COREWEBVIEW2_TEXT_DIRECTION_KINDS_DEFAULT`.
  [propget] HRESULT Direction([out, retval] COREWEBVIEW2_TEXT_DIRECTION_KINDS* value);

  /// The language code of the notification as specified in the constructor's
  /// options parameter. It is in the format of
  /// `language-country` where `language` is the 2-letter code from [ISO
  /// 639](https://www.iso.org/iso-639-language-codes.html) and `country` is the
  /// 2-letter code from [ISO 3166](https://www.iso.org/standard/72482.html).
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Language([out, retval] LPWSTR* value);

  /// The ID of the notification (if any) as specified in the constructor's
  /// options parameter.
  /// The default value is an empty string.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Tag([out, retval] LPWSTR* value);

  /// The URI of the image used as an icon of the notification as specified in
  /// the constructor's options parameter.
  /// Returns `null` if the optional Notification property does not exist.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT IconUri([out, retval] LPWSTR* value);

  /// The title of the notification as specified in the first parameter of the
  /// constructor.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Title([out, retval] LPWSTR* value);


  /// The actions available for users to choose from for interacting with the
  /// notification. Note that actions are only supported for persistent notifications.
  /// An empty NotificationActionCollectionView is returned if no notification actions.
  [propget] HRESULT Actions([out, retval] ICoreWebView2NotificationActionCollectionView** value);

  /// The URI of the image used to represent the notification when there is not
  /// enough space to display the notification itself.
  /// Returns `null` if the optional Notification property does not exist.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT BadgeUri([out, retval] LPWSTR* value);

  /// The URI of an image to be displayed as part of the notification.
  /// Returns `null` if the optional Notification property does not exist.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ImageUri([out, retval] LPWSTR* value);

  /// Specifies whether the user should be notified after a new notification
  /// replaces an old one.
  /// The default value is `FALSE`.
  [propget] HRESULT Renotify([out, retval] BOOL* value);

  /// A boolean value indicating that a notification should remain active until
  /// the user clicks or dismisses it, rather than closing automatically.
  /// The default value is `FALSE`.
  [propget] HRESULT RequireInteraction([out, retval] BOOL* value);

  /// Specifies whether the notification should be silent — i.e., no sounds or
  /// vibrations should be issued, regardless of the device settings.
  /// The default value is `FALSE`.
  [propget] HRESULT Silent([out, retval] BOOL* value);

  /// Specifies the time at which a notification is created or applicable (past,
  /// present, or future).
  /// Returns `null` if the optional Notification property does not exist.
  [propget] HRESULT Timestamp([out, retval] double* value);

  /// Specifies a vibration pattern for devices with vibration hardware to emit.
  /// Returns `null` if the optional Notification property does not exist.
  [propget] HRESULT Vibrate([out, retval] ICoreWebView2UnsignedLongCollection** value);
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
        // TODO: What should the proper data type be for 
        // CoreWebView2Notification.Data? We use IDataObject for COM/C++.
        // Data { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2Notification, Object> Closed;

        void Show();
        void Click();
        void Click(UInt32 actionIndex);
        void Close();
    }
}
```
