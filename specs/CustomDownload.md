# Background
We are redesigning the download experience by providing a DownloadStarting event, and exposing a Download object with all associated download metadata. With this you will be able to block downloads, save to a different path, and have access to the required metadata to build your own download UI.

In this document we describe the updated API. We'd appreciate your feedback.

# Description

There are 2 parts to this API: the CoreWebView2.DownloadStarting event and the DownloadOperation class. The DownloadStarting event can be used to find out about or cancel new downloads and hide the default download dialog. The DownloadOperation object available from the DownloadStarting event has up to date information on a download as it progresses.

# Examples

## Win32 C++
```cpp
ScenarioCustomDownloadExperience::ScenarioCustomDownloadExperience(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    // Register a handler for the `DownloadStarting` event.
    // This example hides the default download dialog and shows a dialog box instead.
    // The dialog box displays the default result file path and allows the user to specify a different path.
    // Selecting `OK` will save the download to the chosen path.
    // Selecting `CANCEL` will cancel the download.
    CHECK_FAILURE(m_webView->add_DownloadStarting(
        Callback<ICoreWebView2DownloadStartingEventHandler>(
            [this](
                ICoreWebView2_3* sender,
                ICoreWebView2DownloadStartingEventArgs* args) -> HRESULT
            {
                // We avoid potential reentrancy from running a message loop in the download
                // starting event handler by showing our download dialog via this lambda run
                // asynchronously later outside of this event handler. Note that a long running
                // synchronous UI prompt or other blocking item on the UI thread can potentially
                // block the WebView2 from doing anything.
                auto showDialog = [this, args]
                {
                    // Hide the default download dialog.
                    CHECK_FAILURE(args->put_Handled(TRUE));

                    wil::com_ptr<ICoreWebView2SDownloadOperation> download;
                    CHECK_FAILURE(args->get_DownloadOperation(&download));

                    INT64 totalBytesToReceive = 0;
                    CHECK_FAILURE(download->get_TotalBytesToReceive(&totalBytesToReceive));

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
                        std::wstring(
                            L"Enter result file path or select `OK` to use default path. "
                            L"Select `Cancel` to cancel the download.");

                    std::wstring description = std::wstring(L"URI: ") + uri.get() + L"\r\n" +
                                                L"Mime type: " + mimeType.get() + L"\r\n";
                    if (totalBytesToReceive >= 0)
                    {
                        description = description + L"Total bytes to receive: " +
                                      std::to_wstring(totalBytesToReceive) + L"\r\n";
                    }

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

                // Obtain a deferral for the event so that the CoreWebView2
                // doesn't examine the properties we set on the event args until
                // after we call the Complete method asynchronously later.
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));

                // We avoid potential reentrancy from running a message loop in
                // the download starting event handler by showing our download
                // dialog later when we complete the deferral asynchronously.
                PostWorkItemToUIThread([showDialog, deferral] {
                    showDialog();
                    CHECK_FAILURE(deferral->Complete());
                });

                return S_OK;
            })
        .Get(),
    &m_downloadStartingToken));
}

// Update download progress
void ScenarioCustomDownloadExperience::UpdateProgress(ICoreWebView2DownloadOperation* download)
{
    CHECK_FAILURE(download->add_BytesReceivedChanged(
        Callback<ICoreWebView2BytesReceivedChangedEventHandler>(
            [this](ICoreWebView2DownloadOperation* download, IUnknown* args) -> HRESULT {
                // Here developer can update UI to show progress of a download using
                // `download->get_BytesReceived` and
                // `download->get_TotalBytesToReceive`.
                return S_OK;
            })
            .Get(),
        &m_bytesReceivedChangedToken));

    CHECK_FAILURE(download->add_StateChanged(
        Callback<ICoreWebView2StateChangedEventHandler>(
          [this](ICoreWebView2DownloadOperation* download,
            IUnknown* args) -> HRESULT {
                COREWEBVIEW2_DOWNLOAD_STATE state;
                CHECK_FAILURE(download->get_State(&state));
                switch (state)
                {
                case COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS:
                    break;
                case COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED:
                    // Here developer can take different actions based on `download->InterruptReason`.
                    // For example, show an error message to the end user.
                    CompleteDownload(download);
                    break;
                case COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED:
                    CompleteDownload(download);
                    break;
                }
                return S_OK;
            })
        .Get(),
    &m_stateChangedToken));
}
```
## .NET/ WinRT
```c#
void DownloadStartingCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.DownloadStarting += delegate (object sender, CoreWebView2DownloadStartingEventArgs args)
    {
        // Developer can obtain a deferral for the event so that the CoreWebView2
        // doesn't examine the properties we set on the event args until
        // after the deferral completes asynchronously.
        CoreWebView2Deferral deferral = args.GetDeferral();

        // We avoid potential reentrancy from running a message loop in the download
        // starting event handler by showing our download dialog later when we
        // complete the deferral asynchronously.
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            using (deferral)
            {
                // Hide the default download dialog.
                args.Handled = true;
                var dialog = new TextInputDialog(
                    title: "Download Starting",
                    description: "Enter new result file path or select OK to keep default path. Select cancel to cancel the download.",
                    defaultInput: args.ResultFilePath);
                if (dialog.ShowDialog() == true)
                {
                    args.ResultFilePath = dialog.Input.Text;
                    UpdateProgress(args.DownloadOperation);
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
void UpdateProgress(CoreWebView2DownloadOperation download)
{
    download.BytesReceivedChanged += delegate (object sender, Object e)
    {
      // Here developer can update download dialog to show progress of a
      // download using `download.BytesReceived` and `download.TotalBytesToReceive`
    };

    download.StateChanged += delegate (object sender, Object e)
    {
        switch (download.State)
        {
          case CoreWebView2DownloadState.InProgress:
            break;
          case CoreWebView2DownloadState.Interrupted:
            // Here developer can take different actions based on `download.InterruptReason`.
            // For example, show an error message to the end user.
            break;
          case CoreWebView2DownloadState.Completed:
            break;
        }
    };
}
```
# Remarks

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```c#
// Enums and structs

typedef enum COREWEBVIEW2_DOWNLOAD_STATE {
  /// The download is in progress.
  COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS,
  /// The connection with the file host was broken. The `InterruptReason` property
  /// can be accessed from `ICoreWebView2DownloadOperation`. See
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON` for descriptions of kinds of
  /// interrupt reasons. Host can check whether an interrupted download can be
  /// resumed with the `CanResume` property on the `ICoreWebView2DownloadOperation`.
  /// Once resumed, a download is in the `COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS` state.
  COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED,
  /// The download completed successfully.
  COREWEBVIEW2_DOWNLOAD_STATE_COMPLETED,
} COREWEBVIEW2_DOWNLOAD_STATE;

