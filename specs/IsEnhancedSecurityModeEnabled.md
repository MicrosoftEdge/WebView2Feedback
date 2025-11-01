IsEnhancedSecurityModeEnabled
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

This proposal introduces an API to enable or disable ESM and persist the configuration 
for a WebView2 profile within the user data folder.

## CoreWebView2Profile.IsEnhancedSecurityModeEnabled
Enables or disables Enhanced Security Mode (ESM) for all WebView2 instances 
sharing the same profile. This property value is persisted for a WebView2 
profile in the user data folder. The default value is false.

- true: ESM enabled in Strict level: Enhanced security is used for all sites.
- false: ESM level is Off.

> Changes apply to future navigations; reload may be required.

# Examples

## IsEnhancedSecurityModeEnabled

Enable Enhanced Security Mode for a profile.

```c#
void EnableEnhancedSecurityMode()
{
    var profile = webView2.CoreWebView2.Profile;
    if (!profile.IsEnhancedSecurityModeEnabled)
    {
        profile.IsEnhancedSecurityModeEnabled = true;
        MessageBox.Show(this,
            "Enhanced Security Mode (Strict) enabled for this profile. Reload pages to apply.",
            "Enhanced Security Mode");
    }
}
```

```cpp
void EnableEnhancedSecurityMode()
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
            CHECK_FAILURE(profile12->put_IsEnhancedSecurityModeEnabled(TRUE));
            MessageBox(nullptr,
                L"Enhanced Security Mode (Strict) enabled. Reload pages to apply.",
                L"Enhanced Security Mode", MB_OK);
        }
    }
}
```

# API Details

```c#
/// Extension of ICoreWebView2Profile to control Enhanced Security Mode (ESM) level.
///
/// ESM reduces the risk of memory-related vulnerabilities by disabling JavaScript
/// Just-in-Time (JIT) compilation and enabling additional OS protections.
/// This property applies to all WebView2 instances sharing the same profile and
/// is persisted in the user data folder.
///
/// Default: false. ESM level is Off.
///
/// true: Enables ESM in Strict level for all sites.
/// false: ESM level is Off.
///
/// Notes:
/// - Changes apply to future navigations; reload may be required.
/// - Enabling ESM improves security but may reduce JavaScript performance.
///
/// See: https://learn.microsoft.com/en-us/DeployEdge/microsoft-edge-security-browse-safer
///
///
[uuid(d5b781db-0a75-5f9c-85b1-40fa814fcea7), object, pointer_default(unique)]
interface ICoreWebView2Profile12 : IUnknown {
  /// Gets whether Enhanced Security Mode is enabled for this profile.
  [propget] HRESULT IsEnhancedSecurityModeEnabled([out, retval] BOOL* value);

  /// Enables or disables Enhanced Security Mode for this profile.
  /// See notes above for behavior and performance impact.
  [propput] HRESULT IsEnhancedSecurityModeEnabled([in] BOOL value);
}
```

```c# 
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Profile
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile12")]
        {
            // ICoreWebView2Profile12 members
            Boolean IsEnhancedSecurityModeEnabled { get; set; };
        }
    }
}
```
