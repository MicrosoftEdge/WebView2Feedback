
Print API
===

# Background

Developers have requested the ability to programmatically print the current page optionally using a print dialog in WebView2. Currently the end user can open a print preview dialog by pressing "Ctrl+ P" or selecting "Print" from the context menu in a document or can open the system print dialog by pressing 
"Ctrl + Shift + P" or clicking the "Print using system dialog" link in the print preview dialog. This API gives developers the ability to open the print dialog without requiring the end user interaction and also can print without a dialog to a specific printer by configuring the print settings. 

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose following API's 

**Print API**: This API gives developers the ability to open a browser print preview dialog or system print dialog without requiring the end user interaction. This API consists of a Print method and can either open a browser print preview dialog or system print dialog based on COREWEBVIEW2_PRINT_DIALOG_KIND value.

**Print without a print dialog**: This API gives developers the ability to print the current page without a print dialog to the specific printer. This API consists of an asynchronous PrintWithSettings method and a PrintSettings2 object. 
PrintSettings2 object extends PrintSettings to support printing to a printer.

**Print to PDF Stream**: This API gives developers printable PDF data, which can be used as a preview in a custom print preview dialog. This API consists of an asynchronous PrintToPdfStream method and a PrintSettings2 object. 


# Examples
## Print

You can use `Print` method to programmatically open a print dialog without end user interaction. Currently devs are using Javascript window.print() using WebView2 ExecuteScriptAsync api to invoke
browser print preview dialog. But there isn't a way to invoke open the system print dialog programmatically nor will `window.print()` work if script is disabled on the page, or the document is a PDF or other non-HTML document.

// This example shows the user a print dialog. If `printDialogKind` is COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER_PRINT_PREVIEW, opens a browser print preview dialog, otherwise opens a system print dialog.       
```cpp
bool AppWindow::OpenPrintDialog(COREWEBVIEW2_PRINT_DIALOG_KIND printDialogKind)
{
     wil::com_ptr<ICoreWebView2_15> webView2_15;
     CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
     CHECK_FEATURE_RETURN(webView2_15);
     CHECK_FAILURE(webView2_15->Print(printDialogKind));
     return true;
}
```

```c#
void OpenPrintDialog(object target, ExecutedRoutedEventArgs e)
{
     string printDialog = e.Parameter.ToString();
     if (printDialog == "PrintPreview")
     {
         webView.CoreWebView2.Print(CoreWebView2PrintDialogKind.BrowserPrintPreview);
     }
     else
     {
         webView.CoreWebView2.Print(CoreWebView2PrintDialogKind.SystemPrint);
     }
}
```

## PrintWithSettings

You can use `PrintWithSettings` method to print to a specific printer without a print dialog. You can programatically configure print settings using `CreatePrintSettings2`, and call `PrintWithSettings` to print the current page.

// This example prints the current page without a print dialog to the `Microsoft Print To PDF` printer with the settings.

```cpp
bool AppWindow::PrintWithSettings()
{
    wil::com_ptr<ICoreWebView2_15> webView2_15;
    CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
    CHECK_FEATURE_RETURN(webView2_15);

    wil::com_ptr<ICoreWebView2PrintSettings2> printSettings = nullptr;

    wil::com_ptr<ICoreWebView2Environment11> webviewEnvironment11;
            CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                IID_PPV_ARGS(&webviewEnvironment11)));
    CHECK_FEATURE_RETURN(webviewEnvironment11);

    CHECK_FAILURE(webviewEnvironment11->CreatePrintSettings2(&printSettings));
    CHECK_FAILURE(printSettings->put_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT));
    CHECK_FAILURE(printSettings->put_PageWidth(8.5));
    CHECK_FAILURE(printSettings->put_PageHeight(11));
    CHECK_FAILURE(printSettings->put_ShouldPrintBackgrounds(true));
    CHECK_FAILURE(printSettings->put_PagesPerSheet(1));
    CHECK_FAILURE(printSettings->put_QualityHorizontal(600));
    CHECK_FAILURE(printSettings->put_QualityVertical(600));;
    CHECK_FAILURE(printSettings->put_PrinterName(L"Microsoft Print To PDF"));

    CHECK_FAILURE(webView2_15->PrintWithSettings(
            printSettings.get(),
            Callback<ICoreWebView2PrintWithSettingsCompletedHandler>(
                                 [this](HRESULT errorCode) -> HRESULT
                                 {
                                     AsyncMessageBox(
                                         (errorCode == S_OK) ? L"Print to printer succeeded" : L"Print to printer failed",
                                         L"Print to printer");
                                     return S_OK;
                                 })
                                 .Get()));
     return true;
}
```

