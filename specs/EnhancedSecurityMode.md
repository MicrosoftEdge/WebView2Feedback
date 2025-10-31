EnhancedSecurityMode
===

# Background

Enhanced Security Mode (ESM) is a Microsoft Edge security feature that reduces the risk of memory-related vulnerabilities by disabling JavaScript Just-in-Time (JIT) compilation and enabling additional operating system protections.

In WebView2, ESM is off by default to avoid performance impact. Host applications can enable ESM for stricter security when rendering untrusted or sensitive content. While this improves security, it may reduce JavaScript performance.

In Microsoft Edge, ESM offers two levels:

- Balanced – Enabled only for unfamiliar sites based on browser usage patterns.
- Strict – Always enabled for all sites.

![image](https://github.com/MicrosoftEdge/WebView2Feedback/assets/82386753/35977716-e46c-4257-82da-906b0c6f833e)

Unlike Edge browser, WebView2 does not support heuristic-based "Balanced" level. Only two options are available: Off and Strict.

Currently, ESM level can only be configured via the `--sdsm-state` browser flag([see for more details](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/webview-features-flags?tabs=dotnetcsharp)) at environment creation, applying globally to all profiles. There is no flexibility to modify the level at runtime.

This proposal introduces an API to enable or disable ESM and persist the configuration for a WebView2 profile within the user data folder.

## CoreWebView2Profile.EnhancedSecurityMode
Enables or disables Enhanced Security Mode (ESM) for all WebView2 instances sharing the same profile. This property value is persisted for a WebView2 profile in the user data folder. The default value is false.

- true: ESM enabled in Strict level: disables JavaScript JIT and applies additional OS protections.
- false: ESM level is Off.

Changes apply to future navigations; reload may be required. Enabling ESM improves security but can reduce JavaScript performance.

# Examples

## EnhancedSecurityMode

Enable Enhanced Security Mode for a profile.

```c#
void EnableEnhancedSecurityMode()
{
    var profile = webView2.CoreWebView2.Profile;
    profile.EnhancedSecurityMode = true;
    MessageBox.Show(this, "Enhanced security mode is enabled", "Enhanced Security Mode");
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
            CHECK_FAILURE(profile12->put_EnhancedSecurityMode(TRUE));
            MessageBox(
                nullptr, L"Enhanced security mode is enabled",
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
  [propget] HRESULT EnhancedSecurityMode([out, retval] BOOL* value);

  /// Enables or disables Enhanced Security Mode for this profile.
  /// See notes above for behavior and performance impact.
  [propput] HRESULT EnhancedSecurityMode([in] BOOL value);
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
            Boolean EnhancedSecurityMode { get; set; };
        }
    }
}
```
