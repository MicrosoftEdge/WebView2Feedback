Post message support for Dedicated and Service Workers
===

# Background
Currently, if developers want to post a message to or from a worker, they must
first post a message to the main thread and then post a message to the worker
from the main thread. This leads to increased load on the main thread.

The WebView2 team is introducing APIs that allow messages to be posted directly
from the Host app to dedicated and service workers, and vice versa. This
eliminates the need for the main thread to act as an intermediary, thereby
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
message sent from worker using `self.chrome.webview`.

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
self.chrome.webview.addEventListener('message', e => {
  let result;
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
      result = first / second;
      break;
    }
    default: {
      result = 'Failed to process the command';
    }
  }

  self.chrome.webview.postMessage('Result: ' + result.toString());
});
```

### C++ Sample
```cpp
using namespace Microsoft::WRL;

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2Staging26> m_webView2Staging_26;

ScenarioDedicatedWorker(AppWindow* appWindow) : m_appWindow(appWindow)
{
    //! [DedicatedWorkerCreated]
    m_appWindow->GetWebView()->QueryInterface(IID_PPV_ARGS(&m_webView2Staging_26));
    CHECK_FEATURE_RETURN_EMPTY(m_webView2Staging_26);

    CHECK_FAILURE(m_webView2Staging_26->add_DedicatedWorkerCreated(
        Callback<ICoreWebView2StagingDedicatedWorkerCreatedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2StagingDedicatedWorkerCreatedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2StagingDedicatedWorker> dedicatedWorker;
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
        nullptr));
    //! [DedicatedWorkerCreated]
}

void SetupEventsOnDedicatedWorker(
    wil::com_ptr<ICoreWebView2StagingDedicatedWorker> dedicatedWorker)
{
    CHECK_FAILURE(dedicatedWorker->add_WebMessageReceived(
        Callback<ICoreWebView2StagingDedicatedWorkerWebMessageReceivedEventHandler>(
            [this](
                ICoreWebView2StagingDedicatedWorker* sender,
                ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring message = messageRaw.get();

                m_appWindow->AsyncMessageBox(message, L"Message from Dedicated Worker");

                return S_OK;
            })
            .Get(),
        nullptr));
}

void ComputeWithDedicatedWorker(
    wil::com_ptr<ICoreWebView2StagingDedicatedWorker> dedicatedWorker)
{
    TextInputDialog dialog(
        m_appWindow->GetMainWindow(), L"Post Web Message JSON", L"Web message JSON",
        L"Enter the web message as JSON.");
    // Ex: {"command":"ADD","first":2,"second":3}
    if (dialog.confirmed)
    {
        dedicatedWorker->PostWebMessageAsJson(dialog.input.c_str());
    }
}
```

### .NET/WinRT
```c#
void DedicatedWorkerCreatedExecuted(object target, ExecutedRoutedEventArgs e)
{
    RegisterForDedicatedWorkerCreated();
}

void RegisterForDedicatedWorkerCreated()
{
    webView.CoreWebView2.DedicatedWorkerCreated += (sender, args) =>
    {
        CoreWebView2DedicatedWorker dedicatedWorker = args.Worker;
        MessageBox.Show("Dedicated worker is created" , "Dedicated Worker Message");
        SetupEventsOnDedicatedWorker(dedicatedWorker);
        ComputeWithDedicatedWorker(dedicatedWorker);
    };
}

void SetupEventsOnDedicatedWorker(CoreWebView2DedicatedWorker dedicatedWorker)
{
    dedicatedWorker.WebMessageReceived += (sender, args) =>
    {
        MessageBox.Show(args.TryGetWebMessageAsString(), "Message from Dedicated Worker");
    };
}

