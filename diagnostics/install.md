# Installer / Setup Logs
1. Export the EdgeUpdate Key to a reg file via regedit
  
`HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate`
  
2. Edge Update and installer logs
  
`C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log`
`%localappdata%\Temp\MicrosoftEdgeUpdate.log`
`C:\Windows\Temp\msedge_installer.log`
  
3. Grab all the files on disk for Edge - the below command will do the trick and create edgefiles.txt
  
`dir /s /b "c:\Program Files (x86)\Microsoft\EdgeWebView\" > edgefiles.txt`