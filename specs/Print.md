
Print API
===

# Background

Developers have requested the ability to programmatically print the current page optionally using a print dialog in WebView2. Currently the end user can open a print preview dialog by pressing "Ctrl+ P" or selecting "Print" from the context menu in a document or can open the system print dialog by pressing
"Ctrl + Shift + P" or clicking the "Print using system dialog" link in the print preview dialog. This API gives developers the ability to open the print dialog without requiring the end user interaction and also can print without a dialog to a specific printer by configuring the print settings.

You can use `CoreWebView2.PrintToPdfAsync` API to print a current page as a pdf file to disk and then use native printing APIs to print the document to a specific printer. However, this API requires the PDF to be printed to the disk which can be prohibitive at times for some financial customers if the printed information is sensitive and also printing to printer without a dialog requires additional effort on the developers for cross platform apps.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose following API's

**Print API**: This API gives developers the ability to open a browser print preview dialog or system print dialog without requiring the end user interaction. This API consists of a Print method and can either open a browser print preview dialog or system print dialog based on COREWEBVIEW2_PRINT_DIALOG_KIND value.

**Print without a print dialog**: This API gives developers the ability to print the current page without a print dialog to the specific printer. This API consists of an asynchronous PrintWithSettings method and a PrintSettings2 object.
PrintSettings2 object extends PrintSettings to support printing to a printer.

**Print to PDF Stream**: This API gives developers printable PDF data, which can be used as a preview in a custom print preview dialog. This API consists of an asynchronous PrintToPdfStream method and a PrintSettings2 object.


# Examples
## Print

You can use the `Print` method to programmatically open a print dialog without end user interaction. Currently devs are using JavaScript `window.print()` using the `CoreWebView2.ExecuteScriptAsync` API to invoke the
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
         // Opens the browser print preview dialog.
         webView.CoreWebView2.Print();
     }
     else
     {
         // Opens the system print dialog.
         webView.CoreWebView2.Print(CoreWebView2PrintDialogKind.SystemPrint);
     }
}
```

## PrintWithSettings

You can use `PrintWithSettings` method to print to a specific printer without a print dialog. You can programatically configure print settings using `CreatePrintSettings`, and call `PrintWithSettings` to print the current page.

// This example prints the current page without a print dialog to the specified printer with the settings.

```cpp
bool AppWindow::PrintWithSettings()
{
    TextInputDialog dialog(
        GetMainWindow(), L"Printer Name", L"Printer Name:",
        L"Specify printer name as understood by the OS.", L"");
    if (dialog.confirmed)
    {
        wil::com_ptr<ICoreWebView2_15> webView2_15;
        CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
        CHECK_FEATURE_RETURN(webView2_15);

        wil::com_ptr<ICoreWebView2Environment6> webviewEnvironment6;
        CHECK_FAILURE(m_webViewEnvironment->QueryInterface(IID_PPV_ARGS(&webviewEnvironment6)));
        CHECK_FEATURE_RETURN(webviewEnvironment6);

        wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
        CHECK_FAILURE(webviewEnvironment6->CreatePrintSettings(&printSettings));

        wil::com_ptr<ICoreWebView2PrintSettings2> printSettings2;
        CHECK_FAILURE(printSettings->QueryInterface(IID_PPV_ARGS(&printSettings2)));
        CHECK_FEATURE_RETURN(printSettings2);

        CHECK_FAILURE(printSettings2->put_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT));
        CHECK_FAILURE(printSettings2->put_PageWidth(8.5));
        CHECK_FAILURE(printSettings2->put_PageHeight(11));
        CHECK_FAILURE(printSettings2->put_ShouldPrintBackgrounds(true));
        CHECK_FAILURE(printSettings2->put_PagesPerSheet(1));
        CHECK_FAILURE(printSettings2->put_QualityHorizontal(600));
        CHECK_FAILURE(printSettings2->put_QualityVertical(600));
        CHECK_FAILURE(printSettings2->put_PrinterName((dialog.input).c_str()));

        CHECK_FAILURE(webView2_15->PrintWithSettings(
            printSettings2.get(), Callback<ICoreWebView2PrintWithSettingsCompletedHandler>(
                                 [this](HRESULT errorCode) -> HRESULT
                                 {
                                     AsyncMessageBox(
                                         (errorCode == S_OK) ? L"Print to printer succeeded"
                                                             : L"Print to printer failed",
                                         L"Print to printer");
                                     return S_OK;
                                 })
                                 .Get()));
    }
    return true;
}
```

```c#
async void PrintWithSettings()
{
    var dialog = new TextInputDialog(
                        title: "Printer Name",
                        description: "Specify printer name as understood by the OS.",
                        defaultInput: "");
    if (dialog.ShowDialog() == true)
    {
        CoreWebView2PrintSettings printSettings = null;
        printSettings = WebViewEnvironment.CreatePrintSettings();
        printSettings.Orientation = CoreWebView2PrintOrientation.Portrait;
        printSettings.PageWidth = 8.5;
        printSettings.PageHeight = 11;
        printSettings.ShouldPrintBackgrounds = true;
        printSettings.PagesPerSheet = 1;
        printSettings.QualityHorizontal = 600;
        printSettings.QualityVertical = 600;
        printSettings.PrinterName = dialog.Input.Text;

        await webView.CoreWebView2.PrintWithSettingsAsync(printSettings);
            MessageBox.Show(this, "Printing is succeeded", "Print with Settings");
    }
}
```

## PrintToPdfStream

You can use `PrintToPdfStream` method to display as a preview in a custom print dialog. The app can also use this API to configure the custom print preview dialog unlike confining print preview dialog to the webview2 control.

// This example prints the Pdf data of the current page to a stream.

```cpp
// Function to display current page pdf data in a custom print preview dialog.
static void DisplayPdfDataInPrintDialog(IStream* pdfData)
{
    // You can display the printable pdf data in a custom print preview dialog to the end user.
}

