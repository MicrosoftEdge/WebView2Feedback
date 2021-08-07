# Background


# Description
Allow end developer to get the child process list from `GetChildProcessesInfo` and iterate through it to `GetChildProcessIdAtIndex` and `GetChildProcessTypeAtIndex` of each child process. Also provide `Count` to get the number of child processes. 

# Examples

The following code snippet demonstrates how the Media related API can be used:

## Win32 C++

```cpp
// sample to be added
```

## .NET and WinRT

```c#
// sample to be added
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2StagingChildProcessList;
interface ICoreWebView2StagingGetChildProcessesInfoCompletedHandler;

[v1_enum]
typedef enum COREWEBVIEW2_PROCESS_KIND {
  /// Indicates the browser process kind. (to be removed if rename the enum to child process)
  COREWEBVIEW2_PROCESS_KIND_BROWSER_PROCESS,

  /// Indicates the renderer process kind.
  COREWEBVIEW2_PROCESS_KIND_RENDERER_PROCESS,

  /// Indicates the utility process kind.
  COREWEBVIEW2_PROCESS_KIND_UTILITY_PROCESS,

  /// Indicates the sandbox helper process kind.
  COREWEBVIEW2_PROCESS_KIND_SANDBOX_HELPER_PROCESS,

  /// Indicates the GPU process kind.
  COREWEBVIEW2_PROCESS_KIND_GPU_PROCESS,

  /// Indicates the PPAPI plugin process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_PLUGIN_PROCESS,

  /// Indicates the PPAPI plugin broker process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_BROKER_PROCESS,

  /// Indicates the process of unspecified kind.
  COREWEBVIEW2_PROCESS_KIND_UNKNOWN_PROCESS,
} COREWEBVIEW2_PROCESS_KIND;

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
  HRESULT GetChildProcessesInfo([in] ICoreWebView2StagingGetChildProcessesInfoCompletedHandler* handler);
}

/// A list containing child process id and corresponding child process type.
/// \snippet ScenarioChildProcess.cpp GetChildProcessesInfo
[uuid(5356F3B3-4859-4763-9C95-837CDEEE8912), object, pointer_default(unique)]
interface ICoreWebView2StagingChildProcessList : IUnknown {
  /// The number of child process contained in the ICoreWebView2StagingChildProcessList.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the process id at the given index.
  HRESULT GetChildProcessIdAtIndex([in] UINT index, [out, retval] UINT32* value);

  /// Gets the process type at the given index.
  HRESULT GetChildProcessTypeAtIndex([in] UINT index, [out, retval] COREWEBVIEW2_PROCESS_KIND* processKind);
}

/// Receives the result of the `GetChildProcessesInfo` method.  The result is written to
/// the child process list provided in the `GetChildProcessesInfo` method call.
[uuid(FFC3771B-E14A-4212-8DA6-8D5C91D7D732), object, pointer_default(unique)]
interface ICoreWebView2StagingGetChildProcessesInfoCompletedHandler : IUnknown {
  /// Provides the completion status of the corresponding asynchronous method
  /// call.
  HRESULT Invoke(HRESULT result, ICoreWebView2StagingChildProcessList* childProcessList);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    /// Kind of process type used in the CoreWebView2ChildProcess.
    enum CoreWebView2ProcessKind
    {
        Browser,
        Renderer,
        Utility,
        SandBoxHelper,
        GPU,
        PPAPIPlugin,
        PPAPIBroker,
        Unknown
    };

    runtimeclass CoreWebView2
    {
        /// Gets a list of child process.
        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ChildProcess>> GetChildProcessesInfoAsync();

        // ...
    }

    /// Provides a set of properties that are used to manage a CoreWebView2ChildProcess.
    runtimeclass CoreWebView2ChildProcess
    {
        /// Child process id.
        UInt32 ProcessId { get; };

        /// Child process type.
        CoreWebView2ProcessKind ProcessType { get; };
    }

    // ...
}
```
