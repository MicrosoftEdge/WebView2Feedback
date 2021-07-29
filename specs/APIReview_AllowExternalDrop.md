# Background
Currently dragging and dropping external objects (e.g. files, hyperlinks) into webview2 is by default enabled and there is no way to disable it. Some developers may want to disable this functionality in their applications. To allow for this, we add a new API to provide developers with the capability to disable the external drag & drop functionality.

# Description
We add a new `AllowExternalDrop` property in `CoreWebView2Controller`. 
This API allows end developers to toggle the external drag & drop functionality easily.
If it's disabled, dragging objects from outside the bounds of the WebView and dropping into the WebView will be disallowed.
To be more specific, some behaviors listed below will be impacted by the toggle of this property.

* Drag&Drop files on disk to webview2  
* Drag&Drop hyperlinks from browser to webview2
* Drag&Drop hyperlinks from one webview2 to another webview2

Some behaviors are not impacted by the toggle of this property like dragging and dropping selected text to webview2. That means toggle of this property has no impact on the expected behavior of this action.

By default, AllowExternalDrop is enabled to keep consistent with the behavior we had before the API is added.

Please note that drag and drop anything from webview2 to external(outside the bounds of the WebView) will not be impacted by this property.

# Examples
## C++

```cpp
// This hypothetical app allows dropping external content
// only on the AttachReceipts page.
wil::com_ptr<ICoreWebView2Controller> m_controller;
BOOL m_allowExternalDropOnNavigationCompleted;
HRESULT OnNavigationStarting(ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args)
{
    // Disable external drop while navigating.
    auto controller4 = m_controller.try_query<ICoreWebView2Controller4>();
    if (controller4)
    {
        CHECK_FAILURE(controller4->put_AllowExternalDrop(FALSE));
    }

    // Decide whether to enable external drop when we finish navigating.
    // Enable it only when AttachReceipts page is navigated.
    wil::unique_cotaskmem_string uri;
    CHECK_FAILURE(args->get_Uri(&uri));
    m_allowExternalDropOnNavigationCompleted =  uri_equal(uri.get(), L"myapp://AttachReceipts.html");
}

HRESULT OnNavigationCompleted(ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args)
{
    auto controller4 = m_controller.try_query<ICoreWebView2Controller4>();
    if (controller4)
    {
        CHECK_FAILURE(controller4->put_AllowExternalDrop(m_allowExternalDropOnNavigationCompleted));
    }
}
```

## C#
```c#
// This hypothetical app allows dropping external content
// only on the AttachReceipts page.
private CoreWebView2Controller controller;
private bool allowExternalDropOnNavigationCompleted;
void OnNavigationStarting(object sender, CoreWebView2NavigationStartingEventArgs args)
{
    // Disable external drop while navigating.
    if (controller != null)
    {
        controller.AllowExternalDrop = false;
    }

    // Decide whether to enable external drop when we finish navigating.
    // Enable it only when AttachReceipts page is navigated.
    string uri = args.Uri;
    allowExternalDropOnNavigationCompleted = uri.Equals("myapp://AttachReceipts.html");
}

void OnNavigationCompleted(object sender, CoreWebView2NavigationCompletedEventArgs args)
{
    controller.AllowExternalDrop = allowExternalDropOnNavigationCompleted;
}
```

# Remarks

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```c#
// This is the ICoreWebView2Controller4 interface.
[uuid(320613e2-990f-4272-bf90-d243a4ff1b8a), object, pointer_default(unique)]
interface ICoreWebView2Controller4 : ICoreWebView2Controller3 {
  /// Gets the `AllowExternalDrop` property which is used to configure the
  /// capability that dragging objects from outside the bounds of webview2 and
  /// dropping into webview2 is allowed or disallowed. The default value is
  /// TRUE.
  [propget] HRESULT AllowExternalDrop([ out, retval ] BOOL * value);
  /// Sets the `AllowExternalDrop` property which is used to configure the
  /// capability that dragging objects from outside the bounds of webview2 and
  /// dropping into webview2 is allowed or disallowed.
  [propput] HRESULT AllowExternalDrop([in] BOOL value);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public class CoreWebView2Controller
    {
        //
        // Summary:
        //     Gets or sets the WebView AllowExternalDrop property.
        //
        // Remarks:
        //     The AllowExternalDrop is to configure the capability that dragging objects from
        //     outside the bounds of webview2 and dropping into webview2 is allowed or disallowed.
        //     The default value is true.
        public bool AllowExternalDrop { get; set; }
    }
}
```
