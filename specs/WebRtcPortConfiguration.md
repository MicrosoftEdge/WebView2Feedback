
WebRTC Port Range Configuration
===

# Background
WebRTC by default allocates ports dynamically from the system’s ephemeral range.  
In enterprise or testing environments, developers often need deterministic or firewall-friendly port allocation.  

This API enables developers to configure the port range WebRTC uses for ICE candidates and media connections.  
The initial support is for **UDP**, with room to extend to **TCP** in the future.  

By exposing a `WebRtcPortConfiguration` object on `CoreWebView2EnvironmentOptions`, developers can set and retrieve the port range before creating the WebView2 environment.  

# Conceptual pages (How To)

Developers can use this API to restrict WebRTC’s UDP ports to a specific range.  

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
### Configure UDP Port Range
```
wil::com_ptr<ICoreWebView2EnvironmentOptions> options = 
    Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();

wil::com_ptr<ICoreWebView2WebRtcPortConfiguration> portConfig;
CHECK_FAILURE(options->get_WebRtcPortConfiguration(&portConfig));

CHECK_FAILURE(portConfig->SetPortRange(
    CoreWebView2WebRtcProtocolKind::Udp, 50000, 51000));
```

### C++ Sample
```cpp
using namespace Microsoft::WRL;

ScenarioWebRtcUdpPortConfiguration::ScenarioWebRtcUdpPortConfiguration(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    // Navigate to a demo page that will trigger WebRTC usage.
    m_demoUri = L"https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/";
    CHECK_FAILURE(m_webView->Navigate(m_demoUri.c_str()));

    // If we navigate away from the demo page, turn off this scenario.
    CHECK_FAILURE(m_webView->add_ContentLoading(
        Callback<ICoreWebView2ContentLoadingEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2ContentLoadingEventArgs* /*args*/)
                -> HRESULT
            {
                wil::unique_cotaskmem_string uri;
                sender->get_Source(&uri);
                if (uri.get() != m_demoUri)
                {
                    m_appWindow->DeleteComponent(this);
                }
                return S_OK;
            })
            .Get(),
        &m_contentLoadingToken));
}

ScenarioWebRtcUdpPortConfiguration::~ScenarioWebRtcUdpPortConfiguration()
{
    CHECK_FAILURE(m_webView->remove_ContentLoading(m_contentLoadingToken));
}

```

# API Details
## C++  
```
/// Specifies the WebRTC protocol type for port range configuration.
[ms_owner("core", "juhishah@microsoft.com")]
enum CoreWebView2WebRtcProtocolKind
{
    /// UDP protocol for WebRTC media and ICE candidates.
    Udp = 0,
    /// TCP protocol for WebRTC media and ICE candidates (future support).
    Tcp = 1,
};
[availability("staging")]
runtimeclass CoreWebView2WebRtcPortConfiguration : [default] ICoreWebView2WebRtcPortConfiguration{}

/// <com>
/// WebRTC port configuration interface for managing WebRTC port range configuration.
/// This interface provides methods to configure and retrieve custom port ranges
/// that WebRTC will use for ICE candidates and media connections across different protocols.
/// </com>
[availability("staging")]
[com_interface("staging=ICoreWebView2StagingWebRtcPortConfiguration")]
[ms_owner("core", "juhishah@microsoft.com")]
interface ICoreWebView2WebRtcPortConfiguration
{
    // ICoreWebView2StagingWebRtcPortConfiguration members
    /// The `SetPortRange` method allows you to set a custom port range for WebRTC to use
    /// for a specific protocol type.
    /// This method allows configuring a specific port range that WebRTC will use
    /// for ICE candidates and media connections for the specified protocol.
    /// 
    /// `protocol` specifies the WebRTC protocol type (UDP, TCP, etc.).
    /// `minPort` and `maxPort` must be in the range 1025-65535 (inclusive).
    /// `minPort` must be less than or equal to `maxPort`.
    /// If `minPort` equals `maxPort`, it represents a single port.
    /// 
    /// Calling this method will replace any previously configured port range for the specified protocol.
    /// <com>
    /// \snippet AppWindow.cpp WebRtcPortConfiguration
    /// </com>
    void SetPortRange(CoreWebView2WebRtcProtocolKind protocol, UInt32 minPort, UInt32 maxPort);

    /// The `GetPortRange` method gets the currently configured port range for a specific protocol.
    /// Returns TRUE if a custom port range is configured for the specified protocol, 
    /// with the range values in out parameters.
    /// Returns FALSE if no custom range is set for the protocol (using default dynamic allocation), 
    /// in which case the out parameter values should be ignored.
    /// <com>
    /// \snippet AppWindow.cpp WebRtcPortConfiguration
    /// </com>
    Boolean GetPortRange(CoreWebView2WebRtcProtocolKind protocol, out UInt32 minPort, out UInt32 maxPort);
}
```

```
/// <com>
/// Additional options used to create WebView2 Environment to manage WebRTC UDP port range configuration.
/// </com>
[availability("staging")]
[com_interface("staging=ICoreWebView2StagingEnvironmentOptions10")]
[ms_owner("core", "juhishah@microsoft.com")]
[exclusiveto(CoreWebView2EnvironmentOptions)]
interface ICoreWebView2StagingEnvironmentOptions10
{
    // ICoreWebView2StagingEnvironmentOptions10 members
    /// Gets the WebRTC UDP port allocator for configuring a custom UDP port range.
    /// This allocator can be used to set and retrieve UDP port range configuration
    /// that WebRTC will use for ICE candidates and media connections.
    /// <com>
    /// \snippet AppWindow.cpp WebRtcPortConfiguration
    /// </com>
    ICoreWebView2WebRtcPortConfiguration WebRtcPortConfiguration { get; };
}
```


# Appendix
Validation rules: Ports must be within 1025–65535. Calls with invalid ranges return E_INVALIDARG.
Default behavior: If no range is configured, WebRTC uses the OS ephemeral port range.
Thread safety: Configuration must be completed before the environment is created.
Extensibility: API is protocol-based to allow future support (e.g., TCP).
