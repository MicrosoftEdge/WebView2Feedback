# Background
A Favicon is an asset which is a part of a  webpage, and typically displayed on each tab. Developers would
like to have an API which allows them to retrieve the Favicon of a webpage, if it has one, as well as get an update whenever
the favicon has changed.

# Description
We propose a new Webview2 event which would allow developers access the current Favicon of a page, 
as well as be notified when the favicon changes.

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
If a Web page does not have a Favicon, then the event is not fired.
See [API Details](#api-details) Section below for API reference
# API Details
## Win32 C++
```cpp
/// Interface for the Favicon changed event handler
[uuid(A0CDE626-8E5E-4EE2-9766-58F3696978FE), object, pointer_default(unique)]
interface ICoreWebView2FaviconChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] IUnknown* args);
}

[uuid(93ACC5AD-DC22-419E-9A3F-75D96A1538E4), object, pointer_default(unique)]
interface ICoreWebView2GetFaviconCompletedHandler : IUnknown {
  /// Called to provide the implementer with the completion information of CoreWebView2.GetFaviconAsync.
  /// corresponding event.
  HRESULT Invoke([in] HRESULT error_code);
}

[uuid(DC838C64-F64B-4DC7-98EC-0992108E2157), object, pointer_default(unique)]
interface ICoreWebView2_10 : ICoreWebView2_9 {
  /// Add an event handler for the `FaviconChanged` event.
  /// `FaviconChanged` runs when the WebView favicon changes
  HRESULT add_FaviconChanged(
        [in] ICoreWebView2FaviconChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

  /// Remove an event handler from the `FaviconChanged` event.
  HRESULT remove_FaviconChanged(
      [in] EventRegistrationToken token);

/// Async function for getting the actual image data of the favicon
 HRESULT GetFaviconAsync(
        [in] COREWEBVIEW2_FAVICON_IMAGE_FORMAT format,
        [in] IStream * imageStream,
        [in] ICoreWebView2GetFaviconCompletedHandler* eventHandler
 );

  /// Used to access the current value of the favicon's URI.
  /// If a page has no favicon then this returns a nullptr.
  [propget] HRESULT FaviconUri([out, retval] LPWSTR* value);

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
