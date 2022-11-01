Family Safety
===

# Background
Provide end evelolper a new API to toggle Family Safety feature on and off. Once Family Safety is enabled, developer won't be able to turn it off while webview2 instance is running. Once enable, it will provide the same functionally as the browser like: Activity report, Safe Search and Web Filtering. Besides toggling the feature, we also provide an API to add desired sites to the soft bypass list, so app functionality will not be impacted by Family Safety restricted mode. Parents can still over the site if they prefer.
Please see https://www.microsoft.com/en-us/microsoft-365/family-safety for details on Family Safety. 

# Examples
## WinRT and .NET   
```c#
void CreateEnvrionmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.IsFamilySafetyEnabled = true;
    options.SetFamilySafetySoftByPassList(1, "https://appassets.example/AppStartPage.html");
    auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}
```
## Win32 C++
```cpp
HRESULT InitializeWebView()
{
    // Enable the Family Safety feature upon webview environment creation complete
    auto options = Microsoft::WRL::Make<CoreWebView2StagingEnvironmentOptions>();
    Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions3> optionsStaging3;
    if (options.As(&optionsStaging3) == S_OK)
    {
        optionsStaging3->put_IsFamilySafetyEnabled(TRUE);

        const WCHAR* byPassLists[1] = {L"appassets.example/AppStartPage.html"};
        optionsStaging3->SetFamilySafetySoftByPassList(1, byPassLists);
    }

    // CreateCoreWebView2EnvironmentWithOptions
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions("", nullptr, options.Get(),
    Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
        this, &AppWindow::OnCreateEnvironmentCompleted)
        .Get());
}
```

# API Details    
```
interface ICoreWebView2EnvironmentOptions3;

/// Additional options used to create WebView2 Environment.
[uuid(D0965AC5-11EB-4A49-AA1A-C8E9898F80AF), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : IUnknown {
  /// When `IsFamilySafetyEnabled` is `TRUE` WebView2 provides the same Family Safety functionality as the Edge browser for child accounts:
  /// Activity Reporting, Web Filtering and SafeSearch. Please see https://www.microsoft.com/en-us/microsoft-365/family-safety for details.
  /// `IsFamilySafetyEnabled` property is to enable/disable family safety feature.
  /// It is `FALSE` by default.
  [propget] HRESULT IsFamilySafetyEnabled([out, retval] BOOL* value);
  /// Sets the `IsFamilySafetyEnabled` property.
  [propput] HRESULT IsFamilySafetyEnabled([in] BOOL value);

  /// When Family Safety feature is enabled, provide ability to modify the soft by pass list so app remain functioning in BlockAll Mode,
  /// parents can still override the URI if they want the app blocked.
  /// \snippet AppWindow.cpp CoreWebView2FamilySafety
  HRESULT GetFamilySafetySoftByPassList([out] UINT32* uriCounts, [out] LPWSTR** lists);
  HRESULT SetFamilySafetySoftByPassList([in] UINT32 urisCount, [in] LPCWSTR* uris);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2Environment
    {
        // ...
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions3")]
        {
            // ICoreWebView2EnvironmentOptions3 members
            Boolean IsFamilySafetyEnabled { get; set; };

            // List of bypass uris
            IList<String> FamilySafetySoftByPassList { get; set; };
        }
    }
}
```

