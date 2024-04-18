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

We proposed the `CoreWebView2.FileTypePolicyChecking` event. You can register
this event to get the file path, file extension and domain uri information,
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
    // Register a handler for the `FileTypePolicyChecking` event.
    m_webView2Staging25->add_FileTypePolicyChecking(
        Callback<ICoreWebView2StagingFileTypePolicyCheckingEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2StagingFileTypePolicyCheckingEventArgs* args) -> HRESULT
            {
                // Get the file extension for file to be saved.
                // And create your own rules of file type policy.
                LPWSTR extension;
                CHECK_FAILURE(args->get_FileExtension(&extension));
                if (lstrcmpW(extension, L"eml") == 0)
                    // Set the `SuppressDefaultPolicy` property to skip the
                    // default file type policy checking and a possible security
                    // alert dialog for "eml" file. This will consent to
                    // save the file.
                    CHECK_FAILURE(args->put_SuppressDefaultPolicy(TRUE));
                if (lstrcmpW(extension, L"exe") == 0)
                    // Set the `Cancel` property to cancel the saving for "exe"
                    // file directly. Save action will be aborted without any
                    // alert.
                    CHECK_FAILURE(args->put_Cancel(TRUE));
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));

                m_appWindow->RunAsync([deferral]() { CHECK_FAILURE(deferral->Complete()); });

                return S_OK;
            })
            .Get(),
        &m_fileTypePolicyCheckingToken);
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
    // Register a handler for the `FileTypePolicyChecking` event.
    webView.CoreWebView2.FileTypePolicyChecking += (sender, args) =>
    {
        // Developer can obtain a deferral for the event so that the CoreWebView2
        // doesn't examine the properties we set on the event args until
        // after the deferral completes asynchronously.
        CoreWebView2Deferral deferral = args.GetDeferral();

        // We avoid potential reentrancy from running a message loop in the event
        // handler. Complete the deferral asynchronously.
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            using (deferral)
            {
                // Get the file extension for file to be saved.
                // And create your own rules of file type policy.
                if (args.FileExtension == "eml")
                    // Set the `SuppressDefaultPolicy` property to skip the
                    // default file type policy checking and a possible security
                    // alert dialog for "eml" file. This will consent to
                    // save the file.
                    args.SuppressDefaultPolicy = true;
                if (args.FileExtension == "exe")
                    // Set the `Cancel` property to cancel the saving for "exe"
                    // file directly. Save action will be aborted without any
                    // alert.
                    args.Cancel = true;
            }
        }, null);
    };
}
```

# API Details
## Win32 C++
```c++
interface ICoreWebView2 : IUnknown {
  /// Adds an event handler for the `FileTypePolicyChecking` event.
  /// This event will be raised during system FileTypePolicy
  /// checking the dangerous file extension list.
  /// 
  /// Developers can specify their own decision on if allow this file 
  /// type extension to be saved, or downloaded. Here are two properties
  /// in `ICoreWebView2FileTypePolicyCheckingEventArgs` to manage the 
  /// decision, `Cancel` and `SuppressDefaultPolicy`.
  /// Table of Properties' value and result:
  /// 
  /// | Cancel | SuppressDefaultPolicy | Result
  /// | ------ | ------ | ---------------------  
  /// | False  | False  | Process to default policy check. It might show 
  /// |        |        | security warning UI if the file extension is 
  /// |        |        | dangerous.
  /// | ------ | ------ | --------------------- 
  /// | False  | True   | Skip the default policy check and the possible
  /// |        |        | security warning. Start saving or downloading.
  /// | ------ | ------ | --------------------- 
  /// | True   | T or F | Skip the default policy check and the possible
  /// |        |        | security warning. Abort save or download.
  HRESULT add_FileTypePolicyChecking(
      [in] ICoreWebView2StagingFileTypePolicyCheckingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_FileTypePolicyChecking`.
  HRESULT remove_FileTypePolicyChecking(
      [in] EventRegistrationToken token);
}


/// The event args for `FileTypePolicyChecking` event.
interface ICoreWebView2StagingFileTypePolicyCheckingEventArgs : IUnknown {
  /// Gets the `Cancel` property.
  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Set if cancel the upcoming save/download. `TRUE` means the action 
  /// will be cancelled before validations in default policy.
  /// 
  /// The default value is `FALSE`.
  [propput] HRESULT Cancel([in] BOOL value);

  /// Get the extension of file to be saved.
  ///
  /// File extension can be empty.
  ///
  /// Only final extension will be provided. For example, "*.tar.gz" 
  /// is a double extension, where the "gz" will be its final extension.
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

  /// Get the uri of file source.
  [propget] HRESULT Uri([out, retval] LPWSTR* value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the FileTypePolicyCheckingEvent.
  HRESULT GetDeferral(
      [out, retval] ICoreWebView2Deferral** value
  );
}

/// Receives `FileTypePolicyChecking` events.
interface ICoreWebView2StagingFileTypePolicyCheckingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StagingFileTypePolicyCheckingEventArgs* args);
}
```

## .Net/ WinRT
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2FileTypePolicyCheckingEventArgs; 
    runtimeclass CoreWebView2;

    runtimeclass CoreWebView2FileTypePolicyCheckingEventArgs
    {
        Boolean Cancel { get; set; };
        String FileExtension { get; };
        String FilePath { get; };
        Boolean SuppressDefaultPolicy { get; set; };
        String Uri { get; };
        Windows.Foundation.Deferral GetDeferral();
    };

    runtimeclass CoreWebView2
    {
        // ...
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_25")]
        {
            event Windows.Foundation.TypedEventHandler
                <CoreWebView2, CoreWebView2FileTypePolicyCheckingEventArgs> FileTypePolicyChecking;
        }
    };
}
```
