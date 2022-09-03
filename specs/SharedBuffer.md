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
  terrabytes of data to produce different graphs on the web side.
  See https://github.com/MicrosoftEdge/WebView2Feedback/issues/1005.

To support these scenarios, we are adding an Edge WebView2 API to support sharing
buffers between the WebView2 host app process and WebView2 renderer process, based
on shared memory from the OS.

The application code can use the APIs to create a shared buffer object, and share to
scripts as [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer) object.
Then both the native application code and the script will be able to access the same memory.

# Conceptual pages (How To)

Besides using the memory address directly, the shared buffer object can be accessed
from native side via an IStream* object that you can get from the shared object.

When the application code calls `PostSharedBufferToScript`, the script side will
receive a `SharedBufferReceived` event containing the buffer as an `ArrayBuffer` object.
After receiving the shared buffer object, it can access it the same way as any other
ArrayBuffer object, including transering to a web worker to process the data on
the worker thread.

As shared buffer normally represent a large memory, instead of waiting for garbage
collection to release the memory along with the owning objects, the application
should try to release the buffer as soon as it doesn't need access to it.
This can be done by calling Close() method on the shared buffer object, or
`chrome.webview.releaseSharedBuffer` from script.

As the memory could contain sensitive information and corrupted memory could crash
the application, the application should only share buffer with trusted sites.

The application can use other messaging channel like `PostWebMessageAsJson` and
`chrome.webview.postMessage` to inform the other side the desire to have a shared
buffer and the status of the buffer (data is produced or consumed).

# Examples

The example below illustrates how to send data from application to script for one time read only consumption.

The script code will look like this:
```
        window.onload = function () {
            window.chrome.webview.addEventListener("SharedBufferReceived", e => {
                SharedBufferReceived(e);
            });
        }

        function SharedBufferReceived(e) {
            if (e.data && e.data.read_only) {
                // This is the one time read only buffer
                let one_time_shared_buffer = e.sharedBuffer;
                // Consume the data from the buffer
                DisplaySharedBufferData(one_time_shared_buffer);
                // Release the buffer after consuming the data.
                chrome.webview.releaseSharedBuffer(one_time_shared_buffer);
            }
        }
```
## Win32 C++
```cpp

        wil::com_ptr<ICoreWebView2Environment11> environment;
        CHECK_FAILURE(
            m_appWindow->GetWebViewEnvironment()->QueryInterface(IID_PPV_ARGS(&environment)));

        wil::com_ptr<ICoreWebView2SharedBuffer> sharedBuffer;
        CHECK_FAILURE(environment->CreateSharedBuffer(bufferSize, &sharedBuffer));
        // Fill data into the shared memory via IStream.
        wil::com_ptr<IStream> stream;
        CHECK_FAILURE(sharedBuffer->GetStream(&stream));
        CHECK_FAILURE(stream->Write(data, dataSize, nullptr));
        PCWSTR additionalDataAsJson = L"{\"read_only\":true}";
        if (forFrame)
        {
            m_webviewFrame->PostSharedBufferToScript(
                sharedBuffer.get(), /*isReadOnlyToScript*/TRUE, additionalDataAsJson);
        }
        else
        {
            m_webView->PostSharedBufferToScript(
               sharedBuffer.get(), /*isReadOnlyToScript*/TRUE, additionalDataAsJson);
        }
        // Explicitly close the one time shared buffer to ensure that the resource is released timely.
        sharedBuffer->Close();
        
```
## WinRT and .NET
```c#
      using (CoreWebView2SharedBuffer sharedBuffer = WebViewEnvironment.CreateSharedBuffer(bufferSize))
      {
          // Fill data using access Stream
          using (Stream stream = sharedBuffer.GetStream())
          {
              using (StreamWriter writer = new StreamWriter(stream))
              {
                  writer.Write(bufferData);
              }
          }
          string additionalDataAsJson = "{\"read_only\":true}";
          if (forFrame)
          {
              m_webviewFrame.PostSharedBufferToScript(sharedBuffer, /*isReadOnlyToScript*/true, additionalDataAsJson);
          }
          else
          {
               m_webview.PostSharedBufferToScript(sharedBuffer, /*isReadOnlyToScript*/true, additionalDataAsJson);
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
  /// For 32bit application, the creation will fail with E_INVALIDARG if `size` is larger than 4GB.
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
  HRESULT GetStream([out, retval] IStream** value);

  /// The file mapping handle of the shared memory of the buffer.
  /// Normal app should use `Buffer` or `GetStream` to get memory address
  /// or IStream object to access the buffer.
  /// For advanced scenarios, you could duplicate this handle to another application
  /// process and create a mapping from the duplicated handle in that process to access
  /// the buffer from that separate process.
  [propget] HRESULT Handle([out, retval] HANDLE* value);
  
  /// Release the backing shared memory. The application should call this API when no
  /// access to the buffer is needed any more, to ensure that the underlying resources
  /// are released timely even if the shared buffer object itself is not released due to
  /// some leaked reference.
  /// After the shared buffer is closed, accessing properties of the object will fail with
  /// `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`. Operations like Read or Write on the IStream
  /// objects returned from `GetStream` will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// `PostSharedBufferToScript` will also fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  ///
  /// The script code should call `chrome.webview.releaseSharedBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access the shared buffer any more.
  /// When script tries to access the buffer after calling `chrome.webview.releaseSharedBuffer`,
  /// JavaScript `TypeError` exception will be raised complaining about accessing a
  /// detached ArrayBuffer, the same exception when trying to access a transferred ArrayBuffer.
  ///
  /// Closing the buffer object on native side doesn't impact access from Script and releasing
  /// the buffer from script doesn't impact access to the buffer from native side.
  /// The underlying shared memory will be released by the OS when both native and script side
  /// releases the buffer.
  HRESULT Close();
}

