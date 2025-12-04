EnhancedSecurityModeLevel
===

# Background

Enhanced Security Mode (ESM) is a Microsoft Edge security feature that reduces 
the risk of memory-related vulnerabilities by disabling JavaScript Just-in-Time 
(JIT) compilation and enabling additional operating system protections.

In WebView2, ESM is off by default to avoid performance impact. You can enable 
ESM for stricter security when rendering untrusted sites. While this improves
security, it may reduce JavaScript performance.

In Microsoft Edge, ESM offers two levels:

- Balanced – Enhanced security is used for unfamiliar sites based on browser usage patterns.
- Strict – Enhanced security is used for all sites.

![image](https://github.com/MicrosoftEdge/WebView2Feedback/assets/82386753/35977716-e46c-4257-82da-906b0c6f833e)

Unlike Microsoft Edge, WebView2 does not support the heuristic-based "Balanced" 
level; only Off and Strict are available.

Today, the ESM level in WebView2 can be set only at environment creation by using
the `--sdsm-state` browser feature flag ([webview2 browser flag docs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/webview-features-flags?tabs=dotnetcsharp)). 
The setting applies globally to all profiles and cannot be changed at runtime.

This proposal introduces an API to configure the Enhanced Security Mode level. 
The configuration is not persisted to the user data folder. The property is reset when the profile is recreated.

# Description

The `EnhancedSecurityModeLevel` property allows you to control the Enhanced Security 
Mode level for WebView2 instances associated with a profile. This level applies to the context of the profile. That is, all WebView2s sharing the same profile are affected.
The configuration is not persisted to the user data folder. The property is reset when the profile is recreated.

The default value is `COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_OFF`.

When set to `Off`, Enhanced Security Mode is completely disabled. When set to 
`Strict`, the feature is enabled and applies strict security policies to all sites.

See `COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL` for descriptions of levels.

Changes apply to future navigations; a reload may be required for the change to take effect.

# Examples

## Setting the ESM Level

Set Enhanced Security Mode level for a profile.

```c#
void SetEnhancedSecurityModeLevel(CoreWebView2EnhancedSecurityModeLevel value)
{
    var profile = webView2.CoreWebView2.Profile;
    profile.EnhancedSecurityModeLevel = value;
    MessageBox.Show(this,
        "Enhanced Security Mode level is set successfully",
        "Enhanced Security Mode");
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

        auto profile12 = profile.try_query<ICoreWebView2Profile12>();
        if (profile12)
        {
            CHECK_FAILURE(profile12->put_EnhancedSecurityModeLevel(value));
            MessageBox(
                nullptr,
                L"Enhanced Security Mode level is set successfully",
                L"Enhanced Security Mode", MB_OK);
        }
    }
}
```

# API Details

```
/// Enhanced Security Mode levels.
[v1_enum]
typedef enum COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL {
  /// Enhanced Security Mode is turned off.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_OFF,
  /// Enhanced Security Mode is enabled in Strict level. Disables JavaScript 
  /// Just-in-Time (JIT) compilation and enables additional operating system protections.
  ///
  /// This level applies enhanced security for all sites but may reduce JavaScript performance.
  ///
  /// See [Browsing more safely with Microsoft Edge](https://learn.microsoft.com/en-us/DeployEdge/microsoft-edge-security-browse-safer)
  /// for more details about Enhanced Security Mode.
  COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL_STRICT,
} COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL;

/// Extension of ICoreWebView2Profile to control Enhanced Security Mode (ESM) level.
///
/// ESM reduces the risk of memory-related vulnerabilities by disabling JavaScript
/// Just-in-Time (JIT) compilation and enabling additional operating system protections.
/// This property applies to all WebView2 instances sharing the same profile.
/// The configuration is not persisted to the user data folder.
/// The property is reset when the profile is recreated.
///
/// See `COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL` for descriptions of levels.
///
/// Changes apply to future navigations; reload may be required.
///
/// Enabling ESM improves security but may reduce JavaScript performance.
[uuid(450fab50-f6d8-4517-baea-964ec12d5c8c), object, pointer_default(unique)]
interface ICoreWebView2Profile12 : IUnknown {
  /// Gets the `EnhancedSecurityModeLevel` property.
  [propget] HRESULT EnhancedSecurityModeLevel([out, retval] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL* value);

  /// Sets the `EnhancedSecurityModeLevel` property.
  [propput] HRESULT EnhancedSecurityModeLevel([in] COREWEBVIEW2_ENHANCED_SECURITY_MODE_LEVEL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2EnhancedSecurityModeLevel
    {
        Off = 0,
        Strict = 1
    };

    runtimeclass CoreWebView2Profile
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile12")]
        {
            // ICoreWebView2Profile12 members
            CoreWebView2EnhancedSecurityModeLevel EnhancedSecurityModeLevel { get; set; };
        }
    }
}
```
