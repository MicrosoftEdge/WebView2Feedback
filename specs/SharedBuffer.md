Shared Buffer Between Native Application Code and Script
===

# Background
For some advanced scenarios, there is a need to exchange large amounts of data
between the WebView2 application process and trusted web pages that are considered
as part of the app. Some examples:
- Web page generates a large amount of data, and passes it to the native side to be
  further processed or fed to other parts of the app or OS. For example, the web page
  generates 100MBs of high DPI images to be printed and needs to pass that to the native
  code to print. See https://github.com/MicrosoftEdge/WebView2Feedback/issues/89.
- Native side generates a large amount of data for the web side to consume. The data
  might or might not come directly from files. For example the native side has generated
  terabytes of data to produce different graphs on the web side.
  See https://github.com/MicrosoftEdge/WebView2Feedback/issues/1005.

To support these scenarios, we are adding an Edge WebView2 API to support sharing
buffers between the WebView2 host app process and WebView2 renderer process, based
on shared memory from the OS.

The application code can use the APIs to create a shared buffer object, and share to
scripts as [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer) object.
Then both the native application code and the script will be able to access the same memory.

# Conceptual pages (How To)

Besides using the memory address directly, the shared buffer object can be accessed
from native side via an IStream* object that you can get from the shared buffer object.

When the application code calls `PostSharedBufferToScript`, the script side will
receive a `sharedbufferreceived` event that you can get from it the buffer as an `ArrayBuffer` object.
After getting the shared buffer, it can access it the same way as any other
ArrayBuffer object, including transferring to a web worker to process the data on
the worker thread.

As shared buffer normally represent a large memory, instead of waiting for garbage
collection to release the memory along with the owning objects, the application
should try to release the buffer as soon as it doesn't need access to it.
This can be done by calling Close() method on the shared buffer object, or
`chrome.webview.releaseBuffer` from script.

As the memory could contain sensitive information and corrupted memory could crash
the application, the application should only share buffer with trusted sites.

The application can use other messaging channel like `PostWebMessageAsJson` and
`chrome.webview.postMessage` to inform the other side the desire to have a shared
buffer and the status of the buffer (like data is produced or consumed).

# Examples

The example below illustrates how to send data from application to script for one time read only consumption.

The script code will look like this:
```
        window.onload = function () {
            window.chrome.webview.addEventListener("sharedbufferreceived", e => {
                SharedBufferReceived(e);
            });
        }

        function SharedBufferReceived(e) {
            if (e.additionalData && e.additionalData.contosoBufferKind == "contosoDisplayBuffer") {
                let displayBuffer = e.getBuffer();
                // Consume the data from the buffer (in the form of an ArrayBuffer)
                let displayBufferArray = new Uint8Array(displayBuffer);
                DisplaySharedBufferData(displayBufferArray);
                // Release the buffer after consuming the data.
                chrome.webview.releaseBuffer(displayBuffer);
            }
        }
```
## Win32 C++
```cpp

        wil::com_ptr<ICoreWebView2SharedBuffer> sharedBuffer;
        CHECK_FAILURE(m_webviewEnvironment->CreateSharedBuffer(dataSize, &sharedBuffer));
        BYTE* buffer;
        CHECK_FAILURE(sharedBuffer->get_Buffer(&buffer));
        // Fill buffer with data.
        memcpy_s(buffer, dataSize, data, dataSize);
        PCWSTR additionalDataAsJson = L"{\"contosoBufferKind\":\"contosoDisplayBuffer\"}";
        m_webView->PostSharedBufferToScript(
           sharedBuffer.get(), COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_ONLY, additionalDataAsJson);

        // The buffer automatically releases any resources if all references to it are released.
        // As we are doing here, you could also explicitly close it when you don't access the buffer
        // any more.to ensure that the resource is released timely even if there are some reference got leaked.
        sharedBuffer->Close();
        
```
## .NET
```c#
      using (CoreWebView2SharedBuffer sharedBuffer = WebViewEnvironment.CreateSharedBuffer(dataSize))
      {
          // Fill buffer with data.
          unsafe
          {
              byte* buffer = (byte*)(sharedBuffer.Buffer.ToPointer());
              ulong dataToCopy = dataSize;
              while (dataToCopy-- > 0) {
                  *buffer++ = *data++;
              }
         }
          string additionalDataAsJson = "{\"contosoBufferKind\":\"contosoDisplayBuffer\"}";
           m_webview.PostSharedBufferToScript(sharedBuffer, CoreWebView2SharedBufferAccess.ReadOnly, additionalDataAsJson);
      }
```
## WinRT
```c#
      using (CoreWebView2SharedBuffer sharedBuffer = WebViewEnvironment.CreateSharedBuffer(dataSize))
      {
          // Fill buffer with data.
          unsafe
          {
              using (IMemoryBufferReference reference = sharedBuffer.Buffer)
              {
                  byte* buffer;
                  uint capacity;
                  ((IMemoryBufferByteAccess)reference).GetBuffer(out buffer, out capacity);
                  byte* buffer = (byte*)(sharedBuffer.Buffer.ToPointer());
                  ulong dataToCopy = dataSize;
                  while (dataToCopy-- > 0) {
                      *buffer++ = *data++;
                  }
              }
         }
          string additionalDataAsJson = "{\"contosoBufferKind\":\"contosoDisplayBuffer\"}";
           m_webview.PostSharedBufferToScript(sharedBuffer, CoreWebView2SharedBufferAccess.ReadOnly, additionalDataAsJson);
      }
```