typedef enum COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON {
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NONE,

  /// Generic file error.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_FAILED,
  /// Access denied due to security restrictions.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_ACCESS_DENIED,
  /// Disk full. User should free some space or choose a different location to
  /// store the file.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_NO_SPACE,
  /// Result file path with file name is too long.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_NAME_TOO_LONG,
  /// File is too large for file system.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_LARGE,
  /// Microsoft Defender Smartscreen detected a virus in the file.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_MALICIOUS,
  /// File was in use, too many files opened, or out of memory.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TRANSIENT_ERROR,
  /// File blocked by local policy.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_BLOCKED_BY_POLICY,
  /// Security check failed unexpectedly. Microsoft Defender SmartScreen could
  //  not scan this file.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_SECURITY_CHECK_FAILED,
  /// Seeking past the end of a file in opening a file, as part of resuming an
  /// interrupted download. The file did not exist or was not as large as
  /// expected. Partially downloaded file was truncated or deleted, and download
  /// will be restarted automatically.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_SHORT,
  /// Partial file did not match the expected hash and was deleted. Download
  /// will be restarted automatically.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_HASH_MISMATCH,
  /// Source and target of download were the same.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_SAME_AS_SOURCE,

  /// Generic network error. User can retry the download manually.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_FAILED,
  /// Network operation timed out.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_TIMEOUT,
  /// Network connection lost. User can retry the download manually.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_DISCONNECTED,
  /// Server has gone down. User can retry the download manually.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_SERVER_DOWN,
  /// Network request invalid because original or redirected URI is invalid, has
  /// an unsupported scheme, or is disallowed by network policy.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_NETWORK_INVALID_REQUEST,

  /// Generic server error. User can retry the download manually.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_FAILED,
  /// Server does not support range requests.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_NO_RANGE,
  /// Server does not have the requested data.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_BAD_CONTENT,
  /// Server did not authorize access to resource.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_UNAUTHORIZED,
  /// Server certificate problem.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CERTIFICATE_PROBLEM,
  /// Server access forbidden.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_FORBIDDEN,
  /// Unexpected server response. Responding server may not be intended server.
  /// User can retry the download manually.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_UNEXPECTED_RESPONSE,
  /// Server sent fewer bytes than the content-length header. Content-length
  /// header may be invalid or connection may have closed. Download is treated
  /// as complete unless there are
  /// [strong validators](https://tools.ietf.org/html/rfc7232#section-2) present
  /// to interrupt the download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CONTENT_LENGTH_MISMATCH,
  /// Unexpected cross-origin redirect.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_CROSS_ORIGIN_REDIRECT,

  /// User canceled the download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_CANCELED,
  /// User shut down the WebView. Resuming downloads that were interrupted
  /// during shutdown is not yet supported.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_SHUTDOWN,
  /// User paused the download.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_PAUSED,

  /// WebView crashed.
  COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_DOWNLOAD_PROCESS_CRASHED,
} COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON;


