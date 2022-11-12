Permission Management APIs
===

# Background

The WebView2 team is adding support for more permission management scenarios. With the
extended `PermissionRequested` event args and new permission APIs you will be able to:
- Set permission for a site at any time
- List all nondefault permissions
- Control more permission kinds

The new `ShouldPersist` property on the `PermissionRequestedEventArgs` lets you
turn off the caching of permission state so that you can intercept all permission
requests. By default, state set from the `PermissionRequested` event handler and default
permission UI is cached across sessions and you may stop receiving PermissionRequested
events for some permission kinds.

The new APIs, `SetPermission` and `GetNonDefaultPermissionCollection`, provide
all the information necessary to build a permission management page where a
user can view and modify existing site permissions. The new permission kinds we will
support are: local font list, automatic downloads, media autoplay, and file editing.

See already supported [permission kinds](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1418.22#corewebview2_permission_kind)
and existing [event args](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2permissionrequestedeventargs?view=webview2-dotnet-1.0.1418.22).


# Examples

## Extended PermissionRequestedEventArgs: ShouldPersist
```c#
// In this example, the app listens to all requests and caches permission on its own
// to decide whether to show custom UI to the user.
void WebView_PermissionRequested(object sender, CoreWebView2PermissionRequestedEventArgs args)
{
    CoreWebView2Deferral deferral = args.GetDeferral();

    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        using (deferral)
        {
            try
            {
              // Do not persist state so that the PermissionRequested event is always
              // raised and the app is in control of all permission requests.
              args.ShouldPersist = true;
            }
            catch (Exception exception) {}
            (string, CoreWebView2PermissionKind, bool) cachedKey =
                (args.Uri, args.PermissionKind, args.IsUserInitiated);
            if (_cachedPermissions.ContainsKey(cachedKey))
            {
                args.State = _cachedPermissions[cachedKey]
                    ? CoreWebView2PermissionState.Allow
                    : CoreWebView2PermissionState.Deny;
            }
            else
            {
                ShowPermissionDialog(args.Uri, args.PermissionKind,
                  args.IsUserInitiated);
            }
        }
    }, null);
}
```
```cpp
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

    // Do not persist state so that the PermissionRequested event is always
    // raised and the app is in control of all permission requests.
    auto extendedArgs = args.try_query<ICoreWebView2PermissionRequestedEventArgs3>();
    if (extendedArgs)
        CHECK_FAILURE(extendedArgs->put_ShouldPersist(FALSE));

    // Do the rest asynchronously, to avoid calling dialog in an event handler.
    m_appWindow->RunAsync([this, deferral, args] {
        COREWEBVIEW2_PERMISSION_KIND kind = COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
        BOOL userInitiated = FALSE;
        wil::unique_cotaskmem_string uri;
        CHECK_FAILURE(args->get_PermissionKind(&kind));
        CHECK_FAILURE(args->get_IsUserInitiated(&userInitiated));
        CHECK_FAILURE(args->get_Uri(&uri));

        auto cachedKey = std::make_tuple(std::wstring(uri.get()), kind, userInitiated);
        auto cachedPermission = m_cachedPermissions.find(cachedKey);
        if (cachedPermission != m_cachedPermissions.end())
        {
            COREWEBVIEW2_PERMISSION_STATE state;
            state =
                (cachedPermission->second ? COREWEBVIEW2_PERMISSION_STATE_ALLOW
                                           : COREWEBVIEW2_PERMISSION_STATE_DENY);
            CHECK_FAILURE(args->put_State(state));
        }
        else
        {
            ShowPermissionDialog(uri, kind, userInitiated);
        }
        CHECK_FAILURE(deferral->Complete());
    });
    return S_OK;
}
```
## SetPermission and GetNonDefaultPermissionCollection
```c#
// Gets the nondefault permission collection and updates a custom permission
// management page.
async void WebView_PermissionPage_DOMContentLoaded(object sender, CoreWebView2DOMContentLoadedEventArgs arg)
{
    foreach (var kind in permissionKinds)
    {
        IReadOnlyList<CoreWebView2PermissionSetting> permissionList =
            await WebViewProfile.GetNonDefaultPermissionCollectionAsync(kind);
        for (int i = 0; i < permissionList.Count; i++)
        {
            var setting = permissionList[i];
            string reply = "{\"PermissionEntry\": \"" + PermissionKindToString(kind)
                            + ", " + setting.origin + ", " +
                            PermissionStateToString(setting.State) + "\"}";
            webView.CoreWebView2.PostWebMessageAsJson(reply);
        }
    }
}

// Called when the user wants to change permission state from the custom
// permission management page.
void HandleWebMessage(CoreWebView2WebMessageReceivedEventArgs args)
{
    try
    {
        string message = args.TryGetWebMessageAsString();
        if (args.Source == "https://appassets.example/ScenarioPermissionManagement.html")
        {
            if (message == "SetPermission")
            {
                // Avoid potential reentrancy from running a message loop in the
                // event handler.
                System.Threading.SynchronizationContext.Current.Post((_) =>
                {
                    var dialog = new PermissionDialog();
                    if (dialog.ShowDialog() == true)
                    {
                        webView.CoreWebView2.SetPermissionState(
                            PermissionKindFromString(dialog.PermissionKind.Text),
                            dialog.Origin.Text,
                            PermissionStateFromString(dialog.PermissionState.Text));
                    }
                }, null);
            }
        }
    catch (Exception e)
    {
        MessageBox.Show($"Unexpected message received: {e.Message}");
    }
}

```
```cpp
void ScenarioPermissionManagement::ScenarioPermissionManagement()
{
    wil::com_ptr<ICoreWebView2_2> m_webView2;
    m_webView2 = m_webView.try_query<ICoreWebView2_2>();
    //! [GetNonDefaultPermissionCollection]
    // Gets the nondefault permission collection and updates a custom permission
    // management page.
    CHECK_FAILURE(m_webView2->add_DOMContentLoaded(
        Callback<ICoreWebView2DOMContentLoadedEventHandler>(
            [this](
                ICoreWebView2* sender, ICoreWebView2DOMContentLoadedEventArgs* args) -> HRESULT
            {
                for (COREWEBVIEW2_PERMISSION_KIND kind : permissionKinds)
                {
                    m_webViewProfile5->GetNonDefaultPermissionCollection(
                        kind,
                        Callback<
                            ICoreWebView2GetNonDefaultPermissionCollectionCompletedHandler>(
                            [this, sender, kind](
                                HRESULT code,
                                ICoreWebView2PermissionCollection* collection) -> HRESULT
                            {
                                UINT32 count;
                                collection->get_Count(&count);
                                UINT32 i = 0;
                                while (i < count)
                                {
                                    wil::com_ptr<ICoreWebView2PermissionSetting> setting;
                                    collection->GetValueAtIndex(i, &setting);
                                    COREWEBVIEW2_PERMISSION_STATE state;
                                    setting->get_State(&state);
                                    wil::unique_cotaskmem_string origin;
                                    setting->get_Origin(&origin);
                                    std::wstring state_string = PermissionStateFromString(state);
                                    std::wstring kind_string = PermissionKindFromString(kind);
                                    std::wstring reply = L"{\"PermissionSetting\": \"" +
                                                         kind_string + L", " + origin.get() +
                                                         L", " + state_string + L"\"}";
                                    CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                                    i++;
                                }
                                return S_OK;
                            })
                            .Get());
                }
                return S_OK;
            })
            .Get(),
        &m_DOMContentLoadedToken));
    //! [GetNonDefaultPermissionCollection]

    // Called when the user wants to change permission state from the custom
    // permission management page.
    m_webView->add_WebMessageReceived(
        Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args)
                -> HRESULT
            {

                wil::unique_cotaskmem_string message;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&message));
                if (wcscmp(message.get(), L"SetPermission") == 0)
                {
                    // Avoid potential reentrancy from running a message loop in
                    // the event handler.
                    m_appWindow->RunAsync([this] {
                        ShowSetPermissionDialog();
                    });
                }
                return S_OK;
            })
            .Get(),
        nullptr);
}

void ScenarioPermissionManagement::ShowSetPermissionDialog()
{
    DialogBoxParam(
        g_hInstance, MAKEINTRESOURCE(IDD_SET_PERMISSION), m_appWindow->GetMainWindow(),
        DlgProcStatic, (LPARAM)m_appWindow);
}

// When the user selects `OK` in the dialog, call SetPermision with the chosen
// origin, kind, and state.
static INT_PTR CALLBACK DlgProcStatic(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
    auto self = (ScenarioPermissionManagement*)GetWindowLongPtr(hDlg, GWLP_USERDATA);

    switch (message)
    {
    case WM_INITDIALOG:
    {
        self = (ScenarioPermissionManagement*)lParam;
        SetWindowLongPtr(hDlg, GWLP_USERDATA, (LONG_PTR)self);
        return (INT_PTR)TRUE;
    }
    case WM_COMMAND:
    {
        if (LOWORD(wParam) == IDOK)
        {
            wchar_t origin[MAX_PATH] = {};
            GetDialogInput(IDC_EDIT_PERMISSION_ORIGIN, origin);
            wchar_t kind[MAX_PATH] = {};
            GetDialogInput(IDC_EDIT_PERMISSION_KIND, kind);
            wchar_t state[MAX_PATH] = {};
            GetDlgItemText(IDC_EDIT_PERMISSION_STATE, state);
            self->SetPermissionState(
                origin, PermissionKindFromString(kind),
                PermissionStateFromString(state));
        }
        if (LOWORD(wParam) == IDOK || LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hDlg, LOWORD(wParam));
            return (INT_PTR)TRUE;
        }
        break;
    }
    case WM_NCDESTROY:
        SetWindowLongPtr(hDlg, GWLP_USERDATA, NULL);
        return (INT_PTR)TRUE;
    }
    return (INT_PTR)FALSE;
}

void ScenarioPermissionManagement::SetPermissionState(
    std::wstring origin, COREWEBVIEW2_PERMISSION_KIND kind, COREWEBVIEW2_PERMISSION_STATE state)
{
    if (m_webViewProfile5)
    {
        m_webViewProfile5->SetPermissionState(kind, origin.c_str(), state);
    }
}
```
# API Details

## Extended PermissionKind
```
[v1_enum]
typedef enum COREWEBVIEW2_PERMISSION_KIND {

  // Other permission kinds not shown.

  /// Indicates permission to automatically download multiple files.
  COREWEBVIEW2_PERMISSION_KIND_AUTOMATIC_DOWNLOADS,

  /// Indicates permission to edit files or folders on the device.
  COREWEBVIEW2_PERMISSION_KIND_FILE_EDITING,

  /// Indicates permission to play audio and video automatically on sites.
  COREWEBVIEW2_PERMISSION_KIND_AUTOPLAY,

  /// Indicates permission to use fonts on the device.
  COREWEBVIEW2_PERMISSION_KIND_LOCAL_FONTS,
} COREWEBVIEW2_PERMISSION_KIND;
```
```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2PermissionKind
    {
        // Other permission kinds not shown.

        // Indicates permission to automatically download multiple files.
        AutomaticDownloads = 7,

        // Indicates permission to edit files or folders on the device.
        FileEditing = 8,

        // Indicates permission to play audio and video automatically on sites.
        Autoplay = 9,

        // Indicates permission to use fonts on the device.
        LocalFonts = 10,
    };
}
```
## Extended PermissionRequestedEventArgs: ShouldPersist
```
/// This is a continuation of the `ICoreWebView2PermissionRequestedEventArgs`
/// interface.
[uuid(08595a19-44f0-41b1-9ae4-5889f5edadcb), object, pointer_default(unique)]
interface ICoreWebView2PermissionRequestedEventArgs3:
    ICoreWebView2PermissionRequestedEventArgs2 {
  /// The permission state set from the `PermissionRequested` event is persisted
  /// across sessions by default and becomes the new default behavior for future
  /// `PermissionRequested` events. Browser heurisitics can affect whether the
  /// event continues to be raised when the state is persisted. Set the
  /// `ShouldPersist` property to `FALSE` to not persist the state beyond the
  /// current request, and to continue to receive `PermissionRequested` events
  /// for this origin and permission kind.
  [propget] HRESULT ShouldPersist([out, retval] BOOL* shouldPersist);

  /// Sets the `ShouldPersist` property.
  [propput] HRESULT ShouldPersist([in] BOOL shouldPersist);
}
```
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2PermissionRequestedEventArgs
    {
        // Other members not shown.

        // The permission state set from the `PermissionRequested` event is persisted
        // across sessions by default and becomes the new default behavior for future
        // `PermissionRequested` events. Browser heurisitics can affect whether the
        // event continues to be raised when the state is persisted. Set the
        // `ShouldPersist` property to `FALSE` to not persist the state beyond the
        // current request, and to continue to receive `PermissionRequested` events
        // for this origin and permission kind.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2PermissionRequestedEventArgs3")]
        {
            Boolean ShouldPersist { get; set; };
        }
    }
}
```
## SetPermission and GetNonDefaultPermissionCollection
```
/// This is the ICoreWebView2 interface for the permission management APIs.
[uuid(5bdfc5dd-C07a-41b7-bcf2-94020975f185), object, pointer_default(unique)]
interface ICoreWebView2Profile5 : ICoreWebView2Profile4 {
  /// Sets permission state for the given permission kind and origin
  /// asynchronously. The change takes effect immediately and persists
  /// across sessions until it is changed.
  HRESULT SetPermissionState(
        [in] COREWEBVIEW2_PERMISSION_KIND permissionKind,
        [in] LPCWSTR origin,
        [in] COREWEBVIEW2_PERMISSION_STATE state);

