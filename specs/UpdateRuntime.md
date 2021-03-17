# Background
The new version of an app might require a newer version of Edge WebView2 Runtime.

An app updater may wish to ensure that a particular minimum version of the Edge WebView2 Runtime is installed before upgrading the app to a version that requires those features.

Alternatively, the newer version of the app could use feature detection to disable portions of the app that rely on new WebView2 Runtime features. In this alternate scenario, the app updater would install the new version of the app immediately, and then request that the Edge WebView2 Runtime be updated, so that the updated app can start taking advantage of the new features once the Edge WebView2 Runtime is updated.

Edge WebView2 Runtime is auto updated and normally the latest version should be already installed. However, there could be cases that we need trigger Edge WebView2 Runtime
update to ensure coordinated app and WebView2 Runtime update.

# Description
You may call the `UpdateRuntime` API to check and install updates for the installed Edge WebView2 Runtime. This is useful when the app wants to coordinate app and
Edge WebView2 Runtime update.

# Examples
## .NET, WinRT
```c#
using Microsoft.Web.WebView2.Core;
async protected bool EnsureWebView2RuntimeVersion(string minimalVersionRequired)
{
    string currentRuntimeVersion = CoreWebView2Environment.GetAvailableBrowserVersionString();
    if (CoreWebView2Environment.CompareBrowserVersions(currentRuntimeVersion, minimalVersionRequired) < 0)
    {
      auto environment = await CoreWebView2Environment.CreateAsync();
      auto updateResult = await environment.UpdateRuntimeAsync();
      if (updateResult.UpdateRuntimeStatus != CoreWebView2RuntimeUpdateStatus.LatestVersionInstalled)
        return false;
      // check runtime version again
      currentRuntimeVersion = CoreWebView2Environment.GetAvailableBrowserVersionString();
    }
    return (CoreWebView2Environment.CompareBrowserVersions(currentRuntimeVersion, minimalVersionRequired) >= 0);
}

// For the scenario where the app wants to light up features fast while running with the old version.
{
    // We could be running with a WebView2 Runtime version that has or doesn't have some features.
    // Therefore, check the version that we are running the WebView2 with, and skip the new feature if running old version.
    string currentRunningVersion = webView2Environment.NewBrowserVersionAvailable;
    if (CoreWebView2Environment.CompareBrowserVersions(currentRunningVersion, minimalVersionHasFeartures) >= 0) {
        // Light up the app features that make usage of APIs that only works in newer version.
    }

    ...
    // Listen to NewBrowserVersionAvailable event to switch to newer version when it is available.
    webView2Environment.NewBrowserVersionAvailable += delegate (object sender, object args)
    {
        // See the NewBrowserVersionAvailable documentation for more information
        // Close current WebView2 Control
        // Wait for it to completely shutdown
        // Recreate WebView2 Control to run with newer version
    };
    
    // Trigger Edge WebView2 Runtime update, ignore update result and rely on NewBrowserVersionAvailable to take action.
    _ = EnsureWebView2RuntimeVersion(desiredVersion);
}

```
## Win32 C++
```cpp
bool IsCurrentVersionSameOrNewer(std::wstring minimalVersionRequired)
{
    wil::unique_cotaskmem_string currentVersion;
    HRESULT hr = GetAvailableCoreWebView2BrowserVersionString(nullptr, &currentVersion);
    if (FAILED(hr) || (currentVersion == nullptr))
    {
      return false;
    }
    int versionComparisonResult;
    CompareBrowserVersions(currentVersion.get(), minimalVersionRequired.c_str(), &versionComparisonResult);
    return (versionComparisonResult >= 0)
}

void EnsureWebView2RuntimeVersion(std::function<void(bool)> const& callback, std::wstring minimalVersionRequired)
{
    if (IsCurrentVersionSameOrNewer(minimalVersionRequired))
    {
      callback(true);
      return;
    }
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [callback, minimalVersionRequired](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT {
                wil::com_ptr<ICoreWebView2Environment> webViewEnvironment = environment;
                auto experimentalEnvironment3 = webViewEnvironment.try_query<ICoreWebView2ExperimentalEnvironment3>();
                HRESULT hr = experimentalEnvironment3->UpdateRuntime(
                    Callback<ICoreWebView2ExperimentalUpdateRuntimeCompletedHandler>(
                        [callback, minimalVersionRequired, experimentalEnvironment3](HRESULT errorCode,
                           ICoreWebView2ExperimentalUpdateRuntimeResult* result) -> HRESULT {
                            COREWEBVIEW2_RUNTIME_UPDATE_STATUS updateStatus =
                                COREWEBVIEW2_RUNTIME_UPDATE_STATUS_FAILED;
                            if ((errorCode == S_OK) && result)
                            {
                              CHECK_FAILURE(result->get_UpdateRuntimeStatus(&updateStatus));
                            }
                            if (updateStatus != COREWEBVIEW2_UPDATE_RUNTIME_STATUS_LATEST_VERSION_INSTALLED)
                            {
                              callback(false);
                            }
                            else
                            {
                              callback(IsCurrentVersionSameOrNewer(minimalVersionRequired));
                            }
                            return S_OK;
                        })
                        .Get());
                return S_OK;
            })
            .Get());
}

```

