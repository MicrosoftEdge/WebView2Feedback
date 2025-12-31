Trusted Origin Support for WebView2
===

# Background

Many WebView2 applications need to apply different security and feature policies depending on the trust level of the content they host. In some scenarios, applications must enable advanced capabilities for trusted origins while enforcing stricter protections for untrusted or external content.

By default, WebView2 enforces a single, uniform security model across all origins. This creates two primary limitations:

- **Feature Access Control**: Applications cannot selectively enable privileged features—such as specific APIs or advanced capabilities—for trusted origins only. As a result, developers must either expose these features to all content or disable them entirely.

- **Performance and Security Trade-offs**: Security mechanisms such as Enhanced Security Mode are essential for untrusted content but may introduce unnecessary overhead when applied to trusted, first‑party experiences.

For example, a content management system may need to grant full feature access and relax certain security restrictions for its administrative interface, while still applying strict security policies to user‑generated or external content displayed within the same WebView2 instance.

The Trusted Origin API enables these scenarios by allowing applications to explicitly identify trusted origins. Once designated, WebView2 can apply differentiated security and feature policies, giving developers fine‑grained control over how content from various sources is handled.

# Description

This specification introduces the following interfaces:

1. `ICoreWebView2Profile3`: 

    The ICoreWebView2Profile3 interface provides APIs for defining, applying, and retrieving trusted‑origin feature settings. It introduces the following members:

    - **CreateTrustedOriginFeatureSetting**: Creates a new CoreWebView2TrustedOriginFeatureSetting object. The returned object can be added to the collection passed to SetTrustedOriginFeatures to configure feature behavior for trusted origins.

    - **SetTrustedOriginFeatures**: Applies the specified trusted‑origin feature settings to one or more origins associated with this profile.

    - **GetTrustedOriginFeatures**: Asynchronously retrieves the trusted‑origin feature settings—both the feature identifier and its enabled/disabled state—for a specified origin.

2. `ICoreWebView2TrustedOriginFeatureSetting`: 

    The  ICoreWebView2TrustedOriginFeatureSetting interface represents a simple pairing of a feature enumeration value and its corresponding feature state (enabled or disabled). Currently, the feature enumeration supports the following values:

    - AccentColor 
    - EnhancedSecurityMode
    - PersistentStorage

# Example

## Configure Origin Settings for Origin Patterns

### C++ example

