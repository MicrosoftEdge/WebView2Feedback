# Background
Developers would like to ensure a browser extension is installed so that they may take advantage 
of the functionality the extension is providing.

# Description
Enable extension services in WebView2. Then end developer can `AddBrowserExtension` from folder 
path, `GetBrowserExtensions` to get list of extensions installed. Once an extension is installed,
developers can use `ICoreWebView2BrowserExtension` to get id, name of this extension. And also 
remove or enable/disable this extension.

# Examples

The following code snippet demonstrates how the Extensions related API can be used:

## Install extension on first run

You may have a browser extension that is specific to your application's web content. This snippet 
shows how you can install your browser extension on your first run.

### Win32 C++
```cpp
// m_defaultExtensionFolderPath need to match the path of the package you want to install
std::wstring m_defaultExtensionFolderPath = L"//extensions/example-extension";

void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CHECK_FAILURE(options->put_AreBrowserExtensionsEnabled(TRUE));

    // ... other option properties

    // ... CreateCoreWebView2EnvironmentWithOptions

    InstallDefaultExtensions();
    
    // ... Navigate
}

void ScenarioExtensionsManagement::InstallDefaultExtensions()
{
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    CHECK_FEATURE_RETURN_EMPTY(webView2_13);
    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto profile6 = webView2Profile.try_query<ICoreWebView2Profile6>();
    CHECK_FEATURE_RETURN_EMPTY(profile6);

    CHECK_FAILURE(profile6->GetBrowserExtensions(
        Callback<ICoreWebView2ProfileGetBrowserExtensionCompletedHandler>(
            [this, profile6, m_defaultExtensionFolderPath](
                HRESULT error, ICoreWebView2BrowserExtensionList* extensions) -> HRESULT
            {
                std::wstring extensionIdString;
                bool extensionInstalled = false;
                UINT extensionsCount = 0;
                extensions->get_Count(&extensionsCount);

                for (UINT index = 0; index < extensionsCount; ++index)
                {
                    wil::com_ptr<ICoreWebView2BrowserExtension> extension;
                    extensions->GetValueAtIndex(index, &extension);

                    wil::unique_cotaskmem_string id;

                    extension->get_Id(&id);
                    extensionIdString = id.get();

                    if (extensionIdString.compare(m_extensionId) == 0)
                    {
                        extensionInstalled = true;
                        break;
                    }
                }

                if (!extensionInstalled)
                {
                    CHECK_FAILURE(profile6->AddBrowserExtension(
                        m_defaultExtensionFolderPath.c_str(),
                        Callback<ICoreWebView2ProfileAddBrowserExtensionCompletedHandler>(
                            [](HRESULT error,
                               ICoreWebView2BrowserExtension* extension) -> HRESULT
                            {
                                if (error != S_OK)
                                {
                                    ShowFailure(error, L"AddExtension failed");
                                    return S_OK;
                                }
                                return S_OK;
                            })
                            .Get()));
                }
                return S_OK;
            })
            .Get()));
}
```

### .NET and WinRT
```c#
// m_defaultExtensionId need to match the package ID you want to install
string m_defaultExtensionId = "apaahjmopbjicnjjcnionchiganhjpcd";
// m_defaultExtensionFolderPath need to match the path of the package you want to install
string m_defaultExtensionFolderPath = "//extensions/example-extension";

/// Create WebView Environment with option
void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.AreBrowserExtensionsEnabled = true;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(CoreWebView2EnvironmentOptions options: options);
    webview.EnsureCoreWebView2Async(environment);

    _ = InstallDefaultExtensions();
}

// Install default extension before first navigation
private async System.Threading.Tasks.Task InstallDefaultExtensions()
{
    List<CoreWebView2BrowserExtension> extensionsList = await m_coreWebView2.Profile.GetBrowserExtensionsAsync();
    bool found = extensionsList.Any(extension => extension.Id == m_defaultExtensionId);
    if (!found)
    {
        await m_coreWebView2.Profile.AddBrowserExtensionAsync(m_defaultExtensionFolderPath);
    }
}
```

## End user manages extensions

Provide end user the ability to add, remove, enable and disable a browser extension from profile.

