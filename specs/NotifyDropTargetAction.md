<!-- TEMPLATE
  The purpose of this spec is to describe a new WebView2 feature and its APIs.

  There are two audiences for the spec. The first are people
  that want to evaluate and give feedback on the API, as part of
  the submission process. When it's complete
  it will be incorporated into the public documentation at
  docs.microsoft.com (https://docs.microsoft.com/en-us/microsoft-edge/webview2/).
  Hopefully we'll be able to copy it mostly verbatim.
  So the second audience is everyone that reads there to learn how
  and why to use this API. 
-->


# Background
This API will allow users to drop things such as images, text, and links into the WebView as part of a drag/drop operation.
The reason that we need a separate API for this with composition hosting is because we don't have an HWND to call RegisterDragDrop on.
The hosting app needs to call RegisterDragDrop on the HWND that contains the WebView and implement IDropTarget so it can forward the
calls (IDropTarget::DragEnter, DragMove, DragLeave, and Drop) to the WebView.

Additionally, the hosting app also needs to call into IDropTargetHelper before forwarding those calls to us as documented here:
https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idroptargethelper


# Description
NotifyDropTargetAction is meant to provide a way for composition hosted WebViews to receive drop events as part of a drag/drop operation.
It is the hosting application's responsibility to call RegisterDragDrop (https://docs.microsoft.com/en-us/windows/win32/api/ole2/nf-ole2-registerdragdrop)
on the HWND that contains any composition hosted WebViews and to implement IDropTarget(https://docs.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idroptarget)
to receive the corresponding drop events from Ole32:

- IDropTarget::DragEnter
- IDropTarget::DragMove
- IDropTarget::DragLeave
- IDropTarget::Drop

NotifyDropTargetAction consolidates these four functions into one and the COREWEBVIEW2_DROP_TARGET_ACTION enum
specifies which corresponding IDropTarget function was called.


# Examples
## Win32
```c++
// Win32 Sample

// Implementation for IDropTarget
HRESULT DropTarget::DragEnter(IDataObject* dataObject,
    DWORD keyState,
    POINTL point,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y};
    // Tell the helper that we entered so it can update the drag image and get
    // the correct effect.
    wil::com_ptr<IDropTargetHelper> dropHelper = DropHelper();
    if (dropHelper)
    {
        dropHelper->DragEnter(GetHWND(), dataObject, &point, *effect);
    }

    // Convert the screen point to client coordinates add the WebView's offset.
    m_viewComponent->OffsetPointToWebView(&point);
    return m_webViewCompositionController2->DragEnter(
        dataObject, keyState, point, effect);
}

HRESULT DropTarget::DragOver(DWORD keyState,
    POINTL point,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y};
    // Tell the helper that we moved over it so it can update the drag image
    // and get the correct effect.
    wil::com_ptr<IDropTargetHelper> dropHelper = DropHelper();
    if (dropHelper)
    {
        dropHelper->DragOver(&point, *effect);
    }

    // Convert the screen point to client coordinates add the WebView's offset.
    // This returns whether the resultant point is over the WebView visual.
    m_viewComponent->OffsetPointToWebView(&point);
    return m_webViewCompositionController2->DragOver(
        keyState, point, effect);
}

HRESULT DropTarget::DragLeave()
{
    // Tell the helper that we moved out of it so it can update the drag image.
    wil::com_ptr<IDropTargetHelper> dropHelper = DropHelper();
    if (dropHelper)
    {
        dropHelper->DragLeave();
    }

    return m_webViewCompositionController2->DragLeave();
}

HRESULT DropTarget::Drop(IDataObject* dataObject,
    DWORD keyState,
    POINTL point,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y};
    // Tell the helper that we dropped onto it so it can update the drag image
    // and get the correct effect.
    wil::com_ptr<IDropTargetHelper> dropHelper = DropHelper();
    if (dropHelper)
    {
        dropHelper->Drop(dataObject, &point, *effect);
    }

    // Convert the screen point to client coordinates add the WebView's offset.
    // This returns whether the resultant point is over the WebView visual.
    m_viewComponent->OffsetPointToWebView(&point);
    return m_webViewCompositionController2->Drop(
        dataObject, keyState, point, effect);
}
```

## WinRT
```c#
// WinRT Sample
private void WebView_DragEnter(object sender, DragEventArgs e)
{
  uint keyboardState = 
    ConvertDragDropModifiersToWin32KeyboardState(e.Modifiers);
  Point pointerPosition = CoreWindow.GetForCurrentThread().PointerPosition;
  DataPackageOperation operation = 
    (DataPackageOperation)webView2CompositionController.DragEnter(
      e.Data, keyboardState, pointerPosition);
  e.AcceptedOperation = operation;
}

private void WebView_DragOver(object sender, DragEventArgs e)
{
  uint keyboardState =
    ConvertDragDropModifiersToWin32KeyboardState(e.Modifiers);
  Point pointerPosition = CoreWindow.GetForCurrentThread().PointerPosition;
  DataPackageOperation operation = 
    (DataPackageOperation)webView2CompositionController.DragOver(
      keyboardState, pointerPosition);
  e.AcceptedOperation = operation;
}

private void WebView_DragLeave(object sender, DragEventArgs e)
{
  webView2CompositionController.DragLeave();
}

private void WebView_Drop(object sender, DragEventArgs e)
{
  uint keyboardState =
    ConvertDragDropModifiersToWin32KeyboardState(e.Modifiers);
  Point pointerPosition = CoreWindow.GetForCurrentThread().PointerPosition;
  DataPackageOperation operation =
    (DataPackageOperation)webView2CompositionController.Drop(
      e.Data, keyboardState, pointerPosition);
  e.AcceptedOperation = operation;
}

// Win32 keyboard state modifiers that are relevant during drag and drop.
public const uint MK_LBUTTON = 1;
public const uint MK_RBUTTON = 2;
public const uint MK_SHIFT = 4;
public const uint MK_CONTROL = 8;
public const uint MK_MBUTTON = 16;
public const uint MK_ALT = 32;

// Helper function to convert DragDropModifiers to win32 keyboard state
// modifiers that WebView2 uses during drag and drop operation.
private uint ConvertDragDropModifiersToWin32KeyboardState(
  Windows.ApplicationModel.DataTransfer.DragDrop.DragDropModifiers modifiers)
{
  uint win32DragDropModifiers = 0;
  if ((modifiers & DragDropModifiers.Shift) == DragDropModifiers.Shift)
    win32DragDropModifiers |= MK_SHIFT;
  if ((modifiers & DragDropModifiers.Control) == DragDropModifiers.Control)
    win32DragDropModifiers |= MK_CONTROL;
  if ((modifiers & DragDropModifiers.Alt) == DragDropModifiers.Alt)
    win32DragDropModifiers |= MK_ALT;
  if ((modifiers & DragDropModifiers.LeftButton) == DragDropModifiers.LeftButton)
    win32DragDropModifiers |= MK_LBUTTON;
  if ((modifiers & DragDropModifiers.MiddleButton) == DragDropModifiers.MiddleButton)
    win32DragDropModifiers |= MK_MBUTTON;
  if ((modifiers & DragDropModifiers.RightButton) == DragDropModifiers.RightButton)
    win32DragDropModifiers |= MK_RBUTTON;
  return win32DragDropModifiers;
}
```


# API Details
## Win32
```c++
[v1_enum]
typedef enum COREWEBVIEW2_DROP_TARGET_ACTION {
  COREWEBVIEW2_DRAG_ENTER,
  COREWEBVIEW2_DRAG_LEAVE,
  COREWEBVIEW2_DRAG_OVER,
  COREWEBVIEW2_DROP,
} COREWEBVIEW2_DROP_TARGET_ACTION;
```

```c++
interface ICoreWebView2CompositionController2 : ICoreWebView2CompositionController {
  /// This set of APIs (DragEnter, DragLeave, DragOver, and Drop) will allow
  /// users to drop things such as images, text, and links into the WebView as
  /// part of a drag/drop operation. The reason that we need a separate API for
  /// this with composition hosting is because we don't have an HWND to call
  /// RegisterDragDrop on. The hosting app needs to call RegisterDragDrop on the
  /// HWND that contains the WebView and implement IDropTarget so it can forward
  /// the calls (IDropTarget::DragEnter, DragMove, DragLeave, and Drop) to the
  /// WebView.
  ///
  /// This function corresponds to IDropTarget::DragEnter
  ///
  /// The hosting application must register as an IDropTarget and implement
  /// and forward DragEnter calls to this function.
  ///
  /// In addition, the hosting application needs to create an IDropTargetHelper
  /// and call the corresponding IDropTargetHelper::DragEnter function on that
  /// object before forwarding the call to WebView.
  ///
  /// point parameter must be modified to include the WebView's offset and be in
  /// the WebView's client coordinates (Similar to how SendMouseInput works).
  HRESULT DragEnter(
      [in] IDataObject* dataObject,
      [in] DWORD keyState,
      [in] POINT point,
      [out, retval] DWORD* effect);

  /// Please refer to DragEnter for more information on how Drag/Drop works with
  /// WebView2.
  ///
  /// This function corresponds to IDropTarget::DragLeave
  ///
  /// The hosting application must register as an IDropTarget and implement
  /// and forward DragLeave calls to this function.
  ///
  /// In addition, the hosting application needs to create an IDropTargetHelper
  /// and call the corresponding IDropTargetHelper::DragLeave function on that
  /// object before forwarding the call to WebView.
  HRESULT DragLeave();

  /// Please refer to DragEnter for more information on how Drag/Drop works with
  /// WebView2.
  ///
  /// This function corresponds to IDropTarget::DragOver
  ///
  /// The hosting application must register as an IDropTarget and implement
  /// and forward DragOver calls to this function.
  ///
  /// In addition, the hosting application needs to create an IDropTargetHelper
  /// and call the corresponding IDropTargetHelper::DragOver function on that
  /// object before forwarding the call to WebView.
  ///
  /// point parameter must be modified to include the WebView's offset and be in
  /// the WebView's client coordinates (Similar to how SendMouseInput works).
  HRESULT DragOver(
      [in] DWORD keyState,
      [in] POINT point,
      [out, retval] DWORD* effect);

  /// Please refer to DragEnter for more information on how Drag/Drop works with
  /// WebView2.
  ///
  /// This function corresponds to IDropTarget::Drop
  ///
  /// The hosting application must register as an IDropTarget and implement
  /// and forward Drop calls to this function.
  ///
  /// In addition, the hosting application needs to create an IDropTargetHelper
  /// and call the corresponding IDropTargetHelper::Drop function on that
  /// object before forwarding the call to WebView.
  ///
  /// point parameter must be modified to include the WebView's offset and be in
  /// the WebView's client coordinates (Similar to how SendMouseInput works).
  HRESULT Drop(
      [in] IDataObject* dataObject,
      [in] DWORD keyState,
      [in] POINT point,
      [out, retval] DWORD* effect);
}
```

## WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
  public sealed class CoreWebView2CompositionController : CoreWebView2Controller, ICoreWebView2CompositionController2
  {
    uint DragEnter(
        Windows.ApplicationModel.DataTransfer.DataPackage dataObject,
        uint keyState,
        Point point);

    void DragLeave();

    uint DragOver(
        uint keyState,
        Windows.Foundation.Point point);

    uint Drop(
        Windows.ApplicationModel.DataTransfer.DataPackage dataObject,
        uint keyState,
        Windows.Foundation.Point point);
  }
}
```

# Appendix
A good resource to read about the whole Ole drag/drop is located here:
https://docs.microsoft.com/en-us/cpp/mfc/drag-and-drop-ole?view=msvc-160#:~:text=You%20select%20the%20data%20from,than%20the%20copy%2Fpaste%20sequence.
