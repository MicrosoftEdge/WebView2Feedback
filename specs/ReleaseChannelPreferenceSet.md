ReleaseChannels.md
===

# Background
The [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) is based on
the evergreen Chromium platform that receives monthly major updates. You should ensure that your
app works well with incoming browser changes by testing regularly against the WebView2 prerelease
builds, which ship along with the [Edge preview channels](https://www.microsoft.com/en-us/edge/download/insider?form=MA13FJ):
Canary (daily), Dev (weekly), and Beta (every 4 weeks). Prerelease testing can help you catch
issues before they reach the stable WebView2 Runtime and affect end users.

## Channel overview

|Channel|Primary purpose|How often updated with new features|
|:---:|---|:---:|
|Stable (WebView2 Runtime)|Broad Deployment|~4 weeks|
|Beta|Flighting with inner rings, automated testing|~4 weeks|
|Dev|Automated testing, selfhosting to test new APIs and features|Weekly|
|Canary|Automated testing, selfhosting to test new APIs and features|Daily|

To make it easier to implement prerelease testing, the WebView2 team is adding new environment
options for channel selection, `ReleaseChannels` and `ChannelSearchKind`.
These options can be used together to specify which channels the WebView2 loader should search for
in order of least to most stable: Canary -> Dev -> Beta -> Stable WebView2 Runtime.
For example, you can set `ChannelSearchKind` to `LeastStable` and specify {Beta, Stable}
to tell the WebView2 loader to try running the app with Beta channel if it exists on the machine,
and otherwise fall back on the stable WebView2 Runtime. With the new options you can:
- Run automated tests against different channels on a machine with multiple channels installed
- Target a particular channel when flighting
- Apply different channels to different flighting rings
- Fall back on a more stable preview channel

# Examples
## ReleaseChannels
The release channels and channel search order are specified on the
CoreWebView2EnvironmentOptions prior to creating the WebView2 environment.
```c#
CoreWebView2Environment _webViewEnvironment;
async System.Threading.Tasks.Task CreateEnvironmentAsync() {
    CoreWebView2ReleaseChannels channels =
        CoreWebView2ReleaseChannels.Beta | CoreWebView2ReleaseChannels.Stable;
    CoreWebView2EnvironmentOptions customOptions = new CoreWebView2EnvironmentOptions
    (
        channelSearchKind: CoreWebView2ChannelSearchKind.LeastStable,
        releaseChannels: channels
    );
    // Use GetAvailableCoreWebView2BrowserVersionString to check which
    // channel is used with the custom options. If Beta channel was not found,
    // install it on the device.
    string version =
        CoreWebView2Environment.GetAvailableBrowserVersionString(
            browserExecutableFolder: null,
            environmentOptions: customOptions);
    if (!IsBetaChannel(version))
    {
        InstallChannel(CoreWebView2ReleaseChannels.Beta);
    }
    // If the loader is unable to find a valid installation from the runtime
    // channel preference set, environment creation will fail.
    _webViewEnvironment = await CoreWebView2Environment.CreateAsync(
        options: customOptions);
    if (_webViewEnvironment != null)
    {
        CheckChannel(_webviewEnvironment.BrowserVersionString());
    }
}
```
```cpp
void AppWindow::InitializeWebViewEnvironment()
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CHECK_FAILURE(options->put_ChannelSearchKind(
        COREWEBVIEW2_CHANNEL_SEARCH_KIND_LEAST_STABLE));
    COREWEBVIEW2_RELEASE_CHANNELS channels =
        COREWEBVIEW2_RELEASE_CHANNELS_BETA |
        COREWEBVIEW2_RELEASE_CHANNELS_STABLE;
    CHECK_FAILURE(options->put_ReleaseChannels(channels));
    // Use GetAvailableCoreWebView2BrowserVersionStringWithOptions to check which
    // channel is used with the custom options. If Beta channel was not found,
    // install it on the device.
    wil::unique_cotaskmem_string version;
    CHECK_FAILURE(GetAvailableCoreWebView2BrowserVersionStringWithOptions(
        nullptr, options.Get(), &version));
    if (!IsBetaChannel(version.get()))
    {
        InstallChannel(COREWEBVIEW2_RELEASE_CHANNELS_BETA);
    }
    // If the loader is unable to find a valid installation from the runtime
    // channel preference set, environment creation will fail with
    // HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND).
    CHECK_FAILURE(CreateCoreWebView2EnvironmentWithOptions(
        nullptr, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get()));
}
void AppWindow::OnCreateEnvironmentCompleted(
    HRESULT result, ICoreWebView2Environment* environment)
{
    if (environment)
    {
        wil::unique_cotaskmem_string version;
        CHECK_FAILURE(environment->get_BrowserVersionString(&version));
        CheckChannel(version.get());
    }
}
```
# API Details
```
/// The channel search kind determines the order that release channels are
/// searched for during environment creation. The default behavior is to search
/// for and use the most stable channel found on the device. The order from most
/// to least stable is: WebView2 Runtime -> Beta -> Dev -> Canary. Switch the
/// order to prefer the least stable channel in order to perform pre-release
/// testing. See `COREWEBVIEW2_RELEASE_CHANNELS` for descriptions of channels.
[v1_enum]
typedef enum COREWEBVIEW2_CHANNEL_SEARCH_KIND {
  /// Search for a release channel from most to least stable:
  /// WebView2 Runtime -> Beta -> Dev -> Canary. This is the default behavior.
  COREWEBVIEW2_CHANNEL_SEARCH_KIND_MOST_STABLE,
  /// Search for a release channel from least to most stable:
  /// Canary -> Dev -> Beta -> WebView2 Runtime.
  COREWEBVIEW2_CHANNEL_SEARCH_KIND_LEAST_STABLE,
} COREWEBVIEW2_CHANNEL_SEARCH_KIND;


/// The WebView2 release channels. Use `ReleaseChannels` and `ChannelSearchKind`
/// on `ICoreWebView2EnvironmentOptions` to control which channel is searched
/// for during environment creation.
///
/// |Channel|Primary purpose|How often updated with new features|
/// |:---:|---|:---:|
/// |Stable (WebView2 Runtime)|Broad Deployment|Monthly|
/// |Beta|Flighting with inner rings, automated testing|Monthly|
/// |Dev|Automated testing, selfhosting to test new APIs and features|Weekly|
/// |Canary|Automated testing, selfhosting to test new APIs and features|Daily|
[v1_enum]
typedef enum COREWEBVIEW2_RELEASE_CHANNELS {
  /// No release channel. Passing only this value to `ReleaseChannels` results
  /// in HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND).
  COREWEBVIEW2_RELEASE_CHANNELS_NONE = 0x0,
  /// The stable WebView2 Runtime that is released every 4 weeks.
  COREWEBVIEW2_RELEASE_CHANNELS_STABLE = 0x1,
  /// The Beta release channel that is released every 4 weeks, a week before the
  /// stable release.
  COREWEBVIEW2_RELEASE_CHANNELS_BETA = 0x2,
  /// The Dev release channel that is released weekly.
  COREWEBVIEW2_RELEASE_CHANNELS_DEV = 0x4,
  /// The Canary release channel that is released daily.
  COREWEBVIEW2_RELEASE_CHANNELS_CANARY = 0x8,
} COREWEBVIEW2_RELEASE_CHANNELS;
cpp_quote("DEFINE_ENUM_FLAG_OPERATORS(COREWEBVIEW2_RELEASE_CHANNELS)")

/// Additional options used to create the WebView2 Environment that support
/// specifying the `ReleaseChannels` and `ChannelSearchKind`.
[uuid(c48d539f-e39f-441c-ae68-1f66e570bdc5), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions7 : IUnknown {
  /// Gets the `ChannelSearchKind` property.
  [propget] HRESULT ChannelSearchKind([out, retval] COREWEBVIEW2_CHANNEL_SEARCH_KIND* value);

  /// The `ChannelSearchKind` property is `COREWEBVIEW2_CHANNEL_SEARCH_KIND_MOST_STABLE`
  /// by default; environment creation searches for a release channel on the machine
  /// from most to least stable using the first channel found. The default search order is:
  /// WebView2 Runtime -&gt; Beta -&gt; Dev -&gt; Canary. Set `ChannelSearchKind` to
  /// `COREWEBVIEW2_CHANNEL_SEARCH_KIND_LEAST_STABLE` to reverse the search order
  /// so that environment creation searches for a channel from least to most stable. If
  /// `ReleaseChannels` has been provided, the loader will only search
  /// for channels in the set. See `COREWEBVIEW2_RELEASE_CHANNELS` for more details
  /// on channels.
  ///
  /// This property can be overridden by the corresponding
  /// registry key `ChannelSearchKind` or the environment variable
  /// `WEBVIEW2_CHANNEL_SEARCH_KIND`. Set the value to `1` to set the search kind to
  /// `COREWEBVIEW2_CHANNEL_SEARCH_KIND_LEAST_STABLE`. See
  /// `CreateCoreWebView2EnvironmentWithOptions` for more details on overrides.
  [propput] HRESULT ChannelSearchKind([in] COREWEBVIEW2_CHANNEL_SEARCH_KIND value);

  /// Gets the `ReleaseChannels` property.
  [propget] HRESULT ReleaseChannels([out, retval] COREWEBVIEW2_RELEASE_CHANNELS* value);

  /// Sets the `ReleaseChannels`, which is a mask of one or more  indicating which channels environment creation should search for.
  /// OR operation(s) can be applied to multiple  to create a mask. The default value is a mask of all the channels. By default, environment creation searches for channels from most to least stable, using the first channel found on the device. When `ReleaseChannels` is provided, environment creation will only search for the channels specified in the set. Set `ChannelSearchKind` to `1` to reverse the search order so that the loader searches for the least stable build first. See `COREWEBVIEW2_RELEASE_CHANNELS` for descriptions of each channel. Environment creation fails if it is unable to find any channel from the `ReleaseChannels` installed on the device. Use `GetAvailableCoreWebView2BrowserVersionStringWithOptions` to verify which channel is used. If both a `ReleaseChannels` and `BrowserExecutableFolder` are provided, the `BrowserExecutableFolder` takes precedence. The `ReleaseChannels` property can be overridden by the corresponding registry override  or the environment variable . Set the value to a comma-separated string of integers, which map to the  values: Stable (0), Beta (1), Dev (2), and Canary (3). For example, the values "0,2" and "2,0" both indicate that the loader should only search for Dev channel and the WebView2 Runtime, using the order indicated by the `ChannelSearchKind`. Environment creation attempts to interpret each integer and treats any invalid entry as Stable channel.
  /// |   ReleaseChannels   |   Channel Search Kind: Most Stable (default)   |   Channel Search Kind: Least Stable   |
  /// | --- | --- | --- |
  /// |CoreWebView2ReleaseChannels.Beta \| CoreWebView2ReleaseChannels.Stable| WebView2 Runtime -> Beta | Beta -> WebView2 Runtime|
  /// |CoreWebView2ReleaseChannels.Canary \| CoreWebView2ReleaseChannels.Dev \| CoreWebView2ReleaseChannels.Beta \| CoreWebView2ReleaseChannels.Stable | WebView2 Runtime -> Beta -> Dev -> Canary | Canary -> Dev -> Beta -> WebView2 Runtime |
  /// |CoreWebView2ReleaseChannels.Canary| Canary | Canary |
  /// |CoreWebView2ReleaseChannels.Beta \| CoreWebView2ReleaseChannels.Canary \| CoreWebView2ReleaseChannels.Stable | WebView2 Runtime -> Beta -> Canary | Canary -> Beta -> WebView2 Runtime |
  [propput] HRESULT ReleaseChannels([in] COREWEBVIEW2_RELEASE_CHANNELS value);
}


/// This function will tell you the browser version info of the release channel
/// used when creating an environment with the same options. Browser version
/// info includes channel name if it is not the WebView2 Runtime. Channel names
/// are Beta, Dev, and Canary.  The format of the return string matches the format of
/// `BrowserVersionString` on `ICoreWebView2Environment`.
///
/// If an override exists for `browserExecutableFolder`, `releaseChannels`,
/// or `ChannelSearchKind`, the override is used. The presence of an override
/// can result in a different channel used than the one expected based on the
/// environment options object. `browserExecutableFolder` takes precedence over
/// the other options, regardless of whether or not its channel is included in
/// the `releaseChannels`. See `CreateCoreWebView2EnvironmentWithOptions`
/// for more details on overrides. If an override is not specified, then the
/// parameters passed to `GetAvailableCoreWebView2BrowserVersionStringWithOptions`
/// are used. Returns `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` if it fails to find
/// an installed WebView2 Runtime or non-stable Microsoft Edge installation. Use
/// `GetAvailableCoreWebView2BrowserVersionString` to get the version info without
/// the environment options.
///
/// The caller must free the returned string with `CoTaskMemFree`.  See
/// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).

cpp_quote("STDAPI GetAvailableCoreWebView2BrowserVersionStringWithOptions(PCWSTR browserExecutableFolder, ICoreWebView2EnvironmentOptions* environmentOptions, LPWSTR* versionInfo);")
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ChannelSearchKind
    {
        MostStable = 0,
        LeastStable = 1,
    };

    [flags]
    enum CoreWebView2ReleaseChannels
    {
        None = 0x00000000,
        Stable = 0x00000001,
        Beta = 0x00000002,
        Dev = 0x00000004,
        Canary = 0x00000008,
    };

    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions7")]
        {
            // ICoreWebView2EnvironmentOptions7 members
            CoreWebView2ChannelSearchKind ChannelSearchKind { get; set; };

            CoreWebView2ReleaseChannels ReleaseChannels { get; set; };
        }
 
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        [static_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentStatics2")]
        {
            [method_name("GetAvailableBrowserVersionStringWithOptions")]
            static String GetAvailableBrowserVersionString(
                String browserExecutableFolder,
                CoreWebView2EnvironmentOptions options);
        }
    }
}
```