### Win32 C++
```cpp
void BrowserExtensionService::AddBrowserExtension()
{

    // Get the profile object.
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto profile6 = webView2Profile.try_query<ICoreWebView2Profile6>();

    OPENFILENAME openFileName = {};
    openFileName.lStructSize = sizeof(openFileName);
    openFileName.hwndOwner = nullptr;
    openFileName.hInstance = nullptr;
    WCHAR fileName[MAX_PATH] = L"";
    openFileName.lpstrFile = fileName;
    openFileName.lpstrFilter = L"Manifest\0manifest.json\0\0";
    openFileName.nMaxFile = ARRAYSIZE(fileName);
    openFileName.Flags = OFN_OVERWRITEPROMPT;

    if (GetOpenFileName(&openFileName))
    {
        // Remove the filename part of the path.
        *wcsrchr(fileName, L'\\') = L'\0';
        profile6->AddBrowserExtension(
            fileName,
            Callback<ICoreWebView2ProfileAddBrowserExtensionCompletedHandler>(
                [](HRESULT error, ICoreWebViewBrowserExtension* extension) -> HRESULT
                {
                    if (error != S_OK)
                    {
                        ShowFailure(error, L"Failed to add extension");
                    }
                    wil::unique_cotaskmem_string id;
                    extension->get_Id(&id);

                    wil::unique_cotaskmem_string name;
                    extension->get_Name(&name);

                    std::wstring extensionInfo;
                    extensionInfo.append(L"Added extension ");
                    extensionInfo.append(name.get());
                    extensionInfo.append(L" (");
                    extensionInfo.append(id.get());
                    extensionInfo.append(L")");
                    MessageBox(nullptr, extensionInfo.c_str(), L"AddBrowserExtension Result", MB_OK);
                    return S_OK;
                })
                .Get());
    }
}

void BrowserExtensionService::RemoveExtension()
{
    // Get the profile object.
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto profile6 = webView2Profile.try_query<ICoreWebView2Profile6>();

    profile6->GetExtensions(
        Callback<ICoreWebView2ProfileGetBrowserExtensionCompletedHandler>(
            [this](HRESULT error, ICoreWebView2BrowserExtensionList* extensions) -> HRESULT
            {
                TextInputDialog dialog(
                    m_appWindow->GetMainWindow(), L"Remove Extension",
                    L"Extension ID:", extensionIdString.c_str());
                if (dialog.confirmed)
                {
                    for (UINT index = 0; index < extensionsCount; ++index)
                    {
                        wil::com_ptr<ICoreWebView2BrowserExtension> extension;
                        extensions->GetValueAtIndex(index, &extension);

                        wil::unique_cotaskmem_string id;
                        wil::unique_cotaskmem_string name;

                        extension->get_Id(&id);
                        if (_wcsicmp(id.get(), dialog.input.c_str()) == 0)
                        {
                            extension->Remove(
                                Callback<ICoreWebView2BrowserExtensionRemoveCompletedHandler>(
                                    [](HRESULT error) -> HRESULT
                                    {
                                        if (error != S_OK)
                                        {
                                            ShowFailure(error, L"Failed to toggle extension enabled.");
                                        }
                                        MessageBox(
                                            nullptr, L"Done", L"Remove Extension", MB_OK);
                                        return S_OK;
                                    })
                                    .Get());
                        }
                    }
                }
                return S_OK;
            })
            .Get());
}

void BrowserExtensionService::ToggleExtensionEnabled()
{
    // Get the profile object.
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto profile6 = webView2Profile.try_query<ICoreWebView2Profile6>();

    profile6->GetExtensions(
        Callback<ICoreWebView2ProfileGetBrowserExtensionCompletedHandler>(
            [this](HRESULT error, ICoreWebView2BrowserExtensionList* extensions) -> HRESULT
            {
                TextInputDialog dialog(
                    m_appWindow->GetMainWindow(),
                    remove ? L"Remove Extension" : L"Disable/Enable Extension",
                    L"Extension ID:", extensionIdString.c_str());
                if (dialog.confirmed)
                {
                    for (UINT index = 0; index < extensionsCount; ++index)
                    {
                        wil::com_ptr<ICoreWebView2BrowserExtension> extension;
                        extensions->GetValueAtIndex(index, &extension);

                        wil::unique_cotaskmem_string id;
                        wil::unique_cotaskmem_string name;

                        extension->get_Id(&id);
                        if (_wcsicmp(id.get(), dialog.input.c_str()) == 0)
                        {
                            BOOL enabled = FALSE;
                            extension->get_IsEnabled(&enabled);

                            extension->SetEnabled(
                                !enabled,
                                Callback<ICoreWebView2BrowserExtensionSetEnabledCompletedHandler>(
                                    [](HRESULT error) -> HRESULT
                                    {
                                        if (error != S_OK)
                                        {
                                            ShowFailure(
                                                error, L"SetEnabled Extension failed");
                                        }
                                        MessageBox(
                                            nullptr, L"Done", L"Toggled Extension", MB_OK);
                                        return S_OK;
                                    })
                                    .Get());
                        }
                    }
                }
                return S_OK;
            })
            .Get());
}
```
### .NET and WinRT
```c#
// Extensions class
/// <summary>
/// Interaction logic for Extensions.xaml
/// </summary>
public partial class Extensions : Window
{
    private CoreWebView2 m_coreWebView2;
    public Extensions(CoreWebView2 coreWebView2)
    {
        m_coreWebView2 = coreWebView2;
        InitializeComponent();
        _ = FillViewAsync();
    }

    public class ListEntry
    {
        public string Name;
        public string Id;
        public bool Enabled;

        public override string ToString()
        {
            return (Enabled ? "" : "Disabled ") + Name + " (" + Id + ")";
        }
    }

    List<ListEntry> m_listData = new List<ListEntry>();

    private async System.Threading.Tasks.Task FillViewAsync()
    {
        List<CoreWebView2BrowserExtension> extensionsList = await m_coreWebView2.Profile.GetBrowserExtensionsAsync();

        m_listData.Clear();
        for (int i = 0; i < extensionsList.Count; ++i)
        {
            ListEntry entry = new ListEntry();
            entry.Name = extensionsList[i].Name;
            entry.Id = extensionsList[i].Id;
            entry.Enabled = extensionsList[i].IsEnabled;
            m_listData.Add(entry);
        }
        ExtensionsList.ItemsSource = m_listData;
        ExtensionsList.Items.Refresh();
    }

    private void AddBrowserExtension(object sender, RoutedEventArgs e)
    {
        _ = AddBrowserExtensionAsync(sender, e);
    }

    private async System.Threading.Tasks.Task AddBrowserExtensionAsync(object sender, RoutedEventArgs e)
    {
        var dialog = new TextInputDialog(
            title: "Add extension",
            description: "Enter the absolute Windows file path to the unpackaged browser extension",
            defaultInput: "");
        if (dialog.ShowDialog() == true)
        {
            try
            {
                CoreWebView2Extension extension = await m_coreWebView2.Profile.AddBrowserExtensionAsync(dialog.Input.Text);
                MessageBox.Show("Added extension " + extension.Name + " (" + extension.Id + ")");
                await FillViewAsync();
            }
            catch (Exception exception)
            {
                MessageBox.Show("Failed to add extension: " + exception);
            }
        }
    }

    private void RemoveExtension(object sender, RoutedEventArgs e)
    {
        _ = RemoveExtensionAsync(sender, e);
    }

    private async System.Threading.Tasks.Task RemoveExtensionAsync(object sender, RoutedEventArgs e)
    {
        ListEntry entry = (ListEntry)ExtensionsList.SelectedItem;
        if (MessageBox.Show("Remove extension " + entry + "?", "Confirm removal", MessageBoxButton.OKCancel) == MessageBoxResult.OK)
        {
            List<CoreWebView2BrowserExtension> extensionsList = await m_coreWebView2.Profile.GetBrowserExtensionsAsync();
            for (int i = 0; i < extensionsList.Count; ++i)
            {
                if (extensionsList[i].Id == entry.Id)
                {
                    try
                    {
                        await extensionsList[i].RemoveAsync();
                    }
                    catch (Exception exception)
                    {
                        MessageBox.Show("Failed to remove extension: " + exception);
                    }
                    break;
                }
            }
        }
        await FillViewAsync();
    }

    private void ToggleExtensionEnabled(object sender, RoutedEventArgs e)
    {
        _ = ToggleExtensionEnabledAsync(sender, e);
    }

    private async System.Threading.Tasks.Task ToggleExtensionEnabledAsync(object sender, RoutedEventArgs e)
    {
        ListEntry entry = (ListEntry)ExtensionsList.SelectedItem;
        List<CoreWebView2BrowserExtension> extensionsList = await m_coreWebView2.Profile.GetBrowserExtensionsAsync();
        for (int i = 0; i < extensionsList.Count; ++i)
        {
            if (extensionsList[i].Id == entry.Id)
            {
                try
                {
                    await extensionsList[i].SetEnabledAsync(extensionsList[i].IsEnabled ? false : true);
                }
                catch (Exception exception)
                {
                    MessageBox.Show("Failed to toggle extension enabled: " + exception);
                }
                break;
            }
        }
        await FillViewAsync();
    }
}

```
# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2Profile6;
interface ICoreWebView2EnvironmentOptions6;
interface ICoreWebView2BrowserExtensionSetEnabledCompletedHandler;
interface ICoreWebView2BrowserExtensionRemoveCompletedHandler;
interface ICoreWebView2BrowserExtension;
interface ICoreWebView2BrowserExtensionList;
interface ICoreWebView2ProfileAddBrowserExtensionCompletedHandler;
interface ICoreWebView2ProfileGetBrowserExtensionsCompletedHandler;

