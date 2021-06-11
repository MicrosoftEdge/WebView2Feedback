<!-- USAGE
  * Fill in each of the sections (like Background) below
  * Wrap code with `single line of code` or ```code block```
  * Before submitting, delete all <!-- TEMPLATE marked comments in this file,
    and the following quote banner:
-->
# Background
The browser has a Status bar that displays text when hovering over a link. Currently, 
Developers are able to opt in to disable showing the status bar through the browser 
settings.

Developers would also like to be able to opt in to intercept the updates which would 
normally be displayed by the Status bar, and show it using thier own custom UI. 
# Description
We propose a new event for WebView2, StatusBarupdates that would allow developers to 
listen for Status bar updates which are triggered by user activity on the embedded 
browser, and then handle those updates however they want in their applications.

When the Status bar is triggered the developers will be able to access: 

1) An Enum which communicates the type of event being triggered {URL, STATUS_TEXT, HIDE}
2) A string value which either represents a url, plain text, or is empty (in case of hide)


# Examples
## Win32 C++ Registering a listener for status bar updates
```
CHECK_FAILURE(m_webView->add_StatusBarUpdates(
    Callback<ICoreWebView2StatusBarUpdatesEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2StatusBarUpdateEventArgs* args) -> HRESULT {

            COREWEBVIEW2_STATUS_BAR_UPDATE_TYPE type;
            std::string message;

            CHECK_FAILURE(args->get_type(&type));
            CHECK_FAILURE(args->get_message(&message));
            
            switch(type) {
                case URL: {
                    // Handle Url text in message
                    break;
                }
                case STATUS_TEXT: {
                    // Handle plain text in message
                    break;
                }
                case HIDE: {
                    // Handle dismiss event
                    break;
                }
            }
            return S_OK;
        }
    ).Get(),
&m_statusBarUpdates))
```
## C#/ .Net/ WinRT Registering a listener for status bar updates
```
webView.CoreWebView2.StatusBarUpdates += (object sender, CoreWebView2StatusBarUpdateEventArgs arg) =>
{
    CoreWebView2StatusBarUpdateType type = args.type;
    string message = args.message;

    switch(type) {
        case URL: {
            // Handle Url text in message
            break;
        }
        case STATUS_TEXT: {
            // Handle plain text in message
            break;
        }
        case HIDE: {
            // Handle dismiss event
            break;
        }
    }
};
```
# API Notes
See [API Details](#api-details) Section below for API reference


# API Details
```
[v1_enum]
typedef enum COREWEBVIEW2_STATUS_BAR_UPDATE_TYPE {
    URL,
    STATUS_TEXT,
    HIDE
} COREWEBVIEW2_STATUS_BAR_UPDATE_TYPE;

interface ICoreWebView2StatusBarUpdateEventArgs : IUnknown {
    [propget] HRESULT type([out, retval] COREWEBVIEW2_STATUS_BAR_UPDATE_TYPE* type);
    [propget] HRESULT message([out, retval] std::string* message);
}
   
interface ICoreWebView2StatusBarUpdatesEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StatusBarUpdateEventArgs* args);
}
```

```
namespace Microsoft.Web.WebView2.Core {

    enum CoreWebView2StatusBarUpdateType {
       URL,
       STATUS_TEXT,
       HIDE
    };

    runtimeclass CoreWebView2StatusBarUpdateEventArgs {
        string message {get;};
        CoreWebView2StatusBarUpdateType type {get;};
    }

    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2StatusBarUpdateEventArgs> StatusBarUpdatesEvent;
    }
}
```


# Appendix
<!-- TEMPLATE
    Anything else that you want to write down for posterity, but
    that isn't necessary to understand the purpose and usage of the API.
    For example, implementation details or links to other resources.
-->
See here for more details about the Status bar: <a href="https://www.computerhope.com/jargon/s/statusbar.htm">Here</a>