```cpp
// This method sets the trusted origin feature settings for the specified origin patterns.
// It takes a vector of origin patterns (e.g., "https://*.contoso.com") and a vector of
// feature-state pairs to configure for the trusted origins.
void ScenarioTrustedOrigin::SetFeatureForOrigins(
    std::vector<std::wstring> originPatterns,
    std::vector<std::pair<COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE, COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE>> features)
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();
    
    // featureSettings holds wil::com_ptr for COM lifetime management (keeps refcount > 0).
    // featureSettingsRaw holds raw pointers extracted from featureSettings to pass to the API.
    // Both are needed because the API requires a pointer array, but we need smart pointers to prevent premature COM object destruction.
    std::vector<wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting>> featureSettings;
    std::vector<ICoreWebView2StagingTrustedOriginFeatureSetting*> featureSettingsRaw;
    
    for (const auto& [featureKind, featureState] : features)
    {
        wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting> setting;
        CHECK_FAILURE(stagingProfile3->CreateTrustedOriginFeatureSetting(
            featureKind,
            featureState,
            &setting));
        featureSettings.push_back(setting);
        featureSettingsRaw.push_back(setting.get());
    }

    std::vector<LPCWSTR> origins;
    for (const auto& pattern : originPatterns)
    {
        origins.push_back(pattern.c_str());
    }
    
    CHECK_FAILURE(
        stagingProfile3->SetTrustedOriginFeatures(
            static_cast<UINT32>(origins.size()),
            origins.data(),
            static_cast<UINT32>(featureSettingsRaw.size()),
            featureSettingsRaw.data()));
}

void ScenarioTrustedOrigin::GetFeatureSettingsForOrigin()
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();

    TextInputDialog inputDialog(
        m_appWindow->GetMainWindow(),
        L"Get Trusted Origin Features",
        L"Enter the origin to retrieve feature settings for:",
        L"Origin:",
        std::wstring(L"https://www.microsoft.com"),
        false);  // not read-only

    if (inputDialog.confirmed)
    {
        std::wstring origin = inputDialog.input;

        CHECK_FAILURE(
            stagingProfile3->GetTrustedOriginFeatures(
                origin.c_str(),
                Callback<ICoreWebView2StagingGetTrustedOriginFeaturesCompletedHandler>(
                    [this, origin](HRESULT errorCode,
                           ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView* result) -> HRESULT
                    {
                        if (SUCCEEDED(errorCode))
                        {
                            UINT32 count = 0;
                            CHECK_FAILURE(result->get_Count(&count));

                            std::wstring message = L"Features for origin: " + origin + L"\n";
                            for (UINT32 i = 0; i < count; i++)  
                            {
                                wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting> setting;
                                CHECK_FAILURE(result->GetValueAtIndex(i, &setting));

                                COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE feature;
                                BOOL isEnabled;
                                CHECK_FAILURE(setting->get_Feature(&feature));
                                CHECK_FAILURE(setting->get_IsEnabled(&isEnabled));

                                message += L"Feature: " + std::to_wstring(static_cast<int>(feature)) +
                                           L", Enabled: " + (isEnabled ? L"True" : L"False") + L"\n";
                            }

                            MessageBoxW(m_appWindow->GetMainWindow(), message.c_str(), L"Trusted Origin Features", MB_OK);
                        }
                        return S_OK;
                    }).Get()));
    }
}
```

### .NET/WinRT 

```c#
using OriginFeatureSetting = System.Collections.Generic.KeyValuePair<CoreWebView2TrustedOriginFeature, CoreWebView2TrustedOriginFeatureState>;

// ...

var profile = webView2.CoreWebView2.Profile;

// Create feature settings collection
var features = new[]
{
    new OriginFeatureSetting(CoreWebView2TrustedOriginFeature.AccentColor, CoreWebView2TrustedOriginFeatureState.Enabled),
    new OriginFeatureSetting(CoreWebView2TrustedOriginFeature.PersistentStorage, CoreWebView2TrustedOriginFeatureState.Disabled),
    new OriginFeatureSetting(CoreWebView2TrustedOriginFeature.EnhancedSecurityMode, CoreWebView2TrustedOriginFeatureState.Enabled)
};

// Set features for origin patterns
var origins = new[] { "https://*.contoso.com" };
profile.SetTrustedOriginFeatures(origins, features);

// Get features for a specific origin
var originFeatures = await profile.GetTrustedOriginFeaturesAsync("https://app.contoso.com");
```


# API details

