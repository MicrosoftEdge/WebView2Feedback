Origin Feature Configuration for WebView2
===

# Background

Many WebView2 applications need to apply different security and feature
policies depending on the origin of the content they host. In some scenarios,
applications must enable advanced capabilities for specific origins while
enforcing stricter protections for other origins.

By default, WebView2 enforces a single, uniform security model across all
origins. This creates two primary limitations:

- **Feature Access Control**: Applications cannot selectively enable
  privileged features—such as specific APIs or advanced capabilities—for
  certain origins only. As a result, developers must either expose these
  features to all content or disable them entirely.

- **Performance and Security Trade-offs**: Security mechanisms such as
  Enhanced Security Mode are essential for external content but may introduce
  unnecessary overhead when applied to first‑party experiences.

For example, a content management system may need to grant full feature access
and relax certain security restrictions for its administrative interface,
while still applying strict security policies to user‑generated or external
content displayed within the same WebView2 instance.

The Origin Configuration API enables these scenarios by allowing applications
to configure origin-specific settings for different features. Applications can
define feature policies for specific origins or origin patterns, giving
developers fine‑grained control over how features and security mechanisms are
applied to content from various sources.

# Description

This specification introduces the following interfaces:

1. `ICoreWebView2ExperimentalProfile16`:

    This interface provides APIs for defining, applying, and retrieving origin
    feature settings. It introduces the following members:

    - **CreateOriginFeatureSetting**: Creates a new
      CoreWebView2OriginFeatureSetting object. The returned object can be
      added to the collection passed to SetOriginFeatures to configure
      feature behavior for origins.

    - **SetOriginFeatures**: Applies the specified origin feature settings to
      one or more origins associated with this profile.

    - **GetEffectiveFeaturesForOrigin**: Asynchronously retrieves the origin feature
      settings—both the feature identifier and its enabled/disabled state—for
      a specified origin.

2. `ICoreWebView2ExperimentalOriginFeatureSetting`:

    This interface pairs a feature enumeration value with its corresponding
    state (enabled or disabled). Currently, the feature enumeration supports
    the following values:

    - EnhancedSecurityMode
    - ReputationChecking

# Example

## Configure Origin Settings for Origin Patterns

### C++ example

Only disable reputation checking for fully trusted, app-controlled origins.
The examples use an exact origin rather than trusting every subdomain.

```cpp
void SetOriginFeatures()
{
    wil::com_ptr<ICoreWebView2ExperimentalProfile16> originProfile;
    CHECK_FAILURE(m_webviewProfile->QueryInterface(IID_PPV_ARGS(&originProfile)));

    wil::com_ptr<ICoreWebView2ExperimentalOriginFeatureSetting>
        enhancedSecuritySetting;
    CHECK_FAILURE(originProfile->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED,
        &enhancedSecuritySetting));

    wil::com_ptr<ICoreWebView2ExperimentalOriginFeatureSetting>
        reputationCheckingSetting;
    CHECK_FAILURE(originProfile->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_REPUTATION_CHECKING,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_DISABLED,
        &reputationCheckingSetting));

    // Set features for origin patterns
    ICoreWebView2ExperimentalOriginFeatureSetting* features[] = {
        enhancedSecuritySetting.get(),
        reputationCheckingSetting.get(),
    };

    LPCWSTR origins[] = { L"https://app.contoso.com" };

    CHECK_FAILURE(originProfile->SetOriginFeatures(
        ARRAYSIZE(origins),
        origins,
        ARRAYSIZE(features),
        features));
}

void GetFeatureSettingsForOrigin()
{
    wil::com_ptr<ICoreWebView2ExperimentalProfile16> originProfile;
    CHECK_FAILURE(m_webviewProfile->QueryInterface(IID_PPV_ARGS(&originProfile)));

    std::wstring origin = L"https://app.contoso.com";

    auto completedHandler =
        Callback<ICoreWebView2ExperimentalGetEffectiveFeaturesForOriginCompletedHandler>(
            [this, origin](HRESULT errorCode,
                ICoreWebView2ExperimentalOriginFeatureSettingCollectionView* result) -> HRESULT
            {
                RETURN_IF_FAILED(errorCode);
                UINT32 count = 0;
                CHECK_FAILURE(result->get_Count(&count));

                std::wstring message = L"Features for origin: " + origin + L"\n";
                for (UINT32 i = 0; i < count; i++)
                {
                    wil::com_ptr<ICoreWebView2ExperimentalOriginFeatureSetting>
                        setting;
                    CHECK_FAILURE(result->GetValueAtIndex(i, &setting));

                    COREWEBVIEW2_ORIGIN_FEATURE feature;
                    COREWEBVIEW2_ORIGIN_FEATURE_STATE state;
                    CHECK_FAILURE(setting->get_Feature(&feature));
                    CHECK_FAILURE(setting->get_State(&state));

                    bool enabled =
                        state == COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED;
                    message += L"Feature: " +
                        std::to_wstring(static_cast<int>(feature)) +
                        L", Enabled: " + (enabled ? L"True" : L"False") + L"\n";
                }

                MessageBoxW(m_appWindow->GetMainWindow(), message.c_str(),
                    L"Origin Features", MB_OK);
                return S_OK;
            });
    CHECK_FAILURE(originProfile->GetEffectiveFeaturesForOrigin(
        origin.c_str(), completedHandler.Get()));
}
```

