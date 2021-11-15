Theme API
===

# Background
This API's main use is to set the overall appearance/theme for WebView2. The options are similar to Edge: match the system default theme, change to light theme, or change to dark theme.
This API has 2 main changes relevant to the end users. First, it sets appearance for WebView2 UI like dialogs, prompts, context menu, etc. And second, this API sets the ['prefers-color-scheme'](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme) [media feature](https://developer.mozilla.org/en-US/docs/Web/CSS/Media_Queries/Using_media_queries#media_features). Websites typically media query for this setting in order to set CSS themes for light/dark.

Please note this API will only set the overall appearance, but not theme as defined in the Edge browser.
For reference, in the screenshot below, this API is meant to expose the Overall Appearance section as a WebView2 API.

![Alt text](./media/EdgeSettingsAppearance.png "a title")
# Examples

## C++

```cpp
wil::com_ptr<ICoreWebView2> m_webView;

void ViewComponent::SetTheme(COREWEBVIEW2_THEME_KIND value)
{
    wil::com_ptr<ICoreWebView2_7> webView7;
    webView7 = m_webView.try_query<ICoreWebView2_7>();

    if (webView7)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView7->get_Profile(&profile));

        auto profile2 = profile.try_query<ICoreWebView2Profile2>();
        if (profile2)
        {
            profile2->put_Theme(value);
        }
    }
}
```

## C#

```c#

private CoreWebView2 m_webView;

void SetTheme(CoreWebView2ThemeKind value)
{
    // Check for runtime support
    try
    {
        m_webView.Profile.Theme = value;
    }
    catch (NotImplementedException exception)
    {
        MessageBox.Show(this, "Set Theme Failed: " + exception.Message,
                        "Set Theme");
    }
}

```

# API Details
## C++
```cpp
[uuid(5f817cce-5d36-4cd0-a1d5-aaaf95c8685f), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : ICoreWebView2Profile {
  /// The Theme property sets the overall theme of the WebView2 instance.
  /// The input parameter is either COREWEBVIEW2_THEME_KIND_SYSTEM,
  /// COREWEBVIEW2_THEME_KIND_LIGHT, or COREWEBVIEW2_THEME_KIND_DARK.
  /// Note that this API applies theme to WebView2 pages, dialogs, and menus
  /// by setting the media feature `prefers-color-scheme` for websites to
  /// respond to.
  ///
  /// \snippet ViewComponent.cpp SetTheme
  /// Returns the value of the `Theme` property.
  [propget] HRESULT Theme(
    [out, retval] COREWEBVIEW2_THEME_KIND* value);

  /// Sets the `Theme` property.
  [propput] HRESULT Theme(
    [in] COREWEBVIEW2_THEME_KIND value);
}

/// An enum to represent the options for WebView2 Theme: system, light, or dark.
[v1_enum]
typedef enum COREWEBVIEW2_THEME_KIND {
  /// System theme
  COREWEBVIEW2_THEME_KIND_SYSTEM,

  /// Light theme
  COREWEBVIEW2_THEME_KIND_LIGHT,

  /// Dark theme
  COREWEBVIEW2_THEME_KIND_DARK
} COREWEBVIEW2_THEME_KIND;
```

### C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    [doc_string("An enum to represent the options for WebView2 Theme: system, light, or dark.")]
    enum CoreWebView2ThemeKind
    {
        [doc_string("System theme.")]
        System = 0,
        [doc_string("Light theme.")]
        Light = 1,
        [doc_string("Dark theme.")]
        Dark = 2,
    };

    [doc_string("Multiple profiles can be created under a single user data directory but with separated cookies, user preference settings, and various data storage etc..")]
    runtimeclass CoreWebView2Profile
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile2")]
        {
            [doc_string("The Theme property sets the overall theme of the WebView2 instance. The input parameter is either CoreWebView2ThemeKind.System, CoreWebView2ThemeKind.Light, or CoreWebView2ThemeKind.Dark. Note that this API applies theme to WebView2 pages, dialogs, and menus by setting the media feature `prefers-color-scheme` for websites to respond to.")]
            CoreWebView2ThemeKind Theme { get; set };
        }
    }
}
```
