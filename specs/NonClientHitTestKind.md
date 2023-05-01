Hit Test Kind
===

# Background
The ability to ask WebView2 for information on a hit test is an important feature for 
visually hosted apps. It can be used to support features related to mouse activity in 
regions that are traditionally Non-Client areas. Features like Draggable Regions, 
Resize, Minimize/Maximize functionality, and more.


# Examples
## Draggable regions (HWND)
Draggable regions are marked regions on a webpage that will move the app window when the 
user clicks and drags on them. It also opens up the system menu if right-clicked. This 
API is designed to provide draggable regions support for apps that are directly hosting 
the CoreWebView2 via visual hosting and for UI framework WebView2 controls that use visual 
hosting, like the WinUI2 and WinUI3 WebView2 control.If your app uses windowed hosting, 
draggable regions are supported by default, no need to follow this guide.

NOTE: This API is not currently supported for environments that use a CoreWindow like UWP.

#### Win32 C++
```cpp
LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
....
    // We need to forward relevant mouse messages to the webview

    // handle the range of mouse messages & WM_NCRBUTTONDOWN
    if (message == WM_NCRBUTTONDOWN || message == WM_NCRBUTTONUP) 
    {
        POINT point {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        // WM_NCRBUTTONDOWN/UP have poitns in screen coordinates we need
        // to convert the point to client coordinates to match the others
        ScreenToClient(hwnd, &point);
        
        // IsPointInWebview is an example of a function which your app can implement that checks if 
        // the mouse message point lies inside the rect of the visual that hosts the WebView2
        if (IsPointInWebView(point)) 
        {
            // Adjust the point from app client coordinates to webview client coordinates.
            // m_webViewBounds is a rect that represents the bounds that you app has set for 
            // the webveiw
            point.x -= m_webViewBounds.left;
            point.y -= m_webViewBounds.top;

            // forward mouse messages to WebView2
            CHECK_FAILURE(m_compositionController->SendMouseInput(
                static_cast<COREWEBVIEW2_MOUSE_EVENT_KIND>(message),
                static_cast<COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS>(GET_KEYSTATE_WPARAM(wParam)),
                0, point));
            return 0;
        }
        
    }

    switch(message) 
    {
        ....
        // Handling this message is important for enabling dragging
        case WM_NCHITTEST:
            POINT point {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
            COREWEBVIEW2_NON_CLIENT_REGION_KIND result = COREWEBVIEW2_NON_CLIENT_REGION_KIND_NOWHERE;
            CHECK_FAILURE(m_compositionController->GetNonClientRegionAtPoint(&point, &result));
            return result;
        ....
    }
....
}
```
#### C#
```c#
protected override void WndProc(ref Message m)
{
....

if (m.Msg == WM_NCHITTEST)
{
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));
    if (m_compositionController.GetNonClientRegionAtPoint(point) == 
        CoreWebView2NonClientRegionKind.Caption) 
    {
        m.Result = (IntPtr)HTCAPTION;
    }
}
else if (m.msg == WM_NCRBUTTONDOWN || m.msg == WM_NCRBUTTONUP) 
{
  
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));

    // WM_NCRBUTTONDOWN/UP have poitns in screen coordinates we need
    // to convert the point to client coordinates to match the others
    ScreenToClient(m.hwnd, ref point);


    // IsPointInWebview is an example of a function which your app can implement that 
    // checks if the mouse message point lies inside the rect of the visual that hosts
    // the WebView.
    if (IsPointInWebView(point)) 
    {
        // Adjust the point from app client coordinates to webview client coordinates.
        // m_webViewBounds is a rect that represents the bounds that you app has set for 
        // the webveiw
        point.x -= m_webViewBounds.left;
        point.y -= m_webViewBounds.top;
        
        // forward mouse messages to WebView2
        m_compositionController.SendMouseInput(
            (CoreWebView2MouseEventKind)m.msg,
            (CoreWebView2MouseEventVirtualKeys)GET_KEYSTATE_WPARAM(wParam),
            0,
            point);

        m.Result = 0
        return;
    }
        
}
// The following code forwards mouse messages to the WebView2 - Start
    ....
}
```
#### C#/WinRT

```c#
void DraggableRegionSample() {

    m_compositionController.NonClientRegionChanged += (object sender, CoreWebView2NonClientRegionChangedEventArgs arg) => {
        CoreWebView2NonClientRegionKind kind = arg.Region;
        CoreWebView2RegionRectCollection region_rects = m_compositionController.QueryNonClientRegion(kind);
        // use kind & region_rects to ConfigureRegion on the InputNonClientPointerSource
    }

}
```
# API Notes
## Marking regions In Your App
Draggable regions in WebView2 are HTML elements marked with the CSS style
`-webkit-app-region: drag`. WebView2 will treat any element with this style as a 
drag handle for the window.

