ProcessId for ProcessFailedEventArgs
===

# Background

WebView2 provides applications with the
[ProcessFailed](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed)
event so they can react accordingly when a process failure occurs. However,
this event does not currently provide the process ID of the failed process.
This is particularly problematic when running multiple renderers. It becomes
difficult for the application to determine which process to address.

In this document we describe an extended version of the
[ProcessFailedEventArgs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.2151.40),
which provides access to an `ICoreWebView2ProcessInfo` object for the failed process. This object includes the process ID, process kind, and other relevant information. This enables the host application to collect
additional information about the process failure, whether it is a renderer, GPU, or
even the browser process.

The updated API is detailed below. We'd appreciate your feedback.

# Description

The `ICoreWebView2ProcessFailedEventArgs4` interface extends the existing
`ProcessFailedEventArgs` to include, when available, the `ICoreWebView2ProcessInfo` of the failed process. Note that `ProcessInfo` may be null or unavailable in certain scenarios. This
enables applications to:
- Correlate process failures with running process data from the ProcessInfo API
- Collect process-specific diagnostic information for logging and telemetry
- Analyze crash dumps for specific processes
- Better track and respond to failures in multi-renderer scenarios

# Examples

The following code snippets demonstrate how the updated
`ProcessFailedEventArgs` can be used by the host application:

## Win32 C++

```cpp
//! [ProcessFailed]
// Register a handler for the ProcessFailed event.
    // This handler collects extended diagnostics so the host can:
    //   * Inspect the failure kind together with reason, description, and exit code.
    //   * Retrieve the CoreWebView2ProcessInfo for the failed process (ID and kind).
    //   * Log the gathered information for telemetry or later correlation and decide
    //     how to react (reload/recreate) based on app policy outside of this sample.
CHECK_FAILURE(m_webView->add_ProcessFailed(
    Callback<ICoreWebView2ProcessFailedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ProcessFailedEventArgs* argsRaw)
            -> HRESULT {
            wil::com_ptr<ICoreWebView2ProcessFailedEventArgs> args = argsRaw;
            COREWEBVIEW2_PROCESS_FAILED_KIND kind;
            CHECK_FAILURE(args->get_ProcessFailedKind(&kind));

            // Try to get the newer interface with additional failure details
            auto args2 =
                args.try_query<ICoreWebView2ProcessFailedEventArgs2>();
            if (args2)
            {
                COREWEBVIEW2_PROCESS_FAILED_REASON reason;
                wil::unique_cotaskmem_string processDescription;
                INT32 exitCode;
                CHECK_FAILURE(args2->get_Reason(&reason));
                CHECK_FAILURE(
                    args2->get_ProcessDescription(&processDescription));
                CHECK_FAILURE(args2->get_ExitCode(&exitCode));

                // Get the process ID of the failed process
                wil::com_ptr<ICoreWebView2ProcessInfo> processInfo;
                auto argProcessInfo = args.try_query<ICoreWebView2ProcessFailedEventArgs4>();
                if (argProcessInfo)
                {
                    CHECK_FAILURE(argProcessInfo->get_ProcessInfo(&processInfo));
                }
                INT32 processId = 0;
                COREWEBVIEW2_PROCESS_KIND processKind = COREWEBVIEW2_PROCESS_KIND_UNKNOWN;
                if (processInfo)
                {
                    CHECK_FAILURE(processInfo->get_ProcessId(&processId));
                    CHECK_FAILURE(processInfo->get_Kind(&processKind));
                }

                // Log the failure details including the process ID
                std::wstringstream message;
                message << L"Kind: " << ProcessFailedKindToString(kind)
                        << L"\n"
                        << L"Reason: " << ProcessFailedReasonToString(reason)
                        << L"\n"
                        << L"Exit code: " << exitCode << L"\n"
                        << L"Process ID: " << processId << L"\n"
                        << L"Process Kind: " << ProcessKindToString(processKind) << L"\n"
                        << L"Process description: "
                        << processDescription.get();

                OutputDebugString(message.str().c_str());
                // Collect the process ID for telemetry or further
                // analysis
            }
            return S_OK;
        })
        .Get(),
    &m_processFailedToken));
//! [ProcessFailed]
```

