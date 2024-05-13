Workers support in WebView2
===

# Background
Currently, WebView2 lacks comprehensive APIs for developers to fully utilize workers, leading to increased load on the main thread, offloading to native, or forking their web app for WebView2 scenarios. To address this, the WebView2 team is introducing support for worker scenarios. This enhancement allows WebView2 users to interact with Web Workers from native apps, bypassing the JavaScript thread to boost app performance and responsiveness, or to run tasks in the background for offline support, push notifications, background sync, content updates, and more. As a part of the work, the WebView2 team is adding support for [Dedicated Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API), [Shared Workers](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker), and [Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API). While there are various types of web workers, our initial focus is on these three, with plans to broaden our support for other workers in the future.

**What is Web Worker?**
[Web Workers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API) allow web content to execute scripts in background threads, enabling tasks to run independently of the user interface and facilitating communication between threads using message passing. Web Workers can also make network requests using fetch() or XMLHttpRequest APIs. Few examples of workers are

- **Dedicated Worker**: Dedicated Workers are a type of Web Worker that operates independently in the background of a web page, enabling parallel execution of tasks without blocking the main UI thread. They are created by specific web pages and communicate with them via message passing, making them ideal for offloading CPU-intensive operations and improving overall performance and responsiveness of web applications.

- **Shared Worker**: Shared Workers are a type of Web Worker that can be accessed by multiple scripts running in different windows, IFrames, or other contexts, as long as they are within the same domain as the worker. Unlike Dedicated Workers, which are tied to a specific web page, Shared Workers require communication via an active port, making them slightly more complex to implement but enabling collaboration and shared resources across different parts of a web application.

- **Service Worker**: Service Workers serve as intermediary agents between web applications, the browser, and the network, functioning as proxy servers. Primarily, they facilitate the development of seamless offline experiences by caching resources and enabling web apps to continue functioning without an internet connection. Additionally, Service Workers intercept network requests, enabling customized responses based on network availability, and can update server-side assets. Moreover, they grant access to push notifications and background sync APIs, enhancing the functionality and interactivity of web applications.

# Description

We propose the introduction of APIs that enable the host application to oversee workers. These APIs lay the groundwork for the development of additional APIs, facilitating direct interaction between the host application and the workers, and support background operations for service workers.

**DedicatedWorkerCreated**: This event, associated with CoreWebView2, is triggered when a web page initiates a dedicated worker. It grants access to the CoreWebView2DedicatedWorker object, which contains information such as the script URL and name. Additionally, it provides a 'destroy' event that is fired just before this object is due for destruction.

**ServiceWorkerRegistered**: This event, originating from the CoreWebView2ServiceWorkerManager assicoated with CoreWebView2Profile is triggered when a service worker is successfully registered within the context of a WebView2 application for the profile. This event provides access to a CoreWebView2ServiceWorkerRegistration object, which encapsulates information about the registered service worker, such as its script URL and scope. Additionally, it enables subscription to the service worker's lifecycle events, including updates and unregistration.

**GetServiceWorkerRegistrations**: The GetServiceWorkerRegistrations method, part of the CoreWebViewServiceWorkerManager class, is used to retrieve all service worker registrations within the context of a WebView2 application for the profile. This method gives a collection of CoreWebView2ServiceWorkerRegistration objects, each encapsulating information about a registered service worker, such as its script URL and scope.

**GetServiceWorkerRegistration**: The GetServiceWorkerRegistration method, part of the CoreWebViewServiceWorkerManager class, is used to retrieve a specific service worker registration within the context of a WebView2 application for the profile. This asynchronous method takes a scope as an argument and returns a CoreWebView2ServiceWorkerRegistration object that encapsulates information about the registered service worker with the given scope, such as its script URL. This method is useful for accessing details of a specific service worker based on its scope.

**SharedWorkerCreated**: This event, originating from the CoreWebView2SharedWorkerManager assicoated with CoreWebView2Profile, is triggered when a shared worker is successfully created within the context of a WebView2 application for the profile. It grants access to the CoreWebView2SharedWorker object, which contains information such as the script URL and name. Additionally, it provides a 'destroy' event that is fired just before this object is due for destruction.

