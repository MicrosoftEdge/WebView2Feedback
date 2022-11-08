Family Safety
===

# Background
Our customers have asked for a new API to toggle the Family Safety feature on and off. The Family 
Safety feature is enabled or disabled for a browser process instance, and the end developer 
won't be able to change it while the webview2 browser process instance is running. Once enabled, 
it will provide the same functionally as the browser Family Safety feature including: Activity 
reports, search filtering, and web filtering. Besides toggling the feature, we also provide an 
API to add desired sites to the allowed uris, so app functionality will not be impacted by 
Family Safety. Additionally, parents can also override a block.
Please see https://www.microsoft.com/en-us/microsoft-365/family-safety for details on Family Safety. 

# Examples
## WinRT and .NET   
```c#
void CreateEnvrionmentWithOption()
{
    // If parents set filtering rules to only allowed sites. App developers can use
    // FamilySafetyAllowedUris to show app content and still honor general filter settings set
    // by parents.
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.IsFamilySafetyEnabled = true;
    // appassets.example is used as an example app content.
    options.FamilySafetyAllowedUris.Add("appassets.example");
    auto environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}
```
## Win32 C++
```cpp
HRESULT InitializeWebView()
{
    // If parents set filtering rules to only allowed sites. App developers can use
    // FamilySafetyAllowedUris to show app content and still honor general filter settings set
    // by parents.
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    options->put_IsFamilySafetyEnabled(TRUE);
    // appassets.example is used as an example app content.
    const WCHAR* allowedUris[1] = {L"appassets.example"};
    options->SetFamilySafetyAllowedUris(1, allowedUris);
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
  /// `IsFamilySafetyEnabled` property is to enable/disable family safety feature.
  /// It is `FALSE` by default.
  /// When `IsFamilySafetyEnabled` is `TRUE` WebView2 provides the same Family Safety 
  /// functionality as the Edge browser. 
  /// Family Safety is a set of features available on Windows for managing children Internet 
  /// priviliges. Microsoft account may be linked to have a family relationship, with adults 
  /// and children. Adults have certain managements options over the children in their family, 
  /// where each option is applied per-child. Edge browser provide the following options: 
  /// Activity reporting, Web filtering and SafeSearch. Please see 
  /// https://aka.ms/EdgeFamilySafetyFeatureOverview for more details on each feature.
  [propget] HRESULT IsFamilySafetyEnabled([out, retval] BOOL* value);
  /// Sets the `IsFamilySafetyEnabled` property.
  [propput] HRESULT IsFamilySaFetyEnabled([in] BOOL value);

  /// `GetFamilySafetyAllowedUris` and `SetFamilySafetyAllowedUris` allow developers to get and set
  /// the list of URIs that will be allowed by the Family Safety filter even when in Block All mode.
  /// Each uri need to be added to the list indivually even with the same domain. No prefix needed
  /// for the uri. Eg: `bing.com`. 
  /// Family Safety provides web filtering control in two modes: Allow-all and Block-all. In 
  /// Allow-all mode, only sites that are blocked by the parents will be blocked. In 
  /// blocked-all mode, only allowed sites that are allowed by the parents are allowed. In this 
  /// scenario, apps using WebView2 will have their content blocked if enabled Family Safety in WebView2.
  /// Please see https://aka.ms/EdgeFamilySafetyContentFiltering for more details.
  /// \snippet AppWindow.cpp CoreWebView2FamilySafety
  HRESULT GetFamilySafetyAllowedUris([out] UINT32* uriCounts, [out] LPWSTR** lists);
  HRESULT SetFamilySafetyAllowedUris([in] UINT32 urisCount, [in] LPCWSTR* uris);
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

            // List of allowed uris
            IVector<String> FamilySafetyAllowedUris { get; };
        }
    }
}
```

