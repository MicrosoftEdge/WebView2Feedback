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
        CHECK_FAILURE(webViewSettingsStaging->get_IsWebViewScriptApisForServiceWorkerEnabled(&isEnabled));
        CHECK_FAILURE(webViewSettingsStaging->put_IsWebViewScriptApisForServiceWorkerEnabled(!isEnabled));
        
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

    // Setup WebMessageReceived event to receive message from main thread.
    m_webView->add_WebMessageReceived(
        Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string message;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&message));

                std::wstring msgStr = message.get();
                if (msgStr == L"MessageFromMainThread")
                {
                    std::wstringstream message{};
                    message << L"Message: " << std::endl << L"Service Worker Message from Main thread" << std::endl;
                    m_appWindow->AsyncMessageBox(message.str(), L"Message from Service Worker");
                }
                return S_OK;
            })
            .Get(),
        &m_webMessageReceivedToken);

    // Get ServiceWorkerManager from profile and setup events to listen to service worker post messages.
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    CHECK_FEATURE_RETURN_EMPTY(webView2_13);

    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto webViewExperimentalProfile13 =
        webView2Profile.try_query<ICoreWebView2ExperimentalProfile13>();
    CHECK_FEATURE_RETURN_EMPTY(webViewExperimentalProfile13);
    CHECK_FAILURE(
        webViewExperimentalProfile13->get_ServiceWorkerManager(&m_serviceWorkerManager));

    CHECK_FAILURE(m_serviceWorkerManager->add_ServiceWorkerRegistered(
        Callback<ICoreWebView2ExperimentalServiceWorkerRegisteredEventHandler>(
            [this](
                ICoreWebView2ExperimentalServiceWorkerManager* sender,
                ICoreWebView2ExperimentalServiceWorkerRegisteredEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ExperimentalServiceWorkerRegistration>
                    serviceWorkerRegistration;
                CHECK_FAILURE(args->get_ServiceWorkerRegistration(&serviceWorkerRegistration));

                if (serviceWorkerRegistration)
                {
                    wil::unique_cotaskmem_string scopeUri;
                    CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));
                    std::wstring scopeUriStr(scopeUri.get());

                    wil::com_ptr<ICoreWebView2ExperimentalServiceWorker> serviceWorker;
                    CHECK_FAILURE(
                        serviceWorkerRegistration->get_ActiveServiceWorker(&serviceWorker));

                    if (serviceWorker)
                    {
                        SetupEventsOnServiceWorker(serviceWorker);
                    }
                    else
                    {
                        CHECK_FAILURE(serviceWorkerRegistration->add_ServiceWorkerActivated(
                            Callback<
                                ICoreWebView2ExperimentalServiceWorkerActivatedEventHandler>(
                                [this](
                                    ICoreWebView2ExperimentalServiceWorkerRegistration* sender,
                                    ICoreWebView2ExperimentalServiceWorkerActivatedEventArgs*
                                        args) -> HRESULT
                                {
                                    wil::com_ptr<ICoreWebView2ExperimentalServiceWorker>
                                        serviceWorker;
                                    CHECK_FAILURE(
                                        args->get_ActiveServiceWorker(&serviceWorker));
                                    SetupEventsOnServiceWorker(serviceWorker);

                                    return S_OK;
                                })
                                .Get(),
                            nullptr));
                    }
                }

                return S_OK;
            })
            .Get(),
        &m_serviceWorkerRegisteredToken));
}

void SetupEventsOnServiceWorker(
    wil::com_ptr<ICoreWebView2ExperimentalServiceWorker> serviceWorker)
{
    serviceWorker->add_WebMessageReceived(
        Callback<ICoreWebView2ExperimentalServiceWorkerWebMessageReceivedEventHandler>(
            [this](
                ICoreWebView2ExperimentalServiceWorker* sender,
                ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {

                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring messageFromWorker = messageRaw.get();

                std::wstringstream message{};
                message << L"Message: " << std::endl << messageFromWorker << std::endl;
                m_appWindow->AsyncMessageBox(message.str(), L"Message from Service Worker");

                return S_OK;
            })
            .Get(),
        nullptr);
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
            
            if (event.data === 'chromeWebViewNotAvailable') {
                self.chrome.webview.postMessage('MessageFromMainThread');
            }
        });
    </script>
</head>
<body>
    <h1>Service Worker Post Message Setting</h1>
    <p>This page registers a service worker, posts a message to it, and listens for responses.</p>
</body>
</html>
```

**service_worker.js**
```js
self.addEventListener('message', (event) => {
  if(self.chrome && self.chrome.webview) {
    event.source.postMessage('chromeWebViewAvailable');
    // When self.chrome.webview is available, message can be directly posted
    // to service worker object on host.
    self.chrome.webview.postMessage('Service Worker Message directly from service worker thread');
  } else {
    // When self.chrome.webview is not available, message can be posted back
    // to main thread, which can then forward it to host.
    event.source.postMessage('chromeWebViewNotAvailable');
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
    WebViewSettings.IsWebViewScriptApisForServiceWorkerEnabled = !WebViewSettings.IsWebViewScriptApisForServiceWorkerEnabled;

    MessageBox.Show(this, 
        $"IsWebViewScriptApisForServiceWorkerEnabled is now set to: {WebViewSettings.IsWebViewScriptApisForServiceWorkerEnabled}",
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
  /// Gets the `IsWebViewScriptApisForServiceWorkerEnabled` property.
  [propget] HRESULT IsWebViewScriptApisForServiceWorkerEnabled([out, retval] BOOL* value);

  /// Enables or disables webview2 specific Service Worker JS APIs in the WebView2.
  /// When set to `TRUE`, chrome and webview objects are available in Service Workers .
  /// chrome.webview exposes APIs to interact with the WebView from Service Workers.
  /// The default value is `FALSE`.
  /// When enabled, this setting takes effect for all the newly installed Service Workers.
  [propput] HRESULT IsWebViewScriptApisForServiceWorkerEnabled([in] BOOL value)
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
            Boolean IsWebViewScriptApisForServiceWorkerEnabled { get; set; };
        }
    }
}
```