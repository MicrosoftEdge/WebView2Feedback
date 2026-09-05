ScriptLocale
===

# Background
Developers have requested access to programmatically choose the specific locale/region to use in WebView2. 
The locale/region updates the JavaScript region (objects in the ECMA standard) which gets reflected as
variations in time and date formats. Currently, the locale is by default set to the same value as the 
display language. 

You can use the `ScriptLocale` property to update the locale value individually from the display
language.

# Description
* The intended value for `SciptLocale` is in the format of BCP 47 Language Tags. 
* More information can be found at [IETF BCP47](https://www.ietf.org/rfc/bcp/bcp47.html).
# Examples
```cpp
ControllerOptions CreateAndInitializeCoreWebView2ControllerAndOptions(std::string locale) 
{
    auto webViewEnvironment10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
    CHECK_FEATURE_RETURN(webViewEnvironment10);
    wil::com_ptr<ICoreWebView2ControllerOptions> options;
    CHECK_FAILURE(webViewEnvironment10->CreateCoreWebView2ControllerOptions(&options));
    options->put_ScriptLocale(locale);
    return options;
}
```

```c#
CoreWebView2Environment environment;
CoreWebView2ControllerOptions CreateAndInitializeCoreWebView2ControllerOptions(CoreWebView2Environment environment, string locale)
{
    CoreWebView2ControllerOptions controllerOptions = null;
    controllerOptions = environment.CreateCoreWebView2ControllerOptions();
    controllerOptions.ScriptLocale = locale;
    return controllerOptions;    
}
```

# API Details
```cpp
[uuid(06c991d8-9e7e-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2ControllerOptions2 : ICoreWebView2ControllerOptions {
  /// The default locale for the WebView2.  It sets the default locale for all
  /// Intl JavaScript APIs and other JavaScript APIs that depend on it, namely
  /// `Intl.DateTimeFormat()` which affects string formatting like
  /// in the time/date formats. Example: `Intl.DateTimeFormat().format(new Date())`
  /// The intended locale value is in the format of
  /// BCP 47 Language Tags. More information can be found from
  /// [IETF BCP47](https://www.ietf.org/rfc/bcp/bcp47.html).
  ///
  /// This property sets the locale for a CoreWebView2Environment used to create the
  /// WebView2ControllerOptions object, which is passed as a parameter in
  /// `CreateCoreWebView2ControllerWithOptions`.
  ///
  /// Changes to the ScriptLocale property apply to renderer processes created after
  /// the change. Any existing renderer processes will continue to use the previous
  /// ScriptLocale value. To ensure changes are applied to all renderer process,
  /// close and restart the CoreWebView2Environment and all associated WebView2 objects.
  ///
  /// The default value for ScriptLocale will depend on the WebView2 language
  /// and OS region. If the language portions of the WebView2 language and OS region
  /// match, then it will use the OS region. Otherwise, it will use the WebView2
  /// language.
  ///
  /// | **OS Region** | **WebView2 Language** | **Default WebView2 ScriptLocale** |
  /// |-----------|-------------------|-------------------------------|
  /// | en-GB     | en-US             | en-GB                         |
  /// | es-MX     | en-US             | en-US                         |
  /// | en-US     | en-GB             | en-US                         |
  /// You can set the ScriptLocale to the empty string to get the default ScriptLocale value.
  ///
  /// Use OS specific APIs to determine the OS region to use with this property
  /// if you want to match the OS. For example:
  ///
  /// Win32 C++:
  /// ```cpp
  ///   wchar_t osLocale[LOCALE_NAME_MAX_LENGTH] = {0};
  ///   GetUserDefaultLocaleName(osLocale, LOCALE_NAME_MAX_LENGTH);
  /// ```
  ///
  /// .NET and WinRT C#:
  /// ```cs
  ///   CultureInfo cultureInfo = Thread.CurrentThread.CurrentCulture;
  ///   return cultureInfo.Name
  /// ```
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  /// \snippet AppWindow.cpp ScriptLocaleSetting
  // MSOWNERS: stevenwei@microsoft.com
  [propget] HRESULT ScriptLocale([out, retval] LPWSTR* locale);
  /// Sets the `ScriptLocale` property.
  // MSOWNERS: stevenwei@microsoft.com
  [propput] HRESULT ScriptLocale([in] LPCWSTR locale);
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

           String ScriptLocale { get; set; };
       }
    }
}