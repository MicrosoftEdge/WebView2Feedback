
Print API
===

# Background

Developers have requested the ability to programmatically print the current page optionally
using a print dialog in WebView2. Currently the end user can open a print preview dialog by
pressing "Ctrl+ P" or selecting "Print" from the context menu in a document or can open the
system print dialog by pressing "Ctrl + Shift + P" or clicking the "Print using system dialog"
link in the print preview dialog. This API gives developers the ability to open the print dialog
without requiring the end user interaction and also can print without a dialog to a specific
printer by configuring the print settings.

You can use `CoreWebView2.PrintToPdfAsync` API to print a current page as a pdf file to disk and
then use native printing APIs to print the document to a specific printer. However, this API
requires the PDF to be printed to the disk which can be prohibitive at times for some financia
customers if the printed information is sensitive and also printing to printer without a dialog
requires additional effort on the developers for cross platform apps.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose following APIs

**ShowPrintUI API**: This API gives developers the ability to open a browser print preview dialog or
system print dialog programmatically. This API consists of a ShowPrintUI method and can either open
a browser print preview dialog or system print dialog based on COREWEBVIEW2_PRINT_DIALOG_KIND value.

**Print**: This API gives developers the ability to print the current web page to the specific printer
without a print dialog. This API consists of an asynchronous Print method and a PrintSettings2 object.
PrintSettings2 object extends PrintSettings to support printing to a specific printer.

**Print to PDF Stream**: This API gives developers printable PDF data, which can be used as a preview
in a custom print preview dialog or print pdf data of current web page using native printer APIs.
This API consists of an asynchronous PrintToPdfStream method and a PrintSettings2 object.


# Examples
## ShowPrintUI

You can use the `ShowPrintUI` method to programmatically open a print dialog. Currently devs are
using JavaScript `window.print()` using the `CoreWebView2.ExecuteScriptAsync` API to invoke the
browser print preview dialog. But there isn't a way to invoke the system print dialog
programmatically nor will `window.print()` work if script is disabled on the page, or the
document is a PDF or other non-HTML document.

```cpp
// This example shows the user a print dialog. If `printDialogKind` is
// COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER, opens a browser print preview dialog,
// otherwise opens a system print dialog.

bool AppWindow::ShowPrintUI(COREWEBVIEW2_PRINT_DIALOG_KIND printDialogKind)
{
  wil::com_ptr<ICoreWebView2_15> webView2_15;
  CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));
  CHECK_FEATURE_RETURN(webView2_15);
  CHECK_FAILURE(webView2_15->ShowPrintUI(printDialogKind));
  return true;
}
```

```c#
void ShowPrintUI(object target, ExecutedRoutedEventArgs e)
{
  string printDialog = e.Parameter.ToString();
  if (printDialog == "Browser")
  {
    // Opens the browser print preview dialog.
    webView.CoreWebView2.ShowPrintUI();
  }
  else
  {
    // Opens the system print dialog.
    webView.CoreWebView2.ShowPrintUI(CoreWebView2PrintDialogKind.System);
  }
}
```

# Print to default printer

You can use `Print` method to print to a default printer without a print dialog.
You can either use default page and printer settings or programmatically configure
print settings, and call `Print` to print the current web page.