### .NET

```c#
public void SetOriginFeatures()
{
    // Create feature settings collection
    var features =
        new Dictionary<CoreWebView2OriginFeature, CoreWebView2OriginFeatureState>
        {
            {
                CoreWebView2OriginFeature.EnhancedSecurityMode,
                CoreWebView2OriginFeatureState.Enabled
            },
            {
                CoreWebView2OriginFeature.ReputationChecking,
                CoreWebView2OriginFeatureState.Disabled
            },
        };

    // Set features for origin patterns
    var origins = new[] { "https://app.contoso.com" };
    m_webviewProfile.SetOriginFeatures(origins, features);
}

private async Task GetFeatureSettingsForOriginAsync()
{
    var settings = await m_webviewProfile.GetEffectiveFeaturesForOriginAsync(
        "https://app.contoso.com");
    var builder = new StringBuilder();
    foreach (var setting in settings)
    {
        builder.AppendLine($"Feature: {setting.Key}, State = {setting.Value}");
    }
    m_appWindow.AsyncMessageBox(builder.ToString(), "Origin features");
}
```

### WinRT

The WinRT `SetOriginFeatures` example is the same as the .NET example above.
Unlike .NET's key/value pairs, WinRT returns a vector view of
`CoreWebView2OriginFeatureSetting` objects:

```c#
private async Task GetFeatureSettingsForOriginAsync()
{
    var settings = await m_webviewProfile.GetEffectiveFeaturesForOriginAsync(
        "https://app.contoso.com");
    var builder = new StringBuilder();
    foreach (var setting in settings)
    {
        builder.AppendLine($"Feature: {setting.Feature}, State = {setting.State}");
    }
    m_appWindow.AsyncMessageBox(builder.ToString(), "Origin features");
}
```

# API details

