# Background
A Favicon is an asset which is a part of a webpage, and typically displayed on each tab. Developers would
like to have an API which allows them to retrieve the Favicon of a webpage, if it has been set, as well as get an update whenever the favicon has changed.

# Description
We propose a new Webview2 event which would allow developers access the current Favicon of a page, 
as well as be notified when the favicon changes. This means when a page first loads, it would fire
the Favicon change event as the icon has inialized to null. DOM or Javascript may change the Favicon,
causing the event to fire again.

# Examples
## Win32 C++ Registering a listener for favicon changes
```cpp
    CHECK_FAILURE(m_webView->add_FaviconChanged(
        Callback<ICoreWebView2FaviconChangedEventHandler>(
            [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                
                wil::unique_cotaskmem_string url;
                CHECK_FAILURE(sender->get_FaviconUri(&url));
                wil::com_ptr<IStream> pStream = SHCreateMemStream(nullptr, 0);

                sender->GetFavicon(
                    COREWEBVIEW2_FAVICON_IMAGE_FORMAT_PNG, 
                    pStream,
                    Callback<
                        ICoreWebView2GetFaviconCompletedHandler>(
                        [&pStream, this](HRESULT code) -> HRESULT {
                                    Gdiplus::Bitmap* pBitmap = new Gdiplus::Bitmap(pStream);
                                    HICON icon;
                                    pBitmap->GetHICON(&icon);
                                    SendMessage(
                                        m_appWindow->GetMainWindow(), WM_SETICON, ICON_SMALL,
                                        (LPARAM)icon);
                            return S_OK;
                        })
                        .Get());

                return S_OK;
            })
            .Get(),
        &m_faviconChangedToken));  
```
## .NET / WinRT Registering a listener for favicon changes
```c#
webView.CoreWebView2.FaviconChanged += (CoreWebView2 sender, Object arg) =>
{
    System.IO.Stream stream = new System.IO.MemoryStream();
    await webView.CoreWebView2.GetFaviconAsync(
        CoreWebView2FaviconImageFormat.Png,
        stream);
    // setting the window Icon to the bitmap
    this.Icon = BitmapFrame.Create(stream); 

};
```
# API Notes
If a Web page does not have a Favicon, then the event is only fires when the
page is navigated to. The Favicon would be an empty image and Uri. The
user is expected to handle this scenario.
See [API Details](#api-details) Section below for API reference
# API Details
## Win32 C++
```cpp
/// This interface is a handler for when the `Favicon` is changed.
/// The sender is the embedded_browser which handle the change and the
/// second argument is null.
/// For more information see `add_FaviconChanged`.
[uuid(2913DA94-833D-4DE0-8DCA-900FC524A1A4), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalFaviconChangedEventHandler : IUnknown {
  /// Called to notify the favicon changed.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] IUnknown* args);
}

/// This interface is a handler for the completion of the copying for the`imageStream`.
/// The 'error_code` is E_NOT_SET if the there is no image. Otherwise error_code 
/// is the result from the image write operation.
/// For more details, see the `GetFavicon` API.
[uuid(A2508329-7DA8-49D7-8C05-FA125E4AEE8D), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalGetFaviconCompletedHandler : IUnknown {
  /// Called to notify the favicon has been retrieved.
  HRESULT Invoke([in] HRESULT error_code);
}

/// This is the ICoreWebView2 Experimental Favicon interface.
/// It has the capability to fire an event for the changing of the
/// Favicon. When a new page loads event would fire due to Favicon not being set.
/// The event would also set the Favicon when the set by DOM or Javascript.
[uuid(DC838C64-F64B-4DC7-98EC-0992108E2157), object, pointer_default(unique)]
interface ICoreWebView2_10 : ICoreWebView2_9 {
    /// Add an event handler for the `FaviconChanged` event.
    HRESULT add_FaviconChanged(
        [in] ICoreWebView2ExperimentalFaviconChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

    /// Remove the event handler for `FaviconChanged` event.
    HRESULT remove_FaviconChanged(
        [in] EventRegistrationToken token);

    /// Get the current Uri of the favicon.
    /// If value is null, the `HRESULT` `E_POINTER`, otherwise it is `S_OK`.
    /// If a page has no favicon then value is an empty string.
    [propget] HRESULT FaviconUri([out, retval] LPWSTR* value);

    /// Async function for getting the actual image data of the favicon.
    /// If the `imageStream` is null, the `HRESULT` will be `E_POINTER`, otherwise
    /// it is `S_OK`.
    /// The image is copied to the `imageStream` object and when complete,
    /// it will execute the `eventHandler` if it was set.
    HRESULT GetFavicon(
        [in] COREWEBVIEW2_FAVICON_IMAGE_FORMAT format,
        [in] IStream* imageStream,
        [in] ICoreWebView2ExperimentalGetFaviconCompletedHandler* eventHandler);
}

[v1_enum]
typedef enum COREWEBVIEW2_FAVICON_IMAGE_FORMAT {
    /// Indicates that CoreWebView2.GetFaviconAsync should return the favicon in PNG format.
    COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG,

    /// Indicates that CoreWebView2.GetFaviconAsync should return the favicon in JPG format.
    COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_JPEG,
}
```

## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2FaviconImageFormat
    {
        Png = 0,
        Jpeg = 1,
    };

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_10")]
        {
            String FaviconUri { get; };

            event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> FaviconChanged;

            Windows.Foundation.IAsyncAction GetFaviconAsync(CoreWebView2FaviconImageFormat format, Windows.Storage.Streams.IRandomAccessStream imageStream);
        }
    }
}
```
