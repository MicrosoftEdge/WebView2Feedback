# Background
This is a proposal for a new API that will provide a framework for native representation of DOM
objects from page content in WebView2 and its implementation for DOM File objects. The [specific ask
from WebView2](https://github.com/MicrosoftEdge/WebView2Feedback/issues/501) is to be able get to
the paths for DOM file objects, which is not accessible to page content. We also have asks to expose
other DOM objects, including iframes, <object> objects, etc. which will be added under this
WebMessageObjects framework in future.

This API will also allow to inject DOM objects into WebView2 content constructed via the app and via
the CoreWebView2.PostWebMessage API in the other direction.

# Conceptual pages (How To)
WebMessageObjects are representations of DOM objects that can be passed via the [WebView2 WebMessage
API](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.core.corewebview2webmessagereceivedeventargs).
You can examine supported DOM objects using native reflections of the types.

Currently the only supported DOM object types with this API are:
- [File](https://developer.mozilla.org/docs/Web/API/File)
- [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle)

In general, the objects that we can support via these APIs are limited to DOM objects that are
[structured-cloneable](https://developer.mozilla.org/docs/Web/API/Web_Workers_API/Structured_clone_algorithm)
and structured clone semantics apply to the posted objects when posting from the app to a web
content. The one important distinction is when a DOM object is posted to a web content from the
app, it will behave as if it originated in the context of that target web content whereas when
posted from one web content to another, an object retain its origin information. This is important for
types like FileSystemHandle, which are restricted to the origin they were obtained on.

Page content in WebView2 can pass objects to the app via the
`chrome.webview.postMessageWithAdditionalObjects(string message, ArrayLike<object> objects)` content
API that takes in the array of such supported DOM objects or you can also use
[ExecuteScript](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.winforms.webview2.executescriptasync)
with same API. `null` or `undefined` objects will be passed as `null`. Otherwise, if an invalid or
unsupported object is passed via this API, an exception will be thrown to the caller and the message
will fail to post. On the WebMessageReceived event handler, the app will retrieve the native
representation of objects via `AdditionalObjects` property and cast the passed objects to their
native types. For example, the DOM File object will be exposed as a `CoreWebView2File` object,
allowing the app to read the path of the passed DOM File object.

The app can also directly create and pass supported DOM objects that it creates via the
EmbeddedBrowserEnvironment using `PostWebMessageAsJsonWithAdditionalObjects([in] LPCWSTR
webMessageAsJson, [in] ICoreWebView2ObjectCollectionView* additionalObjects);` API that takes in the
WebMessage in JSON format and the list of additionalObjects to be injected to the content.
Similarly, from WebContent side, the page will be able to retrieve the DOM types via the
`additionalObjects` ArrayLike object off of the `onmessage` event argument. The API should work for
any WebMessage target that WebView2 supports and will support. It is the app's responsibility to
ensure that it sends the message to the correct content (i.e. apps should check that they are
checking the source of WebView2 before posting the message) and that for any file handle that it is
posting, it has the permission it expects the web content to use and be mindful about providing file
system access to web content in general (i.e. web content should not "ask" for access of a file path
or if it does, the app should validate that the asked path is one that the app should allow the 
web content to get access to).

# Examples
## Read the File path of a DOM File

Use this API with a DOM File object to be able to get the path of files dropped on WebView2. The
HTML and JavaScript snippets are part of the page content code running inside WebView2 and are used
by both the C++ and C# sample code below.

### Page code
```html
<!-- File upload location -->
<input type="file" id="files" />
```

```javascript
const input = document.getElementById('files');
input.addEventListener('change', function() {
    // Note that postMessageWithAdditionalObjects does not accept a single object,
    // but only accepts an ArrayLike object.
    // However, input.files is type FileList, which is already an ArrayLike object so
    // no conversion to array is needed.
    const currentFiles = input.files;
    chrome.webview.postMessageWithAdditionalObjects("FilesDropped", currentFiles);
});
```

### App code

#### Win32

```cpp
CHECK_FAILURE(m_webView->add_WebMessageReceived(
    Callback<ICoreWebView2WebMessageReceivedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) noexcept
        {
            wil::unique_cotaskmem_string message;
            CHECK_FAILURE(args->TryGetWebMessageAsString(&message));
            if (std::wstring(L"FilesDropped") == message.get())
            {  
                wil::com_ptr<ICoreWebView2WebMessageReceivedEventArgs2> args2 =
                    wil::com_ptr<ICoreWebView2WebMessageReceivedEventArgs>(args)
                        .query<ICoreWebView2WebMessageReceivedEventArgs2>();
                if (args2)
                {
                    wil::com_ptr<ICoreWebView2WebMessageObjectCollectionView>
                        objectsCollection;
                    CHECK_FAILURE(args2->get_AdditionalObjects(&objectsCollection));
                    unsigned int length;
                    CHECK_FAILURE(objectsCollection->get_Count(&length));
                    std::vector<std::wstring> paths;

                    for (unsigned int i = 0; i < length; i++)
                    {
                        wil::com_ptr<IUnknown> object;
                        CHECK_FAILURE(objectsCollection->GetValueAtIndex(i, &object));
                        // Note that objects can be null.
                        if (object)
                        {
                            wil::com_ptr<ICoreWebView2File> file =
                                object.query<ICoreWebView2File>();
                            if (file)
                            {
                                // Add the file to message to be sent back to webview
                                wil::unique_cotaskmem_string path;
                                CHECK_FAILURE(file->get_Path(&path));
                                paths.push_back(path.get());
                            }
                        }
                    }
                    ProcessPaths(paths);
                }

            }
            return S_OK;
        })
        .Get(),
    &m_webMessageReceivedToken));
```

#### .NET

```c#
webView.CoreWebView2.WebMessageReceived += WebView_WebMessageReceivedHandler;
void WebView_WebMessageReceivedHandler(object sender, CoreWebView2WebMessageReceivedEventArgs args)
{
    List<string> paths = new List<string>();
    foreach (var additionalObject in args.AdditionalObjects)
    {
        if (additionalObject is CoreWebView2File file)
        {
            paths.Add(file.Path);
        }
    }
    ProcessPaths(paths);
}
```

## Post a FileSystemHandle to the web content
Use this API to create a FileSystemHandle from the app and send it to the web content in WebView2.

### Web content code
```javascript
chrome.webview.addEventListener("message", function (e) {
    if (e.data.MyMessageType === "myFileHandleMessage") {
        var fileHandle = e.additionalObjects[0];
        if (fileHandle.kind === "file") {
            // run file code
        } else if (fileHandle.kind === "directory") {
            // run directory code
        }
    }
});
```

### App code

#### Win32

```cpp
wil::com_ptr<ICoreWebView2_21> webview21 =
    m_webView2.try_query<ICoreWebView2_21>();
if (!webview21) {
    // Feature not available in current runtime.
    return;
}
wil::com_ptr<ICoreWebView2Environment> environment =
    appWindow->GetWebViewEnvironment();
wil::com_ptr<ICoreWebView2Environment14> environment14 = 
    environment.try_query<ICoreWebView2Environment14>();
wil::com_ptr<ICoreWebView2FileSystemHandle> fileHandle;
CHECK_FAILURE(environment14->CreateWebFileSystemFileHandle(
    L"C:\\Users\\<user>\\Documents\\file.txt",
    COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION_READ_ONLY,
    &fileHandle));
wil::com_ptr<ICoreWebView2FileSystemHandle> directoryHandle;
CHECK_FAILURE(environment14->CreateWebFileSystemDirectoryHandle(
    L"C:\\Users\\<user>\\Documents",
    COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION_READ_WRITE,
    &directoryHandle));
wil::com_ptr<ICoreWebView2ObjectCollection> webObjectCollection;
IUnknown* webObjects[] = {fileHandle.get(), directoryHandle.get()};
CHECK_FAILURE(environment14->CreateObjectCollection(
    ARRAYSIZE(webObjects),
    webObjects,
    &webObjectCollection));
// Check the source to ensure that we are sending the message to the correct target.
wil::unique_cotaskmem_string source;
CHECK_FAILURE(m_webView->get_Source(&source));

static const wchar_t* expectedDomain = L"www.example.com";
wil::unique_bstr sourceDomain = GetDomainOfUri(source.get());

// Check the source to ensure the message is sent to the correct target content.
if (wcscmp(expectedDomain, sourceDomain) == 0)
{
    CHECK_FAILURE(webview_staging22->PostWebMessageAsJsonWithAdditionalObjects(
        L"{ \"MyMessageType\" : \"myFileHandleMessage\" }", webObjectCollection.get()));
}
```

#### .NET

```c#
// Check the source to ensure that we are sending the message to the correct target.
if (webView.CoreWebView2.Source.StartsWith("https://www.example.com/")) {
    webView.CoreWebView2.PostWebMessageAsJsonWithAdditionalObjects("{ \"MyMessageType\" : \"myFileHandleMessage\" }", new List<object>()
    {
        webView.CoreWebView2.Environment.CreateWebFileSystemFileHandle(
            "C:\\Users\\<user>\\Documents\\file.txt", 
            CoreWebView2FileSystemHandlePermission.ReadOnly),
        webView.CoreWebView2.Environment.CreateWebFileSystemDirectoryHandle(
            "C:\\Users\\<user>\\Documents", 
            CoreWebView2FileSystemHandlePermission.ReadWrite)
    });
}
```

## Post a File to the web content
Use this API to create a DOM File object from the app and send it to the web content in WebView2.

### Web content code
```javascript
chrome.webview.addEventListener("message", function (e) {
    if (e.data.MyMessageType === "myFileMessage") {
        var file = e.additionalObjects[0];
        // Open the file in a new window.
        var url = URL.createObjectURL(file);
        window.open(url);
    }
});
```

### App code

#### Win32

```cpp
wil::com_ptr<ICoreWebView2_21> webview21 =
    m_webView2.try_query<ICoreWebView2_21>();
if (!webview21) {
    // Feature not available in current runtime.
    return;
}
wil::com_ptr<ICoreWebView2Environment> environment =
    appWindow->GetWebViewEnvironment();
wil::com_ptr<ICoreWebView2Environment14> environment14 = 
    environment.try_query<ICoreWebView2Environment14>();
wil::com_ptr<ICoreWebView2File> file;
CHECK_FAILURE(environment14->CreateWebFile(
    L"C:\\Users\\<user>\\Documents\\file.txt", &file));
wil::com_ptr<ICoreWebView2ObjectCollection> webObjectCollection;
IUnknown* webObjects[] = {file.get()};
CHECK_FAILURE(environment14->CreateObjectCollection(
    ARRAYSIZE(webObjects),
    webObjects,
    &webObjectCollection));
// Check the source to ensure that we are sending the message to the correct target.
wil::unique_cotaskmem_string source;
CHECK_FAILURE(m_webView->get_Source(&source));

static const wchar_t* expectedDomain = L"www.example.com";
wil::unique_bstr sourceDomain = GetDomainOfUri(source.get());

// Check the source to ensure the message is sent to the correct target content.
if (wcscmp(expectedDomain, sourceDomain) == 0)
{
    CHECK_FAILURE(webview_staging22->PostWebMessageAsJsonWithAdditionalObjects(
        L"{ \"MyMessageType\" : \"myFileMessage\" }", webObjectCollectionView.get()));
}
```

#### .NET

```c#
// Check the source to ensure that we are sending the message to the correct target.
if (webView.CoreWebView2.Source.StartsWith("https://www.example.com/")) {
    webView.CoreWebView2.PostWebMessageAsJsonWithAdditionalObjects("{ \"MyMessageType\" : \"myFileMessage\" }", new List<object>()
    {
        webView.CoreWebView2.Environment.CreateWebFile(
            "C:\\Users\\<user>\\Documents\\file.txt")
    });
}
```

# API Details
## SDK API
```c#
/// Representation of a DOM
/// [File](https://developer.mozilla.org/docs/Web/API/File) object
/// passed via WebMessage. You can use this object to obtain the path of a
/// File dropped on WebView2.
/// \snippet ScenarioDragDrop.cpp DroppedFilePath
[uuid(f2c19559-6bc1-4583-a757-90021be9afec), object, pointer_default(unique)]
interface ICoreWebView2File : IUnknown {
  /// Get the absolute file path.
  [propget] HRESULT Path([out, retval] LPWSTR* value);
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

[v1_enum]
typedef enum COREWEBVIEW2_FILE_SYSTEM_HANDLE_KIND {
  /// FileSystemHandle is for a file (i.e. FileSystemFileHandle)
  COREWEBVIEW2_FILE_SYSTEM_HANDLE_KIND_FILE,
  /// FileSystemHandle is for a directory (i.e. FileSystemDirectoryHandle)
  COREWEBVIEW2_FILE_SYSTEM_HANDLE_KIND_DIRECTORY
} COREWEBVIEW2_FILE_SYSTEM_HANDLE_KIND;

[v1_enum]
typedef enum COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION {
  /// Read-only permission for FileSystemHandle
  COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION_READ_ONLY,
  /// Read and write permissions for FileSystemHandle
  COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION_READ_WRITE
} COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION;

/// Representation of a DOM
/// [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle)
/// object.
[uuid(0ecf4d7d-bbf6-4320-930e-82ff6cf2d8dc), object, pointer_default(unique)]
interface ICoreWebView2FileSystemHandle : IUnknown {
  /// The Kind of the FileSystemHandle. It can either be a file or a directory.
  [propget] HRESULT Kind([out, retval] COREWEBVIEW2_FILE_SYSTEM_HANDLE_KIND* value);

  /// The path to the FileSystemHandle.
  [propget] HRESULT Path([out, retval] LPWSTR* value);

  /// The permissions granted to the FileSystemHandle.
  [propget] HRESULT Permission([out, retval] COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION* value);
}

// Generic container of COM objects to pass to WebView2
[uuid(d2fba648-109f-401c-b701-44fd3ddfb440), object, pointer_default(unique)]
interface ICoreWebView2ObjectCollection : ICoreWebView2ObjectCollectionView {
  /// Removes the object at the specified index.
  HRESULT RemoveValueAtIndex([in] UINT32 index);

  /// Inserts the object at the specified index.
  HRESULT InsertValueAtIndex(
      [in] UINT32 index,
      [in] IUnknown* value);
}

[uuid(afae6f48-60d6-4b95-8b81-6f60d9c70f0b), object, pointer_default(unique)]
interface ICoreWebView2Environment14 : ICoreWebView2Environment13 {
  /// Create a `ICoreWebView2FileSystemHandle` object from a path that represents a Web 
  /// [FileSystemFileHandle](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle). 
  /// The `path` is the path pointed by the file and must be a syntactically correct fully qualified
  /// path, but it is not checked here whether it currently points to a file. If an invalid path is
  /// passed, an E_INVALIDARG will be returned and the object will fail to create. Any other state
  /// validation will be done when this handle is accessed from web content
  /// and will cause the DOM exceptions described in
  /// [FileSystemFileHandle methods](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle#instance_methods)
  /// if access operations fail.
  ///
  /// An app needs to be mindful that this object, when posted to the web content, provides it with unusual
  /// access to OS file system via the Web FileSystem API! The app should therefore only post objects
  /// for paths that it wants to allow access to the web content and it is not recommended that the web content
  /// "asks" for this path. The app should also check the source property of the target to ensure
  /// that it is sending to the web content of intended origin.
  ///
  /// Once the object is passed to web content, if the content is attempting a read,
  /// the file must be existing and available to read similar to a file chosen by
  /// [open file picker](https://developer.mozilla.org/docs/Web/API/Window/showOpenFilePicker),
  /// otherwise the read operation will
  /// [throw a DOM exception](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/getFile#exceptions).
  /// For write operations, the file does not need to exist as `FileSystemFileHandle` will behave
  /// as a file path chosen by 
  /// [save file picker](https://developer.mozilla.org/docs/Web/API/Window/showSaveFilePicker)
  /// and will create or overwrite the file, but the parent directory structure pointed 
  /// by the file must exist and an existing file must be available to write and delete
  /// or the write operation will
  /// [throw a DOM exception](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/createWritable#exceptions).
  /// 
  /// `Permission` property is used to specify whether the Handle should be created with a Read-only or
  /// Read-and-write web permission. For the `permission` value specified here, the DOM
  /// [PermissionStatus](https://developer.mozilla.org/docs/Web/API/PermissionStatus) property
  /// will be `[granted](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`
  /// and the unspecified permission will be
  /// `[prompt](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`. Therefore,
  /// the web content then does not need to call
  /// [requestPermission](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/requestPermission)
  /// for the permission that was specified before attempting the permitted operation,
  /// but if it does, the promise will immediately be resolved
  /// with 'granted' PermissionStatus without firing the WebView2 
  /// [PermissionRequested](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs)
  /// event or prompting the user for permission. Otherwise, `requestPermission` will behave as the
  /// status of permission is currently `prompt`, which means the `PermissionRequested` event will fire
  /// or the user will be prompted.
  /// Additionally, the app must have the same OS permissions that have propagated to the
  /// [WebView2 browser process](https://learn.microsoft.com/microsoft-edge/webview2/concepts/process-model)
  /// for the path it wishes to give the web content to read/write the file.
  /// Specifically, the WebView2 browser process will run in same user, package identity, and app
  /// container of the app, but other means such as security context impersonations do not get 
  /// propagated, so such permissions that the app has, will not be effective in WebView2.
  HRESULT CreateWebFileSystemFileHandle(
      [in] LPCWSTR path,
      [in] COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION permission,
      [out, retval] ICoreWebView2FileSystemHandle** fileSystemHandle);

    /// Create a `ICoreWebView2FileSystemHandle` object from a path that represents a Web 
    /// [FileSystemDirectoryHandle](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle). 
    /// The `path` is the path pointed by the directory and must be a syntactically correct fully qualified
    /// path, but it is not checked here whether it currently points to a directory. Any other state
    /// validation will be done when this handle is accessed from web content
    /// and will cause DOM exceptions if access operations fail. If an invalid path is
    /// passed, an E_INVALIDARG will be returned and the object will fail to create.
    ///
    /// An app needs to be mindful that this object, when posted to the web content, provides it with unusual
    /// access to OS file system via the Web FileSystem API! The app should therefore only post objects
    /// for paths that it wants to allow access to the web content and it is not recommended that the web content
    /// "asks" for this path. The app should also check the source property of the target to ensure
    /// that it is sending to the web content of intended origin.
    ///
    /// Once the object is passed to web content, the path must point to a directory as if it was chosen via
    /// [directory picker](https://developer.mozilla.org/docs/Web/API/Window/showDirectoryPicker)
    /// otherwise any IO operation done on the `FileSystemDirectoryHandle` will throw a DOM exception.
    /// 
    /// `Permission` property is used to specify whether the Handle should be created with a Read-only or
    /// Read-and-write web permission. For the `permission` value specified here, the Web
    /// [PermissionStatus](https://developer.mozilla.org/docs/Web/API/PermissionStatus) 
    /// will be `[granted](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`
    /// and the unspecified permission will be
    /// `[prompt](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`. Therefore,
    /// the web content then does not need to call
    /// [requestPermission](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/requestPermission)
    /// for the permission that was specified before attempting the permitted operation,
    /// but if it does, the promise will immediately be resolved
    /// with 'granted' PermissionStatus without firing the WebView2 
    /// [PermissionRequested](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs)
    /// event or prompting the user for permission. Otherwise, `requestPermission` will behave as the
    /// status of permission is currently `Prompt`, which means the `PermissionRequested` event will fire
    /// or the user will be prompted.
    /// Additionally, the app must have the same OS permissions that have propagated to the
    /// [WebView2 browser process](https://learn.microsoft.com/microsoft-edge/webview2/concepts/process-model)
    /// for the path it wishes to give the web content to make any operations on the directory.
    /// Specifically, the WebView2 browser process will run in same user, package identity, and app
    /// container of the app, but other means such as security context impersonations do not get 
    /// propagated, so such permissions that the app has, will not be effective in WebView2.
  HRESULT CreateWebFileSystemDirectoryHandle(
      [in] LPCWSTR path,
      [in] COREWEBVIEW2_FILE_SYSTEM_HANDLE_PERMISSION permission,
      [out, retval] ICoreWebView2FileSystemHandle** fileSystemHandle);

  /// Create a ICoreWebView2File from a file path. The object created is a
  /// representation of a DOM [File](https://developer.mozilla.org/docs/Web/API/File)
  /// object.
  /// The `path` is the full path pointed to the file. It must be a valid file 
  /// that the app has read access for and is available to read or creation will fail
  /// with E_INVALIDARG. Note that this is different from FileSystemHandle as
  /// file metadata properties are needed to create DOM File objects, but not for
  /// FileSystemHandles.
  /// (See Footnote 1)
  HRESULT CreateWebFile(
      [in] LPCWSTR path,
      [out, retval] ICoreWebView2File** file);

  /// Create a generic object collection. 
  HRESULT CreateObjectCollection(
      [in] UINT32 length,
      [in, size_is(length)] IUnknown** items,
      [out, retval] ICoreWebView2ObjectCollection** objectCollection);
}

[uuid(5220d097-c583-4115-8e08-1af2100338c2), object, pointer_default(unique)]
interface ICoreWebView2_24 : ICoreWebView2_23 {
  /// Same as PostWebMessageAsJson, but also has support for posting DOM objects
  /// to page content. The `additionalObjects` property in the DOM MessageEvent
  /// fired on the page content is a ArrayLike list of
  /// DOM objects that can be posted to the web content. Currently these can be
  /// the following types and `null`:
  /// | Win32             | DOM type    |
  /// |-------------------|-------------|
  /// | ICoreWebView2File | [File](https://developer.mozilla.org/docs/Web/API/File) |
  /// | ICoreWebView2FileSystemHandle | [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle) |
  /// | nullptr           | null        |
  /// The objects are posted the to web content following the structured-clone
  /// semantics, meaning only objects that can be cloned can be posted.
  /// They will also behave as if they had been created by the web content they are
  /// posted to. For example, if a FileSystemFileHandle is posted to a web content
  /// it can only be re-transferred via postMessage to other web content
  /// [with the same origin](https://fs.spec.whatwg.org/#filesystemhandle).
  /// Warning: An app needs to be mindful when using this API to post DOM objects
  /// as this API provides the web content with unusual access to sensitive Web
  /// Platform features such as filesystem access! Similar to PostWebMessageAsJson
  /// the app should check the `Source` of WebView2 right before posting the message
  /// to ensure the message and objects will only be sent to the target web content
  /// that it expects to receive the DOM objects.
  HRESULT PostWebMessageAsJsonWithAdditionalObjects([in] LPCWSTR webMessageAsJson, [in] ICoreWebView2ObjectCollectionView* additionalObjects);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2FileSystemHandlePermission
    {
        /// Read-only permission for FileSystemHandle
        ReadOnly = 0,
        /// Read and write permissions for FileSystemHandle
        ReadWrite = 1,
    };
    enum CoreWebView2FileSystemHandleKind
    {
        /// FileSystemHandle is for a file (i.e. FileSystemFileHandle)
        File = 0,
        /// FileSystemHandle is for a directory (i.e. FileSystemDirectoryHandle)
        Directory = 1,
    };

    /// Representation of a DOM
    /// [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle)
    /// object.
    runtimeclass CoreWebView2FileSystemHandle
    {
        /// The Kind of the FileSystemHandle. It can either be a file or a directory.
        CoreWebView2FileSystemHandleKind Kind { get; };

        /// The path to the FileSystemHandle.
        String Path { get; };

        /// The permissions granted to the FileSystemHandle.
        CoreWebView2FileSystemHandlePermission Permission { get; };
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
        /// - CoreWebView2File
        /// - CoreWebView2FileSystemHandle
        /// Cast the object to the native type to access its specific properties.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2WebMessageReceivedEventArgs2")]
        {
            IVectorView<Object> AdditionalObjects { get; };
        }
    }

    runtimeclass CoreWebView2
    {
        ...
        /// Same as `PostWebMessageAsJson`, but also has support for posting DOM objects
        /// to page content. The `additionalObjects` property in the DOM MessageEvent
        /// fired on the page content is a ArrayLike list of
        /// DOM objects that can be posted to the web content. Currently the
        /// following types can be posted to DOM:
        /// | .NET/WinRT       | DOM type    |
        /// |------------------|-------------|
        /// | CoreWebView2File | [File](https://developer.mozilla.org/docs/Web/API/File] |
        /// | CoreWebView2FileSystemHandle | [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle) |
        /// | null             | null        |
        /// The objects are posted the to web content following the structured-clone
        /// semantics, meaning only objects that can be cloned can be posted.
        /// They will also behave as in they are created on the web content they are
        /// posted to. For example, if a FileSystemFileHandle is posted to a web content
        /// it can only be posted via postMessage to other web content with the same origin.
        PostWebMessageAsJsonWithAdditionalObjects(string webMessageAsJson, IVectorView<Object> additionalObjects);
    }

    runtimeclass CoreWebView2Environment
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment22")]
        {
            /// Creates a `CoreWebView2FileSystemHandle` object from a path that represents a Web 
            /// [FileSystemFileHandle](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle). 
            /// The `path` is the path pointed by the file and must be a syntactically correct fully qualified
            /// path but it is not checked here whether it currently points to a file.
            /// If an invalid path is passed, an `InvalidArgumentException` will be thrown and the object will fail to
            /// create. Any other state validation will be done when this handle is accessed from web content
            /// and will cause the DOM exceptions described in
            /// [FileSystemFileHandle methods](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle#instance_methods)
            /// if access operations fail.
            ///
            /// An app needs to be mindful that this object, when posted to the web content, provides it with unusual
            /// access to OS file system via the Web FileSystem API! The app should therefore only post objects
            /// for paths that it wants to allow access to the web content and it is not recommended that the web content
            /// "asks" for this path. The app should also check the source property of the target to ensure
            /// that it is sending to the web content of intended origin.
            ///
            /// Once the object is passed to web content, if the content is attempting a read,
            /// the file must be existing and available to read similar to a file chosen by
            /// [open file picker](https://developer.mozilla.org/docs/Web/API/Window/showOpenFilePicker),
            /// otherwise the read operation will
            /// [throw a DOM exception](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/getFile#exceptions).
            /// For write operations the file does not
            /// need to exist as `FileSystemFileHandle` will behave more like a file path chosen by 
            /// [save file picker](https://developer.mozilla.org/docs/Web/API/Window/showSaveFilePicker)
            /// and will create or overwrite the file, but the parent directory structure pointed 
            /// by the file must exist and an existing file must be available to write and delete
            /// or the write operation will
            /// [throw a DOM exception](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/createWritable#exceptions).
            /// 
            /// `Permission` property is used to specify whether the Handle should be created with a Read-only or
            /// Read-and-write web permission. For the `permission` value specified here, the Web
            /// [PermissionStatus](https://developer.mozilla.org/docs/Web/API/PermissionStatus) 
            /// will be `[granted](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`
            /// and the unspecified permission will be
            /// `[prompt](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`. Therefore,
            /// the web content then does not need to call
            /// [requestPermission](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/requestPermission)
            /// for the permission that was specified before attempting the permitted operation,
            /// but if it does, the promise will immediately be resolved
            /// with 'granted' PermissionStatus without firing the WebView2 
            /// [PermissionRequested](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs)
            /// event or prompting the user for permission. Otherwise, `requestPermission` will behave as the
            /// status of permission is currently `prompt`, which means the PermissionRequested event will fire
            /// or the user will be prompted.
            /// Additionally, the app must have the same OS permissions that have propagated to the
            /// [WebView2 browser process](https://learn.microsoft.com/microsoft-edge/webview2/concepts/process-model)
            /// for the path it wishes to give the web content to read/write the file.
            /// Specifically, the WebView2 browser process will run in same user, package identity, and app
            /// container of the app, but other means such as security context impersonations do not get 
            /// propagated, so such permissions that the app has, will not be effective in WebView2.
            CoreWebView2FileSystemHandle CreateWebFileSystemFileHandle(String path, CoreWebView2FileSystemHandlePermission permission);

            /// Create a `CoreWebView2FileSystemHandle` from a path that represents a Web 
            /// [FileSystemDirectoryHandle](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle). 
            /// If an invalid path is passed, an E_INVALIDARG will be returned and the object will fail to
            /// create. Any other state validation will be done when this handle is accessed from web content
            /// and will cause DOM exceptions described in
            /// [FileSystemDirectoryHandle methods](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle#instance_methods)
            /// if access operations fail.
            /// If an invalid path is
            /// passed, an `InvalidArgumentException` will be thrown and the object will fail to create.
            ///
            /// An app needs to be mindful that this object, when posted to the web content, provides it with unusual
            /// access to OS file system via the Web FileSystem API! The app should therefore only post objects
            /// for paths that it wants to allow access to the web content and it is not recommended that the web content
            /// "asks" for this path. The app should also check the source property of the target to ensure
            /// that it is sending to the web content of intended origin.
            ///
            /// Once the object is passed to web content, the path must point to a directory as if it was chosen via
            /// [directory picker](https://developer.mozilla.org/docs/Web/API/Window/showDirectoryPicker)
            /// otherwise any IO operation done on the `FileSystemDirectoryHandle` will throw a DOM exception.
            /// 
            /// `Permission` property is used to specify whether the Handle should be created with a Read-only or
            /// Read-and-write web permission. For the `permission` value specified here, the Web
            /// [PermissionStatus](https://developer.mozilla.org/docs/Web/API/PermissionStatus) 
            /// will be `[granted](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`
            /// and the unspecified permission will be
            /// `[prompt](https://developer.mozilla.org/docs/Web/API/PermissionStatus/state)`. Therefore,
            /// the web content then does not need to call
            /// [requestPermission](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/requestPermission)
            /// for the permission that was specified before attempting the permitted operation,
            /// but if it does, the promise will immediately be resolved
            /// with 'granted' PermissionStatus without firing the WebView2 
            /// [PermissionRequested](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/icorewebview2permissionrequestedeventargs)
            /// event or prompting the user for permission. Otherwise, `requestPermission` will behave as the
            /// status of permission is currently `prompt`, which means the PermissionRequested event will fire
            /// or the user will be prompted.
            /// Additionally, the app must have the same OS permissions that have propagated to the
            /// [WebView2 browser process](https://learn.microsoft.com/microsoft-edge/webview2/concepts/process-model)
            /// for the path it wishes to give the web content to make any operations on the directory.
            /// Specifically, the WebView2 browser process will run in same user, package identity, and app
            /// container of the app, but other means such as security context impersonations do not get 
            /// propagated, so such permissions that the app has, will not be effective in WebView2.
            CoreWebView2FileSystemHandle CreateWebFileSystemDirectoryHandle(String path, CoreWebView2FileSystemHandlePermission permission);

            /// Create a `CoreWebView2File` from a file path. The object created is a
            /// representation of a DOM [File](https://developer.mozilla.org/docs/Web/API/File)
            /// object.
            /// The `path` is the full path pointed to the file. It must be a valid file 
            /// that the app has read access for and is available to read or this will throw
            /// InvalidArgumentException.
            /// (See Footnote 1)
            CoreWebView2File CreateWebFile(String Path);
        }
    }
}
```
## JS API for page content
We named the JS API `chrome.webview.postMessageWithAdditionalObjects`. We considered making it an
overload of the existing `chrome.webview.postMessage(message)`, but that method is patterned after
the existing `MessagePort.postMessage(message, transferList)` DOM method and we're worried about
confusion or future compat mixing up the `additionalObjects` array with the `transferList` array.

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
     * representations in WebView2. This parameter needs to be ArrayLike.
     * The following DOM types are mapped to native:
     * | DOM       | Win32       | .NET/WinRT |
     * |-----------|-------------|------------|
     * | [File](https://developer.mozilla.org/docs/Web/API/File] | ICoreWebView2File | CoreWebView2File |
     * | [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle) | ICoreWebView2FileSystemHandle | CoreWebView2FileSystemHandle |
     * | null      | nullptr     | null       |
     * | undefined | nullptr     | null       |
     * If an invalid or unsupported object is passed via this API, an exception
     * will be thrown and the message will fail to post.
     * @example
     * Post a message with File objects from input element to the CoreWebView2:
     * ```javascript
     * const input = document.getElementById('files');
     * input.addEventListener('change', function() {
     *    // Note that postMessageWithAdditionalObjects does not accept a single object,
     *    // but only accepts an ArrayLike object.
     *    // However, input.files is type FileList, which is already an ArrayLike object so
     *    // no conversion to array is needed.
     *    const currentFiles = input.files;
     *    chrome.webview.postMessageWithAdditionalObjects("FilesDropped",
     *        currentFiles);
     * });
     * ```
     */
    postMessageWithAdditionalObjects(message: any, additionalObjects: ArrayLike<any>) : void;
}

interface WebViewMessageEvent extends MessageEvent {
    /**
     * The source of the event is the `chrome.webview` object.
     */
    source: WebView;

    /**
     * Additional DOM objects that are sent via PostJSONMessageWithAdditionalObjects.
     * These objects can be of following types:
     * | DOM       | Win32       | .NET/WinRT |
     * |-----------|-------------|------------|
     * | [File](https://developer.mozilla.org/docs/Web/API/File] | ICoreWebView2File | CoreWebView2File |
     * | [FileSystemHandle](https://developer.mozilla.org/docs/Web/API/FileSystemHandle) | ICoreWebView2FileSystemHandle | CoreWebView2FileSystemHandle |
     * | null      | nullptr     | null       |
     * | undefined | nullptr     | null       |
     */
    additionalObjects: ArrayLike<any>
}

// Matching `interface MessagePort` from lib.dom.d.ts for messaging APIs
/**
 * Events of the `WebView` interface.
 */
interface WebViewEventMap {
    "message": WebViewMessageEvent;
    ...
}
```
