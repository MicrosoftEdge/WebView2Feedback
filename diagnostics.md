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
1. Get a trace (instructions above)
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
1. **Export the EdgeUpdate Key to a reg file via regedit**
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate
1. **Edge Update and installer logs** 
C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log
C:\Windows\Temp\msedge_installer.log
1. **Grab all the files on disk for Edge** - the below command will do the trick and create edgefiles.txt
dir /s /b "c:\Program Files (x86)\Microsoft\EdgeWebView\" > edgefiles.txt
