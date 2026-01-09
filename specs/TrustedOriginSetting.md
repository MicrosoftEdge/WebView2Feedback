Origin Feature Configuration for WebView2
===

# Background

Many WebView2 applications need to apply different security and feature policies depending on the origin of the content they host. In some scenarios, applications must enable advanced capabilities for specific origins while enforcing stricter protections for other origins.

By default, WebView2 enforces a single, uniform security model across all origins. This creates two primary limitations:

- **Feature Access Control**: Applications cannot selectively enable privileged features—such as specific APIs or advanced capabilities—for certain origins only. As a result, developers must either expose these features to all content or disable them entirely.

- **Performance and Security Trade-offs**: Security mechanisms such as Enhanced Security Mode are essential for external content but may introduce unnecessary overhead when applied to first‑party experiences.

For example, a content management system may need to grant full feature access and relax certain security restrictions for its administrative interface, while still applying strict security policies to user‑generated or external content displayed within the same WebView2 instance.

The Origin Configuration API enables these scenarios by allowing applications to configure origin-specific settings for different features. Applications can define feature policies for specific origins or origin patterns, giving developers fine‑grained control over how features and security mechanisms are applied to content from various sources.

# Description

This specification introduces the following interfaces:

1. `ICoreWebView2Profile3`: 

    The ICoreWebView2Profile3 interface provides APIs for defining, applying, and retrieving origin feature settings. It introduces the following members:

    - **CreateOriginFeatureSetting**: Creates a new CoreWebView2OriginFeatureSetting object. The returned object can be added to the collection passed to SetOriginFeatures to configure feature behavior for origins.

    - **SetOriginFeatures**: Applies the specified origin feature settings to one or more origins associated with this profile.

    - **GetOriginFeatures**: Asynchronously retrieves the origin feature settings—both the feature identifier and its enabled/disabled state—for a specified origin.

2. `ICoreWebView2OriginFeatureSetting`: 

    The  ICoreWebView2OriginFeatureSetting interface represents a simple pairing of a feature enumeration value and its corresponding feature state (enabled or disabled). Currently, the feature enumeration supports the following values:

    - AccentColor 
    - EnhancedSecurityMode
    - PersistentStorage

# Example

## Configure Origin Settings for Origin Patterns

### C++ example

```cpp
void SetOriginFeatures()
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();
    
    // Create feature settings
    wil::com_ptr<ICoreWebView2StagingOriginFeatureSetting> accentColorSetting;
    CHECK_FAILURE(stagingProfile3->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_ACCENT_COLOR,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED,
        &accentColorSetting));

    wil::com_ptr<ICoreWebView2StagingOriginFeatureSetting> persistentStorageSetting;
    CHECK_FAILURE(stagingProfile3->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_PERSISTENT_STORAGE,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_DISABLED,
        &persistentStorageSetting));

    wil::com_ptr<ICoreWebView2StagingOriginFeatureSetting> enhancedSecuritySetting;
    CHECK_FAILURE(stagingProfile3->CreateOriginFeatureSetting(
        COREWEBVIEW2_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
        COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED,
        &enhancedSecuritySetting));

    // Set features for origin patterns
    ICoreWebView2StagingOriginFeatureSetting* features[] = {
        accentColorSetting.get(),
        persistentStorageSetting.get(),
        enhancedSecuritySetting.get()
    };

    LPCWSTR origins[] = { L"https://*.contoso.com" };
    
    CHECK_FAILURE(stagingProfile3->SetOriginFeatures(
        ARRAYSIZE(origins),
        origins,
        ARRAYSIZE(features),
        features));
}

void GetFeatureSettingsForOrigin()
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();

    TextInputDialog inputDialog(
        m_appWindow->GetMainWindow(),
        L"Get Origin Features",
        L"Enter the origin to retrieve feature settings for:",
        L"Origin:",
        std::wstring(L"https://www.microsoft.com"),
        false);  // not read-only

    if (inputDialog.confirmed)
    {
        std::wstring origin = inputDialog.input;

        CHECK_FAILURE(
            stagingProfile3->GetOriginFeatures(
                origin.c_str(),
                Callback<ICoreWebView2StagingGetOriginFeaturesCompletedHandler>(
                    [this, origin](HRESULT errorCode,
                           ICoreWebView2StagingOriginFeatureSettingCollectionView* result) -> HRESULT
                    {
                        if (SUCCEEDED(errorCode))
                        {
                            UINT32 count = 0;
                            CHECK_FAILURE(result->get_Count(&count));

                            std::wstring message = L"Features for origin: " + origin + L"\n";
                            for (UINT32 i = 0; i < count; i++)  
                            {
                                wil::com_ptr<ICoreWebView2StagingOriginFeatureSetting> setting;
                                CHECK_FAILURE(result->GetValueAtIndex(i, &setting));

                                COREWEBVIEW2_ORIGIN_FEATURE feature;
                                BOOL isEnabled;
                                CHECK_FAILURE(setting->get_Feature(&feature));
                                CHECK_FAILURE(setting->get_IsEnabled(&isEnabled));

                                message += L"Feature: " + std::to_wstring(static_cast<int>(feature)) +
                                           L", Enabled: " + (isEnabled ? L"True" : L"False") + L"\n";
                            }

                            MessageBoxW(m_appWindow->GetMainWindow(), message.c_str(), L"Origin Features", MB_OK);
                        }
                        return S_OK;
                    }).Get()));
    }
}
```

