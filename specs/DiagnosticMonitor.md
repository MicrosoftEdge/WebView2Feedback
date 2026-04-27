Diagnostic Monitor API
===

# Background

WebView2 host applications today lack a unified way to observe
diagnostic signals — such as network failures — across all WebView
instances and profiles within an environment. Existing APIs such as
`ServerCertificateErrorDetected` are per-WebView or per-profile,
interactive (they expect a response), and each has its own event
shape.

The Diagnostic Monitor API introduces an observation-only monitor
object that delivers diagnostic signals from all layers — WebView,
Profile, and Environment — through a single `DiagnosticReceived`
event. Host apps create a monitor from the environment and opt in
per category using `AddDiagnosticReceivedFilter`.


# Description

You create an `ICoreWebView2DiagnosticMonitor` from the environment
using `CreateDiagnosticMonitor`. The monitor observes diagnostic
signals across all WebViews, profiles, and the environment itself.
You control which categories of events are delivered by calling
`AddDiagnosticReceivedFilter` with a category and an optional JSON
filter string.

Key scenarios:

* **Telemetry** — subscribe to all network errors and forward the
  JSON details to your telemetry backend.
* **Targeted monitoring** — filter to specific error codes, HTTP
  methods, or profile names using the JSON filter.
* **Multiple consumers** — create separate monitors for telemetry
  and a debug panel, each with independent filters.

The monitor is active from creation until it is released. Releasing
the monitor stops all events and clears all filters automatically.


# Examples

## Subscribe to diagnostic events

### Win32 C++

The following example creates a `DiagnosticMonitor`, adds a filter
for network errors, and subscribes to the `DiagnosticReceived`
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
        ICoreWebView2DiagnosticEventArgs* args);

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

    // Add a filter for NETWORK_ERROR. Pass "{}" to receive
    // all network errors without field-level filtering.
    CHECK_FAILURE(
        m_monitor->AddDiagnosticReceivedFilter(
            COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_ERROR,
            L"{}"));

    // Subscribe to the diagnostic event.
    CHECK_FAILURE(m_monitor->add_DiagnosticReceived(
        Microsoft::WRL::Callback<
            ICoreWebView2DiagnosticReceivedEventHandler>(
            [this](
                ICoreWebView2DiagnosticMonitor* sender,
                ICoreWebView2DiagnosticEventArgs* args)
                -> HRESULT
            {
                HandleDiagnosticEvent(args);
                return S_OK;
            })
            .Get(),
        &m_diagnosticToken));
}

