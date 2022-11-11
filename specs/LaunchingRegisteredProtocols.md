# Background

We are exposing an event that will be raised when an attempt to launch a protocol that is registered with the OS (external protocol) is made. The host will be given the option to cancel the launch. Cancelling the launch gives the host the opportunity to hide the default dialog, display a custom dialog, and then launch the external protocol themselves.

# Description

This event will be raised before the external protocol launch occurs. When an attempt to launch an external protocol is made, the default dialog is displayed in which the user can select `Open` or `Cancel` if the host does not cancel the event.  The `NavigationStarting` event will be raised before the `LaunchingExternalProtocol` event, followed by the `NavigationCompleted` event. The `SourceChanged`, `ContentLoading`, and `HistoryChanged` events will not be raised when a request is made to launch an external protocol.

The `LaunchingExternalProtocol` event will be raised on the `CoreWebView2` interface.

# Examples

## Win32 C++
    
```cpp 

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
EventRegistrationToken m_launchingExternalProtocolToken = {};

void RegisterLaunchingExternalProtocolHandler()
{
    auto webView16 = m_webView.try_query<ICoreWebView2_16>();
    if (webView16)
    {
        CHECK_FAILURE(webView16->add_LaunchingExternalProtocol(
            Callback<ICoreWebView2LaunchingExternalProtocolEventHandler>(
                [this](
                    ICoreWebView2* sender,
                    ICoreWebView2LaunchingExternalProtocolEventArgs* args)
                {
                    auto showDialog = [this, args]
                    {
                        wil::unique_cotaskmem_string uri;
                        CHECK_FAILURE(args->get_Uri(&uri));
                        if (wcsicmp(uri.get(), L"calculator://") == 0)
                        {
                            // If this matches our desired protocol, then set the
                            // event args to cancel the event and launch the
                            // calculator app.
                            args->put_Cancel(true);
                            std::wstring protocol_url = L"calculator://";
                            SHELLEXECUTEINFO info = {sizeof(info)};
                            info.fMask = SEE_MASK_NOASYNC;
                            info.lpVerb = L"open";
                            info.lpFile = protocol_url.c_str();
                            info.nShow = SW_SHOWNORMAL;
                            ::ShellExecuteEx(&info);
                        }
                        else
                        {
                            // Otherwise use a deferral to display a custom dialog
                            // in which the user can choose to grant permission
                            // to launch the app and set the event args accordingly.
                            wil::unique_cotaskmem_string initiating_uri;
                            CHECK_FAILURE(args->get_InitiatingUri(&initiating_uri));
                            std::wstring message = L"Launching External Protocol request";
                            if (initiating_uri.get() == L"")
                            {
                                message += L"from ";
                                message += initiating_uri.get();
                            }
                            message += L" to ";
                            message += uri.get();
                            message += L"?\n\n";
                            message += L"Do you want to grant permission?\n";
                            int response = MessageBox(
                                nullptr, message.c_str(), L"Launching External Protocol",
                                MB_YESNOCANCEL | MB_ICONWARNING);
                            if (response == IDYES)
                            {
                                args->put_Cancel(true);
                                std::wstring protocol_url = uri.get();
                                SHELLEXECUTEINFO info = {sizeof(info)};
                                info.fMask = SEE_MASK_NOASYNC;
                                info.lpVerb = L"open";
                                info.lpFile = protocol_url.c_str();
                                info.nShow = SW_SHOWNORMAL;
                                ::ShellExecuteEx(&info);
                            }
                            else
                            {
                                args->put_Cancel(true);
                            }
                        }
                        return S_OK;
                    };
                    wil::com_ptr<ICoreWebView2Deferral> deferral;
                    CHECK_FAILURE(args->GetDeferral(&deferral));

                    m_appWindow->RunAsync(
                        [deferral, showDialog]()
                        {
                            showDialog();
                            CHECK_FAILURE(deferral->Complete());
                        });
                    return S_OK;
                })
                .Get(),
            &m_launchingExternalProtocolToken));
    }
}
    
```

## .NET and WinRT

```c#
private WebView2 webView;
void RegisterLaunchingExternalProtocolHandler() 
{
    webView.CoreWebView2.LaunchingExternalProtocol += (sender, args) {
        {
            CoreWebView2Deferral deferral = args.GetDeferral();
            System.Threading.SynchronizationContext.Current.Post((_) =>
            {
                using (deferral)
                {
                    if (String.Equals(args.Uri, "calculator:///", StringComparison.OrdinalIgnoreCase))
                    {
                        // If this matches our desired protocol, then set the
                        // event args to cancel the event and launch the
                        // calculator app.
                        ProcessStartInfo info = new ProcessStartInfo
                        {
                            FileName = args.Uri,
                            UseShellExecute = true
                        };
                        Process.Start(info);
                        args.Cancel = true;
                    } 
                    else
                    {
                        // Otherwise use a deferral to display a custom dialog
                        // in which the user can choose to grant permission
                        // to launch the app and set the event args accordingly. 
                        string text = "Launching External Protocol";
                        if (args.InitiatingUri != "")
                        {
                            text += "from ";
                            text += args.InitiatingUri;
                        }
                        text += " to ";
                        text += args.Uri;
                        text += "\n";
                        text += "Do you want to grant permission?";
                        string caption = "Launching External Protocol request";
                        MessageBoxButton btnMessageBox = MessageBoxButton.YesNoCancel;
                        MessageBoxImage icnMessageBox = MessageBoxImage.None;
                        MessageBoxResult resultbox = MessageBox.Show(text, caption, btnMessageBox, icnMessageBox);
                        switch (resultbox)
                        {
                            case MessageBoxResult.Yes:
                                ProcessStartInfo info = new ProcessStartInfo
                                {
                                    FileName = args.Uri,
                                    UseShellExecute = true
                                };
                                Process.Start(info);
                                args.Cancel = true;
                                break;

                            case MessageBoxResult.No:
                                args.Cancel = true;
                                break;

                            case MessageBoxResult.Cancel:
                                args.Cancel = true;
                                break;
                        }

                    }
                    
                }
            }, null);
        }
    };
}

```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
    
