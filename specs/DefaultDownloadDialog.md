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
        BOOL isOpen;
        m_webView2_6->get_IsDefaultDownloadDialogOpen(&isOpen);
        if (isOpen)
        {
            m_webView2_6->CloseDefaultDownloadDialog();
        }
        else
        {
            m_webView2_6->OpenDefaultDownloadDialog();
        }
    }
}

void ViewComponent::SetDefaultDownloadDialogPosition()
{
    COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION targetPosition =
        COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION_TOP_LEFT;
    UINT32 defaultPadding = 20;
    COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING padding = {
        defaultPadding, defaultPadding};
    CHECK_FAILURE(m_webViewStaging6->put_DefaultDownloadDialogPosition(
        targetPosition));
    CHECK_FAILURE(m_webViewStaging6->put_DefaultDownloadDialogPadding(
        padding));
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

private void SetDefaultDownloadDialogPosition()
{
    uint defaultPadding = 20;
    CoreWebView2DefaultDownloadDialogPosition newPosition =
        CoreWebView2DefaultDownloadDialogPosition.TopLeft;
    CoreWebView2DefaultDownloadDialogPadding padding;
    padding.x = defaultPadding;
    padding.y = defaultPadding;
    webView.CoreWebView2.DefaultDownloadDialogPosition = newPosition;
    webView.CoreWebView2.DefaultDownloadDialogPadding = padding;
}
```

# API Details


```c#
[v1_enum]
/// The default download dialog can be aligned to any of the WebView corners
/// by setting the `DefaultDownloadDialogPosition` property. The default
/// position is top-right corner.
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

/// The padding is the distance between the WebView corner specified by the
/// `DefaultDownloadDialogPosition` and the default download dialog corner
/// nearest to it. It is measured in raw pixels or logical pixels, depending on
/// the COREWEBVIEW2_BOUNDS_MODE. Use (0, 0) to align the dialog to the WebView
/// corner with no padding.
typedef struct COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING {

  /// The padding in the x-direction from the `DefaultDownloadDialogPosition`.
  UINT32 x;

  /// The padding in the y-direction from the `DefaultDownloadDialogPosition`.
  UINT32 y;

} COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING;

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

  /// Get the default download dialog position.
  [propget] HRESULT DefaultDownloadDialogPosition(
      [out, retval] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION* position);

  /// Set the default download dialog position relative to the WebView bounds.
  /// The dialog can be positioned against any of the WebView corners (see
  /// COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION). When the WebView or dialog
  /// changes size, the dialog keeps its position relative to the corner. The
  /// dialog may become partially or completely outside of the WebView bounds if
  /// the WebView is small enough. Set the padding from the position with the
  ///  `DefaultDownloadDialogPadding` property.
  ///
  /// \snippet ViewComponent.cpp SetDefaultDownloadDialogPosition
  [propput] HRESULT DefaultDownloadDialogPosition(
      [in] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_POSITION position);

  /// Get the default download dialog padding.
  [propget] HRESULT DefaultDownloadDialogPadding(
      [out, retval] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING* padding);

  /// Set the default download dialog padding from the
  /// `DefaultDownloadDialogPosition`. See
  /// COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING.
  [propput] HRESULT DefaultDownloadDialogPadding(
      [in] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_PADDING padding);
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

    struct CoreWebView2DefaultDownloadDialogPadding
    {
        UInt32 x;
        UInt32 y;
    };

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_6")]
        {
            // ICoreWebView2_6 members
            Boolean IsDefaultDownloadDialogOpen { get; };

            void OpenDefaultDownloadDialog();

            void CloseDefaultDownloadDialog();

            CoreWebView2DefaultDownloadDialogPosition
                DefaultDownloadDialogPosition { get; set; };

            CoreWebView2DefaultDownloadDialogPadding
                DefaultDownloadDialogPadding { get; set; };
        }
    }
}
```


# Appendix