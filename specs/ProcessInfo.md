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
    _processList = WebViewEnvironment.ProcessInfo;
}

void PerfInfoCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    string result;
    int processListCount = _processList.Count;
    if (processListCount == 0)
    {
        result = "No process found.";
    }
    else
    {
        result = $"{processListCount} child process(s) found\n\n";
        for (int i = 0; i < processListCount; ++i)
        {
            uint processId = _processList[i].Id;
            CoreWebView2ProcessKind kind = _processList[i].Kind;

            var proc = Process.GetProcessById((int)processId);
            var memoryInBytes = proc.PrivateMemorySize64;
            var b2kb = memoryInBytes / 1024;
            result = result + $"Process ID: {processId} | Process Kind: {kind} | Memory: {b2kb} KB\n";
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
        Callback<ICoreWebView2ProcessInfoChangedEventHandler>(
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
void ProcessComponent::PerformanceInfo()
{
    std::wstring result;
    UINT processListCount;
    CHECK_FAILURE(m_processCollection->get_Count(&processListCount));

    if (processListCount == 0)
    {
        result += L"No process found.";
    }
    else
    {
        result += std::to_wstring(processListCount) + L" process(s) found";
        result += L"\n\n";
        for (UINT i = 0; i < processListCount; ++i)
        {
            wil::com_ptr<ICoreWebView2StagingProcessInfo> processInfo;
            CHECK_FAILURE(m_processCollection->GetValueAtIndex(i, &processInfo));

            UINT32 processId = 0;
            COREWEBVIEW2_PROCESS_KIND kind;
            CHECK_FAILURE(processInfo->get_Id(&processId));
            CHECK_FAILURE(processInfo->get_Kind(&kind));

            WCHAR id[4096] = L"";
            StringCchPrintf(id, ARRAYSIZE(id), L"Process ID: %u", processId);

            HANDLE processHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId);
            PROCESS_MEMORY_COUNTERS_EX pmc;
            GetProcessMemoryInfo(
                processHandle, reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&pmc), sizeof(pmc));
            SIZE_T virtualMemUsed = pmc.PrivateUsage / 1024;
            WCHAR memory[4096] = L"";
            StringCchPrintf(memory, ARRAYSIZE(memory), L"Memory: %u", virtualMemUsed);

            result = result + id + L" | Process Kind: " + ProcessKindToString(kind) + L" | " +
                     memory + L" KB\n";
        }
    }
    MessageBox(nullptr, result.c_str(), L"Memory Usage", MB_OK);
}
//! [ProcessInfoChanged]
```

# API Details    
```
interface ICoreWebView2Environment6;
interface ICoreWebView2ProcessInfo;
interface ICoreWebView2ProcessInfoCollection;
interface ICoreWebView2ProcessInfoChangedEventHandler;

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
      [in] ICoreWebView2ProcessInfoChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_ProcessInfoChanged`.
  HRESULT remove_ProcessInfoChanged(
      [in] EventRegistrationToken token);

  /// Returns the `ICoreWebView2ProcessInfoCollection`
  /// Provide a list of all process using same user data folder.
  [propget] HRESULT ProcessInfo([out, retval]ICoreWebView2ProcessInfoCollection** value);
}

/// Provides a set of properties for a process in the `ICoreWebView2Environment`.
[uuid(7798D399-52A1-4823-AD6A-1F3EDD74B0B6), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfo : IUnknown {

  /// The process id of the process.
  [propget] HRESULT Id([out, retval] UINT32* value);

  /// The kind of the process.
  [propget] HRESULT Kind([out, retval] COREWEBVIEW2_PROCESS_KIND* kind);
}

/// A list containing process id and corresponding process type.
[uuid(5356F3B3-4859-4763-9C95-837CDEEE8912), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfoCollection : IUnknown {
  /// The number of process contained in the ICoreWebView2ProcessInfoCollection.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the `ICoreWebView2ProcessInfo` located in the `ICoreWebView2ProcessInfoCollection`
  /// at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index,
                          [out, retval] ICoreWebView2ProcessInfo** processInfo);
}

/// An event handler for the `ProcessInfoChanged` event.
[uuid(CFF13C72-2E3B-4812-96FB-DFDDE67FBE90), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfoChangedEventHandler : IUnknown {
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
        UInt32 Id { get; };

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

