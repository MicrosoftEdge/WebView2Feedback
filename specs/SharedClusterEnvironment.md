Shared WebView2 Cluster Environment
===

# Background

Today an application creates a WebView2 by calling
[`CreateCoreWebView2EnvironmentWithOptions`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/webview2-idl#createcorewebview2environmentwithoptions)
and passing a `UserDataFolder` (UDF). Two hosts that pass the *same* UDF already
share a single browser process. But that sharing is implicit: it is keyed
entirely on the UDF path, the first launcher silently determines the environment
options for everyone else, and a second host has no way to learn what those options
are before it attaches. If the second host's options disagree with the existing set,
it only finds out after it has already attempted to create the environment, and the
failure surfaces as a generic create error.

We want a first-class, *explicit* way for a set of cooperating host applications to
opt into one shared WebView2 environment — a "cluster" — and to agree on the shared
options up front. Cooperating host applications are applications that trust one
another and agree on a shared cluster `Id` in advance; sharing is by convention, and
the WebView2 Runtime does not restrict which applications may join a cluster.

This spec proposes a symmetric create-or-join model and a companion read of a
cluster's options:

- Every host calls the same symmetric `CreateOrJoinCoreWebView2ClusterEnvironment` with
  its full desired options. The **first** host to establish a cluster with a given
  `Id` determines the cluster's options (first-creator-wins). A later host that passes
  matching options attaches to the running cluster; a host that passes different
  options gets a completion status of `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`.
- A separate `GetCoreWebView2ClusterEnvironmentOptions` reads the cluster's options
  for an `Id` without launching the shared browser process, so a host can read a
  cluster's current options before it creates.

Sharing intent is expressed by an `Id` (a stable rendezvous name that all
cooperating hosts agree on). The mapping from `Id` to on-disk user data folder is a
fixed function, so the same `Id` always resolves to the same folder.

# Conceptual pages (How To)

A **cluster environment** is a WebView2 environment that a group of cooperating
host applications deliberately share, identified by a well-known `Id` string that
those hosts agree on out of band. All hosts that establish a cluster with the same
`Id` run inside one shared browser process and one on-disk user data folder.

Unlike `CreateCoreWebView2EnvironmentWithOptions`, you do **not** pass a user data
folder. The runtime derives the folder from the cluster `Id` through a fixed
mapping, so every host that uses the same `Id` resolves to the same on-disk layout.
A cluster occupies its own user data folder namespace: it never joins or collides
with an environment created by `CreateCoreWebView2EnvironmentWithOptions`.

The **cluster options** are the `ICoreWebView2ClusterEnvironmentOptions` that the
first host to establish the cluster supplied. They apply to the whole shared browser
process and are shared by every host that attaches, so the first establishing
caller's set is authoritative for the lifetime of the cluster; there is no per-host
override. This type intentionally exposes only a subset of the environment options.

The recommended usage pattern is **"Get, then Create"**:

1. Call `GetCoreWebView2ClusterEnvironmentOptions(id)` to see what options, if any,
   the cluster already uses. This does not launch the shared browser process.
2. If a cluster already exists, reuse its options and attach to it. If none exists
   yet, provide your own options, which become the cluster's options.
3. Call `CreateOrJoinCoreWebView2ClusterEnvironment` with the chosen options. You either
   establish the cluster or attach to one with matching options.

`Get` is only a hint: it can race with another host that establishes a cluster with
different options the instant after you read. The live browser stays authoritative,
so `Create` still validates and reports a status of
`COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH` if you lost the race, at
which point you re-`Get` the now-authoritative options and retry, or fall back to a
private environment. A private environment is an ordinary environment created with
your own user data folder through `CreateCoreWebView2EnvironmentWithOptions`; it has
its own separate data and does not share with the cluster.

Profile isolation in a cluster is **anti-misuse, not a security boundary**. When
`PerHostProfileIsolation` is TRUE (the default), profile names are namespaced per
host application, so two different apps that happen to use the same profile name do
not accidentally end up sharing one profile. This is not a security boundary: it
does not encrypt or ACL profile data, and apps that deliberately use the same host
identity and profile name can still share a profile.

# Examples

## Win32 C++

The example shows the recommended "Get, then Create" flow: read the cluster's options
for a well-known cluster id, reuse them if the cluster already exists, otherwise
offer your own; then create (which either establishes the cluster or attaches to one
with matching options). On a mismatch, re-read the authoritative options and retry.

```cpp
// A stable rendezvous name that all cooperating hosts agree on.
constexpr PCWSTR kClusterId = L"Contoso.Shell.Default";

// Build the options this host would use if it is the first to establish the cluster.
wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> BuildClusterOptions()
{
    auto options = Microsoft::WRL::Make<CoreWebView2ClusterEnvironmentOptions>();
    CHECK_FAILURE(options->put_Id(kClusterId));
    CHECK_FAILURE(options->put_Language(L"en-US"));
    CHECK_FAILURE(options->put_AreBrowserExtensionsEnabled(FALSE));
    return options;
}

void AppWindow::CreateSharedEnvironment()
{
    // Step 1 - synchronously ask what options the cluster already uses. No browser spawn.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> existing;
    HRESULT hr = GetCoreWebView2ClusterEnvironmentOptions(kClusterId, &existing);

    // Step 2 - reuse the cluster's options if it already exists; offer my own if none
    // exists yet. If cluster environments are not supported in this host, go private.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> options;
    if (SUCCEEDED(hr))
    {
        options = existing;
    }
    else if (hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND))
    {
        options = BuildClusterOptions();
    }
    else if (hr == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED))
    {
        // Sandboxed or low-integrity process (for example a UWP app) that cannot
        // share or access the cluster's user data folder.
        UsePrivateEnvironment();
        return;
    }
    else
    {
        CHECK_FAILURE(hr);
        return;
    }

    // Step 3 - same symmetric create either way: establishes, or attaches to a
    // cluster with matching options.
    CreateSharedEnvironmentWithOptions(options.get());
}

void AppWindow::CreateSharedEnvironmentWithOptions(
    ICoreWebView2ClusterEnvironmentOptions* options)
{
    HRESULT hr = CreateOrJoinCoreWebView2ClusterEnvironment(
        options,
        Microsoft::WRL::Callback<ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler>(
            [this](HRESULT errorCode,
                   ICoreWebView2ClusterEnvironmentCreateResult* result) -> HRESULT
            {
                // A failing errorCode is an unexpected failure (for example the
                // runtime could not be found). Handle it as usual.
                CHECK_FAILURE(errorCode);

                COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS status;
                CHECK_FAILURE(result->get_Status(&status));
                switch (status)
                {
                case COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED:
                {
                    // Established the cluster, or attached to one with matching options.
                    wil::com_ptr<ICoreWebView2Environment> environment;
                    CHECK_FAILURE(result->get_Environment(&environment));
                    OnSharedEnvironmentReady(environment.get());
                    break;
                }

                case COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH:
                {
                    // A live cluster has different options than mine. Re-read the
                    // authoritative options and retry with them (or go private).
                    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> authoritative;
                    if (SUCCEEDED(GetCoreWebView2ClusterEnvironmentOptions(
                            kClusterId, &authoritative)) &&
                        AcceptableForMe(authoritative.get()))
                    {
                        CreateSharedEnvironmentWithOptions(authoritative.get());
                    }
                    else
                    {
                        UsePrivateEnvironment();
                    }
                    break;
                }
                }
                return S_OK;
            })
            .Get());

    if (hr == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED))
    {
        // This host cannot share or access the cluster's user data folder (for
        // example a sandboxed or low-integrity process such as a UWP app). Cluster
        // environments are unavailable here; use a private environment instead.
        UsePrivateEnvironment();
        return;
    }
    CHECK_FAILURE(hr);
}
```

## .NET/WinRT

```c#
// A stable rendezvous name that all cooperating hosts agree on.
const string ClusterId = "Contoso.Shell.Default";

CoreWebView2ClusterEnvironmentOptions BuildClusterOptions()
{
    return new CoreWebView2ClusterEnvironmentOptions()
    {
        Id = ClusterId,
        Language = "en-US",
        AreBrowserExtensionsEnabled = false,
    };
}

async Task CreateSharedEnvironmentAsync()
{
    try
    {
        // Step 1 - synchronously read the cluster's options for this id. No browser
        // spawn. Returns null when no cluster exists yet.
        CoreWebView2ClusterEnvironmentOptions existing =
            CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);

        // Step 2 - reuse the cluster's options, or offer my own if none exists yet.
        CoreWebView2ClusterEnvironmentOptions options = existing ?? BuildClusterOptions();

        // Step 3 - same symmetric create either way. A failing create (for example
        // the runtime could not be found, or cluster environments are not supported
        // in this host) throws an exception; the expected outcomes come back as Status.
        CoreWebView2ClusterEnvironmentCreateResult result =
            await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(options);

        if (result.Status == CoreWebView2ClusterEnvironmentStatus.OptionsMismatch)
        {
            // A live cluster has different options than ours. Re-read the
            // authoritative options and retry with them.
            CoreWebView2ClusterEnvironmentOptions authoritative =
                CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);
            if (authoritative != null && AcceptableForMe(authoritative))
            {
                result =
                    await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(authoritative);
            }
        }

        if (result.Status == CoreWebView2ClusterEnvironmentStatus.Succeeded)
        {
            // Established the cluster, or attached to one with matching options.
            OnSharedEnvironmentReady(result.Environment);
        }
        else
        {
            // Still mismatched after retrying; fall back to a private environment.
            UsePrivateEnvironment();
        }
    }
    // HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED). This host cannot share or access the
    // cluster's user data folder (for example a sandboxed or low-integrity process
    // such as a UWP app); use a private environment instead.
    catch (COMException ex) when (ex.HResult == unchecked((int)0x80070032))
    {
        UsePrivateEnvironment();
    }
}
```

# API Details

## Win32 C++

```
/// The outcome of `CreateOrJoinCoreWebView2ClusterEnvironment`, reported to the
/// completion handler when its `errorCode` is `S_OK`.
[v1_enum] typedef enum COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS {
  /// The shared cluster environment is ready, either freshly established or attached
  /// to an existing cluster with matching options.
  COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED,
  /// A cluster already exists for this `Id` with different options. No environment is
  /// provided; read the cluster's options with
  /// `GetCoreWebView2ClusterEnvironmentOptions` and retry, or use a private
  /// (non-shared) environment.
  COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH,
} COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS;

/// Establishes, or attaches to, the shared WebView2 cluster environment identified
/// by the `Id` in `options`. If no cluster exists for the `Id`, this establishes
/// one and the caller's options become the cluster's options. If a cluster already
/// exists and the caller's options match it, the caller attaches to it. The outcome
/// is reported to the completion handler as a `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS`.
///
/// The synchronous return value reports whether the asynchronous operation could be
/// started:
///   S_OK                                    -> operation started; the completion
///                                              handler will be invoked with the result.
///   E_INVALIDARG                            -> `options` or its `Id` is invalid.
///   HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) -> the host cannot share or access the
///                                              cluster's user data folder (for
///                                              example a sandboxed or low-integrity
///                                              process such as a UWP app); the
///                                              completion handler is not invoked.
/// When the return value is a failing `HRESULT`, the completion handler is not
/// invoked.
STDAPI CreateOrJoinCoreWebView2ClusterEnvironment(
    [in] ICoreWebView2ClusterEnvironmentOptions* options,
    [in] ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler* handler);

/// Synchronously reads the options of the cluster identified by `id` without
/// creating or attaching to a cluster. Returns `S_OK` and the cluster's options
/// when a cluster exists for `id`, or `HRESULT_FROM_WIN32(ERROR_NOT_FOUND)`
/// and `nullptr` `options` when no cluster exists for `id`. The options are available
/// whether or not the cluster is currently running.
///
/// Returns `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)` and `nullptr` `options` in hosts
/// that cannot share or access the cluster's user data folder, for example a
/// sandboxed or low-integrity process such as a UWP app.
STDAPI GetCoreWebView2ClusterEnvironmentOptions(
    [in] LPCWSTR id,
    [out] ICoreWebView2ClusterEnvironmentOptions** options);

/// The options used to establish or attach to a shared cluster environment.
interface ICoreWebView2ClusterEnvironmentOptions : IUnknown {
  /// The name that identifies the cluster. All cooperating hosts use the same
  /// value. Use a stable, descriptive name your applications agree on (for example
  /// `"Contoso.Shell.Default"`); it does not need to be a GUID. Must not be `nullptr`
  /// or empty. The `Id` is case-insensitive and must be a valid file-system folder
  /// name; otherwise the call fails with `E_INVALIDARG`.
  [propget] HRESULT Id([out, retval] LPWSTR* id);
  /// Sets the `Id` property.
  [propput] HRESULT Id([in] LPCWSTR id);

  /// Additional command-line switches passed to the shared browser process.
  [propget] HRESULT AdditionalBrowserArguments([out, retval] LPWSTR* value);
  /// Sets the `AdditionalBrowserArguments` property.
  [propput] HRESULT AdditionalBrowserArguments([in] LPCWSTR value);

  /// The default display language for the shared environment.
  [propget] HRESULT Language([out, retval] LPWSTR* value);
  /// Sets the `Language` property.
  [propput] HRESULT Language([in] LPCWSTR value);

  /// Whether single sign-on using the OS primary account is allowed.
  [propget] HRESULT AllowSingleSignOnUsingOSPrimaryAccount([out, retval] BOOL* value);
  /// Sets the `AllowSingleSignOnUsingOSPrimaryAccount` property.
  [propput] HRESULT AllowSingleSignOnUsingOSPrimaryAccount([in] BOOL value);

  /// Whether tracking prevention is enabled for the shared environment.
  [propget] HRESULT EnableTrackingPrevention([out, retval] BOOL* value);
  /// Sets the `EnableTrackingPrevention` property.
  [propput] HRESULT EnableTrackingPrevention([in] BOOL value);

  /// Whether browser extensions are enabled for the shared environment.
  [propget] HRESULT AreBrowserExtensionsEnabled([out, retval] BOOL* value);
  /// Sets the `AreBrowserExtensionsEnabled` property.
  [propput] HRESULT AreBrowserExtensionsEnabled([in] BOOL value);

  /// When TRUE (the default), profile names are isolated per host application to
  /// prevent accidental cross-app profile use. This is not a security boundary.
  [propget] HRESULT PerHostProfileIsolation([out, retval] BOOL* value);
  /// Sets the `PerHostProfileIsolation` property.
  [propput] HRESULT PerHostProfileIsolation([in] BOOL value);

  /// Gets the custom scheme registrations for the shared environment. The caller
  /// must free the returned array and release each element with
  /// `CoTaskMemFree` / `Release`.
  HRESULT GetCustomSchemeRegistrations(
      [out] UINT32* count,
      [out] ICoreWebView2CustomSchemeRegistration*** schemeRegistrations);
  /// Sets the custom scheme registrations for the shared environment.
  HRESULT SetCustomSchemeRegistrations(
      [in] UINT32 count,
      [in] const ICoreWebView2CustomSchemeRegistration** schemeRegistrations);
}

/// The result of `CreateOrJoinCoreWebView2ClusterEnvironment`, provided to the
/// completion handler when its `errorCode` is `S_OK`.
interface ICoreWebView2ClusterEnvironmentCreateResult : IUnknown {
  /// The outcome of the create-or-join operation.
  [propget] HRESULT Status(
      [out, retval] COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS* value);

  /// The shared cluster environment. This is non-null only when `Status` is
  /// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED`; otherwise it is `nullptr`.
  [propget] HRESULT Environment([out, retval] ICoreWebView2Environment** value);
}

