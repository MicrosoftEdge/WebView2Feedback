File Type Policy API
===

# Background
When saving a file with original SaveFilePicker, a security alert might be
prompted, because the browser applies the [file type policies](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-security-downloads-interruptions#file-types-requiring-a-gesture)
to protect end users. However, in a WebView2 build App, when end users try
to save a file with a certain file extension, they usually can trust the
host App, domain and file extension. So, we provide the App developers the
File Type Policy API to manage the file type policies dynamically.

We'd appreciate your feedback.

# Description

We proposed the `CoreWebView2.SaveFileSecurityCheckStarting` event. You can register
this event to get the file path, file extension and URI source information,
when end users try to save a file from your App. Then you can apply your own
rules to allow save the file with, or without a default warning dialog;
to cancel the saving; and even to create your own UI to manage runtime 
file type policies.

# Examples
## Win32 C++ 
This example shows suppressing file type policy, security dialog, and 
allow to save the file directly. It also blocks saving the exe file.
The sample code will register the event with custom rules.
```c++
bool ScenarioFileTypePolicyStaging::AddCustomFileTypePolicies()
{
    if (!m_webView2Staging25)
        return false;
    // Register a handler for the `SaveFileSecurityCheckStarting` event.
    m_webView2Staging25->add_SaveFileSecurityCheckStarting(
        Callback<ICoreWebView2StagingSaveFileSecurityCheckStartingEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2StagingSaveFileSecurityCheckStartingEventArgs* args) -> HRESULT
            {
                // Get the file extension for file to be saved.
                // And create your own rules of file type policy.
                LPWSTR extension;
                CHECK_FAILURE(args->get_FileExtension(&extension));
                if (lstrcmpW(extension, L"eml") == 0)
                {
                    // Set the `SuppressDefaultPolicy` property to skip the
                    // default file type policy checking and a possible security
                    // alert dialog for "eml" file. This will consent to
                    // save the file.
                    CHECK_FAILURE(args->put_SuppressDefaultPolicy(TRUE));
                }
                if (lstrcmpW(extension, L"exe") == 0)
                {
                    // Set the `Cancel` property to cancel the saving for "exe"
                    // file directly. Save action will be aborted without any
                    // alert.
                    CHECK_FAILURE(args->put_Cancel(TRUE));
                }
                return S_OK;
            })
            .Get(),
        &m_saveFileSecurityCheckStartingToken);
    return true;
}
```

## .Net/ WinRT
This example shows suppressing file type policy, security dialog, and 
allow to save the file directly. It also blocks saving the exe file.
The sample code will register the event with custom rules.
```c#
void AddCustomFileTypePoliciesExecuted(object target, ExecutedRoutedEventArgs e)
{
    // Register a handler for the `SaveFileSecurityCheckStarting` event.
    webView.CoreWebView2.SaveFileSecurityCheckStarting += (sender, args) =>
    {
        // Get the file extension for file to be saved.
        // And create your own rules of file type policy.
        if (args.FileExtension == "eml")
        {
            // Set the `SuppressDefaultPolicy` property to skip the
            // default file type policy checking and a possible security
            // alert dialog for "eml" file. This will consent to
            // save the file.
            args.SuppressDefaultPolicy = true;
        }
        if (args.FileExtension == "exe")
        {
            // Set the `Cancel` property to cancel the saving for "exe"
            // file directly. Save action will be aborted without any
            // alert.
            args.Cancel = true;
        }
    };
}
```

# API Details
## Win32 C++
```c++
interface ICoreWebView2 : IUnknown {
  /// Adds an event handler for the `SaveFileSecurityCheckStarting` event.
  /// If the default save file picker is used to save a file, for
  /// example, client using the File System API `showSaveFilePicker`;
  /// this event will be raised during system FileTypePolicy
  /// checking the dangerous file extension list.
  /// 
  /// Developers can specify their own decision on if allow this file 
  /// type extension to be saved, or downloaded. Here are two properties
  /// in `ICoreWebView2SaveFileSecurityCheckStartingEventArgs` to manage the 
  /// decision, `Cancel` and `SuppressDefaultPolicy`.
  /// Table of Properties' value and result:
  /// 
  /// | Cancel | SuppressDefaultPolicy | Result
  /// | ------ | ------ | ---------------------  
  /// | False  | False  | Perform the default policy check. It may show the
  /// |        |        | security warning UI if the file extension is 
  /// |        |        | dangerous.
  /// | ------ | ------ | --------------------- 
  /// | False  | True   | Skip the default policy check and the possible
  /// |        |        | security warning. Start saving or downloading.
  /// | ------ | ------ | --------------------- 
  /// | True   | Any    | Skip the default policy check and the possible
  /// |        |        | security warning. Abort save or download.
  HRESULT add_SaveFileSecurityCheckStarting(
      [in] ICoreWebView2StagingSaveFileSecurityCheckStartingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_SaveFileSecurityCheckStarting`.
  HRESULT remove_SaveFileSecurityCheckStarting(
      [in] EventRegistrationToken token);
}


