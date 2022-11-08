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
    // appassets.example/AppStartPage.html is used as an example app content.
    options.FamilySafetyAllowedUris.Add("appassets.example/AppStartPage.html");
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

        const WCHAR* allowedUris[1] = {L"appassets.example/AppStartPage.html"};
        optionsStaging3->SetFamilySafetyAllowedUris(1, allowedUris);
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
  /// Family Safety is a set of features available on Windows for managing children Internet 
  /// priviliges. Microsoft account may be linked to have a family relationship, with adults 
  /// and children. Adults have certain managements options over the children in their family, 
  /// where each option is applied per-child. Edge browser provide the following options: 
  /// Activity reporting, Web filtering and SafeSearch. Please see https://support.microsoft.com/en-us/account-billing/getting-started-with-microsoft-family-safety-b6280c9d-38d7-82ff-0e4f-a6cb7e659344 for more 
  /// details on each feature.
  /// When `IsFamilySafetyEnabled` is `TRUE` WebView2 provides the same Family Safety 
  /// functionality as the Edge browser. 
  /// `IsFamilySafetyEnabled` property is to enable/disable family safety feature.
  /// It is `FALSE` by default.
  [propget] HRESULT IsFamilySafetyEnabled([out, retval] BOOL* value);
  /// Sets the `IsFamilySafetyEnabled` property.
  [propput] HRESULT IsFamilySafetyEnabled([in] BOOL value);

  /// Family Safety provides web filtering control in two modes: Allow-all and Block-all. In 
  /// Allow-all mode, only sites that are blocked by the parents will be blocked. In 
  /// blocked-all mode, only allowed sites that are allowed by the parents are allowed. In this 
  /// scenario, apps using WebView2 will have their content blocked if enabled Family Safety in WebView2.
  /// `SetFamilySafetyAllowedUris` provide the ability to add app content sites to a soft override 
  /// list and allow app contents to go through in Block All Mode. Parents still have control
  /// to override those sites.
  /// Each uri need to be added to the list indivually even with the same domain. No prefix needed
  /// for the uri. Eg: `bing.com`. 
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

