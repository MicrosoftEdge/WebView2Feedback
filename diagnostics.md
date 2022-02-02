This file goes over some common steps for gathering more information to help us look into issues you may be facing with the WebView2 controls.

## Crash Dumps
If a crash occurs, the dumps can usually be found in the app's user data folder:
<code><user data folder>\EBWebView\Crashpad\reports</code>
The <user data folder> is created in the app's folder by default:
<code><app folder>\<app name>.exe.WebView2</code>
But apps can specify different user data folders. If they do, they generally know where it is.
  
## Traces
Sometimes issues don't cause a crash, but something still doesn't behave as expected. Or perhaps it manifest as bad performance, slow loading, etc. In these cases you can ask for traces that can be examined.

### Collecting TTD traces from customer environment
Some issues are reproducible only in customer environment and require a TTD trace from that environment. The instructions below might need to be re-tried until a successful trace is collected.
> Cmd windows (A) and (B) can be the same, but if so, the window needs to be started as admin from the beginning.

1. Force `--no-sandbox` for renderer processes (collecting traces for renderer processes requires this flag)
   **Option (1)** - From cmd (A):
   > SET WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--no-sandbox
     SET WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS

   **Option (2)** - From settings:
   Edit system environment variables / Environment variables… / New…
   Make sure to click "OK" on both settings windows.

1. Create directory for dumps
   Make sure it's not in a network location (network locations have paths starting with `\\`)

1. Start trace recording
   Launch admin cmd (B), then run
   ```
   tttracer -bg -dumpFull -parent * -onlaunch msedgewebview2.exe -out <dumps-dir>
   ```
   **Note:** this is the external version of `tttrace` in `C:\Windows\System32` which ships with Windows. No additional setup should be required to use it.

1. Reproduce the issue
   * If option (1) was used on step (1) above, make sure the launching app is restarted.
   * If option (2) was used on step (1) above, launch the app from the same cmd window (A) where the environment variable was set.

1. Stop trace recording
   ```
   tttracer /stop all
   tttracer /cleanup
   tttracer /delete all
   ```

* Verify collected trace hits the issue. If it doesn't, go through steps 2-5 again (use a different directory for step 3). Retries might be faster.
* Send all files in successful trace dumps directory for analysis.
  
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
