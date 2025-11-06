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

This specification introduces two APIs on the `CoreWebView2Profile` object: `EnableFeatureForOrigins` and `DisableFeatureForOrigins`. These APIs allow applications to selectively enable or disable specific WebView2 features based on the origin of the content being loaded.

The APIs support flexible origin matching through both exact origin specification and wildcard patterns. The following table depicts what can be input for 


| Origin Filter String | What It Matches | Description |
|---------|-----------------|-------------|
| `*` | `https://www.google.com`<br>`https://api.contoso.com`<br>`https://www.microsoft.com` | Matches all the origins |
| `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
| `https://*.contoso.com` | `https://app.contoso.com`<br>`https://api.contoso.com`<br>`https://admin.contoso.com` | Matches any subdomain under the specified domain |
| `*://contoso.com` | `https://contoso.com`<br>`http://contoso.com`<br>`ftp://contoso.com` | Matches any protocol for the specified hostname |
| `*contoso.*` | `https://www.contoso.com`<br>`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
| `*example/` | `https://app.example/`<br>`https://api.example/` | Matches any subdomain and top-level domain variations |
| `https://xn--qei.example/` | `https://❤.example/`<br>`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |

This granular control enables applications to implement trust-based security policies, allowing trusted origins to access advanced features while maintaining security restrictions for untrusted content.

The features which can be configured via `EnableFeatureForOrigins`:

1. [Persistence Storage](https://web.dev/articles/persistent-storage): Storage APIs in browser saves data at origin level and in case of low disk space, eviction also happens on origin level so we provide origin level configurability for developers to persist storage for trusted origins.
2. [AccentColor](https://blog.damato.design/posts/accent-color/): AccentColor is a CSS property which is used to expose OS Accent Color on sites. Given the fingerprinting concerns associated with Accent Color, developers might want to expose Accent Color to trusted origins only.
3. [Enhanced Security Mode](https://www.microsoft.com/en-us/edge/features/enhanced-security-mode?form=MA13FJ): 
Enhanced security mode helps reduce the risk of an attack caused by memory-related vulnerabilities by applying stricter security settings. It can be enabled for a certain untrusted origins to make the app more secure.

The features which can be configured via `DisableFeatureForOrigins`:

1. [Enhanced Security Mode](https://www.microsoft.com/en-us/edge/features/enhanced-security-mode?form=MA13FJ): Enhanced security mode helps reduce the risk of an attack caused by memory-related vulnerabilities by applying stricter security settings. ESM when enabled, carries a certain amount of performance impact so it can be disabled for trusted origins.
2. [Tracking Prevention](https://learn.microsoft.com/en-us/microsoft-edge/web-platform/tracking-prevention): Tracking Prevention protect user's privacy by limiting how websites can track browsing activities across different sites. For trusted origins developer can disable it for users to have personalized experience. 

**Note**: The feature appearing in both the enums would have a toggle control to enable and disable the feature.

# Examples

## Enable feature based on origin

Enable Accent Color for a set of origins

### C++ example

```cpp
void EnableAccentColorForOrigins()
{
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView->get_Profile(&profile));

    auto profile9 = profile.try_query<ICoreWebView2Profile9>();
    if (profile9) {
        // Configurable via origin and origin with wildcards
        LPCWSTR origins[] = {
            L"https://contoso.com",
            L"https://*.contoso.com",             
            L"*.microsoft.com/*"
        };

        CHECK_FAILURE(m_webviewStagingProfile3->EnableFeatureForOrigins(
            COREWEBVIEW2_ORIGIN_ENABLED_FEATURE_ACCENT_COLOR,
            static_cast<UINT32>(std::size(origins)), origins));
    }
}

```

### .NET/WinRT Sample

```csharp
var profile = webView2.CoreWebView2.Profile;

// Configurable via origin and origin with wildcards
var origins = new string[]
{
    "https://contoso.com",
    "https://*.contoso.com",             
    "*.microsoft.com/*"
};

