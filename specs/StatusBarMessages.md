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

Developers would also like to be able to opt in to intercept the messages which would 
normally be displayed by the Status bar, and show it using thier own custom UI. 
# Description
We propose a new event for WebView2, StatusBarMessages that would allow developers to 
listen for Status bar messages which are triggered by user activity on the embedded 
browser, and then handle those messages however they want in their applications.

When the Status bar is triggered the developers will be able to access: 

1) The text data which communicates a status from the browser
2) A link which corresponds to whatever the user has their mouse over


# Examples
## Win32 C++ Registering a listener for status bar messages
```
CHECK_FAILURE(m_webView->add_StatusBarMessages(
    Callback<ICoreWebView2StatusBarMessagesEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2StatusBarMessagesEventArgs* args) -> HRESULT {

            BOOL is_url;
            std::string message;

            CHECK_FAILURE(args->get_is_url(&url));
            CHECK_FAILURE(args->get_message(&message));

            if(is_url) {
                // Handle url text in message
            } else {
                // Handle plain text in message
            }

            return S_OK;
        }
    ).Get(),
&m_statusBarMessages))
```
## C#/ .Net/ WinRT Registering a listener for status bar messages
```
webView.CoreWebView2.StatusBarMessages += (object sender, CoreWebView2StatusBarMessagesEventArgs arg) =>
{
    bool is_url = args.is_url;
    string message = args.message;

    if(is_url) {
        // Handle url text in message
    } else {
         // Handle plain text in message
    }
};
```
# API Notes
See [API Details](#api-details) Section below for API reference


# API Details
```
interface ICoreWebView2StatusBarMessagesEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StatusBarMessagesEventArgs* args);
}

interface ICoreWebView2StatusBarMessagesEventArgs : IUnknown {
    [propget] HRESULT is_url([out, retval] BOOL* is_url);
    [propget] HRESULT message([out, retval] std::string* message);
}
```

```
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2StatusBarMessagesEventArgs;

    runtimeclass CoreWebView2StatusBarMessagesEventArgs {
        string message {get;};
        bool is_url {get;};
    }

    runtimeclass CoreWebView2
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2StatusBarMessagesEventArgs> StatusBarMessagesEvent;
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