interface ICoreWebView2_14 : IUnknown {
  /// Share a shared buffer object with script of the main frame in the WebView.
  /// The script will receive a `SharedBufferReceived` event from chrome.webview.
  /// The event arg for that event will have the following properties:
  ///   `sharedBuffer`: an ArrayBuffer object with the backing content from the shared buffer.
  ///   `data`: an object as the result of parsing `additionalDataAsJson` as JSON string.
  ///           This property will be `undefined` if `additionalDataAsJson` is nullptr or empty string.
  ///   `source`: with a value set as `chrome.webview` object.
  /// If a string is provided as `additionalDataAsJson` but it is not a valid JSON string,
  /// the API will fail with `E_INVALIDARG`.
  /// If `isReadOnlyToScript` is true, the script will only have read access to the buffer.
  /// If the script tries to modify the content in a read only buffer, it will cause an access
  /// violation in WebView renderer process and crash the renderer process.
  /// If the shared buffer is already closed, the API will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// 
  /// The script code should call `chrome.webview.releaseSharedBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access to the shared buffer any more.
  ///
  /// Sharing a buffer to script has security risk. You should only share buffer with trusted site.
  /// If a buffer is shared to a untrusted site, possible sensitive information could be leaked.
  /// If a buffer is shared as modifiable by the script and the script modifies it in an unexpected way,
  /// it could result in corrupted data that might even crash the application. 
  HRESULT PostSharedBufferToScript(
    [in] ICoreWebView2SharedBuffer* sharedBuffer,
    [in] BOOL isReadOnlyToScript,
    [in] LPCWSTR additionalDataAsJson);
}

interface ICoreWebView2Frame4 : IUnknown {
  /// Share a shared buffer object with script of the iframe in the WebView.
  /// The script will receive a `SharedBufferReceived` event from chrome.webview.
  /// The event arg for that event will have the following properties:
  ///   `sharedBuffer`: an ArrayBuffer object with the backing content from the shared buffer.
  ///   `data`: an object as the result of parsing `additionalDataAsJson` as JSON string.
  ///           This property will be `undefined` if `additionalDataAsJson` is nullptr or empty string.
  ///   `source`: with a value set as `chrome.webview` object.
  /// If a string is provided as `additionalDataAsJson` but it is not a valid JSON string,
  /// the API will fail with `E_INVALIDARG`.
  /// If `isReadOnlyToScript` is true, the script will only have read access to the buffer.
  /// If the script tries to modify the content in a read only buffer, it will cause an access
  /// violation in WebView renderer process and crash the renderer process.
  /// If the shared buffer is already closed, the API will fail with `HRESULT_FROM_WIN32(ERROR_INVALID_STATE)`.
  /// 
  /// The script code should call `chrome.webview.releaseSharedBuffer` with
  /// the shared buffer as the parameter to release underlying resources as soon
  /// as it does not need access to the shared buffer any more.
  ///
  /// Sharing a buffer to script has security risk. You should only share buffer with trusted site.
  /// If a buffer is shared to a untrusted site, possible sensitive information could be leaked.
  /// If a buffer is shared as modifiable by the script and the script modifies it in an unexpected way,
  /// it could result in corrupted data that might even crash the application. 
  HRESULT PostSharedBufferToScript(
    [in] ICoreWebView2SharedBuffer* sharedBuffer,
    [in] BOOL isReadOnlyToScript,
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
        /// Normal app should use `GetStream` to get a Stream object to access the buffer.
        public IntPtr Buffer { get; };
        
        /// The native file mapping handle of the shared memory of the buffer.
        /// Normal app should use `GetStream` to get a Stream object to access the buffer.
        /// For advanced scenario, you could use native APIs to duplicate this handle to
        /// another application process and create a mapping from the duplicated handle in
        /// that process to access the buffer from that separate process.
        public IntPtr Handle { get; };
        
        public Stream GetStream();
        
        void Close();
        
        // IDisposable
        public void Dispose();
    }
    
    runtimeclass CoreWebView2
    {
        public void PostSharedBufferToScript(
            CoreWebView2SharedBuffer sharedBuffer, bool isReadOnlyToScript, string additionalDataAsJson);
    }
    
    class CoreWebView2Frame
    {
        public void PostSharedBufferToScript(
            CoreWebView2SharedBuffer sharedBuffer, bool isReadOnlyToScript, string additionalDataAsJson);
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
        
        Windows.Storage.Streams.IRandomAccessStream GetStream();
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2SharedBuffer_Manual")]
        {
            /// A reference to the underlying memory of the shared buffer.
            /// You can get IMemoryBufferByteAccess from the object to access the memory as an array of bytes.
            /// See [I](https://docs.microsoft.com/en-us/uwp/api/windows.foundation.imemorybufferreference?view=winrt-22621)
            /// for more details.
            Windows.Foundation.IMemoryBufferReference Buffer { get; };
        }
        
        // Note that we are not exposing Handle from WinRT API.
    
        // IClosable
        void Close();
     }
    
    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_14")]
        {
            void PostSharedBufferToScript(
                CoreWebView2SharedBuffer sharedBuffer, Boolean isReadOnlyToScript, String additionalDataAsJson);
        }
    }
    
    runtimeclass CoreWebView2Frame
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame4")]
        {
            void PostSharedBufferToScript(
                CoreWebView2SharedBuffer sharedBuffer, Boolean isReadOnlyToScript, String additionalDataAsJson);
        }
    }
}

```
