# Figuring out SDK and runtime version

SDK and runtime verion number of WebView2 is helpful for someone who is trying to reproduce a bug. The follow options are ways for you to obtain the version numbers of the host app.

### Option 1: Use WebView2 Utilities (SDK and runtime)
An easy way to obtain the SDK and runtime version for any host app that is currently running, is to use [WebView2Utilities](https://github.com/david-risney/WebView2Utilities).

### Option 2a: Check NuGet Package Manager (SDK only)
If you are a developer for the WebView2 application, on Visual Studio Code, go to `Tools > NuGet Package Manager > Manage NuGet Packages for Solution`, and see the SDK version that is being used for the project

### Option 2b: Check WebView2 child process of host app (Runtime only)
For any application, to check the which WebView2 runtime is being used, do the following:

1. Open Task Manager
2. Right click on the WebView2 process of the application you are interested in
3. Click on Open File Location

The directory of the file location is the WebView2 runtime version
