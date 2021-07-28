# Background
Currently the functionality of dragging and dropping external objects(e.g. files, hyperlinks) into webview2 is default enabled in webview2 and there is no way to disable it. Some developers may want to disbale this functionality in their applications based upon their scenarios. According to such feature requirements, we add the new API to provide developers with the capability to configure the external drag&drop functionality.

# Description
We add a new `AllowExternalDrop` property in `CoreWebView2Controller`. 
This API allows end developers to toggle the external drag&drop functionality easily.
If it's disabled, drag&drop objects from outside into current webview2 will be permitted.
To be more specific, some behaviors listed below will be impacted by the toggle of this property.

* Drag&Drop files on disk to webview2  
* Drag&Drop hyperlinks from browser to webview2
* Drag&Drop hyperlinks from one webview2 to another webview2

Some behaviors are not impacted by the toggle of this property like drag&drop selected text to webview2. That means toggle of this property has no impact on the expected behavior of this action.

By default, AllowExternalDrop is enabled to keep consistent with the behavior we had before the API is added.

Please note that drag&drop anything from webview2 to external(outside current webview2) will not be impacted by this property.

# Examples
## C++

```cpp
wil::com_ptr<ICoreWebView2Controller4> m_controller4;
void ToggleAllowDrop()
{
    if (m_controller4)
    {
        BOOL allowDrop;
        CHECK_FAILURE(m_controller4->get_AllowDrop(&allowDrop));
        if (allowDrop)
        {
            CHECK_FAILURE(m_controller4->put_AllowDrop(FALSE));
        }
        else
        {
            CHECK_FAILURE(m_controller4->put_AllowDrop(TRUE));
        }
    }
}
```

## C#
```c#
private CoreWebView2Controller controller
void ToggleAllowDrop(object target, ExecutedRoutedEventArgs e)
{
    if (controller)
    {
        controller.AllowDrop = !controller.AllowDrop;
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
[uuid(320613e2-990f-4272-bf90-d243a4ff1b8a), object, pointer_default(unique)]
interface ICoreWebView2Controller4 : ICoreWebView2Controller3 {
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