The example below illustrates how to use a shared buffer to send data from application to script in an iframe multiple times.

The script code will look like this:
```
        let displayBuffer;
        let displayBufferArray;
        window.onload = function () {
            window.chrome.webview.addEventListener("sharedbufferreceived", e => {
                if (e.additionalData && e.additionalData.contosoBufferKind == "contosoDisplayBuffer") {
                    // Release potential previous buffer to ensure that the underlying resource can be released timely.
                    if (displayBuffer)
                        chrome.webview.releaseBuffer(displayBuffer);
                    // Hold the shared buffer and the typed array view of it.
                    displayBuffer = e.getBuffer();
                    displayBufferArray = new Uint8Array(displayBuffer);
                }
            });
            window.chrome.webview.addEventListener("message", e => {
                if (e.data == "DisplayBufferUpdated") {
                    // Consume the updated data
                    DisplaySharedBufferData(displayBufferArray);
                    // Notify the application that the data has been consumed
                    window.chrome.webview.postMessage("DisplayBufferConsumed");
                } else if (e.data = "ReleaseDisplayBuffer") {
                    // Release the buffer, don't need it anymore.
                    chrome.webview.releaseBuffer(displayBuffer);
                    // Clear variables holding the buffer.
                    displayBuffer = undefined;
                    displayBufferArray = undefined;
                }
            });
        }

```
## Win32 C++
```cpp

        void EnsureSharedBuffer(UINT64 bufferSize)
        {
            if (m_sharedBuffer && m_bufferSize >= bufferSize)
                return;
            // Close previous buffer if we have one.
            if (m_sharedBuffer)
                m_sharedBuffer->Close();
            CHECK_FAILURE(webviewEnvironment->CreateSharedBuffer(bufferSize, &m_sharedBuffer));
            CHECK_FAILURE(m_sharedBuffer->get_Size(&m_bufferSize);
            PCWSTR additionalDataAsJson = L"{\"contosoBufferKind\":\"contosoDisplayBuffer\"}";
            m_webviewFrame->PostSharedBufferToScript(
                m_sharedBuffer.get(), COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_ONLY, additionalDataAsJson);
        }
        
        void ReleaseDisplayBuffer() 
        {
            if (m_sharedBuffer)
            {
                // Explicitly Close the shared buffer so that we don't have to wait for
                // GC for the underlying shared memory to be released.
                m_sharedBuffer->Close();
                m_sharedBuffer = nullptr;
                CHECK_FAILURE(m_webviewFrame->PostWebMessage(L"ReleaseDisplayBuffer"));
            }
        }

        void UpdateDisplayBuffer() 
        {
            EnsureSharedBuffer(m_dataSize);
            // Fill data into the shared memory via IStream.
            wil::com_ptr<IStream> stream;
            CHECK_FAILURE(sharedBuffer->OpenStream(&stream));
            // The sample code assumes that the data itself contains info about the size
            // of data to consume and we don't have to add it into the shared buffer or
            // as part of the web message.
            CHECK_FAILURE(stream->Write(m_data, m_dataSize, nullptr));
            CHECK_FAILURE(m_webviewFrame->PostWebMessage(L"DisplayBufferUpdated"));
        }

        void OnFrameWebMessageReceived(PCWSTR message) 
        {
            std::wstring DisplayBufferConsumedMessage(L"DisplayBufferConsumed");
            if (DisplayBufferConsumedMessage == message) 
            {
                if (m_hasMoreDataToSend)
                {
                    UpdateDisplayBuffer();
                }
                else
                {
                    ReleaseDisplayBuffer();
                }
            }
        }
        
```
## WinRT and .NET
```c#
        void EnsureSharedBuffer(ulong bufferSize)
        {
            if (m_sharedBuffer && m_sharedBuffer.Size >= bufferSize)
                return;
            // Dispose previous buffer if we have one.
            if (m_sharedBuffer)
                m_sharedBuffer.Dispose();
            m_sharedBuffer = WebviewEnvironment.CreateSharedBuffer(bufferSize);
            string additionalDataAsJson = "{\"contosoBufferKind\":\"contosoDisplayBuffer\"}";
            m_webviewFrame.PostSharedBufferToScript(
                m_sharedBuffer, CoreWebView2SharedBufferAccess.ReadOnly, additionalDataAsJson);
        }
        
        void ReleaseDisplayBuffer() 
        {
            if (m_sharedBuffer)
            {
                // Explicitly dispose the shared buffer so that we don't have to wait for
                // GC for the underlying shared memory to be released.
                m_sharedBuffer.Dispose();
                m_sharedBuffer = null;
                CHECK_FAILURE(m_webviewFrame.PostWebMessage("ReleaseDisplayBuffer"));
            }
        }

        void UpdateDisplayBuffer() 
        {
            EnsureSharedBuffer(m_dataSize);
            // Fill data using access Stream
            using (Stream stream = m_sharedBuffer.OpenStream())
            {
                using (StreamWriter writer = new StreamWriter(stream))
                {
                    writer.Write(m_data);
                }
            }
        }

        void OnFrameWebMessageReceived(string message) 
        {
            if (message == "DisplayBufferConsumed") 
            {
                if (m_hasMoreDataToSend)
                {
                    UpdateDisplayBuffer();
                }
                else
                {
                    ReleaseDisplayBuffer();                    
                }
            }
        }
```

