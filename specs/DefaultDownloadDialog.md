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
        BOOL is_open;
        m_webView2_6->get_IsDefaultDownloadDialogOpen(&is_open);
        if (is_open)
        {
            m_webView2_6->CloseDefaultDownloadDialog();
        }
        else
        {
            m_webView2_6->OpenDefaultDownloadDialog();
        }
    }
}

void ViewComponent::SetDefaultDownloadDialogPosition(
    COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION target_position)
{
    if (m_webView2_6)
    {
        const int padding = 20;
        POINT offset;
        switch (target_position) {
            case COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_TOP_LEFT:
                offset = {padding, padding};
                break;
            case COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_TOP_RIGHT:
                offset = {-padding, padding};
                break;
            case COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_BOTTOM_LEFT:
                offset = {padding, -padding};
                break;
            case COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_BOTTOM_RIGHT:
                offset = {-padding, -padding};
                break;
        }
        CHECK_FAILURE(m_webView2_6->SetDefaultDownloadDialogPosition(
            target_position, offset));
    }
}
```

```c#
void ToggleDownloadDialogCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    if (webView.CoreWebView2.IsDefaultDownloadDialogOpen)
    {
        webView.CoreWebView2.CloseDefaultDownloadDialog();
    }
    else
    {
        webView.CoreWebView2.OpenDefaultDownloadDialog();
    }
}

void DownloadDialogPositionCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    CoreWebView2DefaultDownloadDialogPosition new_position =
        CoreWebView2DefaultDownloadDialogPosition.TopRight;
    System.Drawing.Point offset = new System.Drawing.Point();
    string position = e.Parameter.ToString();
    int padding = 20;
    if (position == "Top-left")
    {
        new_position =
            CoreWebView2DefaultDownloadDialogPosition.TopLeft;
        offset = new System.Drawing.Point(padding, padding);
    }
    else if (position == "Top-right")
    {
        new_position =
            CoreWebView2DefaultDownloadDialogPosition.TopRight;
        offset = new System.Drawing.Point(-padding, padding);
    }
    else if (position == "Bottom-left")
    {
        new_position =
            CoreWebView2DefaultDownloadDialogPosition.BottomLeft;
        offset = new System.Drawing.Point(padding, -padding);
    }
    else if (position == "Bottom-right")
    {
        new_position =
            CoreWebView2DefaultDownloadDialogPosition.BottomRight;
        offset = new System.Drawing.Point(-padding, -padding);
    }
    webView.CoreWebView2.SetDefaultDownloadDialogPosition(
        new_position, offset);
}
```

# API Details


```c#
/// The default download dialog can be aligned to any of the WebView corners.
/// Use `SetDefaultDownloadDialogPosition` to specify a position and optional
/// offset from that position.
typedef enum COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION {

  /// Top-left corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_TOP_LEFT,

  /// Top-right corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_TOP_RIGHT,

  /// Bottom-left corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_BOTTOM_LEFT,

  /// Bottom-right corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_BOTTOM_RIGHT,

} COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION;

[uuid(9139c04d-8f37-42ae-8b63-01940c34d22f), object, pointer_default(unique)]
interface ICoreWebView2_6 : ICoreWebView2_5
{
  /// `TRUE` if the default download dialog is currently open.
  [propget] HRESULT IsDefaultDownloadDialogOpen(
      [out, retval] BOOL* isDefaultDownloadDialogOpen);

  /// Open the default download dialog. If the dialog is opened before there
  /// are recent downloads, the dialog shows all past downloads for the
  /// current profile. Otherwise, the dialog shows only the recent downloads
  /// with a "See more" button for past downloads.
  ///
  /// \snippet ViewComponent.cpp ToggleDefaultDownloadDialog
  HRESULT OpenDefaultDownloadDialog();

  /// Close the default download dialog.
  HRESULT CloseDefaultDownloadDialog();

  /// Set the default download dialog position relative to the WebView bounds.
  /// The dialog can be positioned against any of the WebView corners (see
  /// COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION). When the WebView or dialog
  /// changes size, the dialog keeps its position relative to the corner.
  ///
  /// The offset is an (x, y) coordinate in physical pixels that applies to the
  /// dialog corner nearest to the COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION
  /// specified. Use (0, 0) if no offset should be applied.
  ///
  /// The default position is top-right corner with offset (-30, 10). The dialog
  /// may become partially or completely outside of the WebView bounds if the
  /// WebView is small enough. The height of the dialog starts at 128 pixels and
  /// expands with each new download until it reaches a maximum height of 650
  /// pixels. The dialog also expands to maximum height when the "See more"
  /// button is clicked on. The width is always 360 pixels.
  ///
  /// \snippet ViewComponent.cpp SetDefaultDownloadDialogPosition
  HRESULT SetDefaultDownloadDialogPosition(
      COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION position,
      POINT offset);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2;

    enum CoreWebView2DefaultDownloadDialogPosition
    {
        TopLeft = 0,
        TopRight = 1,
        BottomLeft = 2,
        BottomRight = 3,
    };

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_6")]
        {
            // ICoreWebView2_6 members
            Boolean IsDefaultDownloadDialogOpen { get; };

            void OpenDefaultDownloadDialog();

            void CloseDefaultDownloadDialog();

            void SetDefaultDownloadDialogPosition(
                CoreWebView2DefaultDownloadDialogPosition position,
                Windows.Foundation.Point offset);
        }
    }
}
```


# Appendix