# Test Feature in Canary

The latest runtime changes are first shipped in the WebView2 runtime in the Edge Canary Browser. If you would like to test the new changes with your application, here's a suggested way to do so:

1. Download [Edge Canary](https://www.microsoft.com/en-us/edge/download/insider)
2. Run the following command in a PowerShell with Administrative Priviledges:  
  `REG ADD HKCU\Software\Policies\Microsoft\Edge\WebView2\ChannelSearchKind /v <your_app.exe> /t REG_DWORD /d 1`
3. Restart your application, and you should be able to see that your application picks up the latest runtime. 

To remove the registry key added, run the following:  
`REG DELETE HKCU\Software\Policies\Microsoft\Edge\WebView2\ChannelSearchKind`

For more information, read the documentation on [Test upcoming APIs and features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/set-preview-channe)
