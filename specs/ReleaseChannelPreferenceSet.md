ReleaseChannelPreferenceSet.md
===

# Background
The [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) is based on
the evergreen Chromium platform that receives monthly major updates. You should ensure that your
app works well with incoming browser changes by testing regularly against the WebView2 prerelease
builds, which ship along with the [Edge preview channels](https://www.microsoft.com/en-us/edge/download/insider?form=MA13FJ):
Canary (daily), Dev (weekly), and Beta (every 4 weeks). Prerelease testing can help you catch
issues before they reach the stable WebView2 Runtime and affect end users.

Currently you can test against prerelease channels by setting the `ReleaseChannelPreference` or
`BrowserExecutableFolder` overrides, described in [Test upcoming APIs and features](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/set-preview-channel).
These overrides are useful for testing experimental APIs but are not designed to support more
complex automated testing and flighting scenarios.

To make it easier to implement prerelease testing, the WebView2 team is adding a new API for
channel selection, `ReleaseChannelPreferenceSet`. This API allows you to specify the channels
that the WebView2 loader should search for in order of least to most stable:
Canary -> Dev -> Beta -> Stable WebView2 Runtime. For example, you can specify {Beta, Stable}
to tell the WebView2 loader to try running the app with Beta channel if it exists on the machine,
and otherwise fall back on the stable WebView2 Runtime. With `ReleaseChannelPreferenceSet` you can:
- Run automated tests against different channels on a machine with multiple channels installed
- Target a particular channel when flighting
- Apply different channels to different flighting rings
- Fall back on a more stable preview channel

# Examples
## ReleaseChannelPreferenceSet
The release channel preference set is specified on the CoreWebView2EnvironmentOptions prior to
creating the WebView2 environment.
```c#
CoreWebView2Environment _webViewEnvironment;
async System.Threading.Tasks.Task CreateEnvironmentAsync() {
    List<CoreWebView2ReleaseChannel> channels = new List<CoreWebView2ReleaseChannel>
    {
        CoreWebView2ReleaseChannel.Beta
        CoreWebView2ReleaseChannel.Stable,
    };
    CoreWebView2EnvironmentOptions customOptions = new CoreWebView2EnvironmentOptions
    {
        ReleaseChannelPreferenceSet = channels
    };
    // If the loader is unable to find a valid installation from the release
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
    std::vector<COREWEBVIEW2_RELEASE_CHANNEL> channels =
    {
        COREWEBVIEW2_RELEASE_CHANNEL_BETA,
        COREWEBVIEW2_RELEASE_CHANNEL_STABLE
    };
    CHECK_FAILURE(options->SetReleaseChannelPreferenceSet(
        channels.size(), channels.data()));
    // If the loader is unable to find a valid installation from the release
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
typedef enum COREWEBVIEW2_RELEASE_CHANNEL {
  /// The stable WebView2 Runtime that is released every 4 weeks.
  COREWEBVIEW2_RELEASE_CHANNEL_STABLE,
  /// The Beta release channel that is released every 4 weeks, a week before the
  /// stable release.
  COREWEBVIEW2_RELEASE_CHANNEL_BETA,
  /// The Dev release channel that is released weekly.
  COREWEBVIEW2_RELEASE_CHANNEL_DEV,
  /// The Canary release channel that is released daily.
  COREWEBVIEW2_RELEASE_CHANNEL_CANARY,
} COREWEBVIEW2_RELEASE_CHANNEL;

/// Additional options used to create the WebView2 Environment that support
/// specifying the `ReleaseChannelPreferenceSet`.
[uuid(47ac856e-a726-4e04-b36b-f58dafb39e38), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions6 : ICoreWebView2EnvironmentOptions5 {

  /// Gets the `ReleaseChannelPreferenceSet`. The memory pointed to by *channels
  /// is owned by the `ICoreWebView2EnvironmentOptions` object and there
  /// is no need to release it. The memory also cannot be used after the
  /// `ICoreWebView2EnvironmentOptions` object is released.
  HRESULT GetReleaseChannelPreferenceSet(
      [out] UINT32* count,
      [out] COREWEBVIEW2_RELEASE_CHANNEL** channels);

  /// Sets the `ReleaseChannelPreferenceSet`. By default, the WebView2 loader
  /// searches for channels from most to least stable, using the first channel
  /// found on the device. When a `ReleaseChannelPreferenceSet` is provided, the
  /// channel search order is reversed and the loader searches for the provided
  /// channels from least to most stable in the following order:
  /// Canary -> Dev -> Beta -> WebView2 Runtime.
  /// See `COREWEBVIEW2_RELEASE_CHANNEL` for descriptions of each channel.
  /// `CreateCoreWebView2EnvironmentWithOptions` fails with
  /// `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` if the loader is unable to find
  /// any channel from the `ReleaseChannelPreferenceSet` installed on the device.
  /// Use `BrowserVersionString` on `ICoreWebView2Environment` to verify which
  /// channel is used.
  ///
  /// Examples:
  /// |   ReleaseChannelPreferenceSet   |   Channel Search Order   |
  /// | --- | --- |
  /// |{COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_STABLE}| Beta -> WebView2 Runtime|
  /// |{COREWEBVIEW2_RELEASE_CHANNEL_CANARY, COREWEBVIEW2_RELEASE_CHANNEL_DEV, COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_STABLE}| Canary -> Dev -> Beta -> WebView2 Runtime |
  /// |{COREWEBVIEW2_RELEASE_CHANNEL_CANARY}| Canary |
  /// |{COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_CANARY, COREWEBVIEW2_RELEASE_CHANNEL_STABLE} | Canary -> Beta -> WebView2 Runtime |
  ///
  /// If both a `BrowserExecutableFolder` and a `ReleaseChannelPreferenceSet` are
  /// provided, the `BrowserExecutableFolder` takes precedence. The
  /// `ReleaseChannelPreferenceSet` can be overridden by the corresponding
  /// registry override `WEBVIEW2_RELEASE_CHANNEL_PREFERENCE_SET` or the
  /// environment variable `ReleaseChannelPreferenceSet`. Set the value to a
  /// comma-separated string of integers, which map to the
  /// COREWEBVIEW2_RELEASE_CHANNEL values: Stable (0), Beta (1), Dev (2), and
  /// Canary (3). For example, the value "0,2" indicates that the loader should
  /// search for Dev channel with fallback to the WebView2 Runtime. The loader
  /// attempts to interpret each integer and treats any invalid entry as
  /// Stable channel. Use `GetAvailableCoreWebView2BrowserVersionString` to verify
  /// which channel is used when this override is set. See
  /// `CreateCoreWebView2EnvironmentWithOptions` for more details on overrides.
  HRESULT SetReleaseChannelPreferenceSet(
      [in] UINT32 count,
      [in] COREWEBVIEW2_RELEASE_CHANNEL* channels);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ReleaseChannel
    {
        // The stable WebView2 Runtime that is released every 4 weeks.
        Stable = 0,
        // The Beta release channel that is released every 4 weeks, a week before the stable release.
        Beta = 1,
        // The Dev release channel that is released weekly.
        Dev = 2,
        // The Canary release channel that is released daily.
        Canary = 3,
    };

    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions6")]
        {
            // List of release channels that the WebView2 loader searches for. By default, the
            // WebView2 loader searches for channels from most to least stable, using the first
            // channel found on the device. When a `ReleaseChannelPreferenceSet` is provided,
            // the channel search order is reversed and the loader searches for the provided
            // channels from least to most stable in the following order:
            // Canary -> Dev -> Beta -> WebView2 Runtime. See `CoreWebView2ReleaseChannel` for
            // descriptions of each channel. Environment creation fails if the loader is unable
            // to find any channel from the `ReleaseChannelPreferenceSet` installed on the
            // device. Use `CoreWebView2Environment.BrowserVersionString` to verify which channel
            // is used.
            //
            // |   ReleaseChannelPreferenceSet   |   Channel Search Order   |
            // | --- | --- |
            // |{COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_STABLE}| Beta -> WebView2 Runtime|
            // |{COREWEBVIEW2_RELEASE_CHANNEL_CANARY, COREWEBVIEW2_RELEASE_CHANNEL_DEV, COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_STABLE}| Canary -> Dev -> Beta -> WebView2 Runtime |
            // |{COREWEBVIEW2_RELEASE_CHANNEL_CANARY}| Canary |
            // |{COREWEBVIEW2_RELEASE_CHANNEL_BETA, COREWEBVIEW2_RELEASE_CHANNEL_CANARY, COREWEBVIEW2_RELEASE_CHANNEL_STABLE} | Canary -> Beta -> WebView2 Runtime |
            //
            // If both a `BrowserExecutableFolder` and a `ReleaseChannelPreferenceSet` are
            // provided, the `BrowserExecutableFolder` takes precedence. The
            // `ReleaseChannelPreferenceSet` can be overridden by the corresponding registry
            // override `WEBVIEW2_RELEASE_CHANNEL_PREFERENCE_SET` or the environment variable
            // `ReleaseChannelPreferenceSet`. Set the value to a comma-separated string of
            // integers, which map to the `CoreWebView2ReleaseChannel` values:
            // Stable (0), Beta (1), Dev (2), and Canary (3). For example, the value "0,2"
            // indicates that the loader should search for Dev channel with fallback to the
            // WebView2 Runtime. The loader attempts to interpret each integer and treats any
            // invalid entry as Stable channel.  Use
            // `CoreWebView2Environment.GetAvailableBrowserVersionString` to verify which channel
            // is used when this override is set.
            IVector<CoreWebView2ReleaseChannel> ReleaseChannelPreferenceSet { get; set; };
        }
    }
}
```
