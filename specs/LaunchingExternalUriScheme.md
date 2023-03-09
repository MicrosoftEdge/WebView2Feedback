# Background

We are exposing an event that will be raised when an attempt to launch a URI scheme that is registered with the OS (external URI scheme) is made.
When navigating to a URI, the URI scheme determines how to handle the URI.
Some schemes like http, and https, are resolved by the WebView2 and the navigation is handled in the WebView2.
Other URI schemes may be registered externally to the WebView2 with the OS by other applications.
Such schemes are handled by launching the external URI scheme.

The host will be given the option to cancel the external URI scheme launch with the `LaunchingExternalUriScheme` event.
Cancelling the launch gives the host the opportunity to hide the default dialog, display a custom dialog, and then launch the external URI scheme themselves.

# Description

This event will be raised before the external URI scheme launch occurs.
When an attempt to launch an external URI scheme is made and the host does not cancel the event, the default dialog is displayed in which the user can select `Open` or `Cancel`.
The `NavigationStarting` event will be raised before the `LaunchingExternalUriScheme` event, followed by the `NavigationCompleted` event. The `NavigationCompleted` event will be raised with the `IsSuccess` property set to `FALSE` and the `WebErrorStatus` property set to `ConnectionAborted` regardless of whether the host sets the `Cancel` property on the `ICoreWebView2LaunchingExternalUriSchemeEventArgs`. The `SourceChanged`, `ContentLoading`, and `HistoryChanged` events will not be raised when a request is made to launch an external URI scheme and the `WebView2.Source` property remains unchanged regardless of the `ICoreWebView2LaunchingExternalUriSchemeEventArgs`.

The `LaunchingExternalUriScheme` event will be raised on the `CoreWebView2` interface.

# Examples

## Win32 C++
    
```cpp

AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
EventRegistrationToken m_LaunchingExternalUriSchemeToken = {};

void RegisterLaunchingExternalUriSchemeHandler()
{
    auto webView16 = m_webView.try_query<ICoreWebView2_16>();
    if (webView16)
    {
        CHECK_FAILURE(webView16->add_LaunchingExternalUriScheme(
            Callback<ICoreWebView2LaunchingExternalUriSchemeEventHandler>(
                [this](
                    ICoreWebView2* sender,
                    ICoreWebView2LaunchingExternalUriSchemeEventArgs* args)
                {
                    auto showDialog = [this, args]
                    {
                        wil::unique_cotaskmem_string uri;
                        CHECK_FAILURE(args->get_Uri(&uri));
                        if (wcsicmp(uri.get(), L"calculator://") == 0)
                        {
                            // Set the event args to cancel the event and launch the
                            // calculator app. This will always allow the external URI scheme launch. 
                            args->put_Cancel(true);
                            std::wstring schemeUrl = L"calculator://";
                            SHELLEXECUTEINFO info = {sizeof(info)};
                            info.fMask = SEE_MASK_NOASYNC;
                            info.lpVerb = L"open";
                            info.lpFile = schemeUrl.c_str();
                            info.nShow = SW_SHOWNORMAL;
                            ::ShellExecuteEx(&info);
                        }
                        else if (wcsicmp(uri.get(), L"malicious://") == 0)
                        {
                            // Always block the request in this case by cancelling the event.
                            args->put_Cancel(true);
                        }
                        else if (wcsicmp(uri.get(), L"contoso://") == 0)
                        {
                            // To display a custom dialog we cancel the launch, display
                            // a custom dialog, and then manually launch the external URI scheme
                            // depending on the user's selection.
                            args->put_Cancel(true);
                            wil::unique_cotaskmem_string initiatingOrigin;
                            CHECK_FAILURE(args->get_InitiatingOrigin(&initiatingOrigin));
                            std::wstring message = L"Launching External URI Scheme request";
                            std::wstring initiatingOriginString =
                                initiatingOrigin.get();
                            if (initiatingOriginString.empty()) 
                            {
                                message += L" from ";
                                message += initiatingOriginString;
                            }
                            message += L" to ";
                            message += uri.get();
                            message += L"?\n\n";
                            message += L"Do you want to grant permission?\n";
                            int response = MessageBox(
                                nullptr, message.c_str(), L"Launching External URI Scheme",
                                MB_YESNO | MB_ICONWARNING);
                            if (response == IDYES)
                            {
                                std::wstring schemeUrl = uri.get();
                                SHELLEXECUTEINFO info = {sizeof(info)};
                                info.fMask = SEE_MASK_NOASYNC;
                                info.lpVerb = L"open";
                                info.lpFile = schemeUrl.c_str();
                                info.nShow = SW_SHOWNORMAL;
                                ::ShellExecuteEx(&info);
                            }
                        }
                        else 
                        {
                           // Do not cancel the event, allowing the request to use the default dialog.
                        }
                        return S_OK;
                    };
                    showDialog();
                    return S_OK;
                    // A deferral may be taken for the event so that the CoreWebView2
                    // doesn't examine the properties we set on the event args until
                    // after we call the Complete method asynchronously later.
                    // This will give the user more time to decide whether to launch
                    // the external URI scheme or not. 
                    // wil::com_ptr<ICoreWebView2Deferral> deferral;
                    // CHECK_FAILURE(args->GetDeferral(&deferral));

                    // m_appWindow->RunAsync(
                    //     [deferral, showDialog]()
                    //     {
                    //         showDialog();
                            // CHECK_FAILURE(deferral->Complete());
                    //     });
                    // return S_OK;
                })
                .Get(),
            &m_LaunchingExternalUriSchemeToken));
    }
}
    
```

