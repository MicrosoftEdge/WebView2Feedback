Programmatic Save As API
===

# Background

The context menu has the "Save as" item to manually save the html page, image, pdf, or other content through a save as dialog. We provide more flexiable ways to do the save as programmatically in WebView2. You can bring up the default save as dialog easily. And you will be able to block default dialog, save the content silently, by providing the path and save as type programmatically or even build your own save as UI.

In this document we describe the API. We'd appreciate your feedback.

# Description

We propose the `SaveContentAs` method WebView2, which allows you to trigger the save as programmatically. By using this method alone, the system default will popup.

Additionally, we propose the `SaveAsRequestedEvent`. You can register this event to block the default dialog and use the `SaveAsRequestedEventArgs` instead, to set your perferred save as path, save as type, and depulicate file replacement rule. In your clinet app, you can design your own UI to input these parameters. For html page, we support 3 save as types: HTML_ONLY, SINGLE_FILE and COMPLETE. For non-html page, the type is been set as DEFAULT, which will save the content as it is. This API also provides default values for all parameters, if you don't want to input anything.

# Examples
## Win32 C++
```c++
//! [ToggleSilent]
// Turn on/off Silent SaveAs, which won't show the system default save as dialog.
// This example hides the default save as dialog and shows a customized dialog.
bool ScenarioSaveAs::ToggleSilent()
{
    if (!m_webView2Staging20)
        return false;
    if (m_silentSaveAs)
    {
        // Unregister the handler for the `SaveAsRequested` event.
        m_webView2Staging20->remove_SaveAsRequested(m_saveAsRequestedToken);
    }
    else
    {
        // Register a handler for the `SaveAsRequested` event.
        m_webView2Staging20->add_SaveAsRequested(
            Callback<ICoreWebView2StagingSaveAsRequestedEventHandler>(
                [this](
                    ICoreWebView2* sender,
                    ICoreWebView2StagingSaveAsRequestedEventArgs* args) -> HRESULT
                {
                    // Hide the system default save as dialog.
                    CHECK_FAILURE(args->put_Handled(TRUE));

                    auto showCustomizedDialog = [this, args]
                    {
                        // Preview the content mime type, optional
                        wil::unique_cotaskmem_string mimeType;
                        CHECK_FAILURE(args->get_ContentMimeType(&mimeType));

                        SaveAsDialog dialog(m_appWindow->GetMainWindow(), contentSaveTypes);
                        if (dialog.confirmed)
                        {
                            // Set the ResultFilePath, SaveAsType, AllowReplace for the event
                            // args from this customized dialog inputs, optional. If nothing
                            // needs to input, the event args will provide default values.
                            CHECK_FAILURE(
                                args->put_ResultFilePath((LPCWSTR)dialog.path.c_str()));
                            CHECK_FAILURE(args->put_SaveAsType(dialog.selectedType));
                            CHECK_FAILURE(args->put_AllowReplace(dialog.allowReplace));

                            // Confirm to download, required
                            CHECK_FAILURE(args->put_ConfirmToSave(TRUE));
                        }
                    };

                    wil::com_ptr<ICoreWebView2Deferral> deferral;
                    CHECK_FAILURE(args->GetDeferral(&deferral));

                    m_appWindow->RunAsync(
                        [deferral, showCustomizedDialog]()
                        {
                            showCustomizedDialog();
                            CHECK_FAILURE(deferral->Complete());
                        });
                    return S_OK;
                })
                .Get(),
            &m_saveAsRequestedToken);
    }
    m_silentSaveAs = !m_silentSaveAs;
    MessageBox(
        m_appWindow->GetMainWindow(),
        (m_silentSaveAs ? L"Silent Save As Enabled" : L"Silent Save As Disabled"), L"Info",
        MB_OK);
    return true;
}
//! [ToggleSilent]

//! [ProgrammaticSaveAs]
// Call SaveContentAs method to trigger the programmatic save as.
bool ScenarioSaveAs::ProgrammaticSaveAs()
{
    if (!m_webView2Staging20)
        return false;
    m_webView2Staging20->SaveContentAs(
        Callback<ICoreWebView2StagingSaveContentAsCompletedHandler>(
            [this](HRESULT errorCode, COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS result) -> HRESULT
            {
                // Show SaveContentAs returned result, optional
                // Skip message box when the result is COREWEBVIEW2_SAVE_AS_OPEN_SYSTEM_DIALOG (0),
                // to prevent it deactivates save as modal dialog focus on the window
                if (result > 0)
                {
                    MessageBox(
                        m_appWindow->GetMainWindow(),
                        (L"Save As " + saveAsResultString[result]).c_str(), L"Info", MB_OK);
                }
                return S_OK;
            })
            .Get());
    return true;
}
//! [ProgrammaticSaveAs]
```
# API Details
## Win32 C++
```c++
/// Specifies save as type selection options for `ICoreWebView2Staging20`,
/// used in `SaveAsRequestedEventArgs`
///
/// When the source is a html page, allows to select `HTML_ONLY`,
/// `SINGLE_FILE`, `COMPLETE`; when the source is a non-html,
/// only allows to select `DEFAULT`; otherwise, will deny the download
/// and return `COREWEBVIEW2_SAVE_AS_TYPE_NOT_SUPPORTED`.
///
/// The content type/format is a MIME type, indicated by the source
/// server side and identified by the browser. It’s not related to the
/// file’s type or extension. MIME type of `text/html`,
/// `application/xhtml+xml` are considered as html page.
[v1_enum] typedef enum COREWEBVIEW2_SAVE_AS_TYPE {
  /// Default to save for a non-html content. If it is selected for a html
  /// page, it’s same as HTML_ONLY option.
  COREWEBVIEW2_SAVE_AS_TYPE_DEFAULT,
  /// Save the page as html
  COREWEBVIEW2_SAVE_AS_TYPE_HTML_ONLY,
  /// Save the page as mhtml
  COREWEBVIEW2_SAVE_AS_TYPE_SINGLE_FILE,
  /// Save the page as html, plus, download the page related source files in
  /// a folder
  COREWEBVIEW2_SAVE_AS_TYPE_COMPLETE,
} COREWEBVIEW2_SAVE_AS_TYPE;

/// Status of a programmatic save as call, indicates the result
/// for method `SaveContentAs`
[v1_enum] typedef enum COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS {
  /// Programmatically open a system default save as dialog
  COREWEBVIEW2_SAVE_AS_OPEN_SYSTEM_DIALOG,
  /// Save as downloading not start as given an invalid path
  COREWEBVIEW2_SAVE_AS_INVALID_PATH,
  /// Save as downloading not start as given a duplicate filename and
  /// replace file not allowed
  COREWEBVIEW2_SAVE_AS_FILE_ALREADY_EXISTS,
  /// Save as downloading not start as the `SAVE_AS_TYPE` selection not
  /// supported because of the content MIME type or system limits
  COREWEBVIEW2_SAVE_AS_TYPE_NOT_SUPPORTED,
  /// Cancel the save as request
  COREWEBVIEW2_SAVE_AS_CANCELLED,
  /// Save as request complete, the downloading started
  COREWEBVIEW2_SAVE_AS_STARTED
} COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS;


[uuid(15e1c6a3-c72a-4df3-91d7-d097fbec3bfd), object, pointer_default(unique)]
interface ICoreWebView2Staging20 : IUnknown {
  /// Programmatically trigger a save as action for current content.
  ///
  /// Opens a system modal dialog by default. Returns COREWEBVIEW2_SAVE_AS_OPEN_SYSTEM_DIALOG.
  /// If it was already opened, this method would not open another one
  ///
  /// If the silent save as option is enabled, won't open the system dialog, will
  /// raise the `SaveAsRequested` event instead and process through its event args. The method can return
  /// a detailed info to indicate the call's result. Please see COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS
  ///
  /// \snippet ScenarioSaveAs.cpp ProgrammaticSaveAs
  HRESULT SaveContentAs([in] ICoreWebView2StagingSaveContentAsCompletedHandler* handler);

  /// Add an event handler for the `SaveAsRequested` event. This event is raised
  /// when save as is triggered, programmatically or manually.
  ///
  /// \snippet ScenarioSaveAs.cpp ToggleSilent
  HRESULT add_SaveAsRequested(
   [in] ICoreWebView2StagingSaveAsRequestedEventHandler* eventHanlder,
   [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_SaveAsRequested`.
  ///
  /// \snippet ScenarioSaveAs.cpp ToggleSilent
  HRESULT remove_SaveAsRequested(
   [in] EventRegistrationToken token);
}

