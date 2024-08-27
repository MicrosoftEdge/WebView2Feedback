Origin Settings
===

# Background
Purpose of this API is to provide devloper the ability to control different security related
features by origins. Developer can chose to trust a origin, for example 'microsoft.com' and
toggle differnt security features for this origin. If user navigate to such origin, settings
like auto audio play can be applied.

# Examples
## WinRT and .NET   
```c#

```

## Win32 C++
```cpp

```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++

```c++
interface ICoreWebView2OriginSetting;
interface ICoreWebView2Profile21;

[v1_enum]
typedef enum COREWEBVIEW2_ORIGIN_SETTING_STATE {
  COREWEBVIEW2_ORIGIN_SETTING_STATE_DEFAULT,
  COREWEBVIEW2_ORIGIN_SETTING_STATE_ON,
  COREWEBVIEW2_ORIGIN_SETTING_STATE_OFF,
} COREWEBVIEW2_ORIGIN_SETTING_STATE;


[uuid(e8240179-1b27-5ce2-84b2-ea187e3e91ec), object, pointer_default(unique)]
interface ICoreWebView2OriginSetting : IUnknown {
  // Origins that match a certain pattern
  [propget] HRESULT OriginMatch([out, retval] LPWSTR* value);
  [propput] HRESULT OriginMatch([in] LPCWSTR value);
  
  // Growing list of features that developer can decide to toggle the state.
  // Once enable, uri matching the above origin will grant developer the ability to accessing these features.
  // All feature default to be disabled by default.
  [propget] HRESULT EnhancedSecurityMode([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);
  [propput] HRESULT EnhancedSecurityMode([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);
  [propget] HRESULT SmartScreen([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);
  [propput] HRESULT SmartScreen([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);
  [propget] HRESULT SystemAccentColor([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);
  [propput] HRESULT SystemAccentColor([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);
  [propget] HRESULT MediaAutoPlay([out, retval] COREWEBVIEW2_ORIGIN_SETTING_STATE* value);
  [propput] HRESULT MediaAutoPlay([in] COREWEBVIEW2_ORIGIN_SETTING_STATE value);
}

[uuid(558ba548-eb04-4d92-9207-3b1c838878bd), object, pointer_default(unique)]
interface ICoreWebView2Profile21 : IUnknown {
  // Array of origin settings.
  HRESULT GetOriginSettings(
      [out] UINT32* count,
      [out] ICoreWebView2OriginSetting*** originSettings);
  // Set the array of origin settings to use.
  HRESULT SetOriginSettings(
      [in] UINT32 count,
      [in] const ICoreWebView2OriginSetting** originSettings);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    enum CoreWebView2OriginSettingState
    {
        Default = 0,
        On = 1,
        Off = 2,
    };

    runtimeclass CoreWebView2Profile
    {
        IVector<CoreWebView2OriginSetting> OriginSettings { get; set; };

        // ...
    }

    runtimeclass CoreWebView2OriginSetting
    {
        String OriginMatch { get; };
        CoreWebView2OriginSettingState EnhancedSecurityMode { get; set; };
        CoreWebView2OriginSettingState SmartScreen { get; set; };
        CoreWebView2OriginSettingState SystemAccentColor { get; set; };
        CoreWebView2OriginSettingState MediaAutoPlay { get; set; };
    }

    // ...
}
```