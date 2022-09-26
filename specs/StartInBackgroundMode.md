CreationPriority
===

# Background
WebView2 has a functionality enabled by default which raises the launch priority of WV2
processes to ensure that WV2 processes are given higher CPU priority and access to resources 
while creation, and that can bring improvements on time spent creating a WV2 instance. Since 
this improvement is at the cost of taking higher CPU priority, we introduce `CreationPriority` 
property to give developers an option to decide by themselves.

# Description
* Setting `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_NORMAL` will signal WebView2 
to use less system resources during the creation. 
* Setting `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_HIGH` will attempt to enable 
the launch time improvement functionality with raising the launch priority during the creation.  
* Default value is `COREWEBVIEW2_CREATION_PRIORITY_HIGH`.
## Notes
* The host app's priority is at least normal before applying the launch time improvement functionality. 
Else, WebView2 still get created with normal priority even with `COREWEBVIEW2_CREATION_PRIORITY_HIGH` 
setting.
* Currently launch time improvement functionality is only enabled for WebView2 manager process, so the 
`CreationPriority` only effects the creation of manager process. `CreationPriority` can play the same 
role for other process types like render process if WebView2 opts in launch time improvement functionality 
for those types in the future.
# Examples
## Win32 C++
```cpp
auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
// Set `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_NORMAL` if you don't want to boost the 
// launch time at the cost of using higher CPU priority during the launch phase.
options->put_CreationPriority(COREWEBVIEW2_CREATION_PRIORITY_NORMAL);
HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
  nullptr, m_userDataFolder.c_str(), options.Get(),
  Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
     this, &AppWindow::OnCreateEnvironmentCompleted).Get());
```
## WinRT and .NET
```c#
CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
options.CreationPriority = COREWEBVIEW2_CREATION_PRIORITY_NORMAL;
CoreWebView2Environment Environment = 
    await CoreWebView2Environment.CreateAsync(
        BrowserExecutableFolder, UserDataFolder, options)
```


# API Details
## Win32 C++
```cpp
/// Specifies the type of webview2 creation priority for the
/// `ICoreWebView2EnvironmentOptions3:CreationPriority` option.
[v1_enum]
typedef enum COREWEBVIEW2_CREATION_PRIORITY {
  COREWEBVIEW2_CREATION_PRIORITY_NORMAL,
  COREWEBVIEW2_CREATION_PRIORITY_HIGH,
} COREWEBVIEW2_CREATION_PRIORITY;

[uuid(efb58776-32bd-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : ICoreWebView2EnvironmentOptions2 {

  /// Gets the creation priority for webview2 creation.
  ///
  /// \snippet AppWindow.cpp CreateCoreWebView2EnvironmentWithOptions
  // MSOWNERS: wangsongjin@microsoft.com
  [propget] HRESULT CreationPriority([out, retval] COREWEBVIEW2_CREATION_PRIORITY* creationPriority);

  /// Sets the `CreationPriority` property.
  /// The `CreationPriority` property specifies that the creation priority WebView
  /// environment attempt to create.
  /// Set `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_NORMAL` will create
  /// WebView2 with normal priority.
  /// Set `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_HIGH` will attempt
  /// to create WebView2 with high priority.
  /// Default is `COREWEBVIEW2_CREATION_PRIORITY_HIGH`.
  // MSOWNERS: wangsongjin@microsoft.com
  [propput] HRESULT CreationPriority([in] COREWEBVIEW2_CREATION_PRIORITY creationPriority);
}
```
## WinRT and .NET
```c#
namespace Microsoft.Web.WebView2.Core
{
  enum CoreWebView2CreationPriority
  {
      Normal = 0,
      High = 1,
  };

  runtimeclass CoreWebView2EnvironmentOptions
  {
      
      // ...
      [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions3")]
      {
          
          CoreWebView2CreationPriority CreationPriority { get; set; };

      }
  }
}
```