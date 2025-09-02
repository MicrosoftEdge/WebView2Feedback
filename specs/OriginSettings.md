# Background

Microsoft Edge supports multiple origin based feature used to improve security
and privacy. A couple of which might affect the performance and/ or website 
stability.

## Enhanced Security mode

Microsoft Edge supports a security mode called "Enhanced Security Mode" when
visiting different URLs. 
Paraphrasing from the [public documentation](https://www.microsoft.com/en-us/edge/features/enhanced-security-mode?form=MA13FJ) - 
> Enhanced security mode helps reduce the risk of an attack caused by
> memory-related vulnerabilities by automatically applying stricter security
> settings on unfamiliar sites while adapting to your browsing habits over time. 

In the browser it comes with 3 modes - 
1. Basic (OFF) -> Don't use Enhanced Security Mode.
2. Balanced (Based on site visits) -> Enable only if the website isn't
   frequently visited (Heuristics based).
3. Strict (Always ON) -> Use Enhanced security mode irrespective of the
   frequency of the visit.

Enhanced security mode works by disabling the Just-in-time(JIT) Compilation of
javascript. Hence does carry a certain amount of performance impact. Which is
why for WebView2 it's off by default, unless explicitly enabled via the
`--sdsm-state` browser flag. [See here for
details](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/webview-features-flags?tabs=dotnetcsharp).

## Smart Screen

Microsoft SmartScreen is a security feature that helps protect users from:

- **Phishing and malware websites:** SmartScreen checks websites against a constantly updated list of reported phishing sites and malicious software sites
- **Potentially unwanted application downloads:** Warns users when they attempt to download applications that might include unwanted or malicious software
- **Application reputation detection:** Examines download history and identifies applications with poor reputations

SmartScreen States:
1. On (Default): SmartScreen actively scans pages and provides warnings
2. Off: No scanning or warnings are provided
3. Custom exceptions: Allows specific origins to bypass SmartScreen checks
> Note: It's not possible to **enable** SmartScreen for only a specific origin

See
[IsReputationCheckingRequired](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isreputationcheckingrequired?view=webview2-dotnet-1.0.3179.45)
for configuring smartscreen state globably.

## Tracking Prevention

Tracking Prevention helps protect users' privacy by limiting how websites can track browsing activity across different sites.

Tracking Prevention Levels:
- Basic: Blocks known harmful trackers but allows most trackers for personalization
- Balanced (Default): Blocks trackers from sites you haven't visited while allowing trackers from sites you visit frequently
- Strict: Blocks most trackers across all sites, which may cause some sites to break
- Custom exception for origins

> Note: It's not possible to **enable** Tracking Prevention for only a specific origin


# Description

We propose creating new APIs to allow apps using webview2 to configure the
Enhanced Security Mode.

```c
/// Enhanced security mode levels
[v1_enum]
typedef enum COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL {
  /// Enhanced security mode is turned off.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_OFF,
  /// The most restrictive level. This adds an extra layer of protection 
  /// on all sites--familiar or unfamiliar.
  /// 
  /// Not recommended for most users as it requires some level of configuration
  /// to complete daily tasks and can cause slowdowns.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_STRICT,
} COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL;

/// Complete states for origin settings
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_SETTING_STATE {
  /// State is set to the current state of the origin setting.
  COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE_DEFAULT,
  /// Feature will not be enforced on the origin setting regardless of the current 
  /// feature state. 
  COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE_BYPASS,
  /// Feature is always enforced on the origin setting regardless of the current
  /// feature state.
  COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE_ENFORCE,
} COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE;

/// This is an extension of the ICoreWebView2StagingProfile interface to control levels, allowlist, and denylist of enhanced security mode.
/// 
[uuid(0589a0bc-0998-53a9-a9f3-0e40446cf383), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : IUnknown {
  /// Gets the `PreferredEnhancedSecurityModeLevel` property.
  [propget] HRESULT PreferredEnhancedSecurityModeLevel([out, retval] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL* value);


  /// The PreferredEnhancedSecurityModeLevel property allows you to control levels of ESM for WebView2 
  /// which are associated with a profile. This level would apply to the context of the profile. That is, all
  /// WebView2s sharing the same profile will be affected. The value is also persisted in the user data folder.
  /// 
  /// See CoreWebView2EnhancedSecurityModeLevel for descriptions of levels currently offered.
  /// 
  [propput] HRESULT PreferredEnhancedSecurityModeLevel([in] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL value);

  /// The OriginSettings property allows you to add objects of type OriginSetting where you can set
  /// preferences for each origin setting which are associated with a profile. This property would apply to the 
  /// context of the profile. That is, all WebView2s sharing the same profile will be affected. The 
  /// value is also persisted in the user data folder.
  /// 
  HRESULT GetOriginSettings(
      [out] UINT32* originSettingsCount,
      [out] ICoreWebView2OriginSetting*** originSettings
  );

  /// Set the array of origin settings.
  HRESULT SetOriginSettings(
      [in] UINT32 originSettingsCount,
      [in] ICoreWebView2OriginSetting** originSettings
  );
}

/// Provides a set of properties for managing an origin setting, which includes an origin match and
/// its supported features states. Enhanced security mode and smart screen are the only supported features for now. 
/// 
[uuid(e8240179-1b27-5ce2-84b2-ea187e3e91ec), object, pointer_default(unique)]
interface ICoreWebView2OriginSetting : IUnknown {

  /// Gets the `OriginMatch` property.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT OriginMatch([out, retval] LPWSTR* value);

  /// This is the origin that is being matched to the features. They can be wildcard strings and will
  /// be matched against the navigation uri up to the origin level.
  /// 
  /// Some examples of allowed OriginMatch are as follows:
  /// | URI filter in list      | URI to navigate          | Matched?     |
  /// |___________________________________________________________________|
  /// | *://example.com         | www.example.com          | yes          |
  /// | *://example.com         | www.example2.com         | no           |
  /// | https://www.example.com | www.example.com/hi       | yes          |
  /// | https://sample.com      | www.sample.com           | no           |
  /// | https://*               | https://www.example.com  | yes          |
  /// | example.com             | https://www.example.com  | yes          |
  /// | *                       | https://www.example.com  | yes          | 
  /// 
  [propput] HRESULT OriginMatch([in] LPCWSTR value);

   /// Gets the state of `EnhancedSecurityMode`.
  [propget] HRESULT EnhancedSecurityMode([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);

  /// This is the state of the origin setting for the enhanced security mode feature.
  /// If the EnhancedSecurityMode property is set to CoreWebView2OriginSettingState.Default, 
  /// the ESM level that will be applied to this origin is the value of 
  /// PreferredEnhancedSecurityModeLevel. If the property is set to 
  /// CoreWebView2OriginSettingsState.Bypass, the ESM level for this origin will always be 
  /// set to Off, regardless of the value of PreferredEnhancedSecurityModeLevel. If it is set to 
  /// CoreWebView2FullOriginSettingsState.Enforce, the ESM level for this origin will always be 
  /// set to Strict, regardless of the value of PreferredEnhancedSecurityModeLevel.
  /// 
  [propput] HRESULT EnhancedSecurityMode([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);

  /// Gets the state of `TrackingPrevention`.
  [propget] HRESULT TrackingPrevention([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);

  /// This is the state of the origin setting for tracking prevention feature.
  ///
  /// If the TrackingPrevention property is set to CoreWebView2OriginSettingState.Default,
  /// the global tracking prevention setting will be applied to the origin match.
  ///
  /// If the property is set to CoreWebView2OriginSettingsState.Bypass, the tracking
  /// prevention feature will be always off for the origin match regardless of the global 
  /// state.
  ///
  /// CoreWebView2OriginSettingsState.Enforce is invalid for tracking prevention
  /// 
  [propput] HRESULT TrackingPrevention([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);

  /// Gets the state of `SmartScreen` feature.
  [propget] HRESULT SmartScreen([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);

  /// This is the state of the origin setting for SmartScreen feature.
  ///
  /// If the TrackingPrevention property is set to CoreWebView2OriginSettingState.Default,
  /// the global SmartScreen setting will be applied to the origin match.
  ///
  /// If the property is set to CoreWebView2OriginSettingsState.Bypass, the SmartScreen
  /// feature will be always off for the origin match regardless of the global state.
  ///
  /// CoreWebView2OriginSettingsState.Enforce is invalid for SmartScreen
  ///
  [propput] HRESULT SmartScreen([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);
}

/// This interface is an extension of the ICoreWebView2Environment that supports
/// creating origin settings for a profile.
/// 
[uuid(b30a88f8-9332-5e37-b12f-1e1b59dded1b), object, pointer_default(unique)]
interface ICoreWebView2Environment6 : IUnknown {
  /// Creates the `ICoreWebView2OriginSetting` used by security features
  /// 
  HRESULT CreateOriginSetting(
      [out, retval] ICoreWebView2OriginSetting** value);

}

```

# Examples

## Win32 / COM

```cpp

// Note: The inferface numbers in the examples are not neccessarily a match. It's 
// added here to show how the API will look and feel.

wil::com_ptr<ICoreWebView2_27> webView2_13;
webView2_27 = m_webView.try_query<ICoreWebView2_27>();

wil::com_ptr<ICoreWebView2Profile> profile;
CHECK_FAILURE(webView2_13->get_Profile(&profile));

auto profile3= profile.try_query<ICoreWebView2Profile3>();

// Example of getting and setting the Enahanced secutrity mode globally

COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL value;
CHECK_FAILURE(profile3->get_PreferredEnhancedSecurityModeLevel(&value));
if (value == COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_OFF) {
      MessageBox(
      nullptr, L"Enhanced security mode level is off",
      L"Enhanced Security Mode Level", MB_OK);
} else {
      MessageBox(
      nullptr, L"Enhanced security mode level is Strict",
      L"Enhanced Security Mode Level", MB_OK);
}

CHECK_FAILURE(profile3->set_PreferredEnhancedSecurityModeLevel(COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_STRICT));

// Example of configuring the enhanced security mode via origin settings
// These take precedence over the global settings and act as an override

wil::com_ptr<ICoreWebView2Environment> environment;
CHECK_FAILURE(webview2->get_Environment(&environment));

auto environment6 = environment.try_query<ICoreWebView2Environment6>();

// Store the smart pointers to keep the objects alive
std::vector<wil::com_ptr<ICoreWebView2OriginSetting>> originSettingsStorage;
// This vector stores raw pointers for the API call
std::vector<ICoreWebView2OriginSetting*> originSettings;

for (MyOriginConfigStruct entry : m_originConfig) {
   wil::com_ptr<ICoreWebview2OriginSetting> origin_setting;
   CHECK_FAILURE(environment6->CreateOriginSetting(&origin_setting));

   origin_setting->put_OriginMatch(entry.uri.c_str());
   origin_setting->put_EnhancedSecurityMode(entry.enableESM ? COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE_ENFORCE : COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE_DEFAULT);

   originSettings.push_back(originSettings.get();)
   originSettingsStorage.push_back(std::move(origin_setting));
}

CHECK_FAILURE(profile2->SetOriginSettings(
                    static_cast<uint32_t>(originSettings.size()), originSettings.data()));


// get origin settings

UINT32 counts = 0;
ICoreWebView2StagingOriginSetting** originSettings = nullptr;
HRESULT hr = profileStaging2->GetOriginSettings(&counts, &originSettings);

for (const auto& setting : originSettingsVector)
{
      COREWEBVIEW2_FULL_ORIGIN_SETTING_STATE currState;
      hr = setting->get_EnhancedSecurityMode(&currState);
      wil::unique_cotaskmem_string originMatch;
      hr = setting->get_OriginMatch(&originMatch);
      if (SUCCEEDED(hr) && originMatch)
      {
         std::cout << "Enhanced security mode state: "<< currState << " for - " << originMatch << std::endl
      }
}

```