```c#
async void PrintWithSettings()
{
    CoreWebView2PrintSettings printSettings = null;
    printSettings = WebViewEnvironment.CreatePrintSettings2();
    printSettings.Orientation = CoreWebView2PrintOrientation.Portrait;
    printSettings.PageWidth = 8.5;
    printSettings.PageHeight = 11;
    printSettings.ShouldPrintBackgrounds = true;
    printSettings.PagesPerSheet = 1;
    printSettings.QualityHorizontal = 600;
    printSettings.QualityVertical = 600;
    printSettings.PrinterName = "Microsoft Print To PDF";

    await webView.CoreWebView2.PrintWithSettingsAsync(printSettings);
            MessageBox.Show(this, "Printing is succeeded", "Print with Settings");
}
```

## PrintToPdfStream

You can use `PrintToPdfStream` method to display as a preview in a custom print dialog. The app can also use this API to configure the custom print preview dialog unlike confining print preview dialog to the webview2 control.

// This example prints the Pdf data of the current page to a stream.
        
```cpp
bool AppWindow::PrintToPdfStream()
{
    wil::com_ptr<ICoreWebView2_15> webView2_15;
    CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
    CHECK_FEATURE_RETURN(webView2_15);

    wil::com_ptr<ICoreWebView2PrintSettings2> printSettings = nullptr;

    wil::com_ptr<ICoreWebView2Environment11> webviewEnvironment11;
            CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                IID_PPV_ARGS(&webviewEnvironment11)));
    CHECK_FEATURE_RETURN(webviewEnvironment11);

    CHECK_FAILURE(webviewEnvironment->CreatePrintSettings2(&printSettings));
    CHECK_FAILURE(printSettings->put_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT));
    CHECK_FAILURE(printSettings->put_ShouldPrintBackgrounds(true));

    CHECK_FAILURE(
        webView2_15->PrintToPdfStream(
            printSettings.get(),
            Callback<ICoreWebView2PrintToPdfStreamCompletedHandler>(
                [this](HRESULT errorCode, IStream* pdfData) -> HRESULT
                {
                    CHECK_FAILURE(errorCode);
                    AsyncMessageBox(
                        (errorCode == S_OK) ? L"Print to PDF Stream succeeded"
                                   : L"Print to PDF Stream failed",
                        L"Print to PDF Stream");
                    return S_OK;
                })
                .Get()));
     return true;
}
```

```c#
async void PrintToPdfStream()
{
    CoreWebView2PrintSettings printSettings = null;
    printSettings = WebViewEnvironment.CreatePrintSettings2();
    printSettings.Orientation = CoreWebView2PrintOrientation.Portrait;
    printSettings.ShouldPrintBackgrounds = true;

    MemoryStream pdfStream = new MemoryStream();
    System.IO.Stream stream = await webView.CoreWebView2.PrintToPdfStreamAsync(printSettings);
    MessageBox.Show(this, "Print to PDF Stream succeeded", "Print To PDF Stream");
}
```

# API Details

