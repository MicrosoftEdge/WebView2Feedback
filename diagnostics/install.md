# Installer / Setup Logs
Installer logs include information about any errors that WV2's installer/updater hit when trying to install or update the WV2 runtime. There are a few different logs that we need to best look in to any issues.

## Installer History & File List
There are some registry keys that contain important update information like when the last update occurred, recent error codes, and updater version information. The list of installed files that actually exist the device is also helpful in case there are errors or other processes removing them.

1. Open a command prompt.
2. Run `reg export HKCU\SOFTWARE\Microsoft\EdgeUpdate\ClientState EdgeRegistryUser.txt`
3. Run `reg export HKLM\SOFTWARE\Microsoft\EdgeUpdate\ClientState EdgeRegistryMachine.txt /reg:32`
4. Run `dir "c:\Program Files (x86)\Microsoft\EdgeWebView" /s > EdgeFiles.txt`
5. Run `dir "c:\Program Files (x86)\Microsoft\EdgeCore" /s >> EdgeFiles.txt`

You should now have three files: `EdgeRegistryUser.txt`, `EdgeRegistryMachine.txt`, and `EdgeFiles.txt`.

## Installer Logs
There are four places where WV2's updater will write important details about any install or update issues. If you don't have all of these that's not a problem, include what exists:

1. `C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log`
2. `%localappdata%\Temp\MicrosoftEdgeUpdate.log`
3. `%temp%\msedge_installer.log`
4. `%systemroot%\Temp\msedge_installer.log`
5. `%systemroot%\SystemTemp\msedge_installer.log`

Once you have these files, share them with the WV2 developer who is helping you.