### .NET/WinRT 

```c#
using OriginFeatureSetting = System.Collections.Generic.KeyValuePair<CoreWebView2OriginFeature, CoreWebView2OriginFeatureState>;

// ...

var profile = webView2.CoreWebView2.Profile;

// Create feature settings collection
var features = new[]
{
    new OriginFeatureSetting(CoreWebView2OriginFeature.AccentColor, CoreWebView2OriginFeatureState.Enabled),
    new OriginFeatureSetting(CoreWebView2OriginFeature.PersistentStorage, CoreWebView2OriginFeatureState.Disabled),
    new OriginFeatureSetting(CoreWebView2OriginFeature.EnhancedSecurityMode, CoreWebView2OriginFeatureState.Enabled)
};

// Set features for origin patterns
var origins = new[] { "https://*.contoso.com" };
profile.SetOriginFeatures(origins, features);
```


# API details

## C++
```cpp
/// Specifies the feature types that can be configured for origins.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_FEATURE {
  /// Specifies the accent color feature for the origin.
  /// This controls whether the origin can use the AccentColor CSS keyword, which provides
  /// access to the system's accent color. The AccentColor keyword can be used in CSS color
  /// properties to match the operating system's accent color, enabling
  /// better integration with the native UI theme.
  /// By default, the accent color feature is disabled for all origins.
  /// 
  /// For more information about CSS color keywords, see:
  /// https://developer.mozilla.org/en-US/docs/Web/CSS/color_value
  COREWEBVIEW2_ORIGIN_FEATURE_ACCENT_COLOR,
  /// Specifies persistent storage capabilities for the origin.
  /// This controls whether data stored by the origin (including Cache API, Cookies,
  /// localStorage, IndexedDB, File System API, and Service Workers) can be marked as
  /// persistent. When enabled, WebView2 will not automatically evict the origin's data
  /// during storage pressure situations such as low disk space. When disabled, the
  /// origin's data may be cleared by WebView2 when storage space is needed.
  /// By default, persistent storage is disabled for all origins.
  /// 
  /// For more information about persistent storage, see:
  /// https://web.dev/articles/persistent-storage
  /// https://developer.mozilla.org/en-US/docs/Web/API/Storage_API
  COREWEBVIEW2_ORIGIN_FEATURE_PERSISTENT_STORAGE,
  /// Specifies enhanced security mode settings for the origin.
  /// Enhanced Security Mode provides additional protections by disabling or restricting
  /// certain web platform features that may pose security risks, such as JIT compilation,
  /// certain JavaScript APIs, and other potentially dangerous capabilities. This feature
  /// is particularly useful for protecting against zero-day exploits and reducing attack
  /// surface. When enabled for an origin, that origin will have Enhanced Security Mode
  /// applied; when disabled, normal security mode is used.
  /// Enhanced security mode can be configured globally via EnhancedSecurityModeLevel API on profile.
  /// 
  /// For more information about Enhanced Security Mode, see:
  /// https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/security
  COREWEBVIEW2_ORIGIN_FEATURE_ENHANCED_SECURITY_MODE,
} COREWEBVIEW2_ORIGIN_FEATURE;

/// Specifies the state of the origin feature.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_FEATURE_STATE {
  /// Sets the enabled state of the origin feature.
  COREWEBVIEW2_ORIGIN_FEATURE_STATE_ENABLED,
  /// Sets the disabled state of the origin feature.
  COREWEBVIEW2_ORIGIN_FEATURE_STATE_DISABLED,
} COREWEBVIEW2_ORIGIN_FEATURE_STATE;

/// Receives the result of the `GetOriginFeatures` method.
interface ICoreWebView2StagingGetOriginFeaturesCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2StagingOriginFeatureSettingCollectionView* result);
}


/// This is the ICoreWebView2Profile interface for origin feature management.
interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Creates a CoreWebView2OriginFeatureSetting objects. This object represents a specific feature and its state (enabled or disabled).
  /// This method allows creating a feature settings object that can be used with
  /// SetOriginFeatures to configure features for origins.
  HRESULT CreateOriginFeatureSetting(
      [in] COREWEBVIEW2_ORIGIN_FEATURE featureKind,
      [in] COREWEBVIEW2_ORIGIN_FEATURE_STATE featureState
      , [out, retval] ICoreWebView2StagingOriginFeatureSetting** value);

  /// Configures one or more feature settings for the specified origins. 
	/// 
	/// This method applies feature configurations—such as accent color support, 
	/// persistent storage, or enhanced security mode—to origins. Origins 
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
  HRESULT SetOriginFeatures(
      [in] UINT32 originsCount,
      [in] LPCWSTR* originPatterns,
      [in] UINT32 featureCount,
      [in] ICoreWebView2StagingOriginFeatureSetting** features
  );

  /// Gets the feature configurations for a specified origin.
  /// Returns a collection of feature settings that have been configured for the origin.
  /// If no features have been configured for the origin, an empty collection is returned.
  /// The origin should have a valid scheme and host (e.g. "https://www.example.com"),
  /// otherwise the method fails with `E_INVALIDARG`.
  /// The returned collection contains all the features that are part of `CoreWebView2OriginFeature`.
  HRESULT GetOriginFeatures(
      [in] LPCWSTR origin
      , [in] ICoreWebView2StagingGetOriginFeaturesCompletedHandler* handler);
}

/// Represents a feature setting configuration for a origin.
interface ICoreWebView2StagingOriginFeatureSetting : IUnknown {
  /// The feature type for this setting.
  [propget] HRESULT Feature([out, retval] COREWEBVIEW2_ORIGIN_FEATURE* value);

  /// Indicates whether the feature is enabled for the origin.
  [propget] HRESULT IsEnabled([out, retval] BOOL* value);
}


/// A collection of origin settings.
interface ICoreWebView2StagingOriginFeatureSettingCollectionView : IUnknown {
  /// Gets the number of objects contained in the `OriginFeatureSettingCollection`.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the object at the specified index.
  HRESULT GetValueAtIndex(
      [in] UINT32 index
      , [out, retval] ICoreWebView2StagingOriginFeatureSetting** value);
}
```

## MIDL3

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
        AccentColor = 0,
        PersistentStorage = 1,
        EnhancedSecurityMode = 2,
    };

    runtimeclass CoreWebView2OriginFeatureSetting
    {
        // ICoreWebView2StagingOriginFeatureSetting members
        CoreWebView2OriginFeature Feature { get; };

        Boolean IsEnabled { get; };
    }

    runtimeclass CoreWebView2Profile 
    {
        [interface_name("Microsoft.Web.WebView2.Core.CoreWebView2Profile_Manual5")]
        {
            void SetOriginFeatures(
                Windows.Foundation.Collections.IIterable<String> origins,
                Windows.Foundation.Collections.IIterable<
                Windows.Foundation.Collections.IKeyValuePair<CoreWebView2OriginFeature, CoreWebView2OriginFeatureState> > features);

            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2OriginFeatureSetting> > GetOriginFeaturesAsync(String origin);
        }
    }
}
```