Diagnostic Monitor API
===

# Background

WebView2 host applications are deployed in diverse environments, 
which can occasionally expose issues that cannot be recovered 
from—or even diagnosed—through normal in-app error paths. In 
addition, certain internal code paths do not expose errors through 
the public API by design. When these issues accumulate and lead to 
failure, the only recourse is access to detailed diagnostic information 
from the affected WebView2 instance. However, host applications 
currently have no way to collect this additional logging data.

The Diagnostic Monitor API addresses this gap. It provides a **logging** 
surface that allows a host application to opt in—typically via an external 
trigger such as a registry key or environment setting—to collect detailed 
diagnostic information from a specific instance when needed. This API is 
complementary to standard error handling and is **not** intended to serve as 
a general-purpose error-handling mechanism.

# Description

`ICoreWebView2DiagnosticMonitor` is created from the environment
via `ICoreWebView2Environment17::CreateDiagnosticMonitor`. The
monitor is strictly for **logging**: it reports diagnostic
signals through a single `DiagnosticReceived` event. The host app
cannot intercept, modify, or respond to a signal, and the event
has no deferral mechanism. The API is intended for capturing
diagnostic data on demand for offline analysis, not for driving
runtime decisions.

A monitor captures diagnostic signals from all WebViews,
profiles, and the environment itself. The host app selects which
categories of events are delivered by calling
`SetDiagnosticFilter` with a category and a JSON filter string.
A newly created monitor delivers no events until at least one
filter is set, so a monitor remains inert until the host app
explicitly turns it on — for example, in response to an external
diagnostic trigger targeting a specific deployment.

The API is **JSON-in / JSON-out by design**. Filters are JSON
objects whose schema is defined per category. Diagnostic details
are returned as JSON strings whose schema is also defined per
category, with a set of guaranteed fields. The runtime may
include additional key-value pairs beyond the documented set, so
consumers must ignore unknown keys and must not treat the
documented schema as exhaustive. This JSON-in / JSON-out shape
allows new categories and fields to ship without breaking the API
contract or requiring host-app updates, so that the API can
collect diagnostic data from deployments already in the field.

Typical scenarios:

* **Targeted field diagnostics** — the host app turns the
  monitor on for a specific non-functioning deployment in
  response to an external trigger, captures detailed diagnostic
  data, and turns it back off.
* **Telemetry** — the host app subscribes to a category and
  forwards the JSON details to a telemetry backend.
* **Multiple consumers** — separate monitors run independently
  for a diagnostic capture session and a debug panel, each with
  its own filters.

A monitor is active from creation until it is released or
closed via `Close`. Either action stops all events and clears
all filters automatically.


# Examples

## Subscribe to diagnostic events

### Win32 C++

The following example creates a `DiagnosticMonitor`, adds a filter
for network requests, and subscribes to the `DiagnosticReceived`
event.

```cpp
class DiagnosticComponent
{
public:
    DiagnosticComponent(
        wil::com_ptr<ICoreWebView2Environment> environment);
    ~DiagnosticComponent();

private:
    void SetupDiagnostics();
    void HandleDiagnosticEvent(
        ICoreWebView2DiagnosticReceivedEventArgs* args);

    wil::com_ptr<ICoreWebView2Environment17> m_environment;
    wil::com_ptr<ICoreWebView2DiagnosticMonitor> m_monitor;
    EventRegistrationToken m_diagnosticToken = {};
};
```

