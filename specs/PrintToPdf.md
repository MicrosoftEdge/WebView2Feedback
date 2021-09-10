# Background

Developers have requested the ability to programmatically print to PDF in WebView2. Printing to PDF uses a virtual printer to create a PDF file from the current page. Currently the end user can do this from the print preview dialog by choosing the "Save as PDF" or "Microsoft Print to PDF" options. This API gives developers the ability to print to PDF without requiring the end user to go through the print preview dialog.

In this document we describe the updated API. We'd appreciate your feedback.


# Description
This API consists of an asynchronous PrintToPdf method and a PrintSettings object. The PrintToPdf method accepts a path that the PDF file should be saved to.

Use the CreatePrintSettings method to create a PrintSettings object with default values, which can be modified. The settings consist of: orientation, scale factor, page height and width, margins, printing of backgrounds, printing selection only, printing header and footer, header title, and footer URI. See API Details below for the default values.

Currently other programmatic printing is not supported.

# Examples
```cpp
// Shows the user a file selection dialog, then uses the selected path when
// printing to PDF. If `enableLandscape` is true, the page is printed
// in landscape mode, otherwise the page is printed in portrait mode.
void FileComponent::PrintToPdf(bool enableLandscape)
{
    WCHAR defaultName[MAX_PATH] = L"WebView2_PrintedPdf.pdf";
    OPENFILENAME openFileName = CreateOpenFileName(defaultName, L"PDF File\0*.pdf\0");
    if (GetSaveFileName(&openFileName))
    {
        wil::com_ptr<ICoreWebView2PrintSettings> printSettings = nullptr;
        if (enableLandscape)
        {
            wil::com_ptr<ICoreWebView2Environment5> webviewEnvironment5;
            CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                IID_PPV_ARGS(&webviewEnvironment5)));
            if (webviewEnvironment5)
            {
                CHECK_FAILURE(webviewEnvironment5->CreatePrintSettings(&printSettings));
                CHECK_FAILURE(
                    printSettings->put_Orientation(COREWEBVIEW2_PRINT_ORIENTATION_LANDSCAPE));
            }
        }

        wil::com_ptr<ICoreWebView2_4> webview2_4;
        CHECK_FAILURE(m_webView->QueryInterface(IID_PPV_ARGS(&webview2_4)));
        if (webview2_4)
        {
            m_printToPdfInProgress = true;
            CHECK_FAILURE(webview2_4->PrintToPdf(
                openFileName.lpstrFile, printSettings.get(),
                Callback<ICoreWebView2PrintToPdfCompletedHandler>(
                    [this](HRESULT errorCode, BOOL isSuccessful) -> HRESULT {
                        CHECK_FAILURE(errorCode);
                        m_printToPdfInProgress = false;
                        auto showDialog = [isSuccessful] {
                            MessageBox(
                                nullptr,
                                (isSuccessful) ? L"Print to PDF succeeded"
                                               : L"Print to PDF failed",
                                L"Print to PDF Completed", MB_OK);
                        };
                        m_appWindow->RunAsync([showDialog]() { showDialog(); });
                        return S_OK;
                    })
                    .Get()));
        }
    }
}
```

```c#
// Prints current page to PDF using the default path and settings. If requested,
// the orientation is changed to landscape.
async void PrintToPdfCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    if (_isPrintToPdfInProgress)
    {
        MessageBox.Show(this, "Print to PDF in progress", "Print To PDF");
        return;
    }
    CoreWebView2PrintSettings printSettings = null;
    string orientationString = e.Parameter.ToString();
    if (orientationString == "Landscape")
    {
        printSettings = WebViewEnvironment.CreatePrintSettings();
        printSettings.Orientation =
            CoreWebView2PrintOrientation.Landscape;
    }

    Microsoft.Win32.SaveFileDialog saveFileDialog =
        new Microsoft.Win32.SaveFileDialog();
    saveFileDialog.InitialDirectory = "C:\\";
    saveFileDialog.Filter = "Pdf Files|*.pdf";
    Nullable<bool> result = saveFileDialog.ShowDialog();
    if (result == true) {
        _isPrintToPdfInProgress = true;
        bool isSuccessful = await webView.CoreWebView2.PrintToPdfAsync(
            saveFileDialog.FileName, printSettings);
        _isPrintToPdfInProgress = false;
        string message = (isSuccessful) ?
            "Print to PDF succeeded" : "Print to PDF failed";
        MessageBox.Show(this, message, "Print To PDF Completed");
    }
}
```
# Remarks