**GetSharedWorkers**: The GetSharedWorkers method, part of the CoreWebViewSharedWorkerManager class, is used to retrieve all shared workers created within the context of a WebView2 application for the profile. This method gives a collection of CoreWebView2SharedWorkers objects.

# Examples
## Dedicated Worker
## Monitoring the Creation/Destruction of Dedicated Workers.
The following example demonstrates how to subscribe to the event that is triggered when a web page creates a dedicated worker. This event provides a CoreWebView2 dedicated worker object, enabling the host application to interact with it.

## .NET/WinRT
```c#
    void DedicatedWorkerCreatedExecuted(object target, ExecutedRoutedEventArgs e)
    {
        webView.CoreWebView2.DedicatedWorkerCreated += (sender, args) =>
        {
            CoreWebView2DedicatedWorker dedicatedWorker = args.Worker;
            if(dedicatedWorker != null)
            {
              var stringUrl = dedicatedWorker.ScriptUrl;
              MessageBox.Show("Dedicated is created at " + stringUrl , "Dedicated Worker Message");

              dedicatedWorker.WorkerDestroyed += (sender, args) =>
              {
                 /*Cleanup on worker destruction*/
                 MessageBox.Show("Dedicated is destroyed" , "Dedicated Worker Message");
              };
            }
        };
    }
```
## Win32 C++
```cpp
    ScenarioDedicatedWorker::ScenarioDedicatedWorker(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
    {
      m_webView2_25 = m_webView.try_query<ICoreWebView225>();
      CHECK_FEATURE_RETURN_EMPTY(m_webView2_25);

      CHECK_FAILURE(m_webView2_25->add_DedicatedWorkerCreated(
          Microsoft::WRL::Callback<ICoreWebView2DedicatedWorkerCreatedEventHandler>(
              [this](
                  ICoreWebView2* sender,
                  ICoreWebView2DedicatedWorkerCreatedEventArgs* args)
              {
                  wil::com_ptr<ICoreWebView2DedicatedWorker> dedicatedWorker;

                  CHECK_FAILURE(args->get_Worker(&dedicatedWorker));

                  wil::com_ptr<ICoreWebView2Worker> worker =
                      dedicatedWorker.try_query<ICoreWebView2Worker>();

                  if(worker) {
                    wil::unique_cotaskmem_string scriptUrl;
                    CHECK_FAILURE(worker->get_ScriptUrl(&scriptUrl));

                    m_appWindow->AsyncMessageBox(scriptUrl.get(), L"Dedicated worker is created");

                    // Subscribe to worker destroyed event
                    CHECK_FAILURE(worker->add_Destroyed(
                        Callback<ICoreWebView2WorkerDestroyedEventHandler>(
                            [this](ICoreWebView2Worker* sender, IUnknown* args) -> HRESULT
                            {
                                /*Cleanup on worker destruction*/
                                return S_OK;
                            })
                            .Get(),
                        nullptr));
                  }

                  return S_OK;
              })
              .Get(),
          &m_dedicatedWorkerCreatedToken));
    }
```

## Service Worker
## Monitoring the Registration/Destruction of Service Workers

The following example demonstrates how to subscribe to the event that is triggered when a web page registers a service worker. This event provides a CoreWebView2 service worker registration object, enabling the host application to interact with the service workers.

