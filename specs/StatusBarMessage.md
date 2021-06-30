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

Developers would also like to be able to opt in to intercept the messages which would 
normally be displayed by the Status bar, and show it using thier own custom UI. 
# Description
We propose a new event for WebView2 that would allow developers to 
listen for Status bar updates which are triggered by activity on the WebView, and then handle those updates however they want in their applications.

Developers will be able to register an event handler for changes to the status bar message.
# Examples
## Win32 C++ Registering a listener for status bar message changes
```
CHECK_FAILURE(m_webView->add_StatusBarMessageChanged(
    Microsoft::WRL::Callback<ICoreWebView2StatusBarMessageChangedEventHandler>(
    [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT
    {
        
        LPWSTR value;
        CHECK_FAILURE(sender->get_StatusBarMessage(&value));
        if (wcslen(value) != 0) {

            m_statusBar.show(value);
        } else {
            
            m_statusBar.hide();
        }

        return S_OK;
    }
).Get(),
&m_statusBarMessageChangedToken));
```
## .NET / WinRT Registering a listener for status bar message changes
```
webView.CoreWebView2.StatusBarMessageChanged += (CoreWebView2 sender, Object arg) =>
{
    string value = sender.statusBarMessage;
    // Handle status bar text in value
    if (value.Length != 0) {
        statusBar.show(value);
    } else {
        statusBar.hide();
    }

};
```
# API Notes
See [API Details](#api-details) Section below for API reference
# API Details
## Win32 C++
```
/// Interface for the status bar message changed event handler
[uuid(85c8b75a-ceac-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2StatusBarMessageChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] IUnknown* args);
}

[uuid(b2c01782-ceaf-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2_5 : ICoreWebView2_4 {
  /// Add an event handler for the `StatusBarMessageChanged` event.
  /// `StatusBarMessageChanged` runs when the WebView statusbar content changes
  /// status bar
  HRESULT add_StatusBarMessageChanged(
        [in] ICoreWebView2StatusBarMessageChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

  /// Removing the event handler for `StatusBarMessageChanged` event
  HRESULT remove_StatusBarMessageChanged(
      [in] EventRegistrationToken token);

  /// used to access the current value of the status bar message
  [propget] HRESULT StatusBarMessage([out, retval] LPWSTR* value);
}
```
## .Net/ WinRT
```
namespace Microsoft.Web.WebView2.Core {

/// Interface for the status bar message changed event handler
    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> StatusBarMessageChanged;
        string StatusBarMessage {get;};
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
