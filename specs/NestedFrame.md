CoreWebView2Frame.FrameCreated API
===

# Background
At present, WebView2 enables developers to track only first-level
iframes, which are the direct child iframes of the main frame.
However, we see that WebView2 customers want to manage nested
iframes, such as recording the navigation history for a second
level iframe. To address this, we will introduce the
`CoreWebView2Frame.FrameCreated` API. This new API will allow
developers to subscribe to the nested iframe creation event,
giving them access to all properties, methods, and events of
[CoreWebView2Frame](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2frame)
for the nested iframe.

With the new API, developers can manage iframe tracking on a page
contains multiple levels of iframes. They can choose track only the
main page and first-level iframes (the default behavior), a partial
WebView2 frames tree with specific iframes of interest, or the full
WebView2 frames tree.

# Examples
## Track partial WebView2 Frames Tree
### C++ Sample
```cpp 
wil::com_ptr<ICoreWebView2> m_webview;
std::map<UINT32, std::vector<std::wstring>> m_frame_navigation_urls;
// In this example, we present a scenario where a WebView2 application wants to
// manage the navigation of third-party content residing in second-level iframes
// (Main frame -> First-level frame -> Second-level third-party frames).
void TrackThirdPartyFrameNavigations()
{
    auto webview2_4 = m_webView.try_query<ICoreWebView2_4>();
    if (webview2_4)
    {
        webview2_4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) 
                noexcept -> HRESULT
                {
                    // [AddFrameCreated]
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));

                    // Track nested (second-level) webview frame.
                    auto frame7 = webviewFrame.try_query<ICoreWebView2Frame7>();
                    if (frame7)
                    {
                        frame7->add_FrameCreated(
                            Callback<ICoreWebView2FrameChildFrameCreatedEventHandler>(
                                [this](
                                    ICoreWebView2Frame* sender,
                                    ICoreWebView2FrameCreatedEventArgs* args) noexcept
                                -> HRESULT
                                {
                                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                                    CHECK_FAILURE(args->get_Frame(&webviewFrame));

                                    wil::com_ptr<ICoreWebView2Frame2> frame2 =
                                        webviewFrame.try_query<ICoreWebView2Frame2>();
                                    if (frame2)
                                    {
                                        // Subscribe to nested (second-level) webview frame
                                        // navigation starting event.
                                        frame2->add_NavigationStarting(
                                            Callback<
                                                ICoreWebView2FrameNavigationStartingEventHandler>(
                                                [this](
                                                    ICoreWebView2Frame* sender,
                                                    ICoreWebView2NavigationStartingEventArgs* args) 
                                                    noexcept -> HRESULT
                                                {
                                                    // Manage the navigation, e.g. cancel the
                                                    // navigation if it's on block list.

                                                    UINT32 frameId = 0;
                                                    auto frame5 =
                                                        wil::try_query<ICoreWebView2Frame5>(sender);
                                                    if (frame5)
                                                    {
                                                        CHECK_FAILURE(
                                                            frame5->get_FrameId(&frameId));
                                                    }
                                                    wil::unique_cotaskmem_string uri;
                                                    CHECK_FAILURE(args->get_Uri(&uri));

                                                    // Log the navigation history per frame Id.
                                                    m_frame_navigation_urls[frameId].push_back(uri.get());
                                                    return S_OK;
                                                })
                                                .Get(),
                                            nullptr);
                                    }
                                    return S_OK;
                                })
                                .Get(),
                            nullptr);
                    }
                    // [AddFrameCreated]
                    return S_OK;
                })
                .Get(),
            nullptr);
    }
}

```
### C# Sample
```c#
var _frameNavigationUrls = new Dictionary<UINT32, List<string>>();
// In this example, we present a scenario where a WebView2 application wants to
// manage the navigation of third-party content residing in second-level iframes
// (Main frame -> First-level frame -> second-level third-party frames).
void TrackThirdPartyFrameNavigations()
{
    webView.CoreWebView2.FrameCreated += (sender, args) =>
    {
        // Track nested (second-level) webview frame.
        args.Frame.FrameCreated += (frameCreatedSender, frameCreatedArgs) => 
        {
            CoreWebView2Frame childFrame = frameCreatedArgs.Frame;
            childFrame.NavigationStarting += OnFrameNavigationStarting;
        };
    };
}

void OnFrameNavigationStarting(object sender, 
    CoreWebView2NavigationStartingEventArgs args)
{
    // Manage the navigation, e.g. cancel the navigation 
    // if it's on block list.
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    if (!_frameNavigationUrls.ContainsKey(frame.FrameId))
    {
        _frameNavigationUrls[frame.FrameId] = new List<string>();
    }
    // Log the navigation history per frame Id. 
    _frameNavigationUrls[frame.FrameId].Add(args.Uri);
}
```

