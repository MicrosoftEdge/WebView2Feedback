DragStarting
===

# Background
The WebView2 team has been asked to provide a way to override the default drag drop behavior when running in visual hosting mode. This event allows you to know when a drag is initiated in WebView2 and provides the state necessary to override the default WebView2 drag operation with your own logic.

# Examples
## DragStarting
Users can use `add_DragStarting` on the CompositionController to add an event handler
that is invoked when drag is starting. They can use the event args to start their own
drag or they can just set `Handled` to `FALSE` to ignore the drag.

```C++
CHECK_FAILURE(m_compControllerStaging->add_DragStarting(
  Callback<ICoreWebView2StagingDragStartingEventHandler>(
      [this](ICoreWebView2CompositionController* sender, ICoreWebView2StagingDragStartingEventArgs* args)
      {
          if (m_dragOverrideMode != DragOverrideMode::OVERRIDE)
          {
              // If the event is marked handled, WebView2 will not execute its drag logic.
              args->put_Handled(m_dragOverrideMode == DragOverrideMode::NOOP);
              return S_OK;
          }

          COREWEBVIEW2_DRAG_EFFECTS allowedEffects;
          POINT dragPosition;
          wil::com_ptr<IDataObject> dragData;
          wil::com_ptr<ICoreWebView2Deferral> deferral;

          args->get_DragAllowedOperations(&allowedEffects);
          args->get_DragPosition(&dragPosition);
          args->get_DragData(&dragData);
          args->GetDeferral(&deferral);

          HRESULT hr = S_OK;
          if (!m_oleInitialized)
          {
              hr = OleInitialize(nullptr);
              if (SUCCEEDED(hr))
              {
                  m_oleInitialized = true;
              }
          }

          if (!m_dropSource)
          {
              m_dropSource = Make<ScenarioDragDropOverrideDropSource>();
          }

          if (SUCCEEDED(hr))
          {
              DWORD effect;
              DWORD okEffects = DROPEFFECT_NONE;
              if (allowedEffects & COREWEBVIEW2_DRAG_EFFECTS_COPY)
              {
                  okEffects |= DROPEFFECT_COPY;
              }
              if (allowedEffects & COREWEBVIEW2_DRAG_EFFECTS_MOVE)
              {
                  okEffects |= DROPEFFECT_MOVE;
              }
              if (allowedEffects & COREWEBVIEW2_DRAG_EFFECTS_LINK)
              {
                  okEffects |= DROPEFFECT_LINK;
              }

              hr = DoDragDrop(dragData.get(), m_dropSource.get(), okEffects, &effect);
          }

          deferral->Complete();
          args->put_Handled(TRUE);

          return hr;
      })
      .Get(),
  &m_dragStartingToken));
```

# API Details
```C++
/// Flags enum that represents the effects that a given WebView2 drag drop operation can have.
[v1_enum]
typedef enum COREWEBVIEW2_DRAG_EFFECTS {
  /// Drag operation supports no effect.
  COREWEBVIEW2_DRAG_EFFECTS_NONE = 0x0,
  /// Drag operation supports copying data.
  COREWEBVIEW2_DRAG_EFFECTS_COPY = 0x1,
  /// Drag operation supports moving data.
  COREWEBVIEW2_DRAG_EFFECTS_MOVE = 0x2,
  /// Drag operation supports linking data.
  COREWEBVIEW2_DRAG_EFFECTS_LINK = 0x4,
} COREWEBVIEW2_DRAG_EFFECTS;
cpp_quote("DEFINE_ENUM_FLAG_OPERATORS(COREWEBVIEW2_DRAG_EFFECTS)")

/// Event args for the `DragStarting` event.
[uuid(edb6b243-334f-59d0-b3b3-de87dd401adc), object, pointer_default(unique)]
interface ICoreWebView2StagingDragStartingEventArgs : IUnknown {
  /// The operations this drag data supports.
  [propget] HRESULT DragAllowedOperations([out, retval] COREWEBVIEW2_DRAG_EFFECTS* value);


  /// The data being dragged.
  [propget] HRESULT DragData([out, retval] IDataObject** value);

  /// The position at which drag was detected.
  [propget] HRESULT DragPosition([out, retval] POINT* value);


  /// Gets the `Handled` property.
  [propget] HRESULT Handled([out, retval] BOOL* value);


  /// Indicates whether this event has been handled by the app.  If the
  /// app handles this event, WebView2 will not initiate drag drop.  If
  /// the app does not handle the event, WebView2 will initiate its own
  /// drag drop logic.
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
interface ICoreWebView2StagingDragStartingEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2CompositionController* sender,
      [in] ICoreWebView2StagingDragStartingEventArgs* args);
}

/// A continuation of the ICoreWebView2CompositionController4 interface.
/// This interface includes an API which exposes the DragStarting event.
[uuid(975d6824-6a02-5e98-ab7c-e4679d5357f4), object, pointer_default(unique)]
interface ICoreWebView2StagingCompositionController : IUnknown {
  /// Adds an event handler for the `DragStarting` event.
  /// Adds an event handler for the `DragStarting` event.  `DragStarting` is
  /// raised when the WebView2 detects a drag started within the WebView2.
  /// This event can be used to override WebView2's default drag starting
  /// logic.
  HRESULT add_DragStarting(
      [in] ICoreWebView2StagingDragStartingEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DragStarting`.
  HRESULT remove_DragStarting(
      [in] EventRegistrationToken token);


}
```
```c# (but really MIDL3)
    runtimeclass CoreWebView2DragStartingEventArgs
    {

        Windows.ApplicationModel.DataTransfer.DataPackageOperation DragAllowedOperations { get; };

        Windows.ApplicationModel.DataTransfer.DataPackage DragData { get; };

        Windows.Foundation.Point DragPosition { get; };

        Boolean Handled { get; set; };


        Windows.Foundation.Deferral GetDeferral();



    }

    runtimeclass CoreWebView2CompositionController : CoreWebView2Controller
    {
      // ...
      [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingCompositionController")]
      {

          event Windows.Foundation.TypedEventHandler<CoreWebView2CompositionController, CoreWebView2DragStartingEventArgs> DragStarting;



      }
      // ...
    }
```
