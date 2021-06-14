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
These APIs will allow users to drop things such as images, text, and links into the WebView as part of a drag/drop operation.
The reason that we need separate APIs for this with composition hosting is because we don't have an HWND to call RegisterDragDrop on.
The hosting app needs to call RegisterDragDrop on the HWND that contains the WebView and implement IDropTarget so it can forward the
calls (IDropTarget::DragEnter, DragMove, DragLeave, and Drop) to the WebView. Other UI frameworks have their own ways to register.
For example, Xaml require setting event handler for DragEnter, DragOver, DragLeave, and Drop on the corresponding UIElement.

For API reviewers, We want a unified API surface between COM and WinRT that works in both UWP and Win32.

We could:
1. Have one API focusing on Win32 types and require the end dev to convert from UWP types to Win32 (which we've done).
2. Have one API focusing on UWP types and require the end dev to convert Win32 to UWP.
3. Have two sets of methods one for Win32 and one for UWP types.
Or we could do (1) or (2) and provide a conversion function.
Because the conversion is simple and we have a large Win32 user base we chose (1) and provided a conversion function.


# Description
DragEnter, DragOver, DragLeave, and Drop are functions meant to provide a way for composition hosted WebViews to receive drop events as part of a drag/drop operation.
For win32, it is the hosting application's responsibility to call [RegisterDragDrop](https://docs.microsoft.com/en-us/windows/win32/api/ole2/nf-ole2-registerdragdrop)
on the HWND that contains any composition hosted WebViews and to implement [IDropTarget](https://docs.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idroptarget)
to receive the corresponding drop events from Ole32:

- IDropTarget::DragEnter
- IDropTarget::DragMove
- IDropTarget::DragLeave
- IDropTarget::Drop

The HWND doesn't have to be the immediate parent of the WebView2 but it does have to convert the POINTL argument in the above functions from screen coordinates to client coordinates of the WebView2.

For WinRT, it is the hosting applications responsibility to register as a drop target via [CoreDragDropManager](https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.datatransfer.dragdrop.core.coredragdropmanager)
on CoreDragDropManager.TargetRequested and to call [CoreDropOperationTargetRequestedEventArgs.SetTarget(ICoreDropOperationTarget)](https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.datatransfer.dragdrop.core.coredropoperationtargetrequestedeventargs)
on an implementation of [ICoreDropOperationTarget](https://docs.microsoft.com/en-us/uwp/api/Windows.ApplicationModel.DataTransfer.DragDrop.Core.ICoreDropOperationTarget).

# Examples
## Win32
```c++
// Win32 Sample

// Implementation for IDropTarget
HRESULT DropTarget::DragEnter(IDataObject* dataObject,
    DWORD keyState,
    POINTL cursorPosition,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y };

    // Convert the screen point to client coordinates add the WebView's offset.
    m_viewComponent->OffsetPointToWebView(&point);
    return m_webViewCompositionController2->DragEnter(
        dataObject, keyState, point, effect);
}

HRESULT DropTarget::DragOver(DWORD keyState,
    POINTL cursorPosition,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y };

    // Convert the screen point to client coordinates add the WebView's offset.
    // This returns whether the resultant point is over the WebView visual.
    m_viewComponent->OffsetPointToWebView(&point);
    return m_webViewCompositionController2->DragOver(
        keyState, point, effect);
}

HRESULT DropTarget::DragLeave()
{
    return m_webViewCompositionController2->DragLeave();
}

HRESULT DropTarget::Drop(IDataObject* dataObject,
    DWORD keyState,
    POINTL cursorPosition,
    DWORD* effect)
{
    POINT point = { cursorPosition.x, cursorPosition.y };

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
IAsyncOperation<DataPackageOperation> ICoreDropOperationTarget.EnterAsync(CoreDragInfo dragInfo, CoreDragUIOverride dragUIOverride)
{
    return compositionController.DragEnter(dragInfo, dragUIOverride);
}

IAsyncOperation<DataPackageOperation> ICoreDropOperationTarget.OverAsync(CoreDragInfo dragInfo, CoreDragUIOverride dragUIOverride)
{
    return compositionController.DragOver(dragInfo, dragUIOverride);
}

IAsyncAction ICoreDropOperationTarget.LeaveAsync(CoreDragInfo dragInfo)
{
    return compositionController.DragLeave(dragInfo);
}

IAsyncOperation<DataPackageOperation> ICoreDropOperationTarget.DropAsync(CoreDragInfo dragInfo)
{
    return compositionController.Drop(dragInfo);
}
```


# API Details
## Win32
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
    // New APIs
    Windows.ApplicationModel.DataTransfer.DataPackageOperation DragEnter(
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragInfo dragInfo,
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragUIOverride dragUIOverride);

    Windows.ApplicationModel.DataTransfer.DataPackageOperation DragLeave(
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragInfo dragInfo);

    Windows.ApplicationModel.DataTransfer.DataPackageOperation DragOver(
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragInfo dragInfo,
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragUIOverride dragUIOverride);

    Windows.ApplicationModel.DataTransfer.DataPackageOperation Drop(
        Windows.ApplicationModel.DataTransfer.DragDrop.Core.CoreDragInfo dragInfo);
  }
}
```

# Appendix
A good resource to read about the whole Ole drag/drop is located here:
[OLE Drag and Drop](https://docs.microsoft.com/en-us/cpp/mfc/drag-and-drop-ole?view=msvc-160)
