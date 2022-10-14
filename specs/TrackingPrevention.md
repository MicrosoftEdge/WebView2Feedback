Tracking Prevention
===

# Background
The WebView2 team has been asked for an API to toggle tracking prevention and also ability to control levels of tracking prevention.

We are proposing two API's
IsTrackingPreventionEnabled: This API allows you to enable/disable the tracking prevention feature. By default tracking prevention feature is enabled
and set to `Balanced` level for WebView2. You can set the `CoreWebView2EnvironmentOptions.IsTrackingPreventionEnabled` property to false to disable
the tracking prevention feature for WebView2 before creating environment that also skips the related code and improves the performance.

TrackingPreventionUserPreference: This API allows you to control levels of tracking prevention for WebView2 which are associated with a profile when
feature is enabled otherwise TrackingPreventionUserPreference is CoreWebView2TrackingPreventionUserPreferenceKind.Off and can't be changed to other kinds.
The levels are similar to Edge: off, basic, balanced and strict.

For reference, in the screenshot below, this API sets the levels of tracking prevention as a WebView2 API.

![Edge Tracking Prevention](images/TrackingPreventionLevels.png)

# Examples
## IsTrackingPreventionEnabled

```c#
/// Create WebView Environment with option that disable tracking prevention feature.

void CreateEnvironmentWithOption()
{
    CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
    options.IsTrackingPreventionEnabled = false;
    CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(BrowserExecutableFolder, UserDataFolder, options);
}
```

```cpp
Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions3> options3;
if (options.As(&options3) == S_OK)
{
    CHECK_FAILURE(options3->put_IsTrackingPreventionEnabled(FALSE));
}
```

## TrackingPreventionUserPreference
/// Example to set level of tracking preference.

```c#
/// Below example set user level of tracking preference.

void TrackingPreventionUserPrefCommandExecuted(object target, ExecutedRoutedEventArgs e)
{
    try
    {
        string userPreference = e.Parameter.ToString();
        if (userPreference == "Off")
        {
            WebViewProfile.TrackingPreventionUserPreference = CoreWebView2TrackingPreventionUserPreferenceKind.Off;
        }
        else if (userPreference == "Basic")
        {
            WebViewProfile.TrackingPreventionUserPreference = CoreWebView2TrackingPreventionUserPreferenceKind.Basic;
        }
        else if (userPreference == "Balanced")
        {
            WebViewProfile.TrackingPreventionUserPreference = CoreWebView2TrackingPreventionUserPreferenceKind.Balanced;
        }
        else
        {
            WebViewProfile.TrackingPreventionUserPreference = CoreWebView2TrackingPreventionUserPreferenceKind.Strict;
        }
    }
    catch (NotImplementedException exception)
    {
        MessageBox.Show(this,
           "Failed to set tracking prevention user preference: " +
           exception.Message, "Tracking Prevention User Preference");
    }
}
```

```cpp
void SettingsComponent::SetTrackingPreventionUserPreference(
    COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND value)
{
    wil::com_ptr<ICoreWebView2_13> webView2_13;
    webView2_13 = m_webView.try_query<ICoreWebView2_13>();

    if (webView2_13)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webView2_13->get_Profile(&profile));

        auto profile5 = profile.try_query<ICoreWebView2Profile5>();
        if (profile5)
        {
            profile5->put_TrackingPreventionUserPreference(value);
        }
    }
}
```

# API Details
```
/// Tracking prevention user preference kind.
[v1_enum] typedef enum COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND {
  COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_OFF,
  /// The least restrictive level of tracking prevention for users who enjoy
  /// personalized advertisements and who do not mind being tracked on the web.
  /// This only protects users against malicious trackers such as fingerprints and crypto miners.
  COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_BASIC,
  /// The default level of tracking prevention for users who want to see less creepy
  /// advertisements that follow them around the web while they browse. Balanced aims to
  /// block trackers from sites that users never engage with while minimizing the risk of
  /// compatibility issues on the web.
  COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_BALANCED,
  /// The most restrictive level of tracking prevention for users who are okay
  /// trading website compatibility for maximum privacy.
  COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_STRICT,
} COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND;

/// Additional options used to create WebView2 Environment.
[uuid(12e494a2-c876-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : IUnknown {
  /// The `IsTrackingPreventionEnabled` property is used to toggle tracking prevention feature in WebView2.
  /// By default this feature is enabled and set to `COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_BALANCED`.
  /// You can set this property to false to disable the tracking prevention feature that also skips the related code and
  /// improves the performance.
  ///
  /// Tracking prevention protects users from online tracking by restricting
  /// the ability of trackers to access browser-based storage as well as the network.
  /// See [Tracking prevention](microsoft-edge/web-platform/tracking-prevention).
  // MSOWNERS: monicach@microsoft.com
  [propget] HRESULT IsTrackingPreventionEnabled([out, retval]  BOOL* value);
  /// Sets the `IsTrackingPreventionEnabled` property.
  // MSOWNERS: monicach@microsoft.com
  [propput] HRESULT IsTrackingPreventionEnabled([in]  BOOL value);
}

/// This is the ICoreWebView2 profile.
[uuid(ddc4070a-c873-11eb-b8bc-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2Profile5: IUnknown {
  /// The kind of tracking prevention user preference.
  /// See `COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND` for descriptions of levels.
  ///
  /// `TrackingPreventionUserPreference` will be `COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND_OFF`
  /// if `IsTrackingPreventionEnabled` of `ICoreWebView2EnvironmentOptions3` is false and can't be changed
  /// to other kinds.
  // MSOWNERS: monicach@microsoft.com
  [propget] HRESULT TrackingPreventionUserPreference(
      [out, retval] COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND* value);
  /// Set the `TrackingPreventionUserPreference` property.
  // MSOWNERS: monicach@microsoft.com
  [propput] HRESULT TrackingPreventionUserPreference(
      [in] COREWEBVIEW2_TRACKING_PREVENTION_USER_PREFERENCE_KIND value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2TrackingPreventionUserPreferenceKind
    {
        Off = 0,
        Basic = 1,
        Balanced = 2,
        Strict = 3,
    };

    // ...
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions3")]
        {
            // ICoreWebView2EnvironmentOptions3 members
            Boolean IsTrackingPreventionEnabled { get; set; };
        }
    }

    runtimeclass CoreWebView2Profile
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile5")]
        {
            // ICoreWebView2Profile5 members
            CoreWebView2TrackingPreventionUserPreferenceKind TrackingPreventionUserPreference { get; set; };
        }
    }
}
```