```cpp
DiagnosticComponent::DiagnosticComponent(
    wil::com_ptr<ICoreWebView2Environment> environment)
{
    CHECK_FAILURE(environment->QueryInterface(
        IID_PPV_ARGS(&m_environment)));
    SetupDiagnostics();
}

DiagnosticComponent::~DiagnosticComponent()
{
    if (m_monitor)
    {
        // Unsubscribe before releasing the monitor to
        // ensure no callbacks arrive during teardown.
        m_monitor->remove_DiagnosticReceived(
            m_diagnosticToken);
        m_monitor.Reset();
    }
}

void DiagnosticComponent::SetupDiagnostics()
{
    // Create a diagnostic monitor from the environment.
    CHECK_FAILURE(
        m_environment->CreateDiagnosticMonitor(&m_monitor));

    // Add a filter for NETWORK_REQUEST. Pass "{}" to
    // receive all network requests without field-level
    // filtering.
    CHECK_FAILURE(
        m_monitor->SetDiagnosticFilter(
            COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_REQUEST,
            L"{}"));

    // Subscribe to the diagnostic event.
    CHECK_FAILURE(m_monitor->add_DiagnosticReceived(
        Microsoft::WRL::Callback<
            ICoreWebView2DiagnosticReceivedEventHandler>(
            [this](
                ICoreWebView2DiagnosticMonitor* sender,
                ICoreWebView2DiagnosticReceivedEventArgs* args)
                -> HRESULT
            {
                HandleDiagnosticEvent(args);
                return S_OK;
            })
            .Get(),
        &m_diagnosticToken));
}

void DiagnosticComponent::HandleDiagnosticEvent(
    ICoreWebView2DiagnosticReceivedEventArgs* args)
{
    COREWEBVIEW2_DIAGNOSTIC_CATEGORY category;
    CHECK_FAILURE(args->get_Category(&category));

    COREWEBVIEW2_DIAGNOSTIC_SCOPE scope;
    CHECK_FAILURE(args->get_Scope(&scope));

    wil::unique_cotaskmem_string detailsJson;
    CHECK_FAILURE(args->get_DetailsAsJson(&detailsJson));

    INT64 timestamp = 0;
    CHECK_FAILURE(args->get_Timestamp(&timestamp));

    std::wstringstream log;
    log << L"[Diagnostic] category=" << category
        << L" scope=" << scope
        << L" ts=" << timestamp
        << L" details=" << detailsJson.get();

    OutputDebugStringW(log.str().c_str());
}
```

### .NET, WinRT

```c#
using Microsoft.Web.WebView2.Core;
using System;
using System.Diagnostics;

public class DiagnosticComponent : IDisposable
{
    private CoreWebView2DiagnosticMonitor _monitor;

    public DiagnosticComponent(
        CoreWebView2Environment environment)
    {
        // Create a diagnostic monitor.
        _monitor = environment.CreateDiagnosticMonitor();

        // Add a filter for NetworkRequest. Pass "{}" to
        // receive all network requests without
        // field-level filtering.
        _monitor.SetDiagnosticFilter(
            CoreWebView2DiagnosticCategory.NetworkRequest,
            "{}");

        // Subscribe to the diagnostic event.
        _monitor.DiagnosticReceived +=
            OnDiagnosticReceived;
    }

    private void OnDiagnosticReceived(
        CoreWebView2DiagnosticMonitor sender,
        CoreWebView2DiagnosticReceivedEventArgs args)
    {
        CoreWebView2DiagnosticCategory category =
            args.Category;
        CoreWebView2DiagnosticScope scope =
            args.Scope;
        long timestamp = args.Timestamp;
        string detailsJson =
            args.DetailsAsJson;

        Debug.WriteLine(
            $"[Diagnostic] category={category} " +
            $"scope={scope} ts={timestamp} " +
            $"details={detailsJson}");
    }

    public void Dispose()
    {
        if (_monitor != null)
        {
            // Unsubscribe before disposing the monitor.
            _monitor.DiagnosticReceived -=
                OnDiagnosticReceived;
            _monitor.Dispose();
            _monitor = null;
        }
    }
}
```

## Filter with field-level JSON criteria

You can pass a JSON object to `SetDiagnosticFilter` to
restrict which events are delivered. An empty JSON object `"{}"` receives
all events in that category. A non-empty JSON object applies field-level
matching. Calling the method again for the same category replaces
the previous filter.

### Win32 C++

```cpp
void DiagnosticComponent::SetupFilteredDiagnostics()
{
    CHECK_FAILURE(
        m_environment->CreateDiagnosticMonitor(&m_monitor));

    // Only receive DNS (ERR_NAME_NOT_RESOLVED, -105)
    // and timeout (ERR_TIMED_OUT, -7) errors
    // for GET/POST requests.
    CHECK_FAILURE(
        m_monitor->SetDiagnosticFilter(
            COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_REQUEST,
            LR"({
              "errorCode": [-105, -7],
              "httpMethod": ["GET", "POST"]
            })"));

    CHECK_FAILURE(m_monitor->add_DiagnosticReceived(
        Microsoft::WRL::Callback<
            ICoreWebView2DiagnosticReceivedEventHandler>(
            [this](
                ICoreWebView2DiagnosticMonitor* sender,
                ICoreWebView2DiagnosticReceivedEventArgs* args)
                -> HRESULT
            {
                HandleDiagnosticEvent(args);
                return S_OK;
            })
            .Get(),
        &m_diagnosticToken));
}
```

### .NET, WinRT

