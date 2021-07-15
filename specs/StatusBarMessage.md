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

Developers would also like to be able to opt in to intercept the text which would 
normally be displayed by the Status bar, and show it using their own custom UI. 
# Description
We propose a new event for WebView2 that would allow developers to 
listen for Status bar updates which are triggered by activity on the WebView, and then handle those updates however they want in their applications.

Developers will be able to register an event handler for changes to the status bar text.
# Examples
## Win32 C++ Registering a listener for status bar text changes
```
CHECK_FAILURE(m_webView->add_StatusBarTextChanged(
    Microsoft::WRL::Callback<ICoreWebView2StatusBarTextChangedEventHandler>(
    [this](ICoreWebView2* sender, ICoreWebView2StatusBarTextChangedEventArgs* args) -> HRESULT
    {

        Microsoft::WRL::ComPtr<ICoreWebView2_5> webview5;
        CHECK_FAILURE(sender->QueryInterface(IID_PPV_ARGS(&webview5)));
        
        wil::unique_cotaskmem_string value;
        CHECK_FAILURE(webview5->get_StatusBarText(&value));
        
        if (wcslen(value) != 0)
        {

            m_statusBar.show(value);
        } else {
            
            m_statusBar.hide();
        }

        return S_OK;
    }
).Get(),
&m_statusBarTextChangedToken));
```
## .NET / WinRT Registering a listener for status bar text changes
```
webView.CoreWebView2.StatusBarTextChanged += (CoreWebView2 sender, Object arg) =>
{
    string value = sender.StatusBarText;
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
/// Interface for the status bar text changed event handler
[uuid(85c8b75a-ceac-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2StatusBarTextChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StatusBarTextChangedEventArgs* args);
}

/// Interface for status bar text change event args
[uuid(2B9CAB1C-BE29-4FC8-BFDD-20AF170ACA7F), object, pointer_default(unique)]
interface ICoreWebView2StatusBarTextChangedEventArgs : IUnknown {

}

[uuid(b2c01782-ceaf-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2_5 : ICoreWebView2_4 {
  /// Add an event handler for the `StatusBarTextChanged` event.
  /// `StatusBarTextChanged` runs when the WebView statusbar content changes
  /// status bar
  HRESULT add_StatusBarTextChanged(
        [in] ICoreWebView2StatusBarTextChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

  /// Removing the event handler for `StatusBarTextChanged` event
  HRESULT remove_StatusBarTextChanged(
      [in] EventRegistrationToken token);

  /// used to access the current value of the status bar text
  [propget] HRESULT StatusBarText([out, retval] LPWSTR* value);
}
```
## .Net/ WinRT
```
namespace Microsoft.Web.WebView2.Core {

/// Interface for the status bar text changed event handler
    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2StatusBarTextChangedEventArgs> StatusBarTextChanged;
        string StatusBarText {get;};
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
