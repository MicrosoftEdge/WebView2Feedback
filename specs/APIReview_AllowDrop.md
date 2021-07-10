# Background
Currently the drag&drop functionality is default enabled in webview2 and there is no way to disable it. Some developers may want to disbale this functionality in their applications 
based upon their scenarios. According to such feature requirements, we add the new API to provide developers with the capability to configure the drag&drop functionality.

# Description
We add a new `AllowDrop` property in `CoreWebView2Controller`. 
This API allows end developers to toggle the drag&drop functionality easily.
If it's disabled, any drag&drop actions will keep out of work. 
By default, it's enabled to keep consistent with the behavior we had before the API is added.

# Examples
## C++

```cpp
void ToggleAllowDrop()
{
    // Get webView's controller
    wil::com_ptr<ICoreWebView2Controller> controller = m_appWindow->GetWebViewController();
    if (controller)
    {
        BOOL allowDrop;
        CHECK_FAILURE(controller->get_AllowDrop(&allowDrop));
        if (allowDrop)
        {
            CHECK_FAILURE(controller->put_AllowDrop(FALSE));
            MessageBox(
                nullptr, L"WebView disallows dropping files now.",
                L"WebView AllowDrop property changed", MB_OK);
        }
        else
        {
            CHECK_FAILURE(controller->put_AllowDrop(TRUE));
            MessageBox(
                nullptr, L"WebView allows dropping files now.",
                L"WebView AllowDrop property changed", MB_OK);
        }
    }
}
```

## C#
```c#
void ToggleAllowDrop(object target, ExecutedRoutedEventArgs e)
{
    // Get webView's controller
    var controller = _webView.CoreWebView2Controller;
    if (controller.AllowDrop)
    {
        controller.AllowDrop = false;
    }
    else
    {
        controller.AllowDrop = true;
    }
}
```

# Remarks
The `AllowDrop` property already exists in some controls of .net UI framework like WPF and WinForms. 
The .net control wrapper for webview2 natively inherits this property. 
But actually it doesn't really take effect until this new API is added.
When the new API is promoted to public, we will adjust the WPF/WinForms webview2 control to consume the new API accordingly.


# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```c#
// This is the ICoreWebView2Controller interface.
[uuid(6a360a1f-d1cf-4d90-a0ab-ae2e7d1a29f0), object, pointer_default(unique)]
interface ICoreWebView2Controller : IUnknown {
  /// Gets the `AllowDrop` property which is used to configure the capability
  /// that dropping files into webview2 is allowed or permitted.
  /// The default value is TRUE.
  ///
  /// \snippet SettingsComponent.cpp ToggleAllowDrop
  [propget] HRESULT AllowDrop([out, retval] BOOL* value);
  /// Sets the `AllowDrop` property which is used to configure the capability
  /// that dropping files into webview2 is allowed or permitted.
  [propput] HRESULT AllowDrop([in] BOOL value);
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
        //     Gets or sets the WebView allow drop property.
        //
        // Remarks:
        //     The AllowDrop is to configure the capability that dropping files into webview2
        //     is allowed or permitted. The default value is true.
        public bool AllowDrop { get; set; }
    }
}
```
