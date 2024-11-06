DragStarting
===

# Background
The WebView2 team has been asked to provide a way to override the default drag
drop behavior when running in visual hosting mode. This event allows you to know
when a drag is initiated in WebView2 and provides the state necessary to override
the default WebView2 drag operation with your own logic.

## Note about .NET/WinRT projection
The work to project this API to .NET and WinRT are yet to be completed. Overall
usage of this API is expected to be uncommon. There are no known public asks for
this. Further, this API is exposed on the CompositionController which is very
rarely used in .NET apps.

# Examples
## DragStarting
Users can use `add_DragStarting` on the CompositionController to add an event
handler that is invoked when drag is starting. They can use the event args
to start their own drag. Notably the `Deferral` can be used to execute any async
drag logic and call back into the WebView at a later time. The `Handled`
property lets the WebView2 know whether to exercise its own drag logic or not.

## Override drag and drop
```C++
// Using DragStarting to simply make a synchronous DoDragDrop call instead of
// having WebView2 do it.
CHECK_FAILURE(m_compController5->add_DragStarting(
  Callback<ICoreWebView2DragStartingEventHandler>(
      [this](ICoreWebView2CompositionController5* sender,
            ICoreWebView2DragStartingEventArgs* args)
      {
          DWORD allowedEffects = COREWEBVIEW2_DROP_EFFECTS_NONE;
          POINT dragPosition = {0, 0};
          wil::com_ptr<IDataObject> dragData;

          CHECK_FAILURE(args->get_AllowedDropEffects(&allowedEffects));
          CHECK_FAILURE(args->get_Position(&dragPosition));
          CHECK_FAILURE(args->get_Data(&dragData));

          // This member refers to an implementation of IDropSource. It is an
          // OLE interface that is necessary to initiate drag in an application.
          // https://learn.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idropsource
          if (!m_dropSource)
          {
              m_dropSource = Make<ScenarioDragDropOverrideDropSource>();
          }

          HRESULT hr = DoDragDrop(
              dragData.get(), m_dropSource.get(), allowedEffects, &effect);

          args->put_Handled(SUCCEEDED(hr));

          return hr;
      })
      .Get(),
  &m_dragStartingToken));
```

## Disable drag and drop
```C++
// Using DragStarting to no-op a drag operation.
CHECK_FAILURE(m_compController5->add_DragStarting(
  Callback<ICoreWebView2DragStartingEventHandler>(
      [this](ICoreWebView2CompositionController5* sender,
            ICoreWebView2DragStartingEventArgs* args)
      {
        // If the event is marked handled, WebView2 will not execute its
        // drag logic.
        args->put_Handled(TRUE);
        return S_OK;
      })
      .Get(),
  &m_dragStartingToken));
```

# API Details
```C++
/// DWORD constants that represent the effects that a given WebView2 drag drop
/// operation can have. The values of this enum align with the
/// [OLE DROPEFFECT constant](https://learn.microsoft.com/en-us/windows/win32/com/dropeffect-constants)
/// with the exception of DROPEFFECT_SCROLL which is unused in WebView2 drag
/// drop scenarios.
const DWORD COREWEBVIEW2_DROP_EFFECTS_NONE = 0;
const DWORD COREWEBVIEW2_DROP_EFFECTS_COPY = 1;
const DWORD COREWEBVIEW2_DROP_EFFECTS_MOVE = 2;
const DWORD COREWEBVIEW2_DROP_EFFECTS_LINK = 4;

/// Event args for the `DragStarting` event.
[uuid(edb6b243-334f-59d0-b3b3-de87dd401adc), object, pointer_default(unique)]
interface ICoreWebView2DragStartingEventArgs : IUnknown {
  /// The operations this drag data supports.
  [propget] HRESULT AllowedDropEffects(
      [out, retval] COREWEBVIEW2_DROP_EFFECTS* value);


  /// The data being dragged.
  [propget] HRESULT Data([out, retval] IDataObject** value);

  /// The position at which drag was detected given in WebView2 relative
  /// coordinates.
  [propget] HRESULT Position([out, retval] POINT* value);


  /// Gets the `Handled` property.
  [propget] HRESULT Handled([out, retval] BOOL* value);


  /// Indicates whether this event has been handled by the app.  If the
  /// app handles this event, WebView2 will not initiate drag drop.  If
  /// the app does not handle the event, WebView2 will initiate its own
  /// drag drop logic. The default value is FALSE.
  [propput] HRESULT Handled([in] BOOL value);



  /// Returns an `ICoreWebView2Deferral` object. Use this operation to complete
  /// the CoreWebView2DragStartingEventArgs.
  ///
  /// Until the deferral is completed, subsequent attempts to initiate drag
  /// in the WebView2 will fail and if the cursor was changed as part of
  /// drag it will not restore.
  HRESULT GetDeferral(
      [out, retval] ICoreWebView2Deferral** value);


}

/// Receives `DragStarting` events.
[uuid(3b149321-83c3-5d1f-b03f-a42899bc1c15), object, pointer_default(unique)]
interface ICoreWebView2DragStartingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2CompositionController5* sender,
      [in] ICoreWebView2DragStartingEventArgs* args);
}

/// A continuation of the ICoreWebView2CompositionController4 interface.
/// This interface includes an API which exposes the DragStarting event.
[uuid(975d6824-6a02-5e98-ab7c-e4679d5357f4), object, pointer_default(unique)]
interface ICoreWebView2CompositionController5 : IUnknown {
  /// Adds an event handler for the `DragStarting` event.  `DragStarting` is
  /// a deferrable event that is raised when the WebView2 detects a drag started
  /// within the WebView2.
  /// WebView2's default drag behavior is to synchronously call DoDragDrop when
  /// it detects drag. This event's args expose the data WebView2 uses to call
  /// DoDragDrop to allow users to implement their own drag logic and override
  /// WebView2's.
  /// Handlers of this event must set the `Handled` event to true in order to
  /// override WebView2's default logic. When invoking drag logic asynchronously
  /// using a deferral, handlers must take care to follow these steps in order:
  ///   * Invoke asynchronous drag logic
  ///   * Set the event args `Handled` property true
  ///   * Complete the deferral
  /// In the asynchronous case, WebView2 decides whether or not to invoke its
  /// default drag logic when the deferral completes. So the event args'
  /// `Handled` property must be true when the deferral is completed.
  HRESULT add_DragStarting(
      [in] ICoreWebView2DragStartingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DragStarting`.
  HRESULT remove_DragStarting(
      [in] EventRegistrationToken token);


}

/// Interop interface for the CoreWebView2CompositionController WinRT object to
/// allow WinRT end developers to be able to access the COM interface arguments.
/// This interface is implemented by the
/// Microsoft.Web.WebView2.Core.CoreWebView2CompositionController runtime class.
[uuid(7a4daef9-1701-463f-992d-2136460cf76e), object, pointer_default(unique)]
interface ICoreWebView2CompositionControllerInterop3 : ICoreWebView2CompositionControllerInterop2 {
  /// Adds an event handler for the `DragStarting` event.  `DragStarting` is
  /// raised when the WebView2 detects a drag started within the WebView2.
  /// This event can be used to override WebView2's default drag starting
  /// logic.
  HRESULT add_DragStarting(
      [in] ICoreWebView2DragStartingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DragStarting`.
  HRESULT remove_DragStarting(
      [in] EventRegistrationToken token);


}
```
