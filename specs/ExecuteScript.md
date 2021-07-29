# Background
Currently WebView2 supports script execution in the main page only -
documentation can be found [here](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.902.49#executescript).
With introduction of API for [separate iframes](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2frame?view=webview2-1.0.902.49) we find it useful to support script execution in child frames also.
The time when script can be executed is tightly coupled with the navigation state of the page,
therefore we additionally providing [navigation events](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/navigation-events) in the iframes - NavigationStarting, ContentLoading, NavigationCompleted and DOMContentLoaded event.

In this document we describe API additions to support ExecuteScript and navigation
events in iframes. We'd appreciate your feedback.


# Description
Using ExecuteScript user can run script in the context of a calling frame and receive the script result in the callback if provided.
If ExecuteScript is run during the navigation it should be called after ContentLoading event.

# Examples
## ExecuteScript

## .NET, WinRT
```c#
async void InjectScriptIFrameCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    string iframesData = WebViewFrames_ToString();
    string iframesInfo = "Enter iframe to run the JavaScript code in.\r\nAvailable iframes: " + iframesData;
    var dialogIFrames = new TextInputDialog(
        title: "Inject Script Into IFrame",
        description: iframesInfo,
        defaultInput: "0");
    if (dialogIFrames.ShowDialog() == true)
    {
        int iframeNumber = -1;
        try
        {
            iframeNumber = Int32.Parse(dialogIFrames.Input.Text);
        }
        catch (FormatException)
        {
            Console.WriteLine("Can not convert " + dialogIFrames.Input.Text + " to int");
        }
        if (iframeNumber >= 0 && iframeNumber < _webViewFrames.Count)
        {
            var dialog = new TextInputDialog(
                title: "Inject Script",
                description: "Enter some JavaScript to be executed in the context of iframe " + dialogIFrames.Input.Text,
                defaultInput: "window.getComputedStyle(document.body).backgroundColor");
            if (dialog.ShowDialog() == true)
            {
                string scriptResult = await _webViewFrames[iframeNumber].ExecuteScriptAsync(dialog.Input.Text);
                MessageBox.Show(this, scriptResult, "Script Result");
            }
        }
    }
}
```

## Win32 C++
```cpp
void SampleClass::ExecuteScriptInIframe()
{
    std::wstring iframesEnterCode =
            L"Enter the JavaScript code to run in the iframe " + dialogIFrame.input;
    TextInputDialog dialogScript(
            m_appWindow->GetMainWindow(), L"Inject Script Into IFrame", L"Enter script code:",
            iframesEnterCode.c_str(),
            L"window.getComputedStyle(document.body).backgroundColor");
    if (dialogScript.confirmed)
    {
        wil::com_ptr<ICoreWebView2Frame> frame;
        CHECK_FAILURE(m_frames[index]->QueryInterface(IID_PPV_ARGS(&frame)));
        frame->ExecuteScript(
            dialogScript.input.c_str(),
            Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                [](HRESULT error, PCWSTR result) -> HRESULT {
                    if (error != S_OK)
                    {
                        ShowFailure(error, L"ExecuteScript failed");
                    }
                    MessageBox(nullptr, result, L"ExecuteScript Result", MB_OK);
                    return S_OK;
                })
                .Get());
    }
}
```

## Navigation starting

NavigationStarting is raised when the current frame is requesting permission to navigate to a different URI.

## Win32 C++
```cpp
    frame->add_NavigationStarting(
        Callback<ICoreWebView2FrameNavigationStartingEventHandler>(
            [this](ICoreWebView2Frame* sender, ICoreWebView2NavigationStartingEventArgs* args)
                -> HRESULT {
                std::wstring message = NavigationStartingArgsToJsonString(
                    m_webviewEventSource.get(), args, L"CoreWebView2Frame::NavigationStarting");
                PostEventMessage(message);

                return S_OK;
            })
            .Get(),
        NULL);
```

## Content loading

ContentLoading is raised before any content is loaded, including all scripts.

## Win32 C++
```cpp
    frame->add_ContentLoading(
        Callback<ICoreWebView2FrameContentLoadingEventHandler>(
            [this](ICoreWebView2Frame* sender, ICoreWebView2ContentLoadingEventArgs* args)
                -> HRESULT {
                std::wstring message = ContentLoadingArgsToJsonString(
                    m_webviewEventSource.get(), args, L"CoreWebView2Frame::ContentLoading");
                PostEventMessage(message);

                return S_OK;
            })
            .Get(),
        NULL);
```

## Navigation completed

NavigationCompleted is raised when the current frame has completely loaded (<c>body.onload</c> has been raised) or loading stopped with error.

## Win32 C++
```cpp
    frame->add_NavigationCompleted(
        Callback<ICoreWebView2FrameNavigationCompletedEventHandler>(
            [this](ICoreWebView2Frame* sender, ICoreWebView2NavigationCompletedEventArgs* args)
                -> HRESULT {
                std::wstring message = NavigationCompletedArgsToJsonString(
                    m_webviewEventSource.get(), args, L"CoreWebView2Frame::NavigationCompleted");
                PostEventMessage(message);

                return S_OK;
            })
            .Get(),
        NULL);
```

## DOMContentLoaded event

DOMContentLoaded is raised when the initial HTML document has been parsed.

## Win32 C++
```cpp
    frame->add_DOMContentLoaded(
        Callback<ICoreWebView2FrameDOMContentLoadedEventHandler>(
            [this](ICoreWebView2Frame* sender, ICoreWebView2DOMContentLoadedEventArgs* args)
                -> HRESULT {
                std::wstring message = DOMContentLoadedArgsToJsonString(
                    m_webviewEventSource.get(), args, L"CoreWebView2Frame::DOMContentLoaded");
                PostEventMessage(message);

                return S_OK;
            })
            .Get(),
        NULL);
```

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## IDL
```c#
/// WebView2Frame provides direct access to the iframes information and use.
[uuid(423ba05f-55dd-4c50-8339-22afd009ed31), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFrame : IUnknown {
  /// Add an event handler for the `NavigationStarting` event.
  /// A frame navigation will raise a `NavigationStarting` event and
  /// a `CoreWebView2.FrameNavigationStarting` event. All of the
  /// `FrameNavigationStarting` event handlers will be run before the
  /// `NavigationStarting` event handlers. All of the event handlers share a
  /// common `NavigationStartingEventArgs` object. Whichever event handler is
  /// last to change the `NavigationStartingEventArgs.Cancel` property will
  /// decide if the frame navigation will be cancelled. Redirects raise this
  /// event as well, and the navigation id is the same as the original one.
  ///
  /// You may block corresponding navigations until the event handler returns.
  ///
  /// \snippet ScenarioWebViewEventMonitor.cpp NavigationStarting
  HRESULT add_NavigationStarting(
      [in] ICoreWebView2FrameNavigationStartingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_NavigationStarting`.
  HRESULT remove_NavigationStarting(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `ContentLoading` event.  `ContentLoading`
  /// triggers before any content is loaded, including scripts added with
  /// `AddScriptToExecuteOnDocumentCreated`.  `ContentLoading` does not trigger
  /// if a same page navigation occurs (such as through `fragment`
  /// navigations or `history.pushState` navigations).  This operation
  /// follows the `NavigationStarting` and precedes `NavigationCompleted` events.
  HRESULT add_ContentLoading(
      [in] ICoreWebView2FrameContentLoadingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_ContentLoading`.
  HRESULT remove_ContentLoading(
      [in] EventRegistrationToken token);

  /// Add an event handler for the `NavigationCompleted` event.
  /// `NavigationCompleted` runs when the CoreWebView2Frame has completely
  /// loaded (`body.onload` runs) or loading stopped with error.
  ///
  /// \snippet ScenarioWebViewEventMonitor.cpp NavigationCompleted
  HRESULT add_NavigationCompleted(
      [in] ICoreWebView2FrameNavigationCompletedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_NavigationCompleted`.
  HRESULT remove_NavigationCompleted(
      [in] EventRegistrationToken token);

  /// Add an event handler for the DOMContentLoaded event.
  /// DOMContentLoaded is raised when the iframe html document has been parsed.
  /// This aligns with the the document's DOMContentLoaded event in html.
  ///
  /// \snippet ScenarioWebViewEventMonitor.cpp DOMContentLoaded
  HRESULT add_DOMContentLoaded(
      [in] ICoreWebView2FrameDOMContentLoadedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_DOMContentLoaded.
  HRESULT remove_DOMContentLoaded(
      [in] EventRegistrationToken token);

  /// Run JavaScript code from the javascript parameter in the current frame.
  /// The result of evaluating the provided JavaScript is used in this parameter.
  /// The result value is a JSON encoded string. If the result is undefined,
  /// contains a reference cycle, or otherwise is not able to be encoded into
  /// JSON, the JSON `null` value is returned as the `null` string.
  ///
  /// \> [!NOTE]\n\> A function that has no explicit return value returns undefined.  If the
  /// script that was run throws an unhandled exception, then the result is
  /// also `null`. This method is applied asynchronously. If the method is
  /// run before `ContentLoading`, the script will not be executed
  /// and the JSON `null` will be returned.
  /// This operation works even if `ICoreWebView2Settings::IsScriptEnabled` is
  /// set to `FALSE`.
  ///
  /// \snippet ScriptComponent.cpp ExecuteScriptFrame
  HRESULT ExecuteScript(
      [in] LPCWSTR javaScript,
      [in] ICoreWebView2ExecuteScriptCompletedHandler* handler);
}
```
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    /// CoreWebView2Frame provides direct access to the iframes information and use.
     runtimeclass CoreWebView2Frame
    {
        /// A frame navigation will raise a `NavigationStarting` event and
        /// a `CoreWebView2.FrameNavigationStarting` event. All of the
        /// `FrameNavigationStarting` event handlers will be run before the
        /// `NavigationStarting` event handlers. All of the event handlers share a
        /// common `NavigationStartingEventArgs` object. Whichever event handler is
        /// last to change the `NavigationStartingEventArgs.Cancel` property will
        /// decide if the frame navigation will be cancelled. Redirects raise this
        /// event as well, and the navigation id is the same as the original one.
        ///
        /// You may block corresponding navigations until the event handler returns.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2NavigationStartingEventArgs> NavigationStarting;

        /// `ContentLoading` triggers before any content is loaded, including scripts added with
        /// `AddScriptToExecuteOnDocumentCreated`.  `ContentLoading` does not trigger
        /// if a same page navigation occurs (such as through `fragment`
        /// navigations or `history.pushState` navigations).  This operation
        /// follows the `NavigationStarting` and precedes `NavigationCompleted` events.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2ContentLoadingEventArgs> ContentLoading;

        /// `NavigationCompleted` runs when the CoreWebView2Frame has completely
        /// loaded (`body.onload` runs) or loading stopped with error.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2NavigationCompletedEventArgs> NavigationCompleted;

        /// DOMContentLoaded is raised when the iframe html document has been parsed.
        /// This aligns with the the document's DOMContentLoaded event in html.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2DOMContentLoadedEventArgs> DOMContentLoaded;

        /// Run JavaScript code from the javascript parameter in the current frame.
        /// The result of evaluating the provided JavaScript is used in this parameter.
        /// The result value is a JSON encoded string. If the result is undefined,
        /// contains a reference cycle, or otherwise is not able to be encoded into
        /// JSON, the JSON `null` value is returned as the `null` string.
        ///
        /// \> [!NOTE]\n\> A function that has no explicit return value returns undefined.  If the
        /// script that was run throws an unhandled exception, then the result is
        /// also `null`. This method is applied asynchronously. If the method is
        /// run before `ContentLoading`, the script will not be executed
        /// and the JSON `null` will be returned.
        /// This operation works even if `Microsoft.Web.WebView2.Core.IsScriptEnabled` is
        /// set to `FALSE`.
        Windows.Foundation.IAsyncOperation<String> ExecuteScriptAsync(String javaScript);
    }
```