```cpp
// This example prints the current web page without a print dialog to a default printer
// with the default print settings.

bool AppWindow::PrintToDefaultPrinter()
{
  wil::com_ptr<ICoreWebView2_15> webView2_15;
  CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));

  wil::com_ptr<ICoreWebView2Environment6> webviewEnvironment6;
  CHECK_FAILURE(m_webViewEnvironment->QueryInterface(IID_PPV_ARGS(&webviewEnvironment6)));

  wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
  CHECK_FAILURE(webviewEnvironment6->CreatePrintSettings(&printSettings));

  wil::com_ptr<ICoreWebView2PrintSettings2> printSettings2;
  CHECK_FAILURE(printSettings->QueryInterface(IID_PPV_ARGS(&printSettings2)));

  wil::unique_cotaskmem_string title;
  CHECK_FAILURE(m_webView->get_DocumentTitle(&title));

  // Prints current web page with the default page and printer settings.
  CHECK_FAILURE(webView2_15->Print(
      printSettings2.get(),
      Callback<ICoreWebView2PrintCompletedHandler>(
          [title = title.get(),
          appWindow = m_appWindow](HRESULT errorCode, BOOL isSuccessful) -> HRESULT
          {
            std::wstring message = L"";
            if (errorCode == S_OK && isSuccessful)
            {
              message = L"Printing " + std::wstring(title) +
                              L" document to printer is succedded";
            }
            else
            {
              if (errorCode == S_OK)
              {
                message = L"Printer is not available, offline or error state";
              }
              else if (errorCode == E_ABORT)
              {
                message = L"Printing " + std::wstring(title) +
                                  L" document already in progress";
              }
              else if (errorCode == E_FAIL)
              {
                message = L"Printing " + std::wstring(title) +
                                  L" document to printer is failed";
              }
            }

            if (appWindow)
            {
              appWindow->AsyncMessageBox(message, L"Print to default printer");
            }
            return S_OK;
        })
        .Get()));
  return true;
}
```

```c#
async void PrintToDefaultPrinter ()
{
  try
  {
    CoreWebView2PrintSettings printSettings = null;
    printSettings = WebViewEnvironment.CreatePrintSettings();

    string title = webView.CoreWebView2.DocumentTitle;

    // Prints current web page with the default page and printer settings.
    bool isSuccessful = await webView.CoreWebView2.PrintAsync(printSettings);

    if (isSuccessful)
    {
      MessageBox.Show(this, "Printing " + title + " document to printer is succeeded", "Print to default printer");
    }
    else
    {
      MessageBox.Show(this, "Printer is not available, offline or error state", "Print to default printer");
    }
  }
  catch (NotImplementedException exception)
  {
    MessageBox.Show(this, "Printing is failed: " + exception.Message, "Print to default printer");
  }
}
```

## Print to printer

You can use `Print` method to print to a specific printer with the print settings.
You can configure print settings using `CreatePrintSettings`, and call `Print`
to print the current web page.

