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

    - **CreateTrustedOriginFeatureSettings**: Creates a collection of CoreWebView2TrustedOriginFeatureSetting objects, which can be used to call SetTrustedOriginFeatures to configure features for trusted origins
    - **SetTrustedOriginFeatures**: Sets the feature settings for specified origins.
    - **GetTrustedOriginFeaturesAsync**: Gets the feature settings (Feature and isEnabled) for a specified origin.
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
    
    std::vector<COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE> comFeatures;
    std::vector<BOOL> comIsEnabled;
    if (feature.size() >= 3)
    {
        comFeatures.push_back(COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ACCENT_COLOR);
        comIsEnabled.push_back(feature[0] ? TRUE : FALSE);

        comFeatures.push_back(COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_PERSISTENT_STORAGE);
        comIsEnabled.push_back(feature[1] ? TRUE : FALSE);

        comFeatures.push_back(COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE);
        comIsEnabled.push_back(feature[2] ? TRUE : FALSE);
    }

    // Create a feature collection from the arrays.
    wil::com_ptr<ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView> featureCollection;
    CHECK_FAILURE(
        stagingProfile3->CreateTrustedOriginFeatureSettings(
            static_cast<UINT32>(comFeatures.size()),
            comFeatures.data(),
            comIsEnabled.data(),
            &featureCollection));

    std::vector<LPCWSTR> origins;
    for (const auto& pattern : originPatterns)
    {
        origins.push_back(pattern.c_str());
    }
    CHECK_FAILURE(
        stagingProfile3->SetTrustedOriginFeatures(
            static_cast<UINT32>(origins.size()),
            origins.data(),
            featureCollection.get()));
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
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ACCENT_COLOR,
  /// Specifies persistent storage capabilities for the origin.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_PERSISTENT_STORAGE,
  /// Specifies enhanced security mode settings for the origin.
  COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
} COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE;

/// Receives the result of the `GetTrustedOriginFeatures` method.
interface ICoreWebView2StagingGetTrustedOriginFeaturesCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView* result);
}


/// This is the ICoreWebView2Profile interface for trusted origin feature management.
interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Creates a collection of CoreWebView2TrustedOriginFeatureSetting objects.
  /// This method allows creating a feature settings collection that can be used with
  /// SetTrustedOriginFeatures to configure features for trusted origins.
  HRESULT CreateTrustedOriginFeatureSettings(
      [in] UINT32 featuresCount,
      [in] COREWEBVIEW2_TRUSTED_ORIGIN_FEATURE* features,
      [in] BOOL* isEnabled
      , [out, retval] ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView** value);

  /// Sets the feature configurations for specified origins.
  /// This method allows configuring multiple features for trusted origins,
  /// such as accent color, persistent storage, and enhanced security mode.
  /// The origins can be both exact origin strings and wildcard patterns.
  /// For wildcard patterns, `*` matches zero or more characters.
  /// Examples:
  /// | Origin Filter String | What It Matches | Description |
  /// |---------|-----------------|-------------|
  /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
  /// | `https://*.contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
  /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
  /// | `*contoso.*` | `https://www.contoso.com`,`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
  /// | `*example/` | `https://app.example/`,`https://api.example/` | Matches any subdomain and top-level domain variations |
  /// | `https://xn--qei.example/` | `https://â¤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
  /// 
  HRESULT SetTrustedOriginFeatures(
      [in] UINT32 originsCount,
      [in] LPCWSTR* origins,
      [in] ICoreWebView2StagingTrustedOriginFeatureSettingCollectionView* features
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
[uuid(edf2c30e-daab-572c-887b-61e5acb8c305), object, pointer_default(unique)]
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
        public async Task GetTrustedOriginFeaturesAsync(string origins);

        public void SetTrustedOriginFeatures(IEnumerable<string> origins, IEnumerable<KeyValuePair<CoreWebView2TrustedOriginFeature, bool>> features);
    }
}
```