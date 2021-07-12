# Background
A Favicon is an asset which is a part of every webpage, and typically displayed on each tab. Developers would
like to have an API which allows them to retrieve the Favicon of a webpage, as well as get an update whenever
the favicon has changed.

# Description
We propose a new Webview2 event which would allow developers to get access to the current Favicon of a page, 
as well as be notified when the favicon changes.

# Examples
## Win32 C++ Registering a listener for favicon changes
    ```cpp
        CHECK_FAILURE(m_webView->add_FaviconChanged(
            Microsoft::WRL::Callback<ICoreWebView2FaviconUpdateEventHandler>(
            [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT
            {
                
                LPWSTR value;
                CHECK_FAILURE(sender->get_FaviconUrl(&value));


                return S_OK;
            }
         ).Get(),
        &m_faviconChangedToken));  
    ```
## .NET / WinRT Registering a listener for favicon changes
```c#
webView.CoreWebView2.FaviconChanged += (CoreWebView2 sender, Object arg) =>
{
    string  value = sender.faviconUrl;

};
```
# API Notes
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

[uuid(DC838C64-F64B-4DC7-98EC-0992108E2157), object, pointer_default(unique)]
interface ICoreWebView2_5 : ICoreWebView2_4 {
  /// Add an event handler for the `FaviconChanged` event.
  /// `FaviconChanged` runs when the WebView favicon changes
  HRESULT add_FaviconChanged(
        [in] ICoreWebView2FaviconChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);

  /// Removing the event handler for `FaviconChanged` event
  HRESULT remove_FaviconChanged(
      [in] EventRegistrationToken token);

  /// used to access the current value of the favicon
  [propget] HRESULT FaviconUri([out, retval] LPWSTR* value);
}
```

## .Net/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core {

/// Interface for the Favicon changed event handler
    runtimeclass CoreWebView2 {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> FaviconChanged;
        string FaviconUrl {get;};
    }
}
```