void DiagnosticComponent::HandleDiagnosticEvent(
    ICoreWebView2DiagnosticEventArgs* args)
{
    COREWEBVIEW2_DIAGNOSTIC_CATEGORY category;
    CHECK_FAILURE(args->get_Category(&category));

    COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE scope;
    CHECK_FAILURE(args->get_Scope(&scope));

    wil::unique_cotaskmem_string detailsJson;
    CHECK_FAILURE(args->GetCategoryDetailsAsJson(
        category, &detailsJson));

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

        // Add a filter for NetworkError. Pass "{}" to
        // receive all network errors without field-level
        // filtering.
        _monitor.AddDiagnosticReceivedFilter(
            CoreWebView2DiagnosticCategory.NetworkError,
            "{}");

        // Subscribe to the diagnostic event.
        _monitor.DiagnosticReceived +=
            OnDiagnosticReceived;
    }

    private void OnDiagnosticReceived(
        CoreWebView2DiagnosticMonitor sender,
        CoreWebView2DiagnosticEventArgs args)
    {
        CoreWebView2DiagnosticCategory category =
            args.Category;
        CoreWebView2DiagnosticSourceScope scope =
            args.Scope;
        long timestamp = args.Timestamp;
        string detailsJson =
            args.GetCategoryDetailsAsJson(category);

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

You can pass a JSON object to `AddDiagnosticReceivedFilter` to
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
    // for GET/POST requests from the "Default" profile.
    CHECK_FAILURE(
        m_monitor->AddDiagnosticReceivedFilter(
            COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_ERROR,
            LR"({
              "profileName": "Default",
              "errorCode": [-105, -7],
              "httpMethod": ["GET", "POST"]
            })"));

    CHECK_FAILURE(m_monitor->add_DiagnosticReceived(
        Microsoft::WRL::Callback<
            ICoreWebView2DiagnosticReceivedEventHandler>(
            [this](
                ICoreWebView2DiagnosticMonitor* sender,
                ICoreWebView2DiagnosticEventArgs* args)
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
    // (ERR_TIMED_OUT, -7) errors for GET/POST requests
    // from the "Default" profile.
    _monitor.AddDiagnosticReceivedFilter(
        CoreWebView2DiagnosticCategory.NetworkError,
        @"{
            ""profileName"": ""Default"",
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
/// Specifies the category of diagnostic event.
[v1_enum]
typedef enum COREWEBVIEW2_DIAGNOSTIC_CATEGORY {
  /// Network request failure including DNS resolution
  /// errors, TLS handshake failures, connection timeouts,
  /// HTTP error status codes (4xx/5xx), CORS violations,
  /// and mixed-content blocked requests.
  COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_ERROR,
} COREWEBVIEW2_DIAGNOSTIC_CATEGORY;

/// Specifies the scope that originated a diagnostic event.
[v1_enum]
typedef enum COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE {
  /// The diagnostic signal originated from a specific
  /// WebView instance.
  COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE_WEB_VIEW,

  /// The diagnostic signal originated from a profile or
  /// its underlying network context but is not tied to a
  /// specific WebView.
  COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE_PROFILE,

  /// The diagnostic signal originated from the environment
  /// (for example, a browser-wide event that affects all
  /// WebViews).
  COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE_ENVIRONMENT,
} COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE;

/// Event args for the `DiagnosticReceived` event on
/// `ICoreWebView2DiagnosticMonitor`. Each instance
/// represents a single diagnostic signal.
[uuid(A1B2C3D4-E5F6-7890-ABCD-EF1234567890),
 object, pointer_default(unique)]
interface ICoreWebView2DiagnosticEventArgs : IUnknown {
  /// The diagnostic category that this event belongs to.
  [propget] HRESULT Category(
      [out, retval]
          COREWEBVIEW2_DIAGNOSTIC_CATEGORY* value);

  /// The scope that originated this diagnostic signal.
  [propget] HRESULT Scope(
      [out, retval]
          COREWEBVIEW2_DIAGNOSTIC_SOURCE_SCOPE* value);

  /// Monotonic timestamp in microseconds since an
  /// unspecified epoch. You can use this value to order
  /// events but should not convert it to wall-clock time.
  [propget] HRESULT Timestamp(
      [out, retval] INT64* value);

  /// Returns category-specific diagnostic data as a JSON
  /// string for the specified category.
  ///
  /// The `category` parameter must match the value
  /// returned by `get_Category`. If a different category
  /// is passed, the method returns `"{}"`.
  ///
  /// For `COREWEBVIEW2_DIAGNOSTIC_CATEGORY_NETWORK_ERROR`
  /// the JSON schema is:
  /// ```
  /// {
  ///   "errorCode": -105,
  ///   "statusCode": 404,
  ///   "httpMethod": "GET",
  ///   "elapsedTime": 1234,
  ///   "protocol": "https",
  ///   "uri": "https://www.contoso.com/api/data"
  /// }
  /// ```
  ///
  /// `errorCode` is the Chromium net error code (integer).
  /// `statusCode` is the HTTP response status code
  /// (integer, 0 if no response was received).
  /// `httpMethod` is the HTTP method string.
  /// `elapsedTime` is the request duration in
  /// milliseconds (integer).
  /// `protocol` is the protocol scheme (e.g. "https").
  /// `uri` is the request URI.
  ///
  /// For categories that the runtime does not yet populate,
  /// this method returns `"{}"`.
  ///
  /// Free the returned string with `CoTaskMemFree`.
  HRESULT GetCategoryDetailsAsJson(
      [in] COREWEBVIEW2_DIAGNOSTIC_CATEGORY category,
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
      [in] ICoreWebView2DiagnosticEventArgs* args);
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
[uuid(E4F5A6B7-C8D9-0123-ABCD-456789012345),
 object, pointer_default(unique)]
interface ICoreWebView2DiagnosticMonitor : IUnknown {

  /// Adds a diagnostic filter for the specified category.
  /// After this call, `DiagnosticReceived` will fire for
  /// events in this category that match the JSON criteria.
  ///
  /// Pass `"{}"` or an empty string as `jsonFilter` to
  /// receive all events in the category without
  /// field-level filtering.
  ///
  /// Pass a JSON object to apply field-level filtering.
  /// The object's keys are detail field names.
  /// `profileName` is a single string value; all other
  /// fields are arrays of accepted values.
  ///
  /// Example for `NETWORK_ERROR`:
  /// ```
  /// {
  ///   "profileName": "Default",
  ///   "errorCode": [-105, -7],
  ///   "statusCode": [404, 500],
  ///   "uriPattern": ["https://*.contoso.com/*"],
  ///   "httpMethod": ["GET", "POST"]
  /// }
  /// ```
  ///
  /// `profileName` is a single string that must match
  /// the profile name exactly. All other fields are
  /// arrays of accepted values. An event passes if it
  /// matches any value in each specified field
  /// (OR within a field, AND across fields). String
  /// fields in `uriPattern` support wildcard patterns
  /// using `*` and `?`.
  ///
  /// Calling this method again for the same category
  /// replaces the previous filter for that category.
  ///
  /// Returns `E_INVALIDARG` if the JSON is malformed.
  /// On failure, the filter state is unchanged.
  HRESULT AddDiagnosticReceivedFilter(
      [in] COREWEBVIEW2_DIAGNOSTIC_CATEGORY category,
      [in] LPCWSTR jsonFilter);

  /// Removes the diagnostic filter for the specified
  /// category. After this call, `DiagnosticReceived`
  /// will no longer fire for events in this category.
  ///
  /// If no filter was previously added for the category,
  /// this method is a no-op and returns `S_OK`.
  HRESULT RemoveDiagnosticReceivedFilter(
      [in] COREWEBVIEW2_DIAGNOSTIC_CATEGORY category);

  /// Subscribes to diagnostic events on this monitor.
  /// The handler is invoked on the thread that created
  /// the environment. It fires every time a diagnostic
  /// signal passes a filter added with
  /// `AddDiagnosticReceivedFilter`.
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
  /// until a filter is added via
  /// `AddDiagnosticReceivedFilter`.
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
    /// Specifies the category of diagnostic event.
    enum CoreWebView2DiagnosticCategory
    {
        /// Network request failure (DNS, TLS, timeout,
        /// HTTP error, CORS, mixed content).
        NetworkError = 0,
    };

    /// Specifies the scope that originated a diagnostic
    /// event.
    enum CoreWebView2DiagnosticSourceScope
    {
        /// Signal from a specific WebView instance.
        WebView = 0,

        /// Signal from a profile.
        Profile = 1,

        /// Signal from the environment.
        Environment = 2,
    };

    /// Event args for the DiagnosticReceived event.
    runtimeclass CoreWebView2DiagnosticEventArgs
    {
        CoreWebView2DiagnosticCategory Category { get; };
        CoreWebView2DiagnosticSourceScope Scope { get; };
        Int64 Timestamp { get; };

        /// Returns category-specific data as a JSON
        /// string. Returns "{}" for unrecognized
        /// categories.
        String GetCategoryDetailsAsJson(
            CoreWebView2DiagnosticCategory category);
    }

    /// A diagnostic monitor that receives signals from
    /// all layers. Implements IClosable for deterministic
    /// cleanup.
    runtimeclass CoreWebView2DiagnosticMonitor
        : Windows.Foundation.IClosable
    {
        void AddDiagnosticReceivedFilter(
            CoreWebView2DiagnosticCategory category,
            String jsonFilter);

        void RemoveDiagnosticReceivedFilter(
            CoreWebView2DiagnosticCategory category);

        event Windows.Foundation.TypedEventHandler<
            CoreWebView2DiagnosticMonitor,
            CoreWebView2DiagnosticEventArgs>
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
