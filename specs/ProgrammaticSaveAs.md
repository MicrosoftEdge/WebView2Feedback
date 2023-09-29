Programmatic Save As API
===

# Background

The context menu has the "Save as" item to manually save the html page, image,
pdf, or other content through a save as dialog. We provide more flexiable ways 
to do the save as programmatically in WebView2. You can bring up the default 
save as dialog easily. And you will be able to block default dialog, save the 
content silently, by providing the path and save as kind programmatically or 
even build your own save as UI.

In this document we describe the API. We'd appreciate your feedback.

# Description

We propose the `RequestSaveAs` method WebView2, which allows you to trigger 
the save as programmatically. By using this method, the system default dialog, 
or your own ui will popup.

We propose the `SaveAsRequested` event. You can register this event to block 
the default dialog and use the `SaveAsRequestedEventArgs` instead, to set 
your preferred save as path, save as kind, and duplicate file replacement rule. 
In your client app, you can design your own UI to input these parameters. 
For HTML documents, we support 3 save as kinds: HTML_ONLY, SINGLE_FILE and 
COMPLETE. Non-HTML documents, must use DEFAULT, which will save the content as 
it is. This API has default values for all parameters, to perform the common 
save as operation.

# Examples
## Win32 C++ 
### Add or Remove the Event Handler
This example hides the default save as dialog and shows a customized dialog.
```c++
bool ScenarioSaveAs::ToggleEventHandler()
{
    if (!m_webView2_20)
        return false;
    // m_hasSaveAsRequestedEventHandler indicates whether the event handler
    // has been subscribed.
    if (m_hasSaveAsRequestedEventHandler)
    {
        // Unregister the handler for the `SaveAsRequested` event.
        m_webView2_20->remove_SaveAsRequested(m_saveAsRequestedToken);
    }
    else
    {
        // Register a handler for the `SaveAsRequested` event.
        m_webView2_20->add_SaveAsRequested(
            Callback<ICoreWebView2SaveAsRequestedEventHandler>(
                [this](
                    ICoreWebView2* sender,
                    ICoreWebView2SaveAsRequestedEventArgs* args) -> HRESULT
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
                        SaveAsDialog dialog(m_appWindow->GetMainWindow(), saveKinds);
                        if (dialog.confirmed)
                        {
                            // Setting the ResultFilePath, Kind, AllowReplace for the event
                            // args from this customized dialog inputs is optional.
                            // The event args has default values based on the document to save.
                            CHECK_FAILURE(
                                args->put_ResultFilePath((LPCWSTR)dialog.path.c_str()));
                            CHECK_FAILURE(args->put_Kind(dialog.selectedKind));
                            CHECK_FAILURE(args->put_AllowReplace(dialog.allowReplace));
                        }
                        else
                        {
                            // Save As cancelled from this customized dialog
                            CHECK_FAILURE(args->put_Cancel(TRUE));
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
    m_hasSaveAsRequestedEventHandler = !m_hasSaveAsRequestedEventHandler;
    MessageBox(
        m_appWindow->GetMainWindow(),
        (m_hasSaveAsRequestedEventHandler ? L"Event Handler Added" : L"Event Handler Rremoved"), L"Info",
        MB_OK);
    return true;
}
```
### Programmatic Save As
Call RequestSaveAs method to trigger the programmatic save as.
```c++

bool ScenarioSaveAs::ProgrammaticSaveAs()
{
    if (!m_webView2_20)
        return false;
    m_webView2_20->RequestSaveAs(
        Callback<ICoreWebView2RequestSaveAsCompletedHandler>(
            [this](HRESULT errorCode, COREWEBVIEW2_SAVE_AS_REQUESTED_RESULTS result) -> HRESULT
            {
                // Show RequestSaveAs returned result, optional
                MessageBox(
                    m_appWindow->GetMainWindow(),
                    (L"Save As " + saveAsResultString[result]).c_str(), L"Info", MB_OK);
                return S_OK;
            })
            .Get());
    return true;
}
```