/// The event handler for the `SaveAsRequested` event, when the handler
/// exists, the silent save as enables.
[uuid(55b86cd2-adfd-47f1-9cef-cdfb8c414ed3), object, pointer_default(unique)]
interface ICoreWebView2StagingSaveAsRequestedEventHandler : IUnknown {
  HRESULT Invoke(
   [in] ICoreWebView2* sender,
   [in] ICoreWebView2StagingSaveAsRequestedEventArgs* args);
}

/// The event args for `SaveAsRequested` event
[uuid(80101027-b8c3-49a1-a052-9ea4bd63ba47), object, pointer_default(unique)]
interface ICoreWebView2StagingSaveAsRequestedEventArgs : IUnknown {
  /// Get the Mime type of content to be saved
  [propget] HRESULT ContentMimeType([out, retval] LPWSTR* value);

  /// Indicates if this event is a silent save as job. `Handled` as FALSE means
  /// save as handled by system default dialog; TRUE means a silent save as,
  /// will skip the system dialog.
  ///
  /// Set the `Handled` for save as
  [propput] HRESULT Handled ([in] BOOL handled);

  /// Get the `Handled` for save as
  [propget] HRESULT Handled ([out, retval] BOOL* handled);

  /// Indicates if a silent save as confirm to download, TRUE means confirm.
  /// when the event is invoked, the download will start. A programmatic call will
  /// return COREWEBVIEW2_SAVE_AS_STARTED as well. set it FASLE to cancel save as 
  /// and will return COREWEBVIEW2_SAVE_AS_CANCELLED.
  ///
  /// Set the `ConfrimToSave` for save as
  [propput] HRESULT ConfirmToSave ([in] BOOL confirmToSave);

