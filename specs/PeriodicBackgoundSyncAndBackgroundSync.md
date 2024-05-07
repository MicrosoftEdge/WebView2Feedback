Periodic Background Synchronization and Background Synchronization APIs
===

# Background
There're WebView2 customers who want to run tasks in the background at 
periodic intervals for purposes such as updating code, caching data,  
and pre-loading resources. Based on that, the WebView2 team is adding  
support for [Periodic_Background_Synchronization](https://developer.mozilla.org/docs/Web/API/Web_Periodic_Background_Synchronization_API). 
In the meanwhile, the WebView2 team is also adding support for 
[Background_Synchronization](https://developer.mozilla.org/docs/Web/API/Background_Synchronization_API)
which enhances the offline experience for web applications.

Unlike [Progressive Web App](https://learn.microsoft.com/microsoft-edge/progressive-web-apps-chromium/how-to/background-syncs#use-the-periodic-background-sync-api-to-regularly-get-fresh-content)
which passively run periodic background tasks based on the browser's 
heuristic, WebView2 exposes an API to give developers complete control 
over how to run a periodic background synchronization task.

# Description
We propose following APIs:

**SyncRegistrationManager API**: This API gives developers the ability  
to manage the periodic background synchronizations and background sync 
synchronizations in that service worker. 

**PeriodicSyncRegistered API**: This API gives developers the ability  
to subscribe to the event when a new Periodic Background synchronization 
task is registered.

**BackgroundSyncRegistered API**: This API gives developers the ability 
to subscribe to the event when a new Background synchronization task is  
registered.

**GetSyncRegistrations API**: This asynchronous call returns the 
collection of all periodic background synchronization registrations or 
background synchronization registrations based on the 
`CoreWebView2ServiceWorkerSynchronizationKind` provided. We add
`CoreWebView2ServiceWorkerSyncRegistrationInfo` with `Tag` and 
`MinInterval` properties to represent a synchronization registration.

**DispatchPeriodicSyncEvent API**: This API gives developers the ability 
to trigger a periodic background synchronization task based on the 
tag name. Developers can use native OS timer to implement a scheduler 
to trigger periodic synchronization task according to their own logic.

# API Details
## C++
```
/// Indicates the service worker background synchronization type.
[v1_enum]
typedef enum COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND {
  /// Indicates that the synchronization is a background synchronization.
  /// See [Background Synchronization](https://developer.mozilla.org/docs/Web/API/Background_Synchronization_API)
  /// for more information.
  COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND_BACKGROUND_SYNC,
  /// Indicates that the synchronization is a periodic background synchronization.
  /// See [Periodic Background Synchronization](https://developer.mozilla.org/docs/Web/API/Web_Periodic_Background_Synchronization_API)
  /// for more information.
  COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND_PERIODIC_SYNC,
} COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND;

/// This is the ICoreWebView2ServiceWorkerRegistration interface.
[uuid(08a80c87-d2b7-5163-bce3-4a28cfed142d), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerRegistration : IUnknown {
  /// Get the synchronization task registration manager for the service worker.
  /// See ICoreWebView2ServiceWorkerSyncRegistrationManager.
  ///
  /// \snippet ScenarioWebView2ServiceWorkerSyncRegistrationManager.cpp SyncRegistrationManager
  ///
  [propget] HRESULT SyncRegistrationManager([out, retval] ICoreWebView2ServiceWorkerSyncRegistrationManager** value);
}

/// This is the ICoreWebView2ServiceWorkerSyncRegistrationManager interface for the
/// Service Worker Periodic Background Synchronization and Background Synchronization
/// registration management APIs.
interface ICoreWebView2ServiceWorkerSyncRegistrationManager : IUnknown {
  /// Add an event handler for the `BackgroundSyncRegistered` event.
  ///
  /// \snippet ScenarioSyncRegistrationManager.cpp BackgroundSyncRegistered
  ///
  HRESULT add_BackgroundSyncRegistered(
      [in] ICoreWebView2SyncRegisteredEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_BackgroundSyncRegistered`.
  HRESULT remove_BackgroundSyncRegistered(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `PeriodicSyncRegistered` event.
  ///
  /// \snippet ScenarioServiceWorkerSyncRegistrationManager.cpp PeriodicSyncRegistered
  ///
  HRESULT add_PeriodicSyncRegistered(
      [in] ICoreWebView2SyncRegisteredEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_PeriodicSyncRegistered`.
  HRESULT remove_PeriodicSyncRegistered(
      [in] EventRegistrationToken token);

  /// Gets all background synchronization or periodic background synchronization
  /// registrations.
  HRESULT GetSyncRegistrations(
      [in] COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND kind
      , [in] ICoreWebView2ServiceWorkerSyncRegistrationManagerGetSyncRegistrationsCompletedHandler* handler
  );
}

/// Event args for the `PeriodicSyncRegistered` event or the `BackgroundSyncRegistered` event.
[uuid(ff0810cc-a7aa-5149-88cb-2a342233d7bf), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerSyncRegisteredEventArgs : IUnknown {
  /// The background synchronization task or periodic background synchronization task registration info.
  ///
  /// See `ICoreWebView2ServiceWorkerSyncRegistrationInfo` for details on synchronization task registration
  /// properties.
  ///
  [propget] HRESULT RegistrationInfo([out, retval] ICoreWebView2ServiceWorkerSyncRegistrationInfo** value);
}

/// Provides a set of properties for a service worker synchronization registration.
[uuid(8ab3dbf2-9207-5231-9241-167e96d8cf56), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerSyncRegistrationInfo : IUnknown {
  /// The minimum interval time, in milliseconds, at which the minimum time
  /// interval between periodic background synchronizations should occur.
  /// You should not call `CoreWebView2ServiceWorkerSyncRegistrationManager.DispatchPeriodicSyncEventAsync`
  /// to dispatch periodic synchronization tasks less than its minimum time interval.
  /// This property is always returns an invalid value `-1` for the background synchronization registration.
  ///
  [propget] HRESULT MinInterval([out, retval] INT64* value);

  /// A string representing an unique identifier for the synchronization event.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT Tag([out, retval] LPWSTR* value);
}

/// A collection of ICoreWebView2ServiceWorkerSyncRegistrationInfo.
[uuid(2fc909da-5cc2-548d-bb54-6b6ac4cb36dd), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerSyncRegistrationInfoCollectionView : IUnknown {
  /// Gets the number of synchronization task registration information contained in the collection.
  ///
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the synchronization task registration information at the specified index.
  ///
  HRESULT GetValueAtIndex(
      [in] UINT32 index
      , [out, retval] ICoreWebView2ServiceWorkerSyncRegistrationInfo** value
  );
}

/// Receives the result of the `GetSyncRegistrations` method.
[uuid(f0ab53ac-75dd-5fb0-a2a6-aa5ca88e88fb), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerSyncRegistrationManagerGetSyncRegistrationsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ServiceWorkerSyncRegistrationInfoCollectionView* result);
}

/// Receives `PeriodicSyncRegistered` or `BackgroundSyncRegistered` events.
[uuid(551ce0e3-bef4-559b-b962-d94069b7df67), object, pointer_default(unique)]
interface ICoreWebView2SyncRegisteredEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ServiceWorkerSyncRegistrationManager* sender,
      [in] ICoreWebView2ServiceWorkerSyncRegisteredEventArgs* args);
}

/// This is the ICoreWebView2ServiceWorker interface.
[uuid(feb08591-560a-5102-ab1b-26435eb261b3), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorker : IUnknown {
  /// Dispatches periodic background synchronization task.
  /// Noted that WebView2 does not automatically dispatch periodic synchronization
  /// tasks. You have the flexibility to manually execute specific periodic
  /// background synchronization tasks using your own heuristic approach,
  /// leveraging the support of OS timer APIs. There're different ways to implement
  /// the timer to call the WebView2 API when needed.
  ///
  /// You can use [chrono](https://learn.microsoft.com/cpp/standard-library/chrono)
  /// library and [thread](https://learn.microsoft.com/cpp/standard-library/thread-class)
  /// library to call the periodic synchronization task periodically.
  ///
  HRESULT DispatchPeriodicSyncEvent(
      [in] LPCWSTR tag
      , [in] ICoreWebView2ServiceWorkerDispatchPeriodicSyncEventCompletedHandler* handler
  );
}

/// Receives the result of the `DispatchPeriodicSyncEvent` method.
[uuid(86815a3e-ebc8-58b0-84ce-069d15d67d38), object, pointer_default(unique)]
interface ICoreWebView2ServiceWorkerDispatchPeriodicSyncEventCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] BOOL result);
}
```

C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ServiceWorkerRegistration
    {
        CoreWebView2ServiceWorkerSyncRegistrationManager SyncRegistrationManager { get; };
    }

    runtimeclass CoreWebView2ServiceWorkerSyncRegistrationManager
    {
        
        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerSyncRegistrationManager, CoreWebView2ServiceWorkerSyncRegisteredEventArgs> BackgroundSyncRegistered;

        event Windows.Foundation.TypedEventHandler<CoreWebView2ServiceWorkerSyncRegistrationManager, CoreWebView2ServiceWorkerSyncRegisteredEventArgs> PeriodicSyncRegistered;

        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ServiceWorkerSyncRegistrationInfo>> GetSyncRegistrationsAsync(CoreWebView2ServiceWorkerSynchronizationKind Kind);

        Windows.Foundation.IAsyncOperation<Boolean> DispatchPeriodicSyncEventAsync(String Tag);
    }
}
```


# Examples
### C++ Sample
```cpp
static constexpr WCHAR c_samplePath[] = L"ScenarioServiceWorkerSyncRegistrationManager.html";

ScenarioServiceWorkerSyncRegistrationManager::ScenarioServiceWorkerSyncRegistrationManager(
    AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    m_sampleUri = m_appWindow->GetLocalUri(c_samplePath);

    auto webView2_13 = m_webView.try_query<ICoreWebView2_13>();
    CHECK_FEATURE_RETURN_EMPTY(webView2_13);

    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
    CHECK_FAILURE(webView2_13->get_Profile(&webView2Profile));
    auto webViewProfile3 = webView2Profile.try_query<ICoreWebView2Profile3>();
    CHECK_FEATURE_RETURN_EMPTY(webViewProfile3);
    wil::com_ptr<ICoreWebView2ServiceWorkerManager> serviceWorkerManager;
    CHECK_FAILURE(webViewProfile3->get_ServiceWorkerManager(&serviceWorkerManager));

    if (serviceWorkerManager)
    {
        CHECK_FAILURE(serviceWorkerManager->GetServiceWorkerRegistration(
            m_appWindow->GetLocalUri(L"").c_str(),
            Callback<ICoreWebView2GetServiceWorkerRegistrationCompletedHandler>(
                [this](
                    HRESULT error,
                    ICoreWebView2ServiceWorkerRegistration* serviceWorkerRegistration)
                    -> HRESULT
                {
                    if (serviceWorkerRegistration)
                    {
                        serviceWorkerRegistration->QueryInterface(
                            IID_PPV_ARGS(&m_serviceWorkerRegistration));
                        //! [SyncRegistrationManager]
                        CHECK_FAILURE(serviceWorkerRegistration->get_SyncRegistrationManager(
                            &m_syncRegistrationManager));
                        if (m_syncRegistrationManager)
                        {
                            //! [BackgroundSyncRegistered]
                            CHECK_FAILURE(m_syncRegistrationManager->add_BackgroundSyncRegistered(
                                Microsoft::WRL::Callback<
                                    ICoreWebView2SyncRegisteredEventHandler>(
                                    [this](
                                        ICoreWebView2ServiceWorkerSyncRegistrationManager*
                                            sender,
                                        ICoreWebView2ServiceWorkerSyncRegisteredEventArgs*
                                            args)
                                    {
                                        wil::com_ptr<
                                            ICoreWebView2ServiceWorkerSyncRegistrationInfo>
                                            syncRegistrationInfo;
                                        CHECK_FAILURE(
                                            args->get_RegistrationInfo(&syncRegistrationInfo));
                                        std::wstringstream message;
                                        AppendSyncRegistrationInfo(
                                            syncRegistrationInfo, false, message);
                                        m_appWindow->AsyncMessageBox(
                                            message.str(), L"Background Sync");

                                        return S_OK;
                                    })
                                    .Get(),
                                &m_backgroundSyncRegisteredToken));
                            //! [BackgroundSyncRegistered]
                            //! [PeriodicSyncRegistered]
                            CHECK_FAILURE(m_syncRegistrationManager->add_PeriodicSyncRegistered(
                                Microsoft::WRL::Callback<
                                    ICoreWebView2SyncRegisteredEventHandler>(
                                    [this](
                                        ICoreWebView2ServiceWorkerSyncRegistrationManager*
                                            sender,
                                        ICoreWebView2ServiceWorkerSyncRegisteredEventArgs*
                                            args)
                                    {
                                        wil::com_ptr<
                                            ICoreWebView2ServiceWorkerSyncRegistrationInfo>
                                            syncRegistrationInfo;
                                        CHECK_FAILURE(
                                            args->get_RegistrationInfo(&syncRegistrationInfo));
                                        std::wstringstream message;
                                        AppendSyncRegistrationInfo(
                                            syncRegistrationInfo, true, message);
                                        m_appWindow->AsyncMessageBox(
                                            message.str(), L"Periodic Background Sync");
                                        return S_OK;
                                    })
                                    .Get(),
                                &m_periodicSyncRegisteredToken));
                            //! [PeriodicSyncRegistered]
                        }
                        //! [SyncRegistrationManager]
                    }
                    return S_OK;
                })
                .Get()));
    }

    // Receive dispatch periodic sync task request
    CHECK_FAILURE(m_webView->add_WebMessageReceived(
        Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args)
                -> HRESULT
            {
                wil::unique_cotaskmem_string source;
                CHECK_FAILURE(args->get_Source(&source));
                wil::unique_cotaskmem_string webMessageAsString;
                if (SUCCEEDED(args->TryGetWebMessageAsString(&webMessageAsString)))
                {
                    if (wcscmp(source.get(), m_sampleUri.c_str()) == 0)
                    {
                        std::wstring message = webMessageAsString.get();
                        if (message.compare(0, 26, L"DispatchPeriodicSyncEvent ") == 0)
                        {
                            DispatchPeriodicBackgroundSyncTask(message.substr(26).c_str());
                        }
                        else if (wcscmp(message.c_str(), L"GetPeriodicSyncRegistrations") == 0)
                        {
                            ShowAllSyncRegistrationInfos(COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND_PERIODIC_SYNC);
                        }
                        else if (
                            wcscmp(message.c_str(), L"GetBackgroundSyncRegistrations") == 0)
                        {
                            ShowAllSyncRegistrationInfos(COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND_BACKGROUND_SYNC);
                        }
                    }
                }
                return S_OK;
            })
            .Get(),
        nullptr));
    
    CHECK_FAILURE(m_webView->Navigate(m_sampleUri.c_str()));
}

void ScenarioServiceWorkerSyncRegistrationManager::DispatchPeriodicBackgroundSyncTask(
    const std::wstring& tag)
{
    if (m_serviceWorkerRegistration)
    {
        CHECK_FAILURE(m_serviceWorkerRegistration->GetServiceWorker(
            Callback<ICoreWebView2GetServiceWorkerCompletedHandler>(
                [this, &tag](
                    HRESULT error, ICoreWebView2ServiceWorker* serviceWorker) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Worker> worker;
                    wil::unique_cotaskmem_string scriptUrl;
                    std::wstringstream message;
                    // ![DispatchPeriodicSyncEvent]
                    if (serviceWorker != nullptr)
                    {
                        CHECK_FAILURE(serviceWorker->DispatchPeriodicSyncEvent(
                            tag.c_str(),
                            Microsoft::WRL::Callback<
                                ICoreWebView2ServiceWorkerDispatchPeriodicSyncEventCompletedHandler>(
                                [this](HRESULT errorCode, BOOL isSuccessful) -> HRESULT
                                {
                                    CHECK_FAILURE(errorCode);
                                    m_appWindow->AsyncMessageBox(
                                        (isSuccessful) ? L"Dispatch Periodic Sync task success"
                                                       : L"Dispatch Periodic Sync task failed",
                                        L"Dispatch periodic sync task Completed");
                                    return S_OK;
                                })
                                .Get()));
                    }
                    return S_OK;
                    // ![DispatchPeriodicSyncEvent]
                })
                .Get()));
    }
}

void ScenarioServiceWorkerSyncRegistrationManager::ShowAllSyncRegistrationInfos(
    const COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND kind)
{
    if (m_syncRegistrationManager)
    {
        //! [GetSyncRegistrations]
        CHECK_FAILURE(m_syncRegistrationManager->GetSyncRegistrations(
            kind,
            Callback<
                ICoreWebView2ServiceWorkerSyncRegistrationManagerGetSyncRegistrationsCompletedHandler>(
                [this](
                    HRESULT error,
                    ICoreWebView2ServiceWorkerSyncRegistrationInfoCollectionView*
                        collectionView) -> HRESULT
                {
                    UINT32 count;
                    collectionView->get_Count(&count);
                    bool isPeriodicSync =
                        COREWEBVIEW2_SERVICE_WORKER_SYNCHRONIZATION_KIND_PERIODIC_SYNC ? true
                                                                                       : false;
                    for (UINT32 i = 0; i < count; i++)
                    {
                        wil::com_ptr<ICoreWebView2ServiceWorkerSyncRegistrationInfo>
                            registrationInfo;
                        CHECK_FAILURE(collectionView->GetValueAtIndex(i, &registrationInfo));
                        std::wstringstream message;
                        AppendSyncRegistrationInfo(registrationInfo, isPeriodicSync, message);
                        message << L"\n";
                        m_appWindow->AsyncMessageBox(
                            std::move(message.str()), isPeriodicSync
                                                          ? L"Periodic Sync Registrations"
                                                          : L"Background Sync Registrations");
                    }
                    return S_OK;
                })
                .Get()));
        //! [GetSyncRegistrations]
    }
}

void ScenarioServiceWorkerSyncRegistrationManager::AppendSyncRegistrationInfo(
    wil::com_ptr<ICoreWebView2ServiceWorkerSyncRegistrationInfo> syncRegistrationInfo,
    bool isPeriodicSync, std::wstringstream& message)
{
    if (syncRegistrationInfo)
    {
        wil::unique_cotaskmem_string tag;
        CHECK_FAILURE(syncRegistrationInfo->get_Tag(&tag));
        message << L" Tag: " << tag.get();
        if (isPeriodicSync)
        {
            INT64 minInterval = 0;
            CHECK_FAILURE(syncRegistrationInfo->get_MinInterval(&minInterval));
            message << L" MinInterval: " << minInterval;
        }
    }
}
```
### C# Sample
```c#
CoreWebView2ServiceWorkerSyncRegistrationManager syncRegistrationManager_;
CoreWebView2ServiceWorkerRegistration serviceWorkerRegistration_;
async void ServiceWorkerSyncManagerExecuted(object target, ExecutedRoutedEventArgs e) 
{
    webView.Source = new Uri("https://appassets.example/ScenarioServiceWorkerSyncRegistrationManager.html");
    webView.CoreWebView2.WebMessageReceived += ServiceWorkerSyncEvent_WebMessageReceived;

    CoreWebView2Profile WebViewProfile = webView.CoreWebView2.Profile;
    CoreWebView2ServiceWorkerManager ServiceWorkerManager = WebViewProfile.ServiceWorkerManager;
    if (ServiceWorkerManager != null) {
        serviceWorkerRegistration_ = 
            await ServiceWorkerManager.GetServiceWorkerRegistrationAsync("https://appassets.example.com");
        if (serviceWorkerRegistration_ != null) {
            syncRegistrationManager_ = serviceWorkerRegistration_.SyncRegistrationManager;
            if (syncRegistrationManager_ != null)
            {
                try
                {
                    syncRegistrationManager_.PeriodicSyncRegistered += (sender, args) =>
                    {
                        MessageBox.Show($"Periodic Sync Task Tag: {args.RegistrationInfo.Tag}, 
                                        MinInterval: {args.RegistrationInfo.MinInterval} registered");
                    };
                    syncRegistrationManager_.BackgroundSyncRegistered += (sender, args) =>
                    {
                        MessageBox.Show($"Background Sync Task Tag: {args.RegistrationInfo.Tag} registered");
                    };
                }
                catch (NotImplementedException exception)
                {
                    MessageBox.Show(this, "ServiceWorkerSyncRegistrationManager Failed: " + exception.Message,
                    "ServiceWorkerSyncRegistrationManager");
                }
            }
        }
    }
}

async void ServiceWorkerSyncEvent_WebMessageReceived(object sender, CoreWebView2WebMessageReceivedEventArgs args)
{
    async void ShowServiceWorkerSyncRegistrations(bool isPeriodicSync) 
    {
        if (syncRegistrationManager_) {
            IReadOnlyList<CoreWebView2ServiceWorkerSyncRegistrationInfo> registrationList =
            await syncRegistrationManager_.GetSyncRegistrationsAsync(isPeriodicSync ?
                CoreWebView2ServiceWorkerSynchronizationKind.PeriodicSync :
                CoreWebView2ServiceWorkerSynchronizationKind.BackgroundSync);
        
            int registrationCount = registrationList.Count;
            StringBuilder messageBuilder = new StringBuilder();
            messageBuilder.AppendLine(isPeriodicSync ?
                "No of periodic background sync created: " :
                "No of background sync created: ");
            messageBuilder.Append($"{registrationCount}");

            for (int i = 0; i < registrationCount; ++i)
            {
                var tag = registrationList[i].Tag;
                messageBuilder.AppendLine($"Tag: {tag}");
                if (isPeriodicSync) {
                    var interval = registrationList[i].MinInterval;
                    messageBuilder.Append($" MinInterval: {interval}");
                }
            };

            MessageBox.Show(messageBuilder.ToString(), isPeriodicSync ?
                "Periodic Background Sync Registrations" :
                "Background Sync Registrations", MessageBoxButton.OK);
        }
    }

    if (args.Source != "https://appassets.example/ScenarioServiceWorkerSyncRegistrationManager.html")
    {
        return;
    }

    string message = args.TryGetWebMessageAsString();
    if (message.Contains("DispatchPeriodicSyncEvent"))
    {
        int msgLength = "DispatchPeriodicSyncEvent".Length;
        var tag = message.Substring(msgLength);
        CoreWebView2ServiceWorker serviceWorker = await serviceWorkerRegistration_.GetServiceWorkerAsync();
        if (serviceWorker != null) {
            await serviceWorker.DispatchPeriodicSyncEventAsync(tag);
        }
    } else if (message.Contains("GetPeriodicSyncRegistrations")) {
        ShowServiceWorkerSyncRegistrations(true);
    } else if (message.Contains("GetBackgroundSyncRegistrations")) {
        ShowServiceWorkerSyncRegistrations(false);
    }
}
```
