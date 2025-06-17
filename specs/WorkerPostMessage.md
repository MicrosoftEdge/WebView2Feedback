Post message support for Dedicated and Service Workers
===

# Background
Currently, if developers want to post a message to or from a worker, they must
first post a message to the JS main thread and then post a message to the worker
from the JS main thread. This leads to increased load on the JS main thread.
i.e., the current flow is as below,
ICoreWebView2.PostWebMessage -> DOM window (JS main thread) -> worker

The WebView2 team is introducing APIs that allow messages to be posted directly
from the Host app to dedicated and service workers, and vice versa. This
eliminates the need for the JS main thread to act as an intermediary, thereby
improving app performance and responsiveness.

# Description
We propose the following APIs:

**PostWebMessageAsJson**: This API gives ability to post a message to
dedicated/service worker. The worker receives the message by subscribing to
message event of `self.chrome.webview`.

**PostWebMessageAsString**: This API gives ability to post a message that is
a simple string rather than a string representation of a JSON object to
dedicated/service worker. The worker receives the message by subscribing to
message event of `self.chrome.webview`. This can be used to communicate using
simple strings rather than JSON objects.

**WebMessageReceived**: This event gives Host app the ability to receive
message sent from worker using `self.chrome.webview.postMessage`.

# Examples
## Dedicated Worker
## Posting messages to and from a dedicated worker
### main.js
```JS
if (window.Worker) {
  const worker = new Worker('dedicated_worker.js');
}
```

### dedicated_worker.js
```JS
//! [chromeWebView]
self.chrome.webview.addEventListener('message', (e) => {
  const first = e.data.first;
  const second = e.data.second;
  switch (e.data.command) {
    case 'ADD': {
      result = first + second;
      break;
    }
    case 'SUB': {
      result = first - second;
      break;
    }
    case 'MUL': {
      result = first * second;
      break;
    }
    case 'DIV': {
      if (second === 0) {
        result = 'Error: Division by zero';
        break;
      }

      result = first / second;
      break;
    }
    default: {
      result = 'Failed to process the command';
    }
  }
  self.chrome.webview.postMessage('Result: ' + result.toString());
});
//! [chromeWebView]
```

### C++ Sample
```cpp
using namespace Microsoft::WRL;

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView226> m_webView2_26;
EventRegistrationToken m_dedicatedWorkerCreatedToken = {};

ScenarioDedicatedWorkerPostMessage::ScenarioDedicatedWorkerPostMessage(AppWindow* appWindow)
    : m_appWindow(appWindow)
{
    //! [DedicatedWorkerCreated]
    m_appWindow->GetWebView()->QueryInterface(IID_PPV_ARGS(&m_webView2_26));
    CHECK_FEATURE_RETURN_EMPTY(m_webView2_26);

    CHECK_FAILURE(m_webView2_26->add_DedicatedWorkerCreated(
        Callback<ICoreWebView2DedicatedWorkerCreatedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DedicatedWorkerCreatedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2DedicatedWorker> dedicatedWorker;
                CHECK_FAILURE(args->get_Worker(&dedicatedWorker));

                wil::unique_cotaskmem_string scriptUri;
                CHECK_FAILURE(dedicatedWorker->get_ScriptUri(&scriptUri));

                std::wstring scriptUriStr(scriptUri.get());
                m_appWindow->AsyncMessageBox(scriptUriStr, L"Dedicated worker is created");

                SetupEventsOnDedicatedWorker(dedicatedWorker);
                ComputeWithDedicatedWorker(dedicatedWorker);

                return S_OK;
            })
            .Get(),
        &m_dedicatedWorkerCreatedToken));
    //! [DedicatedWorkerCreated]

    // Navigate to a page that has dedicated worker.
}

void ScenarioDedicatedWorkerPostMessage::SetupEventsOnDedicatedWorker(
    wil::com_ptr<ICoreWebView2DedicatedWorker> dedicatedWorker)
{
    //! [WebMessageReceived]
    dedicatedWorker->add_WebMessageReceived(
        Callback<ICoreWebView2DedicatedWorkerWebMessageReceivedEventHandler>(
            [this](
                ICoreWebView2DedicatedWorker* sender,
                ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string scriptUri;
                CHECK_FAILURE(args->get_Source(&scriptUri));

                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring messageFromWorker = messageRaw.get();

                std::wstringstream message{};
                message << L"Dedicated Worker: " << std::endl << scriptUri.get() << std::endl;
                message << std::endl;
                message << L"Message: " << std::endl << messageFromWorker << std::endl;
                m_appWindow->AsyncMessageBox(message.str(), L"Message from Dedicated Worker");

                return S_OK;
            })
            .Get(),
        nullptr);
    //! [WebMessageReceived]
}

void ScenarioDedicatedWorkerPostMessage::ComputeWithDedicatedWorker(
    wil::com_ptr<ICoreWebView2DedicatedWorker> dedicatedWorker)
{
    // Do not block from event handler
    m_appWindow->RunAsync(
        [this, dedicatedWorker]
        {
            TextInputDialog dialog(
                m_appWindow->GetMainWindow(), L"Post Web Message JSON", L"Web message JSON",
                L"Enter the web message as JSON.");
            // Ex: {"command":"ADD","first":2,"second":3}
            if (dialog.confirmed)
            {
                //! [PostWebMessageAsJson]
                dedicatedWorker->PostWebMessageAsJson(dialog.input.c_str());
                //! [PostWebMessageAsJson]
            }
        });
}
```

