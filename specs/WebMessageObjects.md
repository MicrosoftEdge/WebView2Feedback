# Background
This is a proposal for a new API that will provide a framework for native representation of DOM
objects from page content in WebView2 and its implementation for DOM File objects.. The (specific
ask from WebView2)[https://github.com/MicrosoftEdge/WebView2Feedback/issues/501] is to be able get
to the paths for DOM file objects, which is not accessible to page content. We also have asks to
expose other DOM objects, including iframes, <object> objects, etc. which will be added under this
WebMessageObjects framework in future.

Also in future we want to be able to to inject DOM objects into WebView2 content constructed via the
app and via the CoreWebView2.PostWebMessage API in the other direction. This API surface needs to be
compatible with that. (See Appendix)

# Conceptual pages (How To)
WebMessageObjects are representations of DOM objects that can be passed via the [WebView2 WebMessage
API](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2webmessagereceivedeventargs).
You can examine supported DOM objects using native reflections of the types.

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
HTML and JavaScript snippets are part of the page content code running inside WebView2 and are used
by both the C++ and C# sample code below.

```html
<!-- File upload location -->
<input type="file" id="files" multiple />
```

```javascript
const input = document.getElementById('files');
input.addEventListener('change', function() {
    const currentFiles = input.files;
    chrome.webview.postMessageWithAdditionalObjects("FilesDropped", currentFiles);
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


            ProcessFiles(files);
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
  /// Get the absolute file path.
  [propget] HRESULT Path([out, retval] LPWSTR* path);
}

/// Read-only collection of generic objects
[uuid(b547d2d4-b8d5-4278-a544-c54e66b5f45d), object, pointer_default(unique)]
interface ICoreWebView2ObjectCollectionView : IUnknown {
  /// Gets the number of items in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the object at the specified index. Cast the object to the native type
  /// to access its specific properties.
  HRESULT GetValueAtIndex([in] UINT32 index,
      [out, retval] IUnknown** value);
}

[uuid(50a798ac-40fa-4634-8fb7-9419e5e8a3f8), object, pointer_default(unique)]
interface ICoreWebView2WebMessageReceivedEventArgs2 : ICoreWebView2WebMessageReceivedEventArgs {
  /// Additional received WebMessage objects. To pass `additionalObjects` via
  /// WebMessage to the app, use the
  /// `chrome.webview.postMessageWithAdditionalObjects` content API.
  /// Any DOM object type that can be natively representable that has been
  /// passed in to `additionalObjects` parameter will be accessible here.
  /// Currently a WebMessage object can be the following type:
  /// - `ICoreWebView2File`.
  [propget] HRESULT AdditionalObjects(
      [out, retval] ICoreWebView2ObjectCollectionView** value);
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
        ...
        /// Additional received WebMessage objects. To pass additionalObjects via
        /// WebMessage to the app, use the
        /// `chrome.webview.postMessageWithAdditionalObjects' content API.
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

```ts
interface WebView extends EventTarget {
    ...
  /**
     * When the page calls `postMessageWithAdditionalObjects`, the `message`
     * parameter is sent to WebView2 in same fashion as 'postMessage'.
     * Objects passed as 'additionalObjects' are converted to their native types
     * and will be available in
     * `CoreWebView2WebMessageReceivedEventArgs.AdditionalObjects` property.
     * @param message The message to send to the WebView2 host. This can be any
     * object that can be serialized to JSON.
     * @param additionalObjects A sequence of DOM objects that have native
     * representations in WebView2.
     * The following type is currently available natively:
     * - File -> CoreWebView2File
     * If an invalid or unsupported object is passed via this API, an exception
     * will be thrown and the message will fail to post.
     * @example
     * Post a message with File objects from input element to the CoreWebView2:
     * ```javascript
     * const input = document.getElementById('files');
     * input.addEventListener('change', function() {
     *    const currentFiles = input.files;
     *    chrome.webview.postMessageWithAdditionalObjects("FilesDropped",
     *        currentFiles);
     * });
     * ```
     */
    postMessageWithAdditionalObjects(message: any, additionalObjects: ArrayLike<any>) : void;
}
```

# Appendix
## Draft API Proposal to post DOM Objects injected to WebView2 Content
```c#
/// Representation of a DOM
/// (File)[https://developer.mozilla.org/en-US/docs/Web/API/File] object
/// passed via WebMessage. You can use this object to obtain the path of a
/// File dropped on WebView2 or pass a File to WebView2 content.
/// \snippet ScenarioDragDrop.cpp DroppedFilePath
[uuid(f2c19559-6bc1-4583-a757-90021be9afec), object, pointer_default(unique)]
interface ICoreWebView2File : IUnknown {
  /// Get the absolute file path.
  [propget] HRESULT Path([out, retval] LPWSTR* path);
}

/// This interface is used to create `ICoreWebView2File` object, which
/// can be passed as a parameter to PostWebMessageWithAdditionalObjects
[uuid(b571b60f-def2-41d2-a5eb-05d7ccc81981), object, pointer_default(unique)]
interface ICoreWebView2Environment12 : ICoreWebView2Environment11 {
  /// Create a new ICoreWebView2File from a file handle. The handle must be for an existing file in disk.
  /// An invalid file handle will return E_INVALIDARG.
  HRESULT CreateCoreWebView2File(
      [in] HANDLE fileHandle,
      [out, retval] ICoreWebView2File** file);
}

/// A continuation of the `ICoreWebView2` interface to support posting WebMessage
/// with additional objects.
[uuid(fd4e150b-97d4-4baf-ab35-d9899575e700), object, pointer_default(unique)]
interface ICoreWebView2_17 : IUnknown {
  /// Post the specified webMessage to the top level document in this WebView
  /// along with any additional objects that can be injected to WebView content.
  /// The main page receives the message by subscribing to the `message` event of the
  /// `window.chrome.webview` of the page document.
  ///
  /// ```cpp
  /// window.chrome.webview.addEventListener('message', handler)
  /// window.chrome.webview.removeEventListener('message', handler)
  /// ```
  ///
  /// The event args is an instance of `MessageEvent`.  The
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting must be `TRUE` or
  /// this method fails with `E_INVALIDARG`.  The `data` property of the event
  /// arg is the `webMessage` string parameter parsed as a JSON string into a
  /// JavaScript object.  The `additionalObjects` property of event arg will contain
  /// a sequence of WebMessage objects as their DOM types.
  /// Currently the only supported WebMessage object type that is injectable to content is:
  /// - ICoreWebView2File
  /// The `source` property of the event arg is a reference
  ///  to the `window.chrome.webview` object.  For information about sending
  /// messages from the HTML document in the WebView to the host, navigate to
  /// [add_WebMessageReceived](/microsoft-edge/webview2/reference/win32/icorewebview2#add_webmessagereceived).
  /// The message is delivered asynchronously.  If a navigation occurs before
  /// the message is posted to the page, the message is discarded. If there
  /// are any invalid or unsupported additionalObjects, the method fails
  /// with `E_INVALIDARG`.
  ///
  ///
  [propget] HRESULT PostWebMessageAsJsonWithAdditionalObjects(
    [in] LPCWSTR webMessageAsJson,
    [in] ICoreWebView2ObjectCollectionView additionalObjects);
}