```c#
private CoreWebView2Environment _environment;

private void SetupFilteredDiagnostics()
{
    _monitor = _environment.CreateDiagnosticMonitor();

    // Only DNS (ERR_NAME_NOT_RESOLVED, -105) and timeout
    // (ERR_TIMED_OUT, -7) errors for GET/POST requests.
    _monitor.SetDiagnosticFilter(
        CoreWebView2DiagnosticCategory.NetworkRequest,
        @"{
            ""errorCode"": [-105, -7],
            ""httpMethod"": [""GET"", ""POST""]
        }");

    _monitor.DiagnosticReceived +=
        OnDiagnosticReceived;
}
```


# API Details

## Win32 C++

```idl
/// Specifies the category of diagnostic event. Each value
/// defines its own JSON schemas for the filter accepted by
/// `ICoreWebView2DiagnosticMonitor::SetDiagnosticFilter`
/// and for the details returned by
/// `ICoreWebView2DiagnosticReceivedEventArgs::DetailsAsJson`.
[v1_enum]
typedef enum COREWEBVIEW2_DIAGNOSTIC_CATEGORY {
  /// Network request lifecycle signal. Fires once per
  /// network request issued by any `CoreWebView2` created
  /// from this environment, after the request completes —
  /// including top-level navigations, sub-resource loads,
  /// `fetch`/`XHR`, dedicated and shared worker requests,
  /// and service-worker requests associated with one of
  /// those WebViews. Does not include requests from other
  /// host applications sharing the same user data folder,
  /// nor CSP violation reports.
  ///
  /// **Filter schema** (accepted by `SetDiagnosticFilter`):
  /// Each key maps to an array of accepted values. An event
  /// passes if it matches any value in each specified field
  /// (OR within a field, AND across fields). `uriPattern`
  /// supports `*` and `?` wildcards.
  /// ```
  /// {
  ///   "errorCode":  [-105, -7],
  ///   "statusCode": [404, 500],
  ///   "uriPattern": ["https://*.contoso.com/*"],
  ///   "httpMethod": ["GET", "POST"]
  /// }
  /// ```
  ///
  /// **Details schema** (returned by `DetailsAsJson`):
  /// ```
  /// {
  ///   "errorCode":   -105,
  ///   "statusCode":  404,
  ///   "httpMethod":  "GET",
  ///   "elapsedTime": 1234,
  ///   "scheme":      "https",
  ///   "uri":         "https://www.contoso.com/api/data"
  /// }
  /// ```
  /// `errorCode` is the Chromium net error code (`0` =
  /// success, non-zero = failure). The complete,
  /// authoritative list of values is defined in
  /// [net_error_list.h](https://source.chromium.org/chromium/chromium/src/+/main:net/base/net_error_list.h).
  /// Values are stable across releases; new error codes may
  /// be added over time, so consumers should treat unknown
  /// codes as generic failures.
  /// `statusCode` is the HTTP response status code (0 if
  /// no response was received).
  /// `httpMethod` is the HTTP method string.
  /// `elapsedTime` is the request duration in milliseconds.
  /// `scheme` is the URI scheme (for example, "https").
  /// `uri` is the request URI.
  ///
  /// The runtime may include additional key-value pairs
  /// beyond those listed above. Consumers should ignore
  /// unknown keys.
  COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_REQUEST,
} COREWEBVIEW2_DIAGNOSTIC_CATEGORY;

/// Specifies the scope that originated a diagnostic event.
[v1_enum]
typedef enum COREWEBVIEW2_DIAGNOSTIC_SCOPE {
  /// The diagnostic signal originated from a specific
  /// WebView instance.
  COREWEBVIEW2_DIAGNOSTIC_SCOPE_WEBVIEW,

  /// The diagnostic signal originated from a profile
  /// but is not tied to a specific WebView.
  COREWEBVIEW2_DIAGNOSTIC_SCOPE_PROFILE,

  /// The diagnostic signal originated from the environment
  /// (for example, a browser-wide event that affects all
  /// WebViews).
  COREWEBVIEW2_DIAGNOSTIC_SCOPE_ENVIRONMENT,
} COREWEBVIEW2_DIAGNOSTIC_SCOPE;

/// Event args for the `DiagnosticReceived` event on
/// `ICoreWebView2DiagnosticMonitor`. Each instance
/// represents a single diagnostic signal.
[uuid(A1B2C3D4-E5F6-7890-ABCD-EF1234567890),
 object, pointer_default(unique)]
interface ICoreWebView2DiagnosticReceivedEventArgs : IUnknown {
  /// The diagnostic category that this event belongs to.
  [propget] HRESULT Category(
      [out, retval]
          COREWEBVIEW2_DIAGNOSTIC_CATEGORY* value);

  /// The scope that originated this diagnostic signal.
  [propget] HRESULT Scope(
      [out, retval]
          COREWEBVIEW2_DIAGNOSTIC_SCOPE* value);