### .NET/WinRT
```c#
private string _dedicatedWorkerPostMessageStr;

void DedicatedWorkerPostMessageExecuted(object target, ExecutedRoutedEventArgs e)
{
    _iWebView2.CoreWebView2.DedicatedWorkerCreated +=
        DedicatedWorker_PostMessage_DedicatedWorkerCreated;

    var dialog = new TextInputDialog(
        title: "Post Web Message JSON",
        description: "Enter the web message as JSON.",
        defaultInput: "{\"command\":\"ADD\",\"first\":2,\"second\":3}");
    // Ex: {"command":"MUL","first":2,"second":3}
    if (dialog.ShowDialog() == true)
    {
        _dedicatedWorkerPostMessageStr = dialog.Input.Text;
    }

    // Navigate to a page that has dedicated worker.
}

void DedicatedWorker_PostMessage_DedicatedWorkerCreated(object sender,
        CoreWebView2DedicatedWorkerCreatedEventArgs args)
{
    CoreWebView2DedicatedWorker dedicatedWorker = args.Worker;
    MessageBox.Show("Dedicated worker is created" , "Dedicated Worker Message");
    DedicatedWorker_PostMessage_SetupEventsOnDedicatedWorker(dedicatedWorker);
    DedicatedWorker_PostMessage_ComputeWithDedicatedWorker(dedicatedWorker);
}

void DedicatedWorker_PostMessage_SetupEventsOnDedicatedWorker(
        CoreWebView2DedicatedWorker dedicatedWorker)
{
    dedicatedWorker.WebMessageReceived += (sender, args) =>
    {
        StringBuilder messageBuilder = new StringBuilder();
        messageBuilder.AppendLine($"Dedicated Worker: \n{args.Source} ");
        messageBuilder.AppendLine($"\nMessage: \n{args.TryGetWebMessageAsString()} ");
        MessageBox.Show(messageBuilder.ToString(), "Message from Dedicated Worker",
                        MessageBoxButton.OK);
    };
}

void DedicatedWorker_PostMessage_ComputeWithDedicatedWorker(
        CoreWebView2DedicatedWorker dedicatedWorker)
{
    dedicatedWorker.PostWebMessageAsJson(_dedicatedWorkerPostMessageStr);
}
```