[uuid(E8495255-938A-4784-9EAC-A4BEC8869872), object, pointer_default(unique)]
interface ICoreWebView2_3 : ICoreWebView2_2 {

  /// Add an event handler for the `DownloadStarting` event. This event is
  /// raised when a download has begun, blocking the default download dialog,
  /// but not blocking the progress of the download.
  ///
  /// The host can choose to cancel a download, change the result file path,
  /// and hide the default download dialog.
  /// If the host chooses to cancel the download, the download is not saved, no
  /// dialog is shown, and the state is changed to
  /// COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED with interrupt reason
  /// COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_CANCELED. Otherwise, the
  /// download is saved to the default path after the event completes,
  /// and default download dialog is shown if the host did not choose to hide it.
  /// The host can change the visibility of the download dialog using the
  /// `Handled` property. If the event is not handled, downloads complete
  /// normally with the default dialog shown.
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
/// Event args for the `DownloadStarting` event.
[uuid(c7e95e2f-f789-44e6-b372-3141469240e4), object, pointer_default(unique)]
interface ICoreWebView2DownloadStartingEventArgs : IUnknown
{
  /// Returns the `ICoreWebViewDownloadOperation` for the download that
  /// has started.
  [propget] HRESULT DownloadOperation(
      [out, retval] ICoreWebView2DownloadOperation** value);

  /// The host may set this flag to cancel the download. If canceled, the
  /// download save dialog is not displayed regardless of the
  /// `Handled` property.
  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL value);

  /// The path to the file. If setting the path, the host should ensure that it
  /// is an absolute path, including the file name, and that the path does not
  /// point to an existing file. If the path points to an existing file, the
  /// file will be overwritten. If the directory does not exist, it is created.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* value);

  /// Sets the `ResultFilePath` property.
  [propput] HRESULT ResultFilePath([in] LPCWSTR value);

  /// The host may set this flag to `TRUE` to hide the default download dialog
  /// for this download. The download will progress as normal if it is not
  /// canceled, there will just be no default UI shown. By default the value is
  /// `FALSE` and the default download dialog is shown.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL value);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time. Download progress events do not occur
  /// until the deferral is completed.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

/// Implements the interface to receive `BytesReceivedChanged` event.  Use the
/// `ICoreWebView2DownloadOperation.BytesReceived` property to get the bytes
/// received count.
[uuid(D98F73CE-D94D-4576-A1E0-EB8989A9DBEF), object, pointer_default(unique)]
interface ICoreWebView2BytesReceivedChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2DownloadOperation* sender, [in] IUnknown* args);
}

/// Implements the interface to receive `EstimatedEndTimeChanged` event. Use the
/// `ICoreWebView2DownloadOperation.EstimatedEndTime` property to get the new
/// estimated end time.
[uuid(D46CD703-958B-4100-9F84-4E6C2FC32D57), object, pointer_default(unique)]
interface ICoreWebView2EstimatedEndTimeChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2DownloadOperation* sender, [in] IUnknown* args);
}

/// Implements the interface to receive `StateChanged` event. Use the
/// `ICoreWebView2DownloadOperation.State` property to get the current state,
/// which can be in progress, interrupted, or completed. Use the
/// `ICoreWebView2DownloadOperation.InterruptReason` property to get the
/// interrupt reason if the download is interrupted.
[uuid(74EEBAA9-704B-4A9A-8331-AEBD541CB62C), object, pointer_default(unique)]
interface ICoreWebView2StateChangedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2DownloadOperation* sender, [in] IUnknown* args);
}

