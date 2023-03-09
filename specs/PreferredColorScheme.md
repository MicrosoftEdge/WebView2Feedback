Preferred Color Scheme API
===

# Background
This API's main use is to set the preferred color scheme for WebView2's which are associated with a profile. The options are similar to Edge: auto - which match the OS's default color scheme, change to light color scheme, or change to dark color scheme. This sets the color scheme for WebView2 UI like dialogs, prompts, and context menus by setting the ['prefers-color-scheme'](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme) [media feature](https://developer.mozilla.org/en-US/docs/Web/CSS/Media_Queries/Using_media_queries#media_features). Websites typically query for this setting in order to set CSS themes for light/dark.

Please note this API will only set the overall appearance, but not theme as defined in the Edge browser.
For reference, in the screenshot below, this API is meant to expose the Overall Appearance section as a WebView2 API.

![Edge Settings Appearance Page](https://github.com/MicrosoftEdge/WebView2Feedback/blob/api-appearance/specs/images/EdgeSettingsAppearance.png)

# Description
We propose extending `CoreWebView2Profile` to include a `PreferredColorScheme` property. This property will apply
to any WebView2's which are associated with this profile.

# Examples

## C++

```cpp
wil::com_ptr<ICoreWebView2> m_webView;

void ViewComponent::SetPreferredColorScheme(COREWEBVIEW2_PREFERRED_COLOR_SCHEME value)
{
    wil::com_ptr<ICoreWebView2_7> webView7;
    webView7 = m_webView.try_query<ICoreWebView2_7>();

    if (webView7)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView7->get_Profile(&profile));

        auto profile3 = profile.try_query<ICoreWebView2Profile3>();
        if (profile3)
        {
            profile3->put_PreferredColorScheme(value);
        }
    }
}
```

## C#

```c#

private CoreWebView2 m_webView;

void SetPreferredColorScheme(CoreWebView2PreferredColorScheme value)
{
    m_webView.Profile.PreferredColorScheme = value;
}

```

# API Details
## C++
```cpp
[uuid(5f817cce-5d36-4cd0-a1d5-aaaf95c8685f), object, pointer_default(unique)]
interface ICoreWebView2Profile3 : ICoreWebView2Profile2 {
  /// The PreferredColorScheme property sets the overall color scheme of the WebView2's associated
  /// with this profile. This sets the color scheme for WebView2 UI like dialogs,
  /// prompts, and context menus by setting the
  /// ['prefers-color-scheme'](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme)
  /// CSS media feature for websites to respond to.
  ///
  /// The default value for this is COREWEBVIEW2_PREFERRED_COLOR_SCHEME_AUTO, which will
  /// follow whatever color scheme the OS is currently set to.
  ///
  /// \snippet ViewComponent.cpp SetPreferredColorScheme
  /// Returns the value of the `PreferredColorScheme` property.
  [propget] HRESULT PreferredColorScheme(
    [out, retval] COREWEBVIEW2_PREFERRED_COLOR_SCHEME* value);

  /// Sets the `PreferredColorScheme` property.
  [propput] HRESULT PreferredColorScheme(
    [in] COREWEBVIEW2_PREFERRED_COLOR_SCHEME value);
}

/// An enum to represent the options for WebView2 Color Scheme: auto, light, or dark.
[v1_enum]
typedef enum COREWEBVIEW2_PREFERRED_COLOR_SCHEME {
  /// Auto color scheme
  COREWEBVIEW2_PREFERRED_COLOR_SCHEME_AUTO,

  /// Light color scheme
  COREWEBVIEW2_PREFERRED_COLOR_SCHEME_LIGHT,

  /// Dark color scheme
  COREWEBVIEW2_PREFERRED_COLOR_SCHEME_DARK
} COREWEBVIEW2_PREFERRED_COLOR_SCHEME;
```

### C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    [doc_string("An enum to represent the options for WebView2 Preferred Color Scheme: auto, light, or dark.")]
    enum CoreWebView2PreferredColorScheme
    {
        [doc_string("Auto color scheme.")]
        Auto = 0,
        [doc_string("Light color scheme.")]
        Light = 1,
        [doc_string("Dark color scheme.")]
        Dark = 2,
    };

    [doc_string("Multiple profiles can be created under a single user data directory but with separated cookies, user preference settings, and various data storage etc..")]
    runtimeclass CoreWebView2Profile
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile3")]
        {
            [doc_string("The PreferredColorScheme property sets the overall color scheme of the WebView2's associated with this profile. This sets the color scheme for WebView2 UI like dialogs, prompts, and context menus by setting the prefers-color-scheme CSS media feature for websites to respond to. The default value for this is CoreWebView2PreferredColorScheme.Auto, which will follow whatever color scheme the OS is currently set to.")]
            CoreWebView2PreferredColorScheme PreferredColorScheme { get; set };
        }
    }
}
```