## Service Worker
## Posting messages to and from a service worker
### main.js
```JS
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js");
}

```
### sw.js
```JS
'use strict';

const CACHE_NAME = 'sw_post_message_cache';
const CACHE_LIST = ['style.css'];

const cacheFirst = async (request) => {
  // First try to get the resource from the cache
  const responseFromCache = await caches.match(request);
  if (responseFromCache) {
    console.log('Cache hit for request: ', request.url);
    // Notify the app about the cache hit.
    //! [chromeWebView]
    self.chrome.webview.postMessage('Cache hit for resource: ' + request.url);
    //! [chromeWebView]
    return responseFromCache;
  }

  // Next try to get the resource from the network
  try {
    console.log('Cache miss for request: ', request.url);
    const responseFromNetwork = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    console.log('Cache new resource: ', request.url);
    await cache.put(request, responseFromNetwork.clone());
    return responseFromNetwork;
  } catch (error) {
    return new Response('Network error happened', {
      status: 408,
      headers: { 'Content-Type': 'text/plain' },
    });
  }
};

const addToCache = async (url) => {
  console.log('Add to cache: ', url);
  const cache = await caches.open(CACHE_NAME);
  cache.add(url);
  //! [chromeWebView]
  chrome.webview.postMessage('Added to cache: ' + url);
  //! [chromeWebView]
};

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(CACHE_LIST))
      .then(self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event) => {
  event.respondWith(cacheFirst(event.request));
});

//! [chromeWebView]
self.chrome.webview.addEventListener('message', (event) => {
  if (event.data.command === 'ADD_TO_CACHE') {
    addToCache(event.data.url);
  }
});
//! [chromeWebView]
```

### C++ Sample
```cpp
using namespace Microsoft::WRL;

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
wil::com_ptr<ICoreWebView2ServiceWorkerManager> m_serviceWorkerManager;
EventRegistrationToken m_serviceWorkerRegisteredToken = {};

ScenarioServiceWorkerPostMessage::ScenarioServiceWorkerPostMessage(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    CreateServiceWorkerManager();
    SetupEventsOnWebview();
}

void ScenarioServiceWorkerPostMessage::CreateServiceWorkerManager()
{
    //! [ServiceWorkerManager]
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    CHECK_FEATURE_RETURN_EMPTY(webView2_13);

    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto webViewProfile3 = webView2Profile.try_query<ICoreWebView2Profile3>();
    CHECK_FEATURE_RETURN_EMPTY(webViewProfile3);
    CHECK_FAILURE(webViewProfile3->get_ServiceWorkerManager(&m_serviceWorkerManager));
    //! [ServiceWorkerManager]
}

void ScenarioServiceWorkerPostMessage::SetupEventsOnWebview()
{
    if (!m_serviceWorkerManager)
    {
        return;
    }

    //! [ServiceWorkerRegistered]
    CHECK_FAILURE(m_serviceWorkerManager->add_ServiceWorkerRegistered(
        Callback<ICoreWebView2ServiceWorkerRegisteredEventHandler>(
            [this](
                ICoreWebView2ServiceWorkerManager* sender,
                ICoreWebView2ServiceWorkerRegisteredEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ServiceWorkerRegistration>
                    serviceWorkerRegistration;
                CHECK_FAILURE(args->get_ServiceWorkerRegistration(&serviceWorkerRegistration));

                if (serviceWorkerRegistration)
                {
                    wil::unique_cotaskmem_string scopeUri;
                    CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));
                    std::wstring scopeUriStr(scopeUri.get());

                    wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker;
                    CHECK_FAILURE(
                        serviceWorkerRegistration->get_ActiveServiceWorker(&serviceWorker));

                    if (serviceWorker)
                    {
                        SetupEventsOnServiceWorker(serviceWorker);
                        AddToCache(L"img.jpg", serviceWorker);
                    }
                    else
                    {
                        CHECK_FAILURE(serviceWorkerRegistration->add_ServiceWorkerActivated(
                            Callback<ICoreWebView2ServiceWorkerActivatedEventHandler>(
                                [this](
                                    ICoreWebView2ServiceWorkerRegistration* sender,
                                    ICoreWebView2ServiceWorkerActivatedEventArgs* args)
                                    -> HRESULT
                                {
                                    wil::com_ptr<ICoreWebView2ServiceWorker>
                                        serviceWorker;
                                    CHECK_FAILURE(
                                        args->get_ActiveServiceWorker(&serviceWorker));

                                    SetupEventsOnServiceWorker(serviceWorker);
                                    AddToCache(L"img.jpg", serviceWorker);

                                    return S_OK;
                                })
                                .Get(),
                            nullptr));
                    }

                    m_appWindow->AsyncMessageBox(scopeUriStr, L"Service worker is registered");
                }

                return S_OK;
            })
            .Get(),
        &m_serviceWorkerRegisteredToken));
    //! [ServiceWorkerRegistered]
}

void ScenarioServiceWorkerPostMessage::SetupEventsOnServiceWorker(
    wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker)
{
    //! [WebMessageReceived]
    serviceWorker->add_WebMessageReceived(
        Callback<ICoreWebView2ServiceWorkerWebMessageReceivedEventHandler>(
            [this](
                ICoreWebView2ServiceWorker* sender,
                ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string scriptUri;
                CHECK_FAILURE(args->get_Source(&scriptUri));

                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring messageFromWorker = messageRaw.get();

                std::wstringstream message{};
                message << L"Service Worker: " << std::endl << scriptUri.get() << std::endl;
                message << std::endl;
                message << L"Message: " << std::endl << messageFromWorker << std::endl;
                m_appWindow->AsyncMessageBox(message.str(), L"Message from Service Worker");

                return S_OK;
            })
            .Get(),
        nullptr);
    //! [WebMessageReceived]
}

void ScenarioServiceWorkerPostMessage::AddToCache(
    std::wstring url, wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker)
{
    std::wstring msg = L"{\"command\":\"ADD_TO_CACHE\",\"url\":\"" + url + L"\"}";
    //! [PostWebMessageAsJson]
    serviceWorker->PostWebMessageAsJson(msg.c_str());
    //! [PostWebMessageAsJson]
}
```

