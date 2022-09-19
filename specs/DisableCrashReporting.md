Custom Crash Reports
===

# Background
If any WebView2 process crashes, one or multiple minidump files will be created and sent to Microsoft for diagnosis. This document covers new APIs to allow the end developer to customize crash reporting to help when running diagnostics and doing analysis. They can set the `CoreWebView2EnvironmentOptions.IsCustomCrashReportingEnabled` property to true to prevent crash dumps from being sent to Microsoft and use the `CoreWebView2Environment.CrashDumpFolderPath` property to locate crash dumps and do customization with them instead.

# Examples
## WinRT and .NET   
```c#

/// Create WebView Environment with option
void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.CustomizeFailureReporting = true;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}

void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    webView.CoreWebView2.ProcessFailed += WebView_ProcessFailed;
}

void WebView_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
{
    // When process failed, do custom parsing with dumps
    string failureReportFolder = webView.CoreWebView2.Environment.FailureReportFolderPath;
    ProcessNewCrashDumps(failureReportFolder);
}

```
## Win32 C++
```cpp
void AppWindow::InitializeWebView()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CHECK_FAILURE(options->put_CustomizeFailureReporting(TRUE));
    // ... other option properties

    // ... CreateCoreWebView2EnvironmentWithOptions

    // Set up handler
    wil::com_ptr<ICoreWebView2Environment> environment;
    CHECK_FAILURE(m_webView->get_Environment(&environment));
    wil::com_ptr<ICoreWebView2Environment11> environment11;
    CHECK_FAILURE(environment->QueryInterface(IID_PPV_ARGS(&environment11));
    wil::unique_cotaskmem_string failureReportFolder;
    CHECK_FAILURE(environment11->get_FailureReportFolderPath(&failureReportFolder));
	
	// Register a handler for the ProcessFailed event.
    CHECK_FAILURE(m_webView->add_ProcessFailed(
        Callback<ICoreWebView2ProcessFailedEventHandler>(
            [this, failureReportFolder = std::move(failureReportFolder)](ICoreWebView2* sender, ICoreWebView2ProcessFailedEventArgs* argsRaw)
                -> HRESULT {
                // Custom processing
				ProcessNewCrashDumps(failureReportFolder.get());
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
  /// `FailureReportFolderPath` to customize crash dump experiences.
  /// `FailureReportFolderPath` remains the same for the lifetime of the environment.
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT FailureReportFolderPath([out, retval] LPWSTR* value);
}

/// Additional options used to create WebView2 Environment.
[uuid(3FB94506-58AB-4171-9082-E7D683471A48), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : ICoreWebView2EnvironmentOptions2 {

  /// When `CustomizeFailureReporting` is set to `TRUE`, Windows won't send crash data to Microsoft endpoint.
  /// `CustomizeFailureReporting` is default to be `FALSE`, in this case, WebView respect OS consent. 
  // MSOWNERS: xiaqu@microsoft.com
  [propget] HRESULT CustomizeFailureReporting([out, retval] BOOL* value);

  /// Sets the `CustomizeFailureReporting` property.
  // MSOWNERS: xiaqu@microsoft.com
  [propput] HRESULT CustomizeFailureReporting([in] BOOL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    
    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        Boolean CustomizeFailureReporting { get; set; };
    }

    runtimeclass CoreWebView2Environment
    {
        String FailureReportFolderPath { get; };
    }

    // ...
}
```

