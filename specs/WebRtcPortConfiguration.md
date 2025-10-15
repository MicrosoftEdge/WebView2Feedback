
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
2. Call `SetAllowedPortRange` for `COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL` and `COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP`.
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
        COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, udpMin, udpMax));

    // Get the configured port range
    CHECK_FAILURE(optionsStaging10->GetAllowedPortRange(
        COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL,
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
        COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, udpMin, udpMax);

    // Get the configured port range
    optionsStaging10.GetAllowedPortRange(
        COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL,
        COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP, out m_udpPortRange.minPort,
        out m_udpPortRange.maxPort);
}

var environment = await CoreWebView2Environment.CreateAsync(
        subFolder, m_userDataFolder, options);
OnCreateEnvironmentCompleted(environment);
```

API Rules and Precedence

1. Network Scope param in SetAllowedPortRange
- A network component-specific scope (e.g. _WEB_RTC) always takes precedence over _ALL for that component in `SetAllowedPortRange`.
- `_ALL` defines the port range restrictions for all components without specific overrides.
- Passing `(0, 0)` for a network component scope removes its restriction.
- If `_ALL` is set and a specific scope is reset, that component becomes unrestricted while `_ALL` still applies to others.

| Network Scope State                        | Behaviour                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| Only `_ALL` is set                         | `_ALL` applies port range restrictions to all network components               |
| `_ALL` and `_WEB_RTC` are both set         | `_WEB_RTC` port range restrictions applies to WebRTC; `_ALL` applies to others |
| `_WEB_RTC` only is set                     | `_WEB_RTC` applies port range restrictions only to WebRTC; others unrestricted | 
| `_ALL` set and `_WEB_RTC` reset to `(0,0)` | `_ALL` applies port range restrictions to all except WebRTC (unrestricted)     |

2. Network Scope param in GetAllowedPortRange
- `GetAllowedPortRange` returns the range explicitly set for the queried scope.
- If a specific scope is unset, it inherits `_ALL`.
- Querying `_ALL` only returns `_ALL`; it does not aggregate component-specific settings.
- If neither `_ALL` nor a component-specific scope is set, the default `(0,0)` (unrestricted) is returned.

| `GetAllowedPortRange` Network Scope query                        | Returned Range                |
| ---------------------------------------------------------------- | ----------------------------- |
| Pass `_WEB_RTC` when only `_ALL` is set                          | Returns `_ALL` range          |
| Pass `_WEB_RTC` when `_WEB_RTC` explicitly set                   | Returns `_WEB_RTC` range      |
| Pass `_WEB_RTC` when `_ALL` unset and `_WEB_RTC` unset           | Returns `(0, 0)`              |
| Pass `_WEB_RTC` when `_ALL` set and `_WEB_RTC` reset to `(0, 0)` | Returns `(0, 0)`              |
| Pass `_ALL` when only `_WEB_RTC` set                             | Returns  `(0,0)`              |

# API Details
### C++  
```
/// Specifies the network component scope for port configuration.
[v1_enum]
typedef enum COREWEBVIEW2_NETWORK_COMPONENT_SCOPE {
  /// Scope applies to all components.
  COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_ALL,
  /// Applies only to WebRTC peer-to-peer connection.
  COREWEBVIEW2_NETWORK_COMPONENT_SCOPE_WEB_RTC,
} COREWEBVIEW2_NETWORK_COMPONENT_SCOPE;

/// Specifies the network protocol for port configuration.
[v1_enum]
typedef enum COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND {
  /// User Datagram Protocol - fast, connectionless protocol.
  COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND_UDP,
} COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND;

