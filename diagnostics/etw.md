# Gathering an ETW Trace
[Event Tracing for Windows (ETW)](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/event-tracing-for-windows)traces include detailed events on system state and the activities WV2 was doing before and when an issue occurs.

This repo has two WebView2 recording profiles:

1. **[WebView2_CPU.wprp](resources/WebView2_CPU.wprp) [Recommended]**: This is the default recording profile that captures most of the useful events for diagnosing WebView2 issues, including CPU sampling data. Use this profile for most scenarios.

2. **[WebView2.wprp](resources/WebView2.wprp)**: This profile is recommended when you need to capture longer scenarios and the size of the ETW traces becomes too large. It excludes some data (like CPU sampling data) to produce smaller trace files.

ETW traces can get fairly large, so try to keep the recording time as short as possible while still capturing the issue. If you need a longer trace, ask the WebView2 developer you're working with if `WebView2.wprp` will suffice.

1. Close Edge and any other apps using WV2 to make the trace more clear. Common apps using WV2 may include `widgets.exe`, `msteams.exe`, and Microsoft Office products.
2. Download [WebView2_CPU.wprp](resources/WebView2_CPU.wprp) from this repo.
3. **Optional**: If your app has a specific profile, merge it with [WebView2_CPU.wprp](resources/WebView2_CPU.wprp) to ensure all events are captured in a single ETL file.
4. In an elevated command prompt run `wpr -start WebView2_CPU.wprp -filemode` (wpr.exe is included in Windows).
5. Reproduce the issue.
6. In an elevated command prompt run `wpr -stop trace.etl "trace"`.

ETW traces can contain sensitive information, if you're concerned with sharing one publicly in a GitHub issue, you can ask the WV2 developer you're working with for an email address to send to them privately.
