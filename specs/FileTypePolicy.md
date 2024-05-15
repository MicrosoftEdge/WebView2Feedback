File Type Policy API
===

# Background
When saving a file with the standard SaveFilePicker (window.showSaveFilePicker),
the user might receive a security alert, as the second prompt to confirm the unsafe file type.
It's because the browser applies the [file type policies](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-security-downloads-interruptions#file-types-requiring-a-gesture)
to protect end users. However, in an app that is using WebView2, when end users try
to save a file with a certain file extension, they usually can trust the
host App, domain and file extension. So, we provide the App developers the
File Type Policy API to manage the file type policies dynamically.

We'd appreciate your feedback.

# Description

We proposed the `CoreWebView2.SaveFileSecurityCheckStarting` event. As a developer, you can register a handler on
this event to get the file path, file extension and URI source information. Then you can apply your own
rules to allow save the file without a default file type policy security warning UI;
to cancel the saving; and even to create your own UI to manage runtime 
file type policies.

# Examples
## Win32 C++ 
This example will register the event with two custom rules.
- Suppressing file type policy, security dialog, and 
allows saving ".eml" files directly; when the uri is trusted.
- Showing customized warning UI when saving ".iso" files.
It allows to block the saving directly.
```c++
void ScenarioFileTypePolicy::AddCustomFileTypePolicies()
{
    wil::com_ptr<ICoreWebView2> m_webview;
    EventRegistrationToken m_saveFileSecurityCheckStartingToken = {};
    auto m_webview2_25 = m_webView.try_query<ICoreWebView2_25>();
    // Register a handler for the `SaveFileSecurityCheckStarting` event.
    m_webView2_25->add_saveFileSecurityCheckStarting(
        Callback<ICoreWebView2SaveFileSecurityCheckStartingEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2SaveFileSecurityCheckStartingEventArgs* args) -> HRESULT
            {
                // Get the file extension for file to be saved.
                wil::unique_cotaskmem_string extension;
                CHECK_FAILURE(args->get_FileExtension(&extension));
                // Get the uri of file to be saved.
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_SourceUri(&uri));
                // Convert the file extension value to lower case for
                // the case-insensitive comparison.
                std::wstring extension_lower = extension.get();
                std::transform(
                    extension_lower.begin(), extension_lower.end(),
                    extension_lower.begin(), ::towlower);
                // Set the `SuppressDefaultPolicy` property to skip the
                // default file type policy checking and a possible security
                // alert dialog for ".eml" file, when it's from a trusted uri.
                // This will consent to save the file.
                //
                // 'IsTrustedUri' should be your own helper method
                // to determine whether the uri is trusted.
                if (wcscmp(extension_lower.c_str(), L".eml") == 0 && IsTrustedUri(uri))
                {
                    CHECK_FAILURE(args->put_SuppressDefaultPolicy(TRUE));
                }
                // Show customized warning UI for ".iso" file with
                // the deferral.
                if (wcscmp(extension_lower.c_str(), L".iso") == 0)
                {
                    wil::com_ptr<ICoreWebView2Deferral> deferral;
                    CHECK_FAILURE(args->GetDeferral(&deferral));

                    // 'm_appWindow' should be your main app window.
                    m_appWindow->RunAsync(
                        [args = wil::make_com_ptr(args), deferral]()
                        {
                            // Set the `Cancel` property to cancel the saving 
                            // for ".iso" file directly. Save action will be aborted.
                            //
                            // You can let end users make decision on their save
                            // action with your customized warning UI.
                            // 'IsCancelledFromCustomizedWarningUI' should be
                            // your helper method that retrieves result from the UI.
                            if (IsCancelledFromCustomizedWarningUI())
                            {
                                CHECK_FAILURE(args->put_Cancel(TRUE));
                            }
                            CHECK_FAILURE(deferral->Complete());
                        });
                }
                return S_OK;
            })
            .Get(),
        &m_saveFileSecurityCheckStartingToken);
}
```

## .Net/ WinRT
This example will register the event with two custom rules.
- Suppressing file type policy, security dialog, and 
allows saving ".eml" files directly; when the uri is trusted.
- Showing customized warning UI when saving ".iso" files.
It allows to block the saving directly.
```c#
void AddCustomFileTypePolicies()
{
    // Register a handler for the `SaveFileSecurityCheckStarting` event.
    webView.CoreWebView2.SaveFileSecurityCheckStarting += (sender, args) =>
    {
        if (string.Equals(args.FileExtension, ".eml", StringComparison.OrdinalIgnoreCase)
            && IsTrustedUri(args.SourceUri))
        {
            // Set the `SuppressDefaultPolicy` property to skip the
            // default file type policy checking and a possible security
            // alert dialog for ".eml" file, when it's from a trusted uri.
            // This will consent to save the file.
            //
            // 'IsTrustedUri' should be your own helper method
            // to determine whether the uri is trusted.
            args.SuppressDefaultPolicy = true;
        }
        if (string.Equals(args.FileExtension, ".iso", StringComparison.OrdinalIgnoreCase))
        {
            CoreWebView2Deferral deferral = args.GetDeferral();
            System.Threading.SynchronizationContext.Current.Post((_) =>
            {
                using (deferral)
                {
                    if (IsCancelledFromCustomizedWarningUI())
                    {
                        // Set the `Cancel` property to cancel the saving 
                        // for ".iso" file directly. Save action will be aborted.
                        //
                        // You can let end users make decision on their save
                        // action with your customized warning UI.
                        // 'IsCancelledFromCustomizedWarningUI' should be
                        // your helper method that retrieves result from the UI.
                        args.Cancel = true;
                    }
                }
            }, null);
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

  /// Set whether to cancel the upcoming save/download. `TRUE` means the action 
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
  /// The file extension is the extension portion of the FilePath,
  /// preserving original case.
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