  /// Invokes the handler with a collection of nondefault permission settings
  /// for the given permission kind. Use this method to get the permission state
  /// set in the current and previous sessions.
  ///
  /// \snippet ScenarioPermissionManagement.cpp
  HRESULT GetNonDefaultPermissionCollection(
      [in] COREWEBVIEW2_PERMISSION_KIND permissionKind,
      [in] ICoreWebView2GetNonDefaultPermissionCollectionCompletedEventHandler*
          completedHandler);
}

/// The caller implements this interface to handle the result of
/// `GetNonDefaultPermissionCollection`.
[uuid(64889aec-34d0-47e3-86ed-a4df204f8dcf), object, pointer_default(unique)]
interface
ICoreWebView2GetNonDefaultPermissionCollectionCompletedEventHandler : IUnknown {
  /// Provides the permission collection for the requested permission kind.
  HRESULT Invoke([in] HRESULT errorCode,
      [in] ICoreWebView2PermissionCollection* permissionCollection);
}

/// Collection of `PermissionSetting`s (origin, kind, and state). Used to list
/// the nondefault permission settings on the profile that are persisted across
/// sessions.
[uuid(d862e9e0-67e7-4a33-ba7d-7db22c82f74d), object, pointer_default(unique)]
interface ICoreWebView2PermissionCollection : IUnknown {
  /// Gets the `ICoreWebView2PermissionSetting` at the specified index.
  HRESULT GetValueAtIndex([in] UINT32 index,
                          [out, retval] ICoreWebView2PermissionSetting** permissionSetting);