# API Details
## Win32 C++
```
interface ICoreWebView2Environment11 : IUnknown {
  /// Create a shared memory based buffer with the specified size in bytes.
  /// The buffer can be shared with web contents in WebView by calling
  /// `PostSharedBufferToScript` on `CoreWebView2` or `CoreWebViewFrame` object.
  /// Once shared, the same content of the buffer will be accessible from both
  /// the app process and script in WebView. Modification to the content will be visible
  /// to all parties that have access to the buffer.
  /// The shared buffer is presented to the script as ArrayBuffer. All JavaScript APIs
  /// that works for ArrayBuffer including Atomics APIs can be used on it.
  HRESULT CreateSharedBuffer(
    [in] UINT64 size,
    [out, retval] ICoreWebView2SharedBuffer** shared_buffer);
}

interface ICoreWebView2SharedBuffer : IUnknown {
  /// The size of the shared buffer in bytes.
  [propget] HRESULT Size([out, retval] UINT64* value);

  /// The memory address of the shared buffer.
  [propget] HRESULT Buffer([out, retval] BYTE** value);

  /// Get an IStream object that can be used to access the shared buffer.
  HRESULT OpenStream([out, retval] IStream** value);

  /// Returns a handle to the file mapping object that backs this shared buffer.
  /// The returned handle is owned by the shared buffer object. You should not
  /// call CloseHandle on it.
  /// Normal app should use `Buffer` or `OpenStream` to get memory address
  /// or IStream object to access the buffer.
  /// For advanced scenarios, you could use file-mapping APIs to obtain other views
  /// or duplicate this handle to another application process and create a view from
  /// the duplicated handle in that process to access the buffer from that separate process.
  [propget] HRESULT FileMappingHandle([out, retval] HANDLE* value);
  
  /// Release the backing shared memory. The application should call this API when no
  /// access to the buffer is needed any more, to ensure that the underlying resources
  /// are released timely even if the shared buffer object itself is not released due to
  /// some leaked reference.
  /// After the shared buffer is closed, the buffer address and file mapping handle previously
  /// obtained becomes invalid and cannot be used anymore. Accessing properties of the object
  /// will fail with `RO_E_CLOSED`. Operations like Read or Write on the IStream objects returned
  /// from `OpenStream` will fail with `RO_E_CLOSED`. `PostSharedBufferToScript` will also
  /// fail with `RO_E_CLOSED`.
  ///
  /// The script code should call `chrome.webview.releaseBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access the shared buffer any more.
  /// When script tries to access the buffer after calling `chrome.webview.releaseBuffer`,
  /// JavaScript `TypeError` exception will be raised complaining about accessing a
  /// detached ArrayBuffer, the same exception when trying to access a transferred ArrayBuffer.
  ///
  /// Closing the buffer object on native side doesn't impact access from Script and releasing
  /// the buffer from script doesn't impact access to the buffer from native side.
  /// The underlying shared memory will be released by the OS when both native and script side
  /// release the buffer.
  HRESULT Close();
}

