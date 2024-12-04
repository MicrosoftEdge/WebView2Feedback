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

To prevent unnecessary performance implication, WebView2 does
not track any nested iframes by default. It only tracks a nested
iframe if its parent iframe (`CoreWebView2Frame`) has subscribed
to the `CoreWebView2Frame.FrameCreated` API. For a page with
multi-level iframes, developers can choose to track only the
main page and first-level iframes (the default behavior), a
partial WebView2 frames tree with specific iframes of interest,
or the full WebView2 frames tree.

# Examples
### C++ Sample
```cpp
wil::com_ptr<ICoreWebView2> m_webview;
std::map<int, std::vector<std::wstring>> m_frame_navigation_urls;
// In this example, a WebView2 application wants to manage the 
// navigation of third-party content residing in second-level iframes
// (Main frame -> First-level frame -> Second-level third-party frames).
HRESULT RecordThirdPartyFrameNavigation() {
    auto webview2_4 = m_webView.try_query<ICoreWebView2_4>();
    // Track the first-level webview frame.
    webview2_4->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                    -> HRESULT {
                    // [AddFrameCreated]
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    // Track nested (second-level) webview frame.
                    auto frame7 = webviewFrame.try_query<ICoreWebView2Frame7>();
                    frame7->add_FrameCreated(
                        Callback<ICoreWebView2FrameChildFrameCreatedEventHandler>(
                            [this](
                                ICoreWebView2Frame* sender,
                                ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                            {
                                wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                                CHECK_FAILURE(args->get_Frame(&webviewFrame));
                                wil::com_ptr<ICoreWebView2Frame2> frame2 = 
                                    webviewFrame.try_query<ICoreWebView2Frame2>();
                                if (frame2)
                                {
                                    // Subscribe to nested (second-level) webview frame navigation 
                                    // starting event.
                                    frame2->add_NavigationStarting(
                                        Callback<ICoreWebView2FrameNavigationStartingEventHandler>(
                                            [this](
                                                ICoreWebView2Frame* sender,
                                                ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                                // Manage the navigation, e.g. cancel the 
                                                // navigation if it's on block list.
                                                UINT32 frameId = 0;
                                                auto frame5 = wil::com_ptr<ICoreWebView2Frame>(sender)
                                                                .try_query<ICoreWebView2Frame5>();
                                                CHECK_FAILURE(frame5->get_FrameId(&frameId));
                                                wil::unique_cotaskmem_string uri;
                                                CHECK_FAILURE(args->get_Uri(&uri));
                                                // Log the navigation history per frame Id.
                                                m_frame_navigation_urls[(int)frameId].push_back(uri.get());
                                                return S_OK;
                                            })
                                            .Get(),
                                        nullptr);
                                }
                                return S_OK;
                            })
                            .Get(),
                        nullptr);
                    // [AddFrameCreated]
                    return S_OK;
                })
                .Get(),
        nullptr);
}
```
### C# Sample
```c#
var _frameNavigationUrls = new Dictionary<UINT32, List<string>>();
// In this example, a WebView2 application wants to manage the 
// navigation of third-party content residing in second-level iframes
// (Main frame -> First-level frame -> second-level third-party frames).
void RecordThirdPartyFrameNavigation() {
    webView.CoreWebView2.FrameCreated += (sender, args) =>
    {
        // Track nested (second-level) webview frame.
        args.Frame.FrameCreated += (frameCreatedSender, frameCreatedArgs) => 
        {
            CoreWebView2Frame childFrame = frameCreatedArgs.Frame;
            childFrame.NavigationStarting += HandleChildFrameNavigationStarting;
        }
    }
}

void HandleChildFrameNavigationStarting(object sender, 
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
of tracking nested iframes, this request can be handled directly
by the nested iframe. Therefore, we now raise these requests to
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
closet tracked frame from which the request will be raised from.
* If D is not being tracked, and C is a tracked frame. Then C
is the closet tracked frame from which the request will be
raised from.
* If neither C nor D is tracked, then B is the closet tracked
frame from which the request will be raised. This case applies
to current `PermissionRequested` developers, as they haven't
subscribe to the `CoreWebView2Frame.FrameCreated` event.
Therefore, requests originating from iframes will still be
raised from the first-level iframe.

### `CoreWebView2.ProcessFailed`
With the support of tracking nested iframes, the processes
which support these nested iframes will be also tracked by
[ProcessFailed](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2.processfailed).
As we only track processes running tracked iframes, existing
developers will not receive any process failed events specific
to nested iframes as they haven't subscribe to the 
`CoreWebView2Frame.FrameCreated` event.
