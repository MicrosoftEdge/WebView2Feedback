Enhanced Security Mode
===

# Background

Enhanced Security Mode (ESM) adds protection against memory-related
vulnerabilities by disabling JavaScript Just-in-Time (JIT) compilation and
enabling additional operating system protections. These protections can reduce
JavaScript performance.

The `CoreWebView2Profile.EnhancedSecurityModeState` property lets applications
enable or disable ESM for all WebView2 instances sharing a profile.

# Description

`EnhancedSecurityModeState` has two values:

- `Disabled` (the default): Enhanced Security Mode is disabled.
- `Enabled`: Enhanced Security Mode is enabled.

The setting is not persisted to the user data folder. It resets to `Disabled`
when the profile is destroyed and recreated. Changes apply to new navigations;
existing pages require a reload for the change to take effect.

Applications can configure exceptions for specific origins using
`CoreWebView2Profile.SetOriginFeatures` with
`CoreWebView2OriginFeature.EnhancedSecurityMode`. An origin without an explicit
configuration uses the profile's `EnhancedSecurityModeState`. See
[Origin Feature Configuration][origins] for origin patterns,
precedence, and resetting origin settings.

Only disable ESM for fully trusted, app-controlled content where the
compatibility or performance trade-off is understood.

# Examples

The following examples enable ESM for a profile, then disable it for a known,
trusted application origin that requires JIT compilation. Configure the profile
before navigating to the content.

## Win32 C++

```cpp
HRESULT ConfigureEnhancedSecurityMode(ICoreWebView2Profile* profile)
{
    wil::com_ptr<ICoreWebView2ExperimentalProfile17> esmProfile;
    RETURN_IF_FAILED(profile->QueryInterface(IID_PPV_ARGS(&esmProfile)));

    wil::com_ptr<ICoreWebView2ExperimentalProfile16> originProfile;
    RETURN_IF_FAILED(profile->QueryInterface(IID_PPV_ARGS(&originProfile)));

    RETURN_IF_FAILED(esmProfile->put_EnhancedSecurityModeState(
        COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE_ENABLED));

    wil::com_ptr<ICoreWebView2ExperimentalOriginFeatureSetting> setting;
    RETURN_IF_FAILED(originProfile->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_DISABLED,
        &setting));

    LPCWSTR origins[] = {L"https://app.contoso.com"};
    ICoreWebView2ExperimentalOriginFeatureSetting* features[] = {setting.get()};
    RETURN_IF_FAILED(originProfile->SetOriginFeatures(
        ARRAYSIZE(origins), origins, ARRAYSIZE(features), features));
    return S_OK;
}
```

[origins]: https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/TrustedOriginSetting.md

## .NET and WinRT

```c#
void ConfigureEnhancedSecurityMode(CoreWebView2Profile profile)
{
    profile.EnhancedSecurityModeState =
        CoreWebView2EnhancedSecurityModeState.Enabled;

    var features =
        new Dictionary<CoreWebView2OriginFeature, CoreWebView2OriginFeatureState>
        {
            {
                CoreWebView2OriginFeature.EnhancedSecurityMode,
                CoreWebView2OriginFeatureState.Disabled
            },
        };
    profile.SetOriginFeatures(new[] { "https://app.contoso.com" }, features);
}
```

# API Details

## COM

```cpp
/// Enhanced Security Mode state.
[v1_enum]
typedef enum COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE {
  /// Enhanced Security Mode is disabled.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE_DISABLED,
  /// Disables JavaScript JIT compilation and enables additional operating
  /// system protections. This may reduce JavaScript performance.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE_ENABLED,
} COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE;

/// Controls the Enhanced Security Mode state for a profile.
[uuid(9e84633f-4631-51a1-9197-b3a469a4246a), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalProfile17 : IUnknown {
  /// Gets the EnhancedSecurityModeState property.
  [propget] HRESULT EnhancedSecurityModeState(
      [out, retval] COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE* value);

  /// Enables or disables Enhanced Security Mode for all WebViews sharing
  /// the profile. The default is Disabled.
  ///
  /// The setting is not persisted to the user data folder and resets when
  /// the profile is recreated.
  ///
  /// Changes apply to new navigations. Existing pages require a reload.
  [propput] HRESULT EnhancedSecurityModeState(
      [in] COREWEBVIEW2_ENHANCED_SECURITY_MODE_STATE value);
}
```

## WinRT and .NET

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2EnhancedSecurityModeState
    {
        Disabled = 0,
        Enabled = 1,
    };

    runtimeclass CoreWebView2Profile
    {
        // ... existing members ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile14")]
        {
            CoreWebView2EnhancedSecurityModeState EnhancedSecurityModeState
                { get; set; };
        }
    }
}
```