typedef enum COREWEBVIEW2_SHARED_BUFFER_ACCESS {
    // The script only has read access to the shared buffer
    COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_ONLY,
    // The script has read and write access to the shared buffer
    COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_WRITE
} COREWEBVIEW2_SHARED_BUFFER_ACCESS;

interface ICoreWebView2_14 : IUnknown {
  /// Share a shared buffer object with script of the main frame in the WebView.
  /// The script will receive a `SharedBufferReceived` event from chrome.webview.
  /// The event arg for that event will have the following methods and properties:
  ///   `getBuffer()`: return an ArrayBuffer object with the backing content from the shared buffer.
  ///   `additionalData`: an object as the result of parsing `additionalDataAsJson` as JSON string.
  ///           This property will be `undefined` if `additionalDataAsJson` is nullptr or empty string.
  ///   `source`: with a value set as `chrome.webview` object.
  /// If a string is provided as `additionalDataAsJson` but it is not a valid JSON string,
  /// the API will fail with `E_INVALIDARG`.
  /// If `access` is COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_ONLY, the script will only have read access to the buffer.
  /// If the script tries to modify the content in a read only buffer, it will cause an access
  /// violation in WebView renderer process and crash the renderer process.
  /// If the shared buffer is already closed, the API will fail with `RO_E_CLOSED`.
  /// 
  /// The script code should call `chrome.webview.releaseBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access to the shared buffer any more.
  /// The application can post the same shared buffer object to multiple web pages or iframes, or
  /// post to the same web page or iframe multiple times. Each `PostSharedBufferToScript` will
  /// create a separate ArrayBuffer object with its own view of the memory and is separately
  /// released. The underlying shared memory will be released when all the views are released.
  ///
  /// Sharing a buffer to script has security risk. You should only share buffer with trusted site.
  /// If a buffer is shared to a untrusted site, possible sensitive information could be leaked.
  /// If a buffer is shared as modifiable by the script and the script modifies it in an unexpected way,
  /// it could result in corrupted data that might even crash the application. 
  HRESULT PostSharedBufferToScript(
    [in] ICoreWebView2SharedBuffer* sharedBuffer,
    [in] COREWEBVIEW2_SHARED_BUFFER_ACCESS access,
    [in] LPCWSTR additionalDataAsJson);
}