```csharp
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment12")]
        {
            /// Create a new ICoreWebView2File from a System.IO.File.
            /// The File object must be for an existing file in disk.
            /// An invalid file handle will throw InvalidArgumentException.
            CoreWebView2File CreateCoreWebView2File(System.IO.File file);
        }
    }
    runtimeclass CoreWebView2
    {
        ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_17")]
        {
            // Posts the specified <c>webMessageAsJson</c> to the top level document in this WebView
            // along with any additional objects that can be injected to WebView content.
            // <param name="webMessageAsJson">The web message to be posted to the top level document in
            // this WebView.</param>
            // <param name="additionalObjects">The list of additional WebMessage objects that can be injected
            // to WebView content.
            // Currently the only supported WebMessage object type that is injectable to content is:
            // - CoreWebView2File
            // </param>
            // <remarks>
            // The event args is an instance of <c>MessageEvent</c>.
            // The <see cref="CoreWebView2Settings.IsWebMessageEnabled"/> setting must be
            // <c>true</c>or this method will fail with E_INVALIDARG. The event arg's
            // <c>data</c> property of the event arg is the <c>webMessageAsJson</c> string
            // parameter parsed as a JSON string into a JavaScript object. The event arg's
            // <c>source</c> property of the event arg is a reference
            // to the <c>window.chrome.webview</c> object. The <c>additionalObjects</c> property of
            // event arg will contain a sequence of WebMessage objects as their DOM types. For
            // information about sending messages from the HTML document in the WebView to the
            // host, navigate to <see cref="CoreWebView2.WebMessageReceived"/>. The message is sent
            // asynchronously. If a navigation occurs before the message is posted to the page,
            // the message is not be sent.
            // </remarks>
            // <example>
            // Runs the message event of the <c>window.chrome.webview</c> of the top-level
            // document. JavaScript in that document may subscribe and unsubscribe to the event
            // using the following code:
            // $net$
            // <code>
            // window.chrome.webview.addEventListener('message', handler)
            // window.chrome.webview.removeEventListener('message', handler)
            // </code>
            // $end$
            // $winrt$
            // ```javascript
            // window.chrome.webview.addEventListener('message', handler)
            // window.chrome.webview.removeEventListener('message', handler)
            // ```
            // $end$
            // </example>
            // <seealso cref="CoreWebView2Settings.IsWebMessageEnabled"/>
            // <seealso cref="WebMessageReceived"/>
            // <seealso cref="PostWebMessageAsString"/>
            void PostWebMessageAsJsonWithAdditionalObjects(
                string webMessageAsJson,
                List<object> additionalObjects);
        }
    }
}
```