  /// The number of `ICoreWebView2PermissionSetting`s in the collection.
  [propget] HRESULT Count([out, retval] UINT32* count);
}

/// Provides a set of properties for a permission setting.
[uuid(9c78a547-d008-49d8-a5e2-a3021976c755), object, pointer_default(unique)]
interface ICoreWebView2PermissionSetting : IUnknown {
  /// The kind of the permission setting. See `COREWEBVIEW2_PERMISSION_KIND` for
  /// more details.
  [propget] HRESULT PermissionKind([out, retval] COREWEBVIEW2_PERMISSION_KIND*
      permissionKind);

  /// The origin of the permission setting.
  [propget] HRESULT Origin([out, retval] LPWSTR* uri);

  /// The state of the permission setting.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_PERMISSION_STATE* state);
}
```
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Profile
    {
        // Other members of CoreWebView2Profile not shown.

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile5")]
        {
            // Sets permission state for the given permission kind and origin
            // asynchronously. The change takes effect immediately and persists
            // across sessions until it is changed.
            void SetPermissionState(CoreWebView2PermissionKind PermissionKind,
                String origin, CoreWebView2PermissionState State);

            // Use this method to get the nondefault permission settings from
            // the current and previous sessions.
            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2PermissionSetting>>
            GetNonDefaultPermissionCollectionAsync(
                CoreWebView2PermissionKind PermissionKind);
        }
    }

    runtimeclass CoreWebView2PermissionSetting
    {
        // The kind of the permission setting. See CoreWebView2PermissionKind for
        // more details.
        CoreWebView2PermissionKind PermissionKind { get; };

        // The origin of the permission setting.
        String origin { get; };

        // The state of the permission setting.
        CoreWebView2PermissionState State { get; };
    }
}
```
