Workers support in WebView2
===

# Background
Currently, although workers can be used in web content in WebView2, WebView2
lacks comprehensive WebView2 APIs for developers to fully utilize workers,
leading to increased load on the main thread, offloading to native, or
forking your web app for WebView2 scenarios. To address this, the WebView2 team
is introducing support for worker scenarios. This enhancement allows WebView2
users to interact with Web Workers from native apps, bypassing the JavaScript
thread to boost app performance and responsiveness, or to run tasks in the
background for offline support, push notifications, background sync, content
updates, and more. As a part of the work, the WebView2 team is adding support
for [Dedicated Workers](https://developer.mozilla.org/docs/Web/API/Web_Workers_API), [Shared Workers](https://developer.mozilla.org/docs/Web/API/SharedWorker), and [Service Workers](https://developer.mozilla.org/docs/Web/API/Service_Worker_API).
While there are other types of web workers, our initial focus is on these three,
with plans to broaden our support for other workers in the future.

**What is Web Worker?** [Web Workers](https://developer.mozilla.org/docs/Web/API/Web_Workers_API) allow web
content to execute scripts in background threads, enabling tasks to run
independently of the user interface and facilitating communication between
threads using message passing. Web Workers can also make network requests using
fetch() or XMLHttpRequest APIs. Few examples of workers are

- **Dedicated Worker**: Dedicated Workers are a type of Web Worker that operates
  independently in the background of a web page, enabling parallel execution of
  tasks without blocking the main UI thread. They are created by specific web
  pages and communicate with them via message passing, making them ideal for
  offloading CPU-intensive operations and improving overall performance and
  responsiveness of web applications.

- **Shared Worker**: Shared Workers are a type of Web Worker that can be
  accessed by multiple scripts running in different windows, IFrames, or other
  contexts, as long as they are within the same domain as the worker. Unlike
  Dedicated Workers, which are tied to a specific web page, Shared Workers are
  not tied to a single page and can be used by multiple pages or scripts. This
  requires communication via an active port, making them slightly more complex
  to implement but enabling collaboration and shared resources across different
  parts of a web application.

- **Service Worker**: Service Workers serve as intermediary agents between web
  applications, the browser, and the network, functioning as proxy servers.
  Primarily, they facilitate the development of seamless offline experiences by
  caching resources and enabling web apps to continue functioning without an
  internet connection. Additionally, Service Workers intercept network requests,
  enabling customized responses based on network availability, and can update
  server-side assets. Moreover, they grant access to push notifications and
  background sync APIs, enhancing the functionality and interactivity of web
  applications.

# Description

We propose the introduction of APIs that enable the host application to oversee
workers. These APIs lay the groundwork for the development of additional APIs,
facilitating direct interaction between the host application and the workers,
and support background operations for service workers.

**DedicatedWorkerCreated**: This event, associated with CoreWebView2, is raised
when a web page initiates a dedicated worker. It grants access to the
CoreWebView2DedicatedWorker object, which contains information such as the
script uri. Additionally, it provides a 'destroying' event that is raised
just before this object is due for destruction.

**ServiceWorkerRegistered**: This event, originating from the
CoreWebView2ServiceWorkerManager associated with CoreWebView2Profile is raised
when a service worker is successfully registered within the context of a
WebView2 application for the profile. This event provides access to a
CoreWebView2ServiceWorkerRegistration object, which encapsulates information
about the registered service worker, such as its script uri and scope uri.
Additionally, it enables subscription to the service worker's lifecycle events,
including updates and unregistration.

**GetServiceWorkerRegistrations**: The GetServiceWorkerRegistrations method,
part of the CoreWebView2ServiceWorkerManager class, is used to retrieve all
service worker registrations within the context of a WebView2 application for
the profile. This method gives a collection of
CoreWebView2ServiceWorkerRegistration objects, each encapsulating information
about a registered service worker, such as its script uri and scope uri.

**GetServiceWorkerRegistration**: The GetServiceWorkerRegistration method, part
of the CoreWebView2ServiceWorkerManager class, is used to retrieve a specific
service worker registration within the context of a WebView2 application for the
profile. This asynchronous method takes a scope uri as an argument and returns a
CoreWebView2ServiceWorkerRegistration object that encapsulates information about
the registered service worker with the given scope uri, such as its script uri. This
method is useful for accessing details of a specific service worker based on its
scope uri.

**SharedWorkerCreated**: This event, originating from the
CoreWebView2SharedWorkerManager associated with CoreWebView2Profile, is raised
when a shared worker is successfully created within the context of a WebView2
application for the profile. It grants access to the CoreWebView2SharedWorker
object, which contains information such as the script uri.
Additionally, it provides a 'destroying' event that is raised just before this
object is due for destruction.

**GetSharedWorkers**: The GetSharedWorkers method, part of the
CoreWebViewSharedWorkerManager class, is used to retrieve all shared workers
created within the context of a WebView2 application for the profile. This
method gives a collection of CoreWebView2SharedWorkers objects.

# Background
This API specification provides a basic overview, including fundamental concepts
and introduces management APIs for interaction.
Please note that future API specifications will introduce additional features for workers.

Stay tuned for updates to this spec and look out for new API specs that will
expand on the capabilities of workers.

See work in progress Workers API specs
 - [API Spec for SW Background Sync](https://github.com/MicrosoftEdge/WebView2Feedback/blob/main/specs/PeriodicBackgroundSyncAndBackgroundSync.md)

# Examples
## Dedicated Worker
## Monitoring the Creation/Destruction of Dedicated Workers.
The following example demonstrates how to subscribe to the event that is raised
when a web page creates a dedicated worker. This event provides a
`CoreWebView2DedicatedWorker` object, enabling the host application to interact
with it.

This example also showcases the utilization of the upcoming PostMessage and
WorkerMessageReceived APIs. These APIs enable efficient communication between
the main thread and a dedicated worker.

## .NET/WinRT
```c#
    void PostMessageToWorker(CoreWebView2DedicatedWorker worker)
    {
        // Inside the worker, an event listener is set up for the 'message' event.
        // When a message is received from the host application, the worker
        // performs a fetch request. The host application also sets up an event
        // listener to receive messages from the worker. These messages could
        // contain fetched data or any error information from the worker's fetch
        // operation.
        worker.WorkerMessageReceived += (sender, args) =>
        {
            var message = args.TryGetWorkerMessageAsString();
            // This section of the code is dedicated to handling updates received
            // from the worker. Depending on the nature of these updates, you
            // might choose to perform various actions. For instance, you could
            // modify the user interface to reflect the new data, or you could
            // log the received data for debugging or record-keeping purposes.
        };

        // You can dispatch a message to the worker with the URL you want to
        // fetch data from the host app.
        worker.PostMessage("{ MyMessage: { type: 'FETCH_URL',url: 'https://example.com/data.json' }");
    }

    void DedicatedWorkerCreatedExecuted(object target, ExecutedRoutedEventArgs e)
    {
        RegisterForDedicatedWorkerCreated();
    }

    void RegisterForDedicatedWorkerCreated()
    {
        webView.CoreWebView2.DedicatedWorkerCreated += (sender, args) =>
        {
            CoreWebView2DedicatedWorker dedicatedWorker = args.Worker;
            dedicatedWorker.Destroying += (sender2, args2) =>
            {
              /*Cleanup on worker destruction*/
            };

            string scriptUri = dedicatedWorker.ScriptUri;
            LogMessage("Dedicated Worker has been created with the script located at the " + scriptUri);

            // Send a message to the dedicated worker to offload fetch request from the host app.
            PostMessageToWorker(dedicatedWorker);
        };
    }
```
## Win32 C++
```cpp
    void PostMessageToWorker(wil::com_ptr<ICoreWebView2DedicatedWorker> worker)
    {
        // Inside the worker, an event listener is set up for the 'message' event.
        // When a message is received from the host application, the worker performs
        // a fetch request. The host application also sets up an event listener
        // to receive messages from the worker. These messages could contain
        // fetched data or any error information from the worker's fetch operation.
        CHECK_FAILURE(worker->add_WorkerMessageReceived(
                    Callback<ICoreWebView2DedicatedWorkerMessageReceivedEventHandler>(
                        [](ICoreWebView2DedicatedWorker* sender,
                        ICoreWebView2DedicatedWorkerMessageReceivedEventArgs* args)
                        noexcept -> HRESULT
                        {
                            wil::unique_cotaskmem_string message;
                            CHECK_FAILURE(args->TryGetWorkerMessageAsString(&message));

                            // This section of the code is dedicated to handling
                            // updates received from the worker. Depending on the
                            // nature of these updates, you might choose to perform
                            // various actions. For instance, you could modify
                            // the user interface to reflect the new data, or you
                            // could log the received data for debugging or
                            // record-keeping purposes.

                            return S_OK;
                        })
                        .Get(),
                    nullptr));

        // You can dispatch a message to the worker with the URL you want to fetch data from
        // the host app.
        CHECK_FAILURE(worker->PostMessage("{ MyMessage: {type: 'FETCH_URL',url: 'https://example.com/data.json' }"));
    }

    ScenarioDedicatedWorker::ScenarioDedicatedWorker(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
    {
      m_webView2_25 = m_webView.try_query<ICoreWebView2_25>();
      CHECK_FEATURE_RETURN_EMPTY(m_webView2_25);

      CHECK_FAILURE(m_webView2_25->add_DedicatedWorkerCreated(
          Microsoft::WRL::Callback<ICoreWebView2DedicatedWorkerCreatedEventHandler>(
              [this](
                  ICoreWebView2* sender,
                  ICoreWebView2DedicatedWorkerCreatedEventArgs* args) noexcept
              {
                  wil::com_ptr<ICoreWebView2DedicatedWorker> dedicatedWorker;
                  CHECK_FAILURE(args->get_Worker(&dedicatedWorker));

                  if (dedicatedWorker)
                  {
                      // Subscribe to worker destroying event
                      CHECK_FAILURE(dedicatedWorker->add_Destroying(
                          Callback<ICoreWebView2DedicatedWorkerDestroyingEventHandler>(
                              [this](ICoreWebView2DedicatedWorker* sender2, IUnknown* args2)
                              -> HRESULT
                              {
                                  /*Cleanup on worker destruction*/
                                  return S_OK;
                              })
                              .Get(),
                          nullptr));

                      wil::unique_cotaskmem_string scriptUri;
                      CHECK_FAILURE(worker->get_ScriptUri(&scriptUri));

                      LogMessage(L"Dedicated Worker has been created with the script located at the " + std::wstring(scriptUri.get()));

                      // Send a message to the dedicated worker to offload fetch
                      // request from the host app.
                      PostMessageToWorker(dedicatedWorker);
                  }

                  return S_OK;
              })
              .Get(),
          &m_dedicatedWorkerCreatedToken));
    }
```

## Service Worker
## Monitoring the Registration/Destruction of Service Workers

The following example demonstrates how to subscribe to the event that is raised
when a web page registers a service worker. This event provides a
`CoreWebView2ServiceWorkerRegistration` object, enabling the host application to
interact with the service workers via upcoming PostMessage and
WorkerMessageReceived APIs.

## .NET/WinRT
```c#
    void PostMessageToWorker(CoreWebView2ServiceWorker worker)
    {
        // The service worker communicates updates back to the host application,
        // such as when resource caching is complete. The host application can
        // listen for the WorkerMessageReceived event to receive these updates
        // from the service worker.
        worker.WorkerMessageReceived += (sender, args) =>
        {
            var message = args.TryGetWorkerMessageAsString();

            // Process the messages received from the worker. Depending on the
            // content of these messages, you might choose to log the data for
            // debugging, update the user interface to reflect changes, or raise
            // other actions within your application.
        };

        // You can post messages to the service worker using its PostMessage method.
        // In this sample, the host application is posting a message to the worker to
        // cache certain resources. The message is a JSON string that specifies the
        // type of the message and the payload of the message.
        worker.PostMessage("{ \"MyMessage\": { \"type\": \"CACHE_URLS\", \"payload\": [\"/styles/main.css\", \"/scripts/main.js\", \"/images/logo.png\"]} }");
    }

    void ServiceWorkerRegisteredExecuted(object target, ExecutedRoutedEventArgs e)
    {
        RegisterForServiceWorkerRegistered();
    }

    CoreWebView2ServiceWorkerManager ServiceWorkerManager_;
    void RegisterForServiceWorkerRegistered()
    {
        if (ServiceWorkerManager_ == nullptr)
        {
            ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
        }
        ServiceWorkerManager_.ServiceWorkerRegistered += (sender, args) =>
        {
            CoreWebView2ServiceWorkerRegistration serviceWorkerRegistration = args.ServiceWorkerRegistration;
            serviceWorkerRegistration.Unregistering += (sender2, args2) =>
            {
                /*Cleanup on worker destruction*/
            };

            LogMessage("Service worker has been registered with a scope: " + serviceWorkerRegistration.ScopeUri);

            CoreWebView2ServiceWorker serviceWorker = args.ActiveServiceWorker;

            // Check if there is already an active service worker and handle it
            if (serviceWorker != null)
            {
                // Send a list of resources to the service worker to cache.
                PostMessageToWorker(serviceWorker);
            }
            else
            {
                serviceWorkerRegistration.ServiceWorkerActivated += (sender3, args3) =>
                {
                    CoreWebView2ServiceWorker serviceWorker = args3.ActiveServiceWorker;
                    serviceWorker.Destroying += (sender4, args4) =>
                    {
                            /*Cleanup on worker destruction*/
                    };

                    // Send a list of resources to the service worker to cache.
                    PostMessageToWorker(serviceWorker);
                }
            }
        };
    }
```
## Win32 C++
```cpp

    void PostMessageToWorker(wil::com_ptr<ICoreWebView2ServiceWorker> worker)
    {
        // The service worker communicates updates back to the host application,
        // such as when resource caching is complete. The host application can
        // listen for the WorkerMessageReceived event to receive these updates
        // from the service worker.
        CHECK_FAILURE(worker->add_WorkerMessageReceived(
                            Callback<ICoreWebView2ServiceWorkerMessageReceivedEventHandler>(
                                [this](ICoreWebView2ServiceWorker* sender,
                                ICoreWebView2ServiceWorkerMessageReceivedEventArgs* args)
                                noexcept -> HRESULT
                                {
                                    wil::unique_cotaskmem_string message;
                                    CHECK_FAILURE(args->TryGetWorkerMessageAsString(&message));

                                    // Process the messages received from the worker.
                                    // Depending on the content of these messages,
                                    // you might choose to log the data for debugging,
                                    // update the user interface to reflect changes,
                                    // or raise other actions within your application.

                                    return S_OK;
                                })
                                .Get(),
                            nullptr));

        // You can post messages to the service worker using its PostMessage method.
        // In this sample, the host application is posting a message to the worker
        // to cache certain resources. The message is a JSON string that specifies
        // the type of the message and the payload of the message.
        CHECK_FAILURE(worker->PostMessage(L"{ \"MyMessage\": {\"type\": \"CACHE_URLS\", \"payload\": [\"/styles/main.css\", \"/scripts/main.js\", \"/images/logo.png\"]} }"));
    }

    void ScenarioServiceWorkerManager::CreateServiceWorkerManager()
    {
        auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
        CHECK_FEATURE_RETURN_EMPTY(webView2_13);

        wil::com_ptr<ICoreWebView2Profile> webView2Profile;
        CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
        auto webViewprofile2 = webView2Profile.try_query<ICoreWebView2Profile2>();
        CHECK_FEATURE_RETURN_EMPTY(webViewprofile2);
        CHECK_FAILURE(webViewprofile2->get_ServiceWorkerManager(&m_serviceWorkerManager));
    }

    void ScenarioServiceWorkerManager::SetupEventsOnWebview()
    {
      CHECK_FAILURE(m_serviceWorkerManager->add_ServiceWorkerRegistered(
          Microsoft::WRL::Callback<ICoreWebView2ServiceWorkerRegisteredEventHandler>(
              [this](
                  ICoreWebView2ServiceWorkerManager* sender,
                  ICoreWebView2ServiceWorkerRegisteredEventArgs* args) noexcept
              {
                  wil::com_ptr<ICoreWebView2ServiceWorkerRegistration>
                      serviceWorkerRegistration;
                  CHECK_FAILURE(args->get_ServiceWorkerRegistration(&serviceWorkerRegistration));

                  if(serviceWorkerRegistration)
                  {
                    // Subscribe to worker registration unregistering event
                    CHECK_FAILURE(serviceWorkerRegistration->add_Unregistering(
                      Callback<ICoreWebView2ServiceWorkerRegistrationUnregisteringEventHandler>(
                          [this](
                              ICoreWebView2ServiceWorkerRegistration* sender2,
                              IUnknown* args2) -> HRESULT
                          {
                              /*Cleanup on worker registration destruction*/
                              return S_OK;
                          })
                          .Get(),
                    nullptr));

                    wil::unique_cotaskmem_string scopeUri;
                    CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));

                    wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker;
                    CHECK_FAILURE(args->get_ActiveServiceWorker(&serviceWorker));

                    // Check if there is already an active service worker and handle it
                    if(serviceWorker != nullptr)
                    {
                       // Send a list of resources to the service worker to cache.
                       PostMessageToWorker(serviceWorker);
                    }
                    else
                    {
                      CHECK_FAILURE(serviceWorkerRegistration->add_ServiceWorkerActivated(
                      Callback<ICoreWebView2ServiceWorkerActivatedEventHandler>(
                          [this](
                              ICoreWebView2ServiceWorkerRegistration* sender3,
                              ICoreWebView2ServiceWorkerActivatedEventArgs* args3)
                              noexcept -> HRESULT
                          {
                              wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker;
                              CHECK_FAILURE(args3->get_ActiveServiceWorker(&serviceWorker));

                              // Subscribe to worker destroying event
                              CHECK_FAILURE(serviceWorker->add_Destroying(
                                      Callback<
                                          ICoreWebView2ServiceWorkerDestroyingEventHandler>(
                                          [this](
                                              ICoreWebView2ServiceWorker* sender4,
                                              IUnknown* args4) -> HRESULT
                                          {
                                              /*Cleanup on worker destruction*/
                                              return S_OK;
                                          })
                                          .Get(),
                                      nullptr));

                                  // Send a list of resources to the service worker to cache.
                                  PostMessageToWorker(serviceWorker);

                              return S_OK;
                          })
                          .Get(), nullptr));
                    }

                    LogMessage(L"Service worker has been registered with a scope:  " + std::wstring(scopeUri.get()));
                  }

                  return S_OK;
              })
              .Get(),
          &m_serviceWorkerRegisteredToken));
    }
```

## Retrieving Service Worker Registrations.
The following example below illustrates how to retrieve and present details
about all service worker registrations linked to the WebView2 profile. This
yields a list of `CoreWebView2ServiceWorkerRegistration` objects, enabling the
host application to communicate directly with the service workers via post
messaging.

## .NET/WinRT
```c#
    void GetServiceWorkerRegistrationsExecuted(object target, ExecutedRoutedEventArgs e)
    {
        GetServiceWorkerRegistrations();
    }
    async void GetServiceWorkerRegistrations()
    {
        if (ServiceWorkerManager_ == null)
        {
            ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
        }
        IReadOnlyList<CoreWebView2ServiceWorkerRegistration> registrationList = await
        ServiceWorkerManager_.GetServiceWorkerRegistrationsAsync();

        int registrationCount = registrationList.Count;
        StringBuilder messageBuilder = new StringBuilder();
        messageBuilder.AppendLine($"No of service workers registered: {registrationCount}");

        foreach (var registration in registrationList)
        {
            var scopeUri = registration.ScopeUri;

            messageBuilder.AppendLine($"Scope: {scopeUri}");
        };

        LogMessage(messageBuilder.ToString());
    }
```
## Win32 C++
```cpp
    void ScenarioServiceWorkerManager::GetAllServiceWorkerRegistrations()
    {
        if (!m_serviceWorkerManager)
        {
            CreateServiceWorkerManager();
        }
        CHECK_FAILURE(m_serviceWorkerManager->GetServiceWorkerRegistrations(
            Callback<ICoreWebView2GetServiceWorkerRegistrationsCompletedHandler>(
                [this](
                    HRESULT error, ICoreWebView2ServiceWorkerRegistrationCollectionView*
                                      workerRegistrationCollection)
                    noexcept -> HRESULT
                {
                  CHECK_FAILURE(error);
                  if(workerRegistrationCollection)
                  {
                      UINT32 workersCount = 0;
                      CHECK_FAILURE(workerRegistrationCollection->get_Count(&workersCount));

                      std::wstringstream message{};
                      message << L"No of service workers registered: " << workersCount << std::endl;

                      for (UINT32 i = 0; i < workersCount; i++)
                      {
                          Microsoft::WRL::ComPtr<ICoreWebView2ServiceWorkerRegistration>
                              serviceWorkerRegistration;
                          CHECK_FAILURE(workerRegistrationCollection->GetValueAtIndex(
                              i, &serviceWorkerRegistration));

                          wil::unique_cotaskmem_string scopeUri;
                          CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));

                          message << L"Scope: " << scopeUri.get();
                      }

                      LogMessage(std::wstring(message.str()));
                  }

                    return S_OK;
                })
                .Get()));
    }
```

## Retrieving Service Worker Registration for a Specific Scope.

The following example illustrates how to retrieve the
`CoreWebView2ServiceWorkerRegistration` associated with a specific scope. This
enables the host application to establish a communication channel with the
service worker, facilitating the exchange of messages.

## .NET/WinRT
```c#
    void GetServiceWorkerRegisteredForScopeExecuted(object target, ExecutedRoutedEventArgs e)
    {
        GetServiceWorkerRegisteredForScope();
    }

    async void GetServiceWorkerRegisteredForScope()
    {
        var dialog = new TextInputDialog(
            title: "Scope of the Service Worker Registration",
            description: "Specify a scope uri to get the service worker",
            defaultInput: "");

       var dialogResult = await ShowDialogAsync(dialog);

        if (dialogResult == true)
        {
            if (ServiceWorkerManager_ == null)
            {
                ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
            }
            // The 'ScopeUri' should be a fully qualified URI. For example, if a site
            // registers a service worker with a 'scope' of '/app/' for an application
            // at https://example.com/, you should specify the fully qualified URI, i.e.,
            // https://example.com/app/, when calling this method.
            // Provided `scopeUri` will be normalized so ASCII characters
            // in the scheme and hostname will be lowercased, and non-ASCII characters
            // in the hostname will be normalized to their punycode form for comparision.
            CoreWebView2ServiceWorkerRegistration registration = await
            ServiceWorkerManager_.GetServiceWorkerRegistrationAsync(dialog.Input.Text);

            if(registration != null)
            {
                CoreWebView2ServiceWorker worker = registration.ActiveServiceWorker;
                if(worker != null)
                {
                    LogMessage("Service worker for scope " + dialog.Input.Text + " fetched successfully");
                } else
                {
                    LogMessage("No active service worker available");
                }
            } else
            {
                  LogMessage("No service worker registered for " + dialog.Input.Text);
            }
        }
    }
```
## Win32 C++
```cpp
    void ScenarioServiceWorkerManager::GetServiceWorkerRegisteredForScope()
    {
        if (!m_serviceWorkerManager)
        {
            CreateServiceWorkerManager();
        }

        TextInputDialog dialog(
            m_appWindow->GetMainWindow(), L"Service Worker", L"Scope:",
            L"Specify a scope uri to get the service worker", L"");

        if (dialog.confirmed)
        {
            // The 'ScopeUri' should be a fully qualified URI. For example, if a site
            // registers a service worker with a 'scope' of '/app/' for an application
            // at https://example.com/, you should specify the fully qualified URI, i.e.,
            // https://example.com/app/, when calling this method.
            // Provided `scopeUri` will be normalized so ASCII characters
            // in the scheme and hostname will be lowercased, and non-ASCII characters
            // in the hostname will be normalized to their punycode form for comparision.
            CHECK_FAILURE(m_serviceWorkerManager->GetServiceWorkerRegistration(
                dialog.input.c_str(),
                Callback<ICoreWebView2GetServiceWorkerRegistrationCompletedHandler>(
                    [this](
                        HRESULT error,
                        ICoreWebView2ServiceWorkerRegistration* serviceWorkerRegistration)
                        noexcept -> HRESULT
                    {
                        CHECK_FAILURE(error);
                        if(serviceWorkerRegistration)
                        {
                            wil::unique_cotaskmem_string scopeUri;
                            CHECK_FAILURE(serviceWorkerRegistration->get_ScopeUri(&scopeUri));

                            wil::com_ptr<ICoreWebView2ServiceWorker> serviceWorker;
                            CHECK_FAILURE(serviceWorkerRegistration->get_ActiveServiceWorker(&serviceWorker));
                            if (serviceWorker != nullptr)
                            {
                                wil::unique_cotaskmem_string scriptUri;
                                CHECK_FAILURE(serviceWorker->get_ScriptUri(&scriptUri));

                                LogMessage(L"Service worker for scope " + std::wstring(scopeUri.get()) +
                                L" fetched successfully from the script "
                                + std::wstring(ScriptUri.get()));
                            }
                            else
                            {
                                LogMessage(L"No service worker available");
                            }
                        }
                        else
                        {
                            LogMessage(L"No service worker registered for the scope: " + scopeUri);
                        }

                        return S_OK;
                    })
                    .Get()));
        }
    }
```

## Shared Worker
## Monitoring Shared Worker Creation and Destruction

The following example illustrates how the host application initiates a WebSocket
connection when a web page creates a shared worker, utilizing the Worker
upcoming PostMessage and WorkerMessageReceived APIs.

## .NET/WinRT
```c#
    void PostMessageToWorker(CoreWebView2SharedWorker worker)
    {
        // The shared worker communicates back to the host application with updates
        // from the WebSocket. The host application can monitor this event to receive
        // these updates from the shared worker.
        worker.WorkerMessageReceived += (sender, args) =>
        {
            var message = args.TryGetWorkerMessageAsString();

            // Record the updates from the WebSocket or modify the user interface
            // according to the requirements of the host application.
        };

        // Initiate the WebSocket connection by sending a message to the shared worker.
        worker.PostMessage("{ \"MyMessage\": {\"type\": \"INITIATE_WEBSOCKET_CONNECTION\", \"payload\": \"wss://example.com\"} }");
    }

    void SharedWorkerManagerExecuted(object target, ExecutedRoutedEventArgs e)
    {
         RegisterForSharedWorkerCreated();
    }

    CoreWebView2SharedWorkerManager SharedWorkerManager_;
    void RegisterForSharedWorkerCreated()
    {
        SharedWorkerManager_ = WebViewProfile.SharedWorkerManager;

        if(SharedWorkerManager_ != null)
        {
            SharedWorkerManager_.SharedWorkerCreated += (sender, args) =>
            {
                CoreWebView2SharedWorker sharedWorker = args.Worker;
                sharedWorker.Destroying += (sender, args) =>
                {
                  /*Cleanup on worker destruction*/
                };

                LogMessage("Shared Worker has been created with the script located at the " + sharedWorker.scriptUri);

                // You can utilizes a shared worker to maintain a WebSocket
                // connection, enabling real-time updates through the PostMessage API.
                // The shared worker establishes the WebSocket connection, receives
                // real-time updates, and forwards these updates back to the host application.
                PostMessageToWorker(sharedWorker);
            };
        }
    }
```
## Win32 C++
```cpp
    void PostMessageToWorker(wil::com_ptr<ICoreWebView2SharedWorker> worker)
    {
        // The shared worker communicates back to the host application with
        // updates from the WebSocket. The host application can monitor this
        // event to receive these updates from the shared worker.
        CHECK_FAILURE(worker->add_WorkerMessageReceived(
                            Callback<ICoreWebView2SharedWorkerMessageReceivedEventHandler>(
                                [this](ICoreWebView2SharedWorker* sender,
                                ICoreWebView2SharedWorkerMessageReceivedEventArgs* args)
                                noexcept -> HRESULT
                                {
                                    wil::unique_cotaskmem_string message;
                                    CHECK_FAILURE(args->TryGetWorkerMessageAsString(&message));

                                    // Record the updates from the WebSocket or
                                    // modify the user interface according to the
                                    // requirements of the host application.
                                    return S_OK;
                                })
                                .Get(),
                            nullptr));


        // Initiate the WebSocket connection by sending a message to the shared worker.
        CHECK_FAILURE(worker->PostMessage(L"{ \"MyMessage\": {\"type\": \"INITIATE_WEBSOCKET_CONNECTION\", \"payload\": \"wss://example.com\"} }"));
    }

    void ScenarioSharedWorkerManager::GetSharedWorkerManager()
    {
      auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
      CHECK_FEATURE_RETURN_EMPTY(webView2_13);

      wil::com_ptr<ICoreWebView2Profile> webView2Profile;
      CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
      auto webViewprofile2 = webView2Profile.try_query<ICoreWebView2Profile2>();
      CHECK_FEATURE_RETURN_EMPTY(webViewprofile2);
      CHECK_FAILURE(webViewprofile2->get_SharedWorkerManager(&m_sharedWorkerManager));
    }

    void ScenarioSharedWorkerManager::SetupEventsOnWebview()
    {
      CHECK_FAILURE(m_sharedWorkerManager->add_SharedWorkerCreated(
          Microsoft::WRL::Callback<ICoreWebView2SharedWorkerCreatedEventHandler>(
              [this](
                  ICoreWebView2SharedWorkerManager* sender,
                  ICoreWebView2SharedWorkerCreatedEventArgs* args) noexcept
              {
                  wil::com_ptr<ICoreWebView2SharedWorker> sharedWorker;
                  CHECK_FAILURE(args->get_Worker(&sharedWorker));

                if (sharedWorker)
                {
                    wil::unique_cotaskmem_string scriptUri;
                    CHECK_FAILURE(sharedWorker->get_ScriptUri(&scriptUri));

                    // Subscribe to worker destroying event
                    sharedWorker->add_Destroying(
                        Callback<ICoreWebView2SharedWorkerDestroyingEventHandler>(
                            [](
                                ICoreWebView2SharedWorker* sender,
                                IUnknown* args) -> HRESULT
                            {
                                /*Cleanup on worker destruction*/
                                return S_OK;
                            })
                            .Get(),
                        nullptr);


                    LogMessage(L"Shared Worker has been created with the script located at the " + std::wstring(scriptUri.get()));

                    // The host application leverages a shared worker to sustain
                    // a WebSocket connection, facilitating real-time updates.
                    // The initiation of the WebSocket connection is raised by a
                    // message from the host app to the shared worker via the
                    // PostMessage API. The shared worker then establishes the
                    // WebSocket connection, receives real-time updates, and
                    // relays these updates back to the host application.
                    PostMessageToWorker(sharedWorker);
                }

                return S_OK;
              })
              .Get(),
          &m_sharedWorkerCreatedToken));
    }
```

## Retrieving Shared Workers

The following example demonstrates how to query `CoreWebView2SharedWorkers`
associated with the WebView2 profile for the host app to interact with workers
based on the app needs. Host app can directly talk to shared worker using
CoreWebView2SharedWorker.

## .NET/WinRT
```c#
    void GetSharedWorkersExecuted(object target, ExecutedRoutedEventArgs e)
    {
        GetSharedWorkers();
    }

    async void GetSharedWorkers()
    {
        if (SharedWorkerManager_ == null)
        {
            SharedWorkerManager_ = WebViewProfile.SharedWorkerManager;
        }

        // Creates an instance of CoreWebView2SharedWorker which can be used
        // to communicate with the worker
        IReadOnlyList<CoreWebView2SharedWorker> workerList = await
        SharedWorkerManager_.GetSharedWorkersAsync();

        StringBuilder messageBuilder = new StringBuilder();
        messageBuilder.AppendLine($"No of shared  workers created: {workerList.Count}");

        foreach (var worker in workerList)
        {
            var stringUri = worker.ScriptUri;

            messageBuilder.AppendLine($"ScriptUri: {ScriptUri}");
        };

        LogMessage(messageBuilder.ToString());
    }
```
## Win32 C++
```cpp
  void ScenarioSharedWorkerManager::GetAllSharedWorkers()
  {
    if (!m_sharedWorkerManager)
    {
        GetSharedWorkerManager();
    }
    CHECK_FAILURE(m_sharedWorkerManager->GetSharedWorkers(
        Callback<ICoreWebView2GetSharedWorkersCompletedHandler>(
            [this](
                HRESULT error,
                ICoreWebView2SharedWorkerCollectionView* workersCollection)
                noexcept -> HRESULT
            {
                CHECK_FAILURE(error);

                if(workersCollection)
                {
                    UINT32 workersCount = 0;
                    CHECK_FAILURE(workersCollection->get_Count(&workersCount));

                    std::wstringstream message{};
                    message << L"No of shared workers created: " << workersCount << std::endl;

                    for (UINT32 i = 0; i < workersCount; i++)
                    {
                        Microsoft::WRL::ComPtr<ICoreWebView2SharedWorker> sharedWorker;
                        CHECK_FAILURE(workersCollection->GetValueAtIndex(i, &sharedWorker));

                        if (sharedWorker)
                        {
                            wil::unique_cotaskmem_string scriptUri;
                            CHECK_FAILURE(sharedWorker->get_ScriptUri(&scriptUri));

                            message << L"ScriptUri: " << scriptUri.get();
                            message << std::endl;
                        }
                    }

                    LogMessage(L"Shared workers" + std::wstring(message.str()));
                }
              return S_OK;
            })
            .Get()));
  }
```
## Host Name Canonicalization

The host name used in the APIs is canonicalized using Chromium's host name parsing
logic before use. For more information, see [HTML5 2.6 URLs](https://dev.w3.org/html5/spec-LC/urls.html).

Canonicalization includes the following steps:
- ASCII characters in the scheme and hostname are lowercased.
- Non-ASCII characters in the hostname are normalized to their Punycode form.

# API Details
```
[uuid(29b994e5-0ac8-5430-89fa-5b4bb2091d8d), object, pointer_default(unique)]
interface ICoreWebView2_25 : IUnknown {
  /// Subscribe to this event that gets raised when a new dedicated worker is created.
  ///
  /// A Dedicated Worker is a type of web worker that allow you to run Javascript
  /// code in the background without blocking the main thread, making them useful
  /// for tasks like heavy computations, data processing, and parallel execution.
  /// It is "dedicated" because it is linked to a single parent document and cannot
  /// be shared with other scripts.
  ///
  /// This event is raised when a web application creates a dedicated worker using the
  /// `new Worker("/worker.js")` method. See the
  /// [Worker](https://developer.mozilla.org/docs/Web/API/Worker/Worker)
  /// for more information.
  HRESULT add_DedicatedWorkerCreated(
      [in] ICoreWebView2DedicatedWorkerCreatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DedicatedWorkerCreated`.
  HRESULT remove_DedicatedWorkerCreated(
      [in] EventRegistrationToken token);
}

/// Receives `DedicatedWorkerCreated` events.
[uuid(99c76d22-d2de-5b04-b8e5-07b27584da49), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorkerCreatedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2DedicatedWorkerCreatedEventArgs* args);
}

/// Event args for the `DedicatedWorkerCreated` event.
[uuid(4a122222-390e-5a65-809c-f043486db602), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorkerCreatedEventArgs : IUnknown {
  /// The dedicated worker that was created.
  [propget] HRESULT Worker([out, retval] ICoreWebView2DedicatedWorker** value);
}

/// Receives `Destroying` events.
[uuid(d3066b89-9039-5ffc-b594-f936773d5bc5), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorkerDestroyingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2DedicatedWorker* sender,
      [in] IUnknown* args);
}

[uuid(f233edb4-d9b4-5209-9abd-b7f50089464c), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorker : IUnknown {
  /// A string representing the Uri of the script that the worker is executing.
  ///
  /// The `scriptUri` is a fully qualified URI, including the scheme, host, and path.
  /// In contrast, the `scriptURL` property of the `Worker` object in the DOM returns the relative
  /// URL of the script being executed by the worker. For more details on DOM API, see the
  /// [DOM API documentation](https://developer.mozilla.org/docs/Web/API/Worker/scriptURL).
  ///
  /// Refer to the [Host Name Canonicalization](#host-name-canonicalization) section for
  /// details on how normalization is performed.
  /// The same process applies to the `scriptURL` when a worker is created from DOM API.
  /// The `scriptUri` property reflects this normalization, ensuring that the URL is standardized. For example:
  /// - `HTTPS://EXAMPLE.COM/worker.js` is canonicalized to `https://example.com/worker.js`.
  /// - `https://bücher.de/worker.js` is canonicalized to `https://xn--bcher-kva.de/worker.js`.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ScriptUri([out, retval] LPWSTR* value);

  /// Add an event handler for the `Destroying` event that is raised when the
  /// worker object is Destroying.
  ///
  /// A worker object is Destroying when the worker script is terminated or when
  /// the `CoreWebView2DedicatedWorker` object is Destroying.
  ///
  /// If the worker has already been destroyed before the event handler is registered,
  /// the handler will never be called.
  HRESULT add_Destroying(
      [in] ICoreWebView2DedicatedWorkerDestroyingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Destroying`.
  HRESULT remove_Destroying(
      [in] EventRegistrationToken token);
}


[uuid(ad6921d4-c416-5945-8437-2c97aeb76e6e), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : IUnknown {
  /// Get the service worker manager to monitor service worker registrations and
  /// interact with the service workers associated with the current profile.
  ///
  /// \snippet ScenarioServiceWorkerManager.cpp ServiceWorkerManager
  [propget] HRESULT ServiceWorkerManager([out, retval] ICoreWebView2ServiceWorkerManager** value);


  /// Get the shared worker manager to monitor shared worker creations and interact
  /// with the shared workers associated with the current profile.
  ///
  /// \snippet ScenarioSharedWorkerManager.cpp SharedWorkerManager
  [propget] HRESULT SharedWorkerManager([out, retval] ICoreWebView2SharedWorkerManager** value);
}

[uuid(4e07e562-8db7-5815-907b-6d89a253a974), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerManager : IUnknown {
  /// A ServiceWorker is a specific type of worker that takes a JavaScript file
  /// that can control the web-page/site that it is associated with,
  /// intercepting and modifying navigation and resource requests, and caching
  /// resources in a very granular fashion to give you complete control
  /// over how app behaves in certain situations.
  ///
  /// Service workers essentially act as proxy servers that sit between web applications,
  /// the browser, and the network (when available).
  /// Unlike Shared Workers, which have their own separate global scope, Service
  ///Workers have no DOM access and run in a different context.
  ///
  /// This event is raised when a web application registers a service worker using the
  /// `navigator.serviceWorker.register("/sw.js")` method. See the
  /// [Service Worker Registration](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration)
  /// for more information.
  ///
  ///
  /// \snippet ScenarioServiceWorkerManager.cpp ServiceWorkerRegistered
  HRESULT add_ServiceWorkerRegistered(
      [in] ICoreWebView2ServiceWorkerRegisteredEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_ServiceWorkerRegistered`.
  HRESULT remove_ServiceWorkerRegistered(
      [in] EventRegistrationToken token);


  /// Gets a list of the service worker registrations under the same profile.
  ///
  /// This method returns a list of `CoreWebView2ServiceWorkerRegistration` objects,
  /// each representing a service worker registration.
  ///
  /// This method corresponds to the `getRegistrations` method of the `ServiceWorkerContainer`
  /// object in the DOM which returns a Promise that resolves to an array of
  /// `ServiceWorkerRegistration` objects. See the [MDN documentation]
  /// (https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistrations) for more information.
  HRESULT GetServiceWorkerRegistrations(
      [in] ICoreWebView2GetServiceWorkerRegistrationsCompletedHandler* handler
  );

  /// Gets the service worker registration object associated with the specified scope.
  /// If a service worker has been registered for the given scope, it gets the
  /// corresponding `CoreWebView2ServiceWorkerRegistration` object otherwise returns
  /// nullptr.
  ///
  /// If the service worker is registered with a `scope` of '/app/' for an application
  /// at https://example.com/, you should specify the full qualified URI i.e.,
  /// https://example.com/app/ when calling this method. If the scope was not explicitly
  /// specified during registration, you should use the directory where the service worker
  /// script resides, for example, https://example.com/app/.
  ///
  /// Refer to the [Host Name Canonicalization](#host-name-canonicalization) section for
  /// details on how provided `scriptUri` normalization is performed. For example, `HTTPS://münchen.de/`
  /// will be normalized to `https://www.xn--kfk.com` for comparison.
  ///
  /// This corresponds to the `getRegistration` method of the `ServiceWorkerContainer`
  /// object in the DOM which returns a Promise that resolves to a `ServiceWorkerRegistration`
  /// object. See the [MDN documentation]
  /// (https://developer.mozilla.org/docs/Web/API/ServiceWorkerContainer/getRegistration) for more information.
  ///
  /// If scopeUri is empty string or null or invalid, the completed handler immediately returns
  /// `E_INVALIDARG` and with a null pointer.
  HRESULT GetServiceWorkerRegistration(
      [in] LPCWSTR scopeUri
      , [in] ICoreWebView2GetServiceWorkerRegistrationCompletedHandler* handler
  );
}

/// Receives the result of the `GetServiceWorkerRegistrations` method.
[uuid(3c29552b-7ee2-5904-baf3-a0720e1538a5), object, pointer_default(unique)]
interface ICoreWebView2GetServiceWorkerRegistrationsCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ServiceWorkerRegistrationCollectionView* result);
}

/// Receives the result of the `GetServiceWorkerRegistration` method.
[uuid(e5b37473-5833-5ec1-b57e-ccbbbc099a32), object, pointer_default(unique)]
interface ICoreWebView2GetServiceWorkerRegistrationCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ServiceWorkerRegistration* result);
}

