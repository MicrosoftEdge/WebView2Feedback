Process Info
===

# Background
Currently, when a WebView2 is created a WebView2 crashpad process will be created in addition to starting a WebView2 browser process. If any WebView2 process crashes, the crashpad process will create crash dumps and send them to Microsoft for diagnosis. This document covers new APIs to allow the end developer to customize crash reporting. They can set the `CoreWebView2EnvironmentOptions.IsCustomCrashReportingEnabled` property to not have crash dumps sent to Microsoft and use the `CoreWebView2Environment.CrashDumpFolderPath` property to locate crash dumps and do whatever they like with them instead.

# Examples
## WinRT and .NET   
```c#

/// Create WebView Environment with option
auto options = new CoreWebView2EnvironmentOptions();
options.DisableCrashReporting = true;
auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);

/// Webview creation and setup of completion handler are out of scope of sample
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // Get the crash dump folder
        String crashDumpFolder = webView.CoreWebView2.Environment.CrashDumpFolder();
    }
}

```
## Win32 C++
```cpp
void AppWindow::ToggleCrashReportingUploadConsent()
{
    // Disable crash report
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CHECK_FAILURE(options->put_DisableCrashReporting(TRUE));
}

void AppWindow::GetCrashDumpFolder()
{
    // Get crashpad folder path  
    wil::com_ptr<ICoreWebView2Environment11> environment;
    wil::unique_cotaskmem_string crashPadPath;
    CHECK_FAILURE(environment->get_CrashDumpFolder(&crashPadPath));
}
```

# API Details    
```
interface ICoreWebView2Environment11;
interface ICoreWebView2EnvironmentOptions3;

/// A continuation of the ICoreWebView2Environment interface for
/// getting the crash dump folder path
[uuid(F619312E-0399-4520-B700-30818441785A), object, pointer_default(unique)]
interface ICoreWebView2Environment11 : ICoreWebView2Environment10 {
  /// Get the crash dump folder that all CoreWebView2's from this
  /// environment are using. Whenever a WebView2 process crashes, a crash dump file will be created in the crash dump folder.
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT CrashDumpFolder([out, retval] LPWSTR* value);
}

/// Additional options used to create WebView2 Environment.
[uuid(3FB94506-58AB-4171-9082-E7D683471A48), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : ICoreWebView2EnvironmentOptions2 {

  /// When `DisableCrashReporting` is set to `TRUE`, Windows won't send crash data to Microsoft endpoint.
  /// `DisableCrashReporting` is default to be `FALSE`, in this case, WebView respect OS consent. 
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT DisableCrashReporting([out, retval] BOOL* value);

  /// Sets the `DisableCrashReporting` property.
  // MSOWNERS: xiaqu@microsoft.com
  [propput] HRESULT DisableCrashReporting([in] BOOL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        Boolean DisableCrashReporting { get; set; };
    }

    runtimeclass CoreWebView2Environment
    {
        String CrashDumpFolderPath { get; };
    }

    // ...
}
```

