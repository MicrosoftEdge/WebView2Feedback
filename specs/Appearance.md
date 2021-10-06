Appearance (Theme) API
===

# Background
This API's main use case is to set the overall appearance for WebView2. The options are similar to Edge: match the system default theme, light theme, or dark theme. 
This API changes thing like dialogs, menus, and web content based on native flags. Please note this API will only set the overall appearance, but not theme.
For reference, in the screenshot below this API is meant to expose the Overall Appearance section as a WebView2 API. 

# Conceptual pages (How To)

How to set theme in webview2. 
1. Query interface. (Situational)
2. Call put_Appearance to set the Appearance property. 
3. The input parameter can be either COREWEBVIEW2_APPEARANCE_TYPE_SYSTEM, COREWEBVIEW2_APPEARANCE_TYPE_LIGHT, or COREWEBVIEW2_APPEARANCE_TYPE_DARK.


# Examples

### C++

```cpp
    wil::com_ptr<ICoreWebView2StagingController2> webViewStagingController2;
    
    bool ViewComponent::QuerySetAppearance(COREWEBVIEW2_APPEARANCE_TYPE appearance){
    
    m_appWindow->GetWebViewController()->QueryInterface(IID_PPV_ARGS(&webViewStagingController2));
    CHECK_FEATURE_RETURN(webViewStagingController2);
    
    // Input can be either:
    // 1. COREWEBVIEW2_APPEARANCE_TYPE_SYSTEM 
    // 2. COREWEBVIEW2_APPEARANCE_TYPE_LIGHT 
    // 3. COREWEBVIEW2_APPEARANCE_TYPE_DARK
    
    webViewStagingController2->put_Appearance(appearance); 

    return true;
    }
    
```

# API Details

```
[uuid(5f817cce-5d36-4cd0-a1d5-aaaf95c8685f), object, pointer_default(unique)]
interface ICoreWebView2StagingController2 : IUnknown {

  /// The Appearance property sets the overall theme of the webview2 instance. 
  /// The input parameter is either COREWEBVIEW2_APPEARANCE_TYPE_SYSTEM, 
  /// COREWEBVIEW2_APPEARANCE_TYPE_LIGHT, or COREWEBVIEW2_APPEARANCE_TYPE_DARK.
  /// Note that this applies to pages, dialogs, and menus.  
  
  /// Returns the value of the `Appearance` property.
  [propget] HRESULT Appearance(
  [out, retval] COREWEBVIEW2_APPEARANCE_TYPE* appearance);

  /// Sets the `Appearance` property.
  [propput] HRESULT Appearance(
    [in] COREWEBVIEW2_APPEARANCE_TYPE appearance);

}
```
