CreationPriority
===

# Background
WebView2 has functionality enabled by default which raises the launch priority of WebView2
processes to ensure that WebView2 processes are given higher CPU priority and access to resources
during creation, and that can bring improvements on time spent creating a WebView2 instance. Since 
this improvement is at the cost of taking higher CPU priority, we introduce the `CreationPriority` 
property to give developers an option to decide by themselves.

# Description
* Setting `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_NORMAL` will signal WebView2 
to have normal priority compared to other processes during the creation of the WebView2 browser 
process.
* Setting `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_HIGH` will attempt to enable 
raise the priority of the creation of the WebView2 browser process.
* Default value is `COREWEBVIEW2_CREATION_PRIORITY_HIGH`.
# Examples
## Win32 C++
```cpp
auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
/// Set webView2 browser process to have normal priority during creation, 
/// which avoids to impact other host application processes acquiring 
/// system resources.
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
  /// The `CreationPriority` property specifies the priority used during the WebView2 
  /// browser process creation.
  /// Set `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_NORMAL` will create the
  /// WebView2 browser process with normal priority.
  /// Set `CreationPriority` to `COREWEBVIEW2_CREATION_PRIORITY_HIGH` will attempt to
  /// create the WebView2 browser process with high priority.
  /// Default is `COREWEBVIEW2_CREATION_PRIORITY_HIGH`.
  /// Note that 1)The host app's priority must be at least normal for 
  /// `COREWEBVIEW2_CREATION_PRIORITY_HIGH` to be applied. Else, the WebView2 browser process 
  /// still get created with normal priority even with `COREWEBVIEW2_CREATION_PRIORITY_HIGH` setting.
  /// 2)Currently `CreationPriority` only applies to the creation of the WebView2 browser process.
  /// `CreationPriority` may be broadened to apply to other parts of WebView2 creation in the future.
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