# API Notes


# API Details
```
interface ICoreWebView2_4;
interface ICoreWebView2Environment5;
interface ICoreWebView2PrintSettings;
interface ICoreWebView2PrintToPdfCompletedHandler;


/// The orientation for printing, used by the `Orientation` property on
/// `ICoreWebView2SPrintSettings`. Currently only printing to PDF
/// is supported.
[v1_enum]
typedef enum COREWEBVIEW2_PRINT_ORIENTATION
{
  /// Print the page(s) in portrait orientation.
  COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT,

  /// Print the page(s) in landscape orientation.
  COREWEBVIEW2_PRINT_ORIENTATION_LANDSCAPE,
} COREWEBVIEW2_PRINT_ORIENTATION;

[uuid(9eae81c3-fe02-4084-b475-903a4ed9252e), object, pointer_default(unique)]
interface ICoreWebView2_4 : IUnknown {
  /// Print the current page to PDF asynchronously with the provided settings. See
  /// `ICoreWebView2PrintSettings` for description of settings. Passing
  /// nullptr for `printSettings` results in default print settings used.
  ///
  /// Use `resultFilePath` to specify the path to the PDF file. The host should
  /// provide an absolute path, including file name. If the path
  /// points to an existing file, the file will be overwritten. If the path is
  /// not valid, the method fails with `E_INVALIDARG`.
  ///
  /// The async `PrintToPdf` operation completes when the data has been written
  /// to the PDF file. At this time the
  /// `ICoreWebView2PrintToPdfCompletedHandler` is invoked. If the
  /// application exits before printing is complete, the file is not saved.
  /// Only one `PrintToPdf` operation can be in progress at a time. If
  /// `PrintToPdf` is called while a print to PDF job is in progress, the
  /// completed handler is immediately invoked with `isSuccessful` set to FALSE.
  ///
  /// \snippet FileComponent.cpp PrintToPdf
  HRESULT PrintToPdf(
    [in] LPCWSTR resultFilePath,
    [in] ICoreWebView2PrintSettings* printSettings,
    [in] ICoreWebView2PrintToPdfCompletedHandler* handler);
}

/// Receives the result of the `PrintToPdf` method. If the print to PDF
/// operation succeeds, `isSuccessful` is true. Otherwise, if the operation
/// failed, `isSuccessful` is set to false. An invalid path returns
/// `E_INVALIDARG`.
[uuid(4808ac58-c372-4d3d-be5e-900df2593835), object, pointer_default(unique)]
interface ICoreWebView2PrintToPdfCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, [in] LPCWSTR resultFilePath);
}

/// Settings used by the `PrintToPdf` method. Other programmatic printing is not
/// currently supported.
[uuid(30964a64-2e92-4604-9eaa-3afcd3a015dc), object, pointer_default(unique)]
interface ICoreWebView2PrintSettings : IUnknown {

  /// The orientation can be portrait or landscape. The default orientation is
  /// portrait. See `COREWEBVIEW2_PRINT_ORIENTATION`.
  [propget] HRESULT Orientation(
    [out, retval] COREWEBVIEW2_PRINT_ORIENTATION* orientation);

  /// Sets the `Orientation` property.
  [propput] HRESULT Orientation(
      [in] COREWEBVIEW2_PRINT_ORIENTATION orientation);

  /// The scale factor is a value between 0.1 and 2.0. The default is 1.0.
  [propget] HRESULT ScaleFactor([out, retval] double* scaleFactor);

  /// Sets the `ScaleFactor` property. Returns `E_INVALIDARG` if an invalid
  /// value is provided, and the current value is not changed.
  [propput] HRESULT ScaleFactor([in] double scaleFactor);

  /// The page width in inches. The default width is 8.5 inches.
  [propget] HRESULT PageWidth([out, retval] double* pageWidth);

  /// Sets the `PageWidth` property. Returns `E_INVALIDARG` if the page width is
  /// less than or equal to zero, and the current value is not changed.
  [propput] HRESULT PageWidth([in] double pageWidth);

  /// The page height in inches. The default height is 11 inches.
  [propget] HRESULT PageHeight([out, retval] double* pageHeight);

  /// Sets the `PageHeight` property. Returns `E_INVALIARG` if the page height
  /// is less than or equal to zero, and the current value is not changed.
  [propput] HRESULT PageHeight([in] double pageHeight);

  /// The top margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginTop([out, retval] double* marginTop);

  /// Sets the `MarginTop` property. A margin cannot be less than zero.
  /// Returns `E_INVALIDARG` if an invalid value is provided, and the current
  /// value is not changed.
  [propput] HRESULT MarginTop([in] double marginTop);

  /// The bottom margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginBottom([out, retval] double* marginBottom);

  /// Sets the `MarginBottom` property. A margin cannot be less than zero.
  /// Returns `E_INVALIDARG` if an invalid value is provided, and the current
  /// value is not changed.
  [propput] HRESULT MarginBottom([in] double marginBottom);

  /// The left margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginLeft([out, retval] double* marginLeft);

  /// Sets the `MarginLeft` property. A margin cannot be less than zero.
  /// Returns `E_INVALIDARG` if an invalid value is provided, and the current
  /// value is not changed.
  [propput] HRESULT MarginLeft([in] double marginLeft);

  /// The right margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginRight([out, retval] double* marginRight);

  /// Set the `MarginRight` property.A margin cannot be less than zero.
  /// Returns `E_INVALIDARG` if an invalid value is provided, and the current
  /// value is not changed.
  [propput] HRESULT MarginRight([in] double marginRight);

  /// `TRUE` if background colors and images should be printed. The default value
  /// is `FALSE`.
  [propget] HRESULT ShouldPrintBackgrounds(
      [out, retval] BOOL* shouldPrintBackgrounds);

  /// Set the `ShouldPrintBackgrounds` property.
  [propput] HRESULT ShouldPrintBackgrounds([in] BOOL shouldPrintBackgrounds);

  /// `TRUE` if only the current end user's selection of HTML in the document
  /// should be printed. The default value is `FALSE`.
  [propget] HRESULT ShouldPrintSelectionOnly(
      [out, retval] BOOL* shouldPrintSelectionOnly);

  /// Set the `ShouldPrintSelectionOnly` property.
  [propput] HRESULT ShouldPrintSelectionOnly(
      [in] BOOL shouldPrintSelectionOnly);

  /// `TRUE` if header and footer should be printed. The default value is `FALSE`.
  /// The header consists of the date and time of printing, and the title of the
  /// page. The footer consists of the URI and page number. The height of the
  /// header and footer is 0.5 cm, or ~0.2 inches.
  [propget] HRESULT ShouldPrintHeaderAndFooter(
      [out, retval] BOOL* shouldPrintHeaderAndFooter);

  /// Set the `ShouldPrintHeaderAndFooter` property.
  [propput] HRESULT ShouldPrintHeaderAndFooter(
      [in] BOOL shouldPrintHeaderAndFooter);

  /// The title in the header if `ShouldPrintHeaderAndFooter` is `TRUE`. The
  /// default value is the title of the current document.
  [propget] HRESULT HeaderTitle([out, retval] LPWSTR* headerTitle);

  /// Set the `HeaderTitle` property. If an empty string or null value is
  /// provided, no title is shown in the header.
  [propput] HRESULT HeaderTitle([in] LPCWSTR headerTitle);

  /// The URI in the footer if `ShouldPrintHeaderAndFooter` is `TRUE`. The
  /// default value is the current URI.
  [propget] HRESULT FooterUri([out, retval] LPWSTR* footerUri);

  /// Set the `FooterUri` property. If an empty string or null value is
  /// provided, no URI is shown in the footer.
  [propput] HRESULT FooterUri([in] LPCWSTR footerUri);
}

[uuid(7dee69a9-c2cc-422b-9f86-e6ed6551ce95), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown
{
    /// Creates the `ICoreWebView2PrintSettings` used by the `PrintToPdf`
    /// method with default values.
    HRESULT CreatePrintSettings(
        [out, retval] ICoreWebView2PrintSettings** printSettings);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2PrintSettings;
    runtimeclass CoreWebView2;

    enum CoreWebView2PrintOrientation
    {
        Portrait = 0,
        Landscape = 1,
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
    };

    runtimeclass CoreWebView2Environment
    {
        CoreWebView2PrintSettings CreatePrintSettings();
    }

    runtimeclass CoreWebView2
    {
        Windows.Foundation.IAsyncOperation<bool> PrintToPdfAsync(
            String ResultFilePath, CoreWebView2PrintSettings printSettings);
    }
}
```
# Appendix