## .NET/WinRT
```c#
    CoreWebView2ServiceWorkerManager ServiceWorkerManager_;
    void ServiceWorkerRegisteredExecuted(object target, ExecutedRoutedEventArgs e)
    {
        if (ServiceWorkerManager_ != null)
        {
            ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
        }
        ServiceWorkerManager_.ServiceWorkerRegistered += async (sender, args) =>
        {
            CoreWebView2ServiceWorkerRegistration serviceWorkerRegistration = args.ServiceWorkerRegistration;
            if(serviceWorkerRegistration != null)
            {
                serviceWorkerRegistration.WorkerDestroyed += (sender, args) =>
                {
                    /*Cleanup on worker destruction*/
                    MessageBox.Show("Service worker registration object is destroyed" , "Service Worker Registration Message");
                };

                MessageBox.Show("Service worker is registered for " + serviceWorkerRegistration.Scope, "Service Worker Registration Message");

                CoreWebView2ServiceWorker serviceWorker = await serviceWorkerRegistration.GetServiceWorkerAsync();
                if (serviceWorker != null)
                {
                    serviceWorker.WorkerDestroyed += (sender, args) =>
                    {
                        /*Cleanup on worker destruction*/
                        MessageBox.Show("Service worker object is destroyed" , "Service Worker Message");
                    };
                    MessageBox.Show("Service worker is created.", "Service Worker Message");
                }
                else
                {
                    MessageBox.Show("No active service available.", "Service Worker Message");
                }
            }
        };
    }
```
## Win32 C++
```cpp
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
                  ICoreWebView2ServiceWorkerRegisteredEventArgs* args)
              {
                  wil::com_ptr<ICoreWebView2ServiceWorkerRegistration>
                      serviceWorkerRegistration;
                  CHECK_FAILURE(args->get_ServiceWorkerRegistration(&serviceWorkerRegistration));

                  if(serviceWorkerRegistration)
                  {
                    // Subscribe to worker registration destroyed event
                    CHECK_FAILURE(serviceWorkerRegistration->add_Destroyed(
                      Callback<ICoreWebView2ServiceWorkerRegistrationDestroyedEventHandler>(
                          [this](
                              ICoreWebView2ServiceWorkerRegistration* sender,
                              IUnknown* args) -> HRESULT
                          {
                              /*Cleanup on worker registration destruction*/
                              return S_OK;
                          })
                          .Get(),
                    nullptr));

                    wil::unique_cotaskmem_string scope;
                    CHECK_FAILURE(serviceWorkerRegistration->get_Scope(&scope));

                    CHECK_FAILURE(serviceWorkerRegistration->GetServiceWorker(
                        Callback<ICoreWebView2GetServiceWorkerCompletedHandler>(
                            [this, &scope](
                                HRESULT error,
                                ICoreWebView2ServiceWorker* serviceWorker) -> HRESULT
                            {
                                wil::com_ptr<ICoreWebView2Worker> worker;
                                wil::unique_cotaskmem_string scriptUrl;
                                std::wstringstream message;
                                if (serviceWorker != nullptr)
                                {
                                    if (SUCCEEDED(
                                            serviceWorker->QueryInterface(IID_PPV_ARGS(&worker))))
                                    {
                                        // Subscribe to worker destroyed event
                                        CHECK_FAILURE(worker->add_Destroyed(
                                          Callback<
                                              ICoreWebView2WorkerDestroyedEventHandler>(
                                              [this](
                                                  ICoreWebView2Worker* sender,
                                                  IUnknown* args) -> HRESULT
                                              {
                                                  /*Cleanup on worker destruction*/
                                                  return S_OK;
                                              })
                                              .Get(),
                                          nullptr));

                                        CHECK_FAILURE(worker->get_ScriptUrl(&scriptUrl));
                                    }
                                    message << L"ScriptUrl: " << scriptUrl.get();
                                }
                                else
                                {
                                    message << L"No active service worker is available.";
                                }

                                m_appWindow->AsyncMessageBox(message.str(), L"Service worker");

                                return S_OK;
                            })
                            .Get()));

                    m_appWindow->AsyncMessageBox(scope.get(), L"Registered service worker for: ");
                  }

                  return S_OK;
              })
              .Get(),
          &m_serviceWorkerRegisteredToken));
    }
```

## Retrieving Service Worker Registrations.
The following example demonstrates how to fetch and display information about all the service worker registrations associated with the WebView2 profile.

