# Background

[Edge SmartScreen](https://support.microsoft.com/en-us/microsoft-edge/how-can-smartscreen-help-protect-me-in-microsoft-edge-1c9a874a-6826-be5e-45b1-67fa445a74c8) helps end users identify reported phishing and malware websites, and also helps end users make informed decisions about downloads.

Currently, developers can use `options->put_AdditionalBrowserArguments(L"--disable-features=msSmartScreenProtection")` to disable SmartScreen in the WebView2 application. It is a startup parameter of the browser process and applies to all WebView2 instances using the same user data folder. It must be determined when the WebView2Environment is created, and it cannot be modified at runtime.

To support more flexibility we introduce a new API.

We have CoreWebView2Settings.IsReputationCheckingRequired. Each WebView2 declares if it requires SmartScreen. Some WebView2s may be used to display app content and don't require SmartScreen and others may be rendering arbitrary web content and do need SmartScreen. Having SmartScreen on unnecessarily for app content is a detriment to performance but otherwise not a problem. Having SmartScreen off for arbitrary web content is an issue. We have to turn SmartScreen on or off for all WebView2 using the same user data folder so if any WebView2 requires SmartScreen then we turn it on for all of them. If WebView2 settings change or WebView2s are closed and then all WebView2s using the same user data folder don't require SmartScreen, then we can turn SmartScreen off.

It is much easier to indicate if individual WebView2s require SmartScreen than to have an end developer explicitly manage if SmartScreen should be enabled as a whole, especially when its different sets of WebView2s in different processes (like Excel's set of WebView2s and Word's set of WebView2s) all sharing the same user data folder.
In this document we describe the new setting.


# Description
You can use CoreWebView2Settings.IsReputationCheckingRequired to control SmartScreen. SmartScreen is enabled or disabled per browser process, so all WebView2 applications sharing the same user data folder path also share SmartScreen being enabled or disabled.
If CoreWebView2Setting.IsReputationCheckingRequired is true for any CoreWebView2 using the same user data folder, then SmartScreen is enabled. If CoreWebView2Setting.IsReputationCheckingRequired is false for all CoreWebView2 using the same user data folder, then SmartScreen is disabled.
The default value for `IsReputationCheckingRequired` is true. When creating a new CoreWebVIew2, if it is not set CoreWebView2Settings.IsReputationCheckingRequired, the SmartScreen state of all CoreWebView2s using the same user data folder will be reset to true when the new CoreWebView2 is navigated or downloaded.

Changes to `IsReputationCheckingRequired` take effect on the next navigation or download.

If the option `--disable-features=msSmartScreenProtection` is specified when CoreWebView2Environment is created, then SmartScreen cannot be set through CoreWebView2Settings.IsReputationCheckingRequired. In this scenario, SmartScreen is always turned off.


# Examples
```cpp
// member variable
wil::com_ptr<ICoreWebView2Settings> m_webViewSettings;

// isLocalContent is TRUE if the page is navigated to content that is completely
// app-provided, with no user-provided content or web-served content.
// Note that we must update the property before navigating to the content.
void SettingsComponent::UpdateSmartScreenRequirementBeforeNavigating(bool isLocalContent)
{
   wil::com_ptr<ICoreWebView2Settings11> coreWebView2Settings11;
    coreWebView2Settings11 =
                m_webViewSettings.try_query<ICoreWebView2Settings11>();
    if(coreWebView2Settings11) 
    {
        CHECK_FAILURE(coreWebView2Settings11->put_IsReputationCheckingRequired(!isLocalContent));
    }
}
```

```c#
void UpdateSmartScreenRequirementBeforeNavigating(bool isLocalContent)
{
    var settings = webView2Control.CoreWebView2.Settings;
    settings.IsReputationCheckingRequired = !isLocalContent;
}
```

# Remarks

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```cpp
[uuid(d667d3a7-c1b7-479f-8833-db7547df6687), object, pointer_default(unique)]
interface ICoreWebView2Settings11 : ICoreWebView2Settings10 {
  /// SmartScreen helps webviews identify reported phishing and malware websites and 
  /// also helps users make informed decisions about downloads.
  /// `IsReputationCheckingRequired`  is used to control whether SmartScreen enabled or not. 
  /// SmartScreen is enabled or disabled for all CoreWebView2s using the same user data folder. 
  /// If CoreWebView2Setting.IsReputationCheckingRequired is true for any CoreWebView2 using the same 
  /// user data folder, then SmartScreen is enabled. If CoreWebView2Setting.IsReputationCheckingRequired 
  /// is false for all CoreWebView2 using the same user data folder, then SmartScreen is disabled.
  /// When it is changed, the change will be applied to all WebViews using the 
  /// same user data folder on the next navigation or download.
  /// The default value for `IsReputationCheckingRequired` is true. When a new CoreWebview2 
  /// is created, the SmartScreens of all CoreWebviews using the same user data folder are reset to true.
  [propget] HRESULT IsReputationCheckingRequired([out, retval] BOOL* value); 

  /// Sets whether this webview2 instance needs SmartScreen protection for its content.
  /// Set the `IsReputationCheckingRequired` property. 
  [propput] HRESULT IsReputationCheckingRequired([in] BOOL value); 
}
```

```c# (really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings11")]
        {
            Boolean IsReputationCheckingRequired { get; set; };
        }
    }
}
```

# Appendix

We initially considered an API like `CoreWebView2Environment.IsReputationCheckingRequired` that would directly change the value for all the processes. The problem is this is not easy to do for apps like Office who have multiple apps connected to the same browser process. In their case each app has IsReputationCheckingRequiredxf and its hard for the browser process to know which change to the property should win. 
