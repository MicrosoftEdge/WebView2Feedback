# Gathering an ETW Trace
[Event Tracing for Windows (ETW)](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/event-tracing-for-windows)traces include detailed events on system state and the activities WV2 was doing before and when an issue occurs.

This repo has a WV2 recording profile - [WebView2.wprp](WebView2.wprp) that includes the events that we find most useful. 

ETW traces can get fairly large, so try to keep the amount of extra time spent when recording as small as possible.

1. Close Edge and any other apps using WV2 to make the trace more clear. Common apps using WV2 may include `widgets.exe`, `msteams.exe`, and Microsoft Office products.
1. Download [WebView2.wprp](WebView2.wprp) from this repo.
2. In an elevated command prompt run `wpr -start WebView2.wppr -filemode` (wpr.exe is included in Windows)
3. Reproduce the issue.
4. In an elevated command prompt run `wpr -stop trace.etl "trace"`.

ETW traces can contain sensitive information, if you're concerned with sharing one publicly in a GitHub issue, you can ask the WV2 developer you're working with for an email address to send to them privately.