  /// The wall-clock time at which the runtime observed this
  /// diagnostic event, as the number of seconds since the
  /// UNIX epoch (1970-01-01T00:00:00Z, UTC). Use this value
  /// to correlate diagnostic events with other timestamped
  /// telemetry. The value is derived from the system clock
  /// and may be affected by clock adjustments (for example,
  /// NTP).
  [propget] HRESULT Timestamp(
      [out, retval] double* value);

  /// Returns category-specific diagnostic data as a JSON
  /// string. The schema for each category is documented on
  /// the corresponding `COREWEBVIEW2_DIAGNOSTIC_CATEGORY`
  /// enum value.
  ///
  /// The runtime may include additional key-value pairs
  /// beyond the documented fields. Consumers should ignore
  /// unknown keys.
  ///
  /// Free the returned string with `CoTaskMemFree`.
  [propget] HRESULT DetailsAsJson(
      [out, retval] LPWSTR* value);
}

/// Receives `DiagnosticReceived` events from
/// `ICoreWebView2DiagnosticMonitor`.
[uuid(C3D4E5F6-A7B8-9012-CDEF-123456789012),
 object, pointer_default(unique)]
interface ICoreWebView2DiagnosticReceivedEventHandler
    : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2DiagnosticMonitor* sender,
      [in] ICoreWebView2DiagnosticReceivedEventArgs* args);
}

/// A diagnostic monitor that receives diagnostic signals
/// from all layers — WebView, Profile, and Environment.
///
/// Created via
/// `ICoreWebView2Environment17::CreateDiagnosticMonitor`.
/// Each monitor has its own filters and event handlers,
/// allowing multiple independent consumers (for example,
/// one for telemetry, one for a debug panel).
///
/// The monitor is active from creation until it is
/// released. Releasing the monitor automatically stops all
/// events and clears all filters.
///
/// All members of this interface must be called on the
/// same thread that created the
/// `ICoreWebView2Environment`. Calling from a different
/// thread returns `RPC_E_WRONG_THREAD`. Handlers must
/// not block this thread.
[uuid(E4F5A6B7-C8D9-0123-ABCD-456789012345),
 object, pointer_default(unique)]
interface ICoreWebView2DiagnosticMonitor : IUnknown {

  /// Sets a diagnostic filter for the specified category.
  /// After this call, `DiagnosticReceived` will fire for
  /// events in this category that match the JSON criteria.
  ///
  /// The filter JSON schema is category-specific and is
  /// documented on the corresponding
  /// `COREWEBVIEW2_DIAGNOSTIC_CATEGORY` enum value.
  ///
  /// Pass `"{}"` or an empty string as `jsonFilter` to
  /// receive all events in the category without
  /// field-level filtering.
  ///
  /// Calling this method again for the same category
  /// replaces the previous filter for that category.
  ///
  /// Returns `E_INVALIDARG` if the JSON is malformed or
  /// does not match the category's filter schema. On
  /// failure, the filter state is unchanged.
  HRESULT SetDiagnosticFilter(
      [in] COREWEBVIEW2_DIAGNOSTIC_CATEGORY category,
      [in] LPCWSTR jsonFilter);

  /// Removes the diagnostic filter for the specified
  /// category. After this call, `DiagnosticReceived`
  /// will no longer fire for events in this category.
  ///
  /// If no filter was previously set for the category,
  /// this method is a no-op and returns `S_OK`.
  HRESULT RemoveDiagnosticFilter(
      [in] COREWEBVIEW2_DIAGNOSTIC_CATEGORY category);