```IDL
// This is the ICoreWebView2_16 interface.
[uuid(cc39bea3-d6d8-471b-919f-da253e2fbf03), object, pointer_default(unique)] 
interface ICoreWebView2_16 : ICoreWebView2_15 {
  /// Add an event handler for the `LaunchingExternalProtocol` event.
  /// The `LaunchingExternalProtocol` event is raised when a launch request is made to
  /// a protocol that is registered with the OS. 
  /// The `LaunchingExternalProtocol` event may suppress the default dialog
  /// or replace the default dialog with a custom dialog.
  ///
  /// If a deferral is not taken on the event args, the external protocol launch is 
  /// blocked until the event handler returns.  If a deferral is taken, the
  /// external protocol launch is blocked until the deferral is completed.
  /// The host also has the option to cancel the protocol launch.
  ///
  /// The `NavigationStarting` and `NavigationCompleted` events will be raised,
  /// regardless of whether the `Cancel` property is set to `TRUE` or
  /// `FALSE`. The `SourceChanged`, `ContentLoading`, and `HistoryChanged` events 
  /// will not be raised regardless of this property. 
  /// The `LaunchingExternalProtocol` event will be raised after the 
  /// `NavigationStarting` event and before the `NavigationCompleted` event.
  /// The default settings will also be updated upon navigation to an external
  /// protocol. 
  ///
  /// If the request is made from a trustworthy origin
  /// (https://w3c.github.io/webappsec-secure-contexts#potentially-trustworthy-origin) 
  /// a checkmark box will be displayed on the default browser UI that gives the user 
  /// the option to always allow the external protocol to launch from this origin.
  /// If the user checks this box, upon the next request from that origin to the 
  /// protocol, the event will still be raised. 
  ///
  /// If the request is initiated by a cross-origin iframe without a user gesture, 
  /// the request will be blocked and the `LaunchingExternalProtocol` event will not 
  /// be raised. 
  /// If the request is initiated by a browser popup window or in another case in 
  /// which the embedded browser is null, the `LaunchingExternalProtocol` event will 
  /// not be raised and the request will continue as normal and display the default browser
  /// UI dialog to the user.
  /// \snippet SettingsComponent.cpp LaunchingExternalProtocol
  HRESULT add_LaunchingExternalProtocol(
      [in] ICoreWebView2LaunchingExternalProtocolEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with
  /// `add_LaunchingExternalProtocol`.
  HRESULT remove_LaunchingExternalProtocol(
      [in] EventRegistrationToken token);
  }

/// Receives the `LaunchingExternalProtocol` event.
[uuid(e5fea648-79c9-47aa-8314-f471fe627649), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalProtocolEventHandler: IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2LaunchingExternalProtocolEventArgs* args);
}

/// Event args for `LaunchingExternalProtocol` event.
[uuid(fc43b557-9713-4a67-af8d-a76ef3a206e8), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalProtocolEventArgs: IUnknown {
  /// The URI of the requested external protocol.

  [propget] HRESULT Uri([out, retval] LPWSTR* uri);

  /// The origin initiating the external protocol launch.
  /// The origin will be empty if the WebView2 navigates to the external protocol.

  [propget] HRESULT InitiatingOrigin([out, retval] LPWSTR* uri);

  /// `TRUE` when the external protocol request was initiated through a user gesture.
  ///
  /// \> [!NOTE]\n\> Being initiated through a user gesture does not mean that user intended
  /// to access the associated resource.

  [propget] HRESULT IsUserInitiated([out, retval] BOOL* isUserInitiated);

  /// `TRUE` when the external protocol request was initiated via a non-main frame that 
  /// has a different origin then the owning top-level page.

  [propget] HRESULT IsCrossOriginIframe([out, retval] BOOL* isCrossOriginIframe);

  /// The host may set this flag to cancel the external protocol launch.  If set to
  /// `TRUE`, the external protocol will not be launched, and the default
  /// dialog is not displayed.

  [propget] HRESULT Cancel([out, retval] BOOL* cancel);

  /// Sets the `Cancel` property. The default value is `FALSE`.

  [propput] HRESULT Cancel([in] BOOL cancel);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.

  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2LaunchingExternalProtocolEventArgs;
    
    runtimeclass CoreWebView2LaunchingExternalProtocolEventArgs
    {
        // CoreWebView2LaunchingExternalProtocolEventArgs members
        String Uri { get; };
        String InitiatingOrigin { get; };
        Boolean IsUserInitiated { get; };
        Boolean IsCrossOriginIframe { get; };
        Boolean Cancel { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // CoreWebView2 
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_16")]
        {
            event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2LaunchingExternalProtocolEventArgs> LaunchingExternalProtocol;
        }
    }
}
```