## .NET/WinRT
```c#
    private async void GetServiceWorkerRegistrationsExecuted(object target, ExecutedRoutedEventArgs e)
    {
        try
        {
            if (ServiceWorkerManager_ != null)
            {
                ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
            }
            IReadOnlyList<CoreWebView2ServiceWorkerRegistration> registrationList = await ServiceWorkerManager_.GetServiceWorkerRegistrationsAsync();
            int registrationCount = registrationList.Count;
            StringBuilder messageBuilder = new StringBuilder();
            messageBuilder.AppendLine($"No of service workers registered: {registrationCount}");

            for (int i = 0; i < registrationList.Count(); ++i)
            {
                var scope = registrationList[i].Scope;

                messageBuilder.AppendLine($"Scope: {scope}");
            };

            MessageBox.Show(messageBuilder.ToString(), "Service Worker Registrations", MessageBoxButton.OK);
        }
        catch (NotImplementedException exception)
        {
            MessageBox.Show(this, "GetServiceWorkerRegistrationsAsync Failed: " + exception.Message,
                "Get Service Worker Registrations Info");
        }
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
                                      workerRegistrationCollection) -> HRESULT
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

                        wil::unique_cotaskmem_string scope;
                        CHECK_FAILURE(serviceWorkerRegistration->get_Scope(&scope));

                        message << L"Scope: " << scope.get();
                    }

                    m_appWindow->AsyncMessageBox(
                        std::move(message.str()), L"Registered service workers");

                    return S_OK;
                })
                .Get()));
    }
```

## Retrieving Service Worker Registration for a Specific Scope.

The following example demonstrates how to obtain the service worker registration associated with a specific scope. This allows the application to interact with the service worker.

## .NET/WinRT
```c#
    async void GetServiceWorkerRegisteredForScopeExecuted(object target, ExecutedRoutedEventArgs e)
    {
        var dialog = new TextInputDialog(
            title: "Scope of the Service Worker Registration",
            description: "Specify a scope to get the service worker",
            defaultInput: "");
        if (dialog.ShowDialog() == true)
        {
            try
            {
                if (ServiceWorkerManager_ != null)
                {
                    ServiceWorkerManager_ = WebViewProfile.ServiceWorkerManager;
                }
                CoreWebView2ServiceWorkerRegistration registration = await ServiceWorkerManager_.GetServiceWorkerRegistrationAsync(dialog.Input.Text);
                if(registration != null)
                {
                    StringBuilder messageBuilder = new StringBuilder();

                    CoreWebView2ServiceWorker worker = await registration.GetServiceWorkerAsync();
                    if(worker != null)
                    {
                        messageBuilder.AppendLine($"Service worker for scope '{dialog.Input.Text}' fetched successfully.");

                        MessageBox.Show(messageBuilder.ToString(), "Service Worker Registrations",  MessageBoxButton.OK);
                    } else
                    {
                        MessageBox.Show("No active service worker for " + dialog.Input.Text, "Service Worker Registrations",  MessageBoxButton.OK);
                    }
                } else
                {
                      MessageBox.Show("No service worker registered for " + dialog.Input.Text, "Service Worker Registrations",  MessageBoxButton.OK);
                }
            }
            catch (NotImplementedException exception)
            {
                MessageBox.Show(this, "GetServiceWorkerRegistrationsAsync Failed: " + exception.Message,
                  "Get Service Workers Info");
            }
        }
    }
```
## Win32 C++
```cpp
    void ScenarioServiceWorkerManager::GetServiceWorkerRegistrateredForScope()
    {
        if (!m_serviceWorkerManager)
        {
            CreateServiceWorkerManager();
        }
        std::wstring scope;

        TextInputDialog dialog(
            m_appWindow->GetMainWindow(), L"Service Worker", L"Scope:",
            L"Specify a scope to get the service worker", L"");

        if (dialog.confirmed)
        {
            CHECK_FAILURE(m_serviceWorkerManager->GetServiceWorkerRegistration(
                dialog.input.c_str(),
                Callback<ICoreWebView2GetServiceWorkerRegistrationCompletedHandler>(
                    [this, &scope](
                        HRESULT error,
                        ICoreWebView2ServiceWorkerRegistration* serviceWorkerRegistration)
                        -> HRESULT
                    {
                        CHECK_FAILURE(serviceWorkerRegistration->GetServiceWorker(
                            Callback<ICoreWebView2GetServiceWorkerCompletedHandler>(
                                [this, &scope](
                                    HRESULT error,
                                    ICoreWebView2ServiceWorker* serviceWorker) -> HRESULT
                                {
                                    std::wstringstream message{};

                                    if (serviceWorker != nullptr)
                                    {
                                        wil::com_ptr<ICoreWebView2Worker> worker;
                                        wil::unique_cotaskmem_string scriptUrl;
                                        if (SUCCEEDED(serviceWorker->QueryInterface(
                                                IID_PPV_ARGS(&worker))))
                                        {
                                            CHECK_FAILURE(worker->get_ScriptUrl(&scriptUrl));
                                        }

                                        message << L"ScriptUrl: " << scriptUrl.get();
                                        message << std::endl;
                                    }
                                    else
                                    {
                                        message << L"No service worker available for the scope: "
                                                << scope;
                                        message << std::endl;
                                    }

                                    m_appWindow->AsyncMessageBox(
                                        std::move(message.str()), L"Service Worker");

                                    return S_OK;
                                })
                                .Get()));

                        return S_OK;
                    })
                    .Get()));
        }
    }
```