  /// Subscribes to diagnostic events on this monitor.
  /// The handler is invoked on the thread that created
  /// the environment. It fires every time a diagnostic
  /// signal passes a filter set with
  /// `SetDiagnosticFilter`.
  ///
  /// Multiple handlers can be registered. They are
  /// invoked in registration order.
  HRESULT add_DiagnosticReceived(
      [in] ICoreWebView2DiagnosticReceivedEventHandler*
          eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes a handler previously added with
  /// `add_DiagnosticReceived`.
  HRESULT remove_DiagnosticReceived(
      [in] EventRegistrationToken token);

  /// Release the diagnostic subscription and any registered
  /// handlers. The application should call this API when no
  /// access to the monitor is needed any more, to ensure
  /// that the underlying resources are released timely even
  /// if the monitor object itself is not released due to
  /// some leaked reference.
  HRESULT Close();
}

interface ICoreWebView2Environment17
    : ICoreWebView2Environment16 {

  /// Creates a new diagnostic monitor. The monitor
  /// receives diagnostic signals from all layers —
  /// WebView, Profile, and Environment — that match its
  /// filters.
  ///
  /// Multiple monitors can coexist, each with its own
  /// filters and event handlers. This enables independent
  /// consumers such as a telemetry pipeline and a debug
  /// panel to operate without interfering with each other.
  ///
  /// The monitor is active immediately, but no events fire
  /// until a filter is set via
  /// `SetDiagnosticFilter`.
  ///
  /// Release the monitor to stop receiving events and
  /// free resources.
  HRESULT CreateDiagnosticMonitor(
      [out, retval]
          ICoreWebView2DiagnosticMonitor** value);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    /// Specifies the category of diagnostic event. Each
    /// value defines its own JSON schemas for the filter
    /// accepted by SetDiagnosticFilter and for the details
    /// returned by DetailsAsJson.
    enum CoreWebView2DiagnosticCategory
    {
        /// Network request lifecycle signal. Fires once
        /// per network request issued by any CoreWebView2
        /// created from this environment, after the request
        /// completes — including top-level navigations,
        /// sub-resource loads, fetch/XHR, dedicated and
        /// shared worker requests, and service-worker
        /// requests associated with one of those WebViews.
        /// Does not include requests from other host
        /// applications sharing the same user data folder,
        /// nor CSP violation reports.
        ///
        /// Filter schema (accepted by SetDiagnosticFilter).
        /// Each key maps to an array of accepted values.
        /// An event passes if it matches any value in each
        /// specified field (OR within a field, AND across
        /// fields). `uriPattern` supports `*` and `?`
        /// wildcards.
        /// {
        ///   "errorCode":  [-105, -7],
        ///   "statusCode": [404, 500],
        ///   "uriPattern": ["https://*.contoso.com/*"],
        ///   "httpMethod": ["GET", "POST"]
        /// }
        ///
        /// Details schema (returned by DetailsAsJson).
        /// {
        ///   "errorCode":   -105,
        ///   "statusCode":  404,
        ///   "httpMethod":  "GET",
        ///   "elapsedTime": 1234,
        ///   "scheme":      "https",
        ///   "uri":         "https://www.contoso.com/api/data"
        /// }
        /// `errorCode` is the Chromium net error code
        /// (0 = success, non-zero = failure). The complete,
        /// authoritative list of values is defined in
        /// net_error_list.h. Values are stable across
        /// releases; new error codes may be added over
        /// time, so consumers should treat unknown codes
        /// as generic failures.
        /// `statusCode` is the HTTP response status code
        /// (0 if no response was received).
        /// `httpMethod` is the HTTP method string.
        /// `elapsedTime` is the request duration in
        /// milliseconds.
        /// `scheme` is the URI scheme (for example,
        /// "https").
        /// `uri` is the request URI.
        ///
        /// The runtime may include additional key-value
        /// pairs beyond those listed above. Consumers
        /// should ignore unknown keys.
        NetworkRequest = 0,
    };

    /// Specifies the scope that originated a diagnostic
    /// event.
    enum CoreWebView2DiagnosticScope
    {
        /// Signal from a specific WebView instance.
        WebView = 0,

        /// Signal from a profile.
        Profile = 1,

        /// Signal from the environment.
        Environment = 2,
    };

    /// Event args for the DiagnosticReceived event.
    runtimeclass CoreWebView2DiagnosticReceivedEventArgs
    {
        CoreWebView2DiagnosticCategory Category { get; };
        CoreWebView2DiagnosticScope Scope { get; };
        Windows.Foundation.DateTime Timestamp { get; };

        /// Returns category-specific data as a JSON
        /// string. The schema for each category is
        /// documented on the corresponding
        /// CoreWebView2DiagnosticCategory enum value. The
        /// runtime may include additional key-value pairs
        /// beyond the documented fields; consumers should
        /// ignore unknown keys.
        String DetailsAsJson { get; };
    }

    /// A diagnostic monitor that receives signals from
    /// all layers. Implements IClosable for deterministic
    /// cleanup.
    runtimeclass CoreWebView2DiagnosticMonitor
        : Windows.Foundation.IClosable
    {
        void SetDiagnosticFilter(
            CoreWebView2DiagnosticCategory category,
            String jsonFilter);

        void RemoveDiagnosticFilter(
            CoreWebView2DiagnosticCategory category);

        event Windows.Foundation.TypedEventHandler<
            CoreWebView2DiagnosticMonitor,
            CoreWebView2DiagnosticReceivedEventArgs>
            DiagnosticReceived;
    }

    runtimeclass CoreWebView2Environment
    {
        // ...

        CoreWebView2DiagnosticMonitor
            CreateDiagnosticMonitor();
    }
}
```