bool AppWindow::PrintToPdfStream()
{
    wil::com_ptr<ICoreWebView2_15> webView2_15;
    CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
    CHECK_FEATURE_RETURN(webView2_15);

    wil::com_ptr<ICoreWebView2Environment6> webviewEnvironment6;
    CHECK_FAILURE(m_webViewEnvironment->QueryInterface(IID_PPV_ARGS(&webviewEnvironment6)));
    CHECK_FEATURE_RETURN(webviewEnvironment6);

    wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
    CHECK_FAILURE(webviewEnvironment6->CreatePrintSettings(&printSettings));

    wil::com_ptr<ICoreWebView2PrintSettings2> printSettings2;
    CHECK_FAILURE(printSettings->QueryInterface(IID_PPV_ARGS(&printSettings2)));
    CHECK_FEATURE_RETURN(printSettings2);

    CHECK_FAILURE(printSettings2->put_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT));
    CHECK_FAILURE(printSettings2->put_ShouldPrintBackgrounds(true));

    CHECK_FAILURE(
        webView2_15->PrintToPdfStream(
            printSettings2.get(),
            Callback<ICoreWebView2PrintToPdfStreamCompletedHandler>(
                [this](HRESULT errorCode, IStream* pdfData) -> HRESULT
                {
                    CHECK_FAILURE(errorCode);
                    DisplayPdfDataInPrintDialog(pdfData);
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
    printSettings = WebViewEnvironment.CreatePrintSettings();
    printSettings.Orientation = CoreWebView2PrintOrientation.Portrait;
    printSettings.ShouldPrintBackgrounds = true;

    MemoryStream pdfStream = new MemoryStream();
    System.IO.Stream stream = await webView.CoreWebView2.PrintToPdfStreamAsync(printSettings);
    DisplayPdfDataInPrintDialog(pdfData);
    MessageBox.Show(this, "Print to PDF Stream succeeded", "Print To PDF Stream");
}

// Function to display current page pdf data in a custom print preview dialog.
void DisplayPdfDataInPrintDialog(Stream pdfData)
{
    // You can display the printable pdf data in a custom print preview dialog to the end user.
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
  /// `PrintWithSettings` is called while a `PrintWithSettings` or `PrintToPdf` or `PrintToPdfStream` or `Print`
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
  /// `PrintToPdfStream` is called while a `PrintToPDFStream` or `PrintToPdf` or `PrintWithSettings` or `Print`
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
  /// Page range to print. Defaults to empty string, which means print all pages.
  ///
  /// The PageRanges property is a list of page ranges specifying one or more pages that should be printed separated by commas. Any whitespace between page ranges is ignored.
  /// A valid page range is either a single integer identifying the page to print, or a range in the form `[start page]-[last page]` where `start page` and `last page` are integers identifying the first and last inclusive pages respectively to print. Every page identifier is an integer
  /// greater than 0 unless wildcards are used (see below examples). The first page is 1.
  ///
  /// In a page range of the form `[start page]-[last page]` the start page number must be larger than 0 and less than or equal to the document's total page count.
  /// If the `start page` is not present, then 1 is used as the `start page`.
  /// The `last page` must be larger than the `start page`.
  /// If the `last page` is not present, then the document total page count is used as the `last page`.
  ///
  /// If page range is not valid or if a page is greater than document total page count,
  /// `ICoreWebView2PrintWithSettingsCompletedHandler` handler will return `E_ABORT`.
  ///
  /// |       Example       | Valid |               Notes                   |
  /// "2"                   |  Yes  | Assuming document total page count >= 2.
  /// "1-4, 9, 3-6, 10, 11" |  Yes  | Assuming document total page count >= 11.
  /// "1-4, -6"             |  Yes  | Assuming document total page count >= 6.
  /// "2-"                  |  Yes  | Assuming document total page count >= 2, means from 2 to the * end.
  /// "4-2, 11, -6"         |  No   |
  ///  "-"                  |  Yes  | Assuming document total page count >= 1.
  ///  "1-4dsf, 11"         |  No   | Regardless of document total page count.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PageRanges([out, retval] LPWSTR* value);

  /// Set the `PageRanges` property.
  [propput] HRESULT PageRanges([in] LPCWSTR value);

  /// Number of pages per sheet. Minimum value is `1` and the maximum is `16`.
  /// The default value is 1
  [propget] HRESULT PagesPerSheet([out, retval] INT32* value);

  /// Set the `PagesPerSheet` property. Returns `E_INVALIDARG` if an invalid value is
  /// provided, and the current value is not changed.
  [propput] HRESULT PagesPerSheet([in] INT32 value);

  /// Number of copies to print. Minimum value is `1` and the maximum copies count is `999`.
  /// The default value is 1.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Copies([out, retval] INT32* value);

  /// Set the `Copies` property. Returns `E_INVALIDARG` if an invalid value is provided
  /// and the current value is not changed.
  [propput] HRESULT Copies([in] INT32 value);

  /// True if the printed document should be collated. The default value is `FALSE`.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT ShouldCollate([out, retval] BOOL* value);

  /// Set the `ShouldCollate` property.
  [propput] HRESULT ShouldCollate([in] BOOL value);

  /// True if the print should be in color, otherwise prints in black and white.
  /// The default value is `TRUE`.
  [propget] HRESULT IsColor([out, retval] BOOL* value);

  /// Set the `IsColor` property.
  [propput] HRESULT IsColor([in] BOOL value);

  /// Printer's duplex settings. See `COREWEBVIEW2_PRINT_SIDE` for descriptions
  /// of print sides. The default value is `COREWEBVIEW2_PRINT_SIDE_SINGLE`.
  /// This property is ignored by the PrintToPdf and PrintToPdfStream methods.
  [propget] HRESULT PrintSide([out, retval] COREWEBVIEW2_PRINT_SIDE* value);

  /// Set the `PrintSide` property.
  [propput] HRESULT PrintSide([in] COREWEBVIEW2_PRINT_SIDE value);

  /// The horizontal printer resolution for the page, in dots per inch.
  /// The default value is 600.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT QualityHorizontal([out, retval] INT32* value);

  /// Set the `QualityHorizontal` property.
  [propput] HRESULT QualityHorizontal([in] INT32 value);

  /// The vertical printer resolution for the page, in dots per inch.
  /// The default value is 600.
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT QualityVertical([out, retval] INT32* value);

  /// Set the `QualityVertical` property.
  [propput] HRESULT QualityVertical([in] INT32 value);

  /// The name of the printer to use. Defaults to empty string.
  /// If the printer name is empty string or null, then it prints to the default printer on the OS.
  /// This value is ignored in PrintToPdfStream method.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PrinterName([out, retval] LPWSTR* value);

  /// Set the `PrinterName` property. If provided printer name doesn't match with the name of any printers on the OS,
  /// `ICoreWebView2PrintWithSettingsCompletedHandler` handler will return `E_ABORT`.
  [propput] HRESULT PrinterName([in] LPCWSTR value);
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

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2PrintSettings2")]
        {
            // ICoreWebView2PrintSettings2 members
            String PageRanges { get; set; };
            Int32 PagesPerSheet { get; set; };
            Int32 Copies { get; set; };
            Boolean ShouldCollate { get; set; };
            Boolean IsColor { get; set; };
            CoreWebView2PrintSide PrintSide { get; set; };
            Int32 QualityHorizontal { get; set; };
            Int32 QualityVertical { get; set; };
            String PrinterName { get; set; };
        }
    }

    runtimeclass CoreWebView2
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_15")]
        {
            void Print(CoreWebView2PrintDialogKind printDialogKind);
            void Print();

            Windows.Foundation.IAsyncAction PrintWithSettings(CoreWebView2PrintSettings printSettings);

            Windows.Foundation.IAsyncOperation<Windows.Storage.Streams.IRandomAccessStream> PrintToPdfStreamAsync(CoreWebView2PrintSettings printSettings);
        }
    }
}
```
