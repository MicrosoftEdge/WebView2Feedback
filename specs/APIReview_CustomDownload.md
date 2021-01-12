# Background
<!-- TEMPLATE
    Use this section to provide background context for the new API(s)
    in this spec.

    This section and the appendix are the only sections that likely
    do not get copied into any official documentation, they're just an aid
    to reading this spec.

    If you're modifying an existing API, included a link here to the
    existing page(s) or spec documentation.

    For example, this section is a place to explain why you're adding this
    API rather than modifying an existing API.

    For example, this is a place to provide a brief explanation of some dependent
    area, just explanation enough to understand this new API, rather than telling
    the reader "go read 100 pages of background information posted at ...".
-->
There have been multiple requests by WebView Developers to be able to customize/control the download experience within WebView2.

Some of the requests we've heard, and want to solve with this API are:
- Developers want to be able to disable downloads for the entire environment.
- Developers want to be able to disable downloads on a per-case basis. For example, based on the content type, or user.
- Developers want to have access to downloaded file’s metadata, and be able to prevent downloads based on this information.
   Ex. Dev wants to block downloads above 1GB.
- Developers want to modify the download path.
- Developer don’t want to see edge download UI if download is cancelled.

In this document we describe the updated API. We'd appreciate your feedback.

# Description

Our proposed solution is to give developers an API to control the download experience.
We will do this by exposing a DownloadStarting event.

The DownloadStarting event will be raised when a download has begun.
The host can then choose to cancel a download, change the save path, and hide the default download dialog.
If the event is not handled, downloads will complete normally with the default download dialog shown.

Additionally, the developer will have access to the url, size, mime type, and content disposition
header.


# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.

    The general format is:

    ## FirstFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```

    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    ## SecondFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```

    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    As an example of this section, see the Examples section for the PasswordBox
    control (https://docs.microsoft.com/windows/uwp/design/controls-and-patterns/password-box#examples).
-->
## Win32 C++
```cpp
// Register a handler for the `DownloadStarting` event.
// This example hides the default downloads UI and shows a dialog box instead.
// The dialog box displays the default save path and allows the user to specify a different path.
// Selecting `OK` will save the download to the chosen path.
// Selecting `CANCEL` will cancel the download.
m_webViewStaging = m_webView.query<ICoreWebView2Staging2>();
m_demoUri = L"https://demo.smartscreen.msft.net/";
    CHECK_FAILURE(m_webViewStaging->add_DownloadStarting(
        Callback<ICoreWebView2StagingDownloadStartingEventHandler>(
            [this](
                ICoreWebView2Staging2* sender,
                ICoreWebView2StagingDownloadStartingEventArgs* args) -> HRESULT {
                auto showDialog = [this, args] {
                    // Hide the default download dialog.
                    CHECK_FAILURE(args->put_ShouldDisplayDefaultDownloadDialog(FALSE));

                    UINT64 downloadSizeInBytes = 0;
                    CHECK_FAILURE(args->get_DownloadSizeInBytes(&downloadSizeInBytes));

                    wil::unique_cotaskmem_string uri;
                    CHECK_FAILURE(args->get_Uri(&uri));

                    wil::unique_cotaskmem_string mimeType;
                    CHECK_FAILURE(args->get_MimeType(&mimeType));

                    wil::unique_cotaskmem_string contentDisposition;
                    CHECK_FAILURE(args->get_ContentDisposition(&contentDisposition));

                    wil::unique_cotaskmem_string resultFilePath;
                    CHECK_FAILURE(args->get_ResultFilePath(&resultFilePath));

                    std::wstring prompt =
                        std::wstring(L"Enter result file path or select `OK` to use default path. ") +
                        L"Select `Cancel` to cancel the download.";

                    std::wstring description = std::wstring(L"URI: ") + uri.get() + L"\r\n" +
                                               L"Mime type: " + mimeType.get() + L"\r\n" +
                                               L"Download size in bytes: " + std::to_wstring(downloadSizeInBytes) +
                                               L"\r\n";

                    TextInputDialog dialog(
                        m_appWindow->GetMainWindow(), L"Download Starting", prompt.c_str(),
                        description.c_str(), resultFilePath.get());
                    if (dialog.confirmed)
                    {
                        // If user selects `OK`, the download will complete normally.
                        // Result file path will be updated if a new one was provided.
                        CHECK_FAILURE(args->put_ResultFilePath(dialog.input.c_str()));
                    }
                    else
                    {
                        // If user selects `Cancel`, the download will be canceled.
                        CHECK_FAILURE(args->put_Cancel(TRUE));
                    }
                };

                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));

                m_completeDefferedDownloadEvent = [showDialog, deferral] {
                    showDialog();
                    CHECK_FAILURE(deferral->Complete());
                };

                return S_OK;
            })
            .Get(),
        &m_DownloadStartingToken));
```
## .NET/ WinRT
```c#
webView.CoreWebView2.DownloadStarting += delegate (object sender, CoreWebView2DownloadStartingEventArgs args)
{
  CoreWebView2Deferral deferral = args.GetDeferral();
  using (deferral)
  {
      args.HideUI = 1;
      var dialog = new TextInputDialog(
          title: "Download Starting",
          description: "Enter new save path or select OK to keep default path. Select cancel to cancel the download.",
          defaultInput: args.SavePath);
      if (dialog.ShowDialog() == true)
      {
        args.SavePath = dialog.Input.Text;
      }
      else args.Cancel = true;
  }
};
```
# Remarks
<!-- TEMPLATE
    Explanation and guidance that doesn't fit into the Examples section.

    APIs should only throw exceptions in exceptional conditions; basically,
    only when there's a bug in the caller, such as argument exception.  But if for some
    reason it's necessary for a caller to catch an exception from an API, call that
    out with an explanation either here or in the Examples
-->


# API Notes
<!-- TEMPLATE
    Option 1: Give a one or two line description of each API (type and member),
        or at least the ones that aren't obvious from their name. These
        descriptions are what show up in IntelliSense. For properties, specify
        the default value of the property if it isn't the type's default (for
        example an int-typed property that doesn't default to zero.)

    Option 2: Put these descriptions in the below API Details section,
        with a "///" comment above the member or type.
-->
See [API Details](#api-details) section below for API reference.

# API Details
<!-- TEMPLATE
    The exact API, in IDL format for our COM API and
    in MIDL3 format (https://docs.microsoft.com/en-us/uwp/midl-3/)
    when possible, or in C# if starting with an API sketch for our .NET and WinRT API.

    Include every new or modified type but use // ... to remove any methods,
    properties, or events that are unchanged.

    (GitHub's markdown syntax formatter does not (yet) know about MIDL3, so
    use ```c# instead even when writing MIDL3.)

    Example:

    ```
    /// Event args for the NewWindowRequested event. The event is fired when content
    /// inside webview requested to open a new window (through window.open() and so on.)
    [uuid(34acb11c-fc37-4418-9132-f9c21d1eafb9), object, pointer_default(unique)]
    interface ICoreWebView2NewWindowRequestedEventArgs : IUnknown
    {
        // ...

        /// Window features specified by the window.open call.
        /// These features can be considered for positioning and sizing of
        /// new webview windows.
        [propget] HRESULT WindowFeatures([out, retval] ICoreWebView2WindowFeatures** windowFeatures);
    }
    ```

    ```c# (but really MIDL3)
    public class CoreWebView2NewWindowRequestedEventArgs
    {
        // ...

	       public CoreWebView2WindowFeatures WindowFeatures { get; }
    }
    ```
-->
## Win32 C++
```c#
[uuid(9EAFB7D0-88C3-4450-BBFB-C05A46C40C72), object, pointer_default(unique)]
interface ICoreWebView2_3 : ICoreWebView2_2 {

  /// Add an event handler for the `DownloadStarting` event. This event is
  /// raised when a download has begun, blocking the default download dialog,
  /// but not blocking the progress of the download.
  ///
  /// The host can choose to cancel a download, change the save path, and hide
  /// the default download dialog. If the host chooses to cancel the download, the
  /// download is not saved and no dialog is shown. Otherwise, the download is saved
  /// once the event completes, and default download dialog is shown if the host
  /// did not choose to hide it.
  ///
  /// If the event is not handled, downloads will complete normally with the
  /// default dialog shown.
  ///
  HRESULT add_DownloadStarting(
    [in] ICoreWebView2DownloadStartingEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_DownloadStarting`.
  HRESULT remove_DownloadStarting(
      [in] EventRegistrationToken token);
}

[uuid(53b676ec-c3b1-4804-996a-c72c16b09efb), object, pointer_default(unique)]
interface ICoreWebView2DownloadStartingEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2_3* sender,
      [in] ICoreWebView2DownloadStartingEventArgs* args);
}

/// Event args for the `DownloadStarting` event.
[uuid(c7e95e2f-f789-44e6-b372-3141469240e4), object, pointer_default(unique)]
interface ICoreWebView2DownloadStartingEventArgs : IUnknown
{
  /// The URI of the download.
  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The Content-Disposition header value from HTTP response.
  [propget] HRESULT ContentDisposition([out, retval] LPWSTR* contentDisposition);

  /// MIME type of the downloaded content.
  [propget] HRESULT MimeType([out, retval] LPWSTR* mimeType);

  /// The size of the download in total number of expected bytes.
  [propget] HRESULT DownloadSizeInBytes([out, retval] UINT64* downloadSizeInBytes);

  /// The host may set this flag to cancel the download. If canceled, the
  /// download save dialog will not be displayed regardless of the
  /// ShouldDisplayDefaultDownloadDialog property.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL cancel);

  /// The result file path of the download.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* resultFilePath);

  /// Sets the `ResultFilePath` property.
  [propput] HRESULT ResultFilePath([in] LPCWSTR resultFilePath);

  /// The host may set this flag to hide the default download dialog.
  [propget] HRESULT ShouldDisplayDefaultDownloadDialog([out, retval] BOOL* shouldDisplayDefaultDownloadDialog);

  /// Sets the `ShouldDisplayDefaultDownloadDialog` property.
  [propput] HRESULT ShouldDisplayDefaultDownloadDialog([in] BOOL shouldDisplayDefaultDownloadDialog);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}
```
## .NET/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DownloadStartingEventArgs;

    runtimeclass CoreWebView2DownloadStartingEventArgs
    {
        // CoreWebView2DownloadStartingEventArgs
        String Uri { get; };

        String ContentDisposition { get; };

        String MimeType { get; };

        UInt64 DownloadSizeInBytes { get; };

        Boolean Cancel { get; set; };

        String ResultFilePath { get; set; };

        Boolean ShouldDisplayDefaultDownloadDialog { get; set; };

        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // There are other API in this interface that we are not showing
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DownloadStartingEventArgs> DownloadStarting;
    }
}
```
# Appendix
<!-- TEMPLATE
    Anything else that you want to write down for posterity, but
    that isn't necessary to understand the purpose and usage of the API.
    For example, implementation details or links to other resources.
-->
