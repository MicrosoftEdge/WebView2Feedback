Shared WebView2 Cluster Environment
===

# Background

Today an application gets a WebView2 by calling
[`CreateCoreWebView2EnvironmentWithOptions`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/webview2-idl#createcorewebview2environmentwithoptions)
and passing a `UserDataFolder` (UDF). Two hosts that pass the *same* UDF already
share a single browser process tree. But that sharing is implicit: it is keyed
entirely on the UDF path,
the first launcher silently pins the environment options for everyone else, and a
second host has no way to learn what those pinned options are before it attaches.
If the second host's options disagree with the pinned set, it only finds out after
it has already paid to launch, and the failure surfaces as a generic create error.

We want a first-class, *explicit* way for a set of cooperating host apps to opt into
one shared WebView2 environment — a "cluster" — and to agree on the shared options up
front.

This spec proposes the **symmetric `Create` + synchronous `Get`** model:

- Every host calls the same symmetric `CreateOrJoinCoreWebView2ClusterEnvironment` with
  its full desired options. The **first** host to establish a cluster with a given
  `Id` pins its options (first-creator-wins). A later host that passes an identical
  set attaches to the running cluster; a host that passes a different set gets a
  typed `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH`.
- A separate **synchronous** `GetCoreWebView2ClusterEnvironmentOptions` reads the
  pinned set back for an `Id` without spawning a browser, so a host can pre-flight:
  read what is already pinned, decide whether it likes it, then create.

Sharing intent is expressed by an `Id` (a stable rendezvous name that all
cooperating hosts agree on). The mapping from `Id` to on-disk UDF path is a fixed
function, so the same `Id` always resolves to the same layout and first-creator-wins
applies to the on-disk layout, not just to the live process.

# Conceptual pages (How To)

A **cluster environment** is a WebView2 environment that a group of cooperating
host applications deliberately share, identified by a well-known `Id` string that
those hosts agree on out of band. All hosts that establish a cluster with the same
`Id` run inside one browser process tree and one on-disk user data folder.

Unlike `CreateCoreWebView2EnvironmentWithOptions`, you do **not** pass a user data
folder. The runtime derives the folder from the cluster `Id` through a fixed
mapping, so every host that uses the same `Id` resolves to the same on-disk layout.

The **pinned options** are the `ICoreWebView2ClusterEnvironmentOptions` that the
first host to establish the cluster supplied. Because a browser process tree is a
single process-wide configuration, those options cannot differ per host, so the
first establishing caller's set becomes authoritative for the lifetime of the
cluster. Options that cannot be shared process-wide are intentionally absent from
`ICoreWebView2ClusterEnvironmentOptions`.

The recommended usage pattern is **"Get, then Create"**:

1. Synchronously `GetCoreWebView2ClusterEnvironmentOptions(id)` to see what, if
   anything, is already pinned. This does not launch a browser.
2. If something is pinned, reuse it (attach). If nothing is pinned yet, offer your
   own options (you become the pinner).
3. Call `CreateOrJoinCoreWebView2ClusterEnvironment` with the chosen options. You either
   establish the cluster or attach to an identical one.

`Get` is only a hint: it can race with another host that pins a different set the
instant after you read. The live browser stays authoritative, so `Create` still
validates and returns `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` if you lost the
race, at which point you re-`Get` the now-authoritative options and retry, or fall
back to a private (non-shared) environment.

Profile isolation in a cluster is **anti-misuse, not a security boundary**. The
`PerHostProfileIsolation` option prevents *accidental* cross-app profile use; it
does not encrypt or ACL profile data. Any app that knows the cluster `Id` and
profile name can use a shared profile.

# Examples

## Win32 C++

The example shows the recommended "Get, then Create" flow: read the pinned options
for a well-known cluster id, reuse them if the cluster already exists, otherwise
offer your own; then create (which either establishes the cluster or attaches to an
identical one). On a mismatch, re-read the authoritative options and retry.

```cpp
// A stable rendezvous name that all cooperating hosts agree on (e.g. in a shared header).
constexpr PCWSTR kClusterId = L"Contoso.Shell.Default";

// Build the options this host would like if it turns out to be the first one in.
wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> BuildMyOptions()
{
    auto options = Microsoft::WRL::Make<CoreWebView2ClusterEnvironmentOptions>();
    CHECK_FAILURE(options->put_Id(kClusterId));
    CHECK_FAILURE(options->put_Language(L"en-US"));
    CHECK_FAILURE(options->put_AreBrowserExtensionsEnabled(FALSE));
    return options;
}

void AppWindow::CreateSharedEnvironment()
{
    // Step 1 - synchronously ask what is already pinned for this id. No browser spawn.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> pinned;
    HRESULT hr = GetCoreWebView2ClusterEnvironmentOptions(kClusterId, &pinned);

    // Step 2 - reuse the pinned set if the cluster already exists; offer my own if
    // nothing is pinned yet. Any other failure is a real error.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> options;
    if (SUCCEEDED(hr))
    {
        options = pinned;
    }
    else if (hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND))
    {
        options = BuildMyOptions();
    }
    else
    {
        CHECK_FAILURE(hr);
        return;
    }

    // Step 3 - same symmetric create either way: establishes, or attaches to an
    // identical cluster.
    CreateSharedEnvironmentWithOptions(options.get());
}

void AppWindow::CreateSharedEnvironmentWithOptions(
    ICoreWebView2ClusterEnvironmentOptions* options)
{
    CHECK_FAILURE(CreateOrJoinCoreWebView2ClusterEnvironment(
        options,
        Microsoft::WRL::Callback<ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler>(
            [this](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT
            {
                if (result == HRESULT_FROM_WIN32(ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH))
                {
                    // A live browser pinned a different set since my Get. Re-read the
                    // authoritative options and retry once with them (or go private).
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
                    return S_OK;
                }
                CHECK_FAILURE(result);

                // Established the cluster, or attached to an identical one.
                OnSharedEnvironmentReady(environment);
                return S_OK;
            })
            .Get()));
}
```

## .NET/WinRT

```c#
// A stable rendezvous name that all cooperating hosts agree on.
const string ClusterId = "Contoso.Shell.Default";

// HRESULT_FROM_WIN32(ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH). Matches the value
// thrown as a COMException.HResult when the pinned set differs from ours.
const int OptionsMismatchHResult = unchecked((int)0x8007139F);

CoreWebView2ClusterEnvironmentOptions BuildMyOptions()
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
    // Step 1 - synchronously read the pinned options for this id. No browser spawn.
    // Returns null when nothing is pinned yet.
    CoreWebView2ClusterEnvironmentOptions pinned =
        CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);

    // Step 2 - reuse the pinned set, or offer my own if none exists yet.
    CoreWebView2ClusterEnvironmentOptions options = pinned ?? BuildMyOptions();

    try
    {
        // Step 3 - same symmetric create either way.
        CoreWebView2Environment environment =
            await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(options);
        OnSharedEnvironmentReady(environment);
    }
    catch (COMException ex) when
        // The HRESULT of ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH.
        (ex.HResult == OptionsMismatchHResult)
    {
        // A live browser pinned a different set since my Get. Re-read and retry, or
        // fall back to a private environment.
        CoreWebView2ClusterEnvironmentOptions authoritative =
            CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);
        if (authoritative != null && AcceptableForMe(authoritative))
        {
            CoreWebView2Environment environment =
                await CoreWebView2Environment.CreateOrJoinClusterEnvironmentAsync(authoritative);
            OnSharedEnvironmentReady(environment);
        }
        else
        {
            UsePrivateEnvironment();
        }
    }
}
```

# API Details

## Win32 C++

```
/// Establishes, or attaches to, the shared WebView2 cluster environment identified
/// by the `Id` in `options`. If no cluster exists for the `Id`, this establishes
/// one and the caller's options become the cluster's options. If a cluster already
/// exists and the caller's options match it, the completion handler receives the
/// shared `ICoreWebView2Environment`. If they do not match, the completion handler
/// is invoked with `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` and a null
/// environment.
STDAPI CreateOrJoinCoreWebView2ClusterEnvironment(
    [in] ICoreWebView2ClusterEnvironmentOptions* options,
    [in] ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler* handler);

/// Synchronously reads the options of the cluster identified by `id` without
/// creating or attaching to a cluster. Returns `S_OK` and the cluster's options
/// when a cluster is configured for `id`, or `HRESULT_FROM_WIN32(ERROR_NOT_FOUND)`
/// and null `options` when none is. The options are available whether or not the
/// cluster is currently running.
STDAPI GetCoreWebView2ClusterEnvironmentOptions(
    [in] LPCWSTR id,
    [out] ICoreWebView2ClusterEnvironmentOptions** options);

/// The options used to establish or attach to a shared cluster environment.
interface ICoreWebView2ClusterEnvironmentOptions : IUnknown {
  /// The name that identifies the cluster. All cooperating hosts use the same
  /// value. Must not be null or empty. The `Id` is case-insensitive and must be a
  /// valid file-system folder name; otherwise the call fails with `E_INVALIDARG`.
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

  /// The channel search kind used to locate the WebView2 Runtime.
  [propget] HRESULT ChannelSearchKind(
      [out, retval] COREWEBVIEW2_CHANNEL_SEARCH_KIND* value);
  /// Sets the `ChannelSearchKind` property.
  [propput] HRESULT ChannelSearchKind([in] COREWEBVIEW2_CHANNEL_SEARCH_KIND value);

  /// When TRUE (the default), the effective profile name is namespaced per host
  /// application (`"<HostName>_<ProfileName>"`, where `<HostName>` is the host
  /// executable name on Windows) to prevent accidental cross-app profile use. This
  /// is not a security boundary.
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

/// Receives the result of `CreateOrJoinCoreWebView2ClusterEnvironment`.
interface ICoreWebView2CreateOrJoinClusterEnvironmentCompletedHandler : IUnknown {
  /// `errorCode` is:
  ///  * `S_OK` - `environment` is the shared cluster environment, either freshly
  ///    established or attached to an existing cluster with matching options.
  ///  * `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` - a cluster already exists for
  ///    this `Id` with different options; `environment` is null.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2Environment* environment);
}
```

`ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` is returned as
`HRESULT_FROM_WIN32(ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH)`.

## .NET/WinRT

The two global functions are surfaced as static methods on `CoreWebView2Environment`,
mirroring how `CreateCoreWebView2EnvironmentWithOptions` maps to
`CoreWebView2Environment.CreateAsync`. `GetClusterEnvironmentOptions` is synchronous
and returns `null` when no cluster is configured, matching the `ERROR_NOT_FOUND` case
of the COM API.

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ClusterEnvironmentOptions
    {
        CoreWebView2ClusterEnvironmentOptions();

        String Id { get; set; };
        String AdditionalBrowserArguments { get; set; };
        String Language { get; set; };
        Boolean AllowSingleSignOnUsingOSPrimaryAccount { get; set; };
        Boolean EnableTrackingPrevention { get; set; };
        Boolean AreBrowserExtensionsEnabled { get; set; };
        CoreWebView2ChannelSearchKind ChannelSearchKind { get; set; };
        Boolean PerHostProfileIsolation { get; set; };
        IVector<CoreWebView2CustomSchemeRegistration> CustomSchemeRegistrations { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        // Establishes, or attaches to, the shared cluster identified by
        // options.Id. Throws a COMException whose HResult is
        // HRESULT_FROM_WIN32(ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH) when a
        // cluster already exists for that Id with different options.
        static Windows.Foundation.IAsyncOperation<CoreWebView2Environment>
            CreateOrJoinClusterEnvironmentAsync(CoreWebView2ClusterEnvironmentOptions options);

        // Synchronously reads the options of the cluster identified by id. Returns
        // null when no cluster is configured for id.
        static CoreWebView2ClusterEnvironmentOptions GetClusterEnvironmentOptions(
            String id);
    }
}
```

# Appendix

## Alternatives considered

Two other API shapes were evaluated and rejected in favor of this one.

- **Create / Join role split.** One host `Create`s and pins options; others `Join` by
  name and get the pinned set back. Cleaner asymmetry, but it has a bootstrap race
  (two hosts `Join`ing before anyone `Create`s both get `NOT_FOUND`, needing an extra
  rule). The symmetric model here avoids that because every host runs the same create.
- **One synchronous getter, nothing else.** Keep today's UDF-based sharing and only add
  a `Get` so a joiner can look before it leaps. Smallest surface, but no named
  rendezvous and no lockable "establish" step. This model was chosen because it makes
  sharing explicit; the getter-only shape remains a smaller-surface fallback.

## Relationship to existing options

`ICoreWebView2ClusterEnvironmentOptions` is a new type rather than a reuse of
`ICoreWebView2EnvironmentOptions`. It intentionally exposes only the options that can
hold a single value across a shared browser process tree, plus the cluster `Id`.
Options that cannot be shared process-wide (for example the remote-debugging port or
logging, which the whole process can hold only one of) are omitted, so a host cannot
set something on a cluster that would silently be ignored. The pinned set therefore
belongs to the first creator and is not per host.

