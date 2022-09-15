CreationPriority
===

# Background
WebView2 has a functionality enabled by default which raises the launch priority of WV2 processes to ensure that WV2 processes are given higher CPU priority and access to resources while creation, and that can bring improvements on time spent creating a WV2 instance. Since this improvement is at the cost of taking higher CPU priority, we introduce `CreationPriority` property to give developers an option to decide by themselves.

# Description
* Setting `CreationPriority` to `CreationPriority::NORMAL` will signal WebView2 to use less system resources during the creation. 
* Setting `CreationPriority` to `CreationPriority::HIGH` will attempt to enable the launch time improvement functionality with raising the launch priority during creation.  
* `CreationPriority::DEFAULT` is the default value, we treat it as same as `CreationPriority::HIGH`.
## Notes
* Your application needs to verify that the version of Edge is >=95 before applying the `CreationPriority`, it can cause issues if used on earlier versions of Edge.
* A prerequisitive for WebView2 applying the launch time improvement is the host app's priority is at least normal. Else, WebView2 still get created with normal priority even with `CreationPriority::HIGH`.
* Currently launch time improvement functionality is only enabled for WebView2 manager process, so the `CreationPriority` only effect the creation of manager process. `CreationPriority` can play the same role for other process types like render process if WebView2 opts in launch time improvement functionality for those types in the future.
# Examples
## Win32 C++
```cpp
auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
options->put_CreationPriority(CreationPriority::NORMAL);
HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
  nullptr, m_userDataFolder.c_str(), options.Get(),
  Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
     this, &AppWindow::OnCreateEnvironmentCompleted).Get());
```
## WinRT and .NET
```c#
auto options = new CoreWebView2EnvironmentOptions();
options.CreationPriority = CreationPriority::NORMAL;
auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
```


# API Details
## Win32 C++
```cpp
[uuid(efb58776-32bd-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : ICoreWebView2EnvironmentOptions2 {

  /// Gets the creation priority for webview2 creation.
  // MSOWNERS: wangsongjin@microsoft.com
  [propget] HRESULT CreationPriority([out, retval] CreationPriority* creationPriority);

  /// Sets the `CreationPriority` property.
  /// The `CreationPriority` property` specifies that the creation priority WebView environment get created.
  /// WebView2 currernt has a functionality enabled by deafult which raises the launch priority to
  /// give improvements on the WebView2 creation time. Since this improvement is at the cost of occupying  
  /// higher CPU priority, we give developers options to decide by themselves.
  /// Set `CreationPriority` to `CreationPriority::NORMAL` will create WebView2 instances with normal priority 
  /// which opts out this functionality. 
  /// Set `CreationPriority` to `CreationPriority::HIGH` will try to launch WebView2 with above normal priority  
  /// and opt in this functionality.
  /// Set `CreationPriority` to `CreationPriority::DEFAULT` behaves the same way as `CreationPriority::HIGH`. 
  /// NOTE: A prerequisitive for WebView2 applying the launch time improvement is the host app's priority is
  /// at least normal. Else, WebView2 still get created with normal priority even with `CreationPriority::HIGH`.
  // MSOWNERS: wangsongjin@microsoft.com
  [propput] HRESULT CreationPriority([in] CreationPriority creationPriority);
}
```
## WinRT and .NET
```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...
    unsealed runtimeclass CoreWebView2EnvironmentOptions
    {
        enum CreationPriority { get; set; };
    }
```