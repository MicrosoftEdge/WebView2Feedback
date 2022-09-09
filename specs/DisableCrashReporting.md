Process Info
===

# Background
Currently, when a WebView2 is created a WebView2 crashpad process will be created in addition to starting a WebView2 browser process. If any WebView2 process crashes, the crashpad process will create crash dumps and send them to Microsoft for diagnosis. This document covers new APIs to allow the end developer to customize crash reporting to help when running diagnostics and doing analysis. They can set the `CoreWebView2EnvironmentOptions.IsCustomCrashReportingEnabled` property to not have crash dumps sent to Microsoft and use the `CoreWebView2Environment.CrashDumpFolderPath` property to locate crash dumps and do customization with them instead.

# Examples
## WinRT and .NET   
```c#

/// Create WebView Environment with option
void CreateEnvrionmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.IsCustomCrashReportingEnabled = true;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}

void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    webView.CoreWebView2.ProcessFailed += WebView_ProcessFailed;
}

void WebView_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
{
    // When process failed, do custom parsing with dumps
    string crashDumpFolder = webView.CoreWebView2.Environment.CrashDumpFolderPath;
    ProcessNewCrashDumps(_crashDumpFolder);
}

```
## Win32 C++
```cpp
void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CHECK_FAILURE(options->put_IsCustomCrashReportingEnabled(TRUE));
    // ... other option properties

    // ... CreateCoreWebView2EnvironmentWithOptions
}

void AppWindow::ProcessFailed()
{
    // Get dump folder path
    wil::com_ptr<ICoreWebView2Environment11> environment;
    wil::unique_cotaskmem_string crashDumpFolder;
    CHECK_FAILURE(environment->get_CrashDumpFolderPath(&crashDumpFolder));
	
	// Register a handler for the ProcessFailed event.
    CHECK_FAILURE(m_webView->add_ProcessFailed(
        Callback<ICoreWebView2ProcessFailedEventHandler>(
            [this, &crashDumpFolder](ICoreWebView2* sender, ICoreWebView2ProcessFailedEventArgs* argsRaw)
                -> HRESULT {
                // Custom processing
				ProcessNewCrashDumps(crashDumpFolder);
                return S_OK;
            })
            .Get(),
        &m_processFailedToken));
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
  /// environment are using. Whenever a WebView2 process crashes, 
  /// a crash dump file will be created in the crash dump folder.
  /// A crash dump format is minidump files, please see
  /// https://docs.microsoft.com/en-us/windows/win32/debug/minidump-files for 
  /// detail documentation.
  /// `ProcessFailed` event are raised everytime a crash happens, minidump files 
  /// will be written to disk at that time. Developers can rely on `ProcessFailed` and 
  /// `CrashDumpFolderPath` to customize crash dump experiences.
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT CrashDumpFolderPath([out, retval] LPWSTR* value);
}

/// Additional options used to create WebView2 Environment.
[uuid(3FB94506-58AB-4171-9082-E7D683471A48), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : ICoreWebView2EnvironmentOptions2 {

  /// When `IsCustomCrashReportingEnabled` is set to `TRUE`, Windows won't send crash data to Microsoft endpoint.
  /// `IsCustomCrashReportingEnabled` is default to be `FALSE`, in this case, WebView respect OS consent. 
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT IsCustomCrashReportingEnabled([out, retval] BOOL* value);

  /// Sets the `IsCustomCrashReportingEnabled` property.
  // MSOWNERS: xiaqu@microsoft.com
  [propput] HRESULT IsCustomCrashReportingEnabled([in] BOOL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        Boolean IsCustomCrashReportingEnabled { get; set; };
    }

    runtimeclass CoreWebView2Environment
    {
        String CrashDumpFolderPath { get; };
    }

    // ...
}
```

