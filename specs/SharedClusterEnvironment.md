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
another and agree on a shared cluster `Id` in advance; sharing is by convention, and
the WebView2 Runtime does not restrict which applications may join a cluster.

This spec proposes a symmetric create-or-join model and a companion operation that reads a
cluster's options:

- Every host calls the same symmetric `CreateOrJoinCoreWebView2ClusterEnvironment` with
  its full desired options. The **first** host to establish a cluster with a given
  `Id` determines the cluster's options (first-creator-wins). A later host that passes
  matching options attaches to the running cluster; a host that passes different
  options receives a completion status of
  `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`.
- A separate `GetCoreWebView2ClusterEnvironmentOptions` reads the cluster's options
  for an `Id` without launching the shared browser process, so a host can read a
  cluster's current options before the host calls the create-or-join operation.

Sharing intent is expressed by an `Id` (a stable rendezvous name that all
cooperating hosts agree on). The mapping from `Id` to on-disk user data folder is a
fixed function, so the same `Id` always resolves to the same folder.

# Description

A **cluster environment** is a WebView2 environment that a group of cooperating
host applications deliberately share, identified by a well-known `Id` string that
those hosts agree on out of band. All hosts that establish a cluster with the same
`Id` run inside one shared browser process and one on-disk user data folder.

A host process must be able to create and share the cluster's per-user user data
folder. A host that cannot, such as a sandboxed AppContainer process (for example, a
UWP app), fails with `ERROR_NOT_SUPPORTED`. A transient failure to access an
otherwise-supported cluster's user data folder (for example, an access-denied or
sharing violation) is not reported as `ERROR_NOT_SUPPORTED`; it surfaces as an ordinary
create failure.

These entry points exist only in WebView2 Runtime versions that implement them. On an
older runtime they are unavailable, so a host should feature-detect the API using the
standard WebView2 versioning guidance and fall back to a private environment when it
is absent.

Unlike `CreateCoreWebView2EnvironmentWithOptions`, you do **not** pass a user data
folder. The runtime derives the folder from the cluster `Id`, so every host that uses
the same `Id` resolves to the same on-disk location. `Id` comparison is
case-insensitive, so `Id` values that differ only in case refer to the same cluster.
The folder is created under a per-user cluster root,
`%LOCALAPPDATA%\Microsoft\WebView2Clusters\<Id>`, with the `Id` as the leaf folder
name (this is why the `Id` must be a valid folder name). A cluster occupies its own
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

1. Call `GetCoreWebView2ClusterEnvironmentOptions(id)` to see what options, if any,
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
`CreateOrJoinCoreWebView2ClusterEnvironment`
fails with `ERROR_NOT_SUPPORTED` (this host cannot use a cluster environment), use a
private environment. A private environment is an ordinary environment created with
your own user data folder through `CreateCoreWebView2EnvironmentWithOptions`; it has
its own data and does not share with the cluster.

Options **match** when every option on `ICoreWebView2ClusterEnvironmentOptions`
except `Id` is equal: each scalar and boolean option is equal, `AdditionalBrowserArguments`
is the same string (compared exactly, with no normalization of whitespace or switch
order), and the custom scheme registrations are the same in the same order. The
release-channel options (`ReleaseChannels` and `ChannelSearchKind`) are part of this
comparison, so a host requesting a different channel than the running cluster receives
a mismatch. `Id` identifies the cluster and is not part of this comparison.

Profile isolation in a cluster is **anti-misuse, not a security boundary**. When
`PerHostProfileIsolation` is TRUE (the default), profile names are namespaced per
host application, so two different host applications that use the same profile
name do not accidentally end up sharing one profile. Here a "host application" is
identified by its main executable file name (the same host identity WebView2 already
derives to distinguish apps), compared case-insensitively. This is not a
security boundary: it does not encrypt profile data or apply access control lists to
it, the host identity is not authenticated, and applications that run from an
executable with the same file name, or that deliberately use the same host identity and
profile name, can still share a profile. 
Because a cluster shares one browser process, environment-wide process diagnostics
can expose frame names and last-committed URLs for frames owned by other hosts in the
cluster. Cluster members must trust one another with this metadata.