## .NET and WinRT

```c#
private WebView2 webView;
void RegisterLaunchingExternalUriSchemeHandler() 
{
    webView.CoreWebView2.LaunchingExternalUriScheme += (sender, args) 
    {
        // A deferral may be taken for the event so that the CoreWebView2
        // doesn't examine the properties we set on the event args until
        // after we call the Complete method asynchronously later.
        // This will give the user more time to decide whether to launch
        // the external URI scheme or not. 
        // CoreWebView2Deferral deferral = args.GetDeferral();
        // System.Threading.SynchronizationContext.Current.Post((_) =>
        // {
        //     using (deferral)
        //     {
                if (String.Equals(args.Uri, "calculator:///", StringComparison.OrdinalIgnoreCase))
                {
                    // Set the event args to cancel the event and launch the
                    // calculator app. This will always allow the external URI scheme launch. 
                    args.Cancel = true;
                    ProcessStartInfo info = new ProcessStartInfo
                    {
                        FileName = args.Uri,
                        UseShellExecute = true
                    };
                    Process.Start(info);
                } 
                else if (String.Equals(args.Uri, "malicious:///", StringComparison.OrdinalIgnoreCase)) {
                    // Always block the request in this case by cancelling the event.
                    args.Cancel = true;
                }
                else if (String.Equals(args.Uri, "contoso:///", StringComparison.OrdinalIgnoreCase))
                {
                    // To display a custom dialog we cancel the launch, display
                    // a custom dialog, and then manually launch the external URI scheme
                    // depending on the user's selection. 
                    args.Cancel = true;
                    string text = "Launching External URI Scheme";
                    if (args.InitiatingOrigin != "")
                    {
                        text += "from ";
                        text += args.InitiatingOrigin;
                    }
                    text += " to ";
                    text += args.Uri;
                    text += "\n";
                    text += "Do you want to grant permission?";
                    string caption = "Launching External URI Scheme request";
                    MessageBoxButton btnMessageBox = MessageBoxButton.YesNo;
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
                            break;

                        case MessageBoxResult.No:
                            break;
                    }

                } 
                else 
                {
                    // Do not cancel the event, allowing the request to use the default dialog.
                }
        //     }
        // }, null);
    };
}

```

# API Details

## Win32 C++
    