## Track entire WebView2 Frames Tree
### C++ Sample
```C++ 
wil::com_ptr<ICoreWebView2> m_webview;
std::map<UINT32, std::vector<std::wstring>> m_frame_navigation_urls;
void OnFrameCreated(wil::com_ptr<ICoreWebView2Frame> webviewFrame);
// In this example, we present a scenario where a WebView2 application
// wants to manage the navigation in all iframes.
void TrackAllFrameNavigations()
{
    auto webview2_4 = m_webview.try_query<ICoreWebView2_4>();
    if (webview2_4)
    {
        webview2_4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) 
                noexcept -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    // Track first-level webview frame.
                    OnFrameCreated(webviewFrame);
                    return S_OK;
                })
                .Get(),
            nullptr);
    }
}

void OnFrameCreated(wil::com_ptr<ICoreWebView2Frame> webviewFrame)
{
    auto frame7 = webviewFrame.try_query<ICoreWebView2Frame7>();
    if (frame7)
    {
        //! [AddFrameCreated]
        frame7->add_FrameCreated(
            Callback<ICoreWebView2FrameChildFrameCreatedEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2FrameCreatedEventArgs* args) noexcept -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    // Make a recursive call to track all nested
                    // webview frame.
                    OnFrameCreated(webviewFrame);
                    return S_OK;
                })
                .Get(),
            nullptr);
        //! [AddFrameCreated]
    }

    // Subscribe to webview frame navigation starting event.
    wil::com_ptr<ICoreWebView2Frame2> frame2 = webviewFrame.try_query<ICoreWebView2Frame2>();
    if (frame2)
    {
        frame2->add_NavigationStarting(
            Callback<ICoreWebView2FrameNavigationStartingEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2NavigationStartingEventArgs* args) noexcept -> HRESULT
                {
                    // Manage the navigation, e.g. cancel the
                    // navigation if it's on block list.

                    UINT32 frameId = 0;
                    auto frame5 = wil::try_query<ICoreWebView2Frame5>(sender);
                    if (frame5)
                    {
                        CHECK_FAILURE(frame5->get_FrameId(&frameId));
                    }
                    wil::unique_cotaskmem_string uri;
                    CHECK_FAILURE(args->get_Uri(&uri));

                    // Log the navigation history per frame Id.
                    m_frame_navigation_urls[frameId].push_back(uri.get());
                    return S_OK;
                })
                .Get(),
            nullptr);
    }
}
```

