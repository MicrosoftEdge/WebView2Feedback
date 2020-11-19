# Background

Currently, a developer can pass the --user-agent browser args to the CreateWebView2EnvironmentWithDetails function. 

Ex. CreateWebView2EnvironmentWithDetails(nullptr, nullptr, L"--user-agent=\\"myUA\\"", ...);

For more info about the ‘--user-agent’ flag visit: https://peter.sh/experiments/chromium-command-line-switches/#user-agent.

However, there are a couple limitations to this workaround-- it is not an API that is easy to use or discover, you cannot modify a command line switch at runtime, and you cannot change the User Agent per WebView. In this document we describe the new API. We'd appreciate your feedback.

# Description

The User Agent (UA) is a piece of information regarding the user's OS, application, and version. The browser/webcontrol sends the User Agent to the HTTP server.

The User Agent property lets developers modify WebView2's User Agent. A key scenario is to allow end developers to get the current User Agent from the WebView and modify it based on an event. 

Ex. Update the User Agent to emulate a different browser version upon navigation to a specific website.

# Examples

The following code snippet demonstrates how the User Agent property can be used:

## Win32 C++
    
```cpp 
m_webView->add_NavigationStarting(
    Callback<ICoreWebView2NavigationStartingEventHandler>(
        [this](ICoreWebView2 *sender,
                ICoreWebView2NavigationStartingEventArgs *args) -> HRESULT {
            static const PCWSTR url_compare_example = L"fourthcoffee.com";
            wil::unique_cotaskmem_string uri;
            CHECK_FAILURE(args->get_Uri(&uri));
            wil::unique_bstr domain = GetDomainOfUri(uri.get());
            const wchar_t *domains = domain.get();
            wil::com_ptr<ICoreWebView2Settings> settings;
            CHECK_FAILURE(m_webView->get_Settings(&m_settings));
            if (wcscmp(url_compare_example, domains) == 0) {
                // Upon navigation to a specified url 
                // Change the user agent to emulate a mobile device
                CHECK_FAILURE(settings->put_UserAgent(GetMobileUserAgent())); 
            } else {
                // Change the user agent back to desktop
                CHECK_FAILURE(settings->put_UserAgent(GetDesktopUserAgent()));
            }
            return S_OK;
        })
        .Get(),
    &m_navigationStartingToken);
``` 

## .NET and WinRT

```c #
webView2Control.NavigationStarting += SetUserAgent;
private void SetUserAgent(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs e)
{
    var settings = webView2Control.CoreWebView2.Settings;
    // Note: Oversimplified test. Need to support idn, case-insensitivity, etc.
   if (new Uri(e.Uri).Host == "contoso.com")
   {
      settings.UserAgent = GetMobileUserAgent();
   }
   else
   {
      settings.UserAgent = GetDesktopUserAgent();
   }
}
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
    
```IDL
// This is the ICoreWebView2Settings interface.
[uuid(c79ba37e-9bd6-4b9e-b460-2ced163f231f), object, pointer_default(unique)]
interface ICoreWebView2Settings2 : ICoreWebView2Settings {
    /// `UserAgent` .  Returns the User Agent. The default value is the
    /// default User Agent of the Edge browser.
    [propget] HRESULT UserAgent([ out, retval ] LPWSTR * userAgent);
    /// Sets the `UserAgentString` property. This property may be overriden if
    /// the User-Agent header is set in a request. If the parameter is empty 
    /// the User Agent will not be updated and the current User Agent will remain. 
    [propput] HRESULT UserAgent([in] LPCWSTR userAgent);
}
``` 
## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
        public string UserAgent { get; set; };
    }
}
```