### .NET/WinRT
```c#
CoreWebView2ServiceWorkerManager PostMessage_ServiceWorkerManager_;

void ServiceWorkerPostMessageExecuted(object target, ExecutedRoutedEventArgs e)
{
    PostMessage_ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;

    PostMessage_ServiceWorkerManager_.ServiceWorkerRegistered +=
        ServiceWorker_PostMessage_ServiceWorkerRegistered;
}

void ServiceWorker_PostMessage_ServiceWorkerRegistered(object sender,
        CoreWebView2ServiceWorkerRegisteredEventArgs args)
{
    CoreWebView2ServiceWorkerRegistration serviceWorkerRegistration =
        args.ServiceWorkerRegistration;
    MessageBox.Show("Service worker is registered for " + serviceWorkerRegistration.ScopeUri,
                    "Service Worker Registration Message");

    CoreWebView2ServiceWorker serviceWorker = serviceWorkerRegistration.ActiveServiceWorker;
    if (serviceWorker != null)
    {
        ServiceWorker_PostMessage_SetupEventsOnServiceWorker(serviceWorker);
        ServiceWorker_PostMessage_AddToCache(serviceWorker, "img.jpg");
    }
    else
    {
        serviceWorkerRegistration.ServiceWorkerActivated += (sender1, args1) =>
        {
            ServiceWorker_PostMessage_SetupEventsOnServiceWorker(serviceWorker);
            ServiceWorker_PostMessage_AddToCache(serviceWorker, "img.jpg");
        };
    }
}

void ServiceWorker_PostMessage_SetupEventsOnServiceWorker(CoreWebView2ServiceWorker serviceWorker)
{
    serviceWorker.WebMessageReceived += (sender, args) =>
    {
        StringBuilder messageBuilder = new StringBuilder();
        messageBuilder.AppendLine($"Service Worker: \n{args.Source} ");
        messageBuilder.AppendLine($"\nMessage: \n{args.TryGetWebMessageAsString()} ");
        MessageBox.Show(messageBuilder.ToString(), "Message from Service Worker",
                        MessageBoxButton.OK);
    };
}

void ServiceWorker_PostMessage_AddToCache(CoreWebView2ServiceWorker serviceWorker, string url)
{
    string msg = "{\"command\":\"ADD_TO_CACHE\",\"url\":\"" + url + "\"}";
    serviceWorker.PostWebMessageAsJson(msg);
}
```

