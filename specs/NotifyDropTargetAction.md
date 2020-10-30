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
<!-- TEMPLATE
    Use this section to provide background context for the new API(s)
    in this spec. 

    This section and the appendix are the only sections that likely
    do not get copied into any official documentation, they're just an aid
    to reading this spec. 
    
    If you're modifying an existing API, included a link here to the
    existing page(s) or spec documentation.

    For example, this section is a place to explain why you're adding this
    API rather than modifying an existing API.

    For example, this is a place to provide a brief explanation of some dependent
    area, just explanation enough to understand this new API, rather than telling
    the reader "go read 100 pages of background information posted at ...". 
-->

This API will allow users to drop things such as images, text, and links into the WebView as part of a drag/drop operation.
The reason that we need a separate API for this with composition hosting is because we don't have an HWND to call RegisterDragDrop on.
The hosting app needs to call RegisterDragDrop on the HWND that contains the WebView and implement IDropTarget so it can forward the
calls (IDropTarget::DragEnter, DragMove, DragLeave, and Drop) to the WebView.

Additionally, the hosting app also needs to call into IDropTargetHelper before forwarding those calls to us as documented here:
https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idroptargethelper


# Description
<!-- TEMPLATE
    Use this section to provide a brief description of the feature.

    For an example, see the introduction to the PasswordBox control
    (http://docs.microsoft.com/windows/uwp/design/controls-and-patterns/password-box).
-->

NotifyDropTargetAction is meant to provide a way for composition hosted WebViews to receive drop events as part of a drag/drop operation.
It is the hosting application's responsibility to call RegisterDragDrop (https://docs.microsoft.com/en-us/windows/win32/api/ole2/nf-ole2-registerdragdrop)
on the HWND that contains any composition hosted WebViews and to implement IDropTarget(https://docs.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idroptarget)
to receive the corresponding drop events from Ole32:

IDropTarget::DragEnter
IDropTarget::DragMove
IDropTarget::DragLeave
IDropTarget::Drop

NotifyDropTargetAction consolidates these four functions into one and the COREWEBVIEW2_DROP_TARGET_ACTION enum
specifies which correspondingIDropTarget function was called.


# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.

    The general format is:

    ## FirstFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    ## SecondFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    As an example of this section, see the Examples section for the PasswordBox
    control (https://docs.microsoft.com/windows/uwp/design/controls-and-patterns/password-box#examples). 
-->

```c++
// Initialized elsewhere
wil::com_ptr<ICoreWebView2Controller> webViewController;

webViewCompositionController =
        webViewController.query<ICoreWebView2CompositionController>();

// Implementation for IDropTarget
HRESULT DropTarget::DragEnter(IDataObject * data_object,
    DWORD key_state,
    POINTL cursor_position,
    DWORD* effect)
{
    POINT point = {cursor_position.x, cursor_position.y};
    // Tell the helper that we entered so it can update the drag image and return
    // the allowed effects.
    IDropTargetHelper* drop_helper = DropHelper();
    if (drop_helper) {
        drop_helper->DragEnter(GetHWND(), data_object, &point, *effect);
    }
    // Convert the point to WebView client coordinates from screen coordinates
    // account for any offset.
    ConvertScreenPointToWebView(&point);
    return webViewCompositionController->NotifyDropTargetAction(
        COREWEBVIEW2_DRAG_ENTER, data_object, key_state, point, effect);
}

HRESULT DropTarget::DragOver(DWORD key_state,
    POINTL cursor_position,
    DWORD * effect)
{
    POINT point = {cursor_position.x, cursor_position.y};
    IDropTargetHelper* drop_helper = DropHelper();
    if (drop_helper)
        drop_helper->DragOver(&point, *effect);
    ConvertScreenPointToWebView(&point);
    return webViewCompositionController->NotifyDropTargetAction(
        COREWEBVIEW2_DRAG_OVER, nullptr, key_state, point, effect);
}

HRESULT DropTarget::DragLeave()
{
    IDropTargetHelper* drop_helper = DropHelper();
    if (drop_helper)
        drop_helper->DragLeave();
    return webViewCompositionController->NotifyDropTargetAction(
        COREWEBVIEW2_DRAG_LEAVE, nullptr, 0, {0, 0}, nullptr);
}

HRESULT DropTarget::Drop(IDataObject * data_object,
    DWORD key_state,
    POINTL cursor_position,
    DWORD * effect)
{
    POINT point = {cursor_position.x, cursor_position.y};
    IDropTargetHelper* drop_helper = DropHelper();
    if (drop_helper) {
        drop_helper->Drop(data_object, &point, *effect);
    }
    ConvertScreenPointToWebView(&point);
    return webViewCompositionController->NotifyDropTargetAction(
        COREWEBVIEW2_DROP, data_object, key_state, point, effect);
}
```


# API Details
<!-- TEMPLATE
    The exact API, in IDL format for our COM API and
    in MIDL3 format (https://docs.microsoft.com/en-us/uwp/midl-3/)
    when possible, or in C# if starting with an API sketch for our .NET and WinRT API.

    Include every new or modified type but use // ... to remove any methods,
    properties, or events that are unchanged.

    (GitHub's markdown syntax formatter does not (yet) know about MIDL3, so
    use ```c# instead even when writing MIDL3.)

    Example:
    
    ```
    /// Event args for the NewWindowRequested event. The event is fired when content
    /// inside webview requested to open a new window (through window.open() and so on.)
    [uuid(34acb11c-fc37-4418-9132-f9c21d1eafb9), object, pointer_default(unique)]
    interface ICoreWebView2NewWindowRequestedEventArgs : IUnknown
    {
        // ...

        /// Window features specified by the window.open call.
        /// These features can be considered for positioning and sizing of
        /// new webview windows.
        [propget] HRESULT WindowFeatures([out, retval] ICoreWebView2WindowFeatures** windowFeatures);
    }
    ```

    ```c# (but really MIDL3)
    public class CoreWebView2NewWindowRequestedEventArgs
    {
        // ...

	       public CoreWebView2WindowFeatures WindowFeatures { get; }
    }
    ```
-->

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
/// This function tells allows WebView2 to act as a drop target in composition
/// hosting mode.
///
/// The hosting application needs to register as an IDropTarget and implement
/// all of the functions in IDropTarget: DragEnter, DragOver, DragLeave, and
/// Drop. See:
/// https://docs.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idroptarget
/// In addition, the hosting application needs to create an IDropTargetHelper
/// and call the corresponding functions on that object before forwarding the
/// call to WebView. See:
/// https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idroptargethelper
/// This also allows the hosting application to modify the values of the
/// effect parameter before passing it on to the WebView.
///
/// dropTargetAction is a WebView2 specific enum that should be set to
/// correspond to the IDropTarget function that is currently being called.
/// COREWEBVIEW2_DRAG_ENTER for IDropTarget::DragEnter
/// COREWEBVIEW2_DRAG_OVER for IDropTarget::DragOver
/// COREWEBVIEW2_DRAG_LEAVE for IDropTarget::DragLeave
/// COREWEBVIEW2_DROP for IDropTarget::Drop
///
/// Note that unless COREWEBVIEW2_DRAG_LEAVE is specified for
/// dropTargetAction, effect must be a valid pointer.
///
/// dataObject must also be a valid if COREWEBVIEW2_DRAG_ENTER or
/// COREWEBVIEW2_DROP is specified as the dropTargetAction.
///
/// point parameter must be modified to include the WebView's offset and be in
/// the WebView's client coordinates (Similar to how SendMouseInput works).
HRESULT NotifyDropTargetAction(
    [in] COREWEBVIEW2_DROP_TARGET_ACTION dropTargetAction,
    [in] IDataObject* dataObject,
    [in] DWORD keyState,
    [in] POINT point,
    [out, retval] DWORD* effect);
```


# Appendix
<!-- TEMPLATE
    Anything else that you want to write down for posterity, but
    that isn't necessary to understand the purpose and usage of the API.
    For example, implementation details or links to other resources.
-->

A good resource to read about the whole Ole drag/drop is located here:
https://docs.microsoft.com/en-us/cpp/mfc/drag-and-drop-ole?view=msvc-160#:~:text=You%20select%20the%20data%20from,than%20the%20copy%2Fpaste%20sequence.
