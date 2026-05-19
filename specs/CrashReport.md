Crash Report
===

# Background

WebView2 fires the
[`ProcessFailed`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2#add_processfailed)
event when a WebView2 process crashes, hangs, or fails to launch. The event tells you
the failure kind, the exit code, and the process type, enough to react and recover. But it does not
tell you _which crash report was generated_ for that failure.

When a crash occurs, the WebView2 runtime's crash handler captures a minidump and writes crash
signature data (exception code, faulting module, bucket ID) to disk. This data is useful for
tracking reliability, grouping crashes by root cause, and filing actionable bug reports. Today there
is no supported API to read this data from a host application.

This document proposes `ICoreWebView2CrashReport`, a new read-only property on
`ProcessFailedEventArgs` that delivers crash signature data to your handler at the moment the event
fires: no file parsing, no event log queries, no internal knowledge required. A stable
`CrashReportId` ties the event directly to the crash report on disk, which you can locate via
[`FailureReportFolderPath`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2environment11#get_failurereportfolderpath).

# Description

We propose to extend `ProcessFailedEventArgs` with a read-only `CrashReport` property that exposes
a `CoreWebView2CrashReport` object. This object is a snapshot of crash signature data captured at
the moment of failure (exception code, faulting module and version, fault offset, bucket id, and
report time). Per-property reference documentation appears in the API Details section.

`CrashReport` is `null` when the failure did not produce a crash report. That is:

- The failure is a hang (`CoreWebView2ProcessFailedReason.Unresponsive`); the process is still
  alive at this point, so no crash report exists yet.
- The failure is a launch failure or a clean termination; these do not go through the crash
  handler.

`CrashReport` is populated for any crash-type process failure, including `__fastfail`
(`0xC0000409`) and out-of-memory terminations. For `__fastfail` crashes, fields are
sourced from the Windows Error Reporting event log rather than the crash handler;
`BucketId` will be empty.

Each `CoreWebView2Environment` only delivers reports for its own WebView2 processes (scoped by user
data folder). When
[`IsCustomCrashReportingEnabled`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2environmentoptions3#get_iscustomcrashreportingenabled)
is `TRUE`, the crash handler still catches exceptions and writes the minidump and crash metadata to
disk, so `CrashReport` is populated and all fields except `BucketId` are available. `BucketId` will
be empty because crash data is not uploaded to Microsoft's telemetry service.

# Examples

The following code snippets demonstrate how to use `CrashReport` to log crash identity at failure
time.

## Win32 C++

```cpp
CHECK_FAILURE(m_webView->add_ProcessFailed(
    Callback<ICoreWebView2ProcessFailedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ProcessFailedEventArgs* argsRaw) -> HRESULT
        {
            wil::com_ptr<ICoreWebView2ProcessFailedEventArgs5> args;
            CHECK_FAILURE(argsRaw->QueryInterface(IID_PPV_ARGS(&args)));

            wil::com_ptr<ICoreWebView2CrashReport> crashReport;
            CHECK_FAILURE(args->get_CrashReport(&crashReport));

            if (crashReport)
            {
                wil::unique_cotaskmem_string crashReportId;
                CHECK_FAILURE(crashReport->get_CrashReportId(&crashReportId));

                UINT32 exceptionCode = 0;
                CHECK_FAILURE(crashReport->get_ExceptionCode(&exceptionCode));

                wil::unique_cotaskmem_string faultingModuleName;
                CHECK_FAILURE(crashReport->get_FaultingModuleName(&faultingModuleName));

                wil::unique_cotaskmem_string faultingModuleVersion;
                CHECK_FAILURE(crashReport->get_FaultingModuleVersion(&faultingModuleVersion));

                UINT64 faultOffset = 0;
                CHECK_FAILURE(crashReport->get_FaultOffset(&faultOffset));

                wil::unique_cotaskmem_string bucketId;
                CHECK_FAILURE(crashReport->get_BucketId(&bucketId));

                UINT64 reportTime = 0;
                CHECK_FAILURE(crashReport->get_ReportTime(&reportTime));

                LogCrashReport(
                    crashReportId.get(),
                    exceptionCode,
                    faultingModuleName.get(),
                    faultingModuleVersion.get(),
                    faultOffset,
                    bucketId.get(),
                    reportTime);
            }
            // crashReport is null when the failure did not produce a crash report
            // (e.g., normal exit, hang, or external kill). Use ProcessFailedKind
            // and Reason to decide how to handle the failure.
            return S_OK;
        })
        .Get(),
    &m_processFailedToken));
```

## WinRT and .NET

```c#
webView.CoreWebView2.ProcessFailed += (sender, args) =>
{
    var report = args.CrashReport; // null if no crash report
    if (report != null)
    {
        LogCrashReport(
            report.CrashReportId,
            report.ExceptionCode,
            report.FaultingModuleName,
            report.FaultingModuleVersion,
            report.FaultOffset,
            report.BucketId,
            report.ReportTime); // Windows.Foundation.DateTime (DateTimeOffset in C#)
    }
    // report is null when the failure did not produce a crash report
    // (e.g., normal exit, hang, or external kill).
};
```

# API Details

## COM

```
/// Provides crash signature data captured at the moment of process failure.
/// Accessed via ICoreWebView2ProcessFailedEventArgs5.CrashReport.
///
/// CrashReport is null when the failure did not produce a crash report
/// (normal exit, external kill, launch failure, hang).
[uuid(7c3a1b40-9f1e-4a5d-8b2e-2e0e7c1f3a55), object, pointer_default(unique)]
interface ICoreWebView2CrashReport : IUnknown {
    /// A stable identifier for this crash report. Use this to locate the
    /// corresponding dump file in `FailureReportFolderPath`.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT CrashReportId([out, retval] LPWSTR* value);

    /// The Windows exception code for the failure, e.g. 0xC0000005 for
    /// STATUS_ACCESS_VIOLATION, 0xC0000409 for STATUS_STACK_BUFFER_OVERRUN
    /// (fast-fail), or 0xe0000008 for an out-of-memory termination.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT ExceptionCode([out, retval] UINT32* value);

    /// Basename of the module containing the faulting instruction,
    /// e.g. "v8.dll". Never a full path.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT FaultingModuleName([out, retval] LPWSTR* value);

    /// Version of the faulting module, e.g. "128.0.2739.42".
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT FaultingModuleVersion([out, retval] LPWSTR* value);

    /// Relative virtual address (RVA) of the faulting instruction within
    /// `FaultingModuleName`.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT FaultOffset([out, retval] UINT64* value);

    /// Crash bucket identifier assigned by Microsoft's crash telemetry service,
    /// if available at event-fire time. Returned as a 32-character hex string.
    /// Empty when no bucket was assigned: crash data was not uploaded to
    /// Microsoft's telemetry service (custom crash reporting enabled), the
    /// assignment was not yet received (network throttled/unavailable), or the
    /// crash bypassed the standard handler (e.g. `__fastfail`).
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT BucketId([out, retval] LPWSTR* value);

    /// Time the crash report was recorded, as a Windows FILETIME value
    /// (100-nanosecond intervals since Jan 1 1601 UTC). Zero if unavailable.
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT ReportTime([out, retval] UINT64* value);
}

/// A continuation of the ICoreWebView2ProcessFailedEventArgs4 interface
/// for getting the crash report associated with the process failure.
[uuid(1d8e2f4a-3c6b-4f7d-9a1e-5b8c2d3e4f60), object, pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs5
    : ICoreWebView2ProcessFailedEventArgs4 {
    /// The crash report for this process failure, or null if the failure
    /// did not produce a report (normal exit, external kill, launch
    /// failure, hang).
    // MSOWNERS: core (wvcore@microsoft.com)
    [propget] HRESULT CrashReport(
        [out, retval] ICoreWebView2CrashReport** value);
}
```

## WinRT and .NET

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2CrashReport
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2CrashReport")]
        {
            String   CrashReportId         { get; };
            UInt32   ExceptionCode         { get; };
            String   FaultingModuleName    { get; };
            String   FaultingModuleVersion { get; };
            UInt64   FaultOffset           { get; };
            String   BucketId              { get; };
            // Projected from the COM FILETIME (UINT64).
            Windows.Foundation.DateTime ReportTime { get; };
        }
    }

    runtimeclass CoreWebView2ProcessFailedEventArgs
    {
        // ... existing members ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ProcessFailedEventArgs5")]
        {
            CoreWebView2CrashReport CrashReport { get; };
        }
    }
}
```

# Appendix

## Relationship to existing APIs

| API | Purpose |
| --- | --- |
| `ProcessFailedEventArgs5.CrashReport` _(this API)_ | Crash identity and signature at failure time. |
| [`ProcessFailed`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2#add_processfailed) | Real-time recovery signal (kind, reason, exit code). |
| [`BrowserProcessExited`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2environment5#add_browserprocessexited) | Browser process exit notification (lifecycle, no CrashReport). |
| [`IsCustomCrashReportingEnabled`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2environmentoptions3#get_iscustomcrashreportingenabled) | Disables upload to Microsoft's telemetry service. Minidump is still written locally; `CrashReport` is populated but `BucketId` will be empty. |
| [`FailureReportFolderPath`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2environment11#get_failurereportfolderpath) | Dump folder. Use `CrashReportId` to find the dump file. |

## Privacy

All fields in `CrashReport` are technical crash-signature values with no user-identifying signal:

| Field | Notes | PII Risk |
| --- | --- | --- |
| `CrashReportId` | Random UUID; no user-identifying signal. | None |
| `ExceptionCode`, `FaultOffset` | Technical values; identical across users for the same crash. | None |
| `FaultingModuleName` | Basename only; never a full path. | None |
| `FaultingModuleVersion` | Public version string. | None |
| `BucketId` | Hex string identifier assigned by Microsoft's crash telemetry service; no user data. May be empty. | None |
| `ReportTime` | Timestamp of the crash; identical precision to OS event logs. No user-identifying signal. | None |