Joining a cluster is controlled only by the `Id`. In this initial version there is no
authentication or admission control: any process running as the same user that supplies
a matching `Id` (and resolves the same runtime) attaches to the cluster, and matching
`Id` values are the only requirement to join. The runtime does not verify the identity
of the joining host. Treat the `Id` as a shared capability agreed among cooperating
hosts, and do not use a cluster to share data across trust boundaries. If it matters
that untrusted code on the machine cannot join, choose an `Id` that such code cannot
predict; the per-user cluster root still scopes clusters to a single user.

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
for a well-known cluster ID, reuse them if the cluster already exists, otherwise
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
    // Step 1 - synchronously ask what options the cluster already uses. This call
    // does not start a browser process.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> existing;
    HRESULT hr = GetCoreWebView2ClusterEnvironmentOptions(kClusterId, &existing);

    // Step 2 - if a cluster already exists, decide whether its options are acceptable
    // before attaching; if not, use a private environment. Offer this host's options if no
    // cluster exists yet, or use a private environment if cluster environments are
    // not supported in this host.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> options;
    if (SUCCEEDED(hr))
    {
        if (!AcceptableForMe(existing.get()))
        {
            UsePrivateEnvironment();
            return;
        }
        options = existing;
    }
    else if (hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND))
    {
        options = BuildClusterOptions();
    }
    else if (hr == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED))
    {
        // Sandboxed AppContainer process (for example, a UWP app) that cannot
        // use cluster environments.
        UsePrivateEnvironment();
        return;
    }
    else
    {
        CHECK_FAILURE(hr);
        return;
    }

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
                            kClusterId, &authoritative)) &&
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
                }
                return S_OK;
            })
            .Get());

    if (hr == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED))
    {
        // This host cannot use cluster environments (for
        // example, a sandboxed AppContainer process such as a UWP app). Cluster
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
        // Step 1 - read the cluster's options for this `Id`. This call does not start a
        // browser process. Returns null when no cluster exists yet.
        CoreWebView2ClusterEnvironmentOptions existing =
            CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);

        // Step 2 - if a cluster already exists, decide whether its options are
        // acceptable before attaching; if not, use a private environment. Offer this host's
        // options if no cluster exists yet.
        if (existing != null && !AcceptableForMe(existing))
        {
            UsePrivateEnvironment();
            return;
        }
        CoreWebView2ClusterEnvironmentOptions options = existing ?? BuildClusterOptions();

        // Step 3 - use the same create operation in either case. If the environment cannot be
        // created (for example, the WebView2 Runtime could not be found, or cluster
        // environments are not supported in this host) the call throws, the same as
        // CreateAsync; the expected outcomes come back as Status.
        CoreWebView2ClusterEnvironmentCreateResult result =
            await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(options);

        if (result.Status == CoreWebView2ClusterEnvironmentStatus.OptionsMismatch)
        {
            // The live cluster's options differ from the requested options. Re-read the
            // authoritative options and retry with them.
            CoreWebView2ClusterEnvironmentOptions authoritative =
                CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);
            if (authoritative != null && AcceptableForMe(authoritative))
            {
                result = await CoreWebView2Environment
                    .CreateOrJoinClusterEnvironmentAsync(authoritative);
            }
        }

        if (result.Status == CoreWebView2ClusterEnvironmentStatus.Succeeded)
        {
            // Established the cluster or attached to one with matching options.
            OnSharedEnvironmentReady(result.Environment);
        }
        else
        {
            // Still mismatched after retrying; fall back to a private environment.
            UsePrivateEnvironment();
        }
    }
    // HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED). This host cannot use cluster
    // environments (for example, a sandboxed AppContainer process
    // such as a UWP app); use a private environment instead.
    catch (COMException ex) when (ex.HResult == unchecked((int)0x80070032))
    {
        UsePrivateEnvironment();
    }
}
```

# API Details

## Win32 C++

```cpp
/// The outcome of `CreateOrJoinCoreWebView2ClusterEnvironment`, reported to the
/// completion handler when `errorCode` is `S_OK`.
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

/// Establishes or attaches to the shared WebView2 cluster environment identified
/// by the `Id` in `options`. If no cluster exists for the `Id`, this establishes
/// one and the caller's options become the cluster's options. If a cluster already
/// exists and the caller's options match it, the caller attaches to it. The outcome
/// is reported to `handler` as a `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS`.
///
/// The return value reports whether `CreateOrJoinCoreWebView2ClusterEnvironment`
/// could start:
///   S_OK                                     -> started; `handler` will be invoked
///                                               with the result.
///   E_INVALIDARG                             -> `options` or its `Id` is invalid;
///                                               `handler` is not invoked.
///   HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)  -> the host cannot use cluster
///                                               environments (for
///                                               example, a sandboxed AppContainer
///                                               process such as a UWP app); `handler`
///                                               is not invoked.
///   HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) -> no compatible WebView2 Runtime was
///                                               found; `handler` is not invoked.
/// Runtime discovery and compatibility failures are reported synchronously, before
/// the operation starts, exactly as for `CreateCoreWebView2EnvironmentWithOptions`.
/// When the return value is any failing `HRESULT`, `handler` is not invoked.
///
/// `handler` is invoked on the thread that called this function (which must pump a
/// message loop), the same delivery model as `CreateCoreWebView2EnvironmentWithOptions`.
/// Concurrent calls for the same `Id`, whether from this or another cooperating host,
/// are serialized: the first to establish the cluster fixes its options, and each
/// later call either attaches (matching options) or reports
/// `COREWEBVIEW2_CLUSTER_ENVIRONMENT_STATUS_OPTIONS_MISMATCH`.
STDAPI CreateOrJoinCoreWebView2ClusterEnvironment(
    [in] ICoreWebView2ClusterEnvironmentOptions* options,
    [in] ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler* handler);