# Remarks
See comments in [API Details](#api-details) section below.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
```IDL
/// Status of UpdateRuntime operation result.
[v1_enum] typedef enum COREWEBVIEW2_UPDATE_RUNTIME_STATUS {

  /// Latest version of Edge WebView2 Runtime is installed.
  /// No update for Edge WebView2 Runtime is available, or Edge WebView2
  /// Runtime is updated successfully and latest version is now installed.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_LATEST_VERSION_INSTALLED,

  /// Edge WebView2 Runtime update is already running, which could be
  /// triggered by auto update or by other UpdateRuntime request from some app.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_UPDATE_ALREADY_RUNNING,

  /// Edge WebView2 Runtime update is blocked by group policy.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_BLOCKED_BY_POLICY,

  /// Edge WebView2 Runtime update failed.
  /// See `ExtendedError` property of UpdateRuntimeResult for more
  /// information about the failure.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_FAILED,
} COREWEBVIEW2_UPDATE_RUNTIME_STATUS;

/// The UpdateRuntime operation result.
[uuid(DD503E49-AB19-47C0-B2AD-6DDD09CC3E3A), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalUpdateRuntimeResult : IUnknown {

  /// The status for the UpdateRuntime operation.
  [propget] HRESULT Status(
      [ out, retval ] COREWEBVIEW2_UPDATE_RUNTIME_STATUS * status);

  /// The update error happened while trying to update Edge WebView2 Runtime.
  /// ExtendedError will be S_OK if Status is not `COREWEBVIEW2_UPDATE_RUNTIME_STATUS_FAILED`
  /// or `COREWEBVIEW2_UPDATE_RUNTIME_STATUS_BLOCKED_BY_POLICY`.
  [propget] HRESULT ExtendedError([out, retval] HRESULT* error);
}

/// The caller implements this interface to receive the UpdateRuntime result.
[uuid(F1D2D722-3721-499C-87F5-4C405260697A), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalUpdateRuntimeCompletedHandler : IUnknown {

  /// Provides the result for the UpdateRuntime operation.
  /// `errorCode` will be S_OK if the update operation can be performed
  /// normally, regardless of whether we could update the Edge WebView2
  /// Runtime. If an unexpected error interrupts the update operation, error
  /// code of that unexpected error would be set as `errorCode`.
  /// When update operation can be performed normally, but update resulted in
  /// failure, like download failed, the error code would be presented as
  /// `ExtendedError` property of ICoreWebView2ExperimentalUpdateRuntimeResult.
  HRESULT Invoke([in] HRESULT errorCode,
                 [in] ICoreWebView2ExperimentalUpdateRuntimeResult * result);
}

/// This interface is an extension of the ICoreWebView2Environment. An object
/// implementing the ICoreWebView2ExperimentalEnvironment3 interface will also
/// implement ICoreWebView2Environment.
[uuid(9A2BE885-7F0B-4B26-B6DD-C969BAA00BF1), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalEnvironment3 : IUnknown {
  /// Try to update the installed Microsoft Edge WebView2 Runtime.
  /// This will potentially result in a new version of the Edge WebView2
  /// Runtime being installed and `NewBrowserVersionAvailable` event being raised.
  /// There is no guarantee on the order of that event being raised and
  /// UpdateRuntime's completed handler being invoked. Besides the
  /// `NewBrowserVersionAvailable` event, there will be no impact to any
  /// currently running WebView2s when the update is installed.
  /// Even though the Edge WebView2 Runtime update is installed for the machine
  /// and available to all users, the update will happen silently and not show
  /// elevation prompt.
  /// This will not impact Edge browser installation.
  /// The latest version can always be queried using the
  /// `GetAvailableCoreWebView2BrowserVersionString` API.
  /// The UpdateRuntime method is only supported for an installed Edge WebView2
  /// Runtime. When running a fixed version Edge WebView2 Runtime or non stable
  /// channel Edge browser, this API will return `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)`.
  /// There could only be one active UpdateRuntime operation in an app process,
  /// calling this API before completed handler for previous call is invoked will fail with
  /// `HRESULT_FROM_WIN32(ERROR_BUSY)`.
  /// Calling this API repeatedly in a short period of time, will also fail with
  /// `HRESULT_FROM_WIN32(ERROR_BUSY)`. To protect accidental abuse of the update
  /// service, the implementation throttles the calls of this API to 3 times within
  /// 5 minutes in a process. Throttling limit can change in the future.
  /// Edge update service can only support one update request at a time globally.
  /// If there is already an update operation running in the Edge update service,
  //  UpdateRuntime request will result in the completed handler being invoked with a
  /// result that has `Status` of `COREWEBVIEW2_UPDATE_RUNTIME_STATUS_UPDATE_ALREADY_RUNNING`.
  /// As the running update could succeed or fail, the app should retry later if
  /// `NewBrowserVersionAvailable` event has not been raised.
  /// The UpdateRuntime operation is associated with the CoreWebView2Environment
  /// object and any ongoing UpdateRuntime operation will be aborted when the
  /// associated CoreWebView2Environment along with the CoreWebView2 objects that
  /// are created by the CoreWebView2Environment object are all released. In this
  /// case, the completed handler will be invoked with `S_OK` as `errorCode` and a
  /// result object with `Status` of COREWEBVIEW2_UPDATE_RUNTIME_STATUS_FAILED and
  /// `ExtendedError` as `E_ABORT`.
  HRESULT UpdateRuntime(
      [in] ICoreWebView2ExperimentalUpdateRuntimeCompletedHandler *
      handler);
}

```
## WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2UpdateRuntimeStatus
    {
        LatestVersionInstalled = 0,
        UpdateAlreadyRunning = 1,
        BlockedByPolicy = 2,
        Failed = 3,
    }

    public partial class CoreWebView2UpdateRuntimeResult
    {
        public CoreWebView2UpdateRuntimeStatus Status
        {
            get;
        }
        public Windows.Foundation.HResult ExtendedError
        {
            get;
        }
    }

    public partial class CoreWebView2Environment
    {
        public async Task<CoreWebView2UpdateRuntimeResult> UpdateRuntimeAsync()
    }
}
```
## .NET
```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2UpdateRuntimeStatus
    {
        LatestVersionInstalled = 0,
        UpdateAlreadyRunning = 1,
        BlockedByPolicy = 2,
        Failed = 3,
    }

    public partial class CoreWebView2UpdateRuntimeResult
    {
        public CoreWebView2UpdateRuntimeStatus Status
        {
            get;
        }
        public int ExtendedError
        {
            get;
        }
    }

    public partial class CoreWebView2Environment
    {
        public async Task<CoreWebView2UpdateRuntimeResult> UpdateRuntimeAsync()
    }
}
```