## .NET C#

```c#
void WebView_CoreWebView2InitializationCompleted(object sender,
    CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        webView.CoreWebView2.ProcessFailed += WebView_ProcessFailed;
    }
}

void WebView_ProcessFailed(object sender,
    CoreWebView2ProcessFailedEventArgs e)
{
    // Collect failure details including the process ID
    StringBuilder messageBuilder = new StringBuilder();
    messageBuilder.AppendLine($"Process kind: {e.ProcessFailedKind}");
    messageBuilder.AppendLine($"Reason: {e.Reason}");
    messageBuilder.AppendLine($"Exit code: {e.ExitCode}");
    messageBuilder.AppendLine(
        $"Process description: {e.ProcessDescription}");

    // Get the process ID of the failed process
    if (e.ProcessInfo != null)
    {
        messageBuilder.AppendLine($"Process ID: {e.ProcessInfo.ProcessId}");
        messageBuilder.AppendLine($"Process Kind: {e.ProcessInfo.Kind}");
    }
    else
    {
        messageBuilder.AppendLine("Process Info: unavailable (process may have been terminated externally, e.g., via Task Manager)");
    }

    // Log the failure or send to telemetry
    System.Diagnostics.Debug.WriteLine(messageBuilder.ToString());

    // You can also correlate with process info collected earlier
    var failedProcessInfo = _processInfoList.FirstOrDefault(
        p => p.ProcessId == e.ProcessInfo.ProcessId);
    if (failedProcessInfo != null)
    {
        System.Diagnostics.Debug.WriteLine(
            $"Failed process was of kind: {failedProcessInfo.Kind}");
    }
}
```

# Remarks

The `ProcessInfo` property returns an `ICoreWebView2ProcessInfo` object that contains the process ID of the failed process
and the process kind (GPU, Renderer, Browser, Utility, etc.). When the failing
process starts successfully (for example, GPU process hangs, browser process
exits, utility process exits, renderer process hangs), the process ID is
available so apps can correlate diagnostics. If the process never starts or if
the main frame renderer process is terminated externally (for example, by Task
Manager or taskkill) the associated process information is unavailable and the
reported process ID is 0.

# API Details

## COM

```cpp

/// A continuation of the ICoreWebView2ProcessFailedEventArgs3 interface
/// for getting the process ID of the failed process.
///
[uuid(f71c6e90-b2dc-4f81-bb56-bb3ef56dd8c7), object,
 pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs4 :
    ICoreWebView2ProcessFailedEventArgs3 {
    /// The process info of the failed process, which can be used to
    /// correlate the failing process with the running process data or to
    /// analyze crash dumps for that process. The process ID is available when the
    /// process starts successfully (GPU process hangs, browser process exits,
    /// utility process exits, renderer process hangs). If the process never
    /// started or when the main frame renderer process is terminated externally
    /// (for example by Task Manager or taskkill), the process ID will be set to 0.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT ProcessInfo([out, retval] ICoreWebView2ProcessInfo** value);
}

```

## .NET / WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ProcessFailedEventArgs
    {
    /// The process info of the failed process, which can be used to
    /// correlate the failing process with the running process data or to
    /// analyze crash dumps for that process.
    /// 
    /// This property may be <c>null</c> if the process never started or when the main frame renderer process
    /// is terminated externally (for example, by Task Manager or taskkill). In these cases, process information
    /// is not available. When available, the process ID is set to 0 if the process could not be identified.

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ProcessFailedEventArgs4")]
        {
            CoreWebView2ProcessInfo ProcessInfo { get; };
        }
    }
}
```