## Shared Worker
## Monitoring Shared Worker Creation and Destruction

The following example demonstrates how to subscribe to the shared worker creation event. This event is triggered when a web page creates a shared worker. It provides the host application with access to the CoreWebView2 shared worker object, enabling interaction with shared workers.

## .NET/WinRT
```c#
    CoreWebView2SharedWorkerManager SharedWorkerManager_;
    void SharedWorkerManagerExecuted(object target, ExecutedRoutedEventArgs e)
    {
        SharedWorkerManager_ = WebViewProfile.SharedWorkerManager;

        if(SharedWorkerManager_ != null)
        {
            SharedWorkerManager_.SharedWorkerCreated += (sender, args) =>
            {
                CoreWebView2SharedWorker sharedWorker = args.Worker;
                if(sharedWorker != null)
                {
                  sharedWorker.WorkerDestroyed += (sender, args) =>
                  {
                    /*Cleanup on worker destruction*/
                    MessageBox.Show("Shared worker is destroyed" , "Shared Worker Message");
                  };

                  var stringUrl = sharedWorker.ScriptUrl;
                  MessageBox.Show("Shared is created at" + stringUrl , "Shared Worker Message");
                }
            };
        }
    }
```
## Win32 C++
```cpp
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
                  ICoreWebView2SharedWorkerCreatedEventArgs* args)
              {
                  wil::com_ptr<ICoreWebView2SharedWorker> sharedWorker;
                  CHECK_FAILURE(args->get_Worker(&sharedWorker));

                  wil::com_ptr<ICoreWebView2Worker> worker =
                      sharedWorker.try_query<ICoreWebView2Worker>();
                  if(worker)
                  {
                    wil::unique_cotaskmem_string scriptUrl;
                    CHECK_FAILURE(worker->get_ScriptUrl(&scriptUrl));

                    // Subscribe to worker destroyed event
                    CHECK_FAILURE(worker->add_Destroyed(
                        Callback<ICoreWebView2WorkerDestroyedEventHandler>(
                            [this, &scriptUrl](
                                ICoreWebView2Worker* sender, IUnknown* args) -> HRESULT
                            {
                                /*Cleanup on worker destruction*/
                                m_appWindow->AsyncMessageBox(
                                    scriptUrl.get(), L"Shared worker is destroyed");
                                return S_OK;
                            })
                            .Get(),
                        nullptr));

                    m_appWindow->AsyncMessageBox(scriptUrl.get(), L"Shared worker is created");
                  }
                  return S_OK;
              })
              .Get(),
          &m_sharedWorkerCreatedToken));
    }
```

## Retrieving Shared Workers

The following example demonstrates how to fetch and display information about all the shared workers associated with the WebView2 profile.

