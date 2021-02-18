# Background
WebView2 provides applications with the [ProcessFailed](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed) event so they can react accordingly when a process failure occurs. However, this event does not currently provide additional information about the process failure, nor does it cover the cases in which only subframes within the CoreWebView2 are impacted by the failure, or the cases in which a process other than the browser/render process fails.

In this document we describe an extended version of the [PROCESS_FAILED_KIND](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#corewebview2_process_failed_kind) enum, which covers the new scenarios in which the event is raised: frame-only render process failure, and process failures for processes other than the browser/render process. We also include a new version of the [ProcessFailedEventArgs](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.705.50) that enables the host application to collect additional information about the process failure for their logging and telemetry purposes.

The updated API is detailed below. We'd appreciate your feedback.


# Description
We propose to add new cases for which the `ProcessFailed` event is raised:
  1. When a frame-only render process fails. Only subframes within the `CoreWebView2` are impacted in this case (the content is gone and replaced with a "sad face" layer).
  2. When a WebView2 Runtime child process other than the browser process or a render process fails. The app can use these process failures for logging and telemetry purposes.

We also propose extending the `ProcessFailedEventArgs` to provide additional information about the process failure:
  * Reason of the failure.
  * Exit code.
  * Process description.
  * Impacted frames for (1) above.


# Examples
The following code snippets demonstrate how the `ProcessFailedEventArgs2` can be used by the host application:

## Win32 C++
```cpp
```

## .NET C#
```xml
```

```c#
```


# Remarks
* `ProcessFailedKind` in the event args will be `RENDER_PROCESS_EXITED` if the failed process is the main frame's renderer, even if there were subframes rendered by such process. All frames are gone when this happens and `ImpactedFrames` will be `null` as the attribute is intended for frame-only renderer failures only.

* `Reason` in the event args is always `UNEXPECTED` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `UNRESPONSIVE` when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.

* `ExitCode` is always `1` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.


# API Notes
See [API Details](#api-details) section below for API reference.

* Triple-slash (`///`) comments will appear in the public API documentation.
* Double-slash (`//`) comments are notes for this review only and will not show in public documentation.


# API Details
## COM
```cpp
```

## .NET and WinRT
```c#
```