# API Details
## C++
```
/// Receives `WebMessageReceived` events.
[uuid(b366218b-0bb8-58a3-ac33-f40a2235366e), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorkerWebMessageReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2DedicatedWorker* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

[uuid(66833876-edba-5a60-8508-7da64504a9d2), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorker : IUnknown {
  /// Adds an event handler for the `WebMessageReceived` event.
  /// Add an event handler for the `WebMessageReceived` event.
  /// `WebMessageReceived` can be subscribed to, when the
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting is set TRUE and the
  ///  worker runs
  /// `self.chrome.webview.postMessage`.  The `postMessage` function is
  /// `void postMessage(object)` where object is any object supported by JSON
  /// conversion.
  /// 
  /// If the worker calls `postMessage` multiple times, the corresponding
  /// `WebMessageReceived` events are guaranteed to be fired in the same order.
  HRESULT add_WebMessageReceived(
      [in] ICoreWebView2DedicatedWorkerWebMessageReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_WebMessageReceived`.
  HRESULT remove_WebMessageReceived(
      [in] EventRegistrationToken token);


  /// Post the specific message to this worker.
  /// The worker receives the message by subscribing to the message event of the
  /// `self.chrome.webview` of the worker.
  /// 
  /// self.chrome.webview.addEventListener('message', handler)
  /// self.chrome.webview.removeEventListener('message', handler)
  /// 
  /// The event args is an instance of `MessageEvent`. The
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting must be `TRUE` or
  /// the web message will not be sent. The data property of the event arg is the
  /// message string parameter parsed as a JSON string into a JS object.
  /// The message is delivered asynchronously
  /// If the worker is terminated or destroyed before the message is posted,
  /// the message is discarded.
  /// See also the equivalent methods: `ICoreWebView2::PostWebMessageAsJson` and
  /// `ICoreWebView2Frame::PostWebMessageAsJson`
  HRESULT PostWebMessageAsJson(
      [in] LPCWSTR webMessageAsJson
  );

  /// Posts a message that is a simple string rather than a string
  /// representation of a JSON object.  This behaves exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// arg of the worker's `self.chrome.webview` message is a string with the same
  /// value as `messageAsString`.  Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects. Please see `PostWebMessageAsJson` for additional
  /// information.
  /// See also the equivalent methods: `ICoreWebView2::PostWebMessageAsString`
  /// and `ICoreWebView2Frame::PostWebMessageAsString`
  HRESULT PostWebMessageAsString(
      [in] LPCWSTR webMessageAsString
  );
}

