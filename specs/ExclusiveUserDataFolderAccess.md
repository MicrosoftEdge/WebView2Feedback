# Background
WebViews which use the same user data folder can share browser processes. The `ExclusiveUserDataFolderAccess` property specifies that the WebView environment obtains exclusive access to the user data folder. If the user data folder is already being used by another WebView environment, the WebView creation will fail. Setting exclusive data folder access therefore has the effect of preventing the browser processes from being shared with WebViews associated with other WebView environments.

# Description
The `ExclusiveUserDataFolderAccess` property specifies whether other WebViews can be created with the same user data folder. Setting exclusive access prevents the WebView browser processes from being shared with those belonging to other environments because sharing occurs only between instances that use the same user data folder and the same exclusive access setting.
Default is FALSE.

# Examples
## Win32 C++
```cpp
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    // Don't allow any other WebView environments to use the same user data folder.
    // This prevents other processes from sharing WebView browser process instances with our WebView.
    CHECK_FAILURE(options->put_ExclusiveUserDataFolderAccess(TRUE));
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

  /// Whether other processes can create WebView2 from WebView2Environment created with the
  /// same user data folder and therefore sharing the same WebView browser process instance.
  /// Default is FALSE.
  [propget] HRESULT ExclusiveUserDataFolderAccess([out, retval] BOOL* value);

  /// Sets the `ExclusiveUserDataFolderAccess` property.
  /// The `ExclusiveUserDataFolderAccess` property specifies that the WebView environment
  /// obtains exclusive access to the user data folder.
  /// If the user data folder is already being used by another WebView environment with
  /// different value for `ExclusiveUserDataFolderAccess` property, the creation of WebView2Controller
  /// using the environmen object will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// When set as TRUE, no other WebView can be created from other process using WebView2Environment
  /// objects with the same UserDataFolder. This prevents other processes from creating WebViews
  /// which share the same browser process instance, since sharing is performed among
  /// WebViews that have the same UserDataFolder. When another process tries to create
  /// WebView2Controller from an WebView2Environment object created with the same user data folder,
  /// it will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// Exclusive data folder access also opens optimization opportunities, such as more aggressive
  /// CPU reduction for suspended WebViews.
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
