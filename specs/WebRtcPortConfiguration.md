
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
2. Call `SetAllowedPortRange` for `COREWEBVIEW2_TRANSPORT_PROTOCOL_UDP`.  
3. Pass the options when creating the WebView2 environment.  


# Examples
### C++ Configure UDP Port Range
```cpp
Microsoft::WRL::ComPtr<ICoreWebView2StagingEnvironmentOptions10> optionsStaging10;
if (options.As(&optionsStaging10) == S_OK)
{
    // Configure port ranges for WebRTC UDP traffic to work within enterprise firewalls
    // Set UDP port range (example: 50000-55000 for enterprise environments)
    const INT32 udpMin = 50000, udpMax = 55000;

    CHECK_FAILURE(optionsStaging10->SetAllowedPortRange(
        COREWEBVIEW2_TRANSPORT_PROTOCOL_UDP, udpMin, udpMax));

    // Get the configured port range
    CHECK_FAILURE(optionsStaging10->GetAllowedPortRange(
        COREWEBVIEW2_TRANSPORT_PROTOCOL_UDP, &m_udpPortRange.minPort,
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
    // Configure port ranges for WebRTC UDP traffic to work within enterprise firewalls
    // Set UDP port range (example: 50000-55000 for enterprise environments)
    const int udpMin = 50000, udpMax = 55000;

    optionsStaging10.SetAllowedPortRange(
        COREWEBVIEW2_TRANSPORT_PROTOCOL_UDP, udpMin, udpMax);

    // Get the configured port range
    optionsStaging10.GetAllowedPortRange(
        COREWEBVIEW2_TRANSPORT_PROTOCOL_UDP, out m_udpPortRange.minPort,
        out m_udpPortRange.maxPort);
}

var environment = await CoreWebView2Environment.CreateAsync(
        subFolder, m_userDataFolder, options);
OnCreateEnvironmentCompleted(environment);
```

# API Details
### C++  
```
/// Specifies the network protocol type for port configuration.
[v1_enum]
typedef enum COREWEBVIEW2_NETWORK_PROTOCOL {
  /// User Datagram Protocol - fast, connectionless protocol.
  COREWEBVIEW2_NETWORK_PROTOCOL_UDP,
} COREWEBVIEW2_NETWORK_PROTOCOL;

/// Additional options used to create WebView2 Environment to manage port range configuration.
[uuid(eaf22436-27a1-5e3d-a4e3-84d7e7a69a1a), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironmentOptions10 : IUnknown {
  /// Sets the allowed port range for the specified transport protocol.
  /// This API enables WebView2 to operate within enterprise network or firewall
  /// restrictions by limiting network communication to a defined port range.
  /// 
  /// Currently, only WebRTC UDP Port Range restriction is supported.
  /// 
  /// `minPort` and `maxPort` must be within the range 1025â€“65535 (inclusive),
  /// and `minPort` must be less than or equal to `maxPort`.
  /// If `minPort` equals `maxPort`, the range represents a single port.
  /// 
  /// Passing `(0, 0)` resets to the default behavior, meaning no restrictions
  /// are applied and the system assigns ports from the full ephemeral range.
  /// 
  /// Calls with invalid ranges fail with `E_INVALIDARG`.
  /// 
  /// `protocol` The transport protocol (currently only UDP is supported).
  /// `minPort` The minimum allowed port number (inclusive).
  /// `maxPort` The maximum allowed port number (inclusive).
  /// 
  HRESULT SetAllowedPortRange(
      [in] COREWEBVIEW2_NETWORK_PROTOCOL protocol,
      [in] INT32 minPort,
      [in] INT32 maxPort
  );

  /// Retrieves the allowed port range for the specified transport protocol.
  /// Returns the currently configured port range previously set via
  /// `SetAllowedPortRange`.
  /// 
  /// By default, `(0, 0)` is returned, which indicates no restrictions are applied
  /// and ports are allocated from the systemâ€™s ephemeral range (1025â€“65535 inclusive).
  /// 
  /// `protocol` The transport protocol (currently only UDP is supported).
  /// `minPort` Receives the minimum allowed port number (inclusive).
  /// `maxPort` Receives the maximum allowed port number (inclusive).
  /// 
  HRESULT GetAllowedPortRange(
      [in] COREWEBVIEW2_NETWORK_PROTOCOL protocol,
      [out] INT32* minPort,
      [out] INT32* maxPort
  );


}
```

### C#
```csharp
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2NetworkProtocol
    {
        Udp = 0,
    };

    runtimeclass CoreWebView2EnvironmentOptions
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingEnvironmentOptions10")]
        {
            // ICoreWebView2StagingEnvironmentOptions10 members
            void SetAllowedPortRange(CoreWebView2NetworkProtocol protocol, Int32 minPort, Int32 maxPort);
            void GetAllowedPortRange(CoreWebView2NetworkProtocol protocol, out Int32 minPort, out Int32 maxPort);
        }
    }
}
```
