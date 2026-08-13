Shared WebView2 Cluster Environment
===

# Background

Today an application creates a WebView2 by calling
[`CreateCoreWebView2EnvironmentWithOptions`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/webview2-idl#createcorewebview2environmentwithoptions)
and passing a `userDataFolder` (UDF). Two hosts that pass the *same* UDF already
share a single browser process. But that sharing is implicit: it is keyed
entirely on the UDF path, the first host silently determines the environment
options for all later hosts, and a second host has no way to learn what those options
are before the second host attaches to the shared browser process. If the second
host's options disagree with the existing set,
it only finds out after it has already attempted to create the environment, and the
failure surfaces as a generic create error.

We want a first-class, *explicit* way for a set of cooperating host applications to
opt into one shared WebView2 environment—a "cluster"—and to agree on the shared
options up front. Cooperating host applications trust one
another and agree on a shared `ClusterName` in advance; sharing is by convention, and
the WebView2 Runtime does not restrict which applications may join a cluster.

Cluster environments are intended for well coordinated applications that agree on the
cluster name and options in advance, or that read the current options with
`GetCoreWebView2ClusterEnvironmentOptions` before joining. They are not intended for
loosely coupled applications that share a WebView2 environment without that
coordination.

This spec proposes a symmetric create-or-join model and a companion operation that reads a
cluster's options:

- Every host calls the same symmetric `CreateOrJoinCoreWebView2ClusterEnvironment` with
  its full desired options. The **first** host to establish a cluster with a given
  `ClusterName` determines the cluster's options. A later host that passes
  matching options attaches to the running cluster; a host that passes different
  options receives a completion status of
  `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`.
- A separate `GetCoreWebView2ClusterEnvironmentOptions` reads the cluster's options
  for a `ClusterName` without launching the shared browser process, so a host can read a
  cluster's current options before the host calls the create-or-join operation.

Sharing intent is expressed by a `ClusterName` (a stable rendezvous name that all
cooperating hosts agree on). The mapping from `ClusterName` to on-disk user data folder is a
fixed function, so the same `ClusterName` always resolves to the same folder.

# Description

A **cluster environment** is a WebView2 environment that a group of cooperating
host applications deliberately share, identified by a well-known `ClusterName` string that
those hosts agree on out of band. All hosts that establish a cluster with the same
`ClusterName` run inside one shared browser process and one on-disk user data folder.

Cluster environments are supported for standard desktop host processes: non-sandboxed,
non-containerized applications running at medium or high integrity level. For an
application that cannot create or share the cluster's per-user user data folder, the
outcome is reported with a status of
`COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED` rather than as a failure of the
call. A transient failure to access an otherwise-supported cluster's user data folder
(for example, an access-denied or sharing violation) is not reported that way; it
surfaces as an ordinary create failure.

These entry points exist only in WebView2 Runtime versions that implement them. On an
older runtime they are unavailable, so a host should feature-detect the API using the
standard WebView2 versioning guidance and fall back to a private environment when it
is absent.

Unlike `CreateCoreWebView2EnvironmentWithOptions`, you do **not** pass a user data
folder. The runtime derives the folder from the `ClusterName`, so every host that uses
the same `ClusterName` resolves to the same on-disk location. `ClusterName` comparison is
case-insensitive, so `ClusterName` values that differ only in case refer to the same cluster.
A different `ClusterName` gives a different cluster, with its own folder and its own
browser process.
The folder is created under a per-user cluster root,
`%LOCALAPPDATA%\Microsoft\WebView2Clusters\<ClusterName>`, with the `ClusterName` as the leaf folder
name (this is why the `ClusterName` must be a valid folder name). A cluster occupies its own
user data folder namespace: folders under this root are reachable only through the
cluster API. Even if a caller passes a cluster folder path explicitly to
`CreateCoreWebView2EnvironmentWithOptions`, that call is rejected and does not join the
cluster, so a cluster never joins or collides with an environment created through the
ordinary create path.

The **cluster options** are the `ICoreWebView2ClusterEnvironmentOptions` that the
first host to establish the cluster supplied. They apply to the whole shared browser
process and are shared by every host that attaches, so the options supplied by the
first host are authoritative for as long as the cluster's browser process is
running; there is no per-host override. A cluster exists only while its browser
process is running: once that process exits, the cluster no longer exists, and the
next host to create may supply a different set of options. This type intentionally
exposes only a subset of the environment options.

The recommended usage pattern is **"Get, then create or join"**:

1. Call `GetCoreWebView2ClusterEnvironmentOptions(clusterName)` to see what options, if any,
   the cluster already uses. This does not launch the shared browser process.
2. If a cluster already exists, reuse its options and attach to it. If none exists
   yet, provide your own options, which become the cluster's options.
3. Call `CreateOrJoinCoreWebView2ClusterEnvironment` with the chosen options. You either
   establish the cluster or attach to one with matching options.

`Get` is only a hint: another host can establish a cluster with different options
immediately after `Get` returns. The running browser process remains authoritative, so
`CreateOrJoinCoreWebView2ClusterEnvironment` still validates the supplied options. If
`CreateOrJoinCoreWebView2ClusterEnvironment` reports
`COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`, call
`GetCoreWebView2ClusterEnvironmentOptions` again to read the authoritative options and
retry, or fall back to a private environment. If
`CreateOrJoinCoreWebView2ClusterEnvironment` reports
`COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED` (this host cannot use a cluster
environment), use a private environment. A private environment is an ordinary
environment created with its own user data folder through
`CreateCoreWebView2EnvironmentWithOptions`; it has its own data and does not share with
the cluster.

Options **match** when every option on `ICoreWebView2ClusterEnvironmentOptions`
except `ClusterName` is equal: each scalar and boolean option is equal, `AdditionalBrowserArguments`
is the same string (compared exactly, with no normalization of whitespace or switch
order), and the custom scheme registrations are the same in the same order. The
release-channel options (`ReleaseChannels` and `ChannelSearchKind`) are part of this
comparison, so a host requesting a different channel than the running cluster receives
a mismatch. `ClusterName` identifies the cluster and is not part of this comparison.

Profile isolation in a cluster is **anti-misuse, not a security boundary**. When
`PerHostProfileIsolation` is TRUE (the default), the Edge browser profile names used
within the cluster's shared user data folder are namespaced per host application, so
two different host applications that use the same profile name do not accidentally end
up sharing one profile. Here a "host application" is identified by its main executable
file name (the same host identity WebView2 already derives to distinguish apps),
compared case-insensitively. This is not a security boundary: it does not encrypt
profile data or apply access control lists to it, the host identity is not
authenticated, and applications that run from an executable with the same file name, or
that deliberately use the same host identity and profile name, can still share a
profile. Do not rely on it to isolate mutually distrusting code.

Because a cluster shares one browser process, environment-wide process diagnostics
can expose frame names and last-committed URLs for frames owned by other hosts in the
cluster. Cluster members must trust one another with this metadata.

Joining a cluster is controlled only by the `ClusterName`. In this initial version there is no
authentication or admission control: any process running as the same user that supplies
a matching `ClusterName` (and resolves the same runtime) attaches to the cluster, and matching
`ClusterName` values are the only requirement to join. The runtime does not verify the identity
of the joining host. Treat the `ClusterName` as a shared capability agreed among cooperating
hosts, and do not use a cluster to share data across trust boundaries. The `ClusterName`
is not a security boundary: cluster folders can be enumerated under the per-user cluster
root, so choosing a less predictable name does not provide a meaningful security benefit.

A cluster is scoped to a single user and a single logon session: its user data folder
lives under the user's profile, and its coordination objects live in the per-session
`Local\` namespace. Sharing a cluster across different users or across different logon
sessions is not supported. All cooperating hosts must also run at the same integrity
level and elevation state as the host that established the cluster. A host at a
different integrity level may be unable to open the cluster's coordination objects or
connect to the shared browser process and will fail to join; mixing integrity levels or
elevation among hosts is not supported and is not guaranteed to fail cleanly. This
mirrors the existing guidance against sharing a single user data folder across
elevation with `CreateCoreWebView2EnvironmentWithOptions`.

# Examples

## Win32 C++

The example shows the recommended "Get, then create or join" flow: read the cluster's options
for a well-known cluster name, reuse them if the cluster already exists, otherwise
offer your own; then create (which either establishes the cluster or attaches to one
with matching options). On a mismatch, re-read the authoritative options and retry.

```cpp
// A stable rendezvous name that all cooperating hosts agree on.
constexpr PCWSTR kClusterName = L"Contoso.Shell.Default";

// The first WebView2 Runtime version that supports cluster environments.
constexpr PCWSTR kMinClusterRuntimeVersion = L"1.0.9999.0";

// Build the options this host would use if it is the first to establish the cluster.
wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> BuildClusterOptions()
{
    auto options = Microsoft::WRL::Make<CoreWebView2ClusterEnvironmentOptions>();
    CHECK_FAILURE(options->put_ClusterName(kClusterName));
    CHECK_FAILURE(options->put_Language(L"en-US"));
    CHECK_FAILURE(options->put_AreBrowserExtensionsEnabled(FALSE));
    return options;
}

void AppWindow::CreateSharedEnvironment()
{
    // Step 0 - check that the installed WebView2 Runtime is new enough to support
    // cluster environments. If it is not, use a private environment.
    wil::unique_cotaskmem_string availableVersion;
    int versionComparison = 0;
    if (FAILED(GetAvailableCoreWebView2BrowserVersionString(
            nullptr, &availableVersion)) ||
        FAILED(CompareBrowserVersions(
            availableVersion.get(), kMinClusterRuntimeVersion,
            &versionComparison)) ||
        versionComparison < 0)
    {
        UsePrivateEnvironment();
        return;
    }

    // Step 1 - synchronously ask what options the cluster already uses. This call
    // does not start a browser process. `existing` is null when no cluster is
    // running for this name.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> existing;
    CHECK_FAILURE(GetCoreWebView2ClusterEnvironmentOptions(kClusterName, &existing));

    // Step 2 - if a cluster already exists, decide whether its options are acceptable
    // before attaching; if not, use a private environment. Offer this host's options if
    // no cluster exists yet.
    if (existing && !AcceptableForMe(existing.get()))
    {
        UsePrivateEnvironment();
        return;
    }
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> options =
        existing ? existing : BuildClusterOptions();

    // Step 3 - use the same create operation in either case: it establishes or attaches to a
    // cluster with matching options.
    CreateSharedEnvironmentWithOptions(options.get());
}

void AppWindow::CreateSharedEnvironmentWithOptions(
    ICoreWebView2ClusterEnvironmentOptions* options, bool allowRetry /* = true */)
{
    HRESULT hr = CreateOrJoinCoreWebView2ClusterEnvironment(
        options,
        Microsoft::WRL::Callback<ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler>(
            [this](HRESULT errorCode,
                   ICoreWebView2ClusterEnvironmentCreateResult* result) -> HRESULT
            {
                // A failing errorCode means the operation started but then failed
                // (for example, the browser process could not be launched). Handle the
                // creation failure the same way as a failure from
                // CreateCoreWebView2EnvironmentWithOptions
                // (for example, surface an error and stop).
                CHECK_FAILURE(errorCode);

                COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS status;
                CHECK_FAILURE(result->get_Status(&status));
                switch (status)
                {
                case COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED:
                {
                    // Established the cluster or attached to one with matching options.
                    wil::com_ptr<ICoreWebView2Environment> environment;
                    CHECK_FAILURE(result->get_Environment(&environment));
                    OnSharedEnvironmentReady(environment.get());
                    break;
                }

                case COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH:
                {
                    // The live cluster's options differ from the requested options. Re-read the
                    // authoritative options and retry once with them; if it still
                    // does not work out, go private. Retrying only once (rather than
                    // looping) bounds the work if the cluster keeps changing.
                    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> authoritative;
                    if (allowRetry &&
                        SUCCEEDED(GetCoreWebView2ClusterEnvironmentOptions(
                            kClusterName, &authoritative)) &&
                        authoritative &&
                        AcceptableForMe(authoritative.get()))
                    {
                        CreateSharedEnvironmentWithOptions(
                            authoritative.get(), /*allowRetry=*/false);
                    }
                    else
                    {
                        UsePrivateEnvironment();
                    }
                    break;
                }

                case COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED:
                {
                    // This host cannot use cluster environments, for example a
                    // sandboxed AppContainer process such as a UWP app.
                    UsePrivateEnvironment();
                    break;
                }

                default:
                {
                    // Unknown status from a newer runtime; do not use clusters.
                    UsePrivateEnvironment();
                    break;
                }
                }
                return S_OK;
            })
            .Get());

    // Runtime discovery failures, such as no compatible WebView2 Runtime being
    // installed, are reported synchronously here.
    CHECK_FAILURE(hr);
}
```

## .NET/WinRT

```c#
// A stable rendezvous name that all cooperating hosts agree on.
const string SharedClusterName = "Contoso.Shell.Default";

// The first WebView2 Runtime version that supports cluster environments.
const string MinClusterRuntimeVersion = "1.0.9999.0";

CoreWebView2ClusterEnvironmentOptions BuildClusterOptions()
{
    return new CoreWebView2ClusterEnvironmentOptions()
    {
        ClusterName = SharedClusterName,
        Language = "en-US",
        AreBrowserExtensionsEnabled = false,
    };
}

async Task CreateSharedEnvironmentAsync()
{
    // Step 0 - check that the installed WebView2 Runtime is new enough to support
    // cluster environments. If it is not, use a private environment. A missing
    // Runtime throws, the same as CreateAsync.
    string availableVersion;
    try
    {
        availableVersion = CoreWebView2Environment.GetAvailableBrowserVersionString();
    }
    catch (WebView2RuntimeNotFoundException)
    {
        UsePrivateEnvironment();
        return;
    }

    if (CoreWebView2Environment.CompareBrowserVersions(
            availableVersion, MinClusterRuntimeVersion) < 0)
    {
        UsePrivateEnvironment();
        return;
    }

    // Step 1 - synchronously ask what options the cluster already uses. This call
    // does not start a browser process. `existing` is null when no cluster is
    // running for this name.
    CoreWebView2ClusterEnvironmentOptions existing =
        CoreWebView2Environment.GetClusterEnvironmentOptions(SharedClusterName);

    // Step 2 - if a cluster already exists, decide whether its options are
    // acceptable before attaching; if not, use a private environment. Offer this host's
    // options if no cluster exists yet.
    if (existing != null && !AcceptableForMe(existing))
    {
        UsePrivateEnvironment();
        return;
    }
    CoreWebView2ClusterEnvironmentOptions options = existing ?? BuildClusterOptions();

    // Step 3 - use the same create operation in either case: it establishes or
    // attaches to a cluster with matching options.
    await CreateSharedEnvironmentWithOptionsAsync(options);
}

async Task CreateSharedEnvironmentWithOptionsAsync(
    CoreWebView2ClusterEnvironmentOptions options, bool allowRetry = true)
{
    // The expected outcomes, including this host not being able to use cluster
    // environments, come back as Status. Failures throw the same as CreateAsync,
    // whether the operation could not start (for example, no compatible WebView2
    // Runtime is installed) or started and then failed (for example, the browser
    // process could not be launched).
    CoreWebView2ClusterEnvironmentCreateResult result =
        await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(options);

    switch (result.Status)
    {
        case CoreWebView2ClusterEnvironmentStatus.Succeeded:
            // Established the cluster or attached to one with matching options.
            OnSharedEnvironmentReady(result.Environment);
            break;

        case CoreWebView2ClusterEnvironmentStatus.OptionsMismatch:
        {
            // The live cluster's options differ from the requested options. Re-read
            // the authoritative options and retry once with them; if it still does
            // not work out, go private.
            CoreWebView2ClusterEnvironmentOptions authoritative =
                CoreWebView2Environment.GetClusterEnvironmentOptions(SharedClusterName);
            if (allowRetry &&
                authoritative != null &&
                AcceptableForMe(authoritative))
            {
                await CreateSharedEnvironmentWithOptionsAsync(
                    authoritative, allowRetry: false);
            }
            else
            {
                UsePrivateEnvironment();
            }
            break;
        }

        case CoreWebView2ClusterEnvironmentStatus.NotSupported:
            // This host cannot use cluster environments, for example a sandboxed
            // AppContainer process such as a UWP app.
            UsePrivateEnvironment();
            break;

        default:
            // Unknown status from a newer runtime; do not use clusters.
            UsePrivateEnvironment();
            break;
    }
}
```

## Deleting a cluster's user data folder

WebView2 does not delete a cluster's user data folder automatically. Cleaning it up is
the cooperating applications' shared responsibility. Because several applications can
use the same cluster, the folder must not be deleted until every cooperating application
has been uninstalled.

### Save the folder path when the cluster is created

The folder path can only be read from a live environment, and by uninstall time there is
no environment left to ask. Each application should therefore read `UserDataFolder` when
it first creates or joins the cluster and persist the path somewhere that outlives the
application's installation.

```cpp
// After CreateOrJoinClusterEnvironment succeeds.
wil::unique_cotaskmem_string userDataFolder;
CHECK_FAILURE(m_clusterEnvironment->get_UserDataFolder(&userDataFolder));
SaveClusterUserDataFolderPath(userDataFolder.get());
```

```c#
// After CreateOrJoinClusterEnvironmentAsync succeeds.
SaveClusterUserDataFolderPath(m_clusterEnvironment.UserDataFolder);
```

### Delete the folder once the last application is uninstalled

Deleting the folder requires that no cooperating application remains installed and that
the cluster is not running. A cluster exists only while its browser process is running,
and the folder cannot be deleted while it is in use. How an application determines that
the other cooperating applications have been uninstalled is app-specific and outside the
scope of this API.

How the deletion is triggered depends on the installer technology:

- **MSI**: perform the check and delete the saved folder path from an uninstall custom
  action or uninstall script.
- **MSIX**: packages cannot run code on uninstall, so an application cannot delete the
  folder as part of its own removal. Instead, register a scheduled task that runs
  independently of the package, checks whether all cooperating applications, including
  the one that registered the task, have been uninstalled, and deletes the saved folder
  path once they have. The task should remove itself after it has cleaned up so it does
  not remain registered indefinitely.

# API Details

## Win32 C++

```cpp
/// The outcome of `CreateOrJoinCoreWebView2ClusterEnvironment`, reported to the
/// completion handler when `errorCode` is `S_OK`.
[v1_enum] typedef enum COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS {
  /// The shared cluster environment is ready, either freshly established or attached
  /// to an existing cluster with matching options.
  COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED,
  /// A cluster already exists for this `ClusterName` with different options. No environment is
  /// provided; read the cluster's options with
  /// `GetCoreWebView2ClusterEnvironmentOptions` and retry, or use a private
  /// (non-shared) environment.
  COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH,
  /// This host cannot use cluster environments, for example a sandboxed
  /// AppContainer process such as a UWP app. No environment is provided; use a
  /// private (non-shared) environment instead.
  COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED,
} COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS;

/// Establishes or attaches to the shared WebView2 cluster environment identified
/// by the `ClusterName` in `options`. If no cluster exists for the `ClusterName`, this establishes
/// one and the caller's options become the cluster's options. If a cluster already
/// exists and the caller's options match it, the caller attaches to it. The outcome
/// is reported to `handler` as a `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS`.
///
/// The return value reports whether `CreateOrJoinCoreWebView2ClusterEnvironment`
/// could start:
///   S_OK                                     -> started; `handler` will be invoked
///                                               with the result.
///   E_INVALIDARG                             -> `options` or its `ClusterName` is invalid;
///                                               `handler` is not invoked.
///   HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) -> no compatible WebView2 Runtime was
///                                               found; `handler` is not invoked.
/// Runtime discovery and compatibility failures are reported synchronously, before
/// the operation starts, exactly as for `CreateCoreWebView2EnvironmentWithOptions`.
/// When the return value is any failing `HRESULT`, `handler` is not invoked.
///
/// A host that cannot use cluster environments is not a failure of the call. The
/// operation starts and `handler` is invoked with
/// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED`, so a caller does not need
/// to handle it as an error to use this API correctly.
///
/// `handler` is invoked on the thread that called this function (which must pump a
/// message loop), the same delivery model as `CreateCoreWebView2EnvironmentWithOptions`.
/// Concurrent calls for the same `ClusterName`, whether from this or another cooperating host,
/// are serialized: the first to establish the cluster fixes its options, and each
/// later call either attaches (matching options) or reports
/// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`.
///
/// Only the options on `ICoreWebView2ClusterEnvironmentOptions` participate in the
/// match. Some options resolve against the host process or machine rather than being a
/// fixed value; in that case the first host to establish the cluster fixes the effective
/// behavior for every host that attaches. For example, an empty `Language` resolves to
/// the first host's OS display language, so a later host with a different OS locale uses
/// that same language. Cooperating hosts that want a predictable result should set such
/// options explicitly.
///
/// State that is not an option is not part of the match and does not produce
/// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`. Loader overrides such as
/// `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` are host-determined, and the first host's
/// resolution governs the cluster. The host process's DPI awareness is likewise not an
/// option; as when sharing a user data folder through
/// `CreateCoreWebView2EnvironmentWithOptions`, DPI awareness is negotiated with the
/// shared browser process when a WebView is created on a window, so a later host whose
/// DPI awareness is incompatible with the running shared browser can fail when it creates
/// a WebView rather than here.
STDAPI CreateOrJoinCoreWebView2ClusterEnvironment(
    [in] ICoreWebView2ClusterEnvironmentOptions* options,
    [in] ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler* handler);

/// Reads the options of the cluster identified by its `ClusterName` without creating or
/// attaching to a cluster. A cluster exists only while its browser process is
/// running. Returns `S_OK` and the cluster's options when a cluster is running for
/// that `ClusterName`, or `S_OK` and `nullptr` `options` when no cluster is running for
/// that `ClusterName`. Check `options` for `nullptr` rather than for a failing
/// `HRESULT`. Returns `E_INVALIDARG` for an invalid `ClusterName`.
///
/// The returned object is a detached snapshot of the cluster's options at the time
/// of the call. Modifying it does not affect the running cluster; to change a
/// cluster's options, all hosts must agree on the new set out of band.
///
/// Also returns `S_OK` and `nullptr` `options` in hosts that cannot use cluster
/// environments, such as a sandboxed AppContainer process (for example, a UWP app).
STDAPI GetCoreWebView2ClusterEnvironmentOptions(
    [in] LPCWSTR clusterName,
    [out] ICoreWebView2ClusterEnvironmentOptions** options);

/// Provides the options used to establish or attach to a shared cluster environment.
interface ICoreWebView2ClusterEnvironmentOptions : IUnknown {
  /// The name that identifies the cluster. All cooperating hosts use the same
  /// value. Use a stable, descriptive name that your applications agree on in
  /// advance. To avoid colliding with another application's cluster, include a name
  /// you control, such as your company or product name, or a GUID. For example,
  /// `"Contoso.Shell.Default"` or
  /// `"{5E4A1C6E-9C7B-4C2B-8B1E-2F3A5D7C9E11}.Shell"`. Must not be `nullptr`
  /// or empty. The `ClusterName` is case-insensitive, is limited to 128 characters,
  /// and must be a valid file-system folder
  /// name; otherwise the call fails with `E_INVALIDARG`. The returned string is
  /// allocated with `CoTaskMemAlloc`; the caller must free it with `CoTaskMemFree`.
  [propget] HRESULT ClusterName([out, retval] LPWSTR* value);
  /// Sets the `ClusterName` property.
  [propput] HRESULT ClusterName([in] LPCWSTR value);

  /// Specifies additional command-line switches to pass to the shared browser
  /// process. The default is an empty string. The returned string is allocated with
  /// `CoTaskMemAlloc`; the caller must free it with `CoTaskMemFree`.
  [propget] HRESULT AdditionalBrowserArguments([out, retval] LPWSTR* value);
  /// Sets the `AdditionalBrowserArguments` property.
  [propput] HRESULT AdditionalBrowserArguments([in] LPCWSTR value);

  /// Specifies the default display language for the shared environment. The default
  /// is the empty string (the runtime default). The returned string is allocated
  /// with `CoTaskMemAlloc`; the caller must free it with `CoTaskMemFree`.
  [propget] HRESULT Language([out, retval] LPWSTR* value);
  /// Sets the `Language` property.
  [propput] HRESULT Language([in] LPCWSTR value);

  /// Indicates whether single sign-on using the OS primary account is allowed. The
  /// default is `FALSE`.
  [propget] HRESULT AllowSingleSignOnUsingOSPrimaryAccount([out, retval] BOOL* value);
  /// Sets the `AllowSingleSignOnUsingOSPrimaryAccount` property.
  [propput] HRESULT AllowSingleSignOnUsingOSPrimaryAccount([in] BOOL value);

  /// Indicates whether tracking prevention is enabled for the shared environment.
  /// The default is `TRUE`.
  [propget] HRESULT EnableTrackingPrevention([out, retval] BOOL* value);
  /// Sets the `EnableTrackingPrevention` property.
  [propput] HRESULT EnableTrackingPrevention([in] BOOL value);

  /// Indicates whether browser extensions are enabled for the shared environment.
  /// The default is `FALSE`.
  [propget] HRESULT AreBrowserExtensionsEnabled([out, retval] BOOL* value);
  /// Sets the `AreBrowserExtensionsEnabled` property.
  [propput] HRESULT AreBrowserExtensionsEnabled([in] BOOL value);

  /// When TRUE (the default), the Edge browser profile names used within the
  /// cluster's shared user data folder are namespaced per host application, to
  /// prevent accidental cross-app profile use. This is not a security boundary.
  [propget] HRESULT PerHostProfileIsolation([out, retval] BOOL* value);
  /// Sets the `PerHostProfileIsolation` property.
  [propput] HRESULT PerHostProfileIsolation([in] BOOL value);

  /// The release channels the shared environment creation searches for, as a mask
  /// of one or more `COREWEBVIEW2_RELEASE_CHANNELS`. Because the browser process is
  /// shared, this selects the channel of the shared browser. The default is a mask
  /// of all channels.
  [propget] HRESULT ReleaseChannels([out, retval] COREWEBVIEW2_RELEASE_CHANNELS* value);
  /// Sets the `ReleaseChannels` property.
  [propput] HRESULT ReleaseChannels([in] COREWEBVIEW2_RELEASE_CHANNELS value);

  /// The order in which release channels are searched during shared environment
  /// creation. The default is `COREWEBVIEW2_CHANNEL_SEARCH_KIND_MOST_STABLE`.
  [propget] HRESULT ChannelSearchKind([out, retval] COREWEBVIEW2_CHANNEL_SEARCH_KIND* value);
  /// Sets the `ChannelSearchKind` property.
  [propput] HRESULT ChannelSearchKind([in] COREWEBVIEW2_CHANNEL_SEARCH_KIND value);

  /// Gets the custom scheme registrations for the shared environment. The returned
  /// `ICoreWebView2CustomSchemeRegistration` pointers must be released, and the array
  /// itself must be deallocated with `CoTaskMemFree`.
  HRESULT GetCustomSchemeRegistrations(
      [out] UINT32* count,
      [out] ICoreWebView2CustomSchemeRegistration*** schemeRegistrations);
  /// Sets the custom scheme registrations for the shared environment.
  HRESULT SetCustomSchemeRegistrations(
      [in] UINT32 count,
      [in] const ICoreWebView2CustomSchemeRegistration** schemeRegistrations);
}

/// Describes the result of `CreateOrJoinCoreWebView2ClusterEnvironment` that is
/// provided to the completion handler when `errorCode` is `S_OK`.
interface ICoreWebView2ClusterEnvironmentCreateResult : IUnknown {
  /// Indicates the outcome of the create-or-join operation.
  [propget] HRESULT Status(
      [out, retval] COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS* value);

  /// Gets the shared cluster environment. This is non-null only when `Status` is
  /// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED`; otherwise, it is `nullptr`.
  [propget] HRESULT Environment([out, retval] ICoreWebView2Environment** value);
}

/// Receives the result of `CreateOrJoinCoreWebView2ClusterEnvironment`.
interface ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler : IUnknown {
  /// When `errorCode` is `S_OK`, `result` describes the outcome via its `Status`:
  ///  * `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_SUCCEEDED` - `result.Environment`
  ///    is the shared cluster environment.
  ///  * `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH` - a cluster
  ///    already exists for this `ClusterName` with different options; `result.Environment`
  ///    is `nullptr`.
  ///  * `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_NOT_SUPPORTED` - this host cannot
  ///    use cluster environments; `result.Environment` is `nullptr`.
  ///
  /// When `errorCode` is a failing `HRESULT`, the operation started but then failed
  /// after start (for example, the browser process could not be launched), and
  /// `result` is `nullptr`. Failures detected before the operation starts, such as an
  /// invalid `ClusterName` or a missing WebView2 Runtime, are reported through the synchronous
  /// return value of `CreateOrJoinCoreWebView2ClusterEnvironment` and do not invoke
  /// this handler.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2ClusterEnvironmentCreateResult* result);
}
```

## .NET/WinRT

The two global functions are exposed as static methods on `CoreWebView2Environment`,
mirroring how `CreateCoreWebView2EnvironmentWithOptions` maps to
`CoreWebView2Environment.CreateAsync`. `CreateOrJoinClusterEnvironmentAsync` returns a
`CoreWebView2ClusterEnvironmentCreateResult` that contains the `Status` and, on success,
the `Environment`. A host that cannot use cluster environments (for example, a sandboxed
AppContainer process such as a UWP app) is reported as
`CoreWebView2ClusterEnvironmentStatus.NotSupported` rather than as an exception, so
minimal correct usage of this API does not require a `try`/`catch`. The method still
throws when the operation cannot be started or fails after starting, for example when no
compatible WebView2 Runtime is found, the same as `CreateAsync`.
`GetClusterEnvironmentOptions` returns `null` when no cluster exists for the given
`ClusterName`, matching the COM API, which returns `S_OK` with `nullptr` options.

```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ClusterEnvironmentStatus
    {
        Succeeded = 0,
        OptionsMismatch = 1,
        NotSupported = 2,
    };

    runtimeclass CoreWebView2ClusterEnvironmentCreateResult
    {
        CoreWebView2ClusterEnvironmentStatus Status { get; };
        // Environment is non-null only when Status is Succeeded.
        CoreWebView2Environment Environment { get; };
    }

    runtimeclass CoreWebView2ClusterEnvironmentOptions
    {
        CoreWebView2ClusterEnvironmentOptions();

        String ClusterName { get; set; };
        String AdditionalBrowserArguments { get; set; };
        String Language { get; set; };
        Boolean AllowSingleSignOnUsingOSPrimaryAccount { get; set; };
        Boolean EnableTrackingPrevention { get; set; };
        Boolean AreBrowserExtensionsEnabled { get; set; };
        Boolean PerHostProfileIsolation { get; set; };
        CoreWebView2ReleaseChannels ReleaseChannels { get; set; };
        CoreWebView2ChannelSearchKind ChannelSearchKind { get; set; };
        IVector<CoreWebView2CustomSchemeRegistration> CustomSchemeRegistrations { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        // Establishes or attaches to the shared cluster identified by options.ClusterName.
        // The result's Status reports the outcome (Succeeded, OptionsMismatch or
        // NotSupported); Environment is non-null only when Status is Succeeded. A host
        // that cannot use cluster environments is reported as NotSupported rather than
        // as an exception. Throws when the operation cannot be started or fails after
        // starting, for example when no compatible WebView2 Runtime is found.
        static Windows.Foundation.IAsyncOperation<CoreWebView2ClusterEnvironmentCreateResult>
            CreateOrJoinClusterEnvironmentAsync(CoreWebView2ClusterEnvironmentOptions options);

        // Reads the options of the cluster identified by its ClusterName. Returns
        // null when no cluster exists for that ClusterName, and also returns null in
        // hosts that cannot use cluster environments.
        static CoreWebView2ClusterEnvironmentOptions GetClusterEnvironmentOptions(
            String clusterName);
    }
}
```

# Appendix

## Relationship to existing options

The proposal defines `ICoreWebView2ClusterEnvironmentOptions` as a new type instead of
reusing `ICoreWebView2EnvironmentOptions`. `ICoreWebView2ClusterEnvironmentOptions`
applies to the whole shared browser process. The first host to establish the cluster
supplies the options, and every host that attaches shares them; there is no per-host
override. The type intentionally exposes only a subset of the environment options.

## Runtime selection and loader overrides

Cluster environments locate a WebView2 Runtime through the same loader mechanism as
`CreateCoreWebView2EnvironmentWithOptions`, including the existing loader overrides such
as the `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` environment variable and the corresponding
registry override. This initial version does **not** coordinate those overrides across
hosts. The cluster options do not capture them, they are not part of the options match,
and the API does not detect or reconcile a difference between hosts.

Because a WebView2 host loads a client DLL that must be the same version as the browser
process it connects to, cooperating hosts must resolve the **same** runtime. The first
host to establish the cluster launches the shared browser process from whatever runtime
its loader resolved; a later host that resolves a different runtime (for example, because
it has a loader override set that the first host did not) would load a mismatched client
DLL and fail to join the running cluster. It is therefore the developer's
responsibility to ensure every host that shares a cluster resolves the same runtime,
ideally by not setting loader overrides for these apps, or by setting them identically
across all cooperating hosts.
