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

# Examples
```cpp
auto webViewEnvironment10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
wil::com_ptr<ICoreWebView2ControllerOptions> options;
HRESULT hr = webViewEnvironment10->CreateCoreWebView2ControllerOptions(&options);
options->put_LocaleRegion(m_webviewOption.localeRegion.c_str());
```

```c#
CoreWebView2Environment environment;
CoreWebView2ControllerOptions CreateCoreWebView2ControllerOptions(CoreWebView2Environment environment)
{
    CoreWebView2ControllerOptions ControllerOptions = null;
    if (LocaleRegion != null)
    {
        ControllerOptions = environment.CreateCoreWebView2ControllerOptions();
        ControllerOptions.LocaleRegion = LocaleRegion;
    }
    return ControllerOptions;    
}
```

# API Details
```cpp
[uuid(0c9a374f-20c3-4e3c-a640-67b78a7e0a48), object, pointer_default(unique)]
interface ICoreWebView2StagingControllerOptions : IUnknown {
  /// The default region for the WebView2.  It applies to JavaScript API
  /// Intl.DateTimeFormat() which affects string formatting like
  /// in the time/date formats. The intended locale value is in the format of
  /// `language-country` or `language_country` where `language` is the 2-letter code from [ISO
  /// 639](https://www.iso.org/iso-639-language-codes.html) and `country` is the
  /// 2-letter code from [ISO 3166](https://www.iso.org/standard/72482.html).
  ///
  /// This property sets the region for a CoreWebView2Environment during its creation. 
  /// Creating a new CoreWebView2Environment object that connects to an already running 
  /// browser process cannot change the region previously set by an earlier CoreWebView2Environment.  
  /// The CoreWebView2Environment and all associated webview2 objects will need to closed.
  ///
  /// The default value for LocaleRegion will be depend on the WebView2 language
  /// and OS region. If the language portions of the WebView2 language and OS Region
  /// match, then it will use the OS region. Otherwise, it will use the WebView2
  /// language.
  /// | **OS Region** | **WebView2 Language** | **Default WebView2 LocaleRegion** |
  /// |-----------|-------------------|-------------------------------|
  /// | en-GB     | en-US             | en-GB                         |
  /// | es-MX     | en-US             | en-US                         |
  /// | en-US     | en-GB             | en-US                         |
  /// The default value can be reset using the empty string.
  ///
  /// Use OS specific APIs to determine the OS region to use with this property
  /// if you want to match the OS. For example:
  ///
  /// Win32 C++:
  /// ```cpp
  ///   int LanguageCodeBufferSize =
  ///       ::GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SNAME, nullptr, 0);
  ///   std::unique_ptr<char[]> buffer(new char[LanguageCodeBufferSize]);
  ///   WCHAR* w_language_code = new WCHAR[LanguageCodeBufferSize];
  ///   ::GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SNAME, w_language_code,
  ///                     LanguageCodeBufferSize);
  ///   wcstombs(buffer.get(), w_language_code, LanguageCodeBufferSize);
  ///   delete[] w_language_code;
  ///   return buffer;
  /// ```
  ///
  /// .NET and WinRT C#:
  /// ```cs
  ///   CultureInfo cultureInfo = Thread.CurrentThread.CurrentCulture;
  ///   return cultureInfo.Name
  /// ```
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  /// \snippet AppWindow.cpp RegionLocaleSetting
  // MSOWNERS: stevenwei@microsoft.com
  [propget] HRESULT LocaleRegion([out, retval] LPWSTR* locale);
  /// Sets the `LocaleRegion` property.
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