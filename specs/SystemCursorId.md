# Background

When an app is using composition hosting to host WebView, the current cursor
image cannot be determined easily by the hosting application. For example, if
the cursor over the WebView is also over a textbox inside of the WebView, the
cursor should usually be IDC_IBEAM. And by default, the cursor is IDC_ARROW.
Currently, the `ICoreWebView2CompositionController.Cursor` property returns what
the cursor should be as an HCURSOR object, which the hosting application can
then use the to change the current cursor to the correct image.

However, Office already has a well established way of using cursors internally
by using IDC_* values and there is no easy way to convert the HCURSOR object we
are returning into an IDC value after it's been created.

This new API is to enable hosting applications like Office to get the current
IDC value of the cursor instead of the HCURSOR as an option.

Note that this is a COM and .NET spec as WinRT uses a separate enum structure to
identify cursor IDs.


# Description

The `SystemCursorId` property will return the current system cursor ID reported
by the underlying rendering engine for WebView2. It is not meant to return a
value for any custom cursors, such as those defined by CSS.

It can be used at any time but will only change after a `CursorChanged` event.

Note that developers should generally use the `Cursor` property to support cases
where there may be custom cursors.


# Examples

```cpp
// Handler for WM_SETCURSOR window message.
bool OnSetCursor()
{
    POINT point;
    if (m_compositionController && GetCursorPos(&point))
    {
        // Calculate if the point lies in the WebView visual for composition hosting
        // as it may not cover the whole HWND it's under.
        if (PtInRect(&m_webViewBounds, point))
        {
            HCURSOR cursor;
            UINT32 cursorId;
            wil::com_ptr<ICoreWebView2CompositionController2> compositionController2 =
                m_compositionController.query<ICoreWebView2CompositionController2>();
            CHECK_FAILURE(compositionController2->get_SystemCursorId(&cursorId));
            cursor = ::LoadCursor(nullptr, MAKEINTRESOURCE(cursorId));

            if (cursor)
            {
                ::SetCursor(cursor);
                return true;
            }
        }
    }
    return false;
}

CHECK_FAILURE(m_compositionController->add_CursorChanged(
    Callback<ICoreWebView2CursorChangedEventHandler>(
        [this](ICoreWebView2CompositionController* sender, IUnknown* args)
            -> HRESULT {
            // No need to do hit testing here as the WM_SETCURSOR handler will have
            // to calculate if the point is within the WebView anyways.
            SendMessage(m_appWindow->GetMainWindow(), WM_SETCURSOR,
                (WPARAM)m_appWindow->GetMainWindow(), MAKELPARAM(HTCLIENT, WM_MOUSEMOVE));
            return S_OK;
        })
        .Get(),
    &m_cursorChangedToken));


# API Notes

See [API Details](#api-details) section below for API reference.


# API Details

```cpp
/// This interface is continuation of the 
/// ICoreWebView2CompositionController interface.
[uuid(279ae616-b7cb-4946-8da3-dc853645d2ba), object, pointer_default(unique)]
interface ICoreWebView2CompositionController2 : ICoreWebView2CompositionController {
  /// The current system cursor ID reported by the underlying rendering engine
  /// for WebView. For example, most of the time, when the cursor is over text,
  /// this will return the int value for IDC_IBEAM. The systemCursorId is only
  /// valid if the rendering engine reports a default Windows cursor resource
  /// value. See:
  /// https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadcursorw
  /// Otherwise, if custom CSS cursors are being used, this will return 0.
  /// To actually use systemCursorId in LoadCursor or LoadImage,
  /// MAKEINTRESOURCE must be called on it first.
  /// If possible, use the Cursor property rather than the SystemCursorId
  /// property because the Cursor property can express custom CSS cursors.
  ///
  /// \snippet ViewComponent.cpp SystemCursorId
  [propget] HRESULT SystemCursorId([out, retval] UINT32* systemCursorId);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    //
    // Summary:
    //     This class is an extension of the CoreWebView2CompositionController class to support composition
    //     hosting.
    public class CoreWebView2CompositionController2
    {
        //
        // Summary:
        //     The current system cursor ID that WebView thinks it should be.
        //
        // Remarks:
        //     The current system cursor ID reported by the underlying rendering engine
        //     for WebView. For example, most of the time, when the cursor is over text,
        //     this will return the int value for IDC_IBEAM. The SystemCursorId is only
        //     valid if the rendering engine reports a default Windows cursor resource
        //     value. See:
        //     https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadcursorw
        //     Otherwise, if custom CSS cursors are being used, this will return 0.
        //     To create a Cursor object, create an IntPtr from the returned uint to
        //     pass into the constructor
        //     If possible, use the Cursor property rather than the SystemCursorId
        //     property because the Cursor property can express custom CSS cursors.
        public Uint32 SystemCursorId { get; }
    }
}
```

# Appendix

I expect that most apps will use the get_Cursor API which returns an HCURSOR (Or
the UWP equivalent that will be implemented in the future that will return a
CoreCursor) outside of Office as HCURSOR is more comprehensive and covers the
scenarios in which custom cursors are used.
