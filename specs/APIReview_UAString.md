# Background
The User Agent is a client-side piece of information that the browser/webcontrol sends to the server/website a user visits. It contains information about user’s system and is modifiable by the user.  

Currently, a developer can pass the --user-agent browser args to the CreateWebView2EnvironmentWithDetails function. 
	Ex. CreateWebView2EnvironmentWithDetails(nullptr, nullptr, L"--user-agent=\"myUA\"", ...);
For more info about the ‘—user - agent’ flag visit: https://peter.sh/experiments/chromium-command-line-switches/#user-agent.

However, there are a couple limitations to this workaround-- you cannot modify a command line switch at runtime, nor can you change the user agent per webview. In this document we describe the new API. We'd appreciate your feedback.

# Description
The Settings component will change the UA per WebView2 via Chrome Developer Protocol command (CDP). A key scenario is to allow end developers to get the current user agent from the webview and modify it based on some sort of event, such as navigating to a specific website and setting the user agent to emulate a different browser version.

# Examples

The following code snippet demonstrates how the environment APIs can be used
:

## Win32 C++
    
```cpp 
m_webView->add_NavigationStarting(
    Callback<ICoreWebView2NavigationStartingEventHandler>(
        [this](ICoreWebView2 *sender,
                ICoreWebView2NavigationStartingEventArgs *args) -> HRESULT {
            static const PCWSTR url_compare_example = L"foo.org";
            wil::unique_bstr domain = GetDomainOfUri(uri.get());
            const wchar_t *domains = domain.get();
            if (wcscmp(url_compare_example, domains) == 0) {
                // Upon navigation to a specified url 
                // Change the user agent to emulate a mobile device 
                wil::com_ptr<ICoreWebView2Settings> settings;
                CHECK_FAILURE(m_webView->get_Settings(&m_settings));
                LPCWSTR mobile_ua =
                    "Mozilla/5.0 (Linux; Android 8.0.0; SM-G960F Build/R16NW) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/62.0.3202.84 Mobile Safari/537.36";
                CHECK_FAILURE(settings->put_UserAgent(mobile_ua));
                LPCWSTR received_ua;
                CHECK_FAILURE(settings->get_UserAgent(&received_ua));
                EXPECT_EQ(base::Value(received_ua), base::Value(mobile_ua))
            }
            return S_OK;
        })
        .Get(),
    &m_navigationStartingToken);
``` 

## .NET and WinRT

```c #
private void SetUserAgent(CoreWebView2 sender, CoreWebView2UserAgentArgs e) {
    var settings = webView2Control.CoreWebView2.Settings;
    settings.UserAgent = "Mozilla/5.0 (Linux; Android 8.0.0; SM-G960F Build/R16NW) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.84 Mobile Safari/537.36";
    }
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
    
```IDL
// This is the ICoreWebView2Settings Staging interface.
[uuid(c79ba37e-9bd6-4b9e-b460-2ced163f231f), object, pointer_default(unique)]
interface ICoreWebView2StagingSettings : IUnknown {
    /// `UserAgent` .  Returns the User Agent. The default value is the
    /// default User Agent.
    [propget] HRESULT UserAgent([ out, retval ] LPCWSTR * userAgent);
    /// Sets the `UserAgentString` property. This property may be overriden if
    /// the User-Agent header is set in a request.
    [propput] HRESULT UserAgent([in] LPCWSTR userAgent);
}
``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core {
public
    partial class CoreWebView2 {
    // There are other API in this interface that we are not showing
    public
        CoreWebView2Settings UserAgent {get ; set; };
    }
}
```
