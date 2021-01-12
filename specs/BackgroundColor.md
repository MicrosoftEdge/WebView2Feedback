# Background
WebView2 developers have provided feedback that there is a 'white flicker' when navigating between pages. This flicker comes from WebView briefly showing its default background color for when no web page is loaded. Developers should be able to set a custom background color for the WebView that matches the color scheme of their app and avoids this flicker. We have also received feedback requesting the ability to set the WebView's background color transparent. This way developers can create a seamless UI experience where the WebView displays web content directly over host app content. The BackgroundColor API addresses this need.


# Description
The `BackgroundColor` property enables a seamless UI experience. Developers can replace the 'white flash' between loading pages with a color better suited to their application. For websites with no specified background color, developers can display web contents over a color of their choosing. They can also do away with the background color entirely with transparency and have the 'in between pages color' just be hosting content, or have hosting app content be the backdrop for webpages without a background color specified.

# Examples
## Win32 C++
The fields of COREWEBVIEW2_COLOR can be set with integer values between 0 and 255. In the following example, we see the app reading color values from a COLORREF (which are integers under the covers) into a COREWEBVIEW2_COLOR. It then sets the COREWEBVIEW2_COLOR.A value to 0 or 255. Once the COREWEBVIEW2_COLOR value is filled out, it is passed to the controller's put_BackgroundColor API. 
```cpp
void ViewComponent::SetBackgroundColor(COLORREF color, bool transparent)
{
    COREWEBVIEW2_COLOR wvColor;
    wvColor.R = GetRValue(color);
    wvColor.G = GetGValue(color);
    wvColor.B = GetBValue(color);
    wvColor.A = transparent ? 0 : 255;
    m_controller->put_BackgroundColor(wvColor);
}
```
## WinRT
```c#
private void SetBackgroundColor(Windows.UI.Color color)
{
    _coreWebView2Controller.BackgroundColor = color;
}
```


# Remarks
Currently only colors with an A set to 0 or 255 are supported by the API. The work to support semi-transparent colors is being tracked and will be added later


# API Details
## Win32 C++
```cpp
// This is the ICoreWebView2Controller2 interface
interface ICoreWebView2Controller2 : ICoreWebView2Controller {

  /// The `BackgroundColor` property allows developers to set the color that
  /// shows when WebView has not loaded any web content and when a webpage
  /// does not specify a background color. Color is specified by the
  /// COREWEBVIEW2_COLOR value meaning the background color can also be
  /// transparent.
  /// The WebView background color will show before the initial navigation,
  /// between navigations before the next page has rendered, and for pages with
  /// no `background` style properties set. To clarify the latter case, WebView
  /// will always honor a webpage's background content. `BackgroundColor` will
  /// only show in the absence of css `background` style properties. In that
  /// case, WebView will render web content over the `BackgroundColor` color.
  /// For a transparent background, web content will render over hosting app
  /// content. WebView's default background color is white to match the browser
  /// experience.
  /// It is important to note that while COREWEBVIEW2_COLOR has `A` an alpha
  /// value, semi-transparent colors are not supported by this API and setting
  /// `BackgroundColor` to a semi-transparent color will fail with E_INVALIDARG.
  /// Any alpha value above 0 and below 255 will result in an E_INVALIDARG
  /// error.`BackgroundColor` can only be an opaque color or transparent.
  ///
  /// The `BackgroundColor` property enables a seamless UI experience.
  /// Developers can replace the 'white flash' between loading pages with a
  /// color better suited to their application. For websites with no specified
  /// background color, developers can display web contents over a color of
  /// their choosing. They can also do away with the background color entirely
  /// with transparency and have the 'in between pages color' just be hosting
  /// content, or have hosting app content be the backdrop for webpages without
  /// a background color specified.
  ///
  /// \snippet ViewComponent.cpp BackgroundColor

  [propget] HRESULT BackgroundColor([out, retval] COREWEBVIEW2_COLOR* backgroundColor);

  /// Sets the `BackgroundColor` property.

  [propput] HRESULT BackgroundColor([in] COREWEBVIEW2_COLOR backgroundColor);
}


/// A value representing RGBA color (Red, Green, Blue, Alpha) for WebView2.
/// Each component takes a value from 0 to 255, with 0 being no intensity
/// and 255 being the highest intensity.

typedef struct COREWEBVIEW2_COLOR {

  /// Specifies the intensity of the Alpha ie. opacity value. 0 is transparent,
  /// 255 is opaque.

  BYTE A;

  /// Specifies the intensity of the Red color

  BYTE R;

  /// Specifies the intensity of the Green color

  BYTE G;

  /// Specifies the intensity of the Blue color

  BYTE B;
} COREWEBVIEW2_COLOR;
```
## WinRT
```c#
unsealed runtimeclass CoreWebView2Controller
{
    // ..
    Windows.UI.Color BackgroundColor { get; set; };
}
```