/// Reads the options of the cluster identified by its `Id` without creating or
/// attaching to a cluster. A cluster exists only while its browser process is
/// running. Returns `S_OK` and the cluster's options when a cluster is running for
/// that `Id`, or `HRESULT_FROM_WIN32(ERROR_NOT_FOUND)` and `nullptr` `options` when
/// no cluster is running for that `Id`. Returns `E_INVALIDARG` for an invalid `Id`.
///
/// The returned object is a detached snapshot of the cluster's options at the time
/// of the call. Modifying it does not affect the running cluster; to change a
/// cluster's options, all hosts must agree on the new set out of band.
///
/// Returns `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)` and `nullptr` `options` in hosts
/// that cannot use cluster environments, such as a sandboxed
/// AppContainer process (for example, a UWP app).
STDAPI GetCoreWebView2ClusterEnvironmentOptions(
    [in] LPCWSTR id,
    [out] ICoreWebView2ClusterEnvironmentOptions** options);

/// Provides the options used to establish or attach to a shared cluster environment.
interface ICoreWebView2ClusterEnvironmentOptions : IUnknown {
  /// The name that identifies the cluster. All cooperating hosts use the same
  /// value. Use a stable, descriptive name your applications agree on (for example,
  /// `"Contoso.Shell.Default"`); it does not need to be a GUID. Must not be `nullptr`
  /// or empty. The `Id` is case-insensitive and must be a valid file-system folder
  /// name; otherwise the call fails with `E_INVALIDARG`. The returned string is
  /// allocated with `CoTaskMemAlloc`; the caller must free it with `CoTaskMemFree`.
  [propget] HRESULT Id([out, retval] LPWSTR* id);
  /// Sets the `Id` property.
  [propput] HRESULT Id([in] LPCWSTR id);

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

  /// When TRUE (the default), profile names are isolated per host application to
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
  ///    already exists for this `Id` with different options; `result.Environment`
  ///    is `nullptr`.
  ///
  /// When `errorCode` is a failing `HRESULT`, the operation started but then failed
  /// after start (for example, the browser process could not be launched), and
  /// `result` is `nullptr`. Failures detected before the operation starts, such as an
  /// invalid `Id` or a missing WebView2 Runtime, are reported through the synchronous
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
the `Environment`. When the operation cannot be started or fails, the method throws an exception; in
particular a host that cannot use cluster environments (for
example a sandboxed AppContainer process such as a UWP app) throws a
`COMException` whose `HResult` is `HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED)`.
`GetClusterEnvironmentOptions` returns `null` when no cluster exists for the ID,
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
        // Environment is non-null only when Status is Succeeded.
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
        CoreWebView2ReleaseChannels ReleaseChannels { get; set; };
        CoreWebView2ChannelSearchKind ChannelSearchKind { get; set; };
        IVector<CoreWebView2CustomSchemeRegistration> CustomSchemeRegistrations { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        // Establishes or attaches to the shared cluster identified by options.Id.
        // The result's Status reports the outcome (Succeeded or OptionsMismatch);
        // Environment is non-null only when Status is Succeeded. Throws when the
        // operation cannot be started or fails, including
        // HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) when the host cannot use cluster
        // environments (for example, a sandboxed AppContainer process such as a UWP
        // app).
        static Windows.Foundation.IAsyncOperation<CoreWebView2ClusterEnvironmentCreateResult>
            CreateOrJoinClusterEnvironmentAsync(CoreWebView2ClusterEnvironmentOptions options);

        // Reads the options of the cluster identified by its Id. Returns
        // null when no cluster exists for that Id. Throws a COMException whose
        // HResult is HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) when the host cannot
        // use cluster environments.
        static CoreWebView2ClusterEnvironmentOptions GetClusterEnvironmentOptions(
            String id);
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
DLL and fail to attach cleanly to the running cluster. It is therefore the developer's
responsibility to ensure every host that shares a cluster resolves the same runtime,
ideally by not setting loader overrides for these apps, or by setting them identically
across all cooperating hosts.
