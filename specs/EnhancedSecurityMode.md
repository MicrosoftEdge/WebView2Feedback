Enhanced Security Mode
===

# Background
The WebView2 team has been asked for an API to toggle the Enhanced Security Mode (ESM) feature, control levels of ESM, and also to manage ESM enforce and bypass lists.

We are proposing 4 APIs as follows: 

`CoreWebView2EnvironmentOptions.IsEnhancedSecurityModeEnabled` - this API allows developers to enable/disable ESM. The default value is false. When this property is set to true, the level of ESM is controlled by the `CoreWebView2Profile.PreferredEnhancedSecurityModeLevel` property. 

`CoreWebView2Profile.PreferredEnhancedSecurityModeLevel` - this API allows developers to control levels of ESM for WebView2 which are associated with a profile and persisted in the user data folder. However, the level is not respected if ESM is disabled in `CoreWebView2EnvironmentOptions.IsEnhancedSecurityModeEnabled`. That means, when developers set the property when ESM is disabled, it will be updated and persisted, but will not take effect until the feature is enabled. We will offer 2 levels: Off and Strict. 

For reference, in the screenshot below, this API sets the levels of ESM as a WebView2 API.

![image](https://github.com/MicrosoftEdge/WebView2Feedback/assets/82386753/35977716-e46c-4257-82da-906b0c6f833e)

`CoreWebView2Profile.EnhancedSecurityModeBypassList` - this API allows developers to view and add a URI filter from the ESM bypass list. If a site is in the bypass list, the ESM level for the site will always be set to Off when a user navigates to it, regardless of the value of `CoreWebView2Profile.PreferredEnhancedSecurityModeLevel`. However, this is not respected if ESM is disabled in `CoreWebView2EnvironmentOptions.IsEnhancedSecurityModeEnabled`. That means, when developers set the property when ESM is disabled, it will be updated and persisted, but will not take effect until the feature is enabled.  

`CoreWebView2Profile.EnhancedSecurityModeEnforceList` - this API allows developers to view and add a URI filter from the ESM enforce list. If a site is in the enforce list, the ESM level for the site will always be set to Strict when a user navigates to it, regardless of the value of `CoreWebView2Profile.PreferredEnhancedSecurityModeLevel`. However, similar to the allow list, this is not respected if ESM is disabled in `CoreWebView2EnvironmentOptions.IsEnhancedSecurityModeEnabled`. 

For reference, in the screenshot below, this API allows you to manage the Enforce and Bypass List of ESM as a WebView2API.
![image](https://github.com/MicrosoftEdge/WebView2Feedback/assets/82386753/98085785-bfae-4de0-bb39-c85e85913e1f)

# Examples
## IsEnhancedSecurityModeEnabled
```c#
Create WebView Environment with option that disable Enhanced Security Mode feature.

void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    // Disable IsEnhancedSecurityModeEnabled by default to reduce impact on performance
    options.IsEnhancedSecurityModeEnabled = false;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}
```
```cpp
void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    Microsoft::WRL::ComPtr<ICoreWebView2StagingEnvironmentOptions9> optionsStaging9;
    if (options.As(&optionsStaging9) == S_OK)
    {
        CHECK_FAILURE(optionsStaging9->put_IsEnhancedSecurityModeEnabled(
        m_EnhancedSecurityModeEnabled ? TRUE : FALSE));
    }
    // ... other option properties

    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        subFolder, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get());
}
```
## PreferredEnhancedSecurityModeLevel
```c#
void SetEnhancedSecurityModeLevel(CoreWebView2EnhancedSecurityModeLevel value)
{
    WebViewProfile.PreferredEnhancedSecurityModeLevel = value;
    MessageBox.Show(this, "Enhanced security mode level is set successfully", "Enhanced Security Mode Level");
}
```
```cpp
void SettingsComponent::SetEnhancedSecurityModeLevel(
    COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL value)
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profileStaging2 = profile.try_query<ICoreWebView2StagingProfile2>();
        if (profileStaging2)
        {
            CHECK_FAILURE(profileStaging2->put_PreferredEnhancedSecurityModeLevel(value));
            MessageBox(
                nullptr, L"Enhanced security mode level is set successfully",
                L"Enhanced Security Mode Level", MB_OK);
        }
    }
}
```
## EnhancedSecurityModeBypassList
```c#
void EnhancedSecurityModeGetBypassListCommandExecuted(object target, ExecutedRoutedEventArgs e)
{
    List<string> uris = WebViewProfile.EnhancedSecurityModeBypassList;
    uint counts = (uint)uris.Count;

    string urisAsOneString = string.Join(";\n", uris);

    MessageBox.Show(urisAsOneString, "Enhanced Security Mode Bypass List");
}

void EnhancedSecurityModeSetBypassListCommandExecuted(object target, ExecutedRoutedEventArgs e)
{
    var dialog = new TextInputDialog(
        title: "Add to Enhanced Security Mode Bypass List",
        description: "Enter URI filters to bypass, separated by semicolons.",
        defaultInput: "");
    if (dialog.ShowDialog() == true)
    {
        List<string> uris = WebViewProfile.EnhancedSecurityModeBypassList;
        List<string> inputList = dialog.Input.Text.Split(";").ToList();

        foreach(string uri in inputList)
        {
            uris.Add(uri);
        }
                
        MessageBox.Show("Enhanced Security Mode Bypass List is updated successfully",
            "Enhanced Security Mode Bypass List", MessageBoxButtons.OK);
    }
}
```
```cpp
void SettingsComponent::GetEnhancedSecurityModeBypassList() 
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profileStaging2 = profile.try_query<ICoreWebView2StagingProfile2>();
        if (profileStaging2)
        {
            UINT32 counts = 0;
            LPWSTR* uris;
            profileStaging2->GetEnhancedSecurityModeBypassList(&counts, &uris);
            std::wstring s = L""; 
            for (unsigned int i = 0; i < counts; ++i)
            {
               s += uris[i];
               s += L"\n";
            }

            m_appWindow->AsyncMessageBox(s.c_str(), L"Enhanced Security Mode Bypass List");
        }
    }
}

void SettingsComponent::SetEnhancedSecurityModeBypassList()
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profileStaging2 = profile.try_query<ICoreWebView2StagingProfile2>();
        if (profileStaging2)
        {
            TextInputDialog dialog(
                m_appWindow->GetMainWindow(), L"Add to Enhanced Security Mode Bypass List", L"List:",
                L"Enter URI filters to bypass, separated by semicolons.", L"");
            if (dialog.confirmed) {                
                // forming array
                std::wstringstream ss(dialog.input);
                std::wstring uri;
                std::vector<std::wstring> uris;
 
                while (std::getline(ss, uri, L';')) {
                    uris.push_back(uri);
                }
 
                std::vector<LPCWSTR> uris_cstr;
                for (const auto& uri : uris) {
                    uris_cstr.push_back(uri.c_str());
                }

                CHECK_FAILURE(profileStaging2->SetEnhancedSecurityModeBypassList(
                    static_cast<uint32_t>(uris_cstr.size()), uris_cstr.data()));
                MessageBox(nullptr, L"Enhanced Security Mode Bypass List is updated successfully",
                    L"Enhanced Security Mode Bypass List", MB_OK);
            }
        }
    }
}
```

## EnhancedSecurityModeEnforceList
```c#
void EnhancedSecurityModeGetEnforceListCommandExecuted(object target, ExecutedRoutedEventArgs e)
{
    List<string> uris = WebViewProfile.EnhancedSecurityModeEnforceList;
    uint counts = (uint)uris.Count;

    string urisAsOneString = string.Join(";\n", uris);

    MessageBox.Show(urisAsOneString, "Enhanced Security Mode Enforce List");
}

void EnhancedSecurityModeSetEnforceListCommandExecuted(object target, ExecutedRoutedEventArgs e)
{
    var dialog = new TextInputDialog(
        title: "Add to Enhanced Security Mode Enforce List",
        description: "Enter URI filters to enforce, separated by semicolons.",
        defaultInput: "");
    if (dialog.ShowDialog() == true)
    {
        List<string> uris = WebViewProfile.EnhancedSecurityModeEnforceList;
        List<string> inputList = dialog.Input.Text.Split(";").ToList();

        foreach(string uri in inputList)
        {
            uris.Add(uri);
        }
                
        MessageBox.Show("Enhanced Security Mode Enforce List is updated successfully",
            "Enhanced Security Mode Enforce List", MessageBoxButtons.OK);
    } 
}
```
```cpp
void SettingsComponent::GetEnhancedSecurityModeEnforceList() 
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profileStaging2 = profile.try_query<ICoreWebView2StagingProfile2>();
        if (profileStaging2)
        {
            UINT32 counts = 0;
            LPWSTR* uris;
            profileStaging2->GetEnhancedSecurityModeEnforceList(&counts, &uris);
            std::wstring s = L""; 
            for (unsigned int i = 0; i < counts; ++i)
            {
               s += uris[i];
               s += L"\n";
            }

            m_appWindow->AsyncMessageBox(s.c_str(), L"Enhanced Security Mode Enforce List");
        }
    }
}

void SettingsComponent::SetEnhancedSecurityModeEnforceList()
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profileStaging2 = profile.try_query<ICoreWebView2StagingProfile2>();
        if (profileStaging2)
        {
            TextInputDialog dialog(
                m_appWindow->GetMainWindow(), L"Add to Enhanced Security Mode Enforce List", L"List:",
                L"Enter URI filters to enforce, separated by semicolons.", L"");
            if (dialog.confirmed) {
                // forming array
                std::wstringstream ss(dialog.input);
                std::wstring uri;
                std::vector<std::wstring> uris;
 
                while (std::getline(ss, uri, L';')) {
                    uris.push_back(uri);
                }
 
                std::vector<LPCWSTR> uris_cstr;
                for (const auto& uri : uris) {
                    uris_cstr.push_back(uri.c_str());
                }

                CHECK_FAILURE(profileStaging2->SetEnhancedSecurityModeEnforceList(
                    static_cast<uint32_t>(uris_cstr.size()), uris_cstr.data()));
                MessageBox(nullptr, L"Enhanced Security Mode Enforce List is updated successfully",
                    L"Enhanced Security Mode Enforce List", MB_OK);
            }
        }
    }
}
```

# API Details
```
/// Enhanced security mode levels
[v1_enum]
typedef enum COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL {
  /// Enhanced security mode is turned off.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_NONE,
  /// The most restrictive level. This adds an extra layer of protection 
  /// on all sites--familiar or unfamiliar.
  /// 
  /// Not recommended for most users as it requires some level of configuration
  /// to complete daily tasks and can cause slowdowns.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_STRICT,
} COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL;

/// Additional options used to create WebView2 Environment to manage enhanced security mode.
/// 
[uuid(6b6ddf57-459d-55b9-a6ae-6eb2313417df), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironmentOptions9 : IUnknown {
  /// Gets the `IsEnhancedSecurityModeEnabled` property.
  [propget] HRESULT IsEnhancedSecurityModeEnabled([out, retval] BOOL* value);
  ///
  /// The `IsEnhancedSecurityModeEnabled` property is used to toggle the enhanced security mode(ESM) feature in WebView2.
  /// This property enables or disables ESM for all WebView2s created in the same environment.
  /// By default this feature is disabled to reduce its impact on performance.
  /// 
  /// ESM protects users from memory-related vulnerabilities by disabling just-in-time (JIT)
  /// JavaScript compilation and enabling additional operating system protections from the browser.
  /// 
  /// See https://learn.microsoft.com/en-us/DeployEdge/microsoft-edge-security-browse-safer for more details.
  /// 
  [propput] HRESULT IsEnhancedSecurityModeEnabled([in] BOOL value);
}

/// This is an extension of the ICoreWebView2StagingProfile interface to control levels, allowlist, and denylist of enhanced security mode.
/// 
[uuid(d5b781db-0a75-5f9c-85b1-40fa814fcea7), object, pointer_default(unique)]
interface ICoreWebView2StagingProfile2 : IUnknown {
  /// Gets the `PreferredEnhancedSecurityModeLevel` property.
  [propget] HRESULT PreferredEnhancedSecurityModeLevel([out, retval] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL* value);
  ///
  /// The PreferredEnhancedSecurityModeLevel property allows you to control levels of ESM for WebView2 
  /// which are associated with a profile. This level would apply to the context of the profile. That is, all
  /// WebView2s sharing the same profile will be affected. The value is also persisted in the user data folder.
  /// 
  /// See CoreWebView2EnhancedSecurityModeLevel for descriptions of levels currently offered.
  /// 
  /// There is ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled property to enable/disable ESM
  /// for all the WebView2's created in the same environment. If enabled, PreferredEnhancedSecurityModeLevel is
  /// set to CoreWebView2EnhancedSecurityModeLevel.Strict by default or whatever value was last changed/persisted 
  /// to the profile. 
  /// 
  /// If disabled, PreferredEnhancedSecurityModeLevel is not respected by WebView2. If PreferredEnhancedSecurityModeLevel
  /// is set when the feature is disabled, the property value gets changed and persisted but it will take effect only when
  /// ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled is set to true. 
  /// 
  /// See ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled for more details.
  /// \snippet SettingsComponent.cpp SetEnhancedSecurityModeLevel
  /// 
  [propput] HRESULT PreferredEnhancedSecurityModeLevel([in] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL value);
  ///
  /// The EnhancedSecurityModeBypassList method allows you to add URI filters to the bypass list which are associated
  /// with a profile. This method would apply to the context of the profile. That is, all
  /// WebView2s sharing the same profile will be affected. The value is also persisted in the user data folder.
  /// 
  /// This means that if a site is in the bypass list, the ESM level for that site will always be set to Off, regardless of 
  /// the value of PreferredEnhancedSecurityModeLevel. However, this is not respected if 
  /// ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled is set to false. This means that when you update the list
  /// when ESM is disabled, it will be updated and persisted, but will not take effect until the feature is enabled. 
  /// 
  /// See ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled for more details.
  /// 
  /// The uris parameter is a list of uri filters. It can also take wildcard strings and matches against the navigation uri.
  /// See https://www.chromium.org/administrators/url-blocklist-filter-format/ for more details.
  /// 
  /// Some examples of allowed strings are as follows:
  /// | URI filter in list      | URI to navigate          | ESM applied? |
  /// |___________________________________________________________________|
  /// | *://example.com         | www.example.com          | yes          |
  /// | *://example.com         | www.example2.com         | no           |
  /// | https://www.example.com | www.example.com/hi       | yes          |
  /// | https://sample.com      | www.sample.com           | no           |
  /// | https://*               | https://www.example.com  | yes          |
  /// | example.com             | https://www.example.com  | yes          |
  /// | *                       | https://www.example.com  | yes          | 
  /// 
  /// 
  HRESULT GetEnhancedSecurityModeBypassList(
      [out] UINT32* listCounts,
      [out] LPWSTR** uriFilters
  );
  ///
  /// Set the array of URIs in the allow list.
  /// 
  HRESULT SetEnhancedSecurityModeBypassList(
      [in] UINT32 listCounts,
      [in] LPCWSTR* uriFilters
  );
  ///
  /// The EnhancedSecurityModeEnforceList property allows you to add URI filters to the enforce list which are associated
  /// with a profile. This property would apply to the context of the profile. That is, all
  /// WebView2s sharing the same profile will be affected. The value is also persisted in the user data folder.
  /// 
  /// This means that if a site is in the enforce list, the ESM level for that site will always be set to Strict, regardless of 
  /// the value of PreferredEnhancedSecurityModeLevel. However, this is not respected if 
  /// ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled is set to false. This means that when you update the list
  /// when ESM is disabled, it will be updated and persisted, but will not take effect until the feature is enabled. 
  /// See ICoreWebView2StagingEnvironmentOptions9::IsEnhancedSecurityModeEnabled for more details.
  /// 
  /// The enforce list takes precedence over any other list. That is, if a site URL is both in the enforce and bypass list, its ESM level will
  /// be set to Strict.
  /// 
  /// 
  HRESULT GetEnhancedSecurityModeEnforceList(
      [out] UINT32* listCounts,
      [out] LPWSTR** uriFilters
  );
  ///
  /// Set the array of URIs in the enforce list.
  /// 
  HRESULT SetEnhancedSecurityModeEnforceList(
      [in] UINT32 listCounts,
      [in] LPCWSTR* uriFilters
  );
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings5")]
        {
            Boolean IsPinchZoomEnabled { get; set; };
        }
    }
}

namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2EnhancedSecurityModeLevel
    {
        None = 0,
        Strict = 1,
    };

    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions9")]
        {
            // ICoreWebView2EnvironmentOptions9 members
            Boolean IsEnhancedSecurityModeEnabled { get; set; };
        }
    }


    runtimeclass CoreWebView2Profile
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile9")]
        {
            // ICoreWebView2Profile9 members
            CoreWebView2EnhancedSecurityModeLevel PreferredEnhancedSecurityModeLevel { get; set; };
            void GetEnhancedSecurityModeBypassList(out UInt32 listCounts, out String[] uriFilters);
            void SetEnhancedSecurityModeBypassList(UInt32 listCounts, String[] uriFilters);
            void GetEnhancedSecurityModeEnforceList(out UInt32 listCounts, out String[] uriFilters);
            void SetEnhancedSecurityModeEnforceList(UInt32 listCounts, String[] uriFilters);
        }
    }
}
```