## .Net/ WinRT
### Add or Remove the Event Handler
This example hides the default save as dialog and shows a customized dialog.
```c#

void TaggleEventHandlerExecuted(object target, ExecutedRoutedEventArgs e)
{
    if (hasSaveAsRequestedEventHandler)
        webView.CoreWebView2.SaveAsRequested -= WebView_SaveAsRequested;
    else 
        webView.CoreWebView2.SaveAsRequested += WebView_SaveAsRequested;
    hasSaveAsRequestedEventHandler = !hasSaveAsRequestedEventHandler;
    MessageBox.Show(hasSaveAsRequestedEventHandler? "Event Handler Added":"Event Handler Rremoved" , "Info");
}

void WebView_SaveAsRequested(object sender, CoreWebView2SaveAsRequestedEventArgs args)
    {
    // Hide the system default save as dialog.
    args.SuppressDefaultDialog = true;

    // Developer can obtain a deferral for the event so that the CoreWebView2
    // doesn't examine the properties we set on the event args until
    // after the deferral completes asynchronously.
    CoreWebView2Deferral deferral = args.GetDeferral();

    // We avoid potential reentrancy from running a message loop in the event
    // handler. Show the customized dialog later when complete the deferral
    // asynchronously.
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        using (deferral)
        {
            // This is a customized dialog example, the constructor returns after the 
            // dialog interaction is completed by the end user.
            var dialog = new SaveAsDialog(_Kinds);
            if (dialog.ShowDialog() == true)
            {
                // Preview the content mime type, optional.
                args.ContentMimeType;
                
                // Setting parameters of event args from this dialog is optional.
                // The event args has default values.
                args.ResultFilePath = dialog.Directory.Text + "/" + dialog.Filename.Text;
                args.Kind = (CoreWebView2SaveAsRequestedKind)dialog.Kind.SelectedItem;
                args.AllowReplace = (bool)dialog.AllowReplaceOldFile.IsChecked;

            }
            else
            {
                // Save As cancelled from this customized dialog
                args.Cancel = true;
            }
        }
    }, null);
}
```
### Programmatic Save As
Call RequestSaveAsAsync method to trigger the programmatic save as.
```c#
async void ProgrammaticSaveAsExecuted(object target, ExecutedRoutedEventArgs e)
{
    CoreWebView2SaveAsRequestedResults result = await webView.CoreWebView2.RequestSaveAsAsync();
    // Show RequestSaveAsAsync returned result, optional
    MessageBox.Show(result.ToString(), "Info");
}
```

# API Details
## Win32 C++
```c++
/// Specifies save as requested kind selection options for `ICoreWebView2_20`,
/// used in `SaveAsRequestedEventArgs`
///
/// When the source is a html page, supports to select `HTML_ONLY`,
/// `SINGLE_FILE`, `COMPLETE`; when the source is a non-html,
/// only allows to select `DEFAULT`; otherwise, will deny the download
/// and return `COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_NOT_SUPPORTED`.
///
/// The content type/format is a MIME type, indicated by the source
/// server side and identified by the browser. It’s not related to the
/// file’s type or extension. MIME type of `text/html`,
/// `application/xhtml+xml` are considered as html page.
[v1_enum] typedef enum COREWEBVIEW2_SAVE_AS_REQUESTED_KIND {
  /// Default to save for a non-html content. If it is selected for a html
  /// page, it’s same as HTML_ONLY option.
  COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_DEFAULT,
  /// Save the page as html
  COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_HTML_ONLY,
  /// Save the page as mhtml
  COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_SINGLE_FILE,
  /// Save the page as html, plus, download the page related source files in
  /// a same name directory
  COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_COMPLETE,
} COREWEBVIEW2_SAVE_AS_REQUESTED_KIND;

/// Status of a programmatic save as call, indicates the result
/// for method `RequestSaveAs`
[v1_enum] typedef enum COREWEBVIEW2_SAVE_AS_REQUESTED_RESULTS {
  /// Could not perform Save As because the destination file path is an invalid path.
  ///
  /// It is considered as invalid when:
  /// the path is empty, a relativate path, the parent directory doesn't
  /// exist, or the path is a driectory.
  ///
  /// Parent directory can be itself, if the path is root directory, or
  /// root disk. When the root doesn't exist, the path is invalid.
  COREWEBVIEW2_SAVE_AS_REQUESTED_INVALID_PATH,
  /// Could not perform Save As because the destination file path already exists and 
  /// replacing files was not allowed by the `AllowReplace` property.
  COREWEBVIEW2_SAVE_AS_REQUESTED_FILE_ALREADY_EXISTS,
  /// Could not perform Save As when the `Kind` property selection not
  /// supported because of the content MIME type or system limits
  ///
  /// MIME type limits please see the emun `COREWEBVIEW2_SAVE_AS_REQUESTED_KIND`
  ///
  /// System limits might happen when select `HTML_ONLY` for an error page,
  /// select `COMPLETE` and WebView running in an App Container, etc.
  COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_NOT_SUPPORTED,
  /// Did not perform Save As because the client side decided to cancel.
  COREWEBVIEW2_SAVE_AS_REQUESTED_CANCELLED,
  /// Save as requested completeed, the downloading would start
  COREWEBVIEW2_SAVE_AS_REQUESTED_COMPLETED,
} COREWEBVIEW2_SAVE_AS_REQUESTED_RESULTS;


[uuid(15e1c6a3-c72a-4df3-91d7-d097fbec3bfd), object, pointer_default(unique)]
interface ICoreWebView2_20 : IUnknown {
  /// Programmatically trigger a save as action for current content. `SaveAsRequested` 
  /// event will be raised.
  ///
  /// Opens a system modal dialog by default. If it was already opened, this method 
  /// would not open another one. If the `SuppressDefaultDialog` is TRUE, won't open 
  /// the system dialog.
  ///
  /// The method can return a detailed info to indicate the call's result. 
  /// Please see COREWEBVIEW2_SAVE_AS_REQUESTED_RESULTS
  ///
  /// \snippet ScenarioSaveAs.cpp ProgrammaticSaveAs
  HRESULT SaveContentAs([in] ICoreWebView2RequestSaveAsCompletedHandler* handler);

  /// Add an event handler for the `SaveAsRequested` event. This event is raised
  /// when save as is triggered, programmatically or manually.
  ///
  /// \snippet ScenarioSaveAs.cpp ToggleEventHandler
  HRESULT add_SaveAsRequested(
   [in] ICoreWebView2SaveAsRequestedEventHandler* eventHanlder,
   [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_SaveAsRequested`.
  ///
  /// \snippet ScenarioSaveAs.cpp ToggleEventHandler
  HRESULT remove_SaveAsRequested(
   [in] EventRegistrationToken token);
}