profile.EnableFeatureForOrigins(CoreWebView2OriginEnabledFeature.AccentColor, origins);
```

## Disable feature based on origin

Disable Enahanced Security Mode for a set of origins

### C++ example

```cpp
void DisableESMForOrigins()
{
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView->get_Profile(&profile));

    auto profile9 = profile.try_query<ICoreWebView2Profile9>();
    if (profile9) {
        // Configurable via origin and origin with wildcards
        LPCWSTR origins[] = {
            L"https://contoso.com",
            L"https://*.contoso.com",             
            L"*.microsoft.com/*"
        };

        CHECK_FAILURE(m_webviewStagingProfile3->DisableFeatureForOrigins(
            COREWEBVIEW2_ORIGIN_DISABLED_FEATURE_ESM,
            static_cast<UINT32>(std::size(origins)), origins));
    }
}
```

### C# example

```csharp
var profile = webView2.CoreWebView2.Profile;

// Configurable via origin and origin with wildcards
var origins = new string[]
{
    "https://contoso.com",
    "https://*.contoso.com",             
    "*.microsoft.com/*"
};

profile.DisableFeatureForOrigins(CoreWebView2OriginDisabledFeature.ESM, origins);
```

# API details

## C++ 

```cpp
/// An enum to represent features which can be disabled for a set of origins.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_DISABLED_FEATURE {
  /// Disable Enhanced Security Mode for trusted origins.
  /// Enhanced Security Mode (ESM) provides additional security
  /// restrictions for web content. Disabling ESM for trusted origins
  /// allows those origins to operate without the additional restrictions.
  /// 
  /// This API would take effect if ICoreWebView2StagingProfile2::put_IsEnhancedSecurityModeEnabled
  /// is set to true.
  COREWEBVIEW2_ORIGIN_DISABLED_FEATURE_ENHANCED_SECURITY_MODE = 0x0,
  /// Disable Tracking Prevention for trusted origins.
  /// Tracking Prevention helps protect user privacy by blocking
  /// trackers. Disabling Tracking Prevention for trusted origins
  /// allows those origins to function without interference from
  /// tracking prevention mechanisms.
  /// 
  /// This API would take effect if ICoreWebView2EnvironmentOptions5::put_EnableTrackingPrevention
  /// is set to true.
  COREWEBVIEW2_ORIGIN_DISABLED_FEATURE_TRACKING_PREVENTION = 0x1,
} COREWEBVIEW2_ORIGIN_DISABLED_FEATURE;