## .NET/WinRT
```c#
    private async void GetSharedWorkersExecuted(object target, ExecutedRoutedEventArgs e)
    {
      try
      {
          if (SharedWorkerManager_ != null)
          {
              SharedWorkerManager_ = WebViewProfile.SharedWorkerManager;
          }
          IReadOnlyList<CoreWebView2SharedWorker> workerList = await SharedWorkerManager_.GetSharedWorkersAsync();
          int workerCount = workerList.Count;
          StringBuilder messageBuilder = new StringBuilder();
          messageBuilder.AppendLine($"No of shared  workers created: {workerCount}");

          for (int i = 0; i < workerCount; ++i)
          {
              var stringUrl = workerList[i].ScriptUrl;

              messageBuilder.AppendLine($"ScriptUrl: {scriptUrl}");
          };

          MessageBox.Show(messageBuilder.ToString(), "Shared Workers", MessageBoxButton.OK);
      }
      catch (NotImplementedException exception)
      {
          MessageBox.Show(this, "GetSharedWorkersAsync Failed: " + exception.Message,
              "Get Shared Workers Info");
      }
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
                ICoreWebView2SharedWorkerCollectionView* workersCollection) -> HRESULT
            {
                UINT32 workersCount = 0;
                CHECK_FAILURE(workersCollection->get_Count(&workersCount));

                std::wstringstream message{};
                message << L"No of shared workers created: " << workersCount << std::endl;

                for (UINT32 i = 0; i < workersCount; i++)
                {
                    Microsoft::WRL::ComPtr<ICoreWebView2SharedWorker> sharedWorker;
                    CHECK_FAILURE(workersCollection->GetValueAtIndex(i, &sharedWorker));

                    wil::com_ptr<ICoreWebView2Worker> worker;
                    if (SUCCEEDED(sharedWorker->QueryInterface(IID_PPV_ARGS(&worker))))
                    {
                        wil::unique_cotaskmem_string scriptUrl;
                        CHECK_FAILURE(worker->get_ScriptUrl(&scriptUrl));

                        message << L"ScriptUrl: " << scriptUrl.get();
                        message << std::endl;
                    }
                }

                m_appWindow->AsyncMessageBox(
                    std::move(message.str()), L"Get all shared workers");

                return S_OK;
            })
            .Get()));
  }
```

