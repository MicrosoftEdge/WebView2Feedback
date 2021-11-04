Process Info
===

# Background
Provide end developer a new API to get all browser and child process ID with its type. End developers can use this API to track performance more closely, instead of using the task manager API to gather this information which requires a lot of preset. The process list provides all processes under the same user data folder, processes from multiple WebView creations will also be collected.
Note: Crashpad process is not captured.  

# Examples
## WinRT and .NET   
```c#
IReadOnlyList<CoreWebView2ProcessInfo> _processList = new List<CoreWebView2ProcessInfo>();

void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.Environment.ProcessInfosChanged += WebView_ProcessInfosChanged;
    }
}

void WebView_ProcessInfosChanged(object sender, object e)
{
    _processList = webView.CoreWebView2.Environment.GetProcessInfos;
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
            uint processId = _processList[i].ProcessId;
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
## Win32 C++
```cpp
ProcessComponent::ProcessComponent(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    // Register a handler for the ProcessInfosChanged event.
    //! [ProcessInfosChanged]
    wil::com_ptr<ICoreWebView2Environment> environment = appWindow->GetWebViewEnvironment();
    CHECK_FAILURE(environment->GetProcessInfos(&m_processCollection));
    CHECK_FAILURE(environment->add_ProcessInfosChanged(
        Callback<ICoreWebView2ProcessInfosChangedEventHandler>(
            [this](ICoreWebView2Environment* sender, IUnknown* args) -> HRESULT {
                CHECK_FAILURE(sender->GetProcessInfos(&m_processCollection));

                return S_OK;
            })
            .Get(),
        &m_processInfosChangedToken));
    //! [ProcessInfosChanged]
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

#undef KIND_ENTRY
    }

    return L"PROCESS KIND: " + std::to_wstring(static_cast<uint32_t>(kind));
}

// Get the process info
//! [ProcessInfosChanged]
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

            INT32 processId = 0;
            COREWEBVIEW2_PROCESS_KIND kind;
            CHECK_FAILURE(processInfo->get_ProcessId(&processId));
            CHECK_FAILURE(processInfo->get_Kind(&kind));

            WCHAR id[4096] = L"";
            StringCchPrintf(id, ARRAYSIZE(id), L"Process ID: %u", processId);

            HANDLE processHandle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
            PROCESS_MEMORY_COUNTERS_EX pmc;
            GetProcessMemoryInfo(
                processHandle, reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&pmc), sizeof(pmc));
            SIZE_T virtualMemUsed = pmc.PrivateUsage / 1024;
            WCHAR memory[4096] = L"";
            StringCchPrintf(memory, ARRAYSIZE(memory), L"Memory: %u", virtualMemUsed);
            CloseHandle(processHandle);

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
interface ICoreWebView2ProcessInfosChangedEventHandler;

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
} COREWEBVIEW2_PROCESS_KIND;

[uuid(20856F87-256B-41BE-BD64-AB1C36E3D944), object, pointer_default(unique)]
interface ICoreWebView2Environment6 : ICoreWebView2Environment5
{
  /// Adds an event handler for the `ProcessInfosChanged` event.
  /// 
  /// \snippet ProcessComponent.cpp ProcessInfosChanged
  HRESULT add_ProcessInfosChanged(
      [in] ICoreWebView2ProcessInfosChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_ProcessInfosChanged`.
  HRESULT remove_ProcessInfosChanged(
      [in] EventRegistrationToken token);

  /// Returns the `ICoreWebView2ProcessInfoCollection`
  /// Provide a list of all process using same user data folder.
  HRESULT GetProcessInfos([out, retval]ICoreWebView2ProcessInfoCollection** value);
}

/// Provides a set of properties for a process in the `ICoreWebView2Environment`.
[uuid(7798D399-52A1-4823-AD6A-1F3EDD74B0B6), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfo : IUnknown {

  /// The process id of the process.
  [propget] HRESULT ProcessId([out, retval] INT32* value);

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

/// An event handler for the `ProcessInfosChanged` event.
[uuid(CFF13C72-2E3B-4812-96FB-DFDDE67FBE90), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfosChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] IUnknown* args);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2ProcessInfo;

    /// Kind of process type used in the CoreWebView2ProcessInfoCollection.
    enum CoreWebView2ProcessKind
    {
        Browser = 0,
        Renderer = 1,
        Utility = 2,
        SandboxHelper = 3,
        Gpu = 4,
        PpapiPlugin = 5,
        PpapiBroker = 6,
    };

    runtimeclass CoreWebView2ProcessInfo
    {
        // ICoreWebView2ProcessInfo members
        Int32 ProcessId { get; };

        CoreWebView2ProcessKind Kind { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        /// Gets a list of process.
        IVectorView<CoreWebView2ProcessInfo> ProcessInfos { get; };
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, Object> ProcessInfosChanged;

        // ...
    }

    // ...
}
```

