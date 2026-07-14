# Frame-Level LaunchingExternalUriScheme

## Background

`CoreWebView2.LaunchingExternalUriScheme` is raised when web content attempts
to launch a URI scheme handled by an external application (for example,
`mailto:`, `tel:`, or a custom protocol). Hosts can handle this event to
suppress the default WebView2 dialog, provide custom consent UI, and set
`Cancel` to control whether the URI is launched.

The event arguments expose:

- `Uri`
- `InitiatingOrigin`
- `IsUserInitiated`
- `Cancel`

This event does not identify the originating iframe. When multiple
sub-applications are hosted within iframes, this can prevent reliable
attribution of the request to a specific iframe, including:

- When multiple iframes share the same origin.
- When the same content is hosted in multiple surfaces (for example, windows
  or panels).
- When sandboxed or `srcdoc` iframes report an opaque or inherited origin.

## Description

`LaunchingExternalUriScheme` is also raised on `CoreWebView2Frame`.

The event is raised when content in a frame, or in an iframe nested within it,
attempts to launch an external URI scheme. When the launch originates from a
nested iframe, the event bubbles through each tracked `CoreWebView2Frame` in the
initiating iframe's ancestor chain, starting with the closest (innermost)
tracked frame and proceeding outward toward the top-level frame. The event
sender for each invocation is the `CoreWebView2Frame` receiving the event,
enabling attribution to the initiating frame.

The `LaunchingExternalUriScheme` event arguments add a `Handled` property.

By default, the event is raised on both `CoreWebView2Frame` and `CoreWebView2`.
Frame-level handlers are invoked before WebView-level handlers. If a
frame-level handler sets `Handled` to `TRUE`, the event is not raised on
`CoreWebView2`, and its handlers are not invoked.

The event arguments are shared between handler tiers. Properties set in a
frame-level handler, including `Cancel` and `Handled`, are visible to
WebView-level handlers. A `Deferral` taken in either handler tier delays the
URI launch until the deferral is completed. To suppress the WebView-level
handlers, set `Handled` before taking the deferral.

`Cancel` controls whether the URI is launched. `Handled` controls whether
WebView-level handlers are invoked.

### Nested iframes