/// The event args for `SaveFileSecurityCheckStarting` event.
interface ICoreWebView2StagingSaveFileSecurityCheckStartingEventArgs : IUnknown {
  /// Gets the `Cancel` property.
  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Set if cancel the upcoming save/download. `TRUE` means the action 
  /// will be cancelled before validations in default policy.
  /// 
  /// The default value is `FALSE`.
  [propput] HRESULT Cancel([in] BOOL value);

  /// Get the extension of file to be saved.
  ///
  /// File extension can be empty, if the file name has no extension
  /// at all.
  ///
  /// Only final extension without "." will be provided. For example,
  /// "*.tar.gz" is a double extension, where the "gz" will be its
  /// final extension.
  ///
  /// File extension usage in the API is case sensitive.
  [propget] HRESULT FileExtension([out, retval] LPWSTR* value);

  /// Get the full path of file to be saved. This includes the
  /// file name and extension.
  [propget] HRESULT FilePath([out, retval] LPWSTR* value);

  /// Gets the `SuppressDefaultPolicy` property.
  [propget] HRESULT SuppressDefaultPolicy([out, retval] BOOL* value);

  /// Set if the default policy checking and security warning will be
  /// suppressed. `TRUE` means it will be suppressed. 
  /// 
  /// The default value is `FALSE`.
  [propput] HRESULT SuppressDefaultPolicy([in] BOOL value);

  /// The URI source of this file save operation.
  [propget] HRESULT SourceUri([out, retval] LPWSTR* value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the SaveFileSecurityCheckStartingEvent.
  ///
  /// The default policy checking and any default UI will be blocked temporarily,
  /// saving file to local won't start, until the deferral is completed.
  HRESULT GetDeferral(
      [out, retval] ICoreWebView2Deferral** value
  );
}

/// Receives `SaveFileSecurityCheckStarting` events.
interface ICoreWebView2StagingSaveFileSecurityCheckStartingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StagingSaveFileSecurityCheckStartingEventArgs* args);
}
```

## .Net/ WinRT
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2SaveFileSecurityCheckStartingEventArgs; 
    runtimeclass CoreWebView2;

    runtimeclass CoreWebView2SaveFileSecurityCheckStartingEventArgs
    {
        Boolean Cancel { get; set; };
        String FileExtension { get; };
        String FilePath { get; };
        Boolean SuppressDefaultPolicy { get; set; };
        String SourceUri { get; };
        Windows.Foundation.Deferral GetDeferral();
    };

    runtimeclass CoreWebView2
    {
        // ...
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_25")]
        {
            event Windows.Foundation.TypedEventHandler
                <CoreWebView2, CoreWebView2SaveFileSecurityCheckStartingEventArgs> SaveFileSecurityCheckStarting;
        }
    };
}
```
