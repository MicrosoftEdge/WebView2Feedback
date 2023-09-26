Programmatic Save As API
===

# Background

The context menu has the "Save as" item to manually save the html page, image,
pdf, or other content through a save as dialog. We provide more flexiable ways 
to do the save as programmatically in WebView2. You can bring up the default 
save as dialog easily. And you will be able to block default dialog, save the 
content silently, by providing the path and save as type programmatically or 
even build your own save as UI.

In this document we describe the API. We'd appreciate your feedback.

# Description

We propose the `SaveContentAs` method WebView2, which allows you to trigger 
the save as programmatically. By using this method alone, the system default 
will popup.

Additionally, we propose the `SaveAsRequested` event. You can register this 
event to block the default dialog and use the `SaveAsRequestedEventArgs` 
instead, to set your preferred save as path, save as type, and duplicate file 
replacement rule. In your client app, you can design your own UI to input 
these parameters. For HTML documents, we support 3 save as types: HTML_ONLY, 
SINGLE_FILE and COMPLETE. Non-HTML documents, must use DEFAULT, which will 
save the content as it is. This API has default values for all parameters, 
to perform the common save as operation.

# Examples
## Win32 C++ 
### Add or Remove the Event Handler
This example hides the default save as dialog and shows a customized dialog.
```c++
bool ScenarioSaveAs::ToggleEventHandler()
{
    if (!m_webView2Staging20)
        return false;
    if (m_hasSaveAsRequestedEventHandler)
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
                    CHECK_FAILURE(args->put_SuppressDefaultDialog(TRUE));
                    
                    auto showCustomizedDialog = [this, args]
                    {
                        // Preview the content mime type, optional
                        wil::unique_cotaskmem_string mimeType;
                        CHECK_FAILURE(args->get_ContentMimeType(&mimeType));

                        
                        // As an end developer, you can design your own dialog UI, or no UI at all.
                        // You can ask the user information like file name, file extenstion, and etc. 
                        // Finally, concatenate and pass them into the event args
                        //
                        // This is a customized dialog example, the constructor returns after the 
                        // dialog interaction is completed by the end user.
                        SaveAsDialog dialog(m_appWindow->GetMainWindow(), contentSaveTypes);
                        if (dialog.confirmed)
                        {
                            // Setting the ResultFilePath, SaveAsType, AllowReplace for the event
                            // args from this customized dialog inputs is optional.
                            // The event args has default values based on the document to save.
                            CHECK_FAILURE(
                                args->put_ResultFilePath((LPCWSTR)dialog.path.c_str()));
                            CHECK_FAILURE(args->put_SaveAsType(dialog.selectedType));
                            CHECK_FAILURE(args->put_AllowReplace(dialog.allowReplace));
                        }
                        else
                        {
                            // Save As cancelled from this customized dialog
                            CHECK_FAILURE(args->put_Cancel(TRUE));
                        }

                        // Indicate out parameters have been set.
                        CHECK_FAILURE(args->put_Handled(TRUE));
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
    m_hasSaveAsRequestedEventHandler = !m_hasSaveAsRequestedEventHandler;
    MessageBox(
        m_appWindow->GetMainWindow(),
        (m_hasSaveAsRequestedEventHandler ? L"Event Handler Added" : L"Event Handler Rremoved"), L"Info",
        MB_OK);
    return true;
}
```
### Programmatic Save As
Call SaveContentAs method to trigger the programmatic save as.
```c++

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
```

