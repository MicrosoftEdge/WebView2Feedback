Default Download Dialog Layout
===

# Background
This API gives you the ability to change the position of the default download dialog
relative to the webview window, and to programmatically open and close the dialog.

You can anchor the default download dialog to a button in your application by setting its
position below your button, and alternating open and close calls when the button is
clicked on.

For more complex customizations, you can use the Download APIs -
[DownloadStarting](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2downloadstartingeventargs?view=webview2-1.0.961.33)
 and [DownloadOperation](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2downloadoperation?view=webview2-1.0.961.33) - to build custom download UI.

# Examples
```cpp
void ViewComponent::ToggleDefaultDownloadDialog()
{
    if (m_webView2_6)
    {
        BOOL is_visible;
        m_webView2_6->get_IsDefaultDownloadDialogVisible(&is_visible);
        m_webView2_6->put_IsDefaultDownloadDialogVisible(!is_visible);
    }
}

void ViewComponent::SetDefaultDownloadDialogPosition(DownloadDialogPosition target_position)
{
    if (m_webView2_6)
    {
        CHECK_FAILURE(m_webView2_6->add_DefaultDownloadDialogLayout(
            Callback<ICoreWebView2DefaultDownloadDialogLayoutEventHandler>(
                [this, target_position](
                    ICoreWebView2* sender,
                    ICoreWebView2DefaultDownloadDialogLayoutEventArgs* args) -> HRESULT {
                    RECT bounds;
                    CHECK_FAILURE(args->get_LocalBounds(&bounds));

                    INT32 width;
                    CHECK_FAILURE(args->get_Width(&width));

                    INT32 height;
                    CHECK_FAILURE(args->get_Height(&height));

                    const int padding = 10;
                    const int x_from_right = bounds.right - width - padding;
                    const int y_from_bottom = bounds.bottom - height - padding;
                    POINT new_position;

                    if (target_position == DownloadDialogPosition::kTopLeft)
                    {
                        new_position = {padding, padding};
                    }
                    else if (target_position == DownloadDialogPosition::kTopRight)
                    {
                        new_position = {x_from_right, padding};
                    }
                    else if (target_position == DownloadDialogPosition::kBottomLeft)
                    {
                        new_position = {padding, y_from_bottom};
                    }
                    else if (target_position == DownloadDialogPosition::kBottomRight)
                    {
                        new_position = {x_from_right, y_from_bottom};
                    }
                    CHECK_FAILURE(args->put_Position(new_position));
                    return S_OK;
                })
                .Get(),
            &m_downloadLayoutToken));
    }
}
```

```c#
void ToggleDownloadDialogCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.IsDefaultDownloadDialogVisible =
        !webView.CoreWebView2.IsDefaultDownloadDialogVisible;
}

void DownloadDialogPositionCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.DefaultDownloadDialogLayout += delegate (
        object sender, CoreWebView2DefaultDownloadDialogLayoutEventArgs args)
    {
        int padding = 10;
        int width = args.Width;
        int height = args.Height;
        System.Drawing.Rectangle bounds = args.LocalBounds;
        string position = e.Parameter.ToString();
        int x_from_right = bounds.Width - width - padding;
        int y_from_bottom = bounds.Height - height - padding;
        System.Drawing.Point new_position = args.Position;
        if (position == "Top-left")
        {
            new_position = new System.Drawing.Point(padding, padding);
        }
        else if (position == "Top-right")
        {
            new_position = new System.Drawing.Point(x_from_right, padding);
        }
        else if (position == "Bottom-left")
        {
            new_position = new System.Drawing.Point(padding, y_from_bottom);
        }
        else if (position == "Bottom-right")
        {
            new_position = new System.Drawing.Point(x_from_right, y_from_bottom);
        }
        args.Position = new_position;
    };
}
```

# API Details


