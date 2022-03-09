# Background
A favicon (favorite icon) is a tiny icon included along with a website, which is displayed in places like the browser's address bar, page tabs and bookmarks menu. Developers would like to have an API which allows them to retrieve the Favicon of a webpage, if it has been set, as well as get an update whenever the favicon has changed.

# Description
We propose a new Webview2 event which would allow developers to access the current Favicon of a page and be notified when the favicon changes. This means when a page first loads, it would raise the FaviconChanged event since before parsing the HTML document there is no known favicon. DOM or JavaScript may change the Favicon, causing the event to be raised again for the same document.

# Examples
## Win32 C++ Registering a listener for favicon changes
```cpp
Gdiplus::GdiplusStartupInput gdiplusStartupInput;

// Initialize GDI+.
Gdiplus::GdiplusStartup(&gdiplusToken_, &gdiplusStartupInput, NULL);
CHECK_FAILURE(m_webView2->add_FaviconChanged(
    Callback<ICoreWebView2ExperimentalFaviconChangedEventHandler>(
        [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            if (m_faviconChanged)
            {
                wil::unique_cotaskmem_string url;
                Microsoft::WRL::ComPtr<ICoreWebView2>
                    webview2Experimental;
                CHECK_FAILURE(
                    sender->QueryInterface(IID_PPV_ARGS(&webview2)));

                CHECK_FAILURE(webview2Experimental->get_FaviconUri(&url));
                std::wstring strUrl(url.get());

                webview2->GetFavicon(
                    COREWEBVIEW2_FAVICON_IMAGE_FORMAT_PNG,
                    Callback<ICoreWebView2ExperimentalGetFaviconCompletedHandler>(
                        [this, strUrl](HRESULT errorCode, IStream* iconStream) -> HRESULT
                        {
                            CHECK_FAILURE(errorCode);
                            Gdiplus::Bitmap iconBitmap(iconStream);
                            wil::unique_hicon icon;
                            if (!iconBitmap.GetHICON(&icon))
                            {
                                m_favicon = std::move(icon);
                                SendMessage(
                                    m_appWindow->GetMainWindow(), WM_SETICON,
                                    ICON_SMALL, (LPARAM)m_favicon.get());
                                m_statusBar.Show(strUrl);
                            }

                            return S_OK;
                        })
                        .Get());
            }
            return S_OK;
        }).Get(), &m_faviconChangedToken));
}
```
## .NET / WinRT Registering a listener for favicon changes
```c#
webView.CoreWebView2.FaviconChanged += (CoreWebView2 sender, Object arg) =>
{
    IStream stream = await webView.CoreWebView2.GetFaviconAsync(
        CoreWebView2FaviconImageFormat.Png);
    // setting the window Icon to the bitmap
    this.Icon = BitmapFrame.Create(stream); 

};
```
# API Notes
Note that even if a web page does not have a Favicon, the FaviconChanged event
is raised when the page is navigated to. The Favicon would be an
empty image stream and empty Uri for the lack of a favicon. The end developer is expected to handle this scenario.
Otherwise, we raise the FaviconChanged with an observed change to the
Favicon. In that scenario, the CoreWebView2 has an updated value for the FaviconUri property, and the GetFavicon method to match the updated favicon.
See [API Details](#api-details) Section below for API reference
# API Details
## Win32 C++
```cpp
/// This interface is a handler for when the `Favicon` is changed.
/// The sender is the ICoreWebView2 object the top-level document of 
/// which has changed favicon and the eventArgs is nullptr. Use the 
/// FaviconUri property and GetFavicon method to obtain the favicon 
/// data. The second argument is always null.
/// For more information see `add_FaviconChanged`.
[uuid(2913DA94-833D-4DE0-8DCA-900FC524A1A4), object, pointer_default(unique)]
interface ICoreWebView2FaviconChangedEventHandler : IUnknown {
  /// Called to notify the favicon changed.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] IUnknown* args);
}

/// This interface is a handler for the completion of the population of
/// `imageStream`.
/// `errorCode` returns S_OK if the API succeeded.
/// The image is returned in the `faviconStream` object. If there is no image
/// then no data would be copied into the imageStream.
/// For more details, see the `GetFavicon` API.
[uuid(A2508329-7DA8-49D7-8C05-FA125E4AEE8D), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalGetFaviconCompletedHandler : IUnknown {
  /// Called to notify the favicon has been retrieved.
  HRESULT Invoke(
    [in] HRESULT errorCode,
    [in] IStream* faviconStream);
}

/// This is the ICoreWebView2 Experimental Favicon interface.
[uuid(DC838C64-F64B-4DC7-98EC-0992108E2157), object, pointer_default(unique)]
interface ICoreWebView2_10 : ICoreWebView2_9 {
    /// Add an event handler for the `FaviconChanged` event.
    /// The `FaviconChanged` event is raised when the 
    /// [favicon](https://developer.mozilla.org/en-US/docs/Glossary/Favicon)
    /// when the favicon had a different URL then the previous URL.
    /// The FaviconChanged event will be raised for first navigating to a new 
    /// document, whether or not a document declares a Favicon in HTML if the
    /// favicon is different from the previous fav icon. The event will 
    /// be raised again if a favicon is declared in its HTML or has script 
    /// to set its favicon. The favicon information can then be retrieved with 
    /// `GetFavicon` and `FaviconUri`.
    HRESULT add_FaviconChanged(
        [in] ICoreWebViewFaviconChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

    /// Remove the event handler for `FaviconChanged` event.
    HRESULT remove_FaviconChanged(
        [in] EventRegistrationToken token);

    /// Get the current Uri of the favicon as a string.
    /// If the value is null, then the return value is `E_POINTER`, otherwise it is `S_OK`.
    /// If a page has no favicon then the value is an empty string.
    [propget] HRESULT FaviconUri([out, retval] LPWSTR* value);

    /// Async function for getting the actual image data of the favicon.
    /// If the `imageStream` is null, the `HRESULT` will be `E_POINTER`, otherwise
    /// it is `S_OK`.
    /// The image is copied to the `imageStream` object. If there is no image then
    /// no data would be copied into the imageStream.
    /// In either scenario the `completedHandler` is executed at the end of the operation.
    HRESULT GetFavicon(
        [in] COREWEBVIEW2_FAVICON_IMAGE_FORMAT format,
        [in] IStream* imageStream,
        [in] ICoreWebView2GetFaviconCompletedHandler* completedHandler);
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

            Windows.Foundation.IAsyncAction GetFaviconAsync(CoreWebView2FaviconImageFormat format);
        }
    }
}
```
