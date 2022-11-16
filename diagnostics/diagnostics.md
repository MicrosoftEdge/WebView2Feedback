This file goes over some common steps for gathering more information to help us look into issues you may be facing with the WebView2 controls.

## Crash Dumps
If a crash occurs, the dumps can usually be found in the app's user data folder:
<code><user data folder>\EBWebView\Crashpad\reports</code>
The <user data folder> is created in the app's folder by default:
<code><app folder>\<app name>.exe.WebView2</code>
But apps can specify different user data folders. If they do, they generally know where it is.
  
## Graphics and GPU info
Issues where the WebView2 isn't displaying anything are most often caused by a launch failure, such as un-writeable user data folder, mismatched DPI awareness, or missing files (runtime or binaries). However, if the WebView2 has launched correctly (you can check return values and task manager) but the content is not there, then it might be due to a hosting and/or GPU driver issue.
1. Get the output of `edge://gpu` (wait for the page to load the 'log messages' section at the bottom).
1. Get DirectX diagnostic info
    1. Run `dxdiag` from a console window
    1. Once the dialog displays and is done capturing info (small progress bar) hit the **Save All Information** button to save the info to a dxdiag.txt file
    1. Share the `dxdiag.txt` file
  
## Network Logs
https://textslashplain.com/2020/01/17/capture-network-logs-from-edge-and-chrome/ 
  
https://textslashplain.com/2020/04/08/analyzing-network-traffic-logs-netlog-json/
  
https://dev.chromium.org/for-testers/providing-network-details

Can also get traces:
Navigate to `about:tracing`and use with the `Edge developer (navigation)` profile

## Installer / Setup Logs
1. Export the EdgeUpdate Key to a reg file via regedit
  
`HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate`
  
2. Edge Update and installer logs
  
`C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log`
`%localappdata%\Temp\MicrosoftEdgeUpdate.log`
`C:\Windows\Temp\msedge_installer.log`
  
3. Grab all the files on disk for Edge - the below command will do the trick and create edgefiles.txt
  
`dir /s /b "c:\Program Files (x86)\Microsoft\EdgeWebView\" > edgefiles.txt`

## ETW Trace
One of the best ways to help us understand when something is going wrong like failures to create WV2 or other unexpected behaviors is an [Event Tracing for Windows (ETW)](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/event-tracing-for-windows) trace. This repo has a WV2 recording profile - [WebView2.wprp](WebView2.wprp) that includes the events that we find most useful. 

ETW traces can get fairly large, so try to keep the amount of extra time spent when recording as small as possible. We also recommend closing any other apps using WV2 to make the trace more clear. Common apps using WV2 may include `widgets.exe`, `msteams.exe`, and Microsoft Office products.

To get an ETW trace:
1. Download [WebView2.wprp](WebView2.wprp) from this repo.
2. In an elevated command prompt run `wpr -start WebView2.wppr -filemode` (wpr.exe is included in Windows)
3. Reproduce the issue.
4. In an elevated command prompt run `wpr -stop trace.etl "trace"`.

ETW traces can contain sensitive information, if you're concerned with sharing one publicly in a GitHub issue, you can ask the WV2 developer you're working with for an email address to send to them privately.