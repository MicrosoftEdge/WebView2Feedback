Shared WebView2 Cluster Environment
===

# Background

Today an application gets a WebView2 by calling
[`CreateCoreWebView2EnvironmentWithOptions`](https://learn.microsoft.com/microsoft-edge/webview2/reference/win32/webview2-idl#createcorewebview2environmentwithoptions)
and passing a `UserDataFolder` (UDF). Two hosts that pass the *same* UDF already
share a single browser process tree, which is how multiple WebView2 hosts save
memory today. But that sharing is implicit: it is keyed entirely on the UDF path,
the first launcher silently pins the environment options for everyone else, and a
second host has no way to learn what those pinned options are before it attaches.
If the second host's options disagree with the pinned set, it only finds out after
it has already paid to launch, and the failure surfaces as a generic create error.

We want a first-class, *explicit* way for a set of cooperating host apps (for
example, a shell and the widgets it hosts) to opt into one shared WebView2 browser
process tree — a "cluster" — and to negotiate the shared options up front rather
than by accident.

This spec proposes the **symmetric `Create` + synchronous `Get`** model:

- Every host calls the same symmetric `CreateCoreWebView2ClusterEnvironment` with
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

This spec covers the **public API surface only**; storage, locking, and process
management are implementation details summarized in the Appendix. Two alternative
shapes that were considered (a `Create`/`Join` role split, and a single synchronous
getter keyed on today's UDF) are described in the Appendix for reviewer context.

# Conceptual pages (How To)

_(This is conceptual documentation that will go to learn.microsoft.com "how to" page)_

A **cluster environment** is a WebView2 environment that a group of cooperating
host applications deliberately share, identified by a well-known `Id` string that
those hosts agree on out of band (for example a constant in a shared header). All
hosts that establish a cluster with the same `Id` run inside one browser process
tree and one on-disk user data folder.

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
3. Call `CreateCoreWebView2ClusterEnvironment` with the chosen options. You either
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

    // Step 2 - reuse the pinned set if the cluster already exists, else offer my own.
    wil::com_ptr<ICoreWebView2ClusterEnvironmentOptions> options =
        (hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) ? BuildMyOptions() : pinned;

    // Step 3 - same symmetric create either way: establishes, or attaches to an
    // identical cluster.
    CreateSharedEnvironmentWithOptions(options.get());
}

void AppWindow::CreateSharedEnvironmentWithOptions(
    ICoreWebView2ClusterEnvironmentOptions* options)
{
    CHECK_FAILURE(CreateCoreWebView2ClusterEnvironment(
        options,
        Microsoft::WRL::Callback<ICoreWebView2CreateClusterEnvironmentCompletedHandler>(
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
            await CoreWebView2Environment.CreateClusterEnvironmentAsync(options);
        OnSharedEnvironmentReady(environment);
    }
    catch (COMException ex) when
        (ex.HResult == CoreWebView2ClusterEnvironmentOptions.OptionsMismatchHResult)
    {
        // A live browser pinned a different set since my Get. Re-read and retry, or
        // fall back to a private environment.
        CoreWebView2ClusterEnvironmentOptions authoritative =
            CoreWebView2Environment.GetClusterEnvironmentOptions(ClusterId);
        if (authoritative != null && AcceptableForMe(authoritative))
        {
            CoreWebView2Environment environment =
                await CoreWebView2Environment.CreateClusterEnvironmentAsync(authoritative);
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
/// Establishes, or attaches to, a shared WebView2 cluster environment identified by
/// the `Id` in `options`. This is the symmetric entry point every cooperating host
/// calls with its full desired options.
///
/// The first host to establish a cluster for a given `Id` pins its options
/// (first-creator-wins). A later host attaches when its options equal the pinned
/// set (strict, full-set equality), and the completion handler receives the shared
/// `ICoreWebView2Environment`. A host whose options differ from the pinned set does
/// not attach: the completion handler is invoked with
/// `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` and a null environment; that host
/// should call `GetCoreWebView2ClusterEnvironmentOptions` to read the authoritative
/// set and retry, or create a private (non-shared) environment instead.
///
/// The mapping from `Id` to the on-disk user data folder is a fixed function, so
/// the same `Id` always resolves to the same layout.
STDAPI CreateCoreWebView2ClusterEnvironment(
    [in] ICoreWebView2ClusterEnvironmentOptions* options,
    [in] ICoreWebView2CreateClusterEnvironmentCompletedHandler* handler);

/// Synchronously reads the pinned options for the cluster identified by `id`,
/// without spawning a browser. Use this to pre-flight before calling
/// `CreateCoreWebView2ClusterEnvironment`: read what is already pinned and decide
/// whether to reuse it or offer your own set.
///
/// Returns `S_OK` and the pinned options when a set is pinned for `id`. Returns
/// `HRESULT_FROM_WIN32(ERROR_NOT_FOUND)` and null `options` when nothing is pinned
/// for `id` yet (the caller may create with its own options and become the pinner).
///
/// The value returned is a hint: it can be stale the instant it is read if another
/// host pins a different set concurrently. `CreateCoreWebView2ClusterEnvironment`
/// remains authoritative and validates against the live cluster.
///
/// State: the pinned options are persisted per cluster `Id` in the user data folder
/// resolved from that `Id` (a per-`Id` record). The record survives after the
/// cluster's browser process exits, so `Get` answers whether or not the cluster is
/// currently running. See the Appendix for the full behavior guarantees.
STDAPI GetCoreWebView2ClusterEnvironmentOptions(
    [in] LPCWSTR id,
    [out] ICoreWebView2ClusterEnvironmentOptions** options);

/// The options used to establish or attach to a shared cluster environment. Only
/// options that can be shared process-wide across cooperating hosts are present;
/// process-incompatible options are intentionally omitted.
[uuid(2F3A6D1E-6B9C-4E2A-9A1B-4C0F2D8E7A10), object, pointer_default(unique)]
interface ICoreWebView2ClusterEnvironmentOptions : IUnknown {
  /// The rendezvous name that identifies the cluster. All cooperating hosts agree
  /// on this value out of band. Must not be null or empty.
  [propget] HRESULT Id([out, retval] LPWSTR* id);
  /// Sets the `Id` property.
  [propput] HRESULT Id([in] LPCWSTR id);

  /// Additional command-line switches passed to the shared browser process. Because
  /// the process is shared, this value is part of the pinned set and is process-wide.
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
  /// application (`"<HostName>_<ProfileName>"`) to prevent *accidental* cross-app
  /// profile use. This is anti-misuse, not a security boundary. The name is
  /// deliberately OS-neutral: `<HostName>` is the host application identity on the
  /// current platform (the executable name on Windows).
  [propget] HRESULT PerHostProfileIsolation([out, retval] BOOL* value);
  /// Sets the `PerHostProfileIsolation` property.
  [propput] HRESULT PerHostProfileIsolation([in] BOOL value);

  /// Gets the custom scheme registrations that are part of the pinned set. The
  /// caller must free the returned array and release each element with
  /// `CoTaskMemFree` / `Release`.
  HRESULT GetCustomSchemeRegistrations(
      [out] UINT32* count,
      [out] ICoreWebView2CustomSchemeRegistration*** schemeRegistrations);
  /// Sets the custom scheme registrations that are part of the pinned set.
  HRESULT SetCustomSchemeRegistrations(
      [in] UINT32 count,
      [in] const ICoreWebView2CustomSchemeRegistration** schemeRegistrations);
}

/// Receives the result of `CreateCoreWebView2ClusterEnvironment`.
[uuid(6C4B0A72-1D8E-4F3B-8C2A-5E9D7B1A0C34), object, pointer_default(unique)]
interface ICoreWebView2CreateClusterEnvironmentCompletedHandler : IUnknown {
  /// `errorCode` is:
  ///  * `S_OK` - `environment` is the shared cluster environment (freshly
  ///    established, or attached to an identical running cluster).
  ///  * `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH` - a cluster already exists for
  ///    this `Id` with a different pinned set; `environment` is null. Call
  ///    `GetCoreWebView2ClusterEnvironmentOptions` to read the authoritative set and
  ///    retry, or create a private environment.
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
and returns `null` when nothing is pinned (rather than throwing), matching the
`ERROR_NOT_FOUND` case of the COM API.

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

        // HRESULT of the options-mismatch failure, for callers that catch
        // COMException from CreateClusterEnvironmentAsync.
        static Int32 OptionsMismatchHResult { get; };
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        // Establishes, or attaches to, the shared cluster identified by
        // options.Id. Throws a COMException with HResult == OptionsMismatchHResult
        // when a cluster already exists for that Id with a different pinned set.
        static Windows.Foundation.IAsyncOperation<CoreWebView2Environment>
            CreateClusterEnvironmentAsync(CoreWebView2ClusterEnvironmentOptions options);

        // Synchronously reads the pinned options for the cluster id without
        // spawning a browser. Returns null when nothing is pinned for id yet.
        static CoreWebView2ClusterEnvironmentOptions GetClusterEnvironmentOptions(
            String id);
    }
}
```

# Appendix

## Behavior guarantees

The following are the observable guarantees a caller can rely on; the storage and
locking that back them are runtime implementation details.

- **First-creator-wins.** The first host to establish a cluster for an `Id` pins its
  options. A later host with an identical set attaches; a host with a different set
  gets `ERROR_CLUSTER_ENVIRONMENT_OPTIONS_MISMATCH`.
- **`Get` works whether or not the cluster is running.** The pinned set is remembered
  for the `Id` after the cluster's browser exits, so `Get` can answer with no browser
  spawned. `Get` reads configuration, not liveness.
- **The live cluster is authoritative.** `Get` is only a hint and can race; `Create`
  validates against the running cluster, so a stale or absent pinned set is
  self-healing (the next `Create` attaches if options match, or returns
  `OPTIONS_MISMATCH` to re-read and retry). Concurrent creates never observe a
  partially-established cluster or a half-written option set. Nothing needs a
  background sweep.

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

## Why these options are process-wide

`ICoreWebView2ClusterEnvironmentOptions` deliberately excludes options that cannot
hold a single value across a shared process tree. Some flags (for example the
remote-debugging port or logging) are process-wide and can hold only one value, so
in a cluster they are pinned by the first creator and are not per host. A model for
per-app overrides inside a shared cluster is an open question (below).

## API-shape decisions for reviewers

**New options type vs. extending `ICoreWebView2EnvironmentOptions`.** This spec adds
a *new* `ICoreWebView2ClusterEnvironmentOptions` rather than reusing or extending the
existing `ICoreWebView2EnvironmentOptions`. The tradeoff:

- *New type (chosen).* Lets the surface expose *only* the options that are valid to
  share process-wide, plus the cluster `Id`. Options that cannot hold a single value
  across a shared process (see above) simply do not exist on the type, so a host
  cannot set something that would silently be ignored. Cost: a parallel type that
  duplicates several members already present on `ICoreWebView2EnvironmentOptions`,
  and a small ongoing burden to keep the shared subset in sync as the existing
  options type grows.
- *Extend the existing type.* Would avoid duplication and let hosts reuse option-
  building code (the getter-only alternative B does exactly this). Cost: the existing
  type carries members that are meaningless or unsafe when shared, so the API would
  have to document per-member "ignored in a cluster" behavior instead of omitting it.

Reviewers should confirm the "omit what can't be shared" goal is worth the duplication
before this is locked in; if not, the fallback is to accept an
`ICoreWebView2EnvironmentOptions` plus a separate `Id` parameter.

**How the mismatch surfaces in .NET/WinRT.** This spec projects the mismatch as a
`COMException` whose `HResult` equals a static `OptionsMismatchHResult`, which is
functional but not idiomatic for WinRT (callers must compare an HRESULT in a `catch`
filter). An alternative worth considering is returning a result object or status
enum from `CreateClusterEnvironmentAsync` (for example a
`CoreWebView2ClusterEnvironmentCreateResult` with `Environment` and a `Status` of
`Succeeded` / `OptionsMismatch`), so the mismatch is a normal return value rather
than an exception. The COM handler already models this as a non-fault HRESULT, so
either projection is possible.

## Open questions

- **Get semantics when not running.** Whether `Get` should return the pinned options
  only while the cluster is running, or also when it is configured but not running.
  This spec recommends the latter (forward-stable record) so `Get` can answer with
  no browser spawned.
- **Stronger profile-data security.** Real isolation (encryption with an app key, or
  an OS-defined ACL) is out of scope; today `PerHostProfileIsolation` is anti-misuse
  only and profile data in RAM is unencrypted.
- **Renderer-process sharing across apps.** Under memory pressure the browser can
  reduce site isolation and two hosts could share a renderer. Enterprise/vendor
  renderers should be explicitly blocked from sharing.
- **Per-app overrides in a shared cluster.** Process-wide flags can hold only one
  value, so an override becomes per *cluster*, not per app; a per-app customization
  model is unresolved.
- **Coordinated option changes and shutdown.** Apps update on different timelines, so
  a ready-to-restart or voting mechanism may be needed to apply an option change or
  an upgrade consistently across a cluster. Today an option change lands on the next
  app update or restart, and coordinating it is the apps' responsibility.
- **Strict full-set equality is coarse.** An extensions-on vs extensions-off nuance
  fails equality for both hosts; a finer compatibility model may be wanted later.
