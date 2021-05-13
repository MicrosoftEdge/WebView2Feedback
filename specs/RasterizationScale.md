# Background
The WebView attempts to detects monitor scale changes and applies the monitor DPI scale to all UI produced by the WebView.
When the host app has a DPI awareness of PerMonitorV2, then all child HWNDs receive WM_DPICHANGED.
The WebView can check the current monitor DPI scale when it receives WM_DPICHANGED.
But if the host app is just PerMonitor aware (not v2), then only the top level window receives WM_DPICHANGED.
The WebView could try to use other metrics (like resize) to check the DPI, but resize is not guaranteed in that scenario.
From [GitHub feedback](https://github.com/MicrosoftEdge/WebView2Feedback/issues/65),
we also know that there are consumers of WebView that want to explicitly set a custom DPI scale for WebView.

In this document we describe the updated API. We'd appreciate your feedback.


# Description
To allow the app to control the DPI scale of WebView, we are adding a `RasterizationScale` property to the CoreWebView2Controller interface.
The RasterizationScale property controls the DPI scaling for all UI in WebView.

In order to maintain compatibility with apps developed before this API existed,
WebView2 continues to detect monitor scale changes by default and will update the RasterizationScale property.
When the RasterizationScale property is updated, the `RasterizationScaleChanged` event is raised.
The app can tell WebView2 to stop updating the RasterizationScale property by changing
`ShouldDetectMonitorDpiScaleChanges` from the default value of true, to false.

# Examples
The following code snippets show how to use the RasterizationScale and ShouldDetectMonitorScaleChanges properties,
and now to listen to the RasterizationScaleChanged event.
## Win32 C++
```cpp
void ViewComponent::SetRasterizationScale(float additionalScale)
{
    CHECK_FAILURE(m_controller->put_ShouldDetectMonitorScaleChanges(FALSE));
    m_webviewAdditionalRasterizationScale = additionalScale;
    // RasterizationScale is typically the monitor DPI scale and text scaling, but
    // the app could add an additional scale for its own scenarios.
    double rasterizationScale =
        additionalScale * m_appWindow->GetDpiScale() * m_appWindow->GetTextScale();
    CHECK_FAILURE(m_controller->put_RasterizationScale(rasterizationScale));
}

Callback<ICoreWebView2RasterizationScaleChangedEventHandler>(
    [this](ICoreWebView2Controller* sender, IUnknown* args) -> HRESULT {
        double rasterizationScale;
        CHECK_FAILURE(m_controller->get_RasterizationScale(&rasterizationScale));

        std::wstring message = L"WebView2APISample (RasterizationScale: " +
            std::to_wstring(int(rasterizationScale * 100)) + L"%)";
        SetWindowText(m_appWindow->GetMainWindow(), message.c_str());
        return S_OK;
    })
.Get(), &m_rasterizationScaleChangedToken));
```
## .Net
```c#
public void SetRasterizationScale(double additionalScale)
{
    CoreWebView2Controller.ShouldDetectMonitorScaleChanges = false;
    m_webviewAdditionalRasterizationScale = additionalScale;
    
    // RasterizationScale is typically the monitor DPI scale and text scaling, but
    // the app could add an additional scale for its own scenarios.
    double rasterizationScale = additionalScale * GetDpiScale() * GetTextScale();
    CoreWebView2Controller.RasterizationScale = rasterizationScale;
}
```


# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++
```c#
interface ICoreWebView2Controller2 : ICoreWebView2Controller {
  /// The rasterization scale for the WebView. The rasterization scale is the
  /// combination of the monitor DPI scale and text scaling set by the user.
  /// This value should be updated when the DPI scale of the app's top level
  /// window changes (i.e. monitor DPI scale changes or window changes monitor)
  /// or when the text scale factor of the system changes.
  ///
  /// \snippet AppWindow.cpp DPIChanged
  ///
  /// \snippet AppWindow.cpp TextScaleChanged1
  ///
  /// \snippet AppWindow.cpp TextScaleChanged2
  ///
  /// Rasterization scale applies to the WebView content, as well as
  /// popups, context menus, scroll bars, and so on. Normal app scaling scenarios
  /// should use the ZoomFactor property or SetBoundsAndZoomFactor API which
  /// only scale the rendered HTML content and not popups, context menus, scroll bars and so on.
  ///
  /// \snippet ViewComponent.cpp RasterizationScale
  [propget] HRESULT RasterizationScale([out, retval] double* scale);
  // Set the rasteriation scale property.
  [propput] HRESULT RasterizationScale([in] double scale);

  /// ShouldDetectMonitorScaleChanges property determines whether the WebView
  /// attempts to track monitor DPI scale changes. When true, the WebView will
  /// track monitor DPI scale changes, update the RasterizationScale property,
  /// and raises RasterizationScaleChanged event. Attempting to set RasterizationScale
  /// while ShouldDetectMonitorScaleChanges is true will result in RasterizationScaleChanged
  /// being raised and the value restored to match the monitor DPI scale.
  /// When false, the WebView will not track monitor DPI scale changes, and the app
  /// must update the RasterizationScale property itself. RasterizationScaleChanged
  /// event will never raise when ShouldDetectMonitorScaleChanges is false.
  [propget] HRESULT ShouldDetectMonitorScaleChanges([out, retval] BOOL* value);
  /// Set the ShouldDetectMonitorScaleChanges property.
  [propput] HRESULT ShouldDetectMonitorScaleChanges([in] BOOL value);

  /// Add an event handler for the RasterizationScaleChanged event.
  /// The event is raised when the WebView detects that the monitor DPI scale
  /// has changed, ShouldDetectMonitorScaleChanges is true, and the WebView has
  /// changed the RasterizationScale property.
  ///
  /// \snippet ViewComponent.cpp RasterizationScaleChanged
  HRESULT add_RasterizationScaleChanged(
    [in] ICoreWebView2RasterizationScaleChangedEventHandler*
        eventHandler,
    [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with
  /// add_RasterizationScaleChanged.
  HRESULT remove_RasterizationScaleChanged(
    [in] EventRegistrationToken token);
}
interface ICoreWebView2RasterizationScaleChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event. There are no event args and the args
  /// parameter will be null.
  HRESULT Invoke(
    [in] ICoreWebView2Controller2* sender,
    [in] IUnknown* args);
}
```
## .Net and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    unsealed runtimeclass CoreWebView2Controller
    {
        /// <summary>
        /// Gets or sets the WebView rasterization scale.
        /// </summary>
        /// <remarks>
        /// The rasterization scale is the combination of the monitor DPI scale and text scaling set by the user. This value should be updated when the DPI scale of the app's top level window changes (i.e. monitor DPI scale changes or the window changes monitor) or when the text scale factor of the system changes.
        /// Rasterization scale applies to the WebView content, as well as popups, context menus, scroll bars, and so on. Normal app scaling scenarios should use the <see cref="CoreWebView2.ZoomFactor"/> property or <see cref="CoreWebView2.SetBoundsAndZoomFactor"/> method.
        /// </remarks>
        Double RasterizationScale { get; set; };

        /// <summary>
        /// Determines whether the WebView will detect monitor scale changes.
        /// </summary>
        /// <remarks>
        /// ShouldDetectMonitorScaleChanges property determines whether the WebView attempts to track monitor DPI scale schanges. When true, the WebView will track monitor DPI scale changes, update the <see cref="CoreWebView2.RasterizationScale"/> property, and raise <see cref="CoreWebView2.RasterizationScaleChanged"/> event. When false, the WebView will not track monitor DPI scale changes, and the app must update the <see cref="CoreWebView2.RasterizationScale"/> property itself. <see cref="CoreWebView2.RasterizationScaleChanged"/> event will never be raised when ShouldDetectMonitorScaleChanges is false.
        /// </remarks>
        Boolean ShouldDetectMonitorScaleChanges { get; set; };

        /// <summary>
        /// RasterizationScalechanged is raised when the <see cref="CoreWebView2Controller.RasterizationScale"/> property changes.
        /// </summary>
        /// <remarks>
        /// The event is raised when the Webview detects that the monitor DPI scale has changed, <see cref="CoreWebView2Controller.ShouldDetectMonitorScaleChanges"/> is true, and the Webview has changed the <see cref="CoreWebView2Controller.RasterizationScale"/> property.
        /// </remarks>
        /// <seealso cref="CoreWebView2Controller.RasterizationScale"/>
        event Windows.Foundation.TypedEventHandler<CoreWebView2Controller, Object> RasterizationScaleChanged;
    }
```
