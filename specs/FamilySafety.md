Family Safety
===

# Background
Provide end evelolper a new API to toggle Family Safety feature on and off. End developer can use this API to enable and disable the Family Safety feature. Also provided a iframe filter toggle API to ensure iframes also go through Family Safety services for all subframe navigations.

# Examples
## WinRT and .NET   
```c#
void FamilySafetyFeatureCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.IsFamilySafetyFeatureEnabled = !webView.IsFamilySafetyFeatureEnabled;
    MessageBox.Show("Family Safety is" + (webView.IsFamilySafetyFeatureEnabled ? " enabled " : " disabled ") + "after the next ?????.");
}

void FamilySafetyIframeFilterCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.IsFamilySafetyFirstLevelIFrameFilteringEnabled = !webView.IsFamilySafetyFirstLevelIFrameFilteringEnabled;
    MessageBox.Show("Family Safety iframe filering is" + (webView.IsFamilySafetyFirstLevelIFrameFilteringEnabled ? " enabled " : " disabled ") + "after the next navigation.");
}


```
## Win32 C++
```cpp

// Enable the feature
HRESULT ToggleFamilySafetyFeature()
{
    BOOL areFSEnabled;
    wil::com_ptr<ICoreWebView2Staging3> webview3 =
        m_webView.try_query<ICoreWebView2Staging3>();
    CHECK_FAILURE(webview3->get_IsFamilySafetyFeatureEnabled(
        &areFSEnabled));
    CHECK_FAILURE(webview3->get_IsFamilySafetyFeatureEnabled(
        !areFSEnabled));
    MessageBox(
        nullptr,
        (std::wstring(L"Family Safety will be ") +
            (!areFSEnabled ? L"enabled" : L"disabled") +
            L" after the next ????.").c_str(),
        L"Settings change", MB_OK);
    return true;
}

// Toggle the iframe filter settings
HRESULT ToggleFamilySafetyIframeFilterSettings()
{
    BOOL areIframeFilterEnabled;
    wil::com_ptr<ICoreWebView2Staging3> webview3 =
        m_webView.try_query<ICoreWebView2Staging3>();
    CHECK_FAILURE(webview3->get_IsFamilySafetyFirstLevelIFrameFilteringEnabled(
        &areIframeFilterEnabled));
    CHECK_FAILURE(webview3->put_IsFamilySafetyFirstLevelIFrameFilteringEnabled(
        !areIframeFilterEnabled));
    MessageBox(
        nullptr,
        (std::wstring(L"Iframe Filtering will be ") +
            (!areIframeFilterEnabled ? L"enabled" : L"disabled") +
            L" after the next navigation.").c_str(),
        L"Settings change", MB_OK);
    return true;
}
```

# API Details    
```
interface ICoreWebView2Staging3;

/// A continuation of the ICoreWebView2 interface to toggle Family Safety settings
[uuid(EF7E5FD3-6FAD-4065-8387-15A37288477E), object, pointer_default(unique)]
interface ICoreWebView2Staging3 : IUnknown {
  /// `IsFamilySafetyFeatureEnabled` property is to enable/disable family safety feature.
  [propget] HRESULT IsFamilySafetyFeatureEnabled([out, retval] BOOL* value);

  /// Sets the `IsFamilySafetyFeatureEnabled` property.
  [propput] HRESULT IsFamilySafetyFeatureEnabled([in] BOOL value);

  /// `IsFamilySafetyFirstLevelIFrameFilteringEnabled` property is to enable/disable first level iframe support in family safety.
  [propget] HRESULT IsFamilySafetyFirstLevelIFrameFilteringEnabled([out, retval] BOOL* value);

  /// Sets the `IsFamilySafetyFirstLevelIFrameFilteringEnabled` property.
  [propput] HRESULT IsFamilySafetyFirstLevelIFrameFilteringEnabled([in] BOOL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2
    {
        {
            // ICoreWebView2 members
            Boolean IsFamilySafetyFeatureEnabled { get; set; };
            Boolean IsFamilySafetyFirstLevelIFrameFilteringEnabled { get; set; };
        }

        // ...
    }
}
```

