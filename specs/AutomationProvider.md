# Background
WebView has two hosting modes, windowed (which uses the ICoreWebView2Controller) and visual (which uses the ICoreWebView2CompositionController). Accessibility for the windowed WebView is able to walk the HWND tree to know where to place the WebView in the accessibility tree. For visual hosting, accessibility is not able to know where within the accessibility tree to place the WebView. This results in a WebView being a sibling to the rest of the app content.

In this document we describe the updated API so visual-hosted WebViews are correctly managed by accessibility. We'd appreciate your feedback.


# Description
To give apps using the ICoreWebView2CompositionController more control over how the WebView is positioned in the accessibility tree, we are adding new APIs to let the app retrieve the automation provider for the WebView. This let's the app return the automation provider as part of its accessibility tree.

While traversing child elements, when the app reaches the WebView, it can use the `UIAProvider` property to get the automation provider for the WebView and return it.

When accessibility is traversing parent elements, the app needs to implement IRawElementProviderHwndOverride. The HWND parameter from GetOverrideProviderForHwnd can be passed to `GetProviderForHwnd` to get the automation provider for the corresponding WebView.

# Examples
```cpp
HRESULT WebView2AutomationPeer::GetRawElementProviderSimple(IRawElementProviderSimple** value)
{
    wil::com_ptr<IUnknown> provider;
    CHECK_FAILURE(m_controller->get_AutomationProvider(&provider));
    return provider->QueryInterface(IID_PPV_ARGS(value));
}

// Find the WebView2AutomationPeer for the HWND from
// IRawElementProviderHwndOverride::GetOverrideProviderForHwnd
bool WebView2AutomationPeer::IsAutomationPeerForWindow(HWND window)
{
    wil::com_ptr<IUnknown> provider;
    CHECK_FAILURE(m_controller->get_AutomationProvider(&provider));

    wil::com_ptr<IUnknown> providerForWindow;
    CHECK_FAILURE(m_environment->GetAutomationProviderForWindow(window, &providerForWindow));

    return (provider == providerForWindow);
}
```

# API Notes
See [API Details](#api_details) section below for API reference.

# API Details
## Win32 C++
``` c#
interface ICoreWebView2Environment4 : ICoreWebView2Environment3 {
  /// Returns the UI Automation Provider for the WebView that matches the provided window.
  /// Host apps are expected to implement IRawElementProviderHwndOverride. When GetOverrideProviderForHwnd
  /// is called, the app can pass the HWND to GetAutomationProviderForWindow to find the matching WebView
  /// automation provider.
  HRESULT GetAutomationProviderForWindow([in] HWND window,
                             [out, retval] IUnknown** provider);
}

interface ICoreWebView2CompositionController2 : ICoreWebView2CompositionController {
  /// Returns the UI Automation Provider for the WebView.
  [propget] HRESULT AutomationProvider([out, retval] IUnknown** provider);
}
```
## .Net and WinRT
API is not natively supported in .Net and WinRT. The Win32 COM API is exposed using an interop interface.
