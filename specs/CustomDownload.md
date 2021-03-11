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
We are redesigning the download experience by providing a DownloadStarting event, and exposing a Download object with all associated download metadata. With this you will be able to block downloads, save to a different path, and have access to the required metadata to build your own download UI.


In this document we describe the updated API. We'd appreciate your feedback.

# Description

There are 3 parts to this API.

1. DownloadStarting [Event] - used to intercept a download.
    - Download (the download object below)
    - Cancel
    - Result file path (settable)
    - Deferral
2. Download [Object]: This will give you all the metadata that you might need to block a download, or build UI.
    - Uri
    - Mime type
    - Content disposition
    - Download size in bytes
    - Result file path (read only)
    - Progress size in bytes
    - Estimated end time
    - State (in progress, completed, interrupted)
    - Pause/resume/cancel
    - Events:
        - DownloadStateChanged
            - InterruptReason
        - DownloadProgressSizeInBytesChanged
        - DownloadEstimatedEndTimeChanged
3. WebView Setting: Default Download Dialog - used to disable the default download UI (bottom dock)

We believe these 3 parts of a redesigned Download API, should enable your app to have a customizable & complete download experience.

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
ScenarioCustomDownloadExperience::ScenarioCustomDownloadExperience(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    // Hide the default download dialog.
    wil::com_ptr<ICoreWebView2Settings> settings;
    CHECK_FAILURE(m_webView->get_Settings(&settings));
    CHECK_FAILURE(settings->put_ShouldDisplayDefaultDownloadDialog(FALSE));

    // Register a handler for the `DownloadStarting` event.
    // This example hides the default download dialog and shows a dialog box instead.
    // The dialog box displays the default save path and allows the user to specify a different path.
    // Selecting `OK` will save the download to the chosen path.
    // Selecting `CANCEL` will cancel the download.
    CHECK_FAILURE(m_webView->add_DownloadStarting(
        Callback<ICoreWebView2DownloadStartingEventHandler>(
            [this](
                ICoreWebView2_3* sender,
                ICoreWebView2DownloadStartingEventArgs* args) -> HRESULT
            {
                auto showDialog = [this, args]
                {
                    wil::com_ptr<ICoreWebView2Download> download;
                    CHECK_FAILURE(args->get_Download(&download));

                    INT64 expectedDownloadSizeInBytes = 0;
                    CHECK_FAILURE(download->get_ExpectedDownloadSizeInBytes(
                      &expectedDownloadSizeInBytes));

                    wil::unique_cotaskmem_string uri;
                    CHECK_FAILURE(download->get_Uri(&uri));

                    wil::unique_cotaskmem_string mimeType;
                    CHECK_FAILURE(download->get_MimeType(&mimeType));

                    wil::unique_cotaskmem_string contentDisposition;
                    CHECK_FAILURE(download->get_ContentDisposition(&contentDisposition));

                    // Get the suggested path from the event args.
                    wil::unique_cotaskmem_string resultFilePath;
                    CHECK_FAILURE(args->get_ResultFilePath(&resultFilePath));

                    std::wstring prompt =
                        std::wstring(L"Enter result file path or select `OK` to use default path. ") +
                        L"Select `Cancel` to cancel the download.";

                    std::wstring description = std::wstring(L"URI: ") + uri.get() + L"\r\n" +
                                                L"Mime type: " + mimeType.get() + L"\r\n" +
                                                L"Expected Download size in bytes: " +
                                                std::to_wstring(expectedDownloadSizeInBytes) +
                                                L"\r\n";

                    TextInputDialog dialog(
                        m_appWindow->GetMainWindow(), L"Download Starting", prompt.c_str(),
                        description.c_str(), resultFilePath.get());
                    if (dialog.confirmed)
                    {
                        // If user selects `OK`, the download will complete normally.
                        // Result file path will be updated if a new one was provided.
                        CHECK_FAILURE(args->put_ResultFilePath(dialog.input.c_str()));
                        UpdateProgress(download.get());
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
    &m_downloadStartingToken));
}

// Update download progress
void ScenarioCustomDownloadExperience::UpdateProgress(ICoreWebView2Download* download)
{
    // Register a handler for the `DownloadProgressSizeInBytesChanged` event.
    CHECK_FAILURE(download->add_DownloadProgressSizeInBytesChanged(
        Callback<ICoreWebView2DownloadProgressSizeInBytesChangedEventHandler>(
            [this](ICoreWebView2Download* download, IUnknown* args) -> HRESULT {
                // Here developer can update UI to show progress of a download using
                // `download->get_DownloadProgressSizeInBytes` and
                // `download->get_ExpectedDownloadSizeInBytes`.
                return S_OK;
            })
        .Get(),
    &m_downloadProgressSizeInBytesChangedToken));

    // Register a handler for the `DownloadStateChanged` event.
    CHECK_FAILURE(download->add_DownloadStateChanged(
        Callback<ICoreWebView2DownloadStateChangedEventHandler>(
            [this](ICoreWebView2Download* download,
            ICoreWebView2DownloadStateChangedEventArgs* args) -> HRESULT {
                COREWEBVIEW2_DOWNLOAD_STATE downloadState;
                CHECK_FAILURE(download->get_State(&downloadState));
                switch (downloadState)
                {
                case COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS:
                    break;
                case COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED:
                    // Here developer can take different actions based on `args->InterruptReason`.
                    CompleteDownload(download);
                    break;
                case COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED:
                    CompleteDownload(download);
                    break;
                }
                return S_OK;
            })
        .Get(),
    &m_downloadStateChangedToken));
}
```
## .NET/ WinRT
```c#
void DownloadStartingCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    if (_coreWebView2Settings == null)
    {
        _coreWebView2Settings = webView.CoreWebView2.Settings;
    }
    _coreWebView2Settings.ShouldDisplayDefaultDownloadDialog = false;

    webView.CoreWebView2.DownloadStarting += delegate (object sender, CoreWebView2DownloadStartingEventArgs args)
    {
        CoreWebView2Deferral deferral = args.GetDeferral();
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            using (deferral)
            {
                var dialog = new TextInputDialog(
                    title: "Download Starting",
                    description: "Enter new result file path or select OK to keep default path. Select cancel to cancel the download.",
                    defaultInput: args.ResultFilePath);
                if (dialog.ShowDialog() == true)
                {
                    args.ResultFilePath = dialog.Input.Text;
                    UpdateProgress(args.Download);
                }
                else
                {
                    args.Cancel = true;
                }
            }
        }, null);
    };
}

// Update download progress
void UpdateProgress(CoreWebView2Download download)
{
    download.DownloadProgressSizeInBytesChanged += delegate (object sender, Object e)
    {
        // Here developer can update download dialog to show progress of a download using
        // `download.DownloadProgressSizeInBytes` and `download.ExpectedDownloadSizeInBytes`
    };

    download.DownloadStateChanged += delegate (object sender, CoreWebView2DownloadStateChangedEventArgs args)
    {
        switch (download.State)
        {
          case CoreWebView2DownloadState.InProgress:
            break;
          case CoreWebView2DownloadState.Interrupted:
            // Here developer can take different actions based on `args.InterruptReason`.
            break;
          case CoreWebView2DownloadState.Completed:
            break;
        }
    };
}
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

typedef enum COREWEBVIEW2_DOWNLOAD_STATE {
  /// The download is in progress.
  COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS,
  /// The connection with the file host was broken. The `InterruptReason` property
  /// can be accessed from `ICoreWebView2DownloadStateChangedEventArgs`. See
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON` for descriptions of kinds of
  /// interrupt reasons. Host can check whether an interrupted download can be
  /// resumed with the `CanResume` property on the `ICoreWebView2Download`. Once
  /// resumed, a download is in the `COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS` state.
  COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED,
  /// The download completed successfully.
  COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED,
} COREWEBVIEW2_DOWNLOAD_STATE;

typedef enum COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON {
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NONE,

  /// File errors
  /// Generic file error.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_FAILED,
  /// Access denied due to security restrictions.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_ACCESS_DENIED,
  /// Disk full.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_NO_SPACE,
  /// Result file path with file name is too long.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_NAME_TOO_LONG,
  /// File is too large for file system.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_LARGE,
  /// File contains a virus.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_VIRUS_INFECTED,
  /// File was in use, too many files opened, or out of memory.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TRANSIENT_ERROR,
  /// File blocked by local policy.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_BLOCKED,
  /// Security check failed unexpectedly.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_SECURITY_CHECK_FAILED,
  /// Seeking past the end of a file in opening a file, as part of resuming an
  /// interrupted download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_SHORT,
  /// Partial file did not match the expected hash.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_HASH_MISMATCH,
  /// Source and target of download were the same.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_SAME_AS_SOURCE,

  /// Network errors
  /// Generic network error.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_FAILED,
  /// Network operation timed out.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_TIMEOUT,
  /// Network connection lost.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_DISCONNECTED,
  /// Server has gone down.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_SERVER_DOWN,
  /// Network request invalid because original or redirected URI is invalid, has
  /// an unsupported scheme, or is disallowed by policy.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_INVALID_REQUEST,

  /// Server responses
  /// Generic server error.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_FAILED,
  /// Server does not support range requests.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_NO_RANGE,
  /// Server does not have the requested data.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_BAD_CONTENT,
  /// Server did not authorize access to resource.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_UNAUTHORIZED,
  /// Server certificate problem.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CERT_PROBLEM,
  /// Server access forbidden.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_FORBIDDEN,
  /// Unexpected server response. Responding server may not be intended server.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_UNREACHABLE,
  /// Server sent fewer bytes than the content-length header. Content-length
  /// header may be invalid or connection may have closed. Download is treated
  /// as complete unless there are strong validators present to interrupt the
  /// download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CONTENT_LENGTH_MISMATCH,
  /// Unexpected cross-origin redirect.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CROSS_ORIGIN_REDIRECT,

  /// User input
  /// User canceled the download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_CANCELED,
  /// User shut down the WebView.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_SHUTDOWN,
  /// User paused the download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_PAUSED,

  /// WebView crashed.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_DOWNLOAD_PROCESS_CRASHED,
} COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON;

[uuid(9aab8652-d89f-408d-8b2c-1ade3ab51d6d), object, pointer_default(unique)]
interface ICoreWebView2Settings2 : ICoreWebView2Settings {

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
  /// Returns the `ICoreWebView2Download` for the download that has started.
  [propget] HRESULT Download([out, retval] ICoreWebView2Download** download);

  /// The host may set this flag to cancel the download. If canceled, the
  /// download save dialog will not be displayed regardless of the
  /// ShouldDisplayDefaultDownloadDialog property.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL cancel);

  /// The path to the file. If setting the path, the host should ensure that it
  /// is an absolute path, including the file name. If the directory does not
  /// exist, it will be created. If the path points to an existing file, the
  /// actual file name used will have an ` (N)` suffix appended.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* resultFilePath);

  /// Sets the `ResultFilePath` property.
  [propput] HRESULT ResultFilePath([in] LPCWSTR resultFilePath);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

/// Implements the interface to receive `DownloadProgressSizeInBytesChanged`
/// event.  Use the `ICoreWebView2Download.DownloadProgressSizeInBytes` property
/// to get the received bytes count.

[uuid(D98F73CE-D94D-4576-A1E0-EB8989A9DBEF), object, pointer_default(unique)]
interface ICoreWebView2DownloadProgressSizeInBytesChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2Download* sender, [in] IUnknown* args);
}

/// Implements the interface to receive `DownloadEstimatedEndTimeChanged` event. Use the
/// `ICoreWebView2Download.EstimatedEndTime` property to get the new estimated
/// end time.

[uuid(D46CD703-958B-4100-9F84-4E6C2FC32D57), object, pointer_default(unique)]
interface ICoreWebView2DownloadEstimatedEndTimeChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2Download* sender, [in] IUnknown* args);
}

/// Implements the interface to receive `DownloadStateChanged` event. Use the
/// `ICoreWebView2Download.State` property to get the current state, which can
/// be in progress, interrupted, or complete. Find the `InterruptReason` property
/// on `ICoreWebView2DownloadStateChangedEventArgs`.
[uuid(74EEBAA9-704B-4A9A-8331-AEBD541CB62C), object, pointer_default(unique)]
interface ICoreWebView2DownloadStateChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Download* sender,
      [in] ICoreWebView2DownloadStateChangedEventArgs* args);
}

/// Event args for the `DownloadStateChanged` event.
[uuid(28E3F13A-4DB1-4738-A0A7-FC4B6F6765AD), object, pointer_default(unique)]
interface ICoreWebView2DownloadStateChangedEventArgs : IUnknown
{
  /// The reason why connection with file host was broken.
  [propget] HRESULT InterruptReason(
      [out, retval] COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON* interruptReason);
}

/// Represents a download process. Gives access to the download's metadata
/// and supports a user canceling, pausing, or resuming the download.
[uuid(0C4A07B1-B610-459F-A574-EC253D5EC40D), object, pointer_default(unique)]
interface ICoreWebView2Download : IUnknown
{
  /// Add an event handler for the `DownloadProgressSizeInBytesChanged` event.
  HRESULT add_DownloadProgressSizeInBytesChanged(
    [in] ICoreWebView2DownloadProgressSizeInBytesChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_DownloadProgressSizeInBytesChanged`.
  HRESULT remove_DownloadProgressSizeInBytesChanged(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `DownloadEstimatedEndTimeChanged` event.
  HRESULT add_DownloadEstimatedEndTimeChanged(
    [in] ICoreWebView2DownloadEstimatedEndTimeChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_DownloadEstimatedEndTimeChanged`.
  HRESULT remove_DownloadEstimatedEndTimeChanged(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `DownloadStateChanged` event.
  HRESULT add_DownloadStateChanged(
    [in] ICoreWebView2DownloadStateChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_DownloadStateChanged`.
  HRESULT remove_DownloadStateChanged(
      [in] EventRegistrationToken token);

  /// The URI of the download.
  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The Content-Disposition header value from HTTP response.
  [propget] HRESULT ContentDisposition([out, retval] LPWSTR* contentDisposition);

  /// MIME type of the downloaded content.
  [propget] HRESULT MimeType([out, retval] LPWSTR* mimeType);

  /// The expected size of the download in total number of bytes based on the
  /// HTTP content-length header. Returns -1 if the size is unknown.
  [propget] HRESULT ExpectedDownloadSizeInBytes(
    [out, retval] INT64* expectedDownloadSizeInBytes);

  /// The number of bytes that have been written to the download file.
  [propget] HRESULT DownloadProgressSizeInBytes([out, retval] UINT64* downloadProgressSizeInBytes);

  /// The estimated end time in ISO 8601 format.
  [propget] HRESULT EstimatedEndTime([out, retval] LPWSTR* estimatedEndTime);

  /// The absolute path to the file, including file name. Host can change
  /// this from `ICoreWebView2DownloadStartingEventArgs`.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* resultFilePath);

  /// The state of the download. A download can be in progress, interrupted, or
  /// complete. See `COREWEBVIEW2_DOWNLOAD_STATE` for descriptions of states.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_DOWNLOAD_STATE* downloadState);

  /// Cancels the download. If canceled, the default download dialog will show
  /// that the download was canceled. Host should set the `Cancel` property from
  /// `ICoreWebView2SDownloadStartingEventArgs` if the download should be
  /// cancelled without displaying the default download dialog.
  HRESULT Cancel();

  /// Pauses the download. If paused, the default download dialog will
  /// show that the download is paused. No effect if download is already paused.
  /// Pausing a download will change the state to `COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED`
  /// with `InterruptReason` set to `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_PAUSED`.
  HRESULT Pause();

  /// Resumes a paused download. May also resume a download that was interrupted
  /// for another reason, if `CanResume` returns true. Resuming a download will
  /// change the state from `COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED` to
  /// `COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS`.
  HRESULT Resume();

  /// Returns whether user has paused the download.
  [propget] HRESULT IsPaused([out, retval] BOOL* isPaused);

  /// Returns true if an interrupted download can be resumed. Downloads with
  /// the following interrupt reasons may be auto-resumed:
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_NO_RANGE`,
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_HASH_MISMATCH`,
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_SHORT`.
  [propget] HRESULT CanResume([out, retval] BOOL* canResume);
}
```
## .NET/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Download;
    runtimeclass CoreWebView2DownloadStartingEventArgs;
    runtimeclass CoreWebView2DownloadStateChangedEventArgs;

    enum CoreWebView2DownloadState
    {
        InProgress = 0,
        Interrupted = 1,
        Completed = 2,
    };
    enum CoreWebView2DownloadInterruptReason
    {
        None = 0,
        FileFailed = 1,
        FileAccessDenied = 2,
        FileNoSpace = 3,
        FileNameTooLong = 4,
        FileTooLarge = 5,
        FileVirusInfected = 6,
        FileTransientError = 7,
        FileBlocked = 8,
        FileSecurityCheckFailed = 9,
        FileTooShort = 10,
        FileHashMismatch = 11,
        FileSameAsSource = 12,
        NetworkFailed = 13,
        NetworkTimeout = 14,
        NetworkDisconnected = 15,
        NetworkServerDown = 16,
        NetworkInvalidRequest = 17,
        ServerFailed = 18,
        ServerNoRange = 19,
        ServerBadContent = 20,
        ServerUnauthorized = 21,
        ServerCertProblem = 22,
        ServerForbidden = 23,
        ServerUnreachable = 24,
        ServerContentLengthMismatch = 25,
        ServerCrossOriginRedirect = 26,
        UserCanceled = 27,
        UserShutdown = 28,
        UserPaused = 29,
        DownloadProcessCrashed = 30,
    };

    runtimeclass CoreWebView2Settings
    {
        // CoreWebView2Settings
        // There are other settings that we are not showing
        Boolean ShouldDisplayDefaultDownloadDialog { get; set; };
    }

    runtimeclass CoreWebView2DownloadStateChangedEventArgs
    {
        // CoreWebView2DownloadStateChangedEventArgs
        CoreWebView2DownloadInterruptReason InterruptReason { get; };
    }

    runtimeclass CoreWebView2DownloadStartingEventArgs
    {
        // CoreWebView2DownloadStartingEventArgs
        CoreWebView2Download Download { get; };

        Boolean Cancel { get; set; };

        String ResultFilePath { get; set; };

        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // There are other API in this interface that we are not showing
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DownloadStartingEventArgs> DownloadStarting;
    }

    runtimeclass CoreWebView2Download
    {
        // CoreWebView2Download
        String Uri { get; };

        String ContentDisposition { get; };

        String MimeType { get; };

        Int64 ExpectedDownloadSizeInBytes { get; };

        UInt64 DownloadProgressSizeInBytes { get; };

        Windows.Foundation.DateTime EstimatedEndTime { get; };

        String ResultFilePath { get; };

        CoreWebView2DownloadState State { get; };

        Boolean IsPaused { get; };

        Boolean CanResume { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2Download, Object> DownloadProgressSizeInBytesChanged;
        event Windows.Foundation.TypedEventHandler<CoreWebView2Download, Object> DownloadEstimatedEndTimeChanged;
        event Windows.Foundation.TypedEventHandler<CoreWebView2Download, CoreWebView2DownloadStateChangedEventArgs> DownloadStateChanged;

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
