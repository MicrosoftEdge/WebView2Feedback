CoreWebView2Frame.FrameCreated API
===

# Background
At present, WebView2 enables developers to track only
first-level iframes, which are the direct child frames
of the main frame. However, we're noticing WebView2
customers want to manage nested iframes, such as
recording the navigation history for a nested iframe.
To address this, we will introduce the
`CoreWebView2Frame.FrameCreated` API. This new API will allow
developers to subscribe to the event when a nested WebView frame
is created, giving them access to all properties, methods, and
events of [CoreWebView2Frame](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2frame)
for the nested WebView frame.

To prevent unnecessary performance overhead, WebView2
does not track any nested WebView frames by default.
It only tracks a webview2 frame if its parent webview2
frame has subscribed to the `CoreWebView2Frame.FrameCreated`
API. Therefore, WebView2 developers have the flexibility
to choose whether they want to track specific branches of
the frame tree or all webview2 frames.

# Examples
### C++ Sample
```cpp
EventRegistrationToken m_frameCreatedToken = {};

void PostFrameCreatedEventMessage(wil::com_ptr<ICoreWebView2Frame> webviewFrame);

void ScenarioWebViewEventMonitor::InitializeEventView(ICoreWebView2* webviewEventView)
{
    auto webviewEventView4 = webviewEventView.try_query<ICoreWebView2_4>();
    webviewEventView4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                    -> HRESULT {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    // Track first-level webview frame events.
                    InitializeFrameEventView(webviewFrame);
                    PostFrameCreatedEventMessage(webviewFrame);
                    return S_OK;
                })
                .Get(),
            &m_frameCreatedToken);
}

// Track the creation, destruction, and navigation events of webview frames.
void ScenarioWebViewEventMonitor::InitializeFrameEventView(
    wil::com_ptr<ICoreWebView2Frame> webviewFrame) {
    auto frame7 = webviewFrame.try_query<ICoreWebView2Frame7>();
    if (frame7)
    {
        //! [AddFrameCreated]
        frame7->add_FrameCreated(
            Callback<ICoreWebView2FrameNestedFrameCreatedEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    // Make a recursive call to track all nested 
                    // webview frame events.
                    InitializeFrameEventView(webviewFrame);
                    PostFrameCreatedEventMessage(webviewFrame);
                    return S_OK;
                })
                .Get(),
            &m_frameCreatedToken);
        //! [AddFrameCreated]
    }

    // Subscribe to webview frame destroyed event.
    webviewFrame->add_Destroyed(
        Callback<ICoreWebView2FrameDestroyedEventHandler>(
            [this](ICoreWebView2Frame* sender, IUnknown* args) -> HRESULT
            {
                wil::unique_cotaskmem_string name;
                CHECK_FAILURE(sender->get_Name(&name));
                std::wstring message = L"{ \"kind\": \"event\", \"name\": "
                                       L"\"CoreWebView2Frame::Destroyed\", \"args\": {";
                message += L"\"frame name\": " + EncodeQuote(name.get());
                message +=
                    L"}" + WebViewPropertiesToJsonString(m_webviewEventSource.get()) + L"}";
                PostEventMessage(message);
                return S_OK;
            })
            .Get(),
        NULL);

    // Subscribe to webview frame navigation events.
    wil::com_ptr<ICoreWebView2Frame2> frame2 = webviewFrame.try_query<ICoreWebView2Frame2>();
    if (frame2)
    {
        frame2->add_NavigationStarting(
            Callback<ICoreWebView2FrameNavigationStartingEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                    std::wstring message = NavigationStartingArgsToJsonString(
                        m_webviewEventSource.get(), args,
                        L"CoreWebView2Frame::NavigationStarting");
                    PostEventMessage(message);
                    return S_OK;
                })
                .Get(),
            NULL);

        frame2->add_ContentLoading(
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
        
        frame2->add_DOMContentLoaded(
            Callback<ICoreWebView2FrameDOMContentLoadedEventHandler>(
                [this](ICoreWebView2Frame* sender, ICoreWebView2DOMContentLoadedEventArgs* args)
                    -> HRESULT {
                    std::wstring message = DOMContentLoadedArgsToJsonString(
                        m_webviewEventSource.get(), args,
                        L"CoreWebView2Frame::DOMContentLoaded");
                    PostEventMessage(message);
                    return S_OK;
                })
                .Get(),
            NULL);

        frame2->add_NavigationCompleted(
            Callback<ICoreWebView2FrameNavigationCompletedEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                    std::wstring message = NavigationCompletedArgsToJsonString(
                        m_webviewEventSource.get(), args,
                        L"CoreWebView2Frame::NavigationCompleted");
                    PostEventMessage(message);
                    return S_OK;
                })
                .Get(),
            NULL);
    }
}

void ScenarioWebViewEventMonitor::PostFrameCreatedEventMessage(wil::com_ptr<ICoreWebView2Frame> webviewFrame) {
    wil::unique_cotaskmem_string name;
    CHECK_FAILURE(webviewFrame->get_Name(&name));
    auto frame5 = webviewFrame.try_query<ICoreWebView2Frame5>();
    if (frame5)
    {
        UINT32 frameId = 0;
        CHECK_FAILURE(frame5->get_FrameId(&frameId));
    }

    std::wstring message =
        L"{ \"kind\": \"event\", \"name\": \"FrameCreated\", \"args\": {";
    
    message += L"\"frame\": " + EncodeQuote(name.get());
    message += L",\"webview frame Id\": " + std::to_wstring((int)frameId) + L"}";
    message +=
            WebViewPropertiesToJsonString(m_webview.get());
    message += L"}";
    PostEventMessage(message);
}
```
### C# Sample
```c#
// Track first-level webview frame created event. 
void ChildFrameEventsExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.FrameCreated += HandleChildFrameCreated;
}

// Track the creation, destruction, and navigation events of webview frames.
void HandleChildFrameCreated(object sender, CoreWebView2FrameCreatedEventArgs args)
{
    CoreWebView2Frame childFrame = args.Frame;
    string name = String.IsNullOrEmpty(childFrame.Name) ? "none" : childFrame.Name;
    MessageBox.Show(this, "Id: " + childFrame.FrameId + " name: " + name, "Child frame created", MessageBoxButton.OK);
    // Make a recursive call to track all nested webview2 frames events.
    childFrame.FrameCreated += HandleChildFrameCreated;
    childFrame.NavigationStarting += HandleChildFrameNavigationStarting;
    childFrame.ContentLoading += HandleChildFrameContentLoading;
    childFrame.DOMContentLoaded += HandleChildFrameDOMContentLoaded;
    childFrame.NavigationCompleted += HandleChildFrameNavigationCompleted;
    childFrame.Destroyed += HandleChildFrameDestroyed;
}

void HandleChildFrameDestroyed(object sender, object args) {
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    MessageBox.Show(this, "Id: " + frame.FrameId + " FrameDestroyed", "Child frame Destroyed", MessageBoxButton.OK);
}

void HandleChildFrameNavigationStarting(object sender, CoreWebView2NavigationStartingEventArgs args)
{
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    MessageBox.Show(this, "Id: " + frame.FrameId + " NavigationStarting", "Child frame Navigation", MessageBoxButton.OK);
}

void HandleChildFrameContentLoading(object sender, CoreWebView2ContentLoadingEventArgs args)
{
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    MessageBox.Show(this, "Id: " + frame.FrameId + " ContentLoading", "Child frame Content Loading", MessageBoxButton.OK);
}

void HandleChildFrameDOMContentLoaded(object sender, CoreWebView2DOMContentLoadedEventArgs args)
{
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    MessageBox.Show(this, "Id: " + frame.FrameId + " DOMContentLoaded", "Child frame DOM Content Loaded", MessageBoxButton.OK);
}

void HandleChildFrameNavigationCompleted(object sender, CoreWebView2NavigationCompletedEventArgs args)
{
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    MessageBox.Show(this, "Id: " + frame.FrameId + " NavigationCompleted", "Child frame Navigation Completed", MessageBoxButton.OK);
}
```

# API Details
## C++
```
/// Receives `FrameCreated` events.
interface ICoreWebView2FrameNestedFrameCreatedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2FrameCreatedEventArgs* args);
}

/// This is the ICoreWebView2Frame interface.
interface ICoreWebView2Frame7 : IUnknown {
  /// Adds an event handler for the `FrameCreated` event.
  /// Raised when a new direct descendant iframe is created.
  /// Handle this event to get access to ICoreWebView2Frame objects.
  /// Use `ICoreWebView2Frame.add_Destroyed` to listen for when this
  /// iframe goes away.
  /// 
  /// \snippet ScenarioWebViewEventMonitor.cpp FrameCreated1
  HRESULT add_FrameCreated(
      [in] ICoreWebView2FrameNestedFrameCreatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_FrameCreated`.
  HRESULT remove_FrameCreated(
      [in] EventRegistrationToken token);
}
```

C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Frame
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame7")]
        {
            event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2FrameCreatedEventArgs> FrameCreated;
        }
    }
}
```