### C# Sample
```C# 
var _frameNavigationUrls = new Dictionary<UINT32, List<string>>();
// In this example, we present a scenario where a WebView2 application
// wants to manage the navigation in all iframes.
void TrackAllFrameNavigations(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.FrameCreated += OnFrameCreated;
}

void OnFrameCreated(object sender, CoreWebView2FrameCreatedEventArgs args)
{
    CoreWebView2Frame childFrame = args.Frame;
    // Make a recursive call to track all nested webview frames event.
    childFrame.FrameCreated += OnFrameCreated;
    childFrame.NavigationStarting += OnFrameNavigationStarting;
}

void OnFrameNavigationStarting(object sender, CoreWebView2NavigationStartingEventArgs args)
{
    // Manage the navigation, e.g. cancel the navigation 
    // if it's on block list.
    CoreWebView2Frame frame = (CoreWebView2Frame)sender;
    if (!_frameNavigationUrls.ContainsKey(frame.FrameId))
    {
        _frameNavigationUrls[frame.FrameId] = new List<string>();
    }
    // Log the navigation history per frame Id. 
    _frameNavigationUrls[frame.FrameId].Add(args.Uri);
}
```

# API Details
## C++
```C++
/// Receives `FrameCreated` events.
interface ICoreWebView2FrameChildFrameCreatedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2FrameCreatedEventArgs* args);
}

/// This is the ICoreWebView2Frame interface.
interface ICoreWebView2Frame7 : IUnknown {
  /// Adds an event handler for the `FrameCreated` event.
  /// Raised when a new direct descendant iframe is created.
  /// Handle this event to get access to `ICoreWebView2Frame` objects.
  /// Use `ICoreWebView2Frame::add_Destroyed` to listen for when this
  /// iframe goes away.
  /// 
  /// \snippet ScenarioWebViewEventMonitor.cpp AddFrameCreated
  HRESULT add_FrameCreated(
      [in] ICoreWebView2FrameChildFrameCreatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_FrameCreated`.
  HRESULT remove_FrameCreated(
      [in] EventRegistrationToken token);
}
```

## C#
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

# Appendix
## Impacted API
### `CoreWebView2Frame.PermissionRequested` and `CoreWebView2Frame.ScreenCaptureStarting`
In the current case of nested iframes, the [PermissionRequested](https://learn.microsoft.com/microsoft-edge/webview2/reference/winrt/microsoft_web_webview2_core/corewebview2frame#permissionrequested)
and [ScreenCaptureStarting](https://learn.microsoft.com/microsoft-edge/webview2/reference/winrt/microsoft_web_webview2_core/corewebview2frame#screencapturestarting)
events will be raised from the top-level iframe. With the support
of tracking nested iframes, we can now handle these requests directly
within the nested iframe. Specifically, these requests are raised to
the nearest tracked frame, which is the `CoreWebView2Frame` closest
to the frame that initiates the request (from bottom to top).
```
// Example:
//    A (main frame/CoreWebView2)
//    |
//    B (first-level iframe/CoreWebView2Frame)
//    |  
//    C (nested iframe)
//    |
//    D (nested iframe)
```
Suppose there's a `PermissionRequest` comes from D.
* If D is a tracked frame (`CoreWebView2Frame`), then D is the
closest tracked frame from which the request will be raised from.
* If D is not being tracked, and C is a tracked frame. Then C
is the closest tracked frame from which the request will be
raised from.
* If neither C nor D is tracked, then B is the closest tracked
frame from which the request will be raised. This case applies
to current `PermissionRequested` developers, as they haven't
subscribed to the `CoreWebView2Frame.FrameCreated` event.
Consequently, there is no change in behavior, and requests
originating from iframes will continue to be raised from the
first-level iframe.

If the `PermissionRequested` event is not handled in the current
tracked frame, the request will propagate to its parent
`CoreWebView2Frame`, or to `CoreWebView2` if the parent frame
is the main frame. For example, if frame D is tracked but does
not handle the request, the request will bubble up to frame C.
If frame C handles the request, it will not propagate further
to its parent frame B.

### `CoreWebView2.ProcessFailed`
With the support of tracking nested iframes, the processes
which support these nested iframes will be also tracked by
[ProcessFailed](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2.processfailed).
As we only track processes running tracked iframes, existing
developers will not receive any process failed events specific
to nested iframes as they haven't subscribed to the
`CoreWebView2Frame.FrameCreated` event.
