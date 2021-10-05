
PostWebMessageAsJson/String and add_WebMessageReceived for iframes
===

# Background

We are extending WebView2 iframe interface with three api's for sending and receiving web messages which are equivalent to the next WebView2 APIs that interact with main page:
* [PostWebMessageAsJson](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.961.33#postwebmessageasjson)
* [PostWebMessageAsString](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.961.33#postwebmessageasstring)
* [add_WebMessageReceived](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.961.33#add_webmessagereceived)

# Examples
## add_WebMessageReceived and PostWebMessage
Post message from the iframe to the host app:
```javascript
function SetTitleText() {
    let titleText = document.getElementById("title-text");
    window.chrome.webview.postMessage(`SetTitleText ${titleText.value}`);
}
function GetWindowBounds() {
    window.chrome.webview.postMessage("GetWindowBounds");
}
```

Handle message in host app and post message back to iframe:
```cpp
CHECK_FAILURE(frame->add_WebMessageReceived(
Microsoft::WRL::Callback<ICoreWebView2FrameWebMessageReceivedEventHandler>(
        [this](ICoreWebView2Frame* iframeSender, ICoreWebView2WebMessageReceivedEventArgs* args)
{
    wil::unique_cotaskmem_string uri;
    CHECK_FAILURE(args->get_Source(&uri));
    // Always validate that the origin of the message is what you expect.
    if (uri.get() != m_sampleUri)
    {
        return S_OK;
    }
    wil::unique_cotaskmem_string messageRaw;
    CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
    std::wstring message = messageRaw.get();
    if (message.compare(0, 13, L"SetTitleText ") == 0)
    {
        m_appWindow->SetDocumentTitle(message.substr(13).c_str());
    }
    else if (message.compare(L"GetWindowBounds") == 0)
    {
        RECT bounds = m_appWindow->GetWindowBounds();
        std::wstring reply =
            L"{\"WindowBounds\":\"Left:" + std::to_wstring(bounds.left)
            + L"\\nTop:" + std::to_wstring(bounds.top)
            + L"\\nRight:" + std::to_wstring(bounds.right)
            + L"\\nBottom:" + std::to_wstring(bounds.bottom)
            + L"\"}";

        CHECK_FAILURE(iframeSender->PostWebMessageAsJson(reply.c_str()));
    }
    return S_OK;
}).Get(), NULL));
```

Handle posted message from the host app in the iframe:
```javascript
window.chrome.webview.addEventListener('message', arg => {
    if ("SetColor" in arg.data) {
        document.getElementById("colorable").style.color = arg.data.SetColor;
    }
    if ("WindowBounds" in arg.data) {
        document.getElementById("window-bounds").value = arg.data.WindowBounds;
    }
});
```


# API Details
## IDL
```c#
[uuid(429afcfa-7cea-453d-b8bb-11f2544bdab1), object, pointer_default(unique)]
interface ICoreWebView2Frame : IUnknown {
  /// Posts the specified webMessage to the frame.
  /// Runs the message event of the `window.chrome.webview` of the frame
  /// document. JavaScript in that document may subscribe and unsubscribe to
  /// the event using the following code.
  ///
  /// ```cpp
  /// window.chrome.webview.addEventListener('message', handler)
  /// window.chrome.webview.removeEventListener('message', handler)
  /// ```
  ///
  /// The event args is an instances of `MessageEvent`. The
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting must be `TRUE` or
  /// this method fails with `E_INVALIDARG`. The `data` property of the event
  /// args is the `webMessage` string parameter parsed as a JSON string into a
  /// JavaScript object. The `source` property of the event args is a reference
  /// to the `window.chrome.webview` object.  For information about sending
  /// messages from the iframe to the host, navigate to
  /// \[add_WebMessageReceived]. The message is sent asynchronously. If a
  /// navigation occurs before the message is posted to the iframe, the message
  /// is not sent.
  HRESULT PostWebMessageAsJson([in] LPCWSTR webMessageAsJson);

  /// Posts a message that is a simple string rather than a JSON string
  /// representation of a JavaScript object. This behaves in exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// args of the `window.chrome.webview` message is a string with the same
  /// value as `webMessageAsString`. Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects.
  HRESULT PostWebMessageAsString([in] LPCWSTR webMessageAsString);

  /// Add an event handler for the `WebMessageReceived` event.
  /// `WebMessageReceived` runs when the
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting is set and the
  /// frame document runs `window.chrome.webview.postMessage`.
  /// The `postMessage` function is `void postMessage(object)`
  /// where object is any object supported by JSON conversion.
  ///
  /// \snippet assets\ScenarioWebMessage.html chromeWebView
  ///
  /// When `postMessage` is run, the `Invoke` method of the `handler` is run
  /// with the `object` parameter of the `postMessage` converted to a JSON
  /// string.
  ///
  /// \snippet ScenarioWebMessage.cpp WebMessageReceivedIFrame
  HRESULT add_WebMessageReceived(
      [in] ICoreWebView2FrameWebMessageReceivedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_WebMessageReceived`.
  HRESULT remove_WebMessageReceived(
      [in] EventRegistrationToken token);
}

/// Receives `WebMessageReceived` events for frame.
[uuid(bfd27fe7-90ca-4f7b-8c9e-33c1d7998a3d), object, pointer_default(unique)]
interface ICoreWebView2FrameWebMessageReceivedEventHandler : IUnknown {

  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

// Existing args interface for reference
/// Event args for the `WebMessageReceived` event.
[uuid(0f99a40c-e962-4207-9e92-e3d542eff849), object, pointer_default(unique)]
interface ICoreWebView2WebMessageReceivedEventArgs : IUnknown {

  /// The URI of the document that sent this web message.
  [propget] HRESULT Source([out, retval] LPWSTR* source);

  /// The message posted from the WebView content to the host converted to a
  /// JSON string.  Run this operation to communicate using JavaScript objects.
  ///
  /// For example, the following `postMessage` runs result in the following
  /// `WebMessageAsJson` values.
  ///
  /// ```json
  /// postMessage({'a': 'b'})      L"{\"a\": \"b\"}"
  /// postMessage(1.2)             L"1.2"
  /// postMessage('example')       L"\"example\""
  /// ```
  [propget] HRESULT WebMessageAsJson([out, retval] LPWSTR* webMessageAsJson);

  /// If the message posted from the WebView content to the host is a string
  /// type, this method returns the value of that string.  If the message
  /// posted is some other kind of JavaScript type this method fails with the
  /// following error.
  ///
  /// ```text
  /// E_INVALIDARG
  /// ```
  ///
  /// Run this operation to communicate using simple strings.
  ///
  /// For example, the following `postMessage` runs result in the following
  /// `WebMessageAsString` values.
  ///
  /// ```json
  /// postMessage({'a': 'b'})      E_INVALIDARG
  /// postMessage(1.2)             E_INVALIDARG
  /// postMessage('example')       L"example"
  /// ```
  HRESULT TryGetWebMessageAsString([out, retval] LPWSTR* webMessageAsString);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    /// CoreWebView2Frame provides direct access to the iframes information and use.
    runtimeclass CoreWebView2Frame
    {
        void PostWebMessageAsJson(String webMessageAsJson);
        void PostWebMessageAsString(String webMessageAsString);

        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived;
    }

    runtimeclass CoreWebView2WebMessageReceivedEventArgs
    {
        // ICoreWebView2WebMessageReceivedEventArgs members
        String Source { get; };
        String WebMessageAsJson { get; };
        String TryGetWebMessageAsString();
    }
}
```