# API Details
```
/// State of the service worker.
[v1_enum]
typedef enum COREWEBVIEW2_SERVICE_WORKER_STATE {
  /// The service worker is new and has not been installed yet.
  COREWEBVIEW2_SERVICE_WORKER_STATE_NEW,
  /// The service worker is installing.
  COREWEBVIEW2_SERVICE_WORKER_STATE_INSTALLING,
  /// The service worker is installed. The service worker in this state is considered a waiting worker.
  COREWEBVIEW2_SERVICE_WORKER_STATE_INSTALLED,
  /// The service worker is activating.
  COREWEBVIEW2_SERVICE_WORKER_STATE_ACTIVATING,
  /// The service worker is activated. The service worker in this state is considered an active worker ready to handle functional events.
  COREWEBVIEW2_SERVICE_WORKER_STATE_ACTIVATED,
  /// The service worker is redundant.
  COREWEBVIEW2_SERVICE_WORKER_STATE_REDUNDANT,
} COREWEBVIEW2_SERVICE_WORKER_STATE;

[uuid(29b994e5-0ac8-5430-89fa-5b4bb2091d8d), object, pointer_default(unique)]
interface ICoreWebView225 : IUnknown {
  /// Subscribe to this event that gets raised when a new dedicated worker is created.
  ///
  /// A Dedicated Worker is a type of web worker that allow you to run Javascript code in the background without blocking the main thread, making them useful for tasks like heavy computations, data processing, and parallel execution.
  /// It is "dedicated" because it is linked to a single parent document and cannot be shared with other scripts.
  ///
  /// This event is raised when a web application creates a dedicated worker using the
  /// `new Worker("/worker.js")` method. See the
  /// [Worker](https://developer.mozilla.org/en-US/docs/Web/API/Worker/Worker)
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

[uuid(ad6921d4-c416-5945-8437-2c97aeb76e6e), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : IUnknown {
  /// Get the service worker manager to monitor service worker registrations and interact with the service worker associated with the current profile.
  ///
  /// The changes would apply to the context of the user profile. That is, other WebViews under the same user profile could be affected.
  ///
  /// \snippet ScenarioServiceWorkerManager.cpp ServiceWorkerManager
  [propget] HRESULT ServiceWorkerManager([out, retval] ICoreWebView2ServiceWorkerManager** value);


  /// Get the shared worker manager to monitor shared worker creations and interact with the shared worker associated with the current profile.
  ///
  /// The changes would apply to the context of the user profile. That is, other WebViews under the same user profile could be affected.
  ///
  /// \snippet ScenarioSharedWorkerManager.cpp SharedWorkerManager
  [propget] HRESULT SharedWorkerManager([out, retval] ICoreWebView2SharedWorkerManager** value);
}

[uuid(4e07e562-8db7-5815-907b-6d89a253a974), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerManager : IUnknown {
  /// Adds an event handler for the `ServiceWorkerRegistered` event.
  ///
  /// A ServiceWorker is a specific type of worker that takes a JavaScript file that can control the web-page/site that it is associated with,
  /// intercepting and modifying navigation and resource requests, and caching resources in a very granular fashion to give you complete control
  /// over how app behaves in certain situations.
  ///
  /// Service workers essentially act as proxy servers that sit between web applications, the browser, and the network (when available).
  /// Unlike Shared Workers, which have their own separate global scope, Service Workers have no DOM access and run in a different context.
  ///
  /// This event is raised when a web application registers a service worker using the
  /// `navigator.serviceWorker.register("/sw.js")` method. See the
  /// [Service Worker Registration](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration)
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
  HRESULT GetServiceWorkerRegistrations(
      [in] ICoreWebView2GetServiceWorkerRegistrationsCompletedHandler* handler
  );

  /// Gets the service worker registration object associated with the specified scope. If a service worker has been registered
  /// for the given scope, it gets the corresponding `CoreWebView2ServiceWorkerRegistration` object.
  /// If scope is empty string or null, the completed handler immediately returns `E_POINTER` and with a null pointer.
  HRESULT GetServiceWorkerRegistration(
      [in] LPCWSTR scope
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
  /// A string representing a URL that defines a service worker's registration scope. It is relative to the base URL of the application.
  /// By default, the scope value for a service worker registration is set to the directory where the service worker script is located.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Scope([out, retval] LPWSTR* value);

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

/// Receives the result of the `GetServiceWorker` method.
[uuid(bd120b47-b859-5f44-9913-0318130ffb69), object, pointer_default(unique)]
interface ICoreWebView2GetServiceWorkerCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ServiceWorker* result);
}

/// Receives `Destroyed` events.
[uuid(9d79117e-4e96-5a53-9933-d7a31d0106ae), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistrationDestroyedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorkerRegistration* sender,
      [in] IUnknown* args);
}

[uuid(0c0b03bd-ced2-5518-851a-3d3f71fb5c4b), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistration : IUnknown {
  /// A string representing a URL that defines a service worker's registration scope. It is relative to the base URL of the application.
  /// By default, the scope value for a service worker registration is set to the directory where the service worker script is located.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Scope([out, retval] LPWSTR* value);

  /// Add an event handler for the `Destroyed` event that is raised when the worker registration is
  /// unregistered using the JS api `registration.unregister()` method or when the `CoreWebView2ServiceWorkerRegistration`
  /// object is destroyed. See the
  /// [Unregister](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/unregister)
  /// for more information.

  HRESULT add_Destroyed(
      [in] ICoreWebView2ServiceWorkerRegistrationDestroyedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Destroyed`.
  HRESULT remove_Destroyed(
      [in] EventRegistrationToken token);


  /// The active service worker that was created. If there is no active service worker, the completed handler immediately returns `S_OK` and with a null pointer.
  /// The active service worker is the service worker that controls the pages within the scope of the registration. See the [Service Worker](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorker)
  /// for more information.
  HRESULT GetServiceWorker(
      [in] ICoreWebView2GetServiceWorkerCompletedHandler* handler
  );
}

