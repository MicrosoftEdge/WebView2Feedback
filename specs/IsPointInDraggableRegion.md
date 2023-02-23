<!-- 
    Before submitting, delete all "<!-- TEMPLATE" marked comments in this file,
    and the following quote banner:
-->
> See comments in Markdown for how to use this spec template

<!-- TEMPLATE
    The purpose of this spec is to describe new APIs, in a way
    that will transfer to learn.microsoft.com (https://learn.microsoft.com/microsoft-edge/webview2/).

    There are two audiences for the spec. The first are people that want to evaluate and
    give feedback on the API, as part of the submission process.
    So the second audience is everyone that reads there to learn how and why to use this API.
    Some of this text also shows up in Visual Studio Intellisense.
    When the PR is complete, the content within the 'Conceptual Pages' section of the review spec will be incorporated into the public documentation at
    http://learn.microsoft.com (LMC).

    For example, much of the examples and descriptions in the `RadialGradientBrush` API spec
    (https://github.com/microsoft/microsoft-ui-xaml-specs/blob/master/active/RadialGradientBrush/RadialGradientBrush.md)
    were carried over to the public API page on LMC
    (https://learn.microsoft.com/windows/winui/api/microsoft.ui.xaml.media.radialgradientbrush?view=winui-2.5)

    Once the API is on LMC, that becomes the official copy, and this spec becomes an archive.
    For example if the description is updated, that only needs to happen on LMC and needn't
    be duplicated here.

    Examples:
    * New set of classes and APIs (Custom Downloads):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md
    * New member on an existing class (BackgroundColor):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/BackgroundColor.md

    Style guide:
    * Use second person; speak to the developer who will be learning/using this API.
    (For example "you use this to..." rather than "the developer uses this to...")
    * Use hard returns to keep the page width within ~100 columns.
    (Otherwise it's more difficult to leave comments in a GitHub PR.)
    * Talk about an API's behavior, not its implementation.
    (Speak to the developer using this API, not to the team implementing it.)
    * A picture is worth a thousand words.
    * An example is worth a million words.
    * Keep examples realistic but simple; don't add unrelated complications.
    (An example that passes a stream needn't show the process of launching the File-Open dialog.)
    * Use GitHub flavored Markdown: https://guides.github.com/features/mastering-markdown/

-->

Draggable Regions For Visual Hosted Apps
===

# Background
<!-- TEMPLATE
    Use this section to provide background context for the new API(s)
    in this spec. Try to briefly provide enough information to be able to read
    the rest of the document.

    This section and the appendix are the only sections that likely
    do not get copied into any official documentation, they're just an aid
    to reading this spec. If you find useful information in the background
    or appendix consider moving it to documentation.
    
    If you're modifying an existing API, included a link here to the
    existing page(s) or spec documentation.

    For example, this section is a place to explain why you're adding this
    API rather than modifying an existing API.

    For example, this is a place to provide a brief explanation of some dependent
    area, just explanation enough to understand this new API, rather than telling
    the reader "go read 100 pages of background information posted at ...". 
-->
Draggable regions are marked regions on a webpage that will move the app window when the user clicks and drags on them. It also opens up the system menu if right-clicked. This API is designed to provide draggable regions support for Visual Hosting.


# Examples
## Enable Dragging (L button)
### Handle WM_NCHITTEST
The objective is to tell Windows that the current mouse coordinate corresponds to a caption location if it is within a draggable region.
#### Win32
```cpp
       case WM_NCHITTEST:
            POINT pt {GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)};
            BOOL isInRegion = FALSE;
            webview2->IsPointInDraggableRegion(&pt, &isInRegion);

            if(isInRegion)
            return HTCAPTION;
    
            break;
```
#### .NET / WinRT
```c#
        if (m.Msg == WM_NCHITTEST)
        {
            Point p = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));

            if (webview2.IsPointInDraggableRegion(ref p)) {
                m.Result = (IntPtr)HTCAPTION;
            }
        }
```
## Enable System Menu (R button)
### Handle WM_NCRBUTTONDOWN
NOTE: The setup above is required as well.

Here we must capture the mouse if the current message corresponds to an HTCAPTION area. For later use, we must also flag that we have received an R button down on a draggable region. The latter part is done using 

```cpp
ncrbuttondown_on_draggable_region_ = TRUE
```

NOTE: It is not necessary, but recommended that you also check to ensure the coordinates here lie in a draggable region. Not doing so opens up the possibility that the default system menu will always be overridden. This may or may not be an issue for your application. 

#### Win32
```cpp
        case WM_NCRBUTTONDOWN:
            BOOL isInRegion = FALSE;
            webview2->IsPointInDraggableRegion(&pt, &isInRegion);
            if(
                w_param == HTCAPTION 
                && isInRegion // this clause is not required but recommended, see above for more details
                ) {
                ncrbuttondown_on_draggable_region_ = TRUE
                SetCapture(hwnd); // capture the mouse
                return 0;
            }
```
#### .NET / WinRT
```c#
        if (m.msg == WM_NCRBUTTONDOWN) {
            Point p = new Point(GET_X_LPARAM(m.lParam), GET_Y_LPARAM(m.lParam));

            if(webview2->IsPointInDraggableRegion(ref p) // this clause is not required but recommended, see above for more details
            && m.wParam == HTCAPTION) {
                setCapture(hwnd);
                ncrbuttondown_on_draggable_region_ = true;
                m.Result = 0;
            }
        }
```

### Handle WM_RBUTTONUP
Capturing the mouse earlier allows us to receive this event. We need to verify two things; the point is within a draggable region, and the previous R button-down message was within a draggable region (using ncrbuttondown_on_draggable_region_ ). 

If both clauses are true, then you may proceed to handle this as you, please. Most likely you would want to show the system menu.
#### Win32
```cpp
        case WM_RBUTTONUP:
            BOOL isInRegion = FALSE;
            webview2->IsPointInDraggableRegion(&pt, &isInRegion);

            if(isInRegion && ncrbuttondown_on_draggable_region_ == TRUE) {
                // show system menu
                POINT screen_point{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };

                MapWindowPoints(hwnd, HWND_DESKTOP, &screen_point, 1);
                
                UINT flags =
                    TPM_LEFTALIGN | TPM_TOPALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD;
                
                HMENU menu = GetSystemMenu(hwnd, FALSE);

                const int command = TrackPopupMenu(
                    menu, flags, screen_point.x, screen_point.y, 0, hwnd, nullptr);

                if (command)
                    SendMessage(hwnd, WM_SYSCOMMAND, static_cast<WPARAM>(command),
                            0);
            
            }
            
        break;
```
#### .NET / WinRT
```c#
        if (m.msg == WM_RBUTTONUP) {

            if (webview2.IsPointInDraggableRegion(ref pt) // this clause is not required but recommended, see below for more details
            && ncrbuttondown_on_draggable_region_ == true)
            {
                // show system menu
                POINT screen_point = new POINT(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam));

                MapWindowPoints(hwnd, HWND_DESKTOP, ref screen_point, 1);

                uint flags = TPM_LEFTALIGN | TPM_TOPALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD;

                IntPtr menu = GetSystemMenu(hwnd, false);

                int command = TrackPopupMenu(menu, flags, screen_point.x, screen_point.y, 0, hwnd, IntPtr.Zero);

                if (command != 0)
                {
                    SendMessage(hwnd, WM_SYSCOMMAND, (IntPtr)command, IntPtr.Zero);
                }
            
            }
        }
```

# API Details
<!-- TEMPLATE
    The exact API, in IDL format for our COM API and
    in MIDL3 format (https://learn.microsoft.com/uwp/midl-3/)
    when possible.

    Include every new or modified type but use // ... to remove any methods,
    properties, or events that are unchanged.

    For the MIDL3 parts, after running build-apiwriter, open the generated
    `Microsoft.Web.WebView2.Core.idl` and find the new or modified portions
    generated from your modifications to the COM IDL.

    (GitHub's markdown syntax formatter does not (yet) know about MIDL3, so
    use ```c# instead even when writing MIDL3.)

    Example:
    
```
[uuid(B625A89E-368F-43F5-BCBA-39AA6234CCF8), object, pointer_default(unique)]
interface ICoreWebView2Settings4 : ICoreWebView2Settings3 {
  /// The IsPinchZoomEnabled property enables or disables the ability of 
  /// the end user to use a pinching motion on touch input enabled devices
  /// to scale the web content in the WebView2. It defaults to TRUE.
  /// When set to FALSE, the end user cannot pinch zoom.
  /// This API only affects the Page Scale zoom and has no effect on the
  /// existing browser zoom properties (IsZoomControlEnabled and ZoomFactor)
  /// or other end user mechanisms for zooming.
  ///
  /// \snippet SettingsComponent.cpp TogglePinchZooomEnabled
  [propget] HRESULT IsPinchZoomEnabled([out, retval] BOOL* enabled);
  /// Set the IsPinchZoomEnabled property
  [propput] HRESULT IsPinchZoomEnabled([in] BOOL enabled);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings5")]
        {
            Boolean IsPinchZoomEnabled { get; set; };
        }
    }
}
```

If you are introducing a WebView2 JavaScript API include the TypeScript
definition of that API and reference documentation for it as well.
You can use https://www.typescriptlang.org/play to verify your TypeScript

```ts
interface WebView extends EventTarget {
    postMessage(message: any) : void;
    hostObjects: HostObjectsAsyncRoot;
    // ...
}

interface HostObjectsAsyncRoot {
    cleanupSome() : void;
    options: HostObjectsOptions;
}

interface HostObjectsOptions {
    forceLocalProperties: string[];
    log: (...data: any[]) => void;
    shouldSerializeDates: boolean;
    defaultSyncProxy: boolean;
    forceAsyncMethodMatches: RegExp[];
    ignoreMemberNotFoundError: boolean;
}
```

-->
## Win32 C++
```cpp
[uuid(42BF7BA5-917A-4C27-ADA1-EA6969854C16), object, pointer_default(unique)]
interface ICoreWebView2StagingController : NULL {
    [propget] HRESULT IsPointInDraggableRegion([out, retval] BOOL* value);
}
```
## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core {
    runtimeclass CoreWebView2StagingController {
        public bool IsPointInDraggableRegion(ref Point p);
    }
}
```
<!--
# Appendix
 TEMPLATE
  Anything else that you want to write down about implementation notes and for posterity,
  but that isn't necessary to understand the purpose and usage of the API.
  
  This or the Background section are a good place to describe alternative designs
  and why they were rejected, any relevant implementation details, or links to other
  resources.
-->