/// Receives the result of `CreateOrJoinCoreWebView2ClusterEnvironment`.
interface ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler : IUnknown {
  /// When `errorCode` is `S_OK`, `result` describes the outcome via its `Status`:
  ///  * `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED` - `result.Environment`
  ///    is the shared cluster environment.
  ///  * `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH` - a cluster
  ///    already exists for this `Id` with different options; `result.Environment`
  ///    is `nullptr`.
  ///
  /// When `errorCode` is a failing `HRESULT`, the operation failed for another reason
  /// (for example, the WebView2 Runtime could not be found) and `result` is `nullptr`.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2ClusterEnvironmentCreateResult* result);
}
```

## .NET/WinRT

The two global functions are surfaced as static methods on `CoreWebView2Environment`,
mirroring how `CreateCoreWebView2EnvironmentWithOptions` maps to
`CoreWebView2Environment.CreateAsync`. `CreateOrJoinClusterEnvironmentAsync` returns a
`CoreWebView2ClusterEnvironmentCreateResult` carrying the `Status` and, on success,
the `Environment`. When the operation cannot be started or fails, it throws; in
particular a host that cannot share or access the cluster's user data folder (for
example a sandboxed or low-integrity process such as a UWP app) throws a
`COMException` whose `HResult` is `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)`.
`GetClusterEnvironmentOptions` returns `null` when no cluster exists for the id,
matching the `ERROR_NOT_FOUND` case of the COM API.

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ClusterEnvironmentStatus
    {
        Succeeded = 0,
        OptionsMismatch = 1,
    };

    runtimeclass CoreWebView2ClusterEnvironmentCreateResult
    {
        CoreWebView2ClusterEnvironmentStatus Status { get; };
        // Non-null only when Status is Succeeded.
        CoreWebView2Environment Environment { get; };
    }

    runtimeclass CoreWebView2ClusterEnvironmentOptions
    {
        CoreWebView2ClusterEnvironmentOptions();

        String Id { get; set; };
        String AdditionalBrowserArguments { get; set; };
        String Language { get; set; };
        Boolean AllowSingleSignOnUsingOSPrimaryAccount { get; set; };
        Boolean EnableTrackingPrevention { get; set; };
        Boolean AreBrowserExtensionsEnabled { get; set; };
        Boolean PerHostProfileIsolation { get; set; };
        IVector<CoreWebView2CustomSchemeRegistration> CustomSchemeRegistrations { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        // Establishes, or attaches to, the shared cluster identified by options.Id.
        // The result's Status reports the outcome (Succeeded or OptionsMismatch);
        // Environment is non-null only when Status is Succeeded. Throws when the
        // operation cannot be started or fails, including
        // HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) when the host cannot share or
        // access the cluster's user data folder (for example a sandboxed or
        // low-integrity process such as a UWP app).
        static Windows.Foundation.IAsyncOperation<CoreWebView2ClusterEnvironmentCreateResult>
            CreateOrJoinClusterEnvironmentAsync(CoreWebView2ClusterEnvironmentOptions options);

        // Synchronously reads the options of the cluster identified by id. Returns
        // null when no cluster exists for id. Throws a COMException whose
        // HResult is HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) when the host cannot
        // share or access the cluster's user data folder.
        static CoreWebView2ClusterEnvironmentOptions GetClusterEnvironmentOptions(
            String id);
    }
}
```

# Appendix

## Relationship to existing options

`ICoreWebView2ClusterEnvironmentOptions` is a new type rather than a reuse of
`ICoreWebView2EnvironmentOptions`. Every option on it applies to the whole shared
browser process, supplied by the first host to establish the cluster and shared by
every host that attaches; there is no per-host override. The type intentionally
exposes only a subset of the environment options.