See Documentation [here](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps-chromium/how-to/window-controls-overlay#make-regions-of-your-app-drag-handlers-for-the-window)

# API Details
## Win32 C++
```cpp
/// This enum contains values representing possible regions a given
/// point lies within
typedef enum COREWEBVIEW2_NON_CLIENT_REGION_KIND {
    /// A hit test region in the WebView2 which has the CSS style 
    /// `-webkit-app-region: drag` set. Web content should use this CSS 
    /// style to identify regions that should be treated like the app 
    /// window's title bar. This has the same value as the Win32 HTCAPTION 
    /// constant. 
    COREWEBVIEW2_NON_CLIENT_REGION_KIND_CAPTION = 2,
    /// A hit test region in the WebView2 which does not have the CSS style 
    /// `-webkit-app-region: drag` set. This is normal web content that should not be 
    /// considered part of the app window's title bar. This has the same value 
    /// as the Win32 HTCLIENT constant.
    COREWEBVIEW2_NON_CLIENT_REGION_KIND_CLIENT = 1,
    /// A hit test region out of bounds of the WebView2.
    /// This has the same value as the Win32 HTNOWHERE
    COREWEBVIEW2_NON_CLIENT_REGION_KIND_NOWHERE = 0
} COREWEBVIEW2_NON_CLIENT_REGION_KIND;

[uuid(0BEA1283-39DC-48D1-9893-16275505CBBC), object, pointer_default(unique)]
interface ICoreWebView2NonClientRegionChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2NonClientRegionChangedEventArgs* args);
}

/// Interface for status bar text change event args
[uuid(E404B00C-669E-43EC-BE43-FB8CD7DBB480), object, pointer_default(unique)]
interface ICoreWebView2NonClientRegionChangedEventArgs : IUnknown {
    [propget] HRESULT Region(
                    [out, retval] COREWEBVIEW2_NON_CLIENT_REGION_KIND* value);
}

[uuid(A990DA9D-4243-4FCD-B895-2E7E87EAAB14), object, pointer_default(unique)]
interface ICoreWebView2RegionRectCollection : IUnknown {
  /// Gets the number of `RegionRect` objects contained in the `RegionRectCollection`.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the `RegionRect` at the specified index.
  HRESULT GetValueAtIndex([in] UINT32 index,
      [out, retval] RECT* value);

}

/// This interface includes the new API for enabling WebView2 support for hit-testing regions
[uuid(42BF7BA5-917A-4C27-ADA1-EA6969854C16), object, pointer_default(unique)]
interface ICoreWebView2StagingCompositionController4 : ICoreWebView2CompositionController3 {
  /// If you are hosting a WebView2 using CoreWebView2CompositionController, you can call
  /// this method in your Win32 WndProc to determine if the mouse is moving over or
  /// clicking on WebView2 web content that should be considered part of the app window's
  /// title bar.

  /// The point parameter is expected to be in the client coordinate space of WebView2.
  /// The method sets the out parameter value as follows:
  ///     - COREWEBVIEW2_NON_CLIENT_REGION_KIND_CAPTION when point corresponds to
  ///         a region (HTML element) within the WebView2 with
  ///         `-webkit-app-region: drag` CSS style set
  ///     - COREWEBVIEW2_NON_CLIENT_REGION_KIND_CLIENT when point corresponds to
  ///         a region (HTML element) within the WebView2 without
  ///         `-webkit-app-region: drag` CSS style set
  ///     - COREWEBVIEW2_NON_CLIENT_REGION_KIND_NOWHERE when point is not within the WebView2
  HRESULT GetNonClientRegionAtPoint(
                      [in] POINT point,
                      [out, retval] COREWEBVIEW2_NON_CLIENT_REGION_KIND* value);

  HRESULT QueryNonClientRegion(
    [in] COREWEBVIEW2_NON_CLIENT_REGION_KIND kind,
    [out, retval] ICoreWebView2RegionRectCollection** rects);

  /// Use to add a listener to be notified when NonClientRegion change
  HRESULT add_NonClientRegionChanged(
      [in] ICoreWebView2StagingNonClientRegionChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removing an event handler for `NonClientRegionChanged` event
  HRESULT remove_NonClientRegionChanged(
      [in] EventRegistrationToken token);
}

/// Mouse event type used by SendMouseInput to convey the type of mouse event
/// being sent to WebView. The values of this enum align with the matching
/// WM_* window messages.
typedef enum COREWEBVIEW2_MOUSE_EVENT_KIND {
    ....
    /// Mouse Right Button Down event over a nonclient area, WM_NCRBUTTONDOWN.
    COREWEBVIEW2_MOUSE_EVENT_KIND_NON_CLIENT_RIGHT_BUTTON_DOWN = 0x00A4,
    /// Mouse Right Button up event over a nonclient area, WM_NCRBUTTONUP.
    COREWEBVIEW2_MOUSE_EVENT_KIND_NON_CLIENT_RIGHT_BUTTON_UP = 0x00A5,
    ....
} COREWEBVIEW2_MOUSE_EVENT_KIND;
```
## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core {
    enum CoreWebView2NonClientRegionKind
    {
        Caption = 2,
        Client = 1,
        Nowhere = 0,
    }
    enum CoreWebView2MouseEventKind
    {
        ...
        NonClientRightButtonDown = 0x00A4,
        NonClientRightButtonUp = 0x00A5,
        ...
    }
    runtimeclass CoreWebView2NonClientRegionChangedEventArgs
    {
        // ICoreWebView2NonClientRegionChangedEventArgs members
        CoreWebView2NonClientRegionKind Region { get; };

    }
    runtimeclass CoreWebView2RegionRectCollection
    {
        // ICoreWebView2RegionRectCollection members
        UInt32 Count { get; };

        Windows.Foundation.Rect GetValueAtIndex(UInt32 index);

    }
    runtimeclass CoreWebView2CompositionController {
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2CompositionController4")]
        {
            /// ICoreWebView2CompositionController4 members
            event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2NonClientRegionChangedEventArgs> NonClientRegionChanged;
            CoreWebView2NonClientRegionKind GetNonClientRegionAtPoint(Windows.Foundation.Point point);
            CoreWebView2RegionRectCollection QueryNonClientRegion(CoreWebView2NonClientRegionKind Kind);
        }
    }
}
```