# Background

WebView2 raises the `LaunchingExternalUriScheme` event on `CoreWebView2`
when web content attempts to launch a URI scheme registered with the OS as
an external scheme handler (for example, `mailto:`, `tel:`, or a custom
protocol). The host can handle this event to suppress the default WebView2
dialog, present its own consent UI, and set `Cancel` to control whether the
URI is launched.

The event currently exposes `Uri`, `InitiatingOrigin`, `IsUserInitiated`,
and `Cancel`. It does not identify the originating iframe. Hosts that embed
multiple sub-applications as iframes within a single WebView2 — often served
from a shared origin — cannot reliably attribute a launch to the iframe that
triggered it, because:

1. Multiple iframes can be served from the same origin, and the event
   exposes no identifier beyond the origin.
2. The same iframe content may be presented in more than one host surface
   (window or panel), and the host cannot route the consent prompt to the
   correct surface.
3. Sandboxed and `srcdoc` iframes have opaque origins. The API reports the
   parent origin, making the initiating iframe indistinguishable.

To enable iframe-level attribution, the `LaunchingExternalUriScheme` event
is also raised on `CoreWebView2Frame`. The host can register a handler per
iframe, and the iframe is the `sender` of the event, providing direct
attribution without an additional `QueryInterface` or name lookup. A new
`Handled` property on the event args allows a frame-level handler to suppress
the webview-level handlers for that launch.

This design follows the per-frame event model used by
[`ICoreWebView2Frame3::add_PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested)
and
[`ICoreWebView2PermissionRequestedEventArgs2::Handled`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs2#put_handled).
A related attribution mechanism,
[`OriginalSourceFrameInfo` on `ICoreWebView2NewWindowRequestedEventArgs3`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2newwindowrequestedeventargs3#get_originalsourceframeinfo),
addresses the same problem for the `NewWindowRequested` event. The trade-offs
between the two approaches are described in the Appendix.


# Description

The `LaunchingExternalUriScheme` event is raised on `CoreWebView2Frame` when
content in that frame, or in a descendant iframe that does not have a closer
tracked `CoreWebView2Frame` ancestor, attempts to launch an external URI
scheme. The `sender` of the event is the `CoreWebView2Frame`, so the host can
attribute the launch to a specific iframe.

`CoreWebView2LaunchingExternalUriSchemeEventArgs` exposes a new `Handled`
property.

By default, the event is raised on both `CoreWebView2Frame` and
`CoreWebView2`. Frame-level handlers are invoked before webview-level
handlers. If `Handled` is set to `TRUE` in a frame-level handler, the event
is not raised on `CoreWebView2`, and its handlers are not invoked. This
preserves backward compatibility for hosts that handle the event only on
`CoreWebView2`.

For nested iframes, the event is raised on the closest tracked
`CoreWebView2Frame` in the initiating iframe's ancestor chain, matching the
routing used by
[`CoreWebView2Frame.PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested).

The event args are shared between the two handler tiers. Properties set by
the frame-level handler, including `Cancel` and `Handled`, are visible to
webview-level handlers. A `Deferral` taken in either tier blocks the launch
until the deferral is completed.

`Cancel` controls whether the URI is launched. `Handled` controls whether
webview-level handlers are invoked. The two are independent.


# Examples

## Registering a per-iframe LaunchingExternalUriScheme handler

A host that embeds multiple sub-applications in iframes can register a handler
per iframe to attribute external URI launches to a specific sub-application
and present a consent prompt that names the correct one. Setting
`Handled = TRUE` in the frame-level handler prevents the webview-level handler
from being invoked for the same event.

### Win32 C++

