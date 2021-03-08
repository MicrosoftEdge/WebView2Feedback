# Background
The new version of an app might requires a newer version of Edge WebView2 Runtime. The app updater might want to ensure that the newer version of Edge WebView2 Runtime
is installed before updating the app to the newer version. The app could also update to newer version with some feature disabled, and then request update so that it
could move to newer version of Edge WebView2 Runtime and enable those features faster.
Edge WebView2 Runtime is auto updated and normally the latest version should be already installed. However, there could be cases that we need trigger Edge WebView2 Runtime
update to ensure coordinated app and runtime update.

# Description
You may call the `TryUpdateRuntime` API to check and install updates to installed Edge WebView2 Runtime. This is useful when the app wants to coordinate app and
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
      auto updateResult = await environment.TryUpdateRuntimeAsync();
      if (updateResult.UpdateRuntimeStatus != CoreWebView2RuntimeUpdateStatus.Updated)
        return false;
    }
    // check runtime version again
    currentRuntimeVersion = CoreWebView2Environment.GetAvailableBrowserVersionString();
    return (CoreWebView2Environment.CompareBrowserVersions(currentRuntimeVersion, minimalVersionRequired) >= 0);
}

// For the scenario where the app wants to light up features fast while running with the old version.
{
    ...
    // Listen to NewBrowserVersionAvailable to take action.
    webView2Environment.NewBrowserVersionAvailable += delegate (object sender, object args)
    {
        // See the NewBrowserVersionAvailable documentation for more information
        // Close current WebView2 Control
        // Wait for it to completely shutdown
        // Recreate WebView2 Control to run with newer version
    };
    
    // Trigger Edge WebView2 Runtime update, ignore update result and rely on NewBrowserVersionAvailable to take action.
    EnsureWebView2RuntimeVersion(desiredVersion);
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
                auto experimentalEnvironment3 =
                webViewEnvironment.try_query<ICoreWebView2ExperimentalEnvironment3>();
                HRESULT hr = experimentalEnvironment3->TryUpdateRuntime(
                    Callback<ICoreWebView2ExperimentalTryUpdateRuntimeCompletedHandler>(
                        [callback, minimalVersionRequired, experimentalEnvironment3](HRESULT errorCode,
                           ICoreWebView2ExperimentalUpdateRuntimeResult* result) -> HRESULT {
                            COREWEBVIEW2_RUNTIME_UPDATE_STATUS updateStatus =
                                COREWEBVIEW2_RUNTIME_UPDATE_STATUS_FAILED;
                            if ((errorCode == S_OK) && result)
                            {
                              CHECK_FAILURE(result->get_UpdateRuntimeStatus(&updateStatus));
                            }
                            if (updateStatus != COREWEBVIEW2_RUNTIME_UPDATE_STATUS_UPDATED)
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
/// Status of TryUpdateRuntime operation result.
[v1_enum] typedef enum COREWEBVIEW2_UPDATE_RUNTIME_STATUS {

  /// No update for Edge WebView2 Runtime is available.
  /// Latest version of Edge WebView2 Runtime is already installed.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_NO_UPDATE,

  /// Edge WebView2 Runtime is updated successfully.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_UPDATED,

  /// Edge WebView2 Runtime update is blocked by group policy.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_BLOCKED_BY_POLICY,

  /// Edge WebView2 Runtime update failed.
  /// See `UpdateError` property of UpdateRuntimeResult for more
  /// information about the failure.
  COREWEBVIEW2_UPDATE_RUNTIME_STATUS_FAILED,
} COREWEBVIEW2_UPDATE_RUNTIME_STATUS;


/// The TryUpdateRuntime operation result.
[uuid(DD503E49-AB19-47C0-B2AD-6DDD09CC3E3A), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalUpdateRuntimeResult : IUnknown {

  /// The status for the TryUpdateRuntime operation.
  [propget] HRESULT Status(
      [ out, retval ] COREWEBVIEW2_UPDATE_RUNTIME_STATUS * status);

  /// The update error happened while trying to update Edge WebView2 Runtime.
  [propget] HRESULT UpdateError([out, retval] HRESULT* updateError);
}

/// The caller implements this interface to receive the TryUpdateRuntime result.
[uuid(F1D2D722-3721-499C-87F5-4C405260697A), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalTryUpdateRuntimeCompletedHandler : IUnknown {

  /// Provides the result for the TryUpdateRuntime operation.
  /// `errorCode` will be S_OK if the update operation can be performed
  /// normally, regardless of whether we could update the Edge WebView2
  /// Runtime. If an unexpected error interrupts the update operation, error
  /// code of that unexpected error would be set as `errorCode`.
  /// When update operation can be performed normally, but update resulted in
  /// failure, like download failed, the error code would be presented as
  /// `UpdateError` property of ICoreWebView2ExperimentalUpdateRuntimeResult.
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
  /// Runtime being installed and `NewBrowserVersionAvailable` event being fired.
  /// There is no guarantee on the order of that event being fired and
  /// TryUpdateRuntimeis completed handler being invoked. Besides the
  /// `NewBrowserVersionAvailable` event, there will be no impact to any
  /// currently running WebViews when update is installed.
  /// The latest version can always be queried using
  /// `GetAvailableCoreWebView2BrowserVersionString` API.
  /// The TryUpdateRuntime method is only supported for an installed Edge WebView2
  /// Runtime. When running a fixed version Edge WebView2 Runtime or non stable
  /// channel Edge browser, this API will return `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)`.
  /// There could only be one active TryUpdateRuntime operation, calling this API
  /// before completed handler for previous call is invoked will fail with
  /// `HRESULT_FROM_WIN32(ERROR_BUSY)`.
  /// Calling this API repeatedly in a short period of time, will also fail with
  /// `HRESULT_FROM_WIN32(ERROR_BUSY)`. Don't call the API more than 3 times
  /// within 5 minutes.
  /// The TryUpdateRuntime operation is associated with the CoreWebView2Environment
  /// object and any ongoing TryUpdateRuntime operation will be aborted when the
  /// associated CoreWebView2Environment along with the CoreWebView2 objects that
  /// are created by the CoreWebView2Environment object are all released. In this
  /// case, the completed handler will be invoked with `S_OK` as `errorCode` and a
  /// result object with `Status` of COREWEBVIEW2_UPDATE_RUNTIME_STATUS_FAILED and
  /// `UpdateError` as `E_ABORT`.
  ///
  /// \snippet AppWindow.cpp UpdateRuntime
  HRESULT TryUpdateRuntime(
      [in] ICoreWebView2ExperimentalTryUpdateRuntimeCompletedHandler *
      handler);
}
```
## .NET WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2UpdateRuntimeStatus
    {
        NoUpdate = 0,
        Updated = 1,
        BlockedByPolicy = 2,
        Failed = 3,
    }

    public partial class CoreWebView2UpdateRuntimeResult
    {
        public CoreWebView2UpdateRuntimeStatus Status
        {
            get;
        }
        public int UpdateError
        {
            get;
        }
    }

    public partial class CoreWebView2Environment
    {
        public async Task<CoreWebView2UpdateRuntimeResult> TryUpdateRuntimeAsync()
    }
}
```
