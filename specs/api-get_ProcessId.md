Process ID When a WebView2 Process Fails
===

# Background

WebView2 provides applications with the [ProcessFailed](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed) event so they can react accordingly when a process failure occurs. However, this event does not currently provide the process id of the failed process. This is particularly problematic when running multiple renderers, it becomes difficult for the application to determine which process to address.

In this document we describe an extended version of the [ProcessFailedEventArgs](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.2151.40), which includes the process id. This enables the host application to collect additional information about the process failure whether a renderer, GPU, or even the browser process.

The updated API is detailed below. We'd appreciate your feedback.

# Description

The `ICoreWebView2ProcessFailedEventArgs4` interface extends the existing `ProcessFailedEventArgs` to include the process ID of the failed process. This enables applications to:
- Correlate process failures with running process data from the ProcessInfo API
- Collect process-specific diagnostic information for logging and telemetry
- Analyze crash dumps for specific processes
- Better track and respond to failures in multi-renderer scenarios

The process ID is only available if the process has started and ended unexpectedly. For other failure types where the process was never successfully started, the process ID value will be `0`.

# Examples

The following code snippets demonstrate how the updated `ProcessFailedEventArgs` can be used by the host application:

## Win32 C++

```cpp
//! [ProcessFailed]
// Register a handler for the ProcessFailed event.
    // This handler checks the failure kind and tries to:
    //   * Recreate the webview for browser failure and render unresponsive.
    //   * Reload the webview for render failure.
    //   * Reload the webview for frame-only render failure impacting app content.
    //   * Log information about the failure for other failures.
CHECK_FAILURE(m_webView->add_ProcessFailed(
    Callback<ICoreWebView2ProcessFailedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2ProcessFailedEventArgs* argsRaw)
            -> HRESULT {
            wil::com_ptr<ICoreWebView2ProcessFailedEventArgs> args = argsRaw;
            COREWEBVIEW2_PROCESS_FAILED_KIND kind;
            CHECK_FAILURE(args->get_ProcessFailedKind(&kind));
            
            // Try to get the newer interface with additional failure details
            auto args2 = args.try_query<ICoreWebView2ProcessFailedEventArgs2>();
            if (args2)
            {
                COREWEBVIEW2_PROCESS_FAILED_REASON reason;
                wil::unique_cotaskmem_string processDescription;
                INT32 exitCode;
                CHECK_FAILURE(args2->get_Reason(&reason));
                CHECK_FAILURE(args2->get_ProcessDescription(&processDescription));
                CHECK_FAILURE(args2->get_ExitCode(&exitCode));

                // Get the process ID of the failed process
                INT32 processId = 0;
                auto args4 = args.try_query<ICoreWebView2ProcessFailedEventArgs4>();
                if (args4)
                {
                    CHECK_FAILURE(args4->get_ProcessId(&processId));
                }

                // Log the failure details including the process ID
                std::wstringstream message;
                message << L"Kind: " << ProcessFailedKindToString(kind) << L"\n"
                        << L"Reason: " << ProcessFailedReasonToString(reason) << L"\n"
                        << L"Exit code: " << exitCode << L"\n"
                        << L"Process ID: " << processId << L"\n"
                        << L"Process description: " << processDescription.get();
                
                OutputDebugString(message.str().c_str());
                // Collect the process ID for telemetry or further analysis
            }
            return S_OK;
        })
        .Get(),
    &m_processFailedToken));
//! [ProcessFailed]
```

## .NET C#

```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        webView.CoreWebView2.ProcessFailed += WebView_ProcessFailed;
    }
}

void WebView_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
{
    // Collect failure details including the process ID
    StringBuilder messageBuilder = new StringBuilder();
    messageBuilder.AppendLine($"Process kind: {e.ProcessFailedKind}");
    messageBuilder.AppendLine($"Reason: {e.Reason}");
    messageBuilder.AppendLine($"Exit code: {e.ExitCode}");
    messageBuilder.AppendLine($"Process description: {e.ProcessDescription}");
    
    // Get the process ID of the failed process
    messageBuilder.AppendLine($"Process ID: {e.ProcessId}");
    
    // Log the failure or send to telemetry
    System.Diagnostics.Debug.WriteLine(messageBuilder.ToString());
    
    // You can also correlate with process info collected earlier
    var failedProcessInfo = _processInfoList.FirstOrDefault(p => p.ProcessId == e.ProcessId);
    if (failedProcessInfo != null)
    {
        System.Diagnostics.Debug.WriteLine(
            $"Failed process was of kind: {failedProcessInfo.Kind}");
    }
}
```

# Remarks

The `ProcessId` property returns the process ID of the failed process, which matches the `ProcessId` property in the `CoreWebView2ProcessInfo` interface from the ProcessInfo API. This allows you to correlate process failures with process information collected during normal operation.

The process ID is only available if the process has started and ended unexpectedly. For other failure types where the process was never successfully started or in scenarios where the process ID is not available, the `ProcessId` value will be `0`. Applications should check for this value before attempting to use the process ID.

# API Details

## COM

```cpp

/// A continuation of the ICoreWebView2ProcessFailedEventArgs3 interface
/// for getting the process ID of the failed process.
///
[uuid(f71c6e90-b2dc-4f81-bb56-bb3ef56dd8c7), object, pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs4 : ICoreWebView2ProcessFailedEventArgs3 {
    /// The process ID of the failed process. It will match the `ProcessId`
    /// property in `ICoreWebView2ProcessInfo` interface, which can be used to
    /// correlate the failing process with the running process data or to
    /// analyze crash dumps for that process. The process ID is only available
    /// if the process has started and ended unexpectedly. For other failure
    /// types, the process ID value will be `0`.
    ///
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT ProcessId([out, retval] INT32* value);
}

```

## .NET / WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ProcessFailedEventArgs
    {
        /// The process ID of the failed process. It will match the `ProcessId`
        /// property in `ICoreWebView2ProcessInfo` interface, which can be used to
        /// correlate the failing process with the running process data or to
        /// analyze crash dumps for that process. The process ID is only available
        /// if the process has started and ended unexpectedly. For other failure
        /// types, the process ID value will be `0`.
        ///
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ProcessFailedEventArgs4")]
        {
            Int32 ProcessId { get; };
        }
    }
}
```

