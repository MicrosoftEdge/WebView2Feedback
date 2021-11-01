Default Download Dialog Positioning & Anchoring
===

# Background
This API gives you the ability to change the position of the default download dialog
relative to the webview window, programmatically open and close the dialog, and
make changes in response to the dialog opening or closing.

You can anchor the default download dialog to a button in your application by setting its
position below your button, and alternating open and close calls when the button is
clicked on.

For more complex customizations, you can use the Download APIs -
[DownloadStarting](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2downloadstartingeventargs?view=webview2-1.0.961.33)
 and [DownloadOperation](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2downloadoperation?view=webview2-1.0.961.33) - to build custom download UI.

# Examples
```cpp
void ViewComponent::CreateDownloadsButton()
{
    CreateDownloadsToggleButton(m_downloadsButtonMargin, m_downloadsButtonWidth,
        m_downloadsButtonHeight);

    // Subscribe to the `IsDefaultDownloadDialogOpenChanged` event
    // to make changes in response to the default download dialog
    // opening or closing. For example, if the dialog is anchored
    // to a button in the application, the button can change its appearance
    // depending on whether the dialog is opened or closed.
    CHECK_FAILURE(m_webView2_6->add_IsDefaultDownloadDialogOpenChanged(
        Callback<ICoreWebView2IsDefaultDownloadDialogOpenChangedEventHandler>(
            [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            BOOL isOpen;
            m_webView2_6->get_IsDefaultDownloadDialogOpen(&isOpen);
            // Update the "Show downloads" button state to match the dialog:
            // The button shows as pressed when the dialog is open.
            ShowDownloadsToggleButton().IsChecked(isOpen);
            return S_OK;
            })
            .Get(),
        &m_isDefaultDownloadDialogOpenChangedToken));
}

void ViewComponent::ShowDownloadsToggleButton_OnToggle()
{
    if (ShowDownloadsToggleButton().IsChecked().Value())
    {
        m_webview2_6->OpenDefaultDownloadDialog();
    }
    else
    {
        m_webview2_6->CloseDefaultDownloadDialog();
    }
}

void ViewComponent::SetDefaultDownloadDialogPosition()
{
    COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT cornerAlignment =
        COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT_TOP_LEFT;
    const int defaultMargin = 20;
    POINT margin = {defaultMargin, defaultMargin};
    CHECK_FAILURE(m_webView2_6->put_DefaultDownloadDialogCornerAlignment(
        cornerAlignment));
    CHECK_FAILURE(m_webView2_6->put_DefaultDownloadDialogMargin(margin));
}
```

```c#
void CreateDownloadsButtonCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    Button downloadsButton = new Button();
    downloadsButton.Content = "Downloads";
    downloadsButton.Click += new RoutedEventHandler(ToggleDownloadDialog);
    DockPanel.SetDock(downloadsButton, Dock.Left);
    dockPanel.Children.Insert(downloadsButton);

    // Subscribe to the `IsDefaultDownloadDialogOpenChanged` event
    // to make changes in response to the default download dialog
    // opening or closing. For example, if the dialog is anchored to
    // a button in the application, the button appearance can change
    // depending on whether the dialog is opened or closed.
    webView.CoreWebView2.IsDefaultDownloadDialogOpenChanged +=
        (sender, args) =>
    {
        if (webView.CoreWebView2.IsDefaultDownloadDialogOpen)
        {
            downloadsButton.Background = new SolidColorBrush(Colors.LightBlue);
        }
        else
        {
            downloadsButton.Background = new SolidColorBrush(Colors.AliceBlue);
        }
    };
}

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
    const int defaultMargin = 20;
    CoreWebView2DefaultDownloadDialogCornerAlignment cornerAlignment
        = CoreWebView2DefaultDownloadDialogCornerAlignment.TopLeft;
    System.Drawing.Point margin = new System.Drawing.Point(
        defaultMargin, defaultMargin);
    webView.CoreWebView2.DefaultDownloadDialogCornerAlignment =
        cornerAlignment;
    webView.CoreWebView2.DefaultDownloadDialogMargin = margin;
}
```

# API Details


