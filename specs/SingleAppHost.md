# Background
While WebViews from different app processes normally don't share the same WebView browser process instance, app processes from the same product suite may share the same webview browser process
instance by specifying the same user data folder when creating WebView2Environment object.
The `ExclusiveUserDataFolderAccess` property is for the developer to express the sharing intent, so that we could provide optimized security and performance according expected usage.

# Description
The `ExclusiveUserDataFolderAccess` property indicates whether other processes can create WebView2 sharing the same WebView browser process instance by using WebView2Environment created with the same user data folder.
Default is FALSE.

# Examples
## Win32 C++
```cpp
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    // Don't expect any other process to share the WebView browser process instance.
    CHECK_FAILURE(options->put_ExclusiveUserDataFolderAccess(TRUE);
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        nullptr, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted).Get());
```
## WinRT and .NET
```c#
auto options = new CoreWebView2EnvironmentOptions();
options.ExclusiveUserDataFolderAccess = true;
auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
```

# Remarks
See API details.

# API Details
## Win32 C++
```cpp
interface ICoreWebView2EnvironmentOptions_2 : IUnknown
{

  /// Whether other processes can create WebView2 sharing the same WebView browser
  /// process instance by using WebView2Environment created with the same user data folder.
  /// Default is FALSE.
  [propget] HRESULT ExclusiveUserDataFolderAccess([out, retval] BOOL* value);

  /// Sets the `ExclusiveUserDataFolderAccess` property.
  /// When set as TRUE, no other process can create WebView sharing the same browser
  /// process instance. When another process tries to create WebView2Controller from
  /// an WebView2Environment objct created with the same user data folder, it will fail
  /// with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// When the same user data folder is used, if there is already a WebView running,
  /// creating a WebView using WebView2Environment object with a different value for
  /// this property from that of the WebView2Environment object of the existing WebView
  /// will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// When set to TRUE, `TrySuspend` could potentially do more optimization on reducing
  /// CPU usage for suspended WebViews.
  [propput] HRESULT ExclusiveUserDataFolderAccess([in] BOOL value);

}

```
## WinRT and .NET
```c#
unsealed runtimeclass CoreWebView2EnvironmentOptions
{
    // ..
    bool ExclusiveUserDataFolderAccess { get; set; };
}
```
