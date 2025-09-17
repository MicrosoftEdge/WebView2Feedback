
WebRTC Port Range Configuration
===

# Background
WebRTC by default allocates ports dynamically from the system’s ephemeral range.  
In enterprise or testing environments, developers often need deterministic or firewall-friendly port allocation.  

This API enables developers to configure the port range WebRTC uses for [ICE](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols#ice) candidates and media connections.

The initial support is for **UDP**, with room to extend to **TCP** in the future.  

By exposing a `WebRtcPortConfiguration` object on `CoreWebView2EnvironmentOptions`, developers can set and retrieve the port range before creating the WebView2 environment.  

# Conceptual pages (How To)

Developers can use this API to restrict WebRTC’s UDP ports to a specific range which WebRTC uses for ICE candidate and media connections.

ICE stands for **Interactive Connectivity Establishment**. It is a standard method of NAT traversal used in WebRTC. It is defined in [IETF RFC 5245](https://datatracker.ietf.org/doc/html/rfc5245). ICE deals with the process of connecting media through NATs by conducting connectivity checks.  

Common scenarios:  
- Configure ports for **enterprise firewall compliance**.  
- Run **deterministic tests** where ICE candidate ports are predictable.  
- Avoid conflicts with other applications that may already use ephemeral ranges.  

Usage steps:  
1. Create `CoreWebView2EnvironmentOptions`.  
2. Access the `WebRtcPortConfiguration` object.  
3. Call `SetPortRange` for `CoreWebView2WebRtcProtocolKind.Udp`.  
4. Pass the options when creating the WebView2 environment.  


# Examples
### C++ Configure UDP Port Range
```cpp
wil::com_ptr<ICoreWebView2EnvironmentOptions> options = 
    Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();

wil::com_ptr<ICoreWebView2WebRtcPortConfiguration> portConfig;
CHECK_FAILURE(options->get_WebRtcPortConfiguration(&portConfig));

CHECK_FAILURE(portConfig->SetPortRange(
    CoreWebView2WebRtcProtocolKind::Udp, 50000, 51000));

HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        subFolder, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get());
```

### C# Configure UDP Port Range
```csharp
var options = new CoreWebView2EnvironmentOptions();

var portConfig = options.WebRtcPortConfiguration;
portConfig.SetPortRange(CoreWebView2WebRtcProtocolKind.Udp, 50000, 51000);

var environment = await CoreWebView2Environment.CreateAsync(
    browserExecutableFolder: subFolder,
    userDataFolder: m_userDataFolder,
    options: options);

OnCreateEnvironmentCompleted(environment);
```

# API Details
## C++  
```
/// Additional options used to create WebView2 Environment to manage WebRTC UDP port range configuration.
[uuid(0eebe393-8dcf-5bc5-a15d-d862088242e9), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions10 : IUnknown {
  /// Get the WebRTC port range configuration object for configuring a custom port range.
  /// This configuration object can be used to set and retrieve port range configuration
  /// that WebRTC will use for ICE candidates and media connections.
  /// If no custom range is configured, WebRTC will use the operating system's default dynamic port range.
  /// Configuration must be completed before the environment is created. Once the environment is
  /// created, the port range cannot be customized.
  /// 
  /// 
  /// \snippet AppWindow.cpp WebRtcPortConfiguration
  [propget] HRESULT WebRtcPortConfiguration([out, retval] ICoreWebView2WebRtcPortConfiguration** value);



}

/// WebRTC port configuration interface for managing WebRTC port range configuration.
/// This interface provides methods to configure and retrieve custom port ranges
/// that WebRTC will use for ICE candidates and media connections across different protocols.
[uuid(b1ac2eb4-15b5-574f-aeb7-c51b9f1520fa), object, pointer_default(unique)]
interface ICoreWebView2WebRtcPortConfiguration : IUnknown {
  /// The `SetPortRange` method allows you to set a custom port range for WebRTC to use
  /// for a specific protocol type.
  /// This method allows configuring a specific port range that WebRTC will use
  /// for ICE candidates and media connections for the specified protocol.
  /// 
  /// `protocol` specifies the WebRTC protocol type (UDP, TCP, etc.).
  /// `minPort` and `maxPort` must be in the range 1025-65535 (inclusive).
  /// Calls with invalid ranges return E_INVALIDARG.
  /// `minPort` must be less than or equal to `maxPort`.
  /// If `minPort` equals `maxPort`, it represents a single port.
  /// 
  /// Calling this method will replace any previously configured port range for the specified protocol.
  /// 
  /// 
  /// \snippet AppWindow.cpp WebRtcPortConfiguration
  HRESULT SetPortRange(
      [in] COREWEBVIEW2_WEB_RTC_PROTOCOL_KIND protocol,
      [in] UINT32 minPort,
      [in] UINT32 maxPort
  );

  /// The `GetPortRange` method gets the currently configured port range for a specific protocol.
  /// Returns TRUE if a custom port range is configured for the specified protocol, 
  /// with the range values in out parameters.
  /// Returns FALSE if no custom range is set for the protocol (using default dynamic allocation), 
  /// in which case the out parameter values should be ignored.
  /// 
  /// 
  /// \snippet AppWindow.cpp WebRtcPortConfiguration
  HRESULT GetPortRange(
      [in] COREWEBVIEW2_WEB_RTC_PROTOCOL_KIND protocol,
      [out] UINT32* minPort,
      [out] UINT32* maxPort
      , [out, retval] BOOL* value);


}
```

## C#

```csharp
/// <summary>
/// Specifies the WebRTC protocol type for port range configuration.
/// </summary>
public enum CoreWebView2WebRtcProtocolKind
{
    /// <summary>
    /// UDP protocol for WebRTC media and ICE candidates.
    /// </summary>
    Udp = 0,
}

/// <summary>
/// WebRTC port configuration interface for managing WebRTC port range configuration.
/// This interface provides methods to configure and retrieve custom port ranges
/// that WebRTC will use for ICE candidates and media connections across different protocols.
/// </summary>
public interface ICoreWebView2WebRtcPortConfiguration
{
    /// <summary>
    /// The SetPortRange method allows you to set a custom port range for WebRTC to use
    /// for a specific protocol type.
    /// This method allows configuring a specific port range that WebRTC will use
    /// for ICE candidates and media connections for the specified protocol.
    /// 
    /// protocol specifies the WebRTC protocol type.
    /// minPort and maxPort must be in the range 1025-65535 (inclusive).
    /// Calls with invalid ranges return E_INVALIDARG.
    /// minPort must be less than or equal to maxPort.
    /// If minPort equals maxPort, it represents a single port.
    /// 
    /// Calling this method will replace any previously configured port range for the specified protocol.
    /// </summary>
    /// <param name="protocol">The WebRTC protocol type</param>
    /// <param name="minPort">Minimum port in the range (1025-65535)</param>
    /// <param name="maxPort">Maximum port in the range (1025-65535)</param>
    void SetPortRange(CoreWebView2WebRtcProtocolKind protocol, uint minPort, uint maxPort);

    /// <summary>
    /// The GetPortRange method gets the currently configured port range for a specific protocol.
    /// Returns true if a custom port range is configured for the specified protocol, 
    /// with the range values in out parameters.
    /// Returns false if no custom range is set for the protocol (using default dynamic allocation), 
    /// in which case the out parameter values should be ignored.
    /// </summary>
    /// <param name="protocol">The WebRTC protocol type</param>
    /// <param name="minPort">Output parameter for minimum port in the range</param>
    /// <param name="maxPort">Output parameter for maximum port in the range</param>
    /// <returns>True if custom range is configured, false if using default allocation</returns>
    bool GetPortRange(CoreWebView2WebRtcProtocolKind protocol, out uint minPort, out uint maxPort);
}

/// <summary>
/// Additional options used to create WebView2 Environment to manage WebRTC port range configuration.
/// </summary>
public interface ICoreWebView2EnvironmentOptions
{
    /// <summary>
    /// Gets the WebRTC port configuration object for configuring custom port ranges.
    /// This configuration can be used to set and retrieve port range configuration
    /// that WebRTC will use for ICE candidates and media connections.
    /// If no range is configured, WebRTC uses the OS ephemeral port range.
    /// Configuration must be completed before the environment is created. Once the environment is
    /// setup, the port range can not be customized.
    /// </summary>
    ICoreWebView2WebRtcPortConfiguration WebRtcPortConfiguration { get; }
}
```