/// An enum to represent features which can be enabled for a set of origins.
[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_ENABLED_FEATURE {
  /// Enable OS Accent Color in CSS.
  /// Websites can use accent-color CSS property for form controls
  /// or use AccentColor keyword to set background color, etc.
  COREWEBVIEW2_ORIGIN_ENABLED_FEATURE_ACCENT_COLOR = 0x0,
  /// Enable persistence for storage created by Storage APIs.
  /// Storage created by Storage APIs (e.g. IndexedDB, Cache, etc.) can be
  /// deleted in case of low disk space. This feature ensures that storage
  /// is not deleted for selected origins.
  /// 
  /// Origin Matching Logic Exception:
  /// Value * is not allowed for this enum value.
  COREWEBVIEW2_ORIGIN_ENABLED_FEATURE_PERSISTENCE_STORAGE = 0x1,
  /// Enable Enhanced Security Mode for untrusted origins.
  /// Enhanced Security Mode (ESM) provides additional security
  /// restrictions for web content. Enabling ESM for untrusted origins
  /// provides additional restrictions and overall security to the app.
  /// 
  /// This API would take effect if ICoreWebView2StagingProfile2::put_IsEnhancedSecurityModeEnabled
  /// is set to false.
  COREWEBVIEW2_ORIGIN_ENABLED_FEATURE_ENHANCED_SECURITY_MODE = 0x2,
} COREWEBVIEW2_ORIGIN_ENABLED_FEATURE;

/// This is an extension of the ICoreWebView2StagingProfile interface to expose API for origin based feature control.
[uuid(b411739a-b285-5a4d-a083-3ca7b2c301b8), object, pointer_default(unique)]
interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Enables specified WebView2 feature for a designated set of origins.
  /// 
  /// This method configures feature-specific functionality to be enabled for web content 
  /// loaded from the specified origins. Each feature in COREWEBVIEW2_ORIGIN_ENABLED_FEATURE
  /// can be selectively enabled for trusted origins, allowing fine-grained control over
  /// WebView2 capabilities based on the content source.
  /// 
  /// The configuration is persisted within the profile and applies to all WebView2 instances
  /// sharing the same profile. Features will be enabled immediately for currently loaded
  /// content from matching origins and for future navigations.
  /// 
  /// EnableFeatureForOrigins takes preference over DisableFeatureForOrigins for the same feature and origin.
  ///
  /// Origin Matching Logic:
  /// The origins list accepts both exact origin strings and wildcard patterns.
  /// For wildcard patterns, `*` matches zero or more characters.
  /// Examples:
  /// | Origin Filter String | What It Matches | Description |
  /// |---------|-----------------|-------------|
  /// | `*` | `https://www.google.com`, `https://api.contoso.com`,`https://www.microsoft.com` | Matches all the origins |
  /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
  /// | `https://*.contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
  /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
  /// | `*contoso.*` | `https://www.contoso.com`,`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
  /// | `*example/` | `https://app.example/`,`https://api.example/` | Matches any subdomain and top-level domain variations |
  /// | `https://xn--qei.example/` | `https://❤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
  /// 
  /// Some features may have additional restrictions on allowed origins - refer to the
  /// specific COREWEBVIEW2_ORIGIN_ENABLED_FEATURE enum value documentation for details.
  HRESULT EnableFeatureForOrigins(
      [in] COREWEBVIEW2_ORIGIN_ENABLED_FEATURE Feature,
      [in] UINT32 listCounts,
      [in] LPCWSTR* origins
  );

  /// Disables specified WebView2 feature for a designated set of origins.
  /// 
  /// This method configures feature-specific functionality to be disabled for web content
  /// loaded from the specified origins. Each feature in COREWEBVIEW2_ORIGIN_DISABLED_FEATURE
  /// can be selectively disabled for specific origins, providing enhanced security or
  /// compliance control for untrusted or restricted content sources.
  /// 
  /// The configuration is persisted within the profile and applies to all WebView2 instances
  /// sharing the same profile. Features will be disabled immediately for currently loaded
  /// content from matching origins and for future navigations.
  /// 
  /// Origin Matching Logic:
  /// The origins list accepts both exact origin strings and wildcard patterns.
  /// For wildcard patterns, `*` matches zero or more characters.
  /// Examples:
  /// | Origin Filter String | What It Matches | Description |
  /// |---------|-----------------|-------------|
  /// | `*` | `https://www.google.com`,`https://api.contoso.com`,`https://www.microsoft.com` | Matches all the origins |
  /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
  /// | `https://*.contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
  /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
  /// | `*contoso.*` | `https://www.contoso.com`,`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
  /// | `*example/` | `https://app.example/`,`https://api.example/` | Matches any subdomain and top-level domain variations |
  /// | `https://xn--qei.example/` | `https://❤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
  /// 
  /// Some features may have additional restrictions on allowed origins - refer to the
  /// specific COREWEBVIEW2_ORIGIN_DISABLED_FEATURE enum value documentation for details.
  HRESULT DisableFeatureForOrigins(
      [in] COREWEBVIEW2_ORIGIN_DISABLED_FEATURE Feature,
      [in] UINT32 listCounts,
      [in] LPCWSTR* origins
  );
}
```


## .Net/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2OriginEnabledFeature
    {
        AccentColor = 0,
        PersistenceStorage = 1,
        EnhancedSecurityMode = 2,
    };
    enum CoreWebView2OriginDisabledFeature
    {
        EnhancedSecurityMode = 0,
        TrackingPrevention = 1,
    };

    runtimeclass CoreWebView2Profile
    {
        /// Enables specified WebView2 feature for a designated set of origins.
        /// 
        /// This method configures feature-specific functionality to be enabled for web content 
        /// loaded from the specified origins. Each feature in CoreWebView2OriginEnabledFeature
        /// can be selectively enabled for trusted origins, allowing fine-grained control over
        /// WebView2 capabilities based on the content source.
        /// 
        /// The configuration is persisted within the profile and applies to all WebView2 instances
        /// sharing the same profile. Features will be enabled immediately for currently loaded
        /// content from matching origins and for future navigations.
        /// 
        /// EnableFeatureForOrigins takes preference over DisableFeatureForOrigins for the same feature and origin.
        /// 
        /// Origin Matching Logic:
        /// The origins list accepts both exact origin strings and wildcard patterns.
        /// For wildcard patterns, `*` matches zero or more characters.
        /// Examples:
        /// | Origin Filter String | What It Matches | Description |
        /// |---------|-----------------|-------------|
        /// | `*` | `https://www.google.com`, `https://api.contoso.com`,`https://www.microsoft.com` | Matches all the origins |
        /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
        /// | `https://*.contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
        /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
        /// | `*contoso.*` | `https://www.contoso.com`,`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
        /// | `*example/` | `https://app.example/`,`https://api.example/` | Matches any subdomain and top-level domain variations |
        /// | `https://xn--qei.example/` | `https://❤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
        /// 
        /// Some features may have additional restrictions on allowed origins - refer to the
        /// specific CoreWebView2OriginEnabledFeature enum value documentation for details.
        void EnableFeatureForOrigins(CoreWebView2OriginEnabledFeature feature, Windows.Foundation.Collections.IIterable<String> origins);

        /// Disables specified WebView2 feature for a designated set of origins.
        /// 
        /// This method configures feature-specific functionality to be disabled for web content
        /// loaded from the specified origins. Each feature in CoreWebView2OriginDisabledFeature
        /// can be selectively disabled for specific origins, providing enhanced security or
        /// compliance control for untrusted or restricted content sources.
        /// 
        /// The configuration is persisted within the profile and applies to all WebView2 instances
        /// sharing the same profile. Features will be disabled immediately for currently loaded
        /// content from matching origins and for future navigations.
        /// 
        /// Origin Matching Logic:
        /// The origins list accepts both exact origin strings and wildcard patterns.
        /// For wildcard patterns, `*` matches zero or more characters.
        /// Examples:
        /// | Origin Filter String | What It Matches | Description |
        /// |---------|-----------------|-------------|
        /// | `*` | `https://www.google.com`,`https://api.contoso.com`,`https://www.microsoft.com` | Matches all the origins |
        /// | `https://contoso.com` | Only `https://contoso.com` | Matches the exact origin with specific protocol and hostname |
        /// | `https://*.contoso.com` | `https://app.contoso.com`,`https://api.contoso.com`,`https://admin.contoso.com` | Matches any subdomain under the specified domain |
        /// | `*://contoso.com` | `https://contoso.com`,`http://contoso.com`,`ftp://contoso.com` | Matches any protocol for the specified hostname |
        /// | `*contoso.*` | `https://www.contoso.com`,`http://app.contoso.com` | Matches any protocol and any subdomain under the hostname |
        /// | `*example/` | `https://app.example/`,`https://api.example/` | Matches any subdomain and top-level domain variations |
        /// | `https://xn--qei.example/` | `https://❤.example/`,`https://xn--qei.example/` | Normalized punycode matches with corresponding Non-ASCII hostnames |
        /// 
        /// Some features may have additional restrictions on allowed origins - refer to the
        /// specific CoreWebView2OriginDisabledFeature enum value documentation for details.
        void DisableFeatureForOrigins(CoreWebView2OriginDisabledFeature feature, Windows.Foundation.Collections.IIterable<String> origins);
    }
}
```
