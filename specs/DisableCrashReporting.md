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

var _processed_dump_files = new HashSet<string>();

void WebView_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
{
    // When process failed, do custom parsing with dumps
    string failureReportFolder = webView.CoreWebView2.Environment.FailureReportFolderPath;
    string[] dump_files = Directory.GetFiles(failureReportFolder);
    foreach (string dump_file in dump_files) {
        if (!_processed_dump_files.Contains(dump_file)) {
            _processed_dump_files.Add(dump_file);
            ProcessNewCrashDumps(dump_file);
        }
    }
}

```
## Win32 C++
```cpp
#include <filesystem>
using namespace std;
namespace fs = std::filesystem;

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

    std::set<fs::path> processed_dump_files;
	
	// Register a handler for the ProcessFailed event.
    CHECK_FAILURE(m_webView->add_ProcessFailed(
        Callback<ICoreWebView2ProcessFailedEventHandler>(
            [this, processed_dump_files, 
            failureReportFolder = std::move(failureReportFolder)](
                ICoreWebView2* sender,
                ICoreWebView2ProcessFailedEventArgs* argsRaw) -> HRESULT
            {
                for (const auto& entry: fs::directory_iterator(failureReportFolder.get()))
                {
                    auto dump_file = entry.path().filename();
                    if (processed_dump_files.count(dump_file) == 0)
                    {
                        processed_dump_files.insert(dump_file);
                        ProcessNewCrashDumps(dump_file);
                    }
                }
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
  /// `FailureReportFolderPath` get the folder path of where minidump files is written.
  /// Whenever a WebView2 process crashes, a crash dump file will be created in the crash dump folder.
  /// A crash dump format is minidump files, please see 
  /// https://learn.microsoft.com/windows/win32/debug/minidump-files for detailed documentation. 
  /// Normally when a single child process failed, a minidump will be generated and written to disk, 
  /// then `ProcessFailed` event is raised. But for unexpected crashes, minidump might not be generated 
  /// at all, despite whether `ProcessFailed` event is raised. For times, that there are multiple 
  /// processes failed, multiple minidump files could be generated. Thus `FailureReportFolderPath` 
  /// could contain old minidump files that are not associated with a specific `ProcessFailed` event. 
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