```c#
[uuid(9139c04d-8f37-42ae-8b63-01940c34d22f), object, pointer_default(unique)]
interface ICoreWebView2_6 : ICoreWebView2_5
{
  /// `TRUE` if the default download dialog is currently visible.
  [propget] HRESULT IsDefaultDownloadDialogVisible(
      [out, retval] BOOL* isDefaultDownloadDialogVisible);

  /// Sets the `IsDefaultDownloadDialogVisible` property. A download is
  /// considered recent if it was downloaded in this instance of the webview.
  /// If there has not yet been a recent download, setting the default download
  /// dialog to visible displays all past downloads for the current profile.
  /// Otherwise, the dialog will display only the recent downloads with a
  /// "See more" button, which displays the past downloads when clicked on.
  ///
  /// \snippet ViewComponent.cpp ToggleDefaultDownloadDialog
  [propput] HRESULT IsDefaultDownloadDialogVisible(
      [in] BOOL isDefaultDownloadDialogVisible);

  /// Adds an event handler for the `DefaultDownloadDialogLayout` event. The event is
  /// raised when the default download dialog's position needs to be recomputed,
  /// such as when the dialog is first opened, when the webview is resized, and
  /// when the webview is navigated. Use the `Position` property on the event
  /// args to specify the new position. To set the position relative to the
  /// current webview bounds, use the `LocalBounds` property on the event args.
  ///
  /// \snippet ViewComponent.cpp SetDefaultDownloadDialogPosition
  HRESULT add_DefaultDownloadDialogLayout(
      [in] ICoreWebView2DefaultDownloadDialogLayoutEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_DefaultDownloadDialogLayout`.
  HRESULT remove_DefaultDownloadDialogLayout([in] EventRegistrationToken token);
}

/// Implements the interface to receive `DefaultDownloadDialogLayout` events.
[uuid(86557854-794a-414a-b046-ba515f617306), object, pointer_default(unique)]
interface ICoreWebView2DefaultDownloadDialogLayoutEventHandler : IUnknown {

  /// Provides the event args for the corresponding event.
  HRESULT Invoke([in] ICoreWebView2* sender,
                 [in] ICoreWebView2DefaultDownloadDialogLayoutEventArgs* args);
}

[uuid(e7d2bdea-2e67-4550-b286-6e7d20653d4e), object, pointer_default(unique)]
interface ICoreWebView2DefaultDownloadDialogLayoutEventArgs : IUnknown {
  /// The default download dialog position of the top-left corner, relative to
  /// the webview bounds. Use `LocalBounds` to check the current webview bounds.
  /// The default position of the download dialog is calculated with the
  /// following formula:
  /// (LocalBounds.right - Width - 30, LocalBounds.top + 15).
  [propget] HRESULT Position([out, retval] POINT* position);

  /// Sets the default download dialog position. Returns `E_INVALIDARG` if an
  /// invalid position is provided, and the default position is used instead.
  [propput] HRESULT Position([in] POINT position);

  /// Get the current webview bounds, with the top-left corner being (0, 0).
  [propget] HRESULT LocalBounds([out, retval] RECT* bounds);

    /// Get the width of the default download dialog.
  [propget] HRESULT Width([out, retval] INT32* width);

    /// Get the height of the default download dialog.
  [propget] HRESULT Height([out, retval] INT32* height);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DefaultDownloadDialogLayoutEventArgs;
    runtimeclass CoreWebView2;

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_6")]
        {
            // ICoreWebView2_6 members
            Boolean IsDefaultDownloadDialogVisible { get; set; };

            event Windows.Foundation.TypedEventHandler<CoreWebView2,
                CoreWebView2DefaultDownloadDialogLayoutEventArgs> DefaultDownloadDialogLayout;
        }
    }

    runtimeclass CoreWebView2DefaultDownloadDialogLayoutEventArgs
    {
        // ICoreWebView2DefaultDownloadDialogLayoutEventArgs members
        Windows.Foundation.Point Position { get; set; };

        Windows.Foundation.Rect LocalBounds { get; };

        Int32 Width { get; };

        Int32 Height { get; };
    }
}
```


# Appendix