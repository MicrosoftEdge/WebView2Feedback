Service Worker PostMessage Setting
===
# Background

This API provides a setting to expose the webview2 specific JS APIs on service worker script.

# Description

We propose adding `ServiceWorkerJSAPIsEnabled` setting API as it allows developers to expose the webview2 specific JS APIs on service worker script. When enabled this would enable the developers to use webview2's service worker postmessage APIs to communicate directly between the service worker script and webview2 host.

# Examples

## Win32 C++

```cpp
void ToggleServiceWorkerJsApiSetting()
{
    wil::com_ptr<ICoreWebView2StagingSettings> webviewStagingSettings;
    webviewStagingSettings = m_settings.try_query<ICoreWebView2StagingSettings>();

    if (webviewStagingSettings)
    {
        BOOL value;
        webviewStagingSettings->get_IsServiceWorkerJSAPIsEnabled(&value);
        CHECK_FAILURE(webviewStagingSettings->put_IsServiceWorkerJSAPIsEnabled(!value));
        MessageBox(
            nullptr,
            (std::wstring(L"Service Worker JS API setting has been ") +
             (!value ? L"enabled." : L"disabled."))
                .c_str(),
            L"Service Worker JS API Setting", MB_OK);
    }
}
```

## C#/.NET

```c#
private void ToggleServiceWorkerJsApiSetting()
{
    WebViewSettings.IsServiceWorkerJSAPIsEnabled = !WebViewSettings.AreDefaultScriptDialogsEnabled;

    MessageBox.Show(this, 
        $"IsServiceWorkerJSAPIsEnabled is now set to: {WebViewSettings.IsServiceWorkerJSAPIsEnabled}",
        "Trusted Origins", MessageBoxButtons.OK, MessageBoxIcon.Information);
}
```

# API Details

## Win32 C++
```cpp
/// A continuation of the ICoreWebView2Settings interface to manage Service Worker JS APIs.
interface ICoreWebView2StagingSettings : IUnknown {
  /// Gets the `IsServiceWorkerJSAPIsEnabled` property.
  [propget] HRESULT IsServiceWorkerJSAPIsEnabled([out, retval] BOOL* value);

  /// Enables or disables webview2 specific Service Worker JS APIs in the WebView2.
  /// When set to `TRUE`, chrome and webview objects are available in Service Workers .
  /// chrome.webview exposes APIs to interact with the WebView from Service Workers.
  /// The default value is `FALSE`.
  /// When enabled, this setting takes effect for all the newly installed Service Workers.
  /// \snippet SettingsComponent.cpp ToggleServiceWorkerJSAPIsEnabled
  [propput] HRESULT IsServiceWorkerJSAPIsEnabled([in] BOOL value);
}

```

## .NET/C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings 
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingSettings")]
        {
            Boolean IsServiceWorkerJSAPIsEnabled { get; set; };
        }
    }
}
```