## C++
```cpp
/// Specifies the feature types that can be configured for trusted origins.
[v1_enum]
typedef enum COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE {
  /// Specifies the accent color feature for the origin.
  /// By default, the accent color feature is disabled for all origins.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ACCENT_COLOR,
  /// Specifies persistent storage capabilities for the origin.
  /// By default, persistent storage is disabled for all origins.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_PERSISTENT_STORAGE,
  /// Specifies enhanced security mode settings for the origin.
  /// Enhanced security mode can be configured globally via EnhancedSecurityModeLevel API on profile.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
} COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE;

/// Specifies the state of the trusted origin feature.
[v1_enum]
typedef enum COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE {
  /// Sets the enabled state of the trusted origin feature.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE_ENABLED,
  /// Sets the disabled state of the trusted origin feature.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE_DISABLED,
} COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE;

/// Receives the result of the `GetTrustedOriginFeatures` method.
interface ICoreWebView2StagingGetTrustedOriginFeaturesCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView* result);
}


/// This is the ICoreWebView2Profile interface for trusted origin feature management.
interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Creates a CoreWebView2TrustedOriginFeatureSetting objects. This object represents a specific feature and its state (enabled or disabled).
  /// This method allows creating a feature settings object that can be used with
  /// SetTrustedOriginFeatures to configure features for trusted origins.
  HRESULT CreateTrustedOriginFeatureSetting(
      [in] COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE featureKind,
      [in] COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_STATE featureState
      , [out, retval] ICoreWebView2StagingTrustedOriginFeatureSetting** value);

  /// Configures one or more feature settings for the specified origins. 
	/// 
	/// This method applies feature configurations—such as accent color support, 
	/// persistent storage, or enhanced security mode—to trusted origins. Origins 
	/// may be provided as exact origin strings or as wildcard patterns. 
	/// 
	/// For examples of origin pattern matching, see the table in: 
	/// https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addwebresourcerequestedfilter. 
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
  HRESULT SetTrustedOriginFeatures(
      [in] UINT32 originsCount,
      [in] LPCWSTR* originPatterns,
      [in] UINT32 featureCount,
      [in] ICoreWebView2StagingTrustedOriginFeatureSetting** features
  );

  /// Gets the feature configurations for a specified origin.
  /// Returns a collection of feature settings that have been configured for the origin.
  /// If no features have been configured for the origin, an empty collection is returned.
  /// The origin should have a valid scheme and host (e.g. "https://www.example.com"),
  /// otherwise the method fails with `E_INVALIDARG`.
  /// The returned collection contains all the features that are part of `CoreWebView2TrustedOriginFeature`.
  HRESULT GetTrustedOriginFeatures(
      [in] LPCWSTR origin
      , [in] ICoreWebView2StagingGetTrustedOriginFeaturesCompletedHandler* handler);
}

/// Represents a feature setting configuration for a trusted origin.
interface ICoreWebView2StagingTrustedOriginFeatureSetting : IUnknown {
  /// The feature type for this setting.
  [propget] HRESULT Feature([out, retval] COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE* value);

  /// Indicates whether the feature is enabled for the origin.
  [propget] HRESULT IsEnabled([out, retval] BOOL* value);
}


/// A collection of trusted origin settings.
interface ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView : IUnknown {
  /// Gets the number of objects contained in the `TrustedOriginFeatureSettingCollection`.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the object at the specified index.
  HRESULT GetValueAtIndex(
      [in] UINT32 index
      , [out, retval] ICoreWebView2StagingTrustedOriginFeatureSetting** value);
}
```

## MIDL3

```c#
namespace Microsoft.Web.WebView2.Core
{

    enum CoreWebView2TrustedOriginFeatureState
    {
        Enabled = 0,
        Disabled = 1,
    };
    enum CoreWebView2TrustedOriginFeature
    {
        AccentColor = 0,
        PersistentStorage = 1,
        EnhancedSecurityMode = 2,
    };

    runtimeclass CoreWebView2TrustedOriginFeatureSetting
    {
        // ICoreWebView2StagingTrustedOriginFeatureSetting members
        CoreWebView2TrustedOriginFeature Feature { get; };

        Boolean IsEnabled { get; };
    }

    runtimeclass CoreWebView2Profile 
    {
        [interface_name("Microsoft.Web.WebView2.Core.CoreWebView2Profile_Manual5")]
        {
            void SetTrustedOriginFeatures(
                Windows.Foundation.Collections.IIterable<String> origins,
                Windows.Foundation.Collections.IIterable<
                Windows.Foundation.Collections.IKeyValuePair<CoreWebView2TrustedOriginFeature, CoreWebView2TrustedOriginFeatureState> > features);

            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2TrustedOriginFeatureSetting> > GetTrustedOriginFeaturesAsync(String origin);
        }
    }
}
```