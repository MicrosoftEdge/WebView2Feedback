RuntimeChannelPreferenceSet.md
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

Currently you can test against prerelease channels by setting the `RuntimeChannelPreference` or
`BrowserExecutableFolder` overrides, described in [Test upcoming APIs and features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/set-preview-channel).
These overrides are useful for testing experimental APIs but are not designed to support more
complex automated testing and flighting scenarios.

To make it easier to implement prerelease testing, the WebView2 team is adding new environment
options for channel selection, `RuntimeChannelPreferenceSet` and `ShouldReverseChannelSearchOrder`.
These options can be used together to specify which channels the WebView2 loader should search for
in order of least to most stable: Canary -> Dev -> Beta -> Stable WebView2 Runtime.
For example, you can set `ShouldReverseChannelSearchOrder` to true and specify {Beta, Stable}
to tell the WebView2 loader to try running the app with Beta channel if it exists on the machine,
and otherwise fall back on the stable WebView2 Runtime. With the new options you can:
- Run automated tests against different channels on a machine with multiple channels installed
- Target a particular channel when flighting
- Apply different channels to different flighting rings
- Fall back on a more stable preview channel

# Examples
## RuntimeChannelPreferenceSet
The runtime channel preference set and channel search order are specified on the
CoreWebView2EnvironmentOptions prior to creating the WebView2 environment.
```c#
CoreWebView2Environment _webViewEnvironment;
async System.Threading.Tasks.Task CreateEnvironmentAsync() {
    CoreWebView2RuntimeChannel channels = (CoreWebView2RuntimeChannel)
        (CoreWebView2RuntimeChannel.Beta | CoreWebView2RuntimeChannel.Stable);
    CoreWebView2EnvironmentOptions customOptions = new CoreWebView2EnvironmentOptions
    {
        ShouldReverseChannelSearchOrder = true,
        RuntimeChannelPreferenceSet = channels
    };
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
    CHECK_FAILURE(options->put_ShouldReverseChannelSearchOrder(TRUE));
    COREWEBVIEW2_RUNTIME_CHANNEL channels =
        COREWEBVIEW2_RUNTIME_CHANNEL_BETA |
        COREWEBVIEW2_RUNTIME_CHANNEL_STABLE;
    CHECK_FAILURE(options->SetRuntimeChannelPreferenceSet(channels));
    // If the loader is unable to find a valid installation from the runtime
    // channel preference set, environment creation will fail with
    // HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND).
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        nullptr, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get());
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
/// The WebView2 Runtime channel. Use `RuntimeChannelPreferenceSet` and
/// `ShouldReverseChannelSearchOrder` on `ICoreWebView2EnvironmentOptions` to
/// control which channel the WebView2 loader searches for.
/// |Channel|Primary purpose|How often updated with new features|
/// |:---:|---|:---:|
/// |Stable (WebView2 Runtime)|Broad Deployment|~4 weeks|
/// |Beta|Flighting with inner rings, automated testing|~4 weeks|
/// |Dev|Automated testing, selfhosting to test new APIs and features|Weekly|
/// |Canary|Automated testing, selfhosting to test new APIs and features|Daily|
typedef enum COREWEBVIEW2_RUNTIME_CHANNEL {
  /// The stable WebView2 Runtime that is released every 4 weeks.
  COREWEBVIEW2_RUNTIME_CHANNEL_STABLE,
  /// The Beta Runtime channel that is released every 4 weeks, a week before the
  /// stable release.
  COREWEBVIEW2_RUNTIME_CHANNEL_BETA,
  /// The Dev Runtime channel that is released weekly.
  COREWEBVIEW2_RUNTIME_CHANNEL_DEV,
  /// The Canary Runtime channel that is released daily.
  COREWEBVIEW2_RUNTIME_CHANNEL_CANARY,
} COREWEBVIEW2_RUNTIME_CHANNEL;
cpp_quote("DEFINE_ENUM_FLAG_OPERATORS(COREWEBVIEW2_RUNTIME_CHANNEL)")

/// Additional options used to create the WebView2 Environment that support
/// specifying the `RuntimeChannelPreferenceSet`.
[uuid(47ac856e-a726-4e04-b36b-f58dafb39e38), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions6 : ICoreWebView2EnvironmentOptions5 {

  /// Gets the `RuntimeChannelPreferenceSet`.
  HRESULT GetRuntimeChannelPreferenceSet(
      [out] COREWEBVIEW2_RUNTIME_CHANNEL* channels);

  /// Sets the `RuntimeChannelPreferenceSet`, which is a mask of one or more
  /// `COREWEBVIEW2_RUNTIME_CHANNEL`s. OR operation(s) can be applied to multiple
  /// `COREWEBVIEW2_RUNTIME_CHANNEL`s to create a mask. The default value is a
  /// a mask of all the channels. By default, the WebView2 loader
  /// searches for channels from most to least stable, using the first channel
  /// found on the device. When a `RuntimeChannelPreferenceSet` is provided, the
  /// WebView2 loader will only search for the channels specified in the set.
  /// Set `ReverseChannelSearchOrder` to `TRUE` to reverse the search order so
  /// that the loader searches for least stable build first. See
  /// `COREWEBVIEW2_RUNTIME_CHANNEL` for descriptions of each channel.
  /// `CreateCoreWebView2EnvironmentWithOptions` fails with
  /// `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` if the loader is unable to find
  /// any channel from the `RuntimeChannelPreferenceSet` installed on the device.
  /// Use `BrowserVersionString` on `ICoreWebView2Environment` to verify which channel
  /// is used when this option is set.
  ///
  /// Examples:
  /// |   RuntimeChannelPreferenceSet   |   Default Channel Search Order   |   Reverse Channel Search Order   |
  /// | --- | --- | --- |
  /// |COREWEBVIEW2_RUNTIME_CHANNEL_BETA \| COREWEBVIEW2_RUNTIME_CHANNEL_STABLE| WebView2 Runtime -> Beta | Beta -> WebView2 Runtime|
  /// |COREWEBVIEW2_RUNTIME_CHANNEL_CANARY \| COREWEBVIEW2_RUNTIME_CHANNEL_DEV \| COREWEBVIEW2_RUNTIME_CHANNEL_BETA \| COREWEBVIEW2_RUNTIME_CHANNEL_STABLE| WebView2 Runtime -> Beta -> Dev -> Canary | Canary -> Dev -> Beta -> WebView2 Runtime |
  /// |COREWEBVIEW2_RUNTIME_CHANNEL_CANARY| Canary | Canary |
  /// |COREWEBVIEW2_RUNTIME_CHANNEL_BETA \| COREWEBVIEW2_RUNTIME_CHANNEL_CANARY \| COREWEBVIEW2_RUNTIME_CHANNEL_STABLE | WebView2 Runtime -> Beta -> Canary | Canary -> Beta -> WebView2 Runtime |
  ///
  /// If both a `BrowserExecutableFolder` and a `RuntimeChannelPreferenceSet` are
  /// provided, the `BrowserExecutableFolder` takes precedence. The
  /// `RuntimeChannelPreferenceSet` can be overridden by the corresponding
  /// registry override `WEBVIEW2_RUNTIME_CHANNEL_PREFERENCE_SET` or the
  /// environment variable `RuntimeChannelPreferenceSet`. Set the value to a
  /// comma-separated string of integers, which map to the
  /// COREWEBVIEW2_RUNTIME_CHANNEL values: Stable (0), Beta (1), Dev (2), and
  /// Canary (3). For example, the value "0,2" indicates that the loader should
  /// only search for Dev channel and the WebView2 Runtime, using the order
  /// indicated by `ShouldReverseChannelSearchOrder`. The loader attempts to
  /// interpret each integer and treats any invalid entry as Stable channel. See
  /// `CreateCoreWebView2EnvironmentWithOptions` for more details on overrides.
  /// Use `GetAvailableBrowserVersionString` to verify which channel is used when
  /// this override is set.
  HRESULT SetRuntimeChannelPreferenceSet(
      [in] COREWEBVIEW2_RUNTIME_CHANNEL channels);

  /// The `ShouldReverseChannelSearchOrder` property is `FALSE` by default and
  /// the WebView2 loader searches for a Runtime channel on the machine from
  /// most to least stable using the first channel found. The default search order is:
  /// WebView2 Runtime -> Beta -> Dev -> Canary. Set `ShouldReverseChannelSearchOrder`
  /// to `TRUE` to reverse the search order so that the loader searches for a channel
  /// from least to most stable. If a `RuntimeChannelPreferenceSet` has been provided, the
  /// loader will only search for channels in the set. See `COREWEBVIEW2_RUNTIME_CHANNEL`
  /// for more details on channels. This property can be overridden by the corresponding
  /// registry key `ReverseChannelSearchOrder` or the environment variable
  /// `WEBVIEW2_REVERSE_CHANNEL_SEARCH_ORDER`. Set the value to `1` to reverse the search
  /// order. See `CreateCoreWebView2EnvironmentWithOptions` for more details on
  /// overrides.
  [propget] HRESULT ShouldReverseChannelSearchOrder([out, retval] BOOL* value);

  /// Sets the `ShouldReverseChannelSearchOrder` property.
  [propput] HRESULT ShouldReverseChannelSearchOrder([in] BOOL value);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    // The WebView2 Runtime channel. Use `RuntimeChannelPreferenceSet` and
    // `ShouldReverseChannelSearchOrder` on `ICoreWebView2EnvironmentOptions` to
    // control which channel the WebView2 loader searches for.
    // |Channel|Primary purpose|How often updated with new features|
    // |:---:|---|:---:|
    // |Stable (WebView2 Runtime)|Broad Deployment|~4 weeks|
    // |Beta|Flighting with inner rings, automated testing|~4 weeks|
    // |Dev|Automated testing, selfhosting to test new APIs and features|Weekly|
    // |Canary|Automated testing, selfhosting to test new APIs and features|Daily|
    [Flags] enum CoreWebView2RuntimeChannel
    {
        // The stable WebView2 Runtime that is released every 4 weeks.
        Stable = 1,
        // The Beta Runtime channel that is released every 4 weeks, a week before the stable release.
        Beta = 2,
        // The Dev Runtime channel that is released weekly.
        Dev = 4,
        // The Canary Runtime channel that is released daily.
        Canary = 8,
    };

    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions6")]
        {
            // Sets the `RuntimeChannelPreferenceSet`, which is a mask of one or more
            // `CoreWebView2RuntimeChannel`s. OR operation(s) can be applied to multiple
            // `CoreWebView2RuntimeChannel`s to create a mask. . The default value is a
            // a mask of all the channels. By default, the WebView2 loader searches for
            // channels from most to least stable, using the first channel found on the
            // device. When a `RuntimeChannelPreferenceSet` is provided, the WebView2
            // loader will only search for the channels specified in the set.
            // Set `ReverseChannelSearchOrder` to `true` to reverse the search order so
            // that the loader searches for least stable build first. See
            // `CoreWebView2RuntimeChannel` for descriptions of each channel. Environment creation
            // fails if the loader is unable to find any channel from the
            // `RuntimeChannelPreferenceSet` installed on the device. Use
            // `CoreWebView2Environment.BrowserVersionString` to verify which channel
            // is used.
            //
            // Examples:
            // |   RuntimeChannelPreferenceSet   |   Default Channel Search Order   |   Reverse Channel Search Order   |
            // | --- | --- | --- |
            // |CoreWebView2RuntimeChannel.Beta \| CoreWebView2RuntimeChannel.Stable| WebView2 Runtime -> Beta | Beta -> WebView2 Runtime|
            // |CoreWebView2RuntimeChannel.Canary \| CoreWebView2RuntimeChannel.Dev \| CoreWebView2RuntimeChannel.Beta \| CoreWebView2RuntimeChannel.Stable | WebView2 Runtime -> Beta -> Dev -> Canary | Canary -> Dev -> Beta -> WebView2 Runtime |
            // |CoreWebView2RuntimeChannel.Canary| Canary | Canary |
            // |CoreWebView2RuntimeChannel.Beta \| CoreWebView2RuntimeChannel.Canary \| CoreWebView2RuntimeChannel.Stable | WebView2 Runtime -> Beta -> Canary | Canary -> Beta -> WebView2 Runtime |
            //
            // If both a `BrowserExecutableFolder` and a `RuntimeChannelPreferenceSet` are
            // provided, the `BrowserExecutableFolder` takes precedence. The
            // `RuntimeChannelPreferenceSet` can be overridden by the corresponding registry
            // override `RuntimeChannelPreferenceSet` or the environment variable
            // `WEBVIEW2_RUNTIME_CHANNEL_PREFERENCE_SET`. Set the value to a comma-separated string of
            // integers, which map to the `CoreWebView2RuntimeChannel` values:
            // Stable (0), Beta (1), Dev (2), and Canary (3). For example, the value "0,2"
            // indicates that the loader should only search for Dev channel and the WebView2
            // Runtime, using the order indicated by `ShouldReverseChannelSearchOrder`.
            // The loader attempts to interpret each integer and treats any invalid entry as
            // Stable channel. Use `CoreWebView2Environment.GetAvailableBrowserVersionString`
            // to verify which channel is used when this override is set.
            CoreWebView2RuntimeChannel RuntimeChannelPreferenceSet { get; set; };

            // The `ShouldReverseChannelSearchOrder` property is `false` by default and
            // the WebView2 loader searches for a Runtime channel on the machine from
            // most to least stable using the first channel found. The default search order is:
            // WebView2 Runtime -> Beta -> Dev -> Canary. Set `ShouldReverseChannelSearchOrder`
            // to `true` to reverse the search order so that the loader searches for a channel
            // from least to most stable. If a `RuntimeChannelPreferenceSet` has been provided, the
            // loader will only search for channels in the set. See `CoreWebView2RuntimeChannel`
            // for more details on channels. This property can be overridden by the corresponding
            // registry key `ReverseChannelSearchOrder` or the environment variable
            // `WEBVIEW2_REVERSE_CHANNEL_SEARCH_ORDER`. Set the value to `1` to reverse the search
            // order. See `CreateCoreWebView2EnvironmentWithOptions` for more details on
            // overrides.
            Boolean ShouldReverseChannelSearchOrder { get; set; };
        }
    }
}
```