When the launch originates from a nested iframe, the event bubbles outward
through the tracked `CoreWebView2Frame` ancestors. It is raised first on the
closest (innermost) tracked frame, then on each tracked ancestor frame in turn,
and finally on `CoreWebView2`. If a handler at any tier sets `Handled` to
`TRUE`, the event is not raised on the remaining ancestor frames or on
`CoreWebView2`. This behavior is consistent with
[`CoreWebView2Frame.PermissionRequested`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2frame3#add_permissionrequested).

### Same-origin and cross-origin iframes

The event is raised regardless of origin. For cross-origin iframes without user
activation, the launch is blocked and the event is not raised, consistent with
[`CoreWebView2.LaunchingExternalUriScheme`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2_18#add_launchingexternalurischeme).

## Examples

### Registering a per-iframe handler

A host embedding multiple sub-applications in iframes can register a handler
per iframe to attribute external URI launches and present iframe-specific
consent UI. Setting `Handled = TRUE` prevents the WebView-level handlers from
being invoked.

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

                auto frame9 = webviewFrame
                    .try_query<ICoreWebView2Frame9>();
                if (!frame9)
                {
                    return S_OK;
                }

                CHECK_FAILURE(frame9->add_LaunchingExternalUriScheme(
                    Callback<
                        ICoreWebView2FrameLaunchingExternalUriSchemeEventHandler>(
                        [this](
                            ICoreWebView2Frame* frameSender,
                            ICoreWebView2LaunchingExternalUriSchemeEventArgs2*
                                args) -> HRESULT
                        {
                            // Avoid reentrancy by scheduling the dialog
                            // asynchronously outside the event handler.
                            // Because a deferral is taken, set `Handled`
                            // to TRUE synchronously before taking the
                            // deferral. This prevents `CoreWebView2`-level
                            // handlers from being invoked.
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
            // Because asynchronous work is awaited below, set `Handled`
            // synchronously before taking the deferral. This prevents
            // `CoreWebView2`-level handlers from being invoked.
            args.Handled = true;

            CoreWebView2Deferral deferral = args.GetDeferral();
            using (deferral)
            {
                string message =
                    $"The \"{frameSender.Name}\" iframe is " +
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

## Win32 (C++)

```cpp
interface ICoreWebView2Frame9;
interface ICoreWebView2FrameLaunchingExternalUriSchemeEventHandler;
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs2;

/// Extends the `ICoreWebView2Frame` interface to expose the
/// `LaunchingExternalUriScheme` event at the iframe level.
/// Host applications can subscribe on a per-frame basis to attribute
/// external URI scheme launches to a specific iframe, even when multiple
/// frames share the same origin.
[uuid(0e3c31b7-bbca-5216-a2d1-40e7a211f0ab), object, pointer_default(unique)]
interface ICoreWebView2Frame9 : IUnknown {
  /// Adds an event handler for the `LaunchingExternalUriScheme` event.
  /// The event is raised when content in this `CoreWebView2Frame`, or in one
  /// of its descendant iframes, attempts to launch a URI registered with the
  /// OS as an external scheme handler. When the launch originates from a
  /// nested iframe, the event bubbles outward through the tracked
  /// `CoreWebView2Frame` ancestors, starting with the closest (innermost)
  /// tracked frame and proceeding outward toward the top-level frame.
  ///
  /// This event corresponds to `CoreWebView2.LaunchingExternalUriScheme`.
  /// For iframe-initiated launches, `CoreWebView2Frame` handlers are
  /// invoked before `CoreWebView2` handlers. If the `Handled` property on
  /// `ICoreWebView2LaunchingExternalUriSchemeEventArgs2` is set to `TRUE`
  /// within a `CoreWebView2Frame` handler, the event is not raised on the
  /// remaining ancestor frames or on `CoreWebView2`, and their handlers are
  /// not invoked.
  ///
  /// If a deferral is not taken, the external URI scheme launch is blocked
  /// until the handler returns. If a deferral is taken, the launch remains
  /// blocked until the deferral is completed.
  ///
  /// To prevent `CoreWebView2` handlers from being invoked when a deferral
  /// is taken, set `Handled` to `TRUE` synchronously before taking the
  /// deferral.
  HRESULT add_LaunchingExternalUriScheme(
      [in] ICoreWebView2FrameLaunchingExternalUriSchemeEventHandler*
          eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added by
  /// `add_LaunchingExternalUriScheme`.
  HRESULT remove_LaunchingExternalUriScheme(
      [in] EventRegistrationToken token);
};

/// Receives `LaunchingExternalUriScheme` events raised on
/// `CoreWebView2Frame`.
[uuid(8d0a4bee-a888-50bc-8088-a71678fd3af3), object, pointer_default(unique)]
interface ICoreWebView2FrameLaunchingExternalUriSchemeEventHandler
    : IUnknown {
  /// Invoked when the corresponding event is raised.
  HRESULT Invoke(
      [in] ICoreWebView2Frame* sender,
      [in] ICoreWebView2LaunchingExternalUriSchemeEventArgs2* args);
};

/// Extends `ICoreWebView2LaunchingExternalUriSchemeEventArgs` with a
/// `Handled` property.
[uuid(add51d52-f724-5ab6-b59a-fc032ee90416), object, pointer_default(unique)]
interface ICoreWebView2LaunchingExternalUriSchemeEventArgs2
    : ICoreWebView2LaunchingExternalUriSchemeEventArgs {
  /// By default, the `LaunchingExternalUriScheme` event is raised on both
  /// `CoreWebView2Frame` and `CoreWebView2`, with frame-level handlers
  /// invoked first. Set this property to `TRUE` within a
  /// `CoreWebView2Frame` handler to prevent the event from being raised on
  /// `CoreWebView2`.
  ///
  /// To prevent `CoreWebView2` handlers from being invoked when a deferral
  /// is taken, set `Handled` to `TRUE` synchronously before taking the
  /// deferral.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL value);
};
```

## .Net/C#

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
                "By default, the LaunchingExternalUriScheme event is "
                "raised on both CoreWebView2Frame and CoreWebView2, with "
                "frame-level handlers invoked first. Set this property to "
                "TRUE within a CoreWebView2Frame handler to prevent the "
                "event from being raised on CoreWebView2. To prevent "
                "CoreWebView2 handlers from being invoked when a deferral "
                "is taken, set Handled to TRUE synchronously before taking "
                "the deferral.")]
            Boolean Handled { get; set; };
        }
    }

    runtimeclass CoreWebView2Frame
    {
        // ...

        [interface_name(
            "Microsoft.Web.WebView2.Core.ICoreWebView2Frame9")]
        {
            [doc_string(
                "The LaunchingExternalUriScheme event is raised when "
                "content in this CoreWebView2Frame, or in one of its "
                "descendant iframes, attempts to launch a URI registered "
                "with the OS as an external scheme handler. When the launch "
                "originates from a nested iframe, the event bubbles outward "
                "through the tracked CoreWebView2Frame ancestors, starting "
                "with the closest (innermost) tracked frame and proceeding "
                "outward toward the top-level frame. "
                "Frame-level handlers are invoked before CoreWebView2 "
                "handlers. Set Handled to TRUE in the frame handler to "
                "prevent the remaining ancestor frames and CoreWebView2 "
                "handlers from being invoked.")]
            event Windows.Foundation.TypedEventHandler<
                CoreWebView2Frame,
                CoreWebView2LaunchingExternalUriSchemeEventArgs>
                LaunchingExternalUriScheme;
        }
    }
}
```