```cpp
// This example prints the current web page to a specific printer with the settings.

struct PrintSettings
{
  COREWEBVIEW2_PRINT_ORIENTATION Layout = COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT;
  int Copies = 1;
  int PagesPerSheet = 1;
  std::wstring Pages = L"";
  COREWEBVIEW2_PRINT_COLLATION Collation = COREWEBVIEW2_PRINT_COLLATION_DEFAULT;
  COREWEBVIEW2_PRINT_COLOR_MODE ColorMode = COREWEBVIEW2_PRINT_COLOR_MODE_DEFAULT;
  COREWEBVIEW2_PRINT_DUPLEX Duplex = COREWEBVIEW2_PRINT_DUPLEX_DEFAULT;
  COREWEBVIEW2_PRINT_MEDIA_SIZE Media = COREWEBVIEW2_PRINT_MEDIA_SIZE_DEFAULT;
  double PaperWidth = 8.5;
  double PaperHeight = 11;
  double ScaleFactor = 1.0;
  bool PrintBackgrounds = false;
  bool HeaderAndFooter = false;
  bool ShouldPrintSelectionOnly = false;
  std::wstring HeaderTitle = L"";
  std::wstring FooterUri = L"";
};

// Function to get printer name by displaying printer text input dialog to the user.
// User has to specify the desired printer name by querying the installed printers list on the OS
// to print the web page.
// You may also choose to display printers list to the user and return user selected printer.
std::wstring AppWindow::GetPrinterName()
{
  std::wstring printerName;

  TextInputDialog dialog(
    GetMainWindow(), L"Printer Name", L"Printer Name:",
    L"Specify a printer name from the installed printers list on the OS.", L"");

  if (dialog.confirmed)
  {
    printerName = (dialog.input).c_str();
  }
  return printerName;

  // or
  //
  // Use win32 EnumPrinters function to get locally installed printers.
  // Display the printer list to the user and get the user desired printer to print.
  // Return the user selected printer name.
}

// Function to get print settings for the selected printer.
// You may also choose get the capabilties from the native printer API, display to the user to get
// the print settings for the current web page and for the selected printer.
PrintSettings AppWindow::GetSelectedPrinterPrintSettings(std::wstring printerName)
{
  PrintSettings printSettings;
  printSettings.PrintBackgrounds = true;
  printSettings.HeaderAndFooter = true;

  return printSettings;

  // or
  //
  // Use win32 DeviceCapabilitiesA function to get the capabilities of the selected printer.
  // Display the printer capabilities to the user along with the page settings.
  // Return the user selected settings.
}

bool AppWindow::PrintToPrinter()
{
  std::wstring printerName = GetPrinterName();
  PrintSettings printInfo = GetSelectedPrinterPrintSettings(printerName);

  wil::com_ptr<ICoreWebView2_15> webView2_15;
  CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));

  wil::com_ptr<ICoreWebView2Environment6> webviewEnvironment6;
  CHECK_FAILURE(m_webViewEnvironment->QueryInterface(IID_PPV_ARGS(&webviewEnvironment6)));

  wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
  CHECK_FAILURE(webviewEnvironment6->CreatePrintSettings(&printSettings));

  wil::com_ptr<ICoreWebView2PrintSettings2> printSettings2;
  CHECK_FAILURE(printSettings->QueryInterface(IID_PPV_ARGS(&printSettings2)));

  CHECK_FAILURE(printSettings2->put_Orientation(printInfo.Layout));
  CHECK_FAILURE(printSettings2->put_Copies(printInfo.Copies));
  CHECK_FAILURE(printSettings2->put_PagesPerSheet(printInfo.PagesPerSheet));
  CHECK_FAILURE(printSettings2->put_PageRanges(printInfo.Pages.c_str()));
  if (printInfo.Media == COREWEBVIEW2_PRINT_MEDIA_SIZE_CUSTOM)
  {
    CHECK_FAILURE(printSettings2->put_PageWidth(printInfo.PaperWidth));
    CHECK_FAILURE(printSettings2->put_PageHeight(printInfo.PaperHeight));
  }
  CHECK_FAILURE(printSettings2->put_ColorMode(printInfo.ColorMode));
  CHECK_FAILURE(printSettings2->put_Collation(printInfo.Collation));
  CHECK_FAILURE(printSettings2->put_Duplex(printInfo.Duplex));
  CHECK_FAILURE(printSettings2->put_ScaleFactor(printInfo.ScaleFactor));
  CHECK_FAILURE(printSettings2->put_ShouldPrintBackgrounds(printInfo.PrintBackgrounds));
  CHECK_FAILURE(printSettings2->put_ShouldPrintHeaderAndFooter(printInfo.HeaderAndFooter));
  CHECK_FAILURE(printSettings2->put_HeaderTitle(printInfo.HeaderTitle.c_str()));
  CHECK_FAILURE(printSettings2->put_FooterUri(printInfo.FooterUri.c_str()));
  CHECK_FAILURE(printSettings2->put_PrinterName(printerName.c_str()));

  wil::unique_cotaskmem_string title;
  CHECK_FAILURE(m_webView->get_DocumentTitle(&title));

  CHECK_FAILURE(webView2_15->Print(
      printSettings2.get(),
      Callback<ICoreWebView2PrintCompletedHandler>(
          [title = title.get(),
          appWindow = m_appWindow](HRESULT errorCode, BOOL isSuccessful) -> HRESULT
          {
            std::wstring message = L"";
            if (errorCode == S_OK && isSuccessful)
            {
              message = L"Printing " + std::wstring(title) +
                              L" document to printer is succedded";
            }
            else
            {
              if (errorCode == S_OK)
              {
                message = L"Selected printer is not found, not available, offline or error state.";
              }
              else if (errorCode == E_INVALIDARG)
              {
                message = L"Invalid settings provided for the specified printer";
              }
              else if (errorCode == E_ABORT)
              {
                message = L"Printing " + std::wstring(title) +
                                  L" document already in progress";
              }
              else if (errorCode == E_FAIL)
              {
                message = L"Printing " + std::wstring(title) +
                                  L" document to printer is failed";
              }
            }

            if (appWindow)
            {
              appWindow->AsyncMessageBox(message, L"Print to printer");
            }
            return S_OK;
          })
          .Get()));
  return true;
}
```

