Frame-Level LaunchingExternalUriScheme
===

# Background

WebView2 raises the `LaunchingExternalUriScheme` event on the
`CoreWebView2` when web content attempts to launch a URI scheme registered
with the OS as an external scheme handler (for example `mailto:`, `tel:`,
or a custom protocol). The host can intercept the event to suppress the
default WebView2 dialog, present its own consent UX, and `Cancel` the
launch.

Today the event surfaces only `Uri`, `InitiatingOrigin`,
`IsUserInitiated`, and `Cancel`. There is no way for the host to tell
*which iframe* initiated the launch. Hosts that embed multiple
sub-applications as iframes within a single WebView2 — typically loaded
from a shared CDN host — cannot reliably attribute a launch to the
specific iframe that triggered it, because:

1. Multiple iframes can be served from the same origin and the event
   provides no signal beyond the origin.
2. The same iframe content may be presented in more than one host
   surface (window, panel) and the host cannot route the consent prompt
   to the correct surface.
3. Sandboxed and `srcdoc` iframes have opaque origins; the API reports
   their parent's origin, making the iframe itself invisible.

This spec proposes raising the `LaunchingExternalUriScheme` event
additionally on `CoreWebView2Frame` so hosts can register per-iframe
handlers. The iframe object is the `sender` of the event, giving direct
attribution without any extra `QueryInterface` or name lookup. A new
`Handled` property on the event args lets a frame-level handler suppress
the webview-level handler for that launch.

The shape of this API mirrors
[`ICoreWebView2Frame3::add_PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested)
+
[`ICoreWebView2PermissionRequestedEventArgs2::Handled`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs2#put_handled)
— see
[specs/IFramePermissionRequested.md](IFramePermissionRequested.md) for
the precedent. The
[`OriginalSourceFrameInfo` property added to `NewWindowRequested`](NewWindowSourceFrameInfo.md)
solves a related attribution problem for that event; the trade-offs
between the two shapes are summarized in the Appendix.

We would appreciate your feedback.


# Description

We propose extending `CoreWebView2Frame` with a new
`LaunchingExternalUriScheme` event. The event is raised when content in
the `CoreWebView2Frame` (or any of its descendant iframes that don't have
a closer tracked `CoreWebView2Frame` ancestor) attempts to launch an
external URI scheme. The sender of the event is the `CoreWebView2Frame`
itself, so the host can immediately attribute the launch to a specific
iframe.

We also propose extending
`CoreWebView2LaunchingExternalUriSchemeEventArgs` with a new `Handled`
property.

To maintain backwards compatibility, by default we plan to raise
`LaunchingExternalUriScheme` on both `CoreWebView2Frame` and
`CoreWebView2`. The `CoreWebView2Frame` event handlers will be invoked
first, before the `CoreWebView2` event handlers. If `Handled` is set to
`TRUE` from within the `CoreWebView2Frame` event handler, then the event
will not be raised on the `CoreWebView2`, and its event handlers will
not be invoked.

For nested iframes (an iframe inside an iframe), the event surfaces on
the closest tracked `CoreWebView2Frame` in the ancestor chain — matching
the routing convention already used by
[`CoreWebView2Frame.PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested).

The event args are shared between the two handler tiers — properties set
by the frame handler (`Cancel`, `Handled`) are visible to the
webview handler, and a `Deferral` taken in either tier blocks the launch
until completed.

The existing `Cancel` semantics are preserved. `Handled` is orthogonal:
`Cancel` controls whether the URI is actually launched; `Handled` only
controls whether the webview-level handlers run for this event.


# Examples

## Registering a per-iframe LaunchingExternalUriScheme handler

A host that embeds multiple sub-applications in iframes can register a
handler per iframe to attribute external-URI launches to a specific
sub-app and present a consent prompt that names the right one. Setting
`Handled = TRUE` from the frame handler prevents the webview-level
handler from running again for the same event.

### C++

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
                            // We avoid potential reentrancy by showing the
                            // dialog via a lambda run asynchronously outside
                            // of this event handler. Because we plan to take
                            // a deferral, set `Handled` to TRUE synchronously
                            // before the deferral so that the
                            // `CoreWebView2`-level handlers do not run.
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

                                    std::wstring message =
                                        L"The \"";
                                    message += frameName.get();
                                    message +=
                                        L"\" iframe is trying to launch "
                                        L"the external scheme handler for ";
                                    message += uri.get();
                                    message +=
                                        L".\n\nDo you want to allow it?";

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

### C#

