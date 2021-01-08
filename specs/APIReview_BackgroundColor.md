# Background
WebView2 developers have provided feedback that there is a 'white flicker' when navigating between pages. This flicker comes from WebView briefly showing its default background color for when no web page is loaded. Developers should be able to set a custom background color for the WebView that matches the color scheme of their app and avoids this flicker. We have also received feedback requesting the ability to set the WebView's background color transparent. This way developers can create a seamless UI experience where the WebView displays web content directly over host app content. The BackgroundColor API addresses this need.


# Description
The `BackgroundColor` property allows developers to set the color that shows before WebView loads any web content.  The default color is white. This API uses the `COREWEBVIEW2_COLOR` value which is used to specify an RGBA color. The 4 fields of `COREWEBVIEW2_COLOR` have intensity values from 0 to 255 with 0 being the least intense. Important to note is the A value which allows developers to set transparency. An alpha value of 0 is entirely transparent and 255 is opaque. Semi-transparent colors are not currently supported, but the work is pending. The `BackgroundColor` property enables a seamless UI experience. Developers can choose a color to show between loading pages that matches the color scheme of the hosting application. Or do away with the color entirely and just show the hosting app's content.

# Examples
The fields of CoreWebView2Color can be set with plain old integer values between 0 and 255. In the following example, we see the app reading color values from a COLORREF (which are integers under the covers) into a CoreWebView2Color. It then sets the CoreWebView2Color.A value to 0 or 255. Once the CoreWebView2Color value is filled out, it is passed to the controller's put_BackgroundColor API.  
```cpp
void ViewComponent::SetBackgroundColor(COLORREF color, bool transparent)
{
    CoreWebView2Color wvColor;
    wvColor.R = GetRValue(color);
    wvColor.G = GetGValue(color);
    wvColor.B = GetBValue(color);
    wvColor.A = transparent ? 0 : 255;
    m_controller->put_BackgroundColor(wvColor);
}
```


# Remarks
Currently translucent colors are not supported by the API. This work is being tracked and will be added later. Passing a CoreWebView2Color value with an A value greater than 0 or less than 255 will result in an error.


# API Notes


# API Details
```cpp
[uuid(4d00c0d1-9434-4eb6-8078-8697a560334f), object, pointer_default(unique)]
interface ICoreWebView2Controller : IUnknown {

  // ...

  /// This property can be modified to get and set the color that shows before the WebView
  /// has loaded any web content.
  [propget] HRESULT BackgroundColor([out, retval] CoreWebView2Color* backgroundColor);
  [propput] HRESULT BackgroundColor([in] CoreWebView2Color backgroundColor);
}


/// A value representing color for WebView2
typedef struct CoreWebView2Color {
  BYTE A;
  BYTE R;
  BYTE G;
  BYTE B;
} CoreWebView2Color;
```

# Appendix
