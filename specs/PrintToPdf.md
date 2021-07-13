# Background

Developers have requested the ability to programmatically print to PDF in WebView2. Printing to PDF uses a virtual printer to create a PDF file from the current page. Currently the end user can do this from the print preview dialog by choosing the "Save as PDF" or "Microsoft Print to PDF" options. This API gives developers the ability to print to PDF without requiring the end user to go through the print preview dialog.

In this document we describe the updated API. We'd appreciate your feedback.


# Description
This API consists of an asynchronous PrintToPdf method and a PrintSettings object. The PrintToPdf method accepts a path that the PDF file should be saved to.

Use the CreateDefaultPrintSettings method to create a PrintSettings object with default values, which can be modified. The settings consist of: orientation, scale factor, page height and width, margins, printing of backgrounds, printing selection only, printing header and footer, header title, and footer URI. See API Details below for the default values.

Currently other programmatic printing is not supported.

# Examples
```cpp
// Shows the user a file selection dialog, then uses the selected path when
// printing to PDF. If `useDefaultOrientation` is true, the page is printed
// in portrait mode, otherwise the page is printed in landscape mode.
void FileComponent::PrintToPdf(bool useDefaultOrientation)
{
    WCHAR defaultName[MAX_PATH] = L"WebView2_PrintedPdf.pdf";
    OPENFILENAME openFileName = CreateOpenFileName(defaultName,
                                                   L"PDF File\0*.pdf\0");
    if (GetSaveFileName(&openFileName))
    {
        wil::com_ptr<ICoreWebView2Environment5> webviewEnvironment5;
        CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
            IID_PPV_ARGS(&webviewEnvironment5)));

        wil::com_ptr<ICoreWebView2SPrintSettings> printSettings;
        if (webViewEvironment5)
        {
            CHECK_FAILURE(webviewEnvironment5->CreateDefaultPrintSettings(
                &printSettings));
        }

        if (printSettings)
        {
            if (!useDefaultOrientation)
            {
                CHECK_FAILURE(printSettings->put_Orientation(
                    COREWEBVIEW2_PRINT_ORIENTATION_LANDSCAPE));
            }
            CHECK_FAILURE(m_webView4->PrintToPdf(
                openFileName.lpstrFile, printSettings.get(),
                Callback<ICoreWebView2PrintToPdfCompletedHandler>(
                    [](HRESULT errorCode, LPCWSTR resultFilePath) -> HRESULT {
                        CHECK_FAILURE(errorCode);
                        std::wstringstream formattedMessage;
                        formattedMessage << "ResultFilePath: " << resultFilePath;
                        MessageBox(nullptr, formattedMessage.str().c_str(),
                            L"Print to PDF Completed", MB_OK);
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
    CoreWebView2PrintSettings printSettings =
        WebViewEnvironment.CreateDefaultPrintSettings();

    string orientationString = e.Parameter.ToString();
    if (printSettings != null && orientationString == "Landscape")
    {
        printSettings.Orientation =
            CoreWebView2PrintOrientation.Landscape;
    }
    string resultFilePath = await webView.CoreWebView2.PrintToPdfAsync(
        "" /* use default path*/, printSettings);
    MessageBox.Show(this, resultFilePath, "Print To PDF Completed");
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
  /// Print the current page to PDF asynchronously with the provided settings.
  /// See `ICoreWebView2PrintSettings` for description of settings.
  ///
  /// Use `resultFilePath` to specify the path to the PDF file. The host should
  /// provide an absolute path, including file name. If the path
  /// points to an existing file, the file will be overwritten. If the directory
  /// does not exist, it is created. If `resultFilePath` is empty, the default
  /// path will be used.
  ///
  /// When `PrintToPdf` completes, the `ICoreWebView2PrintToPdfCompletedHandler`
  /// is invoked.
  ///
  /// \snippet FileComponent.cpp PrintToPdf
  HRESULT PrintToPdf(
    [in] LPCWSTR resultFilePath,
    [in] ICoreWebView2PrintSettings* printSettings,
    [in] ICoreWebView2PrintToPdfCompletedHandler* handler);
}

/// Receives the result of the `PrintToPdf` method. The `resultFilePath`
/// contains the final path of the PDF file.
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

  /// The scale factor is a value between 0.1-2.0. The default is 1.0.
  [propget] HRESULT ScaleFactor([out, retval] double* scaleFactor);

  /// Sets the `ScaleFactor` property.
  [propput] HRESULT ScaleFactor([in] double scaleFactor);

  /// The page width in inches. The default width is 8.5 inches.
  [propget] HRESULT PageWidth([out, retval] double* pageWidth);

  /// Sets the `PageWidth` property.
  [propput] HRESULT PageWidth([in] double pageWidth);

  /// The page height in inches. The default height is 11 inches.
  [propget] HRESULT PageHeight([out, retval] double* pageHeight);

  /// Sets the `PageHeight` property.
  [propput] HRESULT PageHeight([in] double pageHeight);

  /// The top margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginTop([out, retval] double* marginTop);

  /// Sets the `MarginTop` property.
  [propput] HRESULT MarginTop([in] double marginTop);

  /// The bottom margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginBottom([out, retval] double* marginBottom);

  /// Sets the `MarginBottom` property.
  [propput] HRESULT MarginBottom([in] double marginBottom);

  /// The left margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginLeft([out, retval] double* marginLeft);

  /// Sets the `MarginLeft` property.
  [propput] HRESULT MarginLeft([in] double marginLeft);

  /// The right margin in inches. The default is 1 cm, or ~0.4 inches.
  [propget] HRESULT MarginRight([out, retval] double* marginRight);

  /// Set the `MarginRight` property.
  [propput] HRESULT MarginRight([in] double marginRight);

  /// `TRUE` if backgrounds should be printed. The default value is `FALSE`.
  [propget] HRESULT ShouldPrintBackgrounds(
      [out, retval] BOOL* shouldPrintBackgrounds);

  /// Set the `ShouldPrintBackgrounds` property.
  [propput] HRESULT ShouldPrintBackgrounds([in] BOOL shouldPrintBackgrounds);

  /// `TRUE` if only the selection should be printed. The default value is `FALSE`.
  [propget] HRESULT ShouldPrintSelectionOnly(
      [out, retval] BOOL* shouldPrintSelectionOnly);

  /// Set the `ShouldPrintSelectionOnly` property.
  [propput] HRESULT ShouldPrintSelectionOnly(
      [in] BOOL shouldPrintSelectionOnly);

  /// `TRUE` if header and footer should be printed. The default value is `FALSE`.
  [propget] HRESULT ShouldPrintHeaderFooter(
      [out, retval] BOOL* shouldPrintHeaderFooter);

  /// Set the `ShouldPrintHeaderFooter` property.
  [propput] HRESULT ShouldPrintHeaderFooter([in] BOOL shouldPrintHeaderFooter);

  /// The title in the header if `ShouldPrintHeaderFooter` is `TRUE`.
  [propget] HRESULT HeaderTitle([out, retval] LPWSTR* headerTitle);

  /// Set the `HeaderTitle` property.
  [propput] HRESULT HeaderTitle([in] LPCWSTR headerTitle);

  /// The URI in the footer if `ShouldPrintHeaderFooter` is `TRUE`.
  [propget] HRESULT FooterUri([out, retval] LPWSTR* footerUri);

  /// Set the `FooterUri` property.
  [propput] HRESULT FooterUri([in] LPCWSTR footerUri);
}

[uuid(7dee69a9-c2cc-422b-9f86-e6ed6551ce95), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown
{
    /// Creates the `ICoreWebView2PrintSettings` used by the `PrintToPdf`
    /// method with the following default values:
    /// - pageOrientation: COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT
    /// - scaleFactor: 1.0
    /// - pageWidth: 8.5 (inches)
    /// - pageHeight: 11 (inches)
    /// - marginTop: 0.4 (inches)
    /// - marginBotoom: 0.4 (inches)
    /// - marginLeft: 0.4 (inches)
    /// - marginRight: 0.4 (inches)
    /// - shouldPrintBackgrounds: FALSE
    /// - shouldPrintSelectionOnly: FALSE
    /// - shouldPrintHeaderFooter: FALSE
    /// - headerTitle: ""
    /// - footerUri: ""
    HRESULT CreateDefaultPrintSettings(
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
        Boolean ShouldPrintHeaderFooter { get; set; };
        String HeaderTitle { get; set; };
        String FooterUri { get; set; };
    };

    runtimeclass CoreWebView2Environment
    {
        CoreWebView2PrintSettings CreateDefaultPrintSettings();
    }

    runtimeclass CoreWebView2
    {
        Windows.Foundation.IAsyncOperation<String> PrintToPdfAsync(
            String ResultFilePath, CoreWebView2PrintSettings printSettings);
    }
}
```
# Appendix