/// Additional options used to create WebView2 Environment.
[uuid(4B1F63E9-F7A5-4EA5-8D84-2B30F2404E82), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions6 : ICoreWebView2EnvironmentOptions5 {
  /// When `AreBrowserExtensionsEnabled` is set to `TRUE`, new extensions can be added to user profile and used.
  /// `AreBrowserExtensionsEnabled` is default to be `FALSE`, in this case, new extensions can't be installed, and
  /// already installed extension won't be avaliable to use in user profile.
  /// See `ICoreWebView2BrowserExtension` for Extensions API details.
  [propget] HRESULT AreBrowserExtensionsEnabled([out, retval] BOOL* value);
  /// Sets the `AreBrowserExtensionsEnabled` property.
  [propput] HRESULT AreBrowserExtensionsEnabled([in] BOOL value);
}

/// This is the ICoreWebView2 profile.
[uuid(8B16D238-9508-4C36-B4D4-749EB9AC4AD0), object, pointer_default(unique)]
interface ICoreWebView2Profile6 : IUnknown {
    /// Adds the [browser extension](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions) using the extension path for unpacked extensions
    /// from the local device. The extension folder path is the topmost folder of an unpacked browser extension and contains the browser extension manifest file.
    /// If the `extensionFolderPath` is an invalid path or doesn't contain the extension manifest.json file, this function will return E_FAIL to callers. 
    /// Installed extension will default `IsEnabled` to true.
    /// When `AreBrowserExtensionsEnabled` is `FALSE`, `AddBrowserExtension` will fail and return HRESULT `ERROR_NOT_SUPPORTED`.
    /// During installation, the content of the extension is not copied to the user data folder. Once the extension is installed, changing the 
    /// content of the extension will cause the extension to be removed from the installed profile. 
    /// When an extension is added the extension is persisted in the corresponding profile. The extension will still be installed the next time you use this profile.
    /// The following summarizes the possible error values that can be returned from 
    /// `AddBrowserExtension` and a description of why these errors occur.
    ///
    /// Error value                                     | Description
    /// ----------------------------------------------- | --------------------------
    /// `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)`       | Extensions are disabled due to policy rules.
    /// `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)`      | Cannot find `manfiest.json` file or it is not a valid extension manfiest.
    /// `E_ACCESSDENIED`                                | Cannot load extension with file or directory name starting with \"_\", reserved for use by the system.
    /// `E_FAIL`                                        | Extension failed to install with other unknown reasons. 
    HRESULT AddBrowserExtension([in] LPCWSTR extensionFolderPath, [in] ICoreWebView2ProfileAddBrowserExtensionCompletedHandler* handler);
    /// Gets a snapshot of the set of extensions installed at the time `GetBrowserExtensions` is called. If an extension is installed or uninstalled 
    /// after `GetBrowserExtensions` completes, the list returned by `GetBrowserExtensions` remains the same.
    /// When `AreBrowserExtensionsEnabled` is `FALSE`, `GetBrowserExtensions` won't return any extensions on current user profile.
    HRESULT GetBrowserExtensions([in] ICoreWebView2ProfileGetBrowserExtensionsCompletedHandler* handler);
}

/// Provides a set of properties for managing an Extension, which includes
/// an ID, name, and whether it is enabled or not, and the ability to Remove
/// the Extension, and enable or disable it.
[uuid(BCFC3E36-1BAD-4009-BFFC-A372C469F6BA), object, pointer_default(unique)]
interface ICoreWebView2BrowserExtension : IUnknown {
    /// This is the browser extension's ID. This is the same browser extension ID returned by 
    /// the browser extension API [`chrome.runtime.id`](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/runtime/id). 
    /// Please see that documentation for more details on how the ID is generated.
    /// The caller must free the returned string with `CoTaskMemFree`.  See
    /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
    [propget] HRESULT Id([out, retval] LPWSTR* value); 
    /// This is the browser extension's name. This value is defined in this browser extension's manifest.json file. 
    /// If manifest.json define extension's localized name, this value will be the localized version of the name.
    /// Please see [Manifest.json name](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/name) for more details.
    /// The caller must free the returned string with `CoTaskMemFree`.  See
    /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
    [propget] HRESULT Name([out, retval] LPWSTR* value);
    /// Removes this browser extension from its WebView2 Profile. The browser extension is removed immediately including from all 
    /// currently running HTML documents associated with this WebView2 Profile. The removal is persisted and future uses of this profile 
    /// will not have this extension installed. After an extension is removed, calling `Remove` again will cause an exception.
    HRESULT Remove([in] ICoreWebView2BrowserExtensionRemoveCompletedHandler* handler);
    /// If isEnabled is true then the Extension is enabled and running in WebView instances.
    /// If it is false then the Extension is disabled and not running in WebView instances.
    /// When a Extension is first installed, `IsEnable` are default to be `TRUE`.
    [propget] HRESULT IsEnabled([out, retval] BOOL* value);
    /// Sets whether this browser extension is enabled or disabled. This change applies immediately 
    /// to the extension in all HTML documents in all WebView2s associated with this profile.
    /// After an extension is removed, calling `SetIsEnabled` will not change the value of `IsEnabled`.
    HRESULT SetIsEnabled([in] BOOL isEnabled, [in] ICoreWebView2BrowserExtensionSetEnabledCompletedHandler* handler);
}

/// Provides a set of properties for managing browser Extension Lists. This
/// includes the number of browser Extensions in the list, and the ability
/// to get an browser Extension from the list at a particular index.
[uuid(59251055-F2F1-448F-A096-F996FB9ACBE2), object, pointer_default(unique)]
interface ICoreWebView2BrowserExtensionList : IUnknown {
    /// The number of browser Extensions in the list.
    [propget] HRESULT Count([out, retval] UINT* count);
    /// Gets the browser Extension located in the browser Extension List at the given index.
    HRESULT GetValueAtIndex([in] UINT index, [out, retval] ICoreWebView2BrowserExtension** extension);
}

/// The caller implements this interface to receive the result of
/// getting the browser Extensions.
[uuid(2A05565F-DE9D-46E3-AAF7-B866966828F4), object, pointer_default(unique)]
interface ICoreWebView2ProfileGetBrowserExtensionsCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2BrowserExtensionList* extensionList);
}

