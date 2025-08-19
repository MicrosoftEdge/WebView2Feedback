# Gathering Diagnostics and Logs

This folder contains directions for gathering various detailed diagnostics/logs when reporting WV2-related issues. There's generally no need to proactively get any of these diagnostics before opening an issue, but if one seems obvious feel free to get it before opening an issue. Otherwise, a WV2 developer might link you to one of these pages to help them investigate an issue.

| Tool / Log                | Purpose                                                                 | Use Case                                                                 |
|---------------------------|-------------------------------------------------------------------------|--------------------------------------------------------------------------|
| [Crash Dumps](crash.md)               | Capture crash data for WebView2 processes.                              | Used when a child process crashes (via ProcessFailed event) or browser process fails. |
| [Memory Dumps (Task Manager)](task_manager_dump.md)| Manual memory capture for unresponsive processes.                      | Helpful when WebView2 hangs or becomes non-responsive.                   |
| [ETW Trace](etw.md)                 | Event Tracing for Windows logs detailed system and WebView2 activity.   | Used to analyze system state and WebView2 behavior before/during issues. |
| [Installer Logs](install.md)            | Logs errors encountered during WebView2 runtime installation or updates.| Diagnose installation failures or update issues.                         |
| [GPU Info](gpu.md)                  | Provides details about the GPU and rendering pipeline.                  | Useful for troubleshooting graphics-related problems.                    |
| [Network Logs](network.md)              | Records network requests, responses, and errors.                        | Diagnose issues with loading resources or connectivity failures.         |
| [Code Integrity](code_integrity.md)            | Identifies root causes of `STATUS_INVALID_IMAGE_HASH` errors.           | Used when encountering image hash validation failures.                   |
| [Test in Canary](test_canary.md)            | Allows testing of WebView2 runtime changes using Edge Canary builds.    | Preview and validate fixes or features before stable release.            |
| [Procmon (Process Monitor)](procmon.md) | Logs file and registry access events.                                   | Useful for diagnosing file not found or access denied errors.            |
| [Time Travel Debugging (TTD)](ttd.md)  | Captures detailed call stacks and execution sequences.                                        | Ideal for deep debugging when other logs are insufficient.                 |
 