## Win32 C++
``` cpp
/// Specifies the print dialog kind.
[v1_enum] 
typedef enum COREWEBVIEW2_PRINT_DIALOG_KIND {
  /// Opens the browser print preview dialog.
  COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER_PRINT_PREVIEW,

  /// Opens the system print dialog.
  COREWEBVIEW2_PRINT_DIALOG_KIND_SYSTEM_PRINT,

} COREWEBVIEW2_PRINT_DIALOG_KIND;

/// Specifies the printing side.
[v1_enum] 
typedef enum COREWEBVIEW2_PRINT_SIDE {
  /// Single-sided printing.
  COREWEBVIEW2_PRINT_SIDE_SINGLE,

  /// Double-sided, horizontal printing.
  COREWEBVIEW2_PRINT_SIDE_BOTH_HORIZONTAL,

  /// Double-sided, vertical printing.
  COREWEBVIEW2_PRINT_SIDE_BOTH_VERTICAL,

} COREWEBVIEW2_PRINT_SIDE;

[uuid(92269C88-1CC1-47E0-9A87-71458409BA15), object, pointer_default(unique)]
interface ICoreWebView2_15 : ICoreWebView2_14 {
  /// Print the current page asynchronously to the specified printer with the provided settings.
  /// See `ICoreWebView2PrintSettings2` for description of settings. The handler will return `E_ABORT`
  /// if `printerName` is empty or null or invalid or invalid settings for a given printer.
  /// 
  /// The async `PrintWithSettings` operation completes when it finishes 
  /// printing to the printer. At this time the `ICoreWebView2SPrintWithSettingsCompletedHandler` 
  /// is invoked. Only one `Printing` operation can be in progress at a time. If
  /// `PrintWithSettings` is called while a `PrintWithSettings` or `PrintToPdf` or `PrintToPdfStream` 
  /// job is in progress, the completed handler is immediately invoked with an error.
  ///
  /// \snippet AppWindow.cpp PrintWithSettings
  HRESULT PrintWithSettings(
    [in] ICoreWebView2PrintSettings2* printSettings,
    [in] ICoreWebView2PrintWithSettingsCompletedHandler* handler);

  /// Opens the print dialog to print the current page. See `COREWEBVIEW2_PRINT_DIALOG_KIND` 
  /// for descriptions of print dialog kinds.
  /// The default value is `COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER_PRINT_PREVIEW`.
  /// 
  /// \snippet AppWindow::OpenPrintDialog
  HRESULT Print([in] COREWEBVIEW2_PRINT_DIALOG_KIND printDialogKind);

  /// Provides the Pdf data of current page asynchronously for the provided settings.
  /// See `ICoreWebView2PrintSettings2` for description of settings. Passing
  /// nullptr for `printSettings` results in default print settings used.
  ///
  /// The async `PrintToPdfStream` operation completes when it finishes 
  /// writing to the stream. At this time the `ICoreWebView2PrintToPdfStreamCompletedHandler` 
  /// is invoked. Only one `Printing` operation can be in progress at a time. If
  /// `PrintToPdfStream` is called while a `PrintToPDFStream` or `PrintToPdf` or `PrintWithSettings` 
  /// job is in progress, the completed handler is immediately invoked with an error.
  ///
  /// \snippet AppWindow.cpp PrintToPdfStream
  HRESULT PrintToPdfStream([in] ICoreWebView2PrintSettings2* printSettings,
                           [in] ICoreWebView2PrintToPdfStreamCompletedHandler* handler);
}

/// Receives the result of the `PrintWithSettings` method.
/// `errorCode` returns S_OK if the PrintWithSettings operation succeeded.
[uuid(4B2FE043-1A1A-4924-803D-C05E5FDCA3B0), object, pointer_default(unique)]
interface ICoreWebView2PrintWithSettingsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method. 
  HRESULT Invoke([in] HRESULT errorCode);
}

/// Receives the result of the `PrintToPdfStream` method.
/// `errorCode` returns S_OK if the PrintToPdfStream operation succeeded.
/// The printable pdf data is returned in the `pdfStream` object.
[uuid(78A9FC37-249B-4E7E-A2E6-20CAAA14AE7B), object, pointer_default(unique)]
interface ICoreWebView2PrintToPdfStreamCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] IStream* pdfStream);
}

/// Settings used by the `PrintWithSettings` method.
[uuid(DA3AD25C-D121-44DC-83DA-BF5E50DBF0DF), object, pointer_default(unique)]
interface ICoreWebView2PrintSettings2 : ICoreWebView2PrintSettings {
  /// Page range to print, e.g., `1-5, 8, 11-13`. Defaults to empty string,
  /// which means print all pages. Invalid pages are ignored.
  /// 
  /// The caller must free the returned string with `CoTaskMemFree`. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PageRanges([out, retval] LPWSTR* value);

  /// Set the `PageRanges` property.
  [propput] HRESULT PageRanges([in] LPCWSTR value);

  /// Number of pages per sheet. The Default value is 1 and maximum is 16.
  [propget] HRESULT PagesPerSheet([out, retval] INT32* value);

  /// Set the `PagesPerSheet` property. Returns `E_INVALIDARG` if an invalid value is
  /// provided, and the current value is not changed.
  [propput] HRESULT PagesPerSheet([in] INT32 value);

  /// Number of copies to print. The Default value is 1 and maximum 
  /// copies count is 999. 
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Copies([out, retval] INT32* value);

  /// Set the `Copies` property. Returns `E_INVALIDARG` if an invalid value is provided 
  /// for the specified printer, and the current value is not changed.
  [propput] HRESULT Copies([in] INT32 value);

  /// Collate of the printer. The default value is `FALSE`. 
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Collate([out, retval] BOOL* value);

  /// Set the `Collate` property.
  [propput] HRESULT Collate([in] BOOL value);

  /// Color of the print. The default value is `TRUE`.
  [propget] HRESULT IsColor([out, retval] BOOL* value);

  /// Set the `Color` property.
  [propput] HRESULT IsColor([in] BOOL value);

  /// Printer's duplex settings. See `COREWEBVIEW2_PRINT_SIDE` for descriptions 
  /// of print sides. The default value is `COREWEBVIEW2_PRINT_SIDE_SINGLE`. 
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT PrintSide([out, retval] COREWEBVIEW2_PRINT_SIDE* value);

  /// Set the `PrintSide` property.
  [propput] HRESULT PrintSide([in] COREWEBVIEW2_PRINT_SIDE value);

  /// The horizontal printer resolution for the page, in dots per inch.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT QualityHorizontal([out, retval] INT32* value);

  /// Set the `QualityHorizontal` property. If an invalid value is provided 
  /// for the specified printer, `ICoreWebView2PrintWithSettingsCompletedHandler`
  /// handler will return `E_ABORT`.
  [propput] HRESULT QualityHorizontal([in] INT32 value);

  /// The vertical printer resolution for the page, in dots per inch.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT QualityVertical([out, retval] INT32* value);

  /// Set the `QualityVertical` property. If an invalid value is provided 
  /// for the specified printer, `ICoreWebView2PrintWithSettingsCompletedHandler`
  ///  handler will return `E_ABORT`.
  [propput] HRESULT QualityVertical([in] INT32 value);

  /// The name of the printer to use.
  /// This value is ignored in PrintToPdfStream method.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PrinterName([out, retval] LPWSTR* value);

  /// Set the `PrinterName` property. If provided printer is empty or null or invalid,
  /// `ICoreWebView2PrintWithSettingsCompletedHandler` handler will return `E_ABORT`.
  [propput] HRESULT PrinterName([in] LPCWSTR value);
}

/// This interface is an extension of the ICoreWebView2Environment that supports
/// creating print settings for printing with settings and printing to PDF.
[uuid(7A9CF5B6-3BDC-4C9D-A1BE-B512C9B2E74F), object, pointer_default(unique)]
interface ICoreWebView2Environment : IUnknown
{
  /// Creates the `ICoreWebView2PrintSettings2` used by the `PrintWithSettings` 
  /// and `PrintToPdfStream` method.
  HRESULT CreatePrintSettings2(
      [out, retval] ICoreWebView2PrintSettings2** printSettings);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2PrintSettings;
    runtimeclass CoreWebView2;

    enum CoreWebView2PrintSide
    {
        Single = 0,
        BothHorizontal = 1,
        BothVertical = 2,
    };

    enum CoreWebView2PrintDialogKind
    {
        BrowserPrintPreview = 0,
        SystemPrint = 1,
    };

    runtimeclass CoreWebView2PrintSettings
    {
        // ICoreWebView2PrintSettings members
        CoreWebView2PrintOrientation Orientation { get; set; };
        Double ScaleFactor { get; set; };
        Double PageWidth { get; set; };
        Double PageHeight { get; set; };
        Double MarginTop { get; set; };
        Double MarginBottom { get; set; };
        Double MarginLeft { get; set; };
        Double MarginRight { get; set; };
        Boolean ShouldPrintBackgrounds { get; set; };
        Boolean ShouldPrintSelectionOnly { get; set; };
        Boolean ShouldPrintHeaderAndFooter { get; set; };
        String HeaderTitle { get; set; };
        String FooterUri { get; set; };

        {
            // ICoreWebView2StagingPrintSettings2 members
            String PageRanges { get; set; };
            Int32 PagesPerSheet { get; set; };
            Int32 Copies { get; set; };
            Boolean IsCollate { get; set; };
            Boolean IsColor { get; set; };
            CoreWebView2PrintSide PrintSide { get; set; };
            Int32 QualityHorizontal { get; set; };
            Int32 QualityVertical { get; set; };
            String PrinterName { get; set; };
        }
    }

    runtimeclass CoreWebView2Environment
    {
       CoreWebView2PrintSettings CreatePrintSettings2();
    }

    runtimeclass CoreWebView2Settings
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_15")]
        {
            // This is only for the .NET API, not the WinRT API.
            void Print(CoreWebView2PrintDialogKind printDialogKind);

            // This is only for the .NET API, not the WinRT API.
            Windows.Foundation.IAsyncAction PrintWithSettings(CoreWebView2PrintSettings printSettings);

            Windows.Foundation.IAsyncOperation<Windows.Storage.Streams.IRandomAccessStream> PrintToPdfStreamAsync(CoreWebView2PrintSettings printSettings);
        }
    }
}
```