/// Additional options used to create WebView2 Environment to manage port range configuration.
[uuid(6ce30f6b-5dcc-5dc1-9c09-723cf233dbe5), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironmentOptions10 : IUnknown {
  /// Sets the allowed port range restriction for the specified network component 
  /// scope and transport protocol.
  /// 
  /// This API enables WebView2 to operate within enterprise network or firewall
  /// restrictions by limiting network communication to a defined port range.
  /// It provides fine-grained control by allowing port restrictions to be applied
  /// per network component scope, such as WebRTC.
  /// 
  /// Currently, only WebRTC UDP Port Range restriction is supported.
  /// 
  /// `minPort` and `maxPort` must be within the range 1025-65535 (inclusive).
  /// `minPort` must be less than or equal to `maxPort`.
  /// If `minPort` equals `maxPort`, the range represents a single port.
  /// 
  /// Passing `(0, 0)` resets to the default behavior, meaning no restrictions
  /// are applied and the system assigns ports from the full ephemeral range.
  /// 
  /// Calls with invalid ranges fail with `E_INVALIDARG`.
  ///
  /// A network component-specific scope (e.g. _WEB_RTC) always takes precedence over _ALL for that component in `SetAllowedPortRange`.
  /// `_ALL` defines the port range restrictions for all components without specific overrides.
  ///  Passing `(0, 0)` for a network component scope removes its restriction.
  ///  If `_ALL` is set and a specific scope is reset, that component becomes unrestricted while `_ALL` still applies to others.

  /// | Network Scope State                        | Behaviour                                                                      |
  /// | ------------------------------------------ | ------------------------------------------------------------------------------ |
  /// | Only `_ALL` is set                         | `_ALL` applies port range restrictions to all network components               |
  /// | `_ALL` and `_WEB_RTC` are both set         | `_WEB_RTC` port range restrictions applies to WebRTC; `_ALL` applies to others |
  /// | `_WEB_RTC` only is set                     | `_WEB_RTC` applies port range restrictions only to WebRTC; others unrestricted | 
  /// | `_ALL` set and `_WEB_RTC` reset to `(0,0)` | `_ALL` applies port range restrictions to all except WebRTC (unrestricted)     |

  /// `scope` Network scope on which restrictions will apply.
  /// `protocol` Transport protocol on which restrictions will apply.
  /// `minPort` The minimum allowed port number (inclusive).
  /// `maxPort` The maximum allowed port number (inclusive).
  /// 
  HRESULT SetAllowedPortRange(
      [in] COREWEBVIEW2_NETWORK_COMPONENT_SCOPE scope,
      [in] COREWEBVIEW2_TRANSPORT_PROTOCOL_KIND protocol,
      [in] INT32 minPort,
      [in] INT32 maxPort
  );

  /// Retrieves the allowed port range for the specified transport protocol.
  /// Returns the currently configured port range previously set via
  /// `SetAllowedPortRange`.
  /// 
  /// By default, `(0, 0)` is returned, which indicates no restrictions are applied
  /// and ports are allocated from the system's ephemeral range (1025-65535 inclusive).
  ///
  /// `GetAllowedPortRange` returns the range explicitly set for the queried scope.
  /// If a specific scope is unset, it inherits `_ALL`.
  /// Querying `_ALL` only returns `_ALL`; it does not aggregate component-specific settings.
  /// If neither `_ALL` nor a component-specific scope is set, the default `(0,0)` (unrestricted) is returned.

  /// | `GetAllowedPortRange` Network Scope query                        | Returned Range                |
  /// | ---------------------------------------------------------------- | ----------------------------- |
  /// | Pass `_WEB_RTC` when only `_ALL` is set                          | Returns `_ALL` range          |
  /// | Pass `_WEB_RTC` when `_WEB_RTC` explicitly set                   | Returns `_WEB_RTC` range      |
  /// | Pass `_WEB_RTC` when `_ALL` unset and `_WEB_RTC` unset           | Returns `(0, 0)`              |
  /// | Pass `_WEB_RTC` when `_ALL` set and `_WEB_RTC` reset to `(0, 0)` | Returns `(0, 0)`              |
  /// | Pass `_ALL` when only `_WEB_RTC` set                             | Returns  `(0,0)`              |

  /// `scope` Network scope on which restrictions is applied.
  /// `protocol` Transport protocol on which restrictions is applied.
  /// `minPort` Receives the minimum allowed port number (inclusive).
  /// `maxPort` Receives the maximum allowed port number (inclusive).
  /// 
  HRESULT GetAllowedPortRange(
      [in] COREWEBVIEW2_NETWORK_COMPONENT_SCOPE scope,
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
    enum CoreWebview2NetworkComponentScope
    {
        All = 0,
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
            void SetAllowedPortRange(CoreWebview2NetworkComponentScope scope, CoreWebView2TransportProtocolKind protocol, Int32 minPort, Int32 maxPort);
            void GetAllowedPortRange(CoreWebview2NetworkComponentScope scope, CoreWebView2TransportProtocolKind protocol, out Int32 minPort, out Int32 maxPort);
        }
    }
}
```