# API Details
## Win32 C++
```c++
/// Specifies save as type selection options for `ICoreWebView2Staging20`,
/// used in `SaveAsRequestedEventArgs`
///
/// When the source is a html page, supports to select `HTML_ONLY`,
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
  /// a same name directory
  COREWEBVIEW2_SAVE_AS_TYPE_COMPLETE,
} COREWEBVIEW2_SAVE_AS_TYPE;

/// Status of a programmatic save as call, indicates the result
/// for method `SaveContentAs`
[v1_enum] typedef enum COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS {
  /// Programmatically open a system default save as dialog
  COREWEBVIEW2_SAVE_AS_OPEN_SYSTEM_DIALOG,
  /// Could not perform Save As because the destination file path is an invalid path.
  ///
  /// It is considered as invalid when:
  /// the path is empty, a relativate path, the parent directory doesn't
  /// exist, or the path is a driectory.
  ///
  /// Parent directory can be itself, if the path is root directory, or
  /// root disk. When the root doesn't exist, the path is invalid.
  COREWEBVIEW2_SAVE_AS_INVALID_PATH,
  /// Could not perform Save As because the destination file path already exists and 
  /// replacing files was not allowed by the AllowReplace property.
  COREWEBVIEW2_SAVE_AS_FILE_ALREADY_EXISTS,
  /// Save as downloading not start as the `SAVE_AS_TYPE` selection not
  /// supported because of the content MIME type or system limits
  ///
  /// MIME type limits please see the emun `COREWEBVIEW2_SAVE_AS_TYPE`
  ///
  /// System limits might happen when select `HTML_ONLY` for an error page,
  /// select `COMPLETE` and WebView running in an App Container, etc.
  COREWEBVIEW2_SAVE_AS_TYPE_NOT_SUPPORTED,
  /// Did not perform Save As because the client side decided to cancel.
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
  /// \snippet ScenarioSaveAs.cpp ToggleEventHandler
  HRESULT add_SaveAsRequested(
   [in] ICoreWebView2StagingSaveAsRequestedEventHandler* eventHanlder,
   [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_SaveAsRequested`.
  ///
  /// \snippet ScenarioSaveAs.cpp ToggleEventHandler
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

  /// Indicates if pramameters in the event args has been set, TRUE means been set.
  ///
  /// The default value is FALSE.
  ///
  /// Set the `Handled` for save as
  [propput] HRESULT Handled ([in] BOOL value);

  /// Get the `Handled` for save as
  [propget] HRESULT Handled ([out, retval] BOOL* value);

  /// Indicates if client side cancelled the silent save as, TRUE means cancelled.
  /// When the event is invoked, the download won't start. A programmatic call will
  /// return COREWEBVIEW2_SAVE_AS_CANCELLED as well. 
  ///
  /// The default value is FALSE.
  ///
  /// Set the `Cancel` for save as
  [propput] HRESULT Cancel ([in] BOOL value);

  /// Get the `Cancel` for save as
  [propget] HRESULT Cancel ([out, retval] BOOL* value);

  /// Indicates if the system default dialog will be supressed, FALSE means
  /// save as default dialog will show; TRUE means a silent save as, will
  /// skip the system dialog. 
  ///
  /// The default value is FALSE.
  ///
  /// Set the `SupressDefaultDialog`
  [propput] HRESULT SupressDefaultDialog([in] BOOL value);

  /// Get the `SupressDefaultDialog`
  [propget] HRESULT SupressDefaultDialog([out, retval] BOOL* value);

  /// Returns an `ICoreWebView2Deferral` object. This will defer showing the 
  /// default Save As dialog and performing the Save As operation.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);

  /// `ResultFilePath` is absolute full path of the location. It includes the
  /// file name and extension. If `ResultFilePath` is not valid, e.g. root drive
  /// not exist, save as will be denied and return COREWEBVIEW2_SAVE_AS_INVALID_PATH.
  ///
  /// When the download complete and success, a target file will be saved at this
  /// location. If the SAVE_AS_TYPE is `COMPLETE`, will be an additional directory
  /// with resources files. The directory has the same name as filename, at the same
  /// location.
  ///
  /// The default value is a system suggested path, based on users' local environment.
  /// 
  /// Set the `ResultFilePath` for save as
  [propput] HRESULT ResultFilePath ([in] LPCWSTR value);

  /// Get the `ResultFilePath` for save as
  [propget] HRESULT ResultFilePath ([out, retval] LPWSTR* value);

  /// `AllowReplace` allows you to control what happens when a file already 
  /// exists in the file path to which the Save As operation is saving.
  /// Setting this TRUE allows existing files to be replaced.
  /// Settings this FALSE will not replace existing files and  will return
  /// COREWEBVIEW2_SAVE_AS_FILE_ALREADY_EXISTS.
  ///
  /// The default value is FALSE
  ///
  /// Set if allowed to replace the old file if duplicate happens in the save as job
  [propput] HRESULT AllowReplace ([in] BOOL value);

  /// Get the duplicates replace rule for save as
  [propget] HRESULT AllowReplace ([out, retval] BOOL* value);

  /// How to save documents with different types. See the enum 
  /// COREWEBVIEW2_SAVE_AS_TYPE for a description of the different options.  
  /// If the type isn't allowed for the current document, 
  /// COREWEBVIEW2_SAVE_AS_TYPE_NOT_SUPPORT will be returned from SaveContentAs.
  ///
  /// The default value is COREWEBVIEW2_SAVE_AS_TYPE_DEFAULT
  ///
  /// Set the content save as type for save as job
  [propput] HRESULT SaveAsType ([in] COREWEBVIEW2_SAVE_AS_TYPE value);

  /// Get the content save as type for save as job
  [propget] HRESULT SaveAsType ([out, retval] COREWEBVIEW2_SAVE_AS_TYPE* value);
}

/// Receive the result for `SaveContentAs` method
[uuid(1a02e9d9-14d3-41c6-9581-8d6e1e6f50fe), object, pointer_default(unique)]
interface ICoreWebView2StagingSaveContentAsCompletedHandler : IUnknown {
  HRESULT Invoke([in] HRESULT errorCode, [in] COREWEBVIEW2_SAVE_CONTENT_AS_RESULTS result);
}
```