/// Represents a download operation. Gives access to the download's metadata
/// and supports a user canceling, pausing, or resuming the download.
[uuid(0C4A07B1-B610-459F-A574-EC253D5EC40D), object, pointer_default(unique)]
interface ICoreWebView2DownloadOperation : IUnknown
{
  /// Add an event handler for the `BytesReceivedChanged` event.
  HRESULT add_BytesReceivedChanged(
    [in] ICoreWebView2BytesReceivedChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_BytesReceivedChanged`.
  HRESULT remove_BytesReceivedChanged(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `EstimatedEndTimeChanged` event.
  HRESULT add_EstimatedEndTimeChanged(
    [in] ICoreWebView2EstimatedEndTimeChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_EstimatedEndTimeChanged`.
  HRESULT remove_EstimatedEndTimeChanged(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `StateChanged` event.
  HRESULT add_StateChanged(
    [in] ICoreWebView2StateChangedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_StateChanged`.
  HRESULT remove_StateChanged(
      [in] EventRegistrationToken token);

  /// The URI of the download.
  [propget] HRESULT Uri([out, retval] LPWSTR* value);

  /// The Content-Disposition header value from the download's HTTP response.
  /// If none, the value is an empty string.
  [propget] HRESULT ContentDisposition([out, retval] LPWSTR* value);

  /// MIME type of the downloaded content.
  [propget] HRESULT MimeType([out, retval] LPWSTR* value);

  /// The expected size of the download in total number of bytes based on the
  /// HTTP Content-Length header. Returns -1 if the size is unknown.
  [propget] HRESULT TotalBytesToReceive([out, retval] INT64* value);

  /// The number of bytes that have been written to the download file.
  [propget] HRESULT BytesReceived([out, retval] INT64* value);

  /// The estimated end time in [ISO 8601 Date and Time Format](https://www.iso.org/iso-8601-date-and-time-format.html).
  [propget] HRESULT EstimatedEndTime([out, retval] LPWSTR* value);

  /// The absolute path to the download file, including file name. Host can change
  /// this from `ICoreWebView2DownloadStartingEventArgs`.
  [propget] HRESULT ResultFilePath([out, retval] LPWSTR* value);

  /// The state of the download. A download can be in progress, interrupted, or
  /// completed. See `COREWEBVIEW2_DOWNLOAD_STATE` for descriptions of states.
  [propget] HRESULT State([out, retval] COREWEBVIEW2_DOWNLOAD_STATE* value);

  /// The reason why connection with file host was broken.
  [propget] HRESULT InterruptReason(
      [out, retval] COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON* value);

  /// Cancels the download. If canceled, the default download dialog shows
  /// that the download was canceled. Host should set the `Cancel` property from
  /// `ICoreWebView2SDownloadStartingEventArgs` if the download should be
  /// canceled without displaying the default download dialog.
  HRESULT Cancel();

  /// Pauses the download. If paused, the default download dialog shows that the
  /// download is paused. No effect if download is already paused. Pausing a
  /// download changes the state to `COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED`
  /// with `InterruptReason` set to `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_USER_PAUSED`.
  HRESULT Pause();

  /// Resumes a paused download. May also resume a download that was interrupted
  /// for another reason, if `CanResume` returns true. Resuming a download changes
  /// the state from `COREWEBVIEW2_DOWNLOAD_STATE_INTERRUPTED` to
  /// `COREWEBVIEW2_DOWNLOAD_STATE_IN_PROGRESS`.
  HRESULT Resume();

  /// Returns true if an interrupted download can be resumed. Downloads with
  /// the following interrupt reasons may automatically resume without you
  /// calling any methods:
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_SERVER_NO_RANGE`,
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_HASH_MISMATCH`,
  /// `COREWEBVIEW2_DOWNLOAD_INTERRUPT_REASON_FILE_TOO_SHORT`.
  /// In these cases download progress may be restarted with `BytesReceived`
  /// reset to 0.
  [propget] HRESULT CanResume([out, retval] BOOL* value);
}
```
## .NET/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DownloadStartingEventArgs;
    runtimeclass CoreWebView2DownloadOperation;

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
        FileMalicious = 6,
        FileTransientError = 7,
        FileBlockedByPolicy = 8,
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
        ServerCertificateProblem = 22,
        ServerForbidden = 23,
        ServerUnexpectedResponse = 24,
        ServerContentLengthMismatch = 25,
        ServerCrossOriginRedirect = 26,
        UserCanceled = 27,
        UserShutdown = 28,
        UserPaused = 29,
        DownloadProcessCrashed = 30,
    };

    runtimeclass CoreWebView2DownloadStartingEventArgs
    {
        // CoreWebView2DownloadStartingEventArgs
        CoreWebView2DownloadOperation DownloadOperation { get; };

        Boolean Cancel { get; set; };

        String ResultFilePath { get; set; };

        Boolean Handled { get; set; };

        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // There are other API in this interface that we are not showing
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2DownloadStartingEventArgs> DownloadStarting;
    }

    runtimeclass CoreWebView2DownloadOperation
    {
        // CoreWebView2DownloadOperation
        String Uri { get; };

        String ContentDisposition { get; };

        String MimeType { get; };

        Int64 TotalBytesToReceive { get; };

        Int64 BytesReceived { get; };

        Windows.Foundation.DateTime EstimatedEndTime { get; };

        String ResultFilePath { get; };

        CoreWebView2DownloadState State { get; };

        CoreWebView2DownloadInterruptReason InterruptReason { get; };

        Boolean CanResume { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2DownloadOperation, Object> BytesReceivedChanged;
        event Windows.Foundation.TypedEventHandler<CoreWebView2DownloadOperation, Object> EstimatedEndTimeChanged;
        event Windows.Foundation.TypedEventHandler<CoreWebView2DownloadOperation, Object> StateChanged;

        void Cancel();

        void Pause();

        void Resume();
    }
}
```
# Appendix