/// Receives `WebMessageReceived` events.
[uuid(8765d114-94f4-5d90-b833-b0c8cc05a4dc), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerWebMessageReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorker* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

[uuid(f115648d-56e3-5570-8d69-be999e769fd8), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorker : IUnknown {
  /// Adds an event handler for the `WebMessageReceived` event.
  /// Add an event handler for the `WebMessageReceived` event.
  /// `WebMessageReceived` is fired, when the
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting is set and the
  ///  worker runs
  /// `self.chrome.webview.postMessage`.  The `postMessage` function is
  /// `void postMessage(object)` where object is any object supported by JSON
  /// conversion.
  /// 
  /// If the worker calls `postMessage` multiple times, the corresponding
  /// `WebMessageReceived` events are guaranteed to be fired in the same order.
  HRESULT add_WebMessageReceived(
      [in] ICoreWebView2ServiceWorkerWebMessageReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_WebMessageReceived`.
  HRESULT remove_WebMessageReceived(
      [in] EventRegistrationToken token);

  /// Post the specific message to this worker.
  /// The worker receives the message by subscribing to the message event of the
  /// `self.chrome.webview` of the worker.
  /// 
  /// self.chrome.webview.addEventListener('message', handler)
  /// self.chrome.webview.removeEventListener('message', handler)
  /// 
  /// The event args is an instance of `MessageEvent`. The
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting must be `TRUE` or
  /// the web message will not be sent. The data property of the event arg is the
  /// message string parameter parsed as a JSON string into a JS object.
  /// The message is delivered asynchronously
  /// If the worker is terminated or destroyed before the message is posted,
  /// the message is discarded.
  /// See also the equivalent methods: `ICoreWebView2::PostWebMessageAsJson` and
  /// `ICoreWebView2Frame::PostWebMessageAsJson`
  HRESULT PostWebMessageAsJson(
      [in] LPCWSTR webMessageAsJson
  );

  /// Posts a message that is a simple string rather than a string
  /// representation of a JSON object.  This behaves exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// arg of the worker's `self.chrome.webview` message is a string with the same
  /// value as `webMessageAsString`.  Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects. Please see `PostWebMessageAsJson` for additional
  /// information.
  /// See also the equivalent methods: `ICoreWebView2::PostWebMessageAsString`
  /// and `ICoreWebView2Frame::PostWebMessageAsString`
  HRESULT PostWebMessageAsString(
      [in] LPCWSTR webMessageAsString
  );
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DedicatedWorker
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2DedicatedWorker,
            CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived;

        void PostWebMessageAsJson(String webMessageAsJson);

        void PostWebMessageAsString(String webMessageAsString);
    }

    runtimeclass CoreWebView2ServiceWorker
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorker,
            CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived;

        void PostWebMessageAsJson(String webMessageAsJson);

        void PostWebMessageAsString(String webMessageAsString);
    }
}
```

## JavaScript
```JS
interface WorkerGlobalScope {
    chrome: Chrome;
}

interface Chrome {
    /**
     * Makes the JavaScript APIs in WebView2 available to the worker.
     */
    webview: WebView;
}

/**
 * `self.chrome.webview` is the interface to access the WebView2-specific APIs
 * that are available to the worker running within WebView2 Runtime.
 */
interface WebView extends EventTarget {
    /**
     * When the worker calls `postMessage`, the `message` parameter is converted
     * to JSON and is posted asynchronously to the WebView2 host process.
     * This will result in either the
     * `ICoreWebView2DedicatedWorker.WebMessageReceived` event or the
     * `ICoreWebView2ServiceWorker.WebMessageReceived` event being raised,
     * depending on if `postMessage` is called from the dedicated worker or
     * service worker.
     * @param message The message to send to the WebView2 host. This can be any
     *    object that can be serialized to JSON.
     */
    postMessage(message: any) : void;

    /**
     * The standard `EventTarget.addEventListener` method. Use it to subscribe
     * to the `message` event.
     * The `message` event receives messages posted from the WebView2 host via
     * `PostWebMessageAsJson` or `PostWebMessageAsString`.
     *
     * @param type The name of the event to subscribe to.
     */
    addEventListener(type: string,
                     listener: EventListenerOrEventListenerObject,
                     options?: boolean | AddEventListenerOptions): void;
    /**
     * The standard `EventTarget.removeEventListener` method. Use it to
     * unsubscribe to the `message` event.
     *
     * @param type The name of the event to unsubscribe from.
     */

    removeEventListener(type: string,
                        listener: EventListenerOrEventListenerObject,
                        options?: boolean | EventListenerOptions): void;
}
```