[uuid(9b897103-d035-551f-892e-3e8f2916d03e), object, pointer_default(unique)]
interface ICoreWebView2SharedWorkerManager : IUnknown {
  /// Add an event handler for the `SharedWorkerCreated` event.
  ///
  /// A SharedWorker is a specific type of worker that can be accessed from several browsing contexts, such as multiple windows, iframes, or even other workers.
  /// Unlike Dedicated Workers, which have their own separate global scope, SharedWorkers share a commoglobal scope called SharedWorkerGlobalScope.
  ///
  /// This event is raised when a web application creates a shared worker using the
  /// `new SharedWorker("worker.js")` method. See the
  /// [Shared Worker](https://developer.mozilla.org/en-US/docs/Web/API/SharedWorker)
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

[uuid(06cfc21b-56e5-59b1-b7b4-13f197d4539d), object, pointer_default(unique)]
interface ICoreWebView2Worker : IUnknown {
  /// A string representing the URL of the script that the worker is executing.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT ScriptUrl([out, retval] LPWSTR* value);


  /// Add an event handler for the `Destroyed` event that is raised when the worker object is destroyed.
  /// A worker object is destroyed when the worker script is terminated or when the `CoreWebView2Worker` object is destroyed.
  HRESULT add_Destroyed(
      [in] ICoreWebView2WorkerDestroyedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_Destroyed`.
  HRESULT remove_Destroyed(
      [in] EventRegistrationToken token);
}

/// Receives `Destroyed` events.
[uuid(3197df3b-4245-5fff-9427-e98118fcf657), object, pointer_default(unique)]
interface ICoreWebView2WorkerDestroyedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Worker* sender,
      [in] IUnknown* args);
}

[uuid(f233edb4-d9b4-5209-9abd-b7f50089464c), object, pointer_default(unique)]
interface ICoreWebView2DedicatedWorker : IUnknown {
  /// A string specified when creating a dedicated worker.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Name([out, retval] LPWSTR* value);
}


[uuid(de8ed42b-5128-55df-9dd0-ea1d4d706c87), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorker : IUnknown {
  /// The state of the service worker. A service worker can be in new, installing, installed, activating, activated, or redundant.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_SERVICE_WORKER_STATE* value);
}

[uuid(876f8390-f9a8-5264-9677-985d8453aeab), object, pointer_default(unique)]
interface ICoreWebView2SharedWorker : IUnknown {
  /// A string specified when creating a shared worker.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Name([out, retval] LPWSTR* value);
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
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView225")]
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
        String Name { get; };

        String ScriptUrl { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2DedicatedWorker, IInspectable> Destroyed;
    }

    enum CoreWebView2ServiceWorkerState
    {
        New = 0,
        Installing = 1,
        Installed = 2,
        Activating = 3,
        Activated = 4,
        Redundant = 5,
    };

    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile9")]
    {
        CoreWebView2ServiceWorkerManager ServiceWorkerManager { get; };

        CoreWebView2SharedWorkerManager SharedWorkerManager { get; };
    }

    runtimeclass CoreWebView2ServiceWorkerManager
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerManager, CoreWebView2ServiceWorkerRegisteredEventArgs> ServiceWorkerRegistered;

        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ServiceWorkerRegistration>> GetServiceWorkerRegistrationsAsync();

        Windows.Foundation.IAsyncOperation<CoreWebView2ServiceWorkerRegistration> GetServiceWorkerRegistrationAsync(String Scope);
    }

    runtimeclass CoreWebView2ServiceWorkerRegisteredEventArgs
    {
        CoreWebView2ServiceWorkerRegistration ServiceWorkerRegistration { get; };
    }

    runtimeclass CoreWebView2ServiceWorkerRegistration
    {
        String Scope { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerRegistration, IInspectable> Destroyed;

        Windows.Foundation.IAsyncOperation<CoreWebView2ServiceWorker> GetServiceWorkerAsync();
    }

    runtimeclass CoreWebView2ServiceWorker
    {
        String ScriptUrl { get; };

        CoreWebView2ServiceWorkerState State { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorker, IInspectable> Destroyed;
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
        String Name { get; };

        String ScriptUrl { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2SharedWorker, IInspectable> Destroyed;
    }
}
```
