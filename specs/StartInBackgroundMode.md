StartInBackgroundMode
===

# Background
By default, WebView2 instances get created with some priorities set higher, assuming the WV2 is being created in the foreground for an important purpose. However, not every developer wants to boost the WebView2 prelaunch phase at the cost of utilizing more system resources. The `StartInBackgroundMode` property specifies that whether WebView2 created with launch boost or not.


# Description
Setting `StartInBackgroundMode` to TRUE will signal WebView2 to start in a 'background mode' which will attempt to use less system resources during the creation and initial load. Default is FALSE.

# Examples
## Win32 C++
```cpp
auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
options->put_StartInBackgroundMode(TRUE));
HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
  nullptr, m_userDataFolder.c_str(), options.Get(),
  Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
     this, &AppWindow::OnCreateEnvironmentCompleted).Get());
```
## WinRT and .NET
```c#
auto options = new CoreWebView2EnvironmentOptions();
options.StartInBackgroundMode = true;
auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
```


# API Details
## Win32 C++
```cpp
interface ICoreWebView2StagingEnvironmentOptions3 : IUnknown 
{
  /// Setting `StartInBackgroundMode` to `TRUE` will signal WebView2 to start in a 'background mode'
  /// which will attempt to use less system resources during the creation and initial load.
  /// Default is FALSE.
  [propget] HRESULT StartInBackgroundMode([out, retval] BOOL* value);
  /// Sets the `StartInBackgroundMode` property.
  [propput] HRESULT StartInBackgroundMode ([in] BOOL value);
}
```
## WinRT and .NET
```c#
unsealed runtimeclass CoreWebView2EnvironmentOptions
{
    bool StartInBackgroundMode { get; set; };
}
```