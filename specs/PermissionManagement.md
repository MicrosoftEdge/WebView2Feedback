Permission Management APIs
===

# Background

The WebView2 team is adding support for more permission management scenarios. With the
extended `PermissionRequested` event args and new permission APIs you will be able to:
- Set permission for a site at any time
- List all nondefault permissions
- Control more permission kinds

The new `SavesInProfile` property on the `PermissionRequestedEventArgs` lets you
turn off the caching of permission state so that you can intercept all permission
requests. By default, state set from the `PermissionRequested` event handler and default
permission UI is saved across sessions and you may stop receiving PermissionRequested
events for some permission kinds.

The new APIs, `SetPermission` and `GetNonDefaultPermissionSettings`, provide
all the information necessary to build a permission management page where a
user can view and modify existing site permissions. The new permission kinds we will
support are: local font list, automatic downloads, media autoplay, file editing, and
system exclusive MIDI access.

See already supported [permission kinds](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1418.22#corewebview2_permission_kind)
and existing [event args](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionrequestedeventargs?view=webview2-dotnet-1.0.1418.22).


# Examples

## Extended PermissionRequestedEventArgs: SavesInProfile
### C# Sample
```c#
IDictionary<(string, CoreWebView2PermissionKind, bool), bool> _cachedPermissions =
    new Dictionary<(string, CoreWebView2PermissionKind, bool), bool>();

// In this example, the app listens to all requests and caches permission on its own
// to decide whether to show custom UI to the user.
void WebView_PermissionRequested(object sender, CoreWebView2PermissionRequestedEventArgs args)
{
    // Obtain a deferral for the event so that the CoreWebView2 doesn't examine
    // the properties set on the event args until after the dialog is closed.
    CoreWebView2Deferral deferral = args.GetDeferral();

    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        using (deferral)
        {
            // Do not save state to the profile so that the PermissionRequested
            // event is always raised and the app is in control of all
            // permission requests.
            args.SavesInProfile = false;
            CoreWebView2PermissionState state = CoreWebView2PermissionState.Default;
            var cachedKey =
                (args.Uri, args.PermissionKind, args.IsUserInitiated);
            if (_cachedPermissions.ContainsKey(cachedKey))
            {
                state = _cachedPermissions[cachedKey]
                    ? CoreWebView2PermissionState.Allow
                    : CoreWebView2PermissionState.Deny;
            }
            else
            {
                var allowed = ShowPermissionDialog(
                    args.Uri, args.PermissionKind, args.IsUserInitiated);
                state = allowed ? CoreWebView2PermissionState.Allow
                                : CoreWebView2PermissionState.Deny;
                _cachedPermissions[cachedKey] = allowed;
            }
            args.State = state;
        }
    }, null);
}
```

### C++ Sample
```cpp
std::map<std::tuple<std::wstring, COREWEBVIEW2_PERMISSION_KIND, BOOL>, bool>
    m_cachedPermissions;

// In this example, the app listens to all requests and caches permission on its own
// to decide whether to show custom UI to the user.
HRESULT SettingsComponent::OnPermissionRequested(
    ICoreWebView2* sender, ICoreWebView2PermissionRequestedEventArgs* args)
{
    // Obtain a deferral for the event so that the CoreWebView2
    // doesn't examine the properties we set on the event args until
    // after we call the Complete method asynchronously later.
    wil::com_ptr<ICoreWebView2Deferral> deferral;
    CHECK_FAILURE(args->GetDeferral(&deferral));

    // Do not save state to the profile so that the PermissionRequested event is
    // always raised and the app is in control of all permission requests.
    auto extendedArgs = args.try_query<ICoreWebView2PermissionRequestedEventArgs3>();
    if (extendedArgs)
    {
        CHECK_FAILURE(extendedArgs->put_SavesInProfile(FALSE));
    }

    // Do the rest asynchronously, to avoid calling dialog in an event handler.
    m_appWindow->RunAsync([this, deferral,
        args = wil::com_ptr<ICoreWebView2PermissionRequestedEventArgs>(args)]
    {
        wil::unique_cotaskmem_string uri;
        COREWEBVIEW2_PERMISSION_KIND kind = COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
        BOOL userInitiated = FALSE;
        CHECK_FAILURE(args->get_Uri(&uri));
        CHECK_FAILURE(args->get_PermissionKind(&kind));
        CHECK_FAILURE(args->get_IsUserInitiated(&userInitiated));

        COREWEBVIEW2_PERMISSION_STATE state = COREWEBVIEW2_PERMISSION_STATE_DEFAULT;
        auto cachedKey = std::make_tuple(std::wstring(uri.get()), kind, userInitiated);
        auto cachedPermission = m_cachedPermissions.find(cachedKey);
        if (cachedPermission != m_cachedPermissions.end())
        {
            state =
                (cachedPermission->second ? COREWEBVIEW2_PERMISSION_STATE_ALLOW
                                          : COREWEBVIEW2_PERMISSION_STATE_DENY);
        }
        else
        {
            bool allowed = ShowPermissionDialog(uri, kind, userInitiated);
            state = (allowed ? COREWEBVIEW2_PERMISSION_STATE_ALLOW
                             : COREWEBVIEW2_PERMISSION_STATE_DENY);
            m_cachedPermissions[cachedKey] = allowed;
        }
        CHECK_FAILURE(args->put_State(state));
        CHECK_FAILURE(deferral->Complete());
    });
    return S_OK;
}
```
## SetPermission and GetNonDefaultPermissionSettings
SetPermission allows the app to change the permissions granted to the WebView outside
of a PermissionRequested event.

GetNonDefaultPermissionSettings returns a collection of permissions previously granted
or denied to the WebView.
### C# Sample
```c#
// Gets the nondefault permission collection and updates a custom permission
// management page.
async void WebView_PermissionManager_DOMContentLoaded(object sender,
    CoreWebView2DOMContentLoadedEventArgs arg)
{
    // Permission management APIs are only used on the app's permission
    // management page.
    if (webView.CoreWebView2.Source !=
        "https://appassets.example/ScenarioPermissionManagement.html")
    {
        return;
    }
    // Get all the nondefault permissions and post them to the app's
    // permission management page. The permission management page can present
    // a list of custom permissions set for this profile and let the end user
    // modify them.
    IReadOnlyList<CoreWebView2PermissionSetting> permissionList =
        await webView.CoreWebView2.Profile.GetNonDefaultPermissionSettingsAsync();
    foreach (CoreWebView2PermissionSetting setting in permissionList)
    {
        string reply = "{\"PermissionSetting\": \"" +
                        PermissionKindToString(setting.PermissionKind) + ", " +
                        setting.Origin + ", " +
                        PermissionStateToString(setting.State) +
                        "\"}";
        webView.CoreWebView2.PostWebMessageAsJson(reply);
    }
}

// Called when the user wants to change permission state from the custom
// permission management page.
void WebView_PermissionManager_WebMessageReceived(object sender,
    CoreWebView2WebMessageReceivedEventArgs args)
{
    // Permission management APIs are only used on the app's permission
    // management page.
    if (args.Source !=
        "https://appassets.example/ScenarioPermissionManagement.html")
    {
        return;
    }
    string message = args.TryGetWebMessageAsString();
    // The app's permission management page can provide a way for the
    // end user to change permissions. For example, the page can have a
    // `Set Permission` button that triggers a dialog, where the user
    // specifies the desired origin, permission kind, and state.
    if (message == "SetPermission")
    {
        // Avoid potential reentrancy from running a message loop in the
        // event handler.
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            var dialog = new SetPermissionDialog();
            if (dialog.ShowDialog() == true)
            {
                SetPermissionState(
                    (CoreWebView2PermissionKind)dialog.PermissionKind.SelectedItem,
                    dialog.Origin.Text,
                    (CoreWebView2PermissionState)dialog.PermissionState.SelectedItem);
            }
        }, null);
    }
}

async void SetPermissionState(CoreWebView2PermissionKind kind, string origin,
    CoreWebView2PermissionState state)
{
    // Example: webView.CoreWebView2.Profile.SetPermissionState(
    //    CoreWebView2PermissionKind.Geolocation,
    //    "https://example.com",
    //    CoreWebView2PermissionState.Deny);
    await webView.CoreWebView2.Profile.SetPermissionStateAsync(
        kind, origin, state);
    // Reload the permission management page.
    webView.Reload();
}
```

### C++ Sample
```cpp
std::wstring m_sampleUri;

ScenarioPermissionManagement::ScenarioPermissionManagement(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    m_sampleUri = m_appWindow->GetLocalUri(c_samplePath);
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    wil::com_ptr<ICoreWebView2Profile> profile;
    if (!webView2_13)
    {
        return;
    }
    CHECK_FAILURE(webView2_13->get_Profile(&profile));
    m_webViewProfile6 = profile.try_query<ICoreWebView2Profile6>();
    if (!m_webViewProfile6)
    {
        return;
    }
    m_webView2 = m_webView.try_query<ICoreWebView2_2>();
    if (m_webView2)
    {
        CHECK_FAILURE(m_webView2->add_DOMContentLoaded(
            Callback<ICoreWebView2DOMContentLoadedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2DOMContentLoadedEventArgs* args)
                    -> HRESULT
                {
                    wil::unique_cotaskmem_string source;
                    CHECK_FAILURE(sender->get_Source(&source));
                    // Permission management APIs are only used on the app's
                    // permission management page.
                    if (source.get() != m_sampleUri)
                    {
                        return S_OK;
                    }
                    // Get all the nondefault permissions and post them to the
                    // app's permission management page. The permission management
                    // page can present a list of custom permissions set for this
                    // profile and let the end user modify them.
                    CHECK_FAILURE(m_webViewProfile6->GetNonDefaultPermissionSettings(
                        Callback<
                            ICoreWebView2GetNonDefaultPermissionSettingsCompletedHandler>(
                            [this, sender](
                                HRESULT code, ICoreWebView2PermissionSettingCollection*
                                                  permissionSettingCollection) -> HRESULT
                            {
                                UINT32 count;
                                permissionSettingCollection->get_Count(&count);
                                for (UINT32 i = 0; i < count; i++)
                                {
                                    wil::com_ptr<ICoreWebView2PermissionSetting>
                                        setting;
                                    CHECK_FAILURE(
                                        permissionSettingCollection->GetValueAtIndex(i, &setting));
                                    COREWEBVIEW2_PERMISSION_KIND kind;
                                    CHECK_FAILURE(
                                        setting->get_PermissionKind(&kind));
                                    std::wstring kind_string =
                                        PermissionKindToString(kind);
                                    COREWEBVIEW2_PERMISSION_STATE state;
                                    CHECK_FAILURE(setting->get_State(&state));
                                    wil::unique_cotaskmem_string origin;
                                    CHECK_FAILURE(setting->get_Origin(&origin));
                                    std::wstring state_string =
                                        PermissionStateToString(state);
                                    std::wstring reply = L"{\"PermissionSetting\": \"" +
                                                          kind_string + L", " +
                                                          origin.get() + L", " +
                                                          state_string + L"\"}";
                                    CHECK_FAILURE(
                                        sender->PostWebMessageAsJson(reply.c_str()));
                                }
                                return S_OK;
                            })
                            .Get()));
                    return S_OK;
                })
                .Get(),
            &m_DOMContentLoadedToken));
    }

    // Called when the user wants to change permission state from the custom
    // permission management page.
    CHECK_FAILURE(m_webView->add_WebMessageReceived(
        Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args)
                -> HRESULT
            {
                wil::unique_cotaskmem_string source;
                CHECK_FAILURE(args->get_Source(&source));
                // Permission management APIs are only used on the app's
                // permission management page.
                if (source.get() != m_sampleUri)
                {
                    return S_OK;
                }
                wil::unique_cotaskmem_string message;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&message));
                // The app's permission management page can provide a way for the
                // end user to change permissions. For example, the page can have a
                // `Set Permission` button that triggers a dialog, where the user
                // specifies the desired origin, permission kind, and state.
                if (wcscmp(message.get(), L"SetPermission") == 0)
                {
                    m_appWindow->RunAsync([this] { ShowSetPermissionDialog(); });
                }
                return S_OK;
            })
            .Get(),
        &m_webMessageReceivedToken));
}

void ScenarioPermissionManagement::ShowSetPermissionDialog()
{
    PermissionDialog dialog(m_appWindow->GetMainWindow());
    if (dialog.confirmed && m_webViewProfile6)
    {
        // Example: m_webViewProfile6->SetPermissionState(
        //    COREWEBVIEW2_PERMISSION_KIND_GEOLOCATION,
        //    L"https://example.com",
        //    COREWEBVIEW2_PERMISSION_STATE_DENY,
        //    SetPermissionStateCallback);
        CHECK_FAILURE(m_webViewProfile6->SetPermissionState(
            dialog.kind, dialog.origin.c_str(), dialog.state,
            Callback<ICoreWebView2SetPermissionStateCompletedHandler>(
            [this](HRESULT error) -> HRESULT
            {
                // Reload the permission management page.
                m_webView->Reload();
                return S_OK;
            })
            .Get()));
    }
}
```
# API Details

```
[v1_enum]
typedef enum COREWEBVIEW2_PERMISSION_KIND {

  // Other permission kinds not shown.

  /// Indicates permission to automatically download multiple files. Permission
  /// is requested when multiple downloads are triggered in quick succession.
  COREWEBVIEW2_PERMISSION_KIND_MULTIPLE_AUTOMATIC_DOWNLOADS,

  /// Indicates permission to read and write to files or folders on the device. Permission
  /// is requested when developers use the [File System Access API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API)
  /// to show the file or folder picker to the end user, and then request "readwrite"
  /// permission for the user's selection.
  COREWEBVIEW2_PERMISSION_KIND_FILE_READ_WRITE,

  /// Indicates permission to play audio and video automatically on sites. This
  /// permission affects the autoplay attribute and play method of the audio and video
  /// HTML elements, and the start method of the Web Audio API. See the
  /// [Autoplay guide for media and Web Audio APIs](https://developer.mozilla.org/en-US/docs/Web/Media/Autoplay_guide)
  /// for details.
  COREWEBVIEW2_PERMISSION_KIND_AUTOPLAY,

  /// Indicates permission to use fonts on the device. Permission is requested when
  /// developers use the [Local Font Access API](https://wicg.github.io/local-font-access/)
  /// to query the system fonts available for styling web content.
  COREWEBVIEW2_PERMISSION_KIND_LOCAL_FONTS,

  /// Indicates permission for a site to use system exlusive messages to access
  /// Musical Instrument Digital Interface (MIDI) devices. Permission is requested
  /// when developers use the [Web MIDI API](https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API)
  /// to request system exclusive MIDI access.
  COREWEBVIEW2_PERMISSION_KIND_MIDI_SYSEX,
} COREWEBVIEW2_PERMISSION_KIND;

/// This is a continuation of the `ICoreWebView2PermissionRequestedEventArgs`
/// interface.
[uuid(08595a19-44f0-41b1-9ae4-5889f5edadcb), object, pointer_default(unique)]
interface ICoreWebView2PermissionRequestedEventArgs3: IUnknown {
  /// The permission state set from the `PermissionRequested` event is saved in
  /// the profile by default; it persists across sessions and becomes the new
  /// default behavior for future `PermissionRequested` events. Browser
  /// heuristics can affect whether the event continues to be raised when the
  /// state is saved in the profile. Set the `SavesInProfile` property to
  /// `FALSE` to not persist the state beyond the current request, and to
  /// continue to receive `PermissionRequested`
  /// events for this origin and permission kind.
  [propget] HRESULT SavesInProfile([out, retval] BOOL* value);

  /// Sets the `SavesInProfile` property.
  [propput] HRESULT SavesInProfile([in] BOOL value);
}

/// This is the ICoreWebView2 interface for the permission management APIs.
[uuid(5bdfc5dd-C07a-41b7-bcf2-94020975f185), object, pointer_default(unique)]
interface ICoreWebView2Profile6 : ICoreWebView2Profile5 {
  /// Sets permission state for the given permission kind and origin
  /// asynchronously. The change persists across sessions until it is changed by
  /// another call to `SetPermissionState`, or by setting the `State` property
  /// in `PermissionRequestedEventArgs`. Setting the state to
  /// `COREWEBVIEW2_PERMISSION_STATE_DEFAULT` will erase any state saved in the
  /// profile and restore the default behavior.
  /// The origin should have a valid scheme and host (e.g. "https://www.example.com"),
  /// otherwise the method fails with `E_INVALIDARG`. Additional URI parts like
  /// path and fragment are ignored. For example, "https://wwww.example.com/app1/index.html/"
  /// is treated the same as "https://wwww.example.com". See the
  /// [MDN origin definition](https://developer.mozilla.org/en-US/docs/Glossary/Origin) for more details.
  HRESULT SetPermissionState(
        [in] COREWEBVIEW2_PERMISSION_KIND permissionKind,
        [in] LPCWSTR origin,
        [in] COREWEBVIEW2_PERMISSION_STATE state,
        [in] ICoreWebView2SetPermissionStateCompletedHandler* completedHandler);

  /// Invokes the handler with a collection of all nondefault permission settings.
  /// Use this method to get the permission state set in the current and previous
  /// sessions.
  HRESULT GetNonDefaultPermissionSettings(
      [in] ICoreWebView2GetNonDefaultPermissionSettingsCompletedHandler*
          completedHandler);
}

/// The caller implements this interface to handle the result of
/// `SetPermissionState`.
[uuid(83972f3b-0716-4f78-b2ae-cc60d2bb807c), object, pointer_default(unique)]
interface ICoreWebView2SetPermissionStateCompletedHandler : IUnknown {
  /// Provide the completion status of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode);
}

/// The caller implements this interface to handle the result of
/// `GetNonDefaultPermissionSettings`.
[uuid(64889aec-34d0-47e3-86ed-a4df204f8dcf), object, pointer_default(unique)]
interface
ICoreWebView2GetNonDefaultPermissionSettingsCompletedEventHandler : IUnknown {
  /// Provides the permission setting collection for the requested permission kind.
  HRESULT Invoke([in] HRESULT errorCode,
      [in] ICoreWebView2PermissionSettingCollection* permissionSettingCollection);
}

/// Collection of `PermissionSetting`s (origin, kind, and state). Used to list
/// the nondefault permission settings on the profile that are persisted across
/// sessions.
[uuid(d862e9e0-67e7-4a33-ba7d-7db22c82f74d), object, pointer_default(unique)]
interface ICoreWebView2PermissionSettingCollection : IUnknown {
  /// Gets the `ICoreWebView2PermissionSetting` at the specified index.
  HRESULT GetValueAtIndex([in] UINT32 index,
                          [out, retval] ICoreWebView2PermissionSetting** permissionSetting);

  /// The number of `ICoreWebView2PermissionSetting`s in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);
}

/// Provides a set of properties for a permission setting.
[uuid(9c78a547-d008-49d8-a5e2-a3021976c755), object, pointer_default(unique)]
interface ICoreWebView2PermissionSetting : IUnknown {
  /// The kind of the permission setting. See `COREWEBVIEW2_PERMISSION_KIND` for
  /// more details.
  [propget] HRESULT PermissionKind([out, retval] COREWEBVIEW2_PERMISSION_KIND*
      value);

  /// The origin of the permission setting.
  [propget] HRESULT Origin([out, retval] LPWSTR* value);

  /// The state of the permission setting.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_PERMISSION_STATE* value);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2PermissionKind
    {
        // Other permission kinds not shown.

        // Indicates permission to automatically download multiple files.
        // Permission is requested whenever multiple downloads are triggered in
        // quick succession.
        MultipleAutomaticDownloads = 7,

        // Indicates permission to read and write to files or folders on the device.
        // Permission is requested when developers use the [File System Access API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API)
        // to show the file or folder picker to the end user, and then request
        // "readwrite" permission for the user's selection.
        FileReadWrite = 8,

        // Indicates permission to play audio and video automatically on sites. This
        // permission affects the autoplay attribute and play method of the audio and
        // video HTML elements, and the start method of the Web Audio API. See the
        // [Autoplay guide for media and Web Audio APIs](https://developer.mozilla.org/en-US/docs/Web/Media/Autoplay_guide)
        // for details.
        Autoplay = 9,

        // Indicates permission to use fonts on the device. Permission is requested when
        // developers use the [Local Font Access API](https://wicg.github.io/local-font-access/)
        // to query the system fonts available for styling web content.
        LocalFonts = 10,


        // Indicates permission for a site to use system exlusive messages to access
        // Musical Instrument Digital Interface (MIDI) devices. Permission is requested
        // when developers use the [Web MIDI API](https://developer.mozilla.org/en-US/docs/Web/API/Web_MIDI_API)
        // to request system exclusive MIDI access.
        MidiSysex = 11,
    };
}

namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2PermissionRequestedEventArgs
    {
        // Other members not shown.

        // The permission state set from the `PermissionRequested` event is
        // saved in the profile by default; it persists across sessions and
        // becomes the new default behavior for future `PermissionRequested` events.
        // Browser heuristics can affect whether the event continues to be raised
        // when the state is saved in the profile. Set the `SavesInProfile`
        // property to `FALSE` to not persist the state beyond the current request,
        // and to continue to receive `PermissionRequested` events for this origin
        // and permission kind.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2PermissionRequestedEventArgs3")]
        {
            Boolean SavesInProfile { get; set; };
        }
    }
}

namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Profile
    {
        // Other members of CoreWebView2Profile not shown.

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile6")]
        {
            // Sets permission state for the given permission kind and origin
            // asynchronously. The change persists across sessions until it is
            // changed by another call to `SetPermissionState`, or by setting
            // the `State` property in `PermissionRequestedEventArgs`. Setting
            // the state to `CoreWebView2PermissionState.Default` will erase any
            // state saved in the profile and restore the default behavior.
            // The origin should have a valid scheme and host (e.g.
            // "https://www.example.com"), otherwise the method fails.
            // Additional URI parts like path and fragment are ignored. For
            // example, "https://wwww.example.com/app1/index.html/" is treated
            // the same as "https://wwww.example.com". See the
            // [MDN origin definition](https://developer.mozilla.org/en-US/docs/Glossary/Origin) for more details.
            Windows.Foundation.IAsyncAction SetPermissionStateAsync(
                CoreWebView2PermissionKind PermissionKind,
                String origin,
                CoreWebView2PermissionState State);

            // Use this method to get all the nondefault permission settings
            // from the current and previous sessions.
           Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2PermissionSetting>>
           GetNonDefaultPermissionSettingsAsync();
        }
    }

    runtimeclass CoreWebView2PermissionSetting
    {
        // The kind of the permission setting. See CoreWebView2PermissionKind for
        // more details.
        CoreWebView2PermissionKind PermissionKind { get; };

        // The origin of the permission setting.
        String Origin { get; };

        // The state of the permission setting.
        CoreWebView2PermissionState State { get; };
    }
}
```
