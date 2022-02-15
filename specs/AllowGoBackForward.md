# Background
Some developers may want to disable navigating back or forward to make a single page displayed, and not allow the users to navigate away from it accidentally. So we can disallow navigating back and forward by setting the API.

# Description
We add new `AllowGoBack` and new `AllowGoForward` properties in `CoreWebView2Settings`.
These two APIs allow end developers to toggle the allow go back and forward functionality easily.
Although the CoreWebView2.NavigationStarting event can be used to cancel navigations it is not easy to distinguish between back and forward navigations from other sources of navigation. If we set these APIs to disabled, users can not navigate back and forward regardless of source (button click, xbutton click, key event and etc.). The `CanGoBack` and `CanGoForward` APIs will also return false if we set `AllowGoBack` and `AllowGoForward` to disabled.
By default, `AllowGoBack` and `AllowGoForward` are enabled to keep consistent with the behavior we had before the APIs are added.
These two settings changes will work in the next navigation, which means that changes made after `NavigatingStarting` event do not apply until the next top-level navigation.

# Examples
## C++

```cpp
wil::com_ptr<ICoreWebView2> m_webview;
void SettingsComponent::ToggleAllowGoBack()
{
    // Get webView's current settings.
    wil::com_ptr<ICoreWebView2Settings> webView2Settings;
    CHECK_FAILURE(m_webview->get_Settings(&webView2Settings);

    BOOL allowGoBack;
    CHECK_FAILURE(webView2Settings->get_AllowGoBack(&allowGoBack));
    if (allowGoBack)
    {
        CHECK_FAILURE(webView2Settings->put_AllowGoBack(FALSE));
    }
    else
    {
        CHECK_FAILURE(webView2Settings->put_AllowGoBack(TRUE));
    }
}

void SettingsComponent::ToggleAllowGoForward()
{
    // Get webView's current settings.
    wil::com_ptr<ICoreWebView2Settings> webView2Settings;
    CHECK_FAILURE(m_webview->get_Settings(&webView2Settings);

    BOOL allowGoForward;
    CHECK_FAILURE(webView2Settings->get_AllowGoForward(&allowGoForward));
    if (allowGoForward)
    {
        CHECK_FAILURE(webView2Settings->put_AllowGoForward(FALSE));
    }
    else
    {
        CHECK_FAILURE(webView2Settings->put_AllowGoForward(TRUE));
    }
}
```

## C#
```c#
private WebView2 _webView;
void ToggleAllowGoBack(object target, ExecutedRoutedEventArgs e)
{
    var webView2Settings = _webView.CoreWebView2.Settings;
    if (webView2Settings.AllowGoBack)
    {
        webView2Settings.AllowGoBack = false;
    }
    else
    {
        webView2Settings.AllowGoBack = true;
    }
}
void ToggleAllowGoForward(object target, ExecutedRoutedEventArgs e)
{
    var webView2Settings = _webView.CoreWebView2.Settings;
    if (webView2Settings.AllowGoForward)
    {
        webView2Settings.AllowGoForward = false;
    }
    else
    {
        webView2Settings.AllowGoForward = true;
    }
}
```

# Remarks

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```c++
/// A continuation of the ICoreWebView2Settings interface to manage allowing navigating
/// back and forward.
[uuid(d21886f5-03fd-4029-8179-d7ed9f726b06), object, pointer_default(unique)]
interface ICoreWebView2Settings8 : ICoreWebView2Settings7 {
  /// `AllowGoBack` controls whether the WebView2 is allowed to navigate back. If it is
  /// false, we will block all back navigations regardless of source (button click, xbutton
  /// click, key event and so on).
  /// The `CanGoBack` API will also return false if we set `AllowGoBack` to disabled.
  /// This setting changes will work in the next navigation, which means that changes made
  /// after `NavigatingStarting` event do not apply until the next top-level navigation.
  /// The default value is true.
  [propget] HRESULT AllowGoBack([out, retval] BOOL* allow);
  /// Set the `AllowGoBack` property.
  [propput] HRESULT AllowGoBack([in] BOOL allow);
  /// `AllowGoForward` controls whether the WebView2 is allowed to navigate forward. If it
  /// is false, we will block all forward navigations regardless of source (button click, xbutton
  /// click, key event and so on).
  /// The `CanGoForward` API will also return false if we set `AllowGoForward` to disabled.
  /// This setting changes will work in the next navigation, which means that changes made
  /// after `NavigatingStarting` event do not apply until the next top-level navigation.
  /// The default value is true.
  [propget] HRESULT AllowGoForward([out, retval] BOOL* allow);
  /// Set the `AllowGoForward` property.
  [propput] HRESULT AllowGoForward([in] BOOL allow);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        // ...
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings8")]
        {
            bool AllowGoBack { get; set; };
            bool AllowGoForward { get; set; };
        }
    }
}
```
