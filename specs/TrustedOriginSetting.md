Trusted Origin Support for WebView2
===

# Background

WebView2 applications often require different security and feature policies for different origins based on trust levels. Some applications need to enable specific features only for trusted origins while applying stricter security measures to untrusted content.

Currently, WebView2 applies uniform security policies across all origins, which creates two key challenges:
- **Feature Access Control**: Applications cannot selectively enable advanced features (such as certain APIs or capabilities) only for origins they trust, forcing them to either expose these features to all origins or disable them entirely.
- **Performance vs Security Trade-offs**: Security features like Enhanced Security Mode, while important for untrusted content, can impact performance when applied to trusted origins where such protections may be unnecessary.

For example, a content management application might want to allow full feature access and disable security restrictions when loading trusted administrative interfaces, while maintaining strict security policies for user-generated or external content loaded in the same WebView2 instance.

The Trusted Origin API addresses these scenarios by allowing applications to designate specific origins as trusted, enabling fine-grained control over which security and feature policies apply to different content sources.

# Description

This specification introduces the following APIs.

1. On `CoreWebView2Profile`  

    - **CreateTrustedOriginFeatureSetting**: Creates a CoreWebView2TrustedOriginFeatureSetting objects, which can be used to create an array to call SetTrustedOriginFeatures to configure features for trusted origins
    - **SetTrustedOriginFeatures**: Sets the feature settings for specified origins.
    - **GetTrustedOriginFeatures**: Gets the feature settings (Feature and isEnabled) for a specified origin asynchronously.
2. `ICoreWebView2TrustedOriginFeatureSetting`interface, is simply a tuple which has feature enum and feature state ( enabled or disabled ). For now the feature enum can have three values

    - AccentColor 
    - EnhancedSecurityMode
    - PersistentStorage

    The feature state is a boolean which can take two values : true (for enable) and false (for disable). 

# Example

## Set Origin Setting for an Origin Pattern

### C++ example

```cpp
// This method sets the trusted origin feature settings for the specified origin patterns.
// It takes a vector of origin patterns (e.g., "https://*.contoso.com") and a vector of
// boolean flags representing the enabled state for AccentColor, PersistentStorage, and
// EnhancedSecurityMode features respectively.
void ScenarioTrustedOrigin::SetFeatureForOrigins(std::vector<std::wstring> originPatterns,
                                              std::vector<bool> feature)
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();
    
    // featureSettings holds wil::com_ptr for COM lifetime management (keeps refcount > 0).
    // featureSettingsRaw holds raw pointers extracted from featureSettings to pass to the API.
    // Both are needed because the API requires a pointer array, but we need smart pointers to prevent premature COM object destruction.
    std::vector<wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting>> featureSettings;
    std::vector<ICoreWebView2StagingTrustedOriginFeatureSetting*> featureSettingsRaw;
    
    if (feature.size() >= 3)
    {
        if (feature[0])
        {
            wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting> setting;
            CHECK_FAILURE(stagingProfile3->CreateTrustedOriginFeatureSetting(
                COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ACCENT_COLOR,
                TRUE,
                &setting));
            featureSettings.push_back(setting);
            featureSettingsRaw.push_back(setting.get());
        }

        if (feature[1])
        {
            wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting> setting;
            CHECK_FAILURE(stagingProfile3->CreateTrustedOriginFeatureSetting(
                COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_PERSISTENT_STORAGE,
                TRUE,
                &setting));
            featureSettings.push_back(setting);
            featureSettingsRaw.push_back(setting.get());
        }

        if (feature[2])
        {
            wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSetting> setting;
            CHECK_FAILURE(stagingProfile3->CreateTrustedOriginFeatureSetting(
                COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
                TRUE,
                &setting));
            featureSettings.push_back(setting);
            featureSettingsRaw.push_back(setting.get());
        }
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
var profile = webView2.CoreWebView2.Profile;

// Create feature settings collection
var features = new[]
{
    new KeyValuePair<CoreWebView2TrustedOriginFeature, bool>(CoreWebView2TrustedOriginFeature.AccentColor, false),
    new KeyValuePair<CoreWebView2TrustedOriginFeature, bool>(CoreWebView2TrustedOriginFeature.PersistentStorage, true),
    new KeyValuePair<CoreWebView2TrustedOriginFeature, bool>(CoreWebView2TrustedOriginFeature.EnhancedSecurityMode, false)
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

/// Receives the result of the `GetTrustedOriginFeatures` method.
interface ICoreWebView2StagingGetTrustedOriginFeaturesCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView* result);
}


/// This is the ICoreWebView2Profile interface for trusted origin feature management.
interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Creates a CoreWebView2TrustedOriginFeatureSetting objects.
  /// This method allows creating a feature settings object that can be used with
  /// SetTrustedOriginFeatures to configure features for trusted origins.
  HRESULT CreateTrustedOriginFeatureSetting(
      [in] COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE features,
      [in] BOOL isEnabled
      , [out, retval] ICoreWebView2StagingTrustedOriginFeatureSetting** value);

  /// Sets the feature configurations for specified origins.
  /// This method allows configuring multiple features for trusted origins,
  /// such as accent color, persistent storage, and enhanced security mode.
  /// The origins can be both exact origin strings and wildcard patterns.
  /// For detailed examples, refer to the table at: https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addwebresourcerequestedfilter.
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

## .Net/WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{

    public enum CoreWebView2TrustedOriginFeature
    {
        AccentColor = 0,
        PersistentStorage = 1,
        EnhancedSecurityMode = 2,
    }

    public partial class CoreWebView2Profile
    {
        public async Task<IEnumerable<KeyValuePair<CoreWebView2TrustedOriginFeature, bool>>> GetTrustedOriginFeaturesAsync(string origins);

        public void SetTrustedOriginFeatures(IEnumerable<string> origins, IEnumerable<KeyValuePair<CoreWebView2TrustedOriginFeature, bool>> features);
    }
}
```