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

    - **GetOriginSettings**: Get the list of `CoreWebView2OriginSetting` for this profile.
    - **CreateOriginSetting**: Create and return a new `CoreWebView2OriginSetting` object.
2. `ICoreWebView2OriginSetting`interface, which exposes get and set APIs for the following features. These APIs are used to set the state of these features.

    - AccentColor 
    - EnhancedSecurityMode
    - PersistentStorage
    - TrackingPrevention

    The feature state can have three values which are defined by OriginSettingState {
    Default,
    Allow,
    Block}

# Example

## Set Origin Setting for an Origin Pattern

### C++ example

```cpp
void ScenarioTrustedOrigin::SetFeatureForOrigins(std::wstring originPattern)
{
    auto stagingProfile3 =
        m_webviewProfile.try_query<ICoreWebView2StagingProfile3>();
    
    wil::com_ptr<ICoreWebView2StagingOriginSettingCollection> originSettingCollection;
    stagingProfile3->GetOriginSettings(&originSettingCollection);

    wil::com_ptr<ICoreWebView2StagingOriginSetting> originSetting;
    stagingProfile3->CreateOriginSetting(&originSetting);

    CHECK_FAILURE(originSetting->put_OriginPattern(originPattern.c_str()));

    // Block Accent Color
    CHECK_FAILURE(originSetting->put_AccentColor(OriginSettingState::OriginSettingState_BLOCK));

    // Allow Persistence Storage
    CHECK_FAILURE(originSetting->put_PersistentStorage(OriginSettingState::OriginSettingState_ALLOW));

    UINT32 count;
    CHECK_FAILURE(originSettingCollection->get_Count(&count));
    CHECK_FAILURE(originSettingCollection->InsertValueAtIndex(count, originSetting.get()));
}
```

### .NET/WinRT 

```c#
var profile = webView2.CoreWebView2.Profile;

var originSetting = profile.CreateOriginSetting();
originSetting.OriginPattern = "https://*.contoso.com";
originSetting.AccentColor = OriginSettingState.Block;
originSetting.PersistentStorage = OriginSettingState.Allow;

var originSettings = profile.GetOriginSettings();
originSettings.Add(originSetting);
```


# API details

## C++
```cpp
[v1_enum]
typedef enum OriginSettingState {
  /// Default state of the feature
  OriginSettingState_DEFAULT = 0x0,
  /// Allow the feature
  OriginSettingState_ALLOW = 0x1,
  /// Block the feature
  OriginSettingState_BLOCK = 0x2,
} OriginSettingState;

interface ICoreWebView2StagingProfile3 : IUnknown {
  /// Gets the list of origin settings associated with this profile.
  HRESULT GetOriginSettings(
      [out, retval] ICoreWebView2StagingOriginSettingCollection** value);

  /// Creates a new `OriginSetting` object.
  HRESULT CreateOriginSetting(
      [out, retval] ICoreWebView2StagingOriginSetting** value);
}

/// Represents settings for a specific origin.
interface ICoreWebView2StagingOriginSetting : IUnknown {
  /// Gets the `AccentColor` property.
  [propget] HRESULT AccentColor([out, retval] OriginSettingState* value);


  /// Sets the enabled property for Accent Color for the associated origin.
  /// The default value for this is `Block`. When set to `Allow`, the origin is
  /// allowed to use AccentColor keyword to display OS Accent Color.
  [propput] HRESULT AccentColor([in] OriginSettingState value);


  /// Gets the `EnhancedSecurityMode` property.
  [propget] HRESULT EnhancedSecurityMode([out, retval] OriginSettingState* value);


  /// Sets the enabled property for Enhanced Security Mode for the associated origin.
  /// When set to `Block`, the origin bypasses Enhanced Security Mode even if
  /// Enhanced Security Mode is enabled for the profile. Similarly, when set to `Allow`,
  /// the origin enforces Enhanced Security Mode even if Enhanced Security Mode is disabled
  /// for the profile.
  [propput] HRESULT EnhancedSecurityMode([in] OriginSettingState value);


  /// Gets the `OriginPattern` property.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT OriginPattern([out, retval] LPWSTR* value);


  /// Sets the origin pattern associated with this origin setting.
  /// The origins pattern can be both exact origin strings and wildcard patterns.
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
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propput] HRESULT OriginPattern([in] LPCWSTR value);


  /// Gets the `PersistentStorage` property.
  [propget] HRESULT PersistentStorage([out, retval] OriginSettingState* value);


  /// Sets the enabled property for Persistence Storage for the associated origin.
  /// The default value for this is `Block`. When set to `Allow`, the storage created
  /// on this origin persists even when browser evicts storage under low disk space conditions.
  [propput] HRESULT PersistentStorage([in] OriginSettingState value);


  /// Gets the `TrackingPrevention` property.
  [propget] HRESULT TrackingPrevention([out, retval] OriginSettingState* value);


  /// Sets the enabled property for Tracking Prevention for the associated origin.
  /// When set to `Block`, the origin bypasses Tracking Prevention even if
  /// Tracking Prevention is enabled for the profile. Similarly, when set to `Allow`,
  /// the origin enforces Tracking Prevention even if Tracking Prevention is disabled
  /// for the profile.
  [propput] HRESULT TrackingPrevention([in] OriginSettingState value);
}
```

## .Net/WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum Originsettingstate
    {
        Default = 0,
        Allow = 1,
        Block = 2,
    };

    runtimeclass CoreWebView2OriginSetting
    {
        Originsettingstate AccentColor { get; set; };

        Originsettingstate EnhancedSecurityMode { get; set; };

        String OriginPattern { get; set; };

        Originsettingstate PersistentStorage { get; set; };

        Originsettingstate TrackingPrevention { get; set; };
    }

    runtimeclass CoreWebView2Profile
    {
        IVector<CoreWebView2OriginSetting> GetOriginSettings();

        CoreWebView2OriginSetting CreateOriginSetting();
    }
}
```