<!-- USAGE
  * Fill in each of the sections (like Background) below
  * Wrap code with `single line of code` or ```code block```
  * Before submitting, delete all <!-- TEMPLATE marked comments in this file,
    and the following quote banner:
-->
# Background
The browser has a Status bar that displays text when hovering over a link, or performing some activity. Currently, 
developers are able to opt in to disable showing the status bar through the browser 
settings.

Developers would also like to be able to opt in to intercept the updates which would 
normally be displayed by the Status bar, and show it using thier own custom UI. 
# Description
We propose two new events for WebView2 that would allow developers to 
listen for Status bar updates which are triggered by activity on the embedded 
browser, and then handle those updates however they want in their applications.

Developers will be able to: 

1) Register an even handler for knowing when to show the status bar and what text to show
2) Register an handler for knowing when the browser wants to dismiss the status bar


# Examples
## Win32 C++ Registering a listener for status bar showing
```
CHECK_FAILURE(m_webView->add_StatusBarShowing(
    Callback<ICoreWebView2StatusBarShowingEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2StatusBarShowingEventArgs* args) -> HRESULT {
            std::string message;
            CHECK_FAILURE(args->get_message(&message));
            
            // Handle status bar text in message

            return S_OK;
        }
    ).Get(),
&m_statusBarShowing));
```
## Win32 C++ Registering a listener for status bar hiding
```
CHECK_FAILURE(m_webView->add_StatusBarHiding(
    Callback<ICoreWebView2StatusBarHidingEventHandler>(
        [this](ICoreWebView2* sender) -> HRESULT {
            
            // Dismiss status bar

            return S_OK;
        }
    ).Get(),
&m_statusBarHiding));
```
## C#/ .Net/ WinRT Registering a listener for status bar showing
```
webView.CoreWebView2.StatusBarShowing += (object sender, CoreWebView2StatusBarShowingEventArgs arg) =>
{
    string message = args.message;
    // Handle status bar text in message
};
```
## C#/ .Net/ WinRT Registering a listener for status bar hiding
```
webView.CoreWebView2.StatusBarHiding += (object sender) =>
{
     // Dismiss status bar
};
```
# API Notes
See [API Details](#api-details) Section below for API reference
# API Details
## Win32 C++
```
interface ICoreWebView2StatusBarShowingEventArgs : IUnknown {
    [propget] HRESULT message([out, retval] std::string* message);
}   
   
interface ICoreWebView2StatusBarShowingEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StatusBarShowingEventArgs* args);
}

interface ICoreWebView2StatusBarHidingEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender);
}
```
## C#/ .Net/ WinRT
```
namespace Microsoft.Web.WebView2.Core {
    runtimeclass CoreWebView2StatusBarShowingEventArgs {
        string message {get;};
    }

    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2StatusBarShowingEventArgs> StatusBarShowingEvent;
    }

    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2> StatusBarHidingEvent;
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