```cpp
AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webview;
EventRegistrationToken m_frameCreatedToken = {};
EventRegistrationToken m_frameLaunchingExternalUriSchemeToken = {};

void RegisterFrameLaunchingExternalUriSchemeHandler()
{
    auto webview4 = m_webview.try_query<ICoreWebView2_4>();
    if (!webview4)
    {
        return;
    }

    CHECK_FAILURE(webview4->add_FrameCreated(
        Callback<ICoreWebView2FrameCreatedEventHandler>(
            [this](ICoreWebView2* sender,
                   ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
            {
                wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                CHECK_FAILURE(args->get_Frame(&webviewFrame));

                auto frame10 = webviewFrame
                    .try_query<ICoreWebView2ExperimentalFrame10>();
                if (!frame10)
                {
                    return S_OK;
                }

                CHECK_FAILURE(frame10->add_LaunchingExternalUriScheme(
                    Callback<
                        ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler>(
                        [this](
                            ICoreWebView2Frame* frameSender,
                            ICoreWebView2LaunchingExternalUriSchemeEventArgs2*
                                args) -> HRESULT
                        {
                            // Avoid reentrancy by scheduling the dialog
                            // asynchronously, outside this event handler.
                            // Because a deferral is taken, set `Handled` to
                            // TRUE synchronously before taking the deferral
                            // so that the `CoreWebView2`-level handlers are
                            // not invoked.
                            CHECK_FAILURE(args->put_Handled(TRUE));

                            wil::com_ptr<ICoreWebView2Deferral> deferral;
                            CHECK_FAILURE(args->GetDeferral(&deferral));

                            wil::com_ptr<ICoreWebView2Frame> sender(
                                frameSender);

                            m_appWindow->RunAsync(
                                [sender, deferral, args]
                                {
                                    wil::unique_cotaskmem_string frameName;
                                    CHECK_FAILURE(
                                        sender->get_Name(&frameName));
                                    wil::unique_cotaskmem_string uri;
                                    CHECK_FAILURE(args->get_Uri(&uri));

                                    std::wstring message = L"The \"";
                                    message += frameName.get();
                                    message +=
                                        L"\" iframe is attempting to launch "
                                        L"an external URI scheme for ";
                                    message += uri.get();
                                    message += L".\n\nAllow this action?";

                                    int response = MessageBox(
                                        nullptr, message.c_str(),
                                        L"Launching External URI Scheme",
                                        MB_YESNO | MB_ICONQUESTION);
                                    CHECK_FAILURE(args->put_Cancel(
                                        response == IDYES ? FALSE : TRUE));
                                    CHECK_FAILURE(deferral->Complete());
                                });
                            return S_OK;
                        })
                        .Get(),
                    &m_frameLaunchingExternalUriSchemeToken));
                return S_OK;
            })
            .Get(),
        &m_frameCreatedToken));
}
```

### .NET C#

```c#
private WebView2 m_webview;

void RegisterFrameLaunchingExternalUriSchemeHandler()
{
    m_webview.CoreWebView2.FrameCreated += (sender, frameCreatedArgs) =>
    {
        frameCreatedArgs.Frame.LaunchingExternalUriScheme +=
            async (frameSender, args) =>
        {
            // Because asynchronous work is awaited below, set `Handled`
            // synchronously before taking the deferral so that the
            // `CoreWebView2`-level handlers are not invoked.
            args.Handled = true;

            CoreWebView2Deferral deferral = args.GetDeferral();
            using (deferral)
            {
                string message = $"The \"{frameSender.Name}\" iframe is " +
                    $"attempting to launch an external URI scheme for " +
                    $"{args.Uri}.\n\nAllow this action?";

                MessageBoxResult selection = MessageBox.Show(
                    message,
                    "Launching External URI Scheme",
                    MessageBoxButton.YesNo);

                args.Cancel = selection != MessageBoxResult.Yes;
            }
        };
    };
}
```


# API Details

## Win32 C++

```cpp
interface ICoreWebView2ExperimentalFrame10;
interface ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler;
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs2;

/// Extends the `ICoreWebView2Frame` interface to expose the
/// `LaunchingExternalUriScheme` event at the iframe level. Host applications
/// can subscribe per iframe to attribute external URI scheme launches to a
/// specific iframe, even when multiple frames share the same origin.
[uuid(0e3c31b7-bbca-5216-a2d1-40e7a211f0ab), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFrame10 : IUnknown {
  /// Adds an event handler for the `LaunchingExternalUriScheme` event. The
  /// event is raised when content in this `CoreWebView2Frame`, or in a
  /// descendant iframe that does not have a closer tracked
  /// `CoreWebView2Frame` ancestor, attempts to launch a URI registered with
  /// the OS as an external scheme handler.
  ///
  /// This event corresponds to `CoreWebView2.LaunchingExternalUriScheme`. For
  /// an iframe-initiated launch, `CoreWebView2Frame` handlers are invoked
  /// before `CoreWebView2` handlers. If the `Handled` property on
  /// `ICoreWebView2LaunchingExternalUriSchemeEventArgs2` is set to `TRUE`
  /// within a `CoreWebView2Frame` handler, the event is not raised on
  /// `CoreWebView2`, and its handlers are not invoked.
  ///
  /// If a deferral is not taken, the external URI scheme launch is blocked
  /// until the handler returns. If a deferral is taken, the launch is blocked
  /// until the deferral is completed. To prevent `CoreWebView2` handlers from
  /// being invoked, set `Handled` synchronously before taking a deferral.
  HRESULT add_LaunchingExternalUriScheme(
      [in] ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler*
          eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with
  /// `add_LaunchingExternalUriScheme`.
  HRESULT remove_LaunchingExternalUriScheme(
      [in] EventRegistrationToken token);
};

/// Receives `LaunchingExternalUriScheme` events raised on `CoreWebView2Frame`.
[uuid(8d0a4bee-a888-50bc-8088-a71678fd3af3), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler
    : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2LaunchingExternalUriSchemeEventArgs2* args);
};

/// Extends `ICoreWebView2LaunchingExternalUriSchemeEventArgs` with a `Handled`
/// property.
[uuid(126db12c-f6dc-51b7-afa4-3eecb5304b9f), object, pointer_default(unique)]
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs2
    : ICoreWebView2LaunchingExternalUriSchemeEventArgs {
  /// By default, the `LaunchingExternalUriScheme` event is raised on both
  /// `CoreWebView2Frame` and `CoreWebView2`, with frame-level handlers
  /// invoked first. Set this property to `TRUE` within a `CoreWebView2Frame`
  /// handler to prevent the event from being raised on `CoreWebView2`.
  ///
  /// If a deferral is taken, set this property to `TRUE` synchronously before
  /// taking the deferral to prevent `CoreWebView2` handlers from being
  /// invoked.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL value);
};
```

