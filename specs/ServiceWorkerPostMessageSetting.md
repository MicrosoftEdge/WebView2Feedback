Service Worker PostMessage Setting
===
# Background

This API provides a setting to expose the webview2 specific JS APIs on service worker script.

# Description

We propose adding the `ServiceWorkerJSAPIsEnabled` setting API to control the exposure of WebView2-specific JavaScript APIs in service worker scripts. When enabled, developers can use WebView2's service worker postmessage APIs to communicate directly between service worker scripts and the WebView2 host.

Previously, WebView2-specific JavaScript APIs were only exposed to service worker scripts when developers subscribed to the `ServiceWorkerRegistered` event. This approach was unreliable because developers could obtain service worker registrations through the `GetServiceWorkerRegistrations` API and attempt to use service worker postmessage APIs, which would fail since the JavaScript APIs were not exposed.

# Examples

## Win32 C++

```cpp
void ToggleServiceWorkerJsApiSetting()
{
    // Unregister every service worker so that for all the newly installed service worker
    // the new settings can be applied.
    m_webView->ExecuteScript(
        L"navigator.serviceWorker.getRegistrations().then(function(registrations) {"
        L"  for(let registration of registrations) {"
        L"    registration.unregister();"
        L"  }"
        L"});",
        nullptr);

    wil::com_ptr<ICoreWebView2Settings> webViewSettings;
    CHECK_FAILURE(m_webView->get_Settings(&webViewSettings));
    auto webViewSettingsStaging =
        webViewSettings.try_query<ICoreWebView2StagingSettings>();

    if (webViewSettingsStaging)
    {
        // Toggle the service worker post message setting.
        BOOL isEnabled;
        CHECK_FAILURE(webViewSettingsStaging->get_IsServiceWorkerJSAPIsEnabled(&isEnabled));
        CHECK_FAILURE(webViewSettingsStaging->put_IsServiceWorkerJSAPIsEnabled(!isEnabled));
        
        MessageBox(
            nullptr,
            (std::wstring(L"Service Worker JS API setting has been ") +
             (!isEnabled ? L"enabled." : L"disabled."))
                .c_str(),
            L"Service Worker JS API Setting", MB_OK);
    }

    // Navigate to index.html which will register a new service worker and
    // check if chrome and webview objects are available in service worker script.
    m_sampleUri = m_appWindow->GetLocalUri(L"index.html");
    CHECK_FAILURE(m_webView->Navigate(m_sampleUri.c_str()));
}

```

**index.html**:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Service Worker Post Message Setting</title>
    <script>
        "use strict";
        
        // Register the service worker
        navigator.serviceWorker.register("service_worker.js").then(function(registration) {

            // Wait for the service worker to be ready
            return navigator.serviceWorker.ready;
        }).then(function(registration) {
            const serviceWorker = registration.active;
            
            // Post a message to the service worker with CHECK_CHROME_WEBVIEW command
            if (serviceWorker) {
                serviceWorker.postMessage({command: 'CHECK_CHROME_WEBVIEW'});
                console.log("Message posted to service worker");
            }
        }).catch(function(error) {
            console.error("Service worker registration or messaging failed:", error);
        });
        
        // Listen to messages from the service worker
        // Messages sent via event.source.postMessage() are received here
        navigator.serviceWorker.addEventListener('message', function(event) {
            console.log("Message received from service worker:", event.data);
            
            // Display the result in the HTML element
            const resultElement = document.getElementById('result');
            if (event.data === 'chromeWebViewAvailable') {
                resultElement.textContent = 'chrome.webview is AVAILABLE in Service Worker';
                resultElement.style.color = 'green';
            } else if (event.data === 'chromeWebViewNotAvailable') {
                resultElement.textContent = 'chrome.webview is NOT AVAILABLE in Service Worker';
                resultElement.style.color = 'red';
            } else {
                resultElement.textContent = 'Received: ' + event.data;
                resultElement.style.color = 'blue';
            }
        });
    </script>
</head>
<body>
    <h1>Service Worker Post Message Setting</h1>
    <p>This page registers a service worker, posts a message to it, and listens for responses.</p>
    <p>Check the console for debug information.</p>
    <div id="result" style="font-size: 18px; font-weight: bold; margin-top: 20px; padding: 10px; border: 2px solid #ccc; border-radius: 5px;">
        Waiting for service worker response...
    </div>
</body>
</html>
```

**service_worker.js**
```js
self.addEventListener('message', (event) => {
  if (event.data.command === 'CHECK_CHROME_WEBVIEW') {
    if(self.chrome && self.chrome.webview) {
      event.source.postMessage('chromeWebViewAvailable');
    } else {
      event.source.postMessage('chromeWebViewNotAvailable');
    }
  }
});
```

## C#/.NET

```c#
private void ToggleServiceWorkerJsApiSetting()
{
    // Unregister every service worker so that for all the newly installed service worker
    // the new settings can be applied.
    webView.CoreWebView2.ExecuteScriptAsync(
        @"navigator.serviceWorker.getRegistrations().then(function(registrations) {
            for(let registration of registrations) {
                registration.unregister();
            }
        });");

    // Toggle the service worker post message setting.
    WebViewSettings.IsServiceWorkerJSAPIsEnabled = !WebViewSettings.IsServiceWorkerJSAPIsEnabled;

    MessageBox.Show(this, 
        $"IsServiceWorkerJSAPIsEnabled is now set to: {WebViewSettings.IsServiceWorkerJSAPIsEnabled}",
        "Service Worker JS API Setting", MessageBoxButtons.OK, MessageBoxIcon.Information);

    // Navigate to index.html which will register a new service worker and
    // check if chrome and webview objects are available in service worker script.
    sampleUri = GetLocalUri("index.html");
    webView.CoreWebView2.Navigate(sampleUri);
}
```

**index.html** and **service_worker.js**: Same as the Win32 C++ example above.

# API Details

## Win32 C++
```cpp
interface ICoreWebView2Settings : IUnknown {
  /// Gets the `IsServiceWorkerJSAPIsEnabled` property.
  [propget] HRESULT IsServiceWorkerJSAPIsEnabled([out, retval] BOOL* value);

  /// Enables or disables webview2 specific Service Worker JS APIs in the WebView2.
  /// When set to `TRUE`, chrome and webview objects are available in Service Workers .
  /// chrome.webview exposes APIs to interact with the WebView from Service Workers.
  /// The default value is `FALSE`.
  /// When enabled, this setting takes effect for all the newly installed Service Workers.
  [propput] HRESULT IsServiceWorkerJSAPIsEnabled([in] BOOL value)
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