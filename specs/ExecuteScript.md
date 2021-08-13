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
## DOMContentLoaded event and ExecuteScript
DOMContentLoaded is raised when the initial HTML document has been parsed.

## .NET, WinRT
```c#
    webView.CoreWebView2.FrameCreated += (sender, args) =>
    {
        args.Frame.DOMContentLoaded += (frameSender, DOMContentLoadedArgs) =>
        {
            args.Frame.ExecuteScriptAsync(
                "let content = document.createElement(\"h2\");" +
                "content.style.color = 'blue';" +
                "content.textContent = \"The url of the iframe is \" + window.location.href.toString();" +
                "document.body.appendChild(content);");
        };
    };
```

## Win32 C++
```cpp
    CHECK_FAILURE(m_appWindow->GetWebView()->QueryInterface(IID_PPV_ARGS(&m_webView2)));
    wil::com_ptr<ICoreWebView2_4> webview2_4 = m_webView.try_query<ICoreWebView2_4>();
    if (webview2_4)
    {
        CHECK_FAILURE(webview2_4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                    -> HRESULT {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    wil::com_ptr<ICoreWebView2ExperimentalFrame> frameExperimental =
                        webviewFrame.try_query<ICoreWebView2ExperimentalFrame>();
                    if (frameExperimental)
                    {
                        frameExperimental->add_DOMContentLoaded(
                            Callback<
                                ICoreWebView2ExperimentalFrameDOMContentLoadedEventHandler>(
                                [](
                                    ICoreWebView2Frame* frame,
                                    ICoreWebView2DOMContentLoadedEventArgs* args) -> HRESULT {
                                    wil::com_ptr<ICoreWebView2ExperimentalFrame> frameExperimental;
                                    frame->QueryInterface(IID_PPV_ARGS(&frameExperimental));

                                    frameExperimental->ExecuteScript(
                                        LR"~(
                                        let content = document.createElement("h2");
                                        content.style.color = 'blue';
                                        content.textContent = "The url of the iframe is " + window.location.href.toString();
                                        document.body.appendChild(content);
                                        )~",
                                        Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                                            [](HRESULT error, PCWSTR result) -> HRESULT {
                                                return S_OK;
                                            })
                                            .Get());
                                    return S_OK;
                                })
                                .Get(),
                            NULL);
                    }
                    return S_OK;
                })
                .Get(),
            NULL));
    }
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