void ComputeWithDedicatedWorker(CoreWebView2DedicatedWorker dedicatedWorker)
{
    var dialog = new TextInputDialog(
        title: "Post Web Message JSON",
        description: "Enter the web message as JSON.",
        defaultInput: "");
    // Ex: {"command":"MUL","first":2,"second":3}
    if (dialog.ShowDialog() == true)
    {
        dedicatedWorker.PostWebMessageAsJson(dialog.Input.Text);
    }
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
const CACHE_NAME = 'sw_post_message_cache';
const CACHE_LIST = ['style.css'];

const cacheFirst = async (request) => {
  // First try to get the resource from the cache
  const responseFromCache = await caches.match(request);
  if (responseFromCache) {
    console.log('Cache hit for request: ', request.url);
    return responseFromCache;
  }

  // Next try to get the resource from the network
  try {
    console.log('Cache miss for request: ', request.url);
    const responseFromNetwork = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    console.log('Cache new resource: ', request.url);
    await cache.put(request, responseFromNetwork.clone());

    // Notify the app about the new cached resource.
    self.chrome.webview.postMessage('Cached new resource: ' + request.url);

    return responseFromNetwork;
  } catch (error) {
    return new Response('Network error happened', {
      status: 408,
      headers: {'Content-Type': 'text/plain'},
    });
  }
};

const addToCache = async (url) => {
  console.log('Add to cache: ', url);
  const cache = await caches.open(CACHE_NAME);
  cache.add(url);
};

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME)
                      .then(cache => cache.addAll(CACHE_LIST))
                      .then(self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', event => {
  event.respondWith(cacheFirst(event.request));
});

self.chrome.webview.addEventListener('message', e => {
  if (e.data.command === 'ADD_TO_CACHE') {
    addToCache(e.data.url);
  }
});
```

### C++ Sample
```cpp
using namespace Microsoft::WRL;

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
wil::com_ptr<ICoreWebView2StagingServiceWorkerManager> m_serviceWorkerManager;

ScenarioServiceWorkerManager(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    CreateServiceWorkerManager();
    SetupEventsOnWebview();
}

void CreateServiceWorkerManager()
{
    //! [ServiceWorkerManager]
    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    CHECK_FEATURE_RETURN_EMPTY(webView2_13);

    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto webViewStagingProfile3 = webView2Profile.try_query<ICoreWebView2StagingProfile3>();
    CHECK_FEATURE_RETURN_EMPTY(webViewStagingProfile3);
    CHECK_FAILURE(webViewStagingProfile3->get_ServiceWorkerManager(&m_serviceWorkerManager));
    //! [ServiceWorkerManager]
}

