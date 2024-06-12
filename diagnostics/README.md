# Gathering Diagnostics and Logs
This folder contains directions for gathering various detailed diagnostics/logs when reporting WV2-related issues. There's generally no need to proactively get any of these diagnostics before opening an issue, but if one seems obvious feel free to get it before opening an issue. Otherwise, a WV2 developer might link you to one of these pages to help them investigate an issue:

- [Crash Dumps](crash.md): Crash dumps are used to better understand why a WV2 process is crashing and firing a [ProcessFailed](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2.processfailed) event.
- [ETW Trace](etw.md): Event Tracing for Windows (ETW) traces include detailed events on system state and the activities WV2 was doing before and when an issue occurs.
- [Installer Logs](install.md): Installer logs include information about any errors that WV2's installer/updater hit when trying to install or update the WV2 runtime.
- [GPU Info](gpu.md): GPU logs include details on the user's GPU and any potential graphics or rendering issues.
- [Network Logs](network.md): Network logs include the network requests, responses, and details on any errors when loading files.
- [Code Integrity](code_integrity.md): how to root cause STATUS_INVALID_IMAGE_HASH errors.
- [Test in Canary](test_canary.md): how to test new WebView2 runtime changes by using Edge Canary.
