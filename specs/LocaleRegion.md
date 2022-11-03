LocaleRegion
===

# Background
Developers have requested access to programmatically choose the specific locale/region to use in WebView2. 
The locale/region updates the JavaScript region (objects in the ECMA standard) which gets reflected as
variations in time and date formats. Currently, the locale is by default set to the same value as the 
display language. 

You can use the `LocaleRegion` API to update the locale value individually from the display
language.

# Description
* The intended value for `LocaleRegion` is in the format of `language[-country]` where `language` is the 
2-letter code from [ISO 639](https://www.iso.org/iso-639-language-codes.html) and `country` is the 
2-letter code from [ISO 3166](https://www.iso.org/standard/72482.html).
* By default, the `LocaleRegion` will be set as the value for the Limited option in the browser.
That means that if the OS region and the display language share the same language code, 
like 'en-GB' and 'en-US', the value will be set to the OS region.

# Examples
```cpp
auto webViewEnvironment10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
wil::com_ptr<ICoreWebView2ControllerOptions> options;
HRESULT hr = webViewEnvironment10->CreateCoreWebView2ControllerOptions(&options);
options->put_LocaleRegion(m_webviewOption.localeRegion.c_str());
```

```c#
CoreWebView2Environment _webViewEnvironment;
WebViewCreationOptions _creationOptions;
public CreateWebView2Controller(IntPtr parentWindow)
{
    CoreWebView2ControllerOptions controllerOptions = new CoreWebView2ControllerOptions();
    controllerOptions.LocaleRegion = _creationOptions.localeRegion;
    CoreWebView2Controller controller = null;
    if (_creationOptions.entry == WebViewCreateEntry.CREATE_WITH_OPTION)
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow, options);
    }
    else
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow);
    }
    // update locale with value
    SetAppLocale(localeRegion);
}
```

# API Details
```cpp
[uuid(0c9a374f-20c3-4e3c-a640-67b78a7e0a48), object, pointer_default(unique)]
interface ICoreWebView2StagingControllerOptions : IUnknown {
  /// Interface for locale region that is updated through the ControllerOptions
  /// API.
  /// The default region for WebView.  It applies to browser UI such as
  /// in the time/date formats. The intended locale value is in the format of
  /// `language[-country]` where `language` is the 2-letter code from [ISO
  /// 639](https://www.iso.org/iso-639-language-codes.html) and `country` is the
  /// 2-letter code from [ISO 3166](https://www.iso.org/standard/72482.html).
  ///
  /// Validation is done on the V8 engine to match on the closest locale
  /// from the passed in locale region value. For example, passing in "en_gb"
  /// will reflect the "en-GB" locale in V8.
  /// If V8 cannot find any matching locale on the input value, it will default
  /// to the display language as the locale.
  ///
  /// The Windows API `GetLocaleInfoEx` can be used if the LocaleRegion value
  /// is always set to match the OS region
  ///
  /// ```cpp
  /// int LanguageCodeBufferSize =
  ///     ::GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SNAME, nullptr, 0);
  /// std::unique_ptr<char[]> buffer(new char[LanguageCodeBufferSize]);
  /// WCHAR* w_language_code = new WCHAR[LanguageCodeBufferSize];
  /// ::GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SNAME, w_language_code,
  ///                   LanguageCodeBufferSize);
  /// wcstombs(buffer.get(), w_language_code, LanguageCodeBufferSize);
  /// delete[] w_language_code;
  /// return buffer;
  /// ```
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  /// \snippet AppWindow.cpp RegionLocaleSetting
  // MSOWNERS: stevenwei@microsoft.com
  [propget] HRESULT LocaleRegion([out, retval] LPWSTR* locale);

  /// Sets the `Region` property.
  // MSOWNERS: stevenwei@microsoft.com
  [propput] HRESULT LocaleRegion([in] LPCWSTR locale);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ControllerOptions
    {        
       // ...
       [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ControllerOptions")]
       {

           String LocaleRegion { get; set; };
       }
    }
}