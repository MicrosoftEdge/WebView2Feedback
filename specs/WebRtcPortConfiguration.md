
Port Range Configuration
===

# Background
In webview2 components like WebRTC by default allocates ports dynamically from the system’s ephemeral range.  
In enterprise or testing environments, developers often need deterministic or firewall-friendly port allocation.  

This API enables developers to configure the port range WebRTC uses for [ICE](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols#ice) candidates and media connections.

The initial support is for **UDP**, with room to extend to **TCP** in the future.  

# Conceptual pages (How To)

Developers can use this API to restrict WebRTC’s UDP ports to a specific range which WebRTC uses for ICE candidate and media connections.

ICE stands for **Interactive Connectivity Establishment**. It is a standard method of NAT traversal used in WebRTC. It is defined in [IETF RFC 5245](https://datatracker.ietf.org/doc/html/rfc5245). ICE deals with the process of connecting media through NATs by conducting connectivity checks.  

Common scenarios:  
- Configure ports for **enterprise firewall compliance**.  
- Run **deterministic tests** where ICE candidate ports are predictable.  
- Avoid conflicts with other applications that may already use ephemeral ranges.  

Usage steps:  
1. Create `CoreWebView2EnvironmentOptions`.   
2. Call `SetAllowedPortRange` for `COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT` and `COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP`.
3. Pass the options when creating the WebView2 environment.

# Examples
### C++ Configure UDP Port Range
```cpp
Microsoft::WRL::ComPtr<ICoreWebView2StagingEnvironmentOptions10> optionsStaging10;
if (options.As(&optionsStaging10) == S_OK)
{
    // Configure port ranges for UDP traffic to work within enterprise firewalls
    // Set UDP port range (example: 50000-55000 for enterprise environments)
    const INT32 udpMin = 50000, udpMax = 55000;

    CHECK_FAILURE(optionsStaging10->SetAllowedPortRange(
        COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, udpMin, udpMax));

    // Get the configured port range
    CHECK_FAILURE(optionsStaging10->GetEffectiveAllowedPortRange(
        COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, &m_udpPortRange.minPort,
        &m_udpPortRange.maxPort));
}

HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        subFolder, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get());
```

### C# Configure UDP Port Range
```csharp
var options = CoreWebView2Environment.CreateCoreWebView2EnvironmentOptions();
var optionsStaging10 = options as ICoreWebView2StagingEnvironmentOptions10;
if (optionsStaging10 != null)
{
    // Configure port ranges for UDP traffic to work within enterprise firewalls
    // Set UDP port range (example: 50000-55000 for enterprise environments)
    const int udpMin = 50000, udpMax = 55000;

    optionsStaging10.SetAllowedPortRange(
        COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, udpMin, udpMax);

    // Get the configured port range
    optionsStaging10.GetEffectiveAllowedPortRange(
        COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, out m_udpPortRange.minPort,
        out m_udpPortRange.maxPort);
}

var environment = await CoreWebView2Environment.CreateAsync(
        subFolder, m_userDataFolder, options);
OnCreateEnvironmentCompleted(environment);
```

API Rules and Precedence

1. Port Range Restriction Scope param in SetAllowedPortRange
- A component specific scope (e.g. _WEB_RTC) always takes precedence over _DEFAULT for that component in `SetAllowedPortRange`.
- `_DEFAULT` defines the base port range restrictions for all components without specific overrides.
- Passing `(0, 0)` for a component scope unset its specific range restriction and inherit range restriction from `_DEFAULT`
- If `_DEFAULT` is set and a specific scope is unset, that component inherits `_DEFAULT`.
- Passing `(1025,65535)` for a component scope make port range unrestricted for that component.

| Scope State                                | Behaviour                                                                                     |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- |
| Only `_DEFAULT` is set                           | `_DEFAULT` applies port range restrictions to all components                            |
| `_DEFAULT` and `_WEB_RTC` are both set           | `_WEB_RTC` port range restrictions applies to WebRTC; `_DEFAULT` applies to others      |
| `_WEB_RTC` only is set                           | `_WEB_RTC` applies port range restrictions only to WebRTC; others unrestricted          |
| `_DEFAULT` set and `_WEB_RTC` reset to `(0,0)`   | `_DEFAULT` applies port range restrictions to all and WebRTC inherits `_DEFAULT`        |
| `_DEFAULT` set and `_WEB_RTC` set to `(1025,65535)` | `_DEFAULT` applies port range restrictions to all except WebRTC which is unrestricted   |

2. Port Range Restriction Scope param in GetEffectiveAllowedPortRange
- GetEffectiveAllowedPortRange returns the port range to use for the specified scope.
- If the scope is _DEFAULT or if the specified scope is unset, then the _DEFAULT port range is returned.
- A range of (0, 0) means that no port range has been set.
- Querying `_DEFAULT` only returns `_DEFAULT`; it does not aggregate component-specific settings.
- If neither `_DEFAULT` nor a component-specific scope is set, the default `(0,0)` (unset) is returned.

| `GetEffectiveAllowedPortRange` Scope query                           | Returned Range                |
| -------------------------------------------------------------------- | ----------------------------- |
| Pass `_WEB_RTC` when only `_DEFAULT` is set                          | Returns `_DEFAULT` range      |
| Pass `_WEB_RTC` when `_WEB_RTC` explicitly set                       | Returns `_WEB_RTC` range      |
| Pass `_WEB_RTC` when `_DEFAULT` unset and `_WEB_RTC` unset           | Returns `(0, 0)`              |
| Pass `_WEB_RTC` when `_DEFAULT` set and `_WEB_RTC` reset to `(0, 0)` | Returns `_DEFAULT`            |
| Pass `_DEFAULT` when only `_WEB_RTC` set                             | Returns  `(0,0)`              |

# API Details
### C++  
```
/// Specifies the scope for port configuration.
[v1_enum]
typedef enum COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE {
  /// Scope applies to all components.
  COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_DEFAULT,
  /// Applies only to WebRTC peer-to-peer connection.
  COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE_WEB_RTC,
} COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE;

/// Specifies the network protocol for port configuration.
[v1_enum]
typedef enum COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND {
  /// User Datagram Protocol - fast, connectionless protocol.
  COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP,
} COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND;

/// Additional options used to create WebView2 Environment to manage port range configuration.
[uuid(2c0f597d-2958-5a94-82f9-c750cf86cb88), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironmentOptions10 : IUnknown {
  /// Sets the allowed port range restriction for the specified 
  /// scope and transport protocol.
  /// 
  /// This API enables WebView2 to operate within enterprise network or firewall
  /// restrictions by limiting network communication to a defined port range.
  /// It provides fine-grained control by allowing port restrictions to be applied
  /// per network component scope, such as WebRTC.
  /// 
  /// Currently, only WebRTC UDP Port Range restriction is supported.
  /// 
  /// `minPort` and `maxPort` must be within the range 1025-65535 (inclusive), or must both be the sentinel value 0.
  /// `minPort` must be less than or equal to `maxPort`.
  /// If `minPort` equals `maxPort`, the range represents a single port.
  /// 
  /// Calls with invalid ranges fail with `E_INVALIDARG`.
  ///
  /// A component specific scope (e.g. _WEB_RTC) always takes precedence over _DEFAULT for that component in `SetAllowedPortRange`.
  /// `_DEFAULT` defines the port range restrictions for all components without specific overrides.
  /// Passing `(0, 0)` for a component scope unset its specific range restriction and inherit range restriction from `_DEFAULT`
  /// If `_DEFAULT` is set and a specific scope is unset, that component inherits `_DEFAULT`.
  /// Passing `(1025,65535)` for a component scope make port range unrestricted for that component.

  /// | Scope State                                         | Behaviour                                                                               |
  /// | --------------------------------------------------- | ----------------------------------------------------------------------------------------|
  /// | Only `_DEFAULT` is set                              | `_DEFAULT` applies port range restrictions to all components                            |
  /// | `_DEFAULT` and `_WEB_RTC` are both set              | `_WEB_RTC` port range restrictions applies to WebRTC; `_DEFAULT` applies to others      |
  /// | `_WEB_RTC` only is set                              | `_WEB_RTC` applies port range restrictions only to WebRTC; others unrestricted          |
  /// | `_DEFAULT` set and `_WEB_RTC` reset to `(0,0)`      | `_DEFAULT` applies port range restrictions to all and WebRTC inherits `_DEFAULT`        |
  /// | `_DEFAULT` set and `_WEB_RTC` set to `(1025,65535)` | `_DEFAULT` applies port range restrictions to all except WebRTC which is unrestricted   |

  /// `scope` scope on which restrictions will apply.
  /// `protocol` Transport protocol on which restrictions will apply.
  /// `minPort` The minimum allowed port number (inclusive).
  /// `maxPort` The maximum allowed port number (inclusive).
  /// 
  HRESULT SetAllowedPortRange(
      [in] COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE scope,
      [in] COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND protocol,
      [in] INT32 minPort,
      [in] INT32 maxPort
  );

  /// Retrieves the effective allowed port range for the specified transport protocol.
  /// Returns the effective port range previously set via
  /// `SetAllowedPortRange`.
  ///
  /// GetEffectiveAllowedPortRange returns the port range to use for the specified scope.
  /// If the scope is _DEFAULT or if the specified scope is unset, then the _DEFAULT port range is returned.
  /// A range of (0, 0) means that no port range has been set.
  /// Querying `_DEFAULT` only returns `_DEFAULT`; it does not aggregate component-specific settings.
  /// If neither `_DEFAULT` nor a component-specific scope is set, the default `(0,0)` (unset) is returned.

  /// | `GetEffectiveAllowedPortRange` Scope query                           | Returned Range                |
  /// | -------------------------------------------------------------------- | ----------------------------- |
  /// | Pass `_WEB_RTC` when only `_DEFAULT` is set                          | Returns `_DEFAULT` range      |
  /// | Pass `_WEB_RTC` when `_WEB_RTC` explicitly set                       | Returns `_WEB_RTC` range      |
  /// | Pass `_WEB_RTC` when `_DEFAULT` unset and `_WEB_RTC` unset           | Returns `(0, 0)`              |
  /// | Pass `_WEB_RTC` when `_DEFAULT` set and `_WEB_RTC` reset to `(0, 0)` | Returns `_DEFAULT`            |
  /// | Pass `_DEFAULT` when only `_WEB_RTC` set                             | Returns  `(0,0)`              |

  /// `scope` scope on which restrictions is applied.
  /// `protocol` Transport protocol on which restrictions is applied.
  /// `minPort` Receives the minimum allowed port number (inclusive).
  /// `maxPort` Receives the maximum allowed port number (inclusive).
  /// 
  HRESULT GetEffectiveAllowedPortRange (
      [in] COREWEBVIEW2_ALLOWED_PORT_RANGE_SCOPE scope,
      [in] COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND protocol,
      [out] INT32* minPort,
      [out] INT32* maxPort
  );


}
```

### C#
```csharp
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebview2AllowedPortRangeScope
    {
        Default = 0,
        WebRtc = 1,
    };

    enum CoreWebView2TransportProtocolKind
    {
        Udp = 0,
    };

    runtimeclass CoreWebView2EnvironmentOptions
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingEnvironmentOptions10")]
        {
            // ICoreWebView2StagingEnvironmentOptions10 members
            void SetAllowedPortRange(CoreWebview2AllowedPortRangeScope scope, CoreWebView2TransportProtocolKind protocol, Int32 minPort, Int32 maxPort);
            void GetEffectiveAllowedPortRange(CoreWebview2AllowedPortRangeScope scope, CoreWebView2TransportProtocolKind protocol, out Int32 minPort, out Int32 maxPort);
        }
    }
}
```