/// The event handler for the `SaveAsRequested` event.
[uuid(55b86cd2-adfd-47f1-9cef-cdfb8c414ed3), object, pointer_default(unique)]
interface ICoreWebView2SaveAsRequestedEventHandler : IUnknown {
  HRESULT Invoke(
   [in] ICoreWebView2* sender,
   [in] ICoreWebView2SaveAsRequestedEventArgs* args);
}

/// The event args for `SaveAsRequested` event
[uuid(80101027-b8c3-49a1-a052-9ea4bd63ba47), object, pointer_default(unique)]
interface ICoreWebView2SaveAsRequestedEventArgs : IUnknown {
  /// Get the Mime type of content to be saved
  [propget] HRESULT ContentMimeType([out, retval] LPWSTR* value);

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
  /// location. If the select `COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_COMPLETE`, will be 
  /// an additional directory with resources files. The directory has the same name 
  /// as filename, at the same location.
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
  /// Set if allowed to replace the old file if duplicate happens in the save as
  [propput] HRESULT AllowReplace ([in] BOOL value);

  /// Get the duplicates replace rule for save as
  [propget] HRESULT AllowReplace ([out, retval] BOOL* value);

  /// How to save documents with different kind. See the enum 
  /// COREWEBVIEW2_SAVE_AS_REQUESTED_KIND for a description of the different options.  
  /// If the kind isn't allowed for the current document, 
  /// COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_NOT_SUPPORT will be returned from RequestSaveAs.
  ///
  /// The default value is COREWEBVIEW2_SAVE_AS_REQUESTED_KIND_DEFAULT
  ///
  /// Set the kind for save as
  [propput] HRESULT Kind ([in] COREWEBVIEW2_SAVE_AS_REQUESTED_KIND value);

  /// Get the kind for save as
  [propget] HRESULT Kind ([out, retval] COREWEBVIEW2_SAVE_AS_REQUESTED_KIND* value);
}

/// Receive the result for `RequestSaveAs` method
[uuid(1a02e9d9-14d3-41c6-9581-8d6e1e6f50fe), object, pointer_default(unique)]
interface ICoreWebView2RequestSaveAsCompletedHandler : IUnknown {
  HRESULT Invoke([in] HRESULT errorCode, [in] COREWEBVIEW2_REQUEST_SAVE_RESULTS result);
}
```

## .Net/ WinRT
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2SaveAsRequestedEventArgs; 
    runtimeclass CoreWebView2;

    enum CoreWebView2SaveAsRequestedResults
    {   
        InvalidPath = 0,
        FileAlreadyExists = 1,
        KindNotSupported = 2,
        Cancelled = 3,
        Completed = 4,
    };

    enum CoreWebView2SaveAsRequestedKind
    {
        Default = 0,
        HtmlOnly = 1,
        SingleFile = 2,
        Complete = 3,
    };

    runtimeclass CoreWebView2SaveAsRequestedEventArgs
    {
        String ContentMimeType { get; };
        Boolean Cancel { get; set; };
        Boolean SuppressDefaultDialog { get; set; };
        String ResultFilePath { get; set; };
        Boolean AllowReplace { get; set; };
        CoreWebView2SaveAsRequestedKind Kind { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    };

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_20")]
        {
            // ...
            event Windows.Foundation.TypedEventHandler
                <CoreWebView2, CoreWebView2SaveAsRequestedEventArgs> SaveAsRequested;
            Windows.Foundation.IAsyncOperation<CoreWebView2SaveAsRequestedResults > 
                RequestSaveAsAsync();
        }
    };
}
```