interface ICoreWebView2Frame4 : IUnknown {
  /// Share a shared buffer object with script of the iframe in the WebView.
  /// The script will receive a `SharedBufferReceived` event from chrome.webview.
  /// The event arg for that event will have the following methods and properties:
  ///   `getBuffer()`: return an ArrayBuffer object with the backing content from the shared buffer.
  ///   `additionalData`: an object as the result of parsing `additionalDataAsJson` as JSON string.
  ///           This property will be `undefined` if `additionalDataAsJson` is nullptr or empty string.
  ///   `source`: with a value set as `chrome.webview` object.
  /// If a string is provided as `additionalDataAsJson` but it is not a valid JSON string,
  /// the API will fail with `E_INVALIDARG`.
  /// If `access` is COREWEBVIEW2_SHARED_BUFFER_ACCESS_READ_ONLY, the script will only have read access to the buffer.
  /// If the script tries to modify the content in a read only buffer, it will cause an access
  /// violation in WebView renderer process and crash the renderer process.
  /// If the shared buffer is already closed, the API will fail with `RO_E_CLOSED`.
  /// 
  /// The script code should call `chrome.webview.releaseBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access to the shared buffer any more.
  /// The application can post the same shared buffer object to multiple web pages or iframes, or
  /// post to the same web page or iframe multiple times. Each `PostSharedBufferToScript` will
  /// create a separate ArrayBuffer object with its own view of the memory and is separately
  /// released. The underlying shared memory will be released when all the views are released.
  ///
  /// Sharing a buffer to script has security risk. You should only share buffer with trusted site.
  /// If a buffer is shared to a untrusted site, possible sensitive information could be leaked.
  /// If a buffer is shared as modifiable by the script and the script modifies it in an unexpected way,
  /// it could result in corrupted data that might even crash the application. 
  HRESULT PostSharedBufferToScript(
    [in] ICoreWebView2SharedBuffer* sharedBuffer,
    [in] COREWEBVIEW2_SHARED_BUFFER_ACCESS access,
    [in] LPCWSTR additionalDataAsJson);
}

```

## .NET
```c#
namespace Microsoft.Web.WebView2.Core
{

    class CoreWebView2Environment
    {
        public CoreWebView2SharedBuffer CreateSharedBuffer(ulong size);
    }

    class CoreWebView2SharedBuffer : System.IDisposable
    {
        public ulong Size { get; };
        
        /// The raw memory address of the buffer.
        /// You can cast it to pointer to real data types like byte* to access the memory
        /// from `unsafe` code region.
        /// Normal app should use `OpenStream` to get a Stream object to access the buffer.
        public IntPtr Buffer { get; };
        
        /// The native file mapping handle of the shared memory of the buffer.
        /// Normal app should use `OpenStream` to get a Stream object to access the buffer.
        /// For advanced scenario, you could use native APIs to duplicate this handle to
        /// another application process and create a mapping from the duplicated handle in
        /// that process to access the buffer from that separate process.
        public System.Runtime.InteropServices.SafeHandle FileMappingHandle { get; };
        
        public Stream OpenStream();
        
        void Close();
    }
    
    enum CoreWebView2SharedBufferAccess
    {
        ReadOnly = 0,
        ReadWrite = 1
    }

    runtimeclass CoreWebView2
    {
        public void PostSharedBufferToScript(
            CoreWebView2SharedBuffer sharedBuffer, CoreWebView2SharedBufferAccess access, string additionalDataAsJson);
    }
    
    class CoreWebView2Frame
    {
        public void PostSharedBufferToScript(
            CoreWebView2SharedBuffer sharedBuffer, CoreWebView2SharedBufferAccess access, string additionalDataAsJson);
    }
}

```
## WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2Environment
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment11")]
        {
            CoreWebView2SharedBuffer CreateSharedBuffer(UInt64 size);
        }
    }

    runtimeclass CoreWebView2SharedBuffer : Windows.Foundation.IClosable
    {
        UInt64 Size { get; };
        
        Windows.Storage.Streams.IRandomAccessStream OpenStream();
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2SharedBuffer_Manual")]
        {
            /// A reference to the underlying memory of the shared buffer.
            /// You can get IMemoryBufferByteAccess from the object to access the memory as an array of bytes.
            /// See [I](https://docs.microsoft.com/en-us/uwp/api/windows.foundation.imemorybufferreference?view=winrt-22621)
            /// for more details.
            Windows.Foundation.IMemoryBufferReference Buffer { get; };
        }
        
        // Note that we are not exposing Handle from WinRT API.
    }
    
    enum CoreWebView2SharedBufferAccess
    {
        ReadOnly = 0,
        ReadWrite = 1
    }

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_14")]
        {
            void PostSharedBufferToScript(
                CoreWebView2SharedBuffer sharedBuffer, CoreWebView2SharedBufferAccess access, String additionalDataAsJson);
        }
    }
    
    runtimeclass CoreWebView2Frame
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame4")]
        {
            void PostSharedBufferToScript(
                CoreWebView2SharedBuffer sharedBuffer, CoreWebView2SharedBufferAccess access, String additionalDataAsJson);
        }
    }
}

```
