Family Safety
===

# Background
Provide end evelolper a new API to toggle Family Safety feature on and off. Once Family Safety is enabled, developer won't be able to turn it off while webview2 instance is running. Once enable, it will provide the same functionally as the browser like: Activity report, Safe Search and Web Filtering. Please see https://www.microsoft.com/en-us/microsoft-365/family-safety for details on Family Safety. 

# Examples
## WinRT and .NET   
```c#
void WebView_ProcessInfosChanged(object sender, object e)
{
    WebViewEnvironment.IsFamilySafetyEnabled = true;
}


```
## Win32 C++
```cpp
// Enable the Family Safety feature upon webview environment creation complete
HRESULT ToggleFamilySafetyFeature()
{
    auto environmentStaing = m_webViewEnvironment.try_query<ICoreWebView2StagingEnvironment>();
    CHECK_FEATURE_RETURN(environmentStaing);
    environmentStaing->put_IsFamilySafetyEnabled(true);
}
```

# API Details    
```
interface ICoreWebView2Environment11;

/// This interface is an extension of the ICoreWebView2Environment that manages
/// Family Safety settings. An object implementing the
/// ICoreWebView2ExperimentalEnvironment3 interface will also implement
/// ICoreWebView2Environment.
[uuid(D0965AC5-11EB-4A49-AA1A-C8E9898F80AF), object, pointer_default(unique)]
interface ICoreWebView2Environment11 : ICoreWebView2Environment {
  /// When the Family Safety feature is enabled, webview provide the same functionalities as the browser for the child accounts:
  /// Activity Reporting, Web Filtering and SafeSearch.
  /// `IsFamilySafetyEnabled` property is to enable/disable family safety feature.
  /// propery is disabled by default
  [propget] HRESULT IsFamilySafetyEnabled([out, retval] BOOL* value);
  /// Sets the `IsFamilySafetyEnabled` property.
  [propput] HRESULT IsFamilySafetyEnabled([in] BOOL value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2Environment
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingEnvironment")]
        {
            // ICoreWebView2StagingEnvironment members
            Boolean IsFamilySafetyEnabled { get; set; };
        }
    }
}
```

