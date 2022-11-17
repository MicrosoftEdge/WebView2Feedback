# Background
This is a proposal for a new API that will provide a framework for native representation of DOM
objects from page content in WebView2 and its implementation for DOM File objects. The (specific ask
from WebView2)[https://github.com/MicrosoftEdge/WebView2Feedback/issues/501] is to be able get to
the paths for DOM file objects, which is not accessible to page content. We also have asks to
expose other DOM objects, including iframes, <object> objects, etc. which will be added under this
WebMessageObjects framework in future.

# Conceptual pages (How To)

WebMessageObjects are representations of DOM objects that can be passed via the [WebView2 WebMessage
API](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webmessagereceivedeventargs)
to the app. You can examine supported DOM objects using native reflections of the types.

Currently the only supported DOM object type with this API is:
- [File](https://developer.mozilla.org/en-US/docs/Web/API/File)

Page content in WebView2 can pass objects to the app via the
`chrome.webview.postMessageWithAdditionalObjects(string message, array<object> objects)` content API
that takes in the array of such supported DOM objects or you can also use
(ExecuteScript)[https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.winforms.webview2.executescriptasync]
with same API. If an invalid or unsupported object is passed via this API, an exception will be
thrown to content and the message will fail to post.

On the WebMessageReceived event handler, the app will retrieve the native representation of objects
via `AdditionalObjects` property and cast the passed objects to their native types. For example, the
DOM File object will be exposed as a `CoreWebView2File` object, allowing the app to read the path of
the passed DOM File object.

# Examples
## Read the File path of a DOM File

Use this API with a DOM File object to be able to get the path of files dropped on WebView2. The
HTML and JavaScript snippets are part of the page content code running inside WebView2.

```html
<!-- File upload location -->
<input type="file" id="files" multiple />
```

```javascript
const input = document.getElementById('files');
input.addEventListener('change', function() {
    const currentFiles = input.files;
    chrome.webview.postMessageWithAdditionalObjects("FilesDropped", curFiles);
});
```

```cpp
m_webView->add_WebMessageReceived(
    Callback<ICoreWebView2WebMessageReceivedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args)
        {
            wil::com_ptr<ICoreWebView2WebMessageReceivedEventArgs2> args2 =
                wil::com_ptr<ICoreWebView2WebMessageReceivedEventArgs>(args)
                    .query<ICoreWebView2WebMessageReceivedEventArgs2>();
            wil::com_ptr<ICoreWebView2WebMessageObjectCollectionView>
                objectsCollection;
            args2->get_AdditionalObjects(&objectsCollection);
            unsigned int length;
            objectsCollection->get_Count(&length);
            std::vector<std::wstring> paths;

            for (unsigned int i = 0; i < length; i++)
            {
                wil::com_ptr<IUnknown> object;
                objectsCollection->GetValueAtIndex(i, &object);

                wil::com_ptr<ICoreWebView2File> file =
                    object.query<ICoreWebView2File>();
                if (file)
                {
                    // Add the file to message to be sent back to webview
                    wil::unique_cotaskmem_string path;
                    file->get_Path(&path);
                    paths.push_back(path.get());
                }
            }

            return S_OK;
        })
        .Get(),
    &m_webMessageReceivedToken);
```

```c#
webView.CoreWebView2.WebMessageReceived += WebView_WebMessageReceivedHandler;
void WebView_WebMessageReceivedHandler(object sender, CoreWebView2WebMessageReceivedEventArgs args)
{
    List<string> paths = new List<string>();
    foreach (var object in args.AdditionalObjects)
    {
        if (object is CoreWebView2File) {
            paths.Add((CoreWebView2File)(object).path);
        }
    }
}
```

# API Details
```c#
/// Representation of a DOM
/// (File)[https://developer.mozilla.org/en-US/docs/Web/API/File] object
/// passed via WebMessage. You can use this object to obtain the path of a 
/// File dropped on WebView2.
/// \snippet ScenarioDragDrop.cpp DroppedFilePath
[uuid(f2c19559-6bc1-4583-a757-90021be9afec), object, pointer_default(unique)]
interface ICoreWebView2File : IUnknown {
  /// Get the file path.
  /// On Windows, this is the DOS path.
  [propget] HRESULT Path([out, retval] LPWSTR* path);
}

/// Read-only collection of WebMessage objects
[uuid(b547d2d4-b8d5-4278-a544-c54e66b5f45d), object, pointer_default(unique)]
interface ICoreWebView2WebMessageObjectCollectionView : IUnknown {
  /// Gets the number of items in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the object at the specified index. Cast the object to the native type
  /// to access its specific properties.
  HRESULT GetValueAtIndex([in] UINT32 index,
      [out, retval] IUnknown** value);
}

[uuid(50a798ac-40fa-4634-8fb7-9419e5e8a3f8), object, pointer_default(unique)]
interface ICoreWebView2WebMessageReceivedEventArgs2 : IUnknown {
  /// Additional received WebMessage objects. To pass `additionalObjects` via
  /// WebMessage to the app, use the
  /// `chrome.webview.postMessageWithAdditionalObjects(string message, array<object> additionalObjects)`
  /// content API.
  /// If an invalid or unsupported object is passed via this API, an exception
  /// will be thrown to content and the message will fail to post.
  /// Any DOM object type that can be natively representable that has been
  /// passed in to `additionalObjects` parameter will be accessible here.
  /// Currently a WebMessage object can be the following type:
  /// - `ICoreWebView2File`.
  [propget] HRESULT AdditionalObjects(
      [out, retval] ICoreWebView2WebMessageObjectCollectionView** value);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    /// Representation of a DOM
    /// (File)[https://developer.mozilla.org/en-US/docs/Web/API/File] object
    /// passed via WebMessage. You can use this object to obtain the path of a 
    /// File dropped on WebView2.
    runtimeclass CoreWebView2File
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2File")]
        {
            /// The file path, which is DOS path on Windows.
            string Path { get; };
        }
    }

    runtimeclass CoreWebView2WebMessageReceivedEventArgs
    {
        /// Additional received WebMessage objects. To pass additionalObjects via
        /// WebMessage to the app, use the
        /// `chrome.webview.postMessageWithAdditionalObjects(string message, array<object> additionalObjects)`
        /// content API.
        /// If an invalid or unsupported object is passed via this API, an exception will be
        /// thrown to content and the message will fail to post.
        /// Any DOM object type that can be natively representable that has been passed in to
        /// `additionalObjects` parameter will be accessible here.
        /// Currently a WebMessage object can be the following type:
        /// - `CoreWebView2File`.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2WebMessageReceivedEventArgs2")]
        {
            List<object> AdditionalObjects { get; };
        }
    }
}
```
