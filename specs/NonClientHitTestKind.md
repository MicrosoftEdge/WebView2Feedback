Hit Test Kind
===

# Background
The ability to ask the Webview for information on a hit test is an important feature for 
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

NOTE: Your app may already be forwarding mouse messages to the WebView, if so the bulk 
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

// used to control when messages are forwarded to WebView
static bool isCapturingMouse = false; 

// handle the range of mouse messages & WM_NCRBUTTONDOWN
if (message >= WM_MOUSEFIRST && message <= WM_MOUSELAST || message == WM_NCRBUTTONDOWN) 
{
    POINT point {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
    // IsPointInWebview is an example of a function which your app can implement that checks if 
    // the mouse message point lies inside the rect of the visual that hosts the WebView
    if (IsPointInWebView(point) || message == WM_MOUSELEAVE || isCapturingMouse) 
    {
    if (message == WM_NCRBUTTONDOWN && w_param == HTCAPTION)
    {
        // capturing the mouse will allow us to begin forwarding messages to 
        // webview
        isCapturingMouse = true;
        SetCapture(mainWindowHwnd);
    }
    if (message ==  WM_RBUTTONUP && GetCapture() == mainWindowHwnd) 
    {
        // no longer need to capture the mouse or forward subsequent messages 
        // to webview
        isCapturingMouse = false 
        ReleaseCapture();
    }

    // forward mouse messages to WV
    CHECK_FAILURE(CompositionController->SendMouseInput(
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
    COREWEBVIEW2_HIT_TEST_KIND result = NULL;
    CHECK_FAILURE(CompositionController->GetHitTestResultAtPoint(&point, &result));

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
....
private bool isCapturingMouse = false;
....

protected override void WndProc(ref Message m)
{
....

if (m.Msg == WM_NCHITTEST)
{
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));
    if (CompositionController.GetHitTestResultAtPoint(point) == 
        CoreWebView2HitTestResult.Htcaption) 
    {
        m.Result = (IntPtr)HTCAPTION;
    }
}
// The following code forwards mouse messages to the WebView2 - Start
else if (m.msg >= WM_MOUSEFIRST && m.msg <= WM_MOUSELAST || m.msg == WM_NCRBUTTONDOWN) 
{
  
    Point point = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));
    // IsPointInWebview is an example of a function which your app can implement that checks if 
    // the mouse message point lies inside the rect of the visual that hosts the WebView
    if (IsPointInWebView(point) || m.msg == WM_MOUSELEAVE || isCapturingMouse) 
    {

        if (m.msg == WM_NCRBUTTONDOWN && m.w_param == HTCAPTION) 
        {
            // capturing the mouse will allow us to begin forwarding messages 
            // to webview
            isCapturingMouse = true;
            SetCapture(mainWindowHwnd);
        }
        else if (message ==  WM_RBUTTONUP && GetCapture() == mainWindowHwnd) 
        {
            // no longer need to capture the mouse for draggbale regions support 
            // after this
            isCapturingMouse = false;
            ReleaseCapture();
        }
        
        // forward mouse messages to WV
        CompositionController.SendMouseInput(
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
# API Details
## Win32 C++
```cpp
/// This enum contains values representing possible regions a given
/// point lies within
typedef enum COREWEBVIEW2_HIT_TEST_RESULT {
    /// A hit test region in the WebView2 which has the CSS style `app-region: drag` set. Web content should use this CSS style to identify regions that should be treated like the app window's title bar. This has the same value as the Win32 HTCAPTION constant. 
    COREWEBVIEW2_HIT_TEST_RESULT_CAPTION = 2,
    /// For regions in the WV which don't have the CSS style 'app-region: drag' set
    COREWEBVIEW2_HIT_TEST_RESULT_CLIENT,
    /// Out of bounds of the app window
    COREWEBVIEW2_HIT_TEST_RESULT_NONE = 0
} COREWEBVIEW2_HIT_TEST_RESULT;

/// This interface includes the new API for enabling Webview support for hit-testing regions
[uuid(42BF7BA5-917A-4C27-ADA1-EA6969854C16), object, pointer_default(unique)]
interface ICoreWebView2CompositionController4 : ICoreWebView2CompositionController3 {
    /// Takes in a point and returns a Hit-test result value as an out parameter
    /// Point is expected to be in the client coordinate space of the WebView.
    
    /// The method returns: 
    ///     -COREWEBVIEW2_HIT_TEST_RESULT_CAPTION: when point corresponds to
    ///         a region (HTML element) within the WV with 
    ///         app-region: drag CSS style set
    ///     -COREWEBVIEW2_HIT_TEST_RESULT_CLIENT: when point corresponds to
    ///         a region (HTML element) within the WV without 
    ///         app-region: drag CSS style set
    ///     -COREWEBVIEW2_HIT_TEST_RESULT_NONE:  when point is not within the WV
    HRESULT GetHitTestResultAtPoint(
                        [in] POINT point, 
                        [out, retval] COREWEBVIEW2_HIT_TEST_RESULT* val);
}
```
## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core {
    /// This enum contains values representing possible regions that Webview
    /// can support
    enum CoreWebView2HitTestResult
    {
        /// Caption region
        Caption = 2,
        /// Client region
        Client = 1,
        /// Out of bounds of the app window
        None = 0,
    }
    /// This runtime class includes more than just the new API for enabling Webview support for hit-testing regions
    runtimeclass CoreWebView2CompositionController {
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2CompositionController4")]
        {
            /// Takes in a point and returns a Hit-test result value
            /// Point is expected to be in the client coordinate space of the WebView
            CoreWebView2HitTestResult GetHitTestResultAtPoint(Windows.Foundation.Point point);
        }
    }
}
```