```c#
async void PrintToPrinter()
{
  string printerName = GetPrinterName();
  PrintSettings printInfo = GetSelectedPrinterPrintSettings(printerName);
  try
  {
    CoreWebView2PrintSettings printSettings = null;
    printSettings = WebViewEnvironment.CreatePrintSettings();

    printSettings.Orientation = printInfo.Layout;
    printSettings.Copies = printInfo.Copies;
    printSettings.PagesPerSheet = printInfo.PagesPerSheet;
    printSettings.PageRanges = printInfo.Pages;
    if (printInfo.Media == CoreWebView2PrintMediaSize.Custom)
    {
      printSettings.PageWidth = printInfo.PaperWidth;
      printSettings.PageHeight = printInfo.PaperHeight;
    }
    printSettings.ColorMode = printInfo.ColorMode;
    printSettings.Collation = printInfo.Collation;
    printSettings.Duplex = printerInfo.Duplex;
    printSettings.ScaleFactor = printerInfo.ScaleFactor;
    printSettings.ShouldPrintBackgrounds = printerInfo.PrintBackgrounds;
    printSettings.ShouldPrintHeaderAndFooter = printerInfo.HeaderAndFooter;
    printSettings.HeaderTitle = printInfo.HeaderTitle;
    printSettings.FooterUri = printInfo.FooterUri;
    printSettings.PrinterName = printerName;

    string title = webView.CoreWebView2.DocumentTitle;

    bool isSuccessful = await webView.CoreWebView2.PrintAsync(printSettings);

    if (isSuccessful)
    {
       MessageBox.Show(this, "Printing " + title + " document to printer is succeeded", "Print to printer");
    }
    else
    {
      MessageBox.Show(this, "Selected printer is not found, not available, offline or error state.", "Print to printer");
    }
  }
  catch (NotImplementedException exception)
  {
    MessageBox.Show(this, "Printing is failed: " + exception.Message, "Print to printer");
  }
}

// Function to get printer name by displaying printer text input dialog to the user.
// User has to specify the desired printer name by querying the installed printers list on the
// OS to print the web page.
// You may also choose to display printers list to the user and return user selected printer.
string GetPrinterName()
{
  var dialog = new TextInputDialog(
                title: "Printer Name",
                description: "Specify a printer name from the installed printers list on the OS.",
                defaultInput: "");
  if (dialog.ShowDialog() == true)
  {
    printerName = dialog.Input.Text;
  }
  return printerName;

  // or
  //
  // Use GetPrintQueues() of LocalPrintServer from System.Printing to get list of locally installed printers.
  // Display the printer list to the user and get the desired printer to print.
  // Return the user selected printer name.
}

// Function to get print settings for the selected printer.
// You may also choose get the capabilties from the native printer API, display to the user to get
 // the print settings for the current web page and for the selected printer.
PrintSettings GetSelectedPrinterPrintSettings(string printerName)
{
  PrintSettings printSettings = new PrintSettings();
  printSettings.PrintBackgrounds = true;
  printSettings.HeaderAndFooter = true;

  return printSettings;

  // or
  // Get PrintQueue for the selected printer and use GetPrintCapabilities() of PrintQueue from System.Printing
  // to get the capabilities of the selected printer.
  // Display the printer capabilities to the user along with the page settings.
  // Return the user selected settings.
}

class PrintSettings
{
  public CoreWebView2PrintOrientation Layout { get; set; }
  public int Copies { get; set; } = 1;
  public int PagesPerSheet { get; set; } = 1;
  public string Pages { get; set; } = "";
  public CoreWebView2PrintCollation Collation { get; set; }
  public CoreWebView2PrintColorMode ColorMode { get; set; }
  public CoreWebView2PrintDuplex Duplex { get; set; }
  public CoreWebView2PrintMediaSize Media { get; set; }
  public double PaperWidth { get; set; } = 8.5;
  public double PaperHeight { get; set; } = 11;
  public double ScaleFactor { get; set; } = 1.0;
  public bool PrintBackgrounds { get; set; }
  public bool HeaderAndFooter { get; set; }
  public bool ShouldPrintSelectionOnly { get; set; }
  public string HeaderTitle { get; set; } = "";
  public string FooterUri { get; set; } = "";
}
```

## PrintToPdfStream