```c#
private WebView2 m_webview;

void RegisterFrameLaunchingExternalUriSchemeHandler()
{
    m_webview.CoreWebView2.FrameCreated += (sender, frameCreatedArgs) =>
    {
        frameCreatedArgs.Frame.LaunchingExternalUriScheme +=
            async (frameSender, args) =>
        {
            // Because we plan to await asynchronous work below, set
            // `Handled` synchronously before taking the deferral so that
            // the `CoreWebView2`-level handlers do not run.
            args.Handled = true;

            CoreWebView2Deferral deferral = args.GetDeferral();
            using (deferral)
            {
                string message = $"The \"{frameSender.Name}\" iframe is " +
                    $"trying to launch the external scheme handler for " +
                    $"{args.Uri}.\n\nDo you want to allow it?";

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

```idl
/// This is an extension of the `ICoreWebView2Frame` interface that
/// surfaces the `LaunchingExternalUriScheme` event at the iframe level.
/// Host apps can subscribe per-iframe to attribute external URI scheme
/// launches to a specific iframe even when multiple frames share the
/// same origin.
[uuid(0e3c31b7-bbca-5216-a2d1-40e7a211f0ab), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFrame10 : IUnknown {
  /// Add an event handler for the `LaunchingExternalUriScheme` event.
  /// `LaunchingExternalUriScheme` is raised when content in this
  /// `CoreWebView2Frame` (or any of its descendant iframes that don't
  /// have a closer tracked `CoreWebView2Frame` ancestor) attempts to
  /// launch a URI registered with the OS as an external scheme handler.
  ///
  /// This relates to the `LaunchingExternalUriScheme` event on the
  /// `CoreWebView2`. For an iframe-initiated launch the
  /// `CoreWebView2Frame`'s event handlers are invoked before the
  /// `CoreWebView2`'s event handlers. If the `Handled` property of the
  /// `ICoreWebView2LaunchingExternalUriSchemeEventArgs2` is set to `TRUE`
  /// within the `CoreWebView2Frame` event handler, then the event will
  /// not be raised on the `CoreWebView2`, and its event handlers will
  /// not be invoked.
  ///
  /// If a deferral is not taken on the event args, the external URI
  /// scheme launch is blocked until the event handler returns. If a
  /// deferral is taken, the launch is blocked until the deferral is
  /// completed. To suppress the `CoreWebView2`-level event handlers,
  /// `Handled` must be set synchronously before any deferral is taken.
  HRESULT add_LaunchingExternalUriScheme(
      [in] ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler*
          eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with
  /// `add_LaunchingExternalUriScheme`.
  HRESULT remove_LaunchingExternalUriScheme(
      [in] EventRegistrationToken token);
}

/// Receives `LaunchingExternalUriScheme` events raised on
/// `CoreWebView2Frame`.
[uuid(8d0a4bee-a888-50bc-8088-a71678fd3af3), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFrameLaunchingExternalUriSchemeEventHandler
    : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2LaunchingExternalUriSchemeEventArgs2* args);
}

/// This is a continuation of the
/// `ICoreWebView2LaunchingExternalUriSchemeEventArgs` interface that
/// adds the `Handled` property.
[uuid(126db12c-f6dc-51b7-afa4-3eecb5304b9f), object, pointer_default(unique)]
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs2
    : ICoreWebView2LaunchingExternalUriSchemeEventArgs {
  /// By default, both the `LaunchingExternalUriScheme` event handlers on
  /// the `CoreWebView2Frame` and the `CoreWebView2` will be invoked,
  /// with the `CoreWebView2Frame` event handlers invoked first. The host
  /// may set this flag to `TRUE` within the `CoreWebView2Frame` event
  /// handlers to prevent the remaining `CoreWebView2` event handlers
  /// from being invoked.
  ///
  /// If a deferral is taken on the event args, then you must
  /// synchronously set `Handled` to `TRUE` prior to taking your deferral
  /// to prevent the `CoreWebView2`'s event handlers from being invoked.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL value);
}
```

## .NET, WinRT

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
                "The host may set this flag to TRUE to prevent the "
                "LaunchingExternalUriScheme event from firing on the "
                "CoreWebView2 as well. By default, both the "
                "LaunchingExternalUriScheme on the CoreWebView2Frame "
                "and the CoreWebView2 will be raised.")]
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
                "LaunchingExternalUriScheme is raised when content in "
                "this CoreWebView2Frame (or any of its descendant "
                "iframes that don't have a closer tracked "
                "CoreWebView2Frame ancestor) attempts to launch a URI "
                "registered with the OS as an external scheme handler. "
                "The CoreWebView2Frame's event handlers are invoked "
                "before the CoreWebView2's event handlers; set Handled "
                "to TRUE in the frame handler to suppress the "
                "webview-level handlers.")]
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

We considered surfacing the initiating frame on the existing webview-level
event via an `OriginalSourceFrameInfo` property, mirroring the pattern
shipped on
[`ICoreWebView2NewWindowRequestedEventArgs3`](NewWindowSourceFrameInfo.md).
That approach delivers the iframe identity to a single webview-level
handler.

We chose the frame-level event instead because it:

* aligns with the per-frame ergonomic already shipped for
  [`PermissionRequested`](IFramePermissionRequested.md) and
  `ScreenCaptureStarting`;
* allows independent handler registration per iframe, decoupling default
  webview-level policy from per-iframe rules;
* makes the iframe object directly available as the event `sender`,
  removing the need for a `QueryInterface` on the args; and
* together with `Handled` lets a frame handler cleanly suppress the
  webview handler — enabling allowlist / default-deny patterns where the
  webview-level handler is the default policy and per-iframe handlers
  override it.

The two approaches are not mutually exclusive — `OriginalSourceFrameInfo`
on the args could be added later if a single-handler tier is preferred
for some scenarios.

## Nested iframes

The event surfaces on the closest tracked `CoreWebView2Frame` in the
initiating iframe's ancestor chain. This matches the routing convention
already used by
[`CoreWebView2Frame.PermissionRequested`](IFramePermissionRequested.md):
the host registers `FrameCreated` handlers (top-level iframes only by
default; or use
[`ICoreWebView2Frame7.add_FrameCreated`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame7#add_framecreated)
to track nested iframes), and `LaunchingExternalUriScheme` is delivered
to the closest tracked iframe up the chain.

## Same-origin / cross-origin iframes

The event fires regardless of whether the iframe shares an origin with
its parent. Cross-origin iframes without a user gesture still follow
existing WebView2 behavior: the external-URI launch is blocked and the
event is not raised, matching the
[`CoreWebView2.LaunchingExternalUriScheme`](LaunchingExternalUriScheme.md)
contract.
