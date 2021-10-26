# Background


# Description


# Examples
## C++: Regestering IFrame Permission Requested Handler

``` cpp
wil::com_ptr<ICoreWebView2> m_webview;

EventRegistrationToken m_frameCreatedToken = {};
EventRegistrationToken m_permissionRequestedToken = {};

void RegisterIFramePermissionRequestedHandler()
{
    webview4 = m_webview.try_query<ICoreWebView2_4>();
    if (webview4)
    {
        CHECK_FAILURE(webview4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));

                    auto webviewFrame2 = webviewFrame.try_query<ICoreWebView2Frame2>();
                    if (webviewFrame2)
                    {
                        CHECK_FAILURE(webviewFrame2->add_PermissionRequested(
                            Callback<ICoreWebView2FramePermissionRequestedEventHandler>(
                                [this](ICoreWebView2Frame* sender,
                                   ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
                                    COREWEBVIEW2_PERMISSION_KIND kind =
                                        COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
                                    BOOL userInitiated = FALSE;
                                    wil::unique_cotaskmem_string uri;

                                    CHECK_FAILURE(args->get_PermissionKind(&kind));
                                    CHECK_FAILURE(args->get_IsUserInitiated(&userInitiated));
                                    CHECK_FAILURE(args->get_Uri(&uri));

                                    auto cached_key = std::tuple<
                                        std::wstring, COREWEBVIEW2_PERMISSION_KIND, BOOL>(
                                        std::wstring(uri.get()), kind, userInitiated);

                                    auto cached_permission =
                                        m_cached_permissions.find(cached_key);
                                    if (cached_permission != m_cached_permissions.end())
                                    {
                                        bool allow = cached_permission->second;
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
                                    message += SettingsComponent::NameOfPermissionKind(kind);
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
                                        m_cached_permissions[cached_key] = true;
                                        state = COREWEBVIEW2_PERMISSION_STATE_ALLOW;
                                    }
                                    else if (response == IDNO)
                                    {
                                        m_cached_permissions[cached_key] = false;
                                        state = COREWEBVIEW2_PERMISSION_STATE_DENY;
                                    }

                                    CHECK_FAILURE(args->put_State(state));

                                    PutHandled(args);
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
    if (args2) {
        CHECK_FAILURE(args2->put_Handled(true));
    }
}
```

## C#: TBD
```c#

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
  /// `PermissionRequested` is raised when content in an iframe requests
  /// permission to access some priveleged resources.
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

```