## .NET C#

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2LaunchingExternalUriSchemeEventArgs
    {
        // ...

        [interface_name(
            "Microsoft.Web.WebView2.Core.ICoreWebView2LaunchingExternalUriSchemeEventArgs2")]
        {
            [doc_string(
                "Set this property to TRUE to prevent the "
                "LaunchingExternalUriScheme event from being raised on "
                "CoreWebView2. By default, the event is raised on both "
                "CoreWebView2Frame and CoreWebView2, with frame-level "
                "handlers invoked first. If a deferral is taken, set this "
                "property to TRUE synchronously before taking the deferral.")]
            Boolean Handled { get; set; };
        }
    }

    runtimeclass CoreWebView2Frame
    {
        // ...

        [interface_name(
            "Microsoft.Web.WebView2.Core.ICoreWebView2ExperimentalFrame10")]
        {
            [doc_string(
                "The LaunchingExternalUriScheme event is raised when content "
                "in this CoreWebView2Frame, or in a descendant iframe that "
                "does not have a closer tracked CoreWebView2Frame ancestor, "
                "attempts to launch a URI registered with the OS as an "
                "external scheme handler. Frame-level handlers are invoked "
                "before CoreWebView2 handlers. Set Handled to TRUE in the "
                "frame handler to prevent CoreWebView2 handlers from being "
                "invoked.")]
            event Windows.Foundation.TypedEventHandler<
                CoreWebView2Frame,
                CoreWebView2LaunchingExternalUriSchemeEventArgs>
                LaunchingExternalUriScheme;
        }
    }
}
```


# Appendix

## Alternative considered: `OriginalSourceFrameInfo` on the webview-level args

An alternative considered was surfacing the initiating frame on the existing
webview-level event through an `OriginalSourceFrameInfo` property, mirroring
the pattern shipped on
[`ICoreWebView2NewWindowRequestedEventArgs3`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2newwindowrequestedeventargs3#get_originalsourceframeinfo).
That approach delivers the iframe identity to a single webview-level handler.

The frame-level event was chosen instead because it:

* aligns with the per-frame model already shipped for
  [`PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested)
  and
  [`ScreenCaptureStarting`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame6#add_screencapturestarting);
* allows independent handler registration per iframe, decoupling default
  webview-level policy from per-iframe rules;
* makes the iframe object directly available as the event `sender`, removing
  the need for a `QueryInterface` on the args; and
* together with `Handled`, allows a frame-level handler to suppress the
  webview-level handler, enabling allowlist and default-deny patterns where
  the webview-level handler is the default policy and per-iframe handlers
  override it.

The two approaches are not mutually exclusive. `OriginalSourceFrameInfo` on
the args could be added later if a single handler tier is preferred for some
scenarios.

## Nested iframes

The event is raised on the closest tracked `CoreWebView2Frame` in the
initiating iframe's ancestor chain. This matches the routing used by
[`CoreWebView2Frame.PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested).
The host registers `FrameCreated` handlers (top-level iframes only by default,
or
[`ICoreWebView2Frame7.add_FrameCreated`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame7#add_framecreated)
to track nested iframes), and `LaunchingExternalUriScheme` is delivered to the
closest tracked iframe in the chain.

## Same-origin and cross-origin iframes

The event is raised regardless of whether the iframe shares an origin with its
parent. Cross-origin iframes without a user gesture follow existing WebView2
behavior: the external URI launch is blocked and the event is not raised,
matching the
[`CoreWebView2.LaunchingExternalUriScheme`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2_18#add_launchingexternalurischeme)
contract.