/// Receives `ServiceWorkerRegistered` events.
[uuid(81262ddf-ef6c-5184-8ae0-01fa0a4c86c7), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegisteredEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorkerManager* sender,
      [in] ICoreWebView2ServiceWorkerRegisteredEventArgs* args);
}

/// Event args for the `ServiceWorkerRegistered` event.
[uuid(a18bd62a-8246-5d2b-abc5-2bdbbc13767b), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegisteredEventArgs : IUnknown {
  /// The service worker that was registered.
  HRESULT GetServiceWorkerRegistration(
      [out, retval] ICoreWebView2ServiceWorkerRegistration** value
  );
}

/// A collection of ICoreWebView2ServiceWorkerRegistration.
[uuid(9860773f-16e5-5521-9bc2-a6d8e5347d4a), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistrationCollectionView : IUnknown {
  /// The number of elements contained in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the element at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index, [out, retval] ICoreWebView2ServiceWorkerRegistration** value);
}

/// Receives `Unregistering` events.
[uuid(9d79117e-4e96-5a53-9933-d7a31d0106ae), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistrationUnregisteringEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorkerRegistration* sender,
      [in] IUnknown* args);
}

[uuid(0c0b03bd-ced2-5518-851a-3d3f71fb5c4b), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistration : IUnknown {
  /// The `scopeUri` is a fully qualified URI, including the scheme, host and path,
  /// that specifies the range of URLs a service worker can control.
  ///
  /// When registering a service worker, if no scope is specified, it defaults to the
  /// directory of the service worker script resides. For example, if the script is
  /// located at https://example.com/app/sw.js, the default `scopeUri` would be
  /// https://example.com/app/. However, if a scope is provided, it is defined relative
  /// to the application's base URI. For instance, if an application at
  /// https://example.com/ registers a service worker with a scope of /app/, the resulting
  /// `scopeUri` is https://example.com/app/.
  ///
  /// Refer to the [Host Name Canonicalization](#host-name-canonicalization) section for
  /// details on how normalization is performed.
  /// The same process applies to the `Scope` when a service worker is registered from DOM API.
  /// The `scopeUri` property reflects this normalization, ensuring that the URI is standardized. For example:
  /// - `HTTPS://EXAMPLE.COM/app/` is canonicalized to `https://example.com/app/`.
  /// - `https://bücher.de/` is canonicalized to `https://xn--bcher-kva.de/`.
  ///
  /// The `scope` property of the `ServiceWorkerRegistration` object in the DOM returns
  /// the relative URL based on the application's base URI, while this property always
  /// returns a fully qualified URI.  For more information on DOM API, see the
  /// [MDN documentation](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/scope).
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ScopeUri([out, retval] LPWSTR* value);

  /// Adds an event handler for the `ServiceWorkerActivated` event.
  ///
  /// This event is raised when a service worker is activated. A service worker is
  /// activated when its script has been successfully registered and it is ready to
  /// control the pages within the scope of the registration.
  ///
  /// This event is also raised when an updated version of a service worker reaches the active state.
  /// In such a case, the existing CoreWebView2ServiceWorker object is destroying, and this event is
  /// raised with a new CoreWebView2ServiceWorker object representing the updated service worker.
  /// The active service worker is the one that receives fetch and message events for the pages it controls.
  /// See the [Service Worker](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/active)
  /// documentation for more information.
  ///
  /// If you register for the `ServiceWorkerActivated` event and the registration already
  /// has an active worker, the event handler is not called immediately. Instead, it waits
  /// for the next activation event to occur. Therefore, you should first check if an active
  /// service worker is running by using the `ActiveServiceWorker` property.
  HRESULT add_ServiceWorkerActivated(
      [in] ICoreWebView2ServiceWorkerActivatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_ServiceWorkerActivated`.
  HRESULT remove_ServiceWorkerActivated(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `Unregistering` event that is raised when the worker registration is
  /// unregistered using the JS api `registration.unregister()`. See the
  /// [Unregister](https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/unregister)
  /// for more information.

  HRESULT add_Unregistering(
      [in] ICoreWebView2ServiceWorkerRegistrationUnregisteringEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Unregistering`.
  HRESULT remove_Unregistering(
      [in] EventRegistrationToken token);


  /// The active service worker that was created. If there is no active service worker,
  /// it returns a null pointer.
  /// The active service worker is the service worker that controls the pages within
  /// the scope of the registration. See the [Service Worker]
  /// (https://developer.mozilla.org/docs/Web/API/ServiceWorker) for more information.
  ///
  /// This corresponds to the `active` property of the `ServiceWorkerRegistration` object in the DOM.
  /// For more information, see the [MDN documentation]
  /// (https://developer.mozilla.org/docs/Web/API/ServiceWorkerRegistration/active).
  [propget] HRESULT ActiveServiceWorker([out, retval] ICoreWebView2ServiceWorker** value);
}

/// Receives `ServiceWorkerActivated` events.
[uuid(0f383156-1a08-52d4-81b0-a626484aac40), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerActivatedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorkerRegistration* sender,
      [in] ICoreWebView2ServiceWorkerActivatedEventArgs* args);
}

/// Event args for the `ServiceWorkerActivated` event.
[uuid(5685c4b6-a514-58b2-9721-b61ef4ccd9d8), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerActivatedEventArgs : IUnknown {
  /// The service worker that was activated.
  [propget] HRESULT ActiveServiceWorker([out, retval] ICoreWebView2ServiceWorker** value);
}

/// Receives `Destroying` events.
[uuid(f514c5e7-27f3-5dd8-aa1c-04e053177edd), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerDestroyingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorker* sender,
      [in] IUnknown* args);
}

[uuid(de8ed42b-5128-55df-9dd0-ea1d4d706c87), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorker : IUnknown {
  /// A string representing the Uri of the script that the worker is executing.
  ///
  /// The `scriptUri` is a fully qualified URI, including the scheme, host, and path.
  /// In contrast, the `scriptURL` property of the `Worker` object in the DOM returns the relative
  /// URL of the script being executed by the worker. For more details on DOM API, see the
  /// [DOM API documentation](https://developer.mozilla.org/docs/Web/API/Worker/scriptURL).
  ///
  /// Refer to the [Host Name Canonicalization](#host-name-canonicalization) section for
  /// details on how normalization is performed.
  /// The same process applies to the `scriptURL` when a worker is registered from DOM API.
  /// The `scriptUri` property reflects this normalization, ensuring that the URL is standardized. For example:
  /// - `HTTPS://EXAMPLE.COM/worker.js` is canonicalized to `https://example.com/worker.js`.
  /// - `https://bücher.de/worker.js` is canonicalized to `https://xn--bcher-kva.de/worker.js`.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ScriptUri([out, retval] LPWSTR* value);

  /// Add an event handler for the `Destroying` event that is raised when the
  /// worker object is Destroying.
  ///
  /// A worker object is Destroying when the worker script is terminated or when
  /// the `CoreWebView2ServiceWorker` object is Destroying.
  ///
  /// If the worker has already been destroyed before the event handler is registered,
  /// the handler will never be called.
  HRESULT add_Destroying(
      [in] ICoreWebView2ServiceWorkerDestroyingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Destroying`.
  HRESULT remove_Destroying(
      [in] EventRegistrationToken token);
}

[uuid(9b897103-d035-551f-892e-3e8f2916d03e), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerManager : IUnknown {
  /// Add an event handler for the `SharedWorkerCreated` event.
  ///
  /// A SharedWorker is a specific type of worker that can be accessed from several
  /// browsing contexts, such as multiple windows, iframes, or even other workers.
  /// Unlike Dedicated Workers, which have their own separate global scope, SharedWorkers
  /// share a common global scope called SharedWorkerGlobalScope.
  ///
  /// This event is raised when a web application creates a shared worker using the
  /// `new SharedWorker("worker.js")` method. See the
  /// [Shared Worker](https://developer.mozilla.org/docs/Web/API/SharedWorker)
  /// for more information.
  ///
  /// \snippet ScenarioSharedWorkerManager.cpp SharedWorkerCreated
  HRESULT add_SharedWorkerCreated(
      [in] ICoreWebView2SharedWorkerCreatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_SharedWorkerCreated`.
  HRESULT remove_SharedWorkerCreated(
      [in] EventRegistrationToken token);

  /// Gets a list of the shared workers created under the same profile.
  HRESULT GetSharedWorkers(
      [in] ICoreWebView2GetSharedWorkersCompletedHandler* handler
  );
}

/// Event args for the `SharedWorkerCreated` event.
[uuid(9f6615b0-08f1-5baa-9c95-a02a1dc56d3f), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerCreatedEventArgs : IUnknown {
  /// The shared worker that was created.
  [propget] HRESULT Worker([out, retval] ICoreWebView2SharedWorker** value);
}

/// Receives the result of the `GetSharedWorkers` method.
[uuid(1f3179ae-15e5-51e4-8583-be0caf85adc7), object, pointer_default(unique)]
interface ICoreWebView2GetSharedWorkersCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2SharedWorkerCollectionView* result);
}

/// Receives `SharedWorkerCreated` events.
[uuid(79cb8524-b842-551a-8d31-5f824b6955ed), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerCreatedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2SharedWorkerManager* sender,
      [in] ICoreWebView2SharedWorkerCreatedEventArgs* args);
}

/// A collection of ICoreWebView2SharedWorker.
[uuid(f8842b09-0108-5575-a965-3d76fd267050), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerCollectionView : IUnknown {
  /// The number of elements contained in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the element at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index, [out, retval] ICoreWebView2SharedWorker** value);
}

/// Receives `Destroying` events.
[uuid(fa58150a-5b67-5069-a82e-5606f9f61a67), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerDestroyingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2SharedWorker* sender,
      [in] IUnknown* args);
}

[uuid(876f8390-f9a8-5264-9677-985d8453aeab), object, pointer_default(unique)]
interface ICoreWebView2SharedWorker : IUnknown {
  /// A string representing the Uri of the script that the worker is executing.
  ///
  /// The `scriptUri` is a fully qualified URI, including the scheme, host, and path.
  /// In contrast, the `scriptURL` property of the `Worker` object in the DOM returns the relative
  /// URL of the script being executed by the worker. For more details on DOM API, see the
  /// [DOM API documentation](https://developer.mozilla.org/docs/Web/API/Worker/scriptURL).
  ///
  /// Refer to the [Host Name Canonicalization](#host-name-canonicalization) section for
  /// details on how normalization is performed.
  /// The same process applies to the `scriptURL` when a worker is created from DOM API.
  /// The `scriptUri` property reflects this normalization, ensuring that the URL is standardized. For example:
  /// - `HTTPS://EXAMPLE.COM/worker.js` is canonicalized to `https://example.com/worker.js`.
  /// - `https://bücher.de/worker.js` is canonicalized to `https://xn--bcher-kva.de/worker.js`.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ScriptUri([out, retval] LPWSTR* value);

  /// Add an event handler for the `Destroying` event that is raised when the
  /// worker object is Destroying.
  ///
  /// A worker object is Destroying when the worker script is terminated or when
  /// the `CoreWebView2SharedWorker` object is Destroying.
  ///
  /// If the worker has already been destroyed before the event handler is registered,
  /// the handler will never be called.
  HRESULT add_Destroying(
      [in] ICoreWebView2SharedWorkerDestroyingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Destroying`.
  HRESULT remove_Destroying(
      [in] EventRegistrationToken token);
}
```

```c# (but really MIDL3)
runtimeclass CoreWebView2DedicatedWorkerCreatedEventArgs;
runtimeclass CoreWebView2DedicatedWorker;
runtimeclass CoreWebView2ServiceWorkerRegistration;
runtimeclass CoreWebView2ServiceWorkerRegisteredEventArgs;
runtimeclass CoreWebView2ServiceWorkerManager;
runtimeclass CoreWebView2ServiceWorker;
runtimeclass CoreWebView2SharedWorkerManager;
runtimeclass CoreWebView2SharedWorkerCreatedEventArgs;
runtimeclass CoreWebView2SharedWorker;

namespace Microsoft.Web.WebView2.Core
{
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_25")]
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DedicatedWorkerCreatedEventArgs> DedicatedWorkerCreated;
    }

    // ...
    runtimeclass CoreWebView2DedicatedWorkerCreatedEventArgs
    {
        CoreWebView2DedicatedWorker Worker { get; };
    }

    runtimeclass CoreWebView2DedicatedWorker
    {
        String ScriptUri { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2DedicatedWorker, IInspectable> Destroying;
    }

    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile9")]
    {
        CoreWebView2ServiceWorkerManager ServiceWorkerManager { get; };

        CoreWebView2SharedWorkerManager SharedWorkerManager { get; };
    }

    runtimeclass CoreWebView2ServiceWorkerManager
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerManager, CoreWebView2ServiceWorkerRegisteredEventArgs> ServiceWorkerRegistered;

        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ServiceWorkerRegistration>> GetServiceWorkerRegistrationsAsync();

        Windows.Foundation.IAsyncOperation<CoreWebView2ServiceWorkerRegistration> GetServiceWorkerRegistrationAsync(String scopeUri);
    }

    runtimeclass CoreWebView2ServiceWorkerRegisteredEventArgs
    {
        CoreWebView2ServiceWorkerRegistration ServiceWorkerRegistration { get; };
    }

    runtimeclass CoreWebView2ServiceWorkerRegistration
    {
        String ScopeUri { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerRegistration, IInspectable> Unregistering;

        CoreWebView2ServiceWorker ActiveServiceWorker { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerRegistration, CoreWebView2ServiceWorkerActivatedEventArgs> ServiceWorkerActivated;
    }

    runtime CoreWebView2ServiceWorkerActivatedEventArgs
    {
        CoreWebView2ServiceWorker ActiveServiceWorker { get; };
    }

    runtimeclass CoreWebView2ServiceWorker
    {
        String ScriptUri { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorker, IInspectable> Destroying;
    }

    runtimeclass CoreWebView2SharedWorkerManager
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2SharedWorkerManager, CoreWebView2SharedWorkerCreatedEventArgs> SharedWorkerCreated;

        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2SharedWorker>> GetSharedWorkersAsync();
    }

    runtimeclass CoreWebView2SharedWorkerCreatedEventArgs
    {
        CoreWebView2SharedWorker Worker { get; };
    }

    runtimeclass CoreWebView2SharedWorker
    {
        String ScriptUri { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2SharedWorker, IInspectable> Destroying;
    }
}
```
