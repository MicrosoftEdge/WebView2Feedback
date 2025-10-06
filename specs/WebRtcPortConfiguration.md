
WebRTC Port Range Configuration
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
2. Call `SetAllowedPortRange` for `COREWEBVIEW2_NETWORK_PROTOCOL_UDP`.  
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
        COREWEBVIEW2_NETWORK_PROTOCOL_UDP, udpMin, udpMax));

    // Get the configured port range
    CHECK_FAILURE(optionsStaging10->GetAllowedPortRange(
        COREWEBVIEW2_NETWORK_PROTOCOL_UDP, &m_udpPortRange.minPort,
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
        COREWEBVIEW2_NETWORK_PROTOCOL_UDP, udpMin, udpMax);

    // Get the configured port range
    optionsStaging10.GetAllowedPortRange(
        COREWEBVIEW2_NETWORK_PROTOCOL_UDP, out m_udpPortRange.minPort,
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
  /// Transmission Control Protocol - reliable, connection-oriented protocol.
  COREWEBVIEW2_NETWORK_PROTOCOL_TCP,
  /// User Datagram Protocol - fast, connectionless protocol.
  COREWEBVIEW2_NETWORK_PROTOCOL_UDP,
} COREWEBVIEW2_NETWORK_PROTOCOL;

/// Additional options used to create WebView2 Environment to manage port range configuration.
[uuid(eaf22436-27a1-5e3d-a4e3-84d7e7a69a1a), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironmentOptions10 : IUnknown {
  /// Sets the allowed port range for the specified network protocol.
  /// This allows WebView2 to work within enterprise firewall constraints
  /// by restricting network communication to the specified port range.
  /// Currently WebRTC UDP port restriction is supported.
  /// 
  /// `protocol` The network protocol (TCP or UDP) for which to set the port range.
  /// `minPort` The minimum port number in the allowed range (inclusive).
  /// `maxPort` The maximum port number in the allowed range (inclusive).
  /// 
  HRESULT SetAllowedPortRange(
      [in] COREWEBVIEW2_NETWORK_PROTOCOL protocol,
      [in] INT32 minPort,
      [in] INT32 maxPort
  );

  /// Gets the allowed port range for the specified network protocol.
  /// Returns the current port range configuration that was set via
  /// SetAllowedPortRange. Default value is 0,0, which means no restrictions applied
  /// and ports are allocated randomly between system's ephemeral range.
  /// 
  /// `protocol` The network protocol (TCP or UDP) for which to get the port range.
  /// `minPort` Receives the minimum port number in the allowed range.
  /// `maxPort` Receives the maximum port number in the allowed range.
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
/// <summary>
/// Specifies the network protocol type for port configuration.
/// </summary>
public enum COREWEBVIEW2_NETWORK_PROTOCOL
{
    /// <summary>
    /// Transmission Control Protocol - reliable, connection-oriented protocol.
    /// </summary>
    COREWEBVIEW2_NETWORK_PROTOCOL_TCP,
    /// <summary>
    /// User Datagram Protocol - fast, connectionless protocol.
    /// </summary>
    COREWEBVIEW2_NETWORK_PROTOCOL_UDP,
}

/// <summary>
/// Additional options used to create WebView2 Environment to manage port range configuration.
/// </summary>
public interface ICoreWebView2StagingEnvironmentOptions10
{
    /// <summary>
    /// Sets the allowed port range for the specified network protocol.
    /// This allows WebView2 to work within enterprise firewall constraints
    /// by restricting network communication to the specified port range.
    /// Currently WebRTC UDP port restriction is supported.
    /// </summary>
    /// <param name="protocol">The network protocol (TCP or UDP) for which to set the port range.</param>
    /// <param name="minPort">The minimum port number in the allowed range (inclusive).</param>
    /// <param name="maxPort">The maximum port number in the allowed range (inclusive).</param>
    void SetAllowedPortRange(
        COREWEBVIEW2_NETWORK_PROTOCOL protocol,
        int minPort,
        int maxPort
    );

    /// <summary>
    /// Gets the allowed port range for the specified network protocol.
    /// Returns the current port range configuration that was set via
    /// SetAllowedPortRange. Default value is 0,0, which means no restrictions applied
    /// and ports are allocated randomly between system's ephemeral range.
    /// </summary>
    /// <param name="protocol">The network protocol (TCP or UDP) for which to get the port range.</param>
    /// <param name="minPort">Receives the minimum port number in the allowed range.</param>
    /// <param name="maxPort">Receives the maximum port number in the allowed range.</param>
    void GetAllowedPortRange(
        COREWEBVIEW2_NETWORK_PROTOCOL protocol,
        out int minPort,
        out int maxPort
    );
}
```
