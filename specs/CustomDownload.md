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
We are redesigning the download experience by providing a DownloadStarting event, and exposing a downloadItem object with all associated download metadata. With this you will be able to block downloads, save to a different path, and have access to the required metadata to build your own download UI.


In this document we describe the updated API. We'd appreciate your feedback.

# Description

There are 3 parts to this API.

1. DownloadStarting Event - used to intercept a download.
    - DownloadItem: 
    - Cancel
    - Result file path (set)
2. WebView Setting: Default Download Dialogue - used to disable the default download UI (bottom dock)
3. DownloadItem: This will give you all the metadata that you might need to block a download, and build UI.
    - Url
    - Mime type
    - Content disposition
    - Total bytes
    - Result file path (get)
    - Danger
    - Received bytes
    - Estimated time
    - State (in progress, completed, etc.)
    - Error 
    - Id
    - Pause/resume/cancel
    - Deferral`

We beleive with these 3 parts of a redesigned Download API, should enable your app have an elegant download experience.

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
// This example hides the default download dialog and shows a dialog box instead.
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
                    wil::com_ptr<ICoreWebView2Settings> m_settings;
                    CHECK_FAILURE(m_webView->get_Settings(&m_settings));
                    wil::com_ptr<ICoreWebView2StagingSettings> m_settingsStaging =
                        m_settings.try_query<ICoreWebView2StagingSettings>();
                    CHECK_FAILURE(
                        m_settingsStaging->put_ShouldDisplayDefaultDownloadDialog(FALSE));

                    wil::com_ptr<ICoreWebView2StagingDownloadItem> downloadItem;
                    CHECK_FAILURE(args->DownloadItem(&downloadItem));

                    UINT64 downloadSizeInBytes = 0;
                    CHECK_FAILURE(downloadItem->get_DownloadSizeInBytes(&downloadSizeInBytes));

                    wil::unique_cotaskmem_string uri;
                    CHECK_FAILURE(downloadItem->get_Uri(&uri));

                    wil::unique_cotaskmem_string mimeType;
                    CHECK_FAILURE(downloadItem->get_MimeType(&mimeType));

                    wil::unique_cotaskmem_string contentDisposition;
                    CHECK_FAILURE(downloadItem->get_ContentDisposition(&contentDisposition));

                    // Get the suggested path from the event args.
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

                // This function can be called to show the download dialog and
                // complete the event at a later time, allowing the developer to
                // perform async work before the event completes.
                m_completeDeferredDownloadEvent = [showDialog, deferral] {
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
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        using (deferral)
        {
        
            if (_coreWebView2Settings == null)
            {
                _coreWebView2Settings = webView.CoreWebView2.Settings;
            }
            _coreWebView2Settings.ShouldDisplayDefaultDownloadDialog = false;

            var dialog = new TextInputDialog(
                title: "Download Starting",
                description: "Enter new result file path or select OK to keep default path. Select cancel to cancel the download.",
                defaultInput: args.ResultFilePath);
            if (dialog.ShowDialog() == true)
            {
            args.ResultFilePath = dialog.Input.Text;
            }
            else
            {
            args.Cancel = true;
            }
        }
    }, null);
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
// Enums and structs

typedef enum COREWEBVIEW2_DOWNLOAD_DANGER_TYPE {
  // The download is safe.
  DANGER_TYPE_NONE,
  // The download file is dangerous.
  DANGER_TYPE_FILE,
  // The URI leads to a malicious file download.
  DANGER_TYPE_URI,
  // The content of the file is dangerous.
  DANGER_TYPE_CONTENT,
  // Not enough data to know whether download is dangerous.
  DANGER_TYPE_UNCOMMON,
  // The host is known to serve dangerous content.
  DANGER_TYPE_HOST,
  // The download is an application or extension that modifies browser or
  // computer settings.
  DANGER_TYPE_POTENTIALLY_UNWANTED,
} COREWEBVIEW2_DOWNLOAD_DANGER_TYPE;

typedef enum COREWEBVIEW2_DOWNLOAD_STATE {
  /// The download is in progress.
  DOWNLOAD_IN_PROGRESS,
  /// The download has been interrupted.
  DOWNLOAD_INTERRUPTED,
  /// The download is complete.
  DOWNLOAD_COMPLETE,
} COREWEBVIEW2_DOWNLOAD_STATE;

[uuid(9aab8652-d89f-408d-8b2c-1ade3ab51d6d), object, pointer_default(unique)]
interface ICoreWebView2Settings : IUnknown {

  /// The host may set this flag to hide the default download dialog.
  [propget] HRESULT ShouldDisplayDefaultDownloadDialog(
    [out, retval] BOOL* shouldDisplayDefaultDownloadDialog);

  /// Sets the `ShouldDisplayDefaultDownloadDialog` property.
  [propput] HRESULT ShouldDisplayDefaultDownloadDialog(
    [in] BOOL shouldDisplayDefaultDownloadDialog);
}

[uuid(E8495255-938A-4784-9EAC-A4BEC8869872), object, pointer_default(unique)]
interface ICoreWebView2_3 : ICoreWebView2_2 {

  /// Add an event handler for the `DownloadStarting` event. This event is
  /// raised when a download has begun, blocking the default download dialog,
  /// but not blocking the progress of the download.
  ///
  /// The host can choose to cancel a download and change the result file path.
  /// If the host chooses to cancel the download, the download is not saved and
  /// no dialog is shown. Otherwise, the download is saved after the event completes, 
  /// and default download dialog is shown if the host did not choose to hide it.
  /// The host can change the visibility of the download dialog using the
  /// `ShouldDisplayDefaultDownloadDialog` property on `ICoreWebView2Settings`.
  ///
  /// If the event is not handled, downloads will complete normally with the
  /// default dialog shown.
  ///
  /// \snippet ScenarioCustomDownloadExperience.cpp CustomDownloadExperience
  HRESULT add_DownloadStarting(
    [in] ICoreWebView2StagingDownloadStartingEventHandler* eventHandler,
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
  /// Returns the `ICoreWebView2DownloadItem` for the download that has started.
  HRESULT DownloadItem([out, retval] ICoreWebView2DownloadItem** downloadItem);

  /// The host may set this flag to cancel the download. If canceled, the
  /// download save dialog will not be displayed regardless of the
  /// ShouldDisplayDefaultDownloadDialog property.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL cancel);

  /// The path to the file. If setting the path, the host should ensure that it
  /// is an absolute path, including the file name. If the directory does not
  /// exist, it will be created.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* resultFilePath);

  /// Sets the `ResultFilePath` property.
  [propput] HRESULT ResultFilePath([in] LPCWSTR resultFilePath);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

/// Represents a download process. Gives access to the download's metadata
/// and supports a user canceling, pausing, or resuming the download.
[uuid(0C4A07B1-B610-459F-A574-EC253D5EC40D), object, pointer_default(unique)]
interface ICoreWebView2DownloadItem : IUnknown
{
  /// The unique ID of the download.
  [propget] HRESULT Id([out, retval] UINT32* id);

  /// The URI of the download.
  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The Content-Disposition header value from HTTP response.
  [propget] HRESULT ContentDisposition([out, retval] LPWSTR* contentDisposition);

  /// MIME type of the downloaded content.
  [propget] HRESULT MimeType([out, retval] LPWSTR* mimeType);

  /// The size of the download in total number of expected bytes.
  [propget] HRESULT DownloadSizeInBytes([out, retval] UINT64* downloadSizeInBytes);
  
  /// The number of bytes that have been written to the download file.
  [propget] HRESULT ReceivedBytes([out, retval] UINT64* receivedBytes);

  /// The estimated end time in ISO 8601 format.
  [propget] HRESULT EstimatedEndTime([out, retval] LPWSTR* estimatedEndTime);

  /// The absolute path to the file, including file name. Host can change
  /// this from `ICoreWebView2DownloadStartingEventArgs`.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* resultFilePath);

  /// The danger type of the download. The danger type can be none, file, content,
  /// uncommon, host, or potentially unwanted. See `COREWEBVIEW2_DOWNLOAD_DANGER_TYPE`
  /// for more details.
  [propget] HRESULT DangerType([out, retval] COREWEBVIEW2_DOWNLOAD_DANGER_TYPE* dangerType);

  /// The state of the download. A download can be in progress, interrupted, or
  /// complete.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_DOWNLOAD_STATE* downloadState);

  /// The reason why a download was interrupted.
  [propget] HRESULT InterruptReason([out, retval] LPWSTR* interruptReason);

  /// Cancels the download. If canceled, the default download dialog will show that the
  /// download was canceled. Host should set `Cancel` from `ICoreWebView2SDownloadStartingEventArgs`
  /// if cancellation should be hidden from default download dialog.
  HRESULT Cancel();

  /// Pauses the download. If paused, the default download dialog will
  /// show that the download is paused. No effect if download is already paused.
  HRESULT Pause();

  /// Resumes a paused download. No effect if download is not paused.
  HRESULT Resume();
}
```
## .NET/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DownloadItem;
    runtimeclass CoreWebView2DownloadStartingEventArgs;

    enum CoreWebView2DownloadState
    {
        DownloadInProgress = 0,
        DownloadInterrupted = 1,
        DownloadComplete = 2,
    };
    enum CoreWebView2DownloadDangerType
    {
        DangerTypeNone = 0,
        DangerTypeFile = 1,
        DangerTypeUri = 2,
        DangerTypeContent = 3,
        DangerTypeUncommon = 4,
        DangerTypeHost = 5,
        DangerTypePotentiallyUnwanted = 6,
    };

    runtimeclass CoreWebView2Settings
    {
        // CoreWebView2Settings
        // There are other settings that we are not showing
        Boolean ShouldDisplayDefaultDownloadDialog { get; set; };
    }

     runtimeclass CoreWebView2DownloadStartingEventArgs
    {
        // CoreWebView2DownloadStartingEventArgs
        Boolean Cancel { get; set; };

        String ResultFilePath { get; set; };

        CoreWebView2DownloadItem DownloadItem();

        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // There are other API in this interface that we are not showing
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DownloadStartingEventArgs> DownloadStarting;
    }

     runtimeclass CoreWebView2DownloadItem
    {
        // CoreWebView2DownloadItem
        UInt32 id { get; };

        String Uri { get; };

        String ContentDisposition { get; };

        String MimeType { get; };

        UInt64 DownloadSizeInBytes { get; };

        UInt64 ReceivedBytes { get; };

        String EstimatedEndTime { get; };

        String ResultFilePath { get; };

        CoreWebView2DownloadDangerType DangerType { get; };

        CoreWebView2DownloadState State { get; };

        String InterruptReason { get; };

        void Cancel();

        void Pause();
        
        void Resume();
    }
}
```
# Appendix
<!-- TEMPLATE
    Anything else that you want to write down for posterity, but
    that isn't necessary to understand the purpose and usage of the API.
    For example, implementation details or links to other resources.
-->