## C++
```cpp
/// Specifies the feature types that can be configured for origins.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_FEATURE {
  /// Specifies enhanced security mode settings for the origin.
  /// Enhanced Security Mode provides additional protections by disabling or restricting
  /// certain web platform features that may pose security risks, such as JIT compilation,
  /// certain JavaScript APIs, and other potentially dangerous capabilities. This feature
  /// is particularly useful for protecting against zero-day exploits and reducing attack
  /// surface. When enabled for an origin, that origin will have Enhanced Security Mode
  /// applied; when disabled, normal security mode is used.
  /// Enhanced security mode can be configured globally via EnhancedSecurityModeState API on profile.
  /// If Enhanced Security Mode is not configured for an origin, the global profile setting will apply.
  ///
  /// For more information about Enhanced Security Mode, see:
  /// https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/security
  COREWEBVIEW2_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
  /// Specifies per-origin reputation checking settings.
  /// Reputation checking protects users from phishing and malware by checking
  /// navigated URLs and downloaded files against a cloud-based reputation service.
  /// Setting this feature to `Disabled` for an origin will skip reputation
  /// checks for navigations and downloads from that origin, effectively
  /// allow-listing it. If reputation checking is not configured for an origin,
  /// it is governed by [IsReputationCheckingRequired](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2settings.isreputationcheckingrequired).
  /// Note: If `IsReputationCheckingRequired` is set to false,
  /// setting this feature to `Enabled` for a specific origin
  /// will not re-enable reputation checks for that origin.
  /// `IsReputationCheckingRequired` takes precedence.
  ///
  /// Warning: Disabling reputation checking for an origin bypasses phishing and
  /// malware reputation checks. Only disable for fully trusted, app-controlled
  /// origins where the content is known to be safe.
  COREWEBVIEW2_ORIGIN_FEATURE_REPUTATION_CHECKING,
} COREWEBVIEW2_ORIGIN_FEATURE;

/// Specifies the state of the origin feature.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_FEATURE_STATE {
  /// Sets the enabled state of the origin feature.
  COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED,
  /// Sets the disabled state of the origin feature.
  COREWEBVIEW2_ORIGIN_FEATURE_STATE_DISABLED,
} COREWEBVIEW2_ORIGIN_FEATURE_STATE;

/// Receives the result of the `GetEffectiveFeaturesForOrigin` method.
[uuid(4e5d6c7b-8a9f-0e1d-2c3b-4a5e6d7c8b9a), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalGetEffectiveFeaturesForOriginCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ExperimentalOriginFeatureSettingCollectionView* result);
}


/// This is the ICoreWebView2Profile interface for origin feature management.
[uuid(9234b39e-e9d7-5f73-88d8-6413612ba09b), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalProfile16 : IUnknown {
  /// Creates a CoreWebView2OriginFeatureSetting objects. This object represents a specific feature and its state (enabled or disabled).
  /// This method allows creating a feature settings object that can be used with
  /// SetOriginFeatures to configure features for origins.
  HRESULT CreateOriginFeatureSetting(
      [in] COREWEBVIEW2_ORIGIN_FEATURE featureKind,
      [in] COREWEBVIEW2_ORIGIN_FEATURE_STATE featureState
      , [out, retval] ICoreWebView2ExperimentalOriginFeatureSetting** value);

  /// Configures one or more feature settings for the specified origins.
  ///
  /// This method applies feature configurations (such as enhanced security
  /// mode or reputation checking) to origins. Origins
  /// may be provided as exact origin strings or as wildcard patterns.
  ///
  /// The origin pattern can be an exact origin string or a wildcard pattern.
  /// For wildcard patterns, `*` matches zero or more characters.
  /// Examples:
  /// | Origin Filter String | What It Matches | Description |
  /// |---------|-----------------|-------------|
  /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
  /// | `https://[*.]contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
  /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
  /// | `https://www.microsoft.com:*` | `https://www.microsoft.com:123` | Matches any port for the specified origin |
  /// | `[*.]example.com` | `https://www.example.com`,`http://abc.example.com` | Matches any subdomain with any protocol for the specified domain |
  /// | `https://xn--qei.example/` | `https://❤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
  ///
  /// Calling this method multiple times with the same (featureKind, featureState)
  /// pair overwrites the previous configuration; the most recent call takes
  /// precedence.
  ///
  /// When multiple configurations exist for the same feature but specify
  /// different featureState values, the configuration whose origin pattern is
  /// more specific takes precedence.
  ///
  /// The specificity of an origin pattern is determined by the presence and
  /// placement of wildcards. Three wildcard categories influence specificity:
  /// - Wildcards in the port (for example, `https://www.example.com:*/*`)
  /// - Wildcards in the scheme (for example, `*://www.example.com:123/*`)
  /// - Wildcards in the hostname (for example, `https://*.example.com:123/*`)
  ///
  /// If one pattern is more specific in one component but less specific in
  /// another, specificity is evaluated in the following order:
  /// 1. Hostname
  /// 2. Scheme
  /// 3. Port
  ///
  /// For example, the following patterns are ordered by precedence:
  /// `https://www.example.com:*/*` → `*://www.example.com:123/*` → `https://*.example.com:123/*`.
  ///
  /// To reset the origin list for a particular (feature, state) pair, call
  /// SetOriginFeatures with an empty origin list or nullptr for the same
  /// feature setting.
  /// For example,
  /// SetOriginFeatures(1, {"https://microsoft.com"}, 1, {{ESM: Enabled}});
  /// SetOriginFeatures(0, {}, 1, {{ESM: Enabled}}); // Resets {ESM: Enabled}
  HRESULT SetOriginFeatures(
      [in] UINT32 originsCount,
      [in] LPCWSTR* originPatterns,
      [in] UINT32 featureSettingsCount,
      [in] ICoreWebView2ExperimentalOriginFeatureSetting** featureSettings
  );

  /// Gets the effective feature settings for a specified origin.
  /// Returns a collection of feature settings for all the features in
  /// `COREWEBVIEW2_ORIGIN_FEATURE`. This collection contains the effective
  /// (computed) setting values for all features, including features that were
  /// not explicitly configured via `SetOriginFeatures` and thus have their
  /// default values.
  /// The order of features in the returned collection is not guaranteed.
  /// The origin should have a valid scheme and host (e.g. "https://www.example.com"),
  /// otherwise the method fails with `E_INVALIDARG`.
  HRESULT GetEffectiveFeaturesForOrigin(
      [in] LPCWSTR origin
      , [in] ICoreWebView2ExperimentalGetEffectiveFeaturesForOriginCompletedHandler* handler);
}