/// The caller implements this interface to receive the result
/// of loading an browser Extension.
[uuid(E81499FE-8BC6-4BA6-BAD7-D21FFA4C3266), object, pointer_default(unique)]
interface ICoreWebView2ProfileAddBrowserExtensionCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2BrowserExtension* extension);
}

/// The caller implements this interface to receive the result of removing
/// the browser Extension from the Profile.
[uuid(BD73ED6B-08A3-4A57-9DD0-2903067632B4), object, pointer_default(unique)]
interface ICoreWebView2BrowserExtensionRemoveCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode);
}

/// The caller implements this interface to receive the result of setting the
/// browser Extension as enabled or disabled. If enabled, the browser Extension is 
/// running in WebView instances. If disabled, the browser Extension is not running in WebView instances.
[uuid(0A5F7098-2265-49C7-BA60-5A511E80805A), object, pointer_default(unique)]
interface ICoreWebView2BrowserExtensionSetEnabledCompletedHandler : IUnknown {
    HRESULT Invoke([in] HRESULT errorCode);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    
    // ...
    runtimeclass CoreWebView2BrowserExtension;
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        Boolean AreBrowserExtensionsEnabled { get; set; };
    }

    // ...
    runtimeclass CoreWebView2Profile
    {
        // ...
        Windows.Foundation.IAsyncOperation<CoreWebView2BrowserExtension> AddBrowserExtensionAsync(String extensionFolderPath);
        IAsyncOperation<IVectorView<CoreWebView2BrowserExtension>> GetBrowserExtensionsAsync();
    }

    runtimeclass CoreWebView2BrowserExtension
    {
        String Id { get; };
        String Name { get; };
        Boolean IsEnabled { get; };
        Windows.Foundation.IAsyncAction RemoveAsync();
        Windows.Foundation.IAsyncAction SetEnabledAsync(Boolean IsEnabled);
    }

    // ...
}
```