void SetupEventsOnWebview()
{
    if (!m_serviceWorkerManager)
    {
        return;
    }

    //! [ServiceWorkerRegistered]
    CHECK_FAILURE(m_serviceWorkerManager->add_ServiceWorkerRegistered(
        Callback<ICoreWebView2StagingServiceWorkerRegisteredEventHandler>(
            [this](
                ICoreWebView2StagingServiceWorkerManager* sender,
                ICoreWebView2StagingServiceWorkerRegisteredEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2StagingServiceWorkerRegistration>
                    serviceWorkerRegistration;
                CHECK_FAILURE(args->get_ServiceWorkerRegistration(&serviceWorkerRegistration));

                if (serviceWorkerRegistration)
                {
                    wil::unique_cotaskmem_string scopeUri;
                    CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));
                    std::wstring scopeUriStr(scopeUri.get());

                    wil::com_ptr<ICoreWebView2StagingServiceWorker> serviceWorker;
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
                            Callback<ICoreWebView2StagingServiceWorkerActivatedEventHandler>(
                                [this](
                                    ICoreWebView2StagingServiceWorkerRegistration* sender,
                                    ICoreWebView2StagingServiceWorkerActivatedEventArgs* args)
                                    -> HRESULT
                                {
                                    wil::com_ptr<ICoreWebView2StagingServiceWorker>
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
        nullptr));
    //! [ServiceWorkerRegistered]
}

void SetupEventsOnServiceWorker(
    wil::com_ptr<ICoreWebView2StagingServiceWorker> serviceWorker)
{
    CHECK_FAILURE(serviceWorker->add_WebMessageReceived(
        Callback<ICoreWebView2StagingServiceWorkerWebMessageReceivedEventHandler>(
            [this](
                ICoreWebView2StagingServiceWorker* sender,
                ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring message = messageRaw.get();

                m_appWindow->AsyncMessageBox(message, L"Message from Service Worker");

                return S_OK;
            })
            .Get(),
        nullptr));
}

void AddToCache(
    std::wstring url, wil::com_ptr<ICoreWebView2StagingServiceWorker> serviceWorker)
{
    std::wstring msg = L"{\"command\":\"ADD_TO_CACHE\",\"url\":\"" + url + L"\"}";
    serviceWorker->PostWebMessageAsJson(msg.c_str());
}
```

### .NET/WinRT
```c#
CoreWebView2ServiceWorkerManager ServiceWorkerManager_;
void ServiceWorkerRegisteredExecuted(object target, ExecutedRoutedEventArgs e)
{
    RegisterForServiceWorkerRegistered();
}

void RegisterForServiceWorkerRegistered()
{
    if (ServiceWorkerManager_ == null)
    {
        ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
    }

    ServiceWorkerManager_.ServiceWorkerRegistered += (sender, args) =>
    {
        CoreWebView2ServiceWorkerRegistration serviceWorkerRegistration = args.ServiceWorkerRegistration;
        MessageBox.Show("Service worker is registered for " + serviceWorkerRegistration.ScopeUri, "Service Worker Registration Message");

        CoreWebView2ServiceWorker serviceWorker = serviceWorkerRegistration.ActiveServiceWorker;
        if (serviceWorker != null)
        {
            SetupEventsOnServiceWorker(serviceWorker);
            AddToCache(serviceWorker, "img.jpg");
        }
        else
        {
            serviceWorkerRegistration.ServiceWorkerActivated += (sender1, args1) =>
            {
                SetupEventsOnServiceWorker(serviceWorker);
                AddToCache(serviceWorker, "img.jpg");
            };
        }
    };
}

void SetupEventsOnServiceWorker(CoreWebView2ServiceWorker serviceWorker)
{
    serviceWorker.WebMessageReceived += (sender, args) =>
    {
        MessageBox.Show(args.TryGetWebMessageAsString(), "Message from Service Worker");
    };
}

void AddToCache(CoreWebView2ServiceWorker serviceWorker, string url)
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
interface ICoreWebView2StagingDedicatedWorkerWebMessageReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingDedicatedWorker* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

[uuid(66833876-edba-5a60-8508-7da64504a9d2), object, pointer_default(unique)]
interface ICoreWebView2StagingDedicatedWorker : IUnknown {
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
      [in] ICoreWebView2StagingDedicatedWorkerWebMessageReceivedEventHandler* eventHandler,
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
  HRESULT PostWebMessageAsJson(
      [in] LPCWSTR messageAsJson
  );

  /// Posts a message that is a simple string rather than a string
  /// representation of a JSON object.  This behaves exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// arg of the worker's `self.chrome.webview` message is a string with the same
  /// value as `messageAsString`.  Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects.
  HRESULT PostWebMessageAsString(
      [in] LPCWSTR messageAsString
  );
}

/// Receives `WebMessageReceived` events.
[uuid(8765d114-94f4-5d90-b833-b0c8cc05a4dc), object, pointer_default(unique)]
interface ICoreWebView2StagingServiceWorkerWebMessageReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingServiceWorker* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

[uuid(f115648d-56e3-5570-8d69-be999e769fd8), object, pointer_default(unique)]
interface ICoreWebView2StagingServiceWorker : IUnknown {
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
      [in] ICoreWebView2StagingServiceWorkerWebMessageReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_WebMessageReceived`.
  HRESULT remove_WebMessageReceived(
      [in] EventRegistrationToken token);

  /// Post the specific message to this worker.
  /// The worker receives the message by subscribing to the message event of the
  /// `self.chrome.webview` of the worker.
  /// 
  /// self.chrome.webview.addEventListener(â€˜messageâ€™, handler)
  /// self.chrome.webview.removeEventListener(â€˜messageâ€™, handler)
  /// 
  /// The event args is an instance of `MessageEvent`. The
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting must be `TRUE` or
  /// the web message will not be sent. The data property of the event arg is the
  /// message string parameter parsed as a JSON string into a JS object.
  /// The message is delivered asynchronously
  /// If the worker is terminated or destroyed before the message is posted,
  /// the message is discarded.
  HRESULT PostWebMessageAsJson(
      [in] LPCWSTR messageAsJson
  );

  /// Posts a message that is a simple string rather than a string
  /// representation of a JSON object.  This behaves exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// arg of the worker's `self.chrome.webview` message is a string with the same
  /// value as `messageAsString`.  Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects.
  HRESULT PostWebMessageAsString(
      [in] LPCWSTR messageAsString
  );
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DedicatedWorker
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2DedicatedWorker, CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived;

        void PostWebMessageAsJson(String messageAsJson);

        void PostWebMessageAsString(String messageAsString);
    }

    runtimeclass CoreWebView2ServiceWorker
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorker, CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived;

        void PostWebMessageAsJson(String messageAsJson);

        void PostWebMessageAsString(String messageAsString);
    }
}
```