/// Represents a feature setting configuration for a origin.
[uuid(4f774652-5134-5065-9748-deeec577852e), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalOriginFeatureSetting : IUnknown {
  /// The feature type for this setting.
  [propget] HRESULT Feature([out, retval] COREWEBVIEW2_ORIGIN_FEATURE* value);

  /// Indicates whether the feature is enabled for the origin.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_ORIGIN_FEATURE_STATE* value);
}


/// A collection of origin settings.
[uuid(f13210ed-3d4c-5d0c-9afd-4d994b7b56c3), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalOriginFeatureSettingCollectionView : IUnknown {
  /// Gets the number of objects contained in the `OriginFeatureSettingCollection`.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the object at the specified index.
  HRESULT GetValueAtIndex(
      [in] UINT32 index
      , [out, retval] ICoreWebView2ExperimentalOriginFeatureSetting** value);
}
```

## WinRT (MIDL3)

```c#
namespace Microsoft.Web.WebView2.Core
{

    enum CoreWebView2OriginFeatureState
    {
        Enabled = 0,
        Disabled = 1,
    };
    enum CoreWebView2OriginFeature
    {
        EnhancedSecurityMode = 0,
        ReputationChecking = 1,
    };

    runtimeclass CoreWebView2OriginFeatureSetting
    {
        // ICoreWebView2OriginFeatureSetting members
        CoreWebView2OriginFeature Feature { get; };

        CoreWebView2OriginFeatureState State { get; };
    }

    runtimeclass CoreWebView2Profile
    {
        [interface_name("Microsoft.Web.WebView2.Core.CoreWebView2Profile_Manual5")]
        {
            void SetOriginFeatures(
                Windows.Foundation.Collections.IIterable<String> origins,
                Windows.Foundation.Collections.IIterable<
                Windows.Foundation.Collections.IKeyValuePair<CoreWebView2OriginFeature, CoreWebView2OriginFeatureState> > features);

            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2OriginFeatureSetting> > GetEffectiveFeaturesForOriginAsync(String origin);
        }
    }
}
```

## .NET

The .NET methods accept origin patterns and feature/state pairs. The
asynchronous getter returns key/value pairs rather than WinRT setting objects.

```c#
void SetOriginFeatures(
    IEnumerable<string> origins,
    IEnumerable<KeyValuePair<CoreWebView2OriginFeature,
        CoreWebView2OriginFeatureState>> features);

Task<IEnumerable<KeyValuePair<CoreWebView2OriginFeature,
    CoreWebView2OriginFeatureState>>> GetEffectiveFeaturesForOriginAsync(
        string origin);
```