```c#
[v1_enum]
/// The default download dialog can be aligned to any of the WebView corners
/// by setting the `DefaultDownloadDialogCornerAlignment` property. The default
/// position is top-right corner.
typedef enum COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT {

  /// Top-left corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT_TOP_LEFT,

  /// Top-right corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT_TOP_RIGHT,

  /// Bottom-left corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT_BOTTOM_LEFT,

  /// Bottom-right corner of the WebView.
  COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT_BOTTOM_RIGHT,

} COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT;

[uuid(9139c04d-8f37-42ae-8b63-01940c34d22f), object, pointer_default(unique)]
interface ICoreWebView2_6 : ICoreWebView2_5
{
  /// Raised when the `IsDefaultDownloadDialogOpen` property changes. This event
  /// comes after the `DownloadStarting` event. Setting the `Handled` property
  /// on the `DownloadStartingEventArgs` disables the default download dialog
  /// and ensures that this event is never raised.
  HRESULT add_IsDefaultDownloadDialogOpenChanged(
      [in] ICoreWebView2IsDefaultDownloadDialogOpenChangedEventHandler*
          handler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with
  /// `add_IsDefaultDownloadDialogOpenChanged`.
  HRESULT remove_IsDefaultDownloadDialogOpenChanged(
      [in] EventRegistrationToken token);

  /// `TRUE` if the default download dialog is currently open. The value of this
  /// property changes only when the default download dialog is explicitly
  /// opened or closed. Hiding the WebView implicitly hides the dialog, but does
  /// not change the value of this property.
  [propget] HRESULT IsDefaultDownloadDialogOpen([out, retval] BOOL* value);

  /// Open the default download dialog. If the dialog is opened before there
  /// are recent downloads, the dialog shows all past downloads for the
  /// current profile. Otherwise, the dialog shows only the recent downloads
  /// with a "See more" button for past downloads. Calling this method raises
  /// the `IsDefaultDownloadDialogOpenChanged` event if the dialog was closed.
  /// No effect if the dialog is already open.
  ///
  /// \snippet ViewComponent.cpp ToggleDefaultDownloadDialog
  HRESULT OpenDefaultDownloadDialog();

  /// Close the default download dialog. Calling this method raises the
  /// `IsDefaultDownloadDialogOpenChanged` event if the dialog was open. No
  /// effect if the dialog is already closed.
  HRESULT CloseDefaultDownloadDialog();

  /// Get the default download dialog corner alignment.
  [propget] HRESULT DefaultDownloadDialogCornerAlignment(
      [out, retval] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT* value);

  /// Set the default download dialog corner alignment. The dialog can be
  /// aligned to any of the WebView corners (see
  /// COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT). When the WebView
  /// or dialog changes size, the dialog keeps its position relative to the
  /// corner. The dialog may become partially or completely outside of the
  /// WebView bounds if the WebView is small enough. Set the margin relative to
  /// the corner with the `DefaultDownloadDialogMargin` property.
  ///
  /// \snippet ViewComponent.cpp SetDefaultDownloadDialogPosition
  [propput] HRESULT DefaultDownloadDialogCornerAlignment(
      [in] COREWEBVIEW2_DEFAULT_DOWNLOAD_DIALOG_CORNER_ALIGNMENT value);

  /// Get the default download dialog margin.
  [propget] HRESULT DefaultDownloadDialogMargin([out, retval] POINT* value);

  /// Set the default download dialog margin relative to the WebView corner
  /// specified by `DefaultDownloadDialogCornerAlignment`. The margin is a
  /// point that describes the vertical and horizontal distances between the
  /// chosen WebView corner and the default download dialog corner nearest to
  /// it. Positive values move the dialog towards the center of the WebView from
  /// the chosen WebView corner, and negative values move the dialog away from
  /// it. Use (0, 0) to align the dialog to the WebView corner with no margin.
  [propput] HRESULT DefaultDownloadDialogMargin([in] POINT value);
}

/// Implements the interface to receive `IsDefaultDownloadDialogOpenChanged`
/// events.
[uuid(3117da26-ae13-438d-bd46-edbeb2c4ce81), object, pointer_default(unique)]
interface ICoreWebView2IsDefaultDownloadDialogOpenChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event. No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] IUnknown* args);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2;

    enum CoreWebView2DefaultDownloadDialogCornerAlignment
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

            event Windows.Foundation.TypedEventHandler<CoreWebView2, Object>
                IsDefaultDownloadDialogOpenChanged;

            void OpenDefaultDownloadDialog();

            void CloseDefaultDownloadDialog();

            CoreWebView2DefaultDownloadDialogCornerAlignment
                DefaultDownloadDialogCornerAlignment { get; set; };

            Windows.Foundation.Point DefaultDownloadDialogMargin { get; set; };
        }
    }
}
```


# Appendix