  /// Get the `ConfrimToSave` for save as
  [propget] HRESULT ConfirmToSave ([out, retval] BOOL* confirmToSave);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the SaveAsRequestedEvent.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);

  /// `ResultFilePath` is absolute full path of the location. It includes the
  /// file name and extension. If `ResultFilePath` is not valid, e.g. root drive
  /// not exist, save as will be denied and return COREWEBVIEW2_SAVE_AS_INVALID_PATH.
  ///
  /// Set the `ResultFilePath` for save as
  [propput] HRESULT ResultFilePath ([in] LPCWSTR resultFilePath);

  /// Get the `ResultFilePath` for save as
  [propget] HRESULT ResultFilePath ([out, retval] LPWSTR* resultFilePath);

  /// `AllowReplace` gives the user an option to control when the file name
  /// duplicates with an existing file. TRUE allows the old file be replaced.
  /// FALSE denies when the file name duplicates, the download won’t start,
  /// will return COREWEBVIEW2_SAVE_AS_FILE_ALREADY_EXISTS.
  ///
  /// Set if allowed to replace the old file if duplicate happens in the save as job
  [propput] HRESULT AllowReplace ([in] BOOL allowReplace);

  /// Get the duplicates replace rule for save as
  [propget] HRESULT AllowReplace ([out, retval] BOOL* allowReplace);

  /// `SaveAsType` is required, see the enum COREWEBVIEW2_SAVE_AS_TYPE, if the type
  /// doesn’t match, return COREWEBVIEW2_SAVE_AS_TYPE_NOT_SUPPORT
  ///
  /// Set the content save as type for save as job
  [propput] HRESULT SaveAsType ([in] COREWEBVIEW2_SAVE_AS_TYPE type);

  /// Get the content save as type for save as job
  [propget] HRESULT SaveAsType ([out, retval] COREWEBVIEW2_SAVE_AS_TYPE* type);
}

/// Receive the result for `SaveContentAs` method
[uuid(1a02e9d9-14d3-41c6-9581-8d6e1e6f50fe), object, pointer_default(unique)]
interface ICoreWebView2StagingSaveContentAsCompletedHandler : IUnknown {
  HRESULT Invoke([in] HRESULT errorCode, [in] COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS result);
}
```