You can use `PrintToPdfStream` method to display as a preview in a custom print dialog.
The app can also use this API to configure the custom print preview dialog unlike confining
print preview dialog to the webview2 control.

```cpp
// This example prints the Pdf data of the current web page to a stream.

// Function to display current web page pdf data in a custom print preview dialog.
static void DisplayPdfDataInPrintDialog(IStream* pdfData)
{
  // You can display the printable pdf data in a custom print preview dialog to the end user.
}

bool AppWindow::PrintToPdfStream()
{
  wil::com_ptr<ICoreWebView2_15> webView2_15;
  CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webView2_15)));

  wil::com_ptr<ICoreWebView2Environment6> webviewEnvironment6;
  CHECK_FAILURE(m_webViewEnvironment->QueryInterface(IID_PPV_ARGS(&webviewEnvironment6)));

  wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
  CHECK_FAILURE(webviewEnvironment6->CreatePrintSettings(&printSettings));

  wil::com_ptr<ICoreWebView2PrintSettings2> printSettings2;
  CHECK_FAILURE(printSettings->QueryInterface(IID_PPV_ARGS(&printSettings2)));

  CHECK_FAILURE(printSettings2->put_ShouldPrintBackgrounds(true));

  wil::unique_cotaskmem_string title;
  CHECK_FAILURE(m_webView->get_DocumentTitle(&title));

  CHECK_FAILURE(
      webView2_15->PrintToPdfStream(
          printSettings2.get(),
          Callback<ICoreWebView2PrintToPdfStreamCompletedHandler>(
              [title = title.get(),
              appWindow = m_appWindow](HRESULT errorCode, IStream* pdfData) -> HRESULT
              {
                DisplayPdfDataInPrintDialog(pdfData);
                std::wstring message = L"Printing " + std::wstring(title) +
                                       L" document to PDF Stream " +
                                       ((errorCode == S_OK) ? L"succedded" : L"failed");

                if (appWindow)
                {
                  appWindow->AsyncMessageBox(message, L"Print to PDF Stream");
                }

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
  printSettings.ShouldPrintBackgrounds = true;

  string title = webView.CoreWebView2.DocumentTitle;

  System.IO.Stream stream = await webView.CoreWebView2.PrintToPdfStreamAsync(printSettings);
  DisplayPdfDataInPrintDialog(stream);

  MessageBox.Show(this, "Printing " + title + " document to PDF Stream succeeded", "Print To PDF Stream");
}

// Function to display current web page pdf data in a custom print preview dialog.
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
  COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER,

  /// Opens the system print dialog.
  COREWEBVIEW2_PRINT_DIALOG_KIND_SYSTEM,

} COREWEBVIEW2_PRINT_DIALOG_KIND;

/// Specifies the duplex option for a print.
[v1_enum]
typedef enum COREWEBVIEW2_PRINT_DUPLEX {
  /// The default duplex for a printer.
  COREWEBVIEW2_PRINT_DUPLEX_DEFAULT,

  /// Print on only one side of the sheet.
  COREWEBVIEW2_PRINT_DUPLEX_ONE_SIDED,

  /// Print on both sides of the sheet, flipped along the long edge.
  COREWEBVIEW2_PRINT_DUPLEX_TWO_SIDED_LONG_EDGE,

  /// Print on both sides of the sheet, flipped along the short edge.
  COREWEBVIEW2_PRINT_DUPLEX_TWO_SIDED_SHORT_EDGE,

} COREWEBVIEW2_PRINT_DUPLEX;

/// Specifies the color mode for a print.
[v1_enum]
typedef enum COREWEBVIEW2_PRINT_COLOR_MODE {
  /// The default color mode for a printer.
  COREWEBVIEW2_PRINT_COLOR_MODE_DEFAULT,

  /// Indicate that the printed output will be in color.
  COREWEBVIEW2_PRINT_COLOR_MODE_COLOR,

  /// Indicate that the printed output will be in shades of gray.
  COREWEBVIEW2_PRINT_COLOR_MODE_GRAYSCALE,

} COREWEBVIEW2_PRINT_COLOR_MODE;

/// Specifies the collation for a print.
[v1_enum]
typedef enum COREWEBVIEW2_PRINT_COLLATION {
  /// The default collation for a printer.
  COREWEBVIEW2_PRINT_COLLATION_DEFAULT,

  /// Indicate that the collation has been selected for the printed output.
  COREWEBVIEW2_PRINT_COLLATION_COLLATED,

  /// Indicate that the collation has not been selected for the printed output.
  COREWEBVIEW2_PRINT_COLLATION_UNCOLLATED,

} COREWEBVIEW2_PRINT_COLLATION;

/// Specifies the media size for a print.
[v1_enum] typedef enum COREWEBVIEW2_PRINT_MEDIA_SIZE {
  /// The default media size for a printer.
  COREWEBVIEW2_PRINT_MEDIA_SIZE_DEFAULT,

  /// Indicate custom media size that is specific to the printer.
  COREWEBVIEW2_PRINT_MEDIA_SIZE_CUSTOM,

} COREWEBVIEW2_PRINT_MEDIA_SIZE;

[uuid(92269C88-1CC1-47E0-9A87-71458409BA15), object, pointer_default(unique)]
interface ICoreWebView2_15 : ICoreWebView2_14 {
  /// Print the current web page asynchronously to the specified printer with the provided settings.
  /// See `ICoreWebView2PrintSettings2` for description of settings.
  /// The handler will return `errorCode` as `S_OK` and `isSuccessful` as FALSE if `printerName`
  /// doesn't match with the name of any installed printers on the user OS.
  /// The handler will return `errorCode` as `E_INVALIDARG` and `isSuccessful` as FALSE
  /// if the caller provides invalid settings for a given printer.
  ///
  /// The async `Print` operation completes when it finishes printing to the printer.
  /// At this time the `ICoreWebView2PrintCompletedHandler` is invoked. Only one `Printing` operation
  /// can be in progress at a time. If `Print` is called while a `Print` or `PrintToPdf`
  /// or `PrintToPdfStream` or `ShowPrintUI` job is in progress, the completed handler is
  /// immediately invoked with `E_ABORT` and `isSuccessful` set to FALSE.
  ///
  /// \snippet AppWindow.cpp PrintToPrinter
  HRESULT Print(
    [in] ICoreWebView2PrintSettings2* printSettings,
    [in] ICoreWebView2PrintCompletedHandler* handler);

  /// Opens the print dialog to print the current web page. See `COREWEBVIEW2_PRINT_DIALOG_KIND`
  /// for descriptions of print dialog kinds.
  ///
  /// \snippet AppWindow::ShowPrintUI
  HRESULT ShowPrintUI([in] COREWEBVIEW2_PRINT_DIALOG_KIND printDialogKind);

  /// Provides the Pdf data of current web page asynchronously for the provided settings.
  /// See `ICoreWebView2PrintSettings2` for description of settings. Passing
  /// nullptr for `printSettings` results in default print settings used.
  ///
  /// The async `PrintToPdfStream` operation completes when it finishes
  /// writing to the stream. At this time the `ICoreWebView2PrintToPdfStreamCompletedHandler`
  /// is invoked. Only one `Printing` operation can be in progress at a time. If
  /// `PrintToPdfStream` is called while a `PrintToPdfStream` or `PrintToPdf` or `Print` or `ShowPrintUI`
  /// job is in progress, the completed handler is immediately invoked with `E_ABORT`.
  ///
  /// \snippet AppWindow.cpp PrintToPdfStream
  HRESULT PrintToPdfStream([in] ICoreWebView2PrintSettings2* printSettings,
                           [in] ICoreWebView2PrintToPdfStreamCompletedHandler* handler);
}

/// Receives the result of the `Print` method.
/// |       errorCode     |       isSuccessful    |               Notes                                                                           |
/// | --- | --- | --- |
/// |        S_OK         |        True           | Print operation succeeded.                                                                    |
/// |        S_OK         |        False          | If specified printer is not found or printer status is not available, offline or error state. |
/// |       E_FAIL        |        False          | Print operation is failed.                                                                    |
/// |     E_INVALIDARG    |        False          | If the caller provides invalid settings for the specified printer.                            |
/// |       E_ABORT       |        False          | Print operation is failed as printing job already in progress.                                     |
[uuid(4B2FE043-1A1A-4924-803D-C05E5FDCA3B0), object, pointer_default(unique)]
interface ICoreWebView2PrintCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] BOOL isSuccessful);
}

/// Receives the result of the `PrintToPdfStream` method.
/// `errorCode` returns S_OK if the PrintToPdfStream operation succeeded.
/// The printable pdf data is returned in the `pdfStream` object.
[uuid(78A9FC37-249B-4E7E-A2E6-20CAAA14AE7B), object, pointer_default(unique)]
interface ICoreWebView2PrintToPdfStreamCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] IStream* pdfStream);
}

/// Settings used by the `Print` method.
[uuid(DA3AD25C-D121-44DC-83DA-BF5E50DBF0DF), object, pointer_default(unique)]
interface ICoreWebView2PrintSettings2 : ICoreWebView2PrintSettings {
  /// Page range to print. Defaults to empty string, which means print all pages.
  ///
  /// The PageRanges property is a list of page ranges specifying one or more pages that
  /// should be printed separated by commas. Any whitespace between page ranges is ignored.
  /// A valid page range is either a single integer identifying the page to print, or a range
  /// in the form `[start page]-[last page]` where `start page` and `last page` are integers
  /// identifying the first and last inclusive pages respectively to print.
  /// Every page identifier is an integer greater than 0 unless wildcards are used (see below examples).
  /// The first page is 1.
  ///
  /// In a page range of the form `[start page]-[last page]` the start page number must be
  /// larger than 0 and less than or equal to the document's total page count.
  /// If the `start page` is not present, then 1 is used as the `start page`.
  /// The `last page` must be larger than the `start page`.
  /// If the `last page` is not present, then the document total page count is used as the `last page`.
  ///
  /// Repeating a page does not print it multiple times. To print multiple times, use the `Copies` property.
  ///
  /// The pages are always printed in ascending order, even if specified in non-ascending order."
  ///
  /// If page range is not valid or if a page is greater than document total page count,
  /// `ICoreWebView2PrintCompletedHandler` or ICoreWebView2PrintToPdfStreamCompletedHandler`
  /// handler will return `E_INVALIDARG`.
  ///
  /// The following examples assume a document with 20 total pages.
  ///
  /// |       Example         |       Result      |               Notes                                              |
  /// | --- | --- | --- |
  /// | "2"                   |  Page 2           |                                                                  |
  /// | "1-4, 9, 3-6, 10, 11" |  Pages 1-6, 9-11  |                                                                  |
  /// | "1-4, -6"             |  Pages 1-6        | The "-6" is interpreted as "1-6".                                |
  /// | "2-"                  |  Pages 2-20       | The "2-" is interpreted as "pages 2 to the end of the document". |
  /// | "4-2, 11, -6"         |  Invalid          | "4-2" is an invalid range.                                       |
  /// | "-"                   |  Pages 1-20       | The "-" is interpreted as "page 1 to the end of the document".   |
  /// | "1-4dsf, 11"          |  Invalid          |                                                                  |
  /// | "2-2"                 |  Invalid          | Use "2" to print only page 2.                                    |
  ///
  /// The caller must free the returned string with `CoTaskMemFree`. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PageRanges([out, retval] LPWSTR* value);

  /// Set the `PageRanges` property.
  [propput] HRESULT PageRanges([in] LPCWSTR value);

  /// Prints multiple pages of a document on a single piece of paper. Choose from 1, 2, 4, 6, 9 or 16.
  /// The default value is 1.
  [propget] HRESULT PagesPerSheet([out, retval] INT32* value);

  /// Set the `PagesPerSheet` property. Returns `E_INVALIDARG` if an invalid value is
  /// provided, and the current value is not changed.
  [propput] HRESULT PagesPerSheet([in] INT32 value);

  /// Number of copies to print. Minimum value is `1` and the maximum copies count is `999`.
  /// The default value is 1.
  ///
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Copies([out, retval] INT32* value);

  /// Set the `Copies` property. Returns `E_INVALIDARG` if an invalid value is provided
  /// and the current value is not changed.
  [propput] HRESULT Copies([in] INT32 value);

  /// Printer collation. See `COREWEBVIEW2_PRINT_COLLATION` for descriptions of
  /// collation. The default value is `COREWEBVIEW2_PRINT_COLLATION_DEFAULT`.
  ///
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Collation([out, retval] COREWEBVIEW2_PRINT_COLLATION* value);

  /// Set the `Collation` property.
  [propput] HRESULT Collation([in] COREWEBVIEW2_PRINT_COLLATION value);

  /// Printer color mode. See `COREWEBVIEW2_PRINT_COLOR_MODE` for descriptions
  /// of color modes.
  /// The default value is `COREWEBVIEW2_PRINT_COLOR_MODE_DEFAULT`.
  [propget] HRESULT ColorMode([out, retval] COREWEBVIEW2_PRINT_COLOR_MODE* value);

  /// Set the `ColorMode` property.
  [propput] HRESULT ColorMode([in] COREWEBVIEW2_PRINT_COLOR_MODE value);

  /// Printer duplex settings. See `COREWEBVIEW2_PRINT_DUPLEX` for descriptions of duplex.
  /// The default value is `COREWEBVIEW2_PRINT_DUPLEX_DEFAULT`.
  ///
  /// This value is ignored in PrintToPdfStream method.
  [propget] HRESULT Duplex([out, retval] COREWEBVIEW2_PRINT_DUPLEX* value);

  /// Set the `Duplex` property.
  [propput] HRESULT Duplex([in] COREWEBVIEW2_PRINT_DUPLEX value);

  /// Printer media size. See `COREWEBVIEW2_PRINT_MEDIA_SIZE` for descriptions of media size.
  /// The default value is `COREWEBVIEW2_PRINT_MEDIA_SIZE_DEFAULT`.
  ///
  /// If media size is `COREWEBVIEW2_PRINT_MEDIA_SIZE_CUSTOM`, you should set the `PageWidth`
  /// and `PageHeight`.
  [propget] HRESULT MediaSize([out, retval] COREWEBVIEW2_PRINT_MEDIA_SIZE* value);

  /// Set the `MediaSize` property.
  [propput] HRESULT MediaSize([in] COREWEBVIEW2_PRINT_MEDIA_SIZE value);

  /// The name of the printer to use. Defaults to empty string.
  /// If the printer name is empty string or null, then it prints to the default
  /// printer on the user OS.
  ///
  /// This value is ignored in PrintToPdfStream method.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings)
  [propget] HRESULT PrinterName([out, retval] LPWSTR* value);

  /// Set the `PrinterName` property. If provided printer name doesn't match with
  /// the name of any installed printers on the user OS, `ICoreWebView2PrintCompletedHandler` handler
  /// will return `errorCode` as `S_OK` and `isSuccessful` as FALSE.
  [propput] HRESULT PrinterName([in] LPCWSTR value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
  runtimeclass CoreWebView2PrintSettings;
  runtimeclass CoreWebView2;

  enum CoreWebView2PrintDialogKind
  {
      Browser = 0,
      System = 1,
  };

  enum CoreWebView2PrintDuplex
  {
      Default = 0,
      OneSided = 1,
      TwoSidedLongEdge = 2,
      TwoSidedShortEdge = 3,
  };

  enum CoreWebView2PrintColorMode
  {
      Default = 0,
      Color = 1,
      Grayscale = 2,
  };

  enum CoreWebView2PrintCollation
  {
      Default = 0,
      Collated = 1,
      Uncollated = 2,
  };

  enum CoreWebView2PrintMediaSize
  {
      Default = 0,
      Custom = 1,
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
          CoreWebView2PrintCollation Collation { get; set; };
          CoreWebView2PrintColorMode ColorMode { get; set; };
          CoreWebView2PrintDuplex Duplex { get; set; };
          CoreWebView2PrintMediaSize MediaSize { get; set; };
          String PrinterName { get; set; };
      }
  }

  runtimeclass CoreWebView2
  {
      // ...

      [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_15")]
      {
          void ShowPrintUI(CoreWebView2PrintDialogKind printDialogKind);
          void ShowPrintUI();

          Windows.Foundation.IAsyncOperation<bool> PrintAsync(CoreWebView2PrintSettings printSettings);

          Windows.Foundation.IAsyncOperation<Windows.Storage.Streams.IRandomAccessStream>
          PrintToPdfStreamAsync(CoreWebView2PrintSettings printSettings);
      }
  }
}
```
