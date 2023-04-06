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

NOTE: Your app may already be forwarding mouse messages to WebView2, if so the bulk 
of the code below is likely already in your app. One thing you need to do specifically 
for this feature is to add the check for w_param == HTCAPTION as a clause for capturing 
the mouse and forwarding messages. It is necessary for the system menu to show. If you 
choose not to include this you would have to handle the logic for showing the system menu 
yourself.

NOTE: This API is not currently supported for environments that use a CoreWindow like UWP

#### Win32 C++
```cpp
LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
....
// The following code forwards mouse messages to the WebView2 - Start

// handle the range of mouse messages & WM_NCRBUTTONDOWN
if (message >= WM_MOUSEFIRST && message <= WM_MOUSELAST 
    || message == WM_NCRBUTTONDOWN || message == WM_NCRBUTTONUP) 
{
    POINT point {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
    // IsPointInWebview is an example of a function which your app can implement that checks if 
    // the mouse message point lies inside the rect of the visual that hosts the WebView2
    if (IsPointInWebView(point) || message == WM_MOUSELEAVE) 
    {
        // forward mouse messages to WebView2
        CHECK_FAILURE(m_compositionController->SendMouseInput(
            static_cast<COREWEBVIEW2_MOUSE_EVENT_KIND>(message),
            static_cast<COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS>(GET_KEYSTATE_WPARAM(wParam)),
            mouseData, point));
        return 0;
    }
    
}
// The following code forwards mouse messages to the WebView2 - End

switch(message) 
{
    ....
    // Handling this message is important for enabling dragging
    case WM_NCHITTEST:
        POINT point {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
        COREWEBVIEW2_HIT_TEST_RESULT result = NULL;
        CHECK_FAILURE(m_compositionController->GetHitTestResultAtPoint(&point, &result));

        if (result == COREWEBVIEW2_HIT_TEST_RESULT_HTCAPTION)
        {
            return HTCAPTION;
        }

        break;
    ....
}
....
}
```
#### C#/WinRT
```c#
protected override void WndProc(ref Message m)
{
....

if (m.Msg == WM_NCHITTEST)
{
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));
    if (m_compositionController.GetHitTestResultAtPoint(point) == 
        CoreWebView2HitTestResult.Htcaption) 
    {
        m.Result = (IntPtr)HTCAPTION;
    }
}
// The following code forwards mouse messages to the WebView2 - Start
else if (m.msg >= WM_MOUSEFIRST && m.msg <= WM_MOUSELAST 
        || m.msg == WM_NCRBUTTONDOWN || m.msg == WM_NCRBUTTONUP) 
{
  
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));
    // IsPointInWebview is an example of a function which your app can implement that 
    // checks if the mouse message point lies inside the rect of the visual that hosts
    // the WebView.
    if (IsPointInWebView(point) || m.msg == WM_MOUSELEAVE) 
    {
        
        // forward mouse messages to WebView2
        m_compositionController.SendMouseInput(
            (CoreWebView2MouseEventKind)message,
            (CoreWebView2MouseEventVirtualKeys)GET_KEYSTATE_WPARAM(wParam),
            mouseData,
            point);

        m.Result = 0
        return;
    }
        
}
// The following code forwards mouse messages to the WebView2 - Start
    ....
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
typedef enum COREWEBVIEW2_HIT_TEST_RESULT {
    /// A hit test region in the WebView2 which has the CSS style 
    /// `-webkit-app-region: drag` set. Web content should use this CSS 
    /// style to identify regions that should be treated like the app 
    /// window's title bar. This has the same value as the Win32 HTCAPTION 
    /// constant. 
    COREWEBVIEW2_HIT_TEST_RESULT_CAPTION = 2,
    /// A hit test region in the WebView2 which does not have the CSS style 
    /// `-webkit-app-region: drag` set. This is normal web content that should not be 
    /// considered part of the app window's title bar. This has the same value 
    /// as the Win32 HTCLIENT constant.
    COREWEBVIEW2_HIT_TEST_RESULT_CLIENT = 1,
    /// A hit test region out of bounds of the WebView2.
    /// This has the same value as the Win32 HTNOWHERE
    COREWEBVIEW2_HIT_TEST_RESULT_NOWHERE = 0
} COREWEBVIEW2_HIT_TEST_RESULT;

/// This interface includes the new API for enabling WebView2 support for hit-testing regions
[uuid(42BF7BA5-917A-4C27-ADA1-EA6969854C16), object, pointer_default(unique)]
interface ICoreWebView2CompositionController4 : ICoreWebView2CompositionController3 {
    /// If you are hosting a WebView2 using CoreWebView2CompositionController, you can call 
    /// this method in your Win32 WndProc to determine if the mouse is moving over or 
    /// clicking on WebView2 web content that should be considered part of the app window's 
    /// title bar.

    /// [in] Point is expected to be in the client coordinate space of WebView2.
    /// [out, retval] The method returns: 
    ///     - COREWEBVIEW2_HIT_TEST_RESULT_CAPTION when point corresponds to
    ///         a region (HTML element) within the WebView2 with 
    ///         `-webkit-app-region: drag` CSS style set
    ///     - COREWEBVIEW2_HIT_TEST_RESULT_CLIENT when point corresponds to
    ///         a region (HTML element) within the WebView2 without 
    ///         `-webkit-app-region: drag` CSS style set
    ///     - COREWEBVIEW2_HIT_TEST_RESULT_NOWHERE when point is not within the WebView2

    HRESULT GetHitTestResultAtPoint(
                        [in] POINT point, 
                        [out, retval] COREWEBVIEW2_HIT_TEST_RESULT* val);
}

/// Mouse event type used by SendMouseInput to convey the type of mouse event
/// being sent to WebView. The values of this enum align with the matching
/// WM_* window messages.
typedef enum COREWEBVIEW2_MOUSE_EVENT_KIND {
    ....
    /// Mouse Right Button Down event over a nonclient area, WM_NCRBUTTONDOWN.
    COREWEBVIEW2_MOUSE_EVENT_KIND_NON_CLIENT_RIGHT_BUTTON_DOWN = 0x00A4,
    ....
    /// Mouse Right Button up event over a nonclient area, WM_NCRBUTTONUP.
    COREWEBVIEW2_MOUSE_EVENT_KIND_NON_CLIENT_RIGHT_BUTTON_UP = 0x00A5,
    ....
} COREWEBVIEW2_MOUSE_EVENT_KIND;
```
## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core {
    enum CoreWebView2HitTestResult
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
    runtimeclass CoreWebView2CompositionController {
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2CompositionController4")]
        {
            CoreWebView2HitTestResult GetHitTestResultAtPoint(Windows.Foundation.Point point);
        }
    }
}
```