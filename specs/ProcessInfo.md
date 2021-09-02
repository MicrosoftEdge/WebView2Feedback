Process Info
===

# Background
Provide end developer a new API to get all browser and child process ID and type. End developers can use this API to do perf count, instead of trying to hook up with task manager API to do that. 

# Examples
## ProcessRequested

Feature explanation text goes here, including why an app would use it, how it
replaces or supplements existing functionality.

```c#
IReadOnlyList<CoreWebView2ProcessInfo> _processList;

void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        WebViewEnvironment.ProcessInfoChanged += WebView_ProcessInfoChanged;
    }
}

void WebView_ProcessInfoChanged(object sender, object e)
{
    _processList = WebViewEnvironment.processInfo;
}

void ProcessInfoCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    string result;
    int processListSize = _processList.Count;
    if (processListSize == 0)
    {
        result = "No process found.";
    }
    else
    {
        result = $"{processListSize} child process(s) found\n\n";
        for (int i = 0; i < processListSize; ++i)
        {
            uint processId = _processList[i].id;
            CoreWebView2ProcessKind kind = _processList[i].Kind;
            result = result + $"Process ID: {processId}\nProcess Kind: {kind}\n";
        }
    }
    MessageBox.Show(this, result, "Process List");
}
```
    
```cpp
ProcessComponent::ProcessComponent(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    // Register a handler for the ProcessInfoChanged event.
    //! [ProcessInfoChanged]
    environment = appWindow->GetWebViewEnvironment();
    CHECK_FAILURE(environment->add_ProcessInfoChanged(
        Callback<ICoreWebView2StagingProcessInfoChangedEventHandler>(
            [this,environment](ICoreWebView2Environment* sender, IUnknown* args) -> HRESULT {
                CHECK_FAILURE(environment->get_ProcessInfo(&m_processCollection));

                return S_OK;
            })
            .Get(),
        &m_processInfoChangedToken));
    //! [ProcessInfoChanged]
}

std::wstring ProcessComponent::ProcessKindToString(const COREWEBVIEW2_PROCESS_KIND kind)
{
    switch (kind)
    {
#define KIND_ENTRY(kindValue)                                                                  \
    case kindValue:                                                                            \
        return L#kindValue;

        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_BROWSER);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_RENDERER);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_UTILITY);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_SANDBOX_HELPER);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_GPU);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_PPAPI_PLUGIN);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_PPAPI_BROKER);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_KIND_UNKNOWN);

#undef KIND_ENTRY
    }

    return L"PROCESS KIND: " + std::to_wstring(static_cast<uint32_t>(kind));
}

// Get the process info
//! [ProcessInfoChanged]
void ProcessComponent::ProcessInfo()
{
    std::wstring result;
    UINT process_list_size;
    CHECK_FAILURE(m_processCollection->get_Count(&process_list_size));

    if (process_list_size == 0)
    {
        result += L"No process found.";
    }
    else
    {
        result += std::to_wstring(process_list_size) + L" process(s) found";
        result += L"\n\n";
        for (UINT i = 0; i < process_list_size; ++i)
        {
            wil::com_ptr<ICoreWebView2StagingProcessInfo> processInfo;
            CHECK_FAILURE(m_processCollection->GetValueAtIndex(i, &processInfo));

            UINT32 processId = 0;
            COREWEBVIEW2_PROCESS_KIND kind;
            CHECK_FAILURE(processInfo->get_Id(&processId));
            CHECK_FAILURE(processInfo->get_Kind(&kind));

            WCHAR buffer[4096] = L"";
            StringCchPrintf(buffer, ARRAYSIZE(buffer), L"Process ID: %u\n", processId);

            result += buffer;

            result += L"Process Kind: " + ProcessKindToString(kind);
            result += L"\n";
        }
    }
    MessageBox(nullptr, result.c_str(), L"GetProcessesInfo Result", MB_OK);
}
//! [ProcessInfoChanged]
```

