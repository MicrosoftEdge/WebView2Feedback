# Background
WebView2 raises the `NewWindowRequested` event when a new window is opened. The WebView2 team has been asked to include the name of the new window 
being created as a parameter of `NewWindowRequestedEventArgs`. This window name is the name given to the window when it is opened 
using `window.open(url, windowName)`.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending the `NewWindowRequestedEventArgs` to provide access to the `Name` property. 
The `Name` property will return the name of the new window being created. 

# Examples
## C++: Get name of window

``` cpp
wil::com_ptr<ICoreWebView2> m_webviewEventSource;
EventRegistrationToken m_newWindowRequestedToken = {};

m_webviewEventSource->add_NewWindowRequested(
    Callback<ICoreWebView2NewWindowRequestedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args)
          -> HRESULT 
            {
                wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs2> args2;
              
                if(SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args2)))) 
                {
                    wil::unique_cotaskmem_string name;
                    CHECK_FAILURE(args2->get_Name(&name));

                    wil::unique_cotaskmem_string uri;
                    CHECK_FAILURE(args->get_Uri(&uri));

                    // Example usage of how the customer would use the window name to pass
                    // additional context from their web content to their webview2 event handler.
                    if (wcscmp(name.get(), L"openInNewBrowser") == 0)
                    {
                        ShellExecute(NULL, "open", uri.get(), 
                            NULL, NULL, SW_SHOWNORMAL);
                        args->put_Handled(true);
                    }
                    else 
                    {
                        HandleNewWindow(args);
                    }
                }

              return S_OK;
            })
            .Get(),
  &m_newWindowRequestedToken);
```

## C#: Get name of window
```c#
webView.CoreWebView2.NewWindowRequested += WebView_NewWindowRequested;

void WebView_NewWindowRequested(object sender, CoreWebView2NewWindowRequestedEventArgs e)
{
    string newWindowName = e.Name;
    
    // Example usage of how the customer would use the window name to pass
    // additional context from their web content to their webview2 event handler.
    if (newWindowName == "openInNewBrowser")
    {
        Process.Start(e.Uri);
        e.Handled = true;
    }
    else
    {
        HandleNewWindow(e);
    }
}
```

# API Details
## C++
```
/// This is a continuation of the `ICoreWebView2NewWindowRequestedEventArgs` interface.
[uuid(9bcea956-6e1f-43bc-bf02-0a360d73717b), object, pointer_default(unique)]
interface ICoreWebView2NewWindowRequestedEventArgs2 : ICoreWebView2NewWindowRequestedEventArgs {
  /// Gets the name of the new window. This window can be created via `window.open(url, windowName)`,
  /// where the windowName parameter corresponds to `Name` property.
  /// If no windowName is passed to `window.open`, then the `Name` property 
  /// will be set to an empty string. Additionally, if window is opened through other means, 
  /// such as `<a target="windowName">...</a>` or `<iframe name="windowName>...</iframe>`,
  /// then the `Name` property will be set accordingly. In the case of target=_blank, 
  /// the `Name` property will be an empty string.
  /// Opening a window via ctrl+clicking a link would result in the `Name` property 
  /// being set to an empty string.
  [propget] HRESULT Name([out, retval] LPWSTR* value);
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2NewWindowRequestedEventArgs
    {
        // The following properties already exist in the CoreWebView2NewWindowRequestedEventArgs
        // ICoreWebView2NewWindowRequestedEventArgs members
        // String Uri { get; };
        // CoreWebView2 NewWindow { get; set; };
        // Boolean Handled { get; set; };
        // Boolean IsUserInitiated { get; };
        // CoreWebView2WindowFeatures WindowFeatures { get; };
       
        String Name { get; };

        // The following already exists in the CoreWebView2NewWindowRequestedEventArgs
        // Windows.Foundation.Deferral GetDeferral();
    }
}
```
