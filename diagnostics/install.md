# Installer / Setup Logs
Installer logs include information about any errors that WV2's installer/updater hit when trying to install or update the WV2 runtime. There are a few different logs that we need to best look in to any issues.

## Registry Key
This registry contains important update information like when the last update occurred, recent error codes, and updater version information.
1. Open `regedit.exe`
2. Find `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate`
3. Select it, click "File" and choose "Export..."
4. Name it `registryoutput.txt`, change "Save as Type" to .txt, and ensure "Selected branch" is the path from step #2.
5. Click Save.

## Installer Logs
There are three places where WV2's updater will write potentially important logs:

1. `C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log`
2. `%localappdata%\Temp\MicrosoftEdgeUpdate.log`
3. `C:\Windows\Temp\msedge_installer.log`

If you don't have all three of these, that's not a problem.

## List of Installed WV2 Files
Finally, including a list of all the files installed by WV2 will let us understand if there is something missing in your installation causing the issue.
1. Open a command prompt.
2. Run `dir /s /b "c:\Program Files (x86)\Microsoft\EdgeWebView\" > edgefiles.txt` this creates `edgefiles.txt` with the list of files.

Once you have all five of these files: `registryoutput.txt`, `msedge_installer.log`, `edgefiles.txt`, and the two `MicrosoftEdgeUpdate.log`s, share them with the WV2 developer who is helping you.