# API Details    
```
interface ICoreWebView2StagingEnvironment5;
interface ICoreWebView2StagingProcessInfo;
interface ICoreWebView2StagingProcessInfoCollection;
interface ICoreWebView2StagingProcessInfoChangedEventHandler;

[v1_enum]
typedef enum COREWEBVIEW2_PROCESS_KIND {
  /// Indicates the browser process kind.
  COREWEBVIEW2_PROCESS_KIND_BROWSER,

  /// Indicates the render process kind.
  COREWEBVIEW2_PROCESS_KIND_RENDERER,

  /// Indicates the utility process kind.
  COREWEBVIEW2_PROCESS_KIND_UTILITY,

  /// Indicates the sandbox helper process kind.
  COREWEBVIEW2_PROCESS_KIND_SANDBOX_HELPER,

  /// Indicates the GPU process kind.
  COREWEBVIEW2_PROCESS_KIND_GPU,

  /// Indicates the PPAPI plugin process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_PLUGIN,

  /// Indicates the PPAPI plugin broker process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_BROKER,

  /// Indicates the process of unspecified kind.
  COREWEBVIEW2_PROCESS_KIND_UNKNOWN,
} COREWEBVIEW2_PROCESS_KIND;

[uuid(20856F87-256B-41BE-BD64-AB1C36E3D944), object, pointer_default(unique)]
interface ICoreWebView2Environment6 : ICoreWebView2Environment5
{
  /// Adds an event handler for the `ProcessInfoChanged` event.
  /// 
  /// \snippet ProcessComponent.cpp ProcessInfoChanged
  HRESULT add_ProcessInfoChanged(
      [in] ICoreWebView2StagingProcessInfoChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_ProcessInfoChanged`.
  HRESULT remove_ProcessInfoChanged(
      [in] EventRegistrationToken token);

  /// Returns the `ICoreWebView2StagingProcessInfoCollection`
  [propget] HRESULT ProcessInfo([out, retval]ICoreWebView2StagingProcessInfoCollection** value);
}

/// Provides a set of properties for a process in the `ICoreWebView2Environment`.
[uuid(7798D399-52A1-4823-AD6A-1F3EDD74B0B6), object, pointer_default(unique)]
interface ICoreWebView2StagingProcessInfo : IUnknown {

  /// The process id in the process.
  [propget] HRESULT Id([out, retval] UINT32* value);

  /// The process type in the process.
  [propget] HRESULT Kind([out, retval] COREWEBVIEW2_PROCESS_KIND* kind);
}

/// A list containing process id and corresponding process type.
[uuid(5356F3B3-4859-4763-9C95-837CDEEE8912), object, pointer_default(unique)]
interface ICoreWebView2StagingProcessInfoCollection : IUnknown {
  /// The number of process contained in the ICoreWebView2StagingProcessInfoCollection.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the `ICoreWebView2StagingProcessInfo` located in the `ICoreWebView2StagingProcessInfoCollection`
  /// at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index,
                          [out, retval] ICoreWebView2StagingProcessInfo** processInfo);
}

/// An event handler for the `ProcessInfoChanged` event.
[uuid(CFF13C72-2E3B-4812-96FB-DFDDE67FBE90), object, pointer_default(unique)]
interface ICoreWebView2StagingProcessInfoChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] IUnknown* args);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2ProcessInfoCollection;
    runtimeclass CoreWebView2ProcessInfo;

    /// Kind of process type used in the CoreWebView2ProcessCollection.
    enum CoreWebView2ProcessKind
    {
        Browser = 0,
        Renderer = 1,
        Utility = 2,
        SandboxHelper = 3,
        Gpu = 4,
        PpapiPlugin = 5,
        PpapiBroker = 6,
        Unknown = 7,
    };

    runtimeclass CoreWebView2ProcessInfoCollection
    {
        // ICoreWebView2ProcessInfoCollection members
        UInt32 Count { get; };

        CoreWebView2ProcessInfo GetValueAtIndex(UInt32 index);
    }

    runtimeclass CoreWebView2ProcessInfo
    {
        // ICoreWebView2ProcessInfo members
        UInt32 id { get; };

        CoreWebView2ProcessKind Kind { get; };
    }

    runtimeclass CoreWebView2
    {
        /// Gets a list of process.
        IVectorView<CoreWebView2ProcessInfo> ProcessInfo { get; };
        event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> ProcessInfoChanged;

        // ...
    }

    // ...
}
```