```IDL
// This is the ICoreWebView2_16 interface.
[uuid(cc39bea3-d6d8-471b-919f-da253e2fbf03), object, pointer_default(unique)] 
interface ICoreWebView2_16 : ICoreWebView2_15 {
  /// Add an event handler for the `LaunchingExternalUriScheme` event.
  /// The `LaunchingExternalUriScheme` event is raised when a navigation request is made to
  /// a URI scheme that is registered with the OS. 
  /// The `LaunchingExternalUriScheme` event handler may suppress the default dialog
  /// or replace the default dialog with a custom dialog.
  ///
  /// If a deferral is not taken on the event args, the external URI scheme launch is 
  /// blocked until the event handler returns.  If a deferral is taken, the
  /// external URI scheme launch is blocked until the deferral is completed.
  /// The host also has the option to cancel the URI scheme launch.
  ///
  /// The `NavigationStarting` and `NavigationCompleted` events will be raised,
  /// regardless of whether the `Cancel` property is set to `TRUE` or
  /// `FALSE`. The `NavigationCompleted` event will be raised with the `IsSuccess` property 
  /// set to `FALSE` and the `WebErrorStatus` property set to `ConnectionAborted` regardless of 
  /// whether the host sets the `Cancel` property on the 
  /// `ICoreWebView2LaunchingExternalUriSchemeEventArgs`. The `SourceChanged`, `ContentLoading`, 
  /// and `HistoryChanged` events will not be raised for this navigation to the external URI
  /// scheme regardless of the `Cancel` property. 
  /// The `LaunchingExternalUriScheme` event will be raised after the 
  /// `NavigationStarting` event and before the `NavigationCompleted` event.
  /// The default `CoreWebView2Settings` will also be updated upon navigation to an external
  /// URI scheme. If a setting on the `CoreWebView2Settings` interface has been changed, 
  /// navigating to an external URI scheme will trigger the `CoreWebView2Settings` to update. 
  ///
  /// The WebView2 may not display the default dialog based on user settings, browser settings, 
  /// and whether the origin is determined as a 
  /// [trustworthy origin](https://w3c.github.io/webappsec-secure-contexts#
  /// potentially-trustworthy-origin); however, the event will still be raised. 
  ///
  /// If the request is initiated by a cross-origin frame without a user gesture, 
  /// the request will be blocked and the `LaunchingExternalUriScheme` event will not 
  /// be raised.
  /// \snippet SettingsComponent.cpp LaunchingExternalUriScheme
  HRESULT add_LaunchingExternalUriScheme(
      [in] ICoreWebView2LaunchingExternalUriSchemeEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with
  /// `add_LaunchingExternalUriScheme`.
  HRESULT remove_LaunchingExternalUriScheme(
      [in] EventRegistrationToken token);
  }

/// Event handler for the `LaunchingExternalUriScheme` event.
[uuid(e5fea648-79c9-47aa-8314-f471fe627649), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalUriSchemeEventHandler: IUnknown {
  /// Receives the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2LaunchingExternalUriSchemeEventArgs* args);
}

/// Event args for `LaunchingExternalUriScheme` event.
[uuid(fc43b557-9713-4a67-af8d-a76ef3a206e8), object, pointer_default(unique)] 
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs: IUnknown {
  /// The URI with the external URI scheme to be launched.

  [propget] HRESULT Uri([out, retval] LPWSTR* value);

  /// The origin initiating the external URI scheme launch.
  /// The origin will be an empty string if the request is initiated by calling 
  /// `CoreWebView2.Navigate` on the external URI scheme. If a script initiates 
  /// the navigation, the `InitiatingOrigin` will be the top-level document's 
  /// `Source`, i.e. if `window.location` is set to `"calculator://", the `InitiatingOrigin` 
  /// will be set to `calculator://`. If the request is initiated from a child frame, the
  /// `InitiatingOrigin` will be the source of that child frame. 

  [propget] HRESULT InitiatingOrigin([out, retval] LPWSTR* value);

  /// `TRUE` when the external URI scheme request was initiated through a user gesture.
  ///
  /// \> [!NOTE]\n\> Being initiated through a user gesture does not mean that user intended
  /// to access the associated resource.

  [propget] HRESULT IsUserInitiated([out, retval] BOOL* value);

  /// The event handler may set this property to `TRUE` to cancel the external URI scheme
  /// launch. If set to `TRUE`, the external URI scheme will not be launched, and the default
  /// dialog is not displayed. This property can be used to replace the normal 
  /// handling of launching an external URI scheme. 
  /// The initial value of the `Cancel` property is `FALSE`. 

  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Sets the `Cancel` property.

  [propput] HRESULT Cancel([in] BOOL value);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.

  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** value);
}

``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2LaunchingExternalUriSchemeEventArgs;
    
    runtimeclass CoreWebView2LaunchingExternalUriSchemeEventArgs
    {
        // CoreWebView2LaunchingExternalUriSchemeEventArgs members
        String Uri { get; };
        String InitiatingOrigin { get; };
        Boolean IsUserInitiated { get; };
        Boolean Cancel { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // CoreWebView2 
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_16")]
        {
            event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2LaunchingExternalUriSchemeEventArgs> LaunchingExternalUriScheme;
        }
    }
}
```
