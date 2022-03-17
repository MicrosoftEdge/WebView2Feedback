See comments in Markdown for how to use this spec template

RegisterCustomScheme
===

# Background
Currently the WebResourceRequested event is not raised for non-http(s) URIs. Spartan WebView has built-in support for ms-appx* URIs and support of providing an IUriToStreamResolver parameter in NavigateToLocalStreamUri. Raising the CoreWebView2.WebResourceRequested would close the functional gap between WebView1 and WebView2 as the app can just provide a WebResourceResponse for a given custom protocol URI.

To be able to provide the ability to raise WebResourceRequested for custom schemes, WebView2 needs to be able to know how to treat such custom scheme URIs. By the W3C standard, custom schemes have opaque origins and do not participate in security policies. However, in order to make web requests with custom schemes useful, some of these URIs would need to act more like HTTP URIs. The app needs to be able to make the choices on which schemes to enable security policies for and make similar to HTTP URIs. The following questions arise:

- Are custom scheme URIs considered secure contexts?
- Do custom schemes URIs participate in CORS policies?
- Which origins should be able to issue requests from these custom schemes?

As a result, we introduce a new API to be able to register custom schemes and allow the end developer to answer these questions as a part of registration.

# Conceptual pages (How To)

WebResourceRequested event can also be raised for custom schemes. For this, the app has to register the custom schemes it would like to be able to issue resource requests for using the CustomSchemeRegistrar. With each registration, the app will specify the security policies it wants enabled for the URIs with such schemes and it will also need to explicitly specify the origins that are allowed to interact with these custom scheme URIs.  The registrations are valid throughout the lifetime of the WebView2Environment and browser process and any other WebView2Environments that share the browser process must register exactly same schemes to be able to create a WebView2Environment.

For each custom scheme the developer wants to register they can:
1) Enable the scheme to be used for CORS requests provided the origin making the request is also in list of allowed origins list.
2) Set it to be a secure context scheme to prevent insecure content warnings.
3) Provide a list of origins that can make requests to the custom scheme.

# Examples

## CustomSchemeRegistrations

The following code sample registers 3 custom schemes on the CoreWebView2EnvironmentOptions:

-Scheme 1 has CORS enabled and has https://*.example.com in its allowed origins list.
-Scheme 2 has CORS enabled, but has a null allowed origins list.
-Scheme 3 has CORS disabled and has https://*.example.com in its allowed origins list.

It adds a WebResourceRequested handler for the requests to the custom schemes, which will serve the requests locally. Then it navigates the WebView to https://www.example.com and attempts to do XHRs with the three schemes. Only XHR from the scheme 1 will succeed because it's the only one with CORS enabled and has https://www.example.com in its allowed origin list.
``` c#
CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
string[] allowedOriginsList = new string[1];
allowedOriginsList[0] = "https://*.example.com";

options.CustomSchemeRegistrations.Add(new CoreWebView2CustomSchemeRegistration("custom-scheme", true /* isSecure*/, true /* isCorsEnabled */, false, allowedOriginsList));
options.CustomSchemeRegistrations.Add(new CoreWebView2CustomSchemeRegistration("custom-scheme-cors-disabled", true /* isSecure*/,
    false /* isCorsEnabled */, false, allowedOriginsList));
options.CustomSchemeRegistrations.Add(new CoreWebView2CustomSchemeRegistration("custom-scheme-not-in-allowed-origins", true /* isSecure*/,
    true /* isCorsEnabled */, false, null));
...
string customScheme = "custom-scheme";
webView.CoreWebView2.AddWebResourceRequestedFilter(
        customScheme + ":*", All);
webView.CoreWebView2.WebResourceRequested += delegate (
            object sender, CoreWebView2WebResourceRequestedEventArgs e) {
        CoreWebView2WebResourceResponse response;
        CoreWebView2WebResourceRequest request = e.Request;
        String uri = request.uri;
        if (uri.StartsWith(customScheme + "://"))
        {
            string assetsFilePath = L"data/";
            assetsFilePath += uri.Substring(customScheme.Length + 3);
            FileStream fileStream = new FileStream(assetsFilePath, FileMode.Open, FileAccess.Read);

            if (stream)
            {
              e.Response = webView.CoreWebView2.CreateWebResourceResponse(fileStream, 200, "OK", L"Content-Type: application/json\nAccess-Control-Allow-Origin: *");
            }
            else
            {
                e.Response = webView.CoreWebView2.CreateWebResourceResponse(null, 404, "Not Found", L"");
            }
        }
}

webView.CoreWebView2.Navigate(L"https://www.example.com");

// The following XHR will execute in the context of https://www.example.com page and will succeed.
// WebResourceRequested event will be raised for this request as *.example.com is in the allowed origin list of custom-scheme and
// the custom scheme has CORS enabled. Since the response header provided in WebResourceRequested handler allows all origins for CORS
// the XHR succeeds.
webView.CoreWebView2.ExecuteScriptAsync("var oReq = new XMLHttpRequest();\
                                        oReq.addEventListener(\"load\", reqListener);\
                                        oReq.open(\"GET\", \"custom-scheme://example-data.json\");\
                                        oReq.send();");
// The following XHR will fail because *.example.com is in the not allowed origin list of custom-scheme2.
// The WebResourceRequested event will not be raised for this request.
webView.CoreWebView2.ExecuteScriptAsync("var oReq = new XMLHttpRequest();\
                                        oReq.addEventListener(\"load\", reqListener);\
                                        oReq.open(\"GET\", \"custom-scheme-not-in-allowed-origins://example-data.json\");\
                                        oReq.send();");
// The following XHR will fail because CORS is not enabled for custom-scheme-cors-disabled.
// The WebResourceRequested event will not be raised for this request.
webView.CoreWebView2.ExecuteScriptAsync("var oReq = new XMLHttpRequest();\
                                        oReq.addEventListener(\"load\", reqListener);\
                                        oReq.open(\"GET\", \"custom-scheme-cors-disabled://example-data.json\");\
                                        oReq.send();");
```

``` cpp
Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions3> options3;
if (options.As(&options3) == S_OK) {
  std::vector<Microsoft::WRL::ComPtr<ICoreWebView2CustomSchemeRegistration>> schemeRegistrations;
  
  const WCHAR* allowedOrigins[1] = {L"https://*.example.com"};
  schemeRegistrations.push_back(Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(
          L"custom-scheme", TRUE /* isSecure*/, TRUE /* isCorsEnabled */,
          1, allowedOrigins));
  schemeRegistrations.push_back(Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(
          L"custom-scheme-not-in-allowed-origins-list", TRUE /* isSecure*/, TRUE /* isCorsEnabled */, nullptr));
  schemeRegistrations.push_back(Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(
          L"custom-scheme-cors-disabled", TRUE /* isSecure*/, FALSE /* isCorsEnabled */,
          1, allowedOrigins));
  CHECK_FAILURE(options3->SetCustomSchemeRegistrations(schemeRegistrations.size(), schemeRegistrations.data());
}
...

CHECK_FAILURE(m_webView->AddWebResourceRequestedFilter(
        L"custom-scheme*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL));
CHECK_FAILURE(m_webView->add_WebResourceRequested(
    Callback<ICoreWebView2WebResourceRequestedEventHandler>(
        [this](
            ICoreWebView2* sender,
            ICoreWebView2WebResourceRequestedEventArgs* args) {
        wil::com_ptr<ICoreWebView2WebResourceRequest> request;
        wil::com_ptr<ICoreWebView2WebResourceResponse> response;
        CHECK_FAILURE(args->get_Request(&request));
        wil::unique_cotaskmem_string uri;
        CHECK_FAILURE(request->get_Uri(&uri));
        if (wcsncmp(uri.get(), L"custom-scheme", ARRAYSIZE(L"custom-scheme")-1) == 0)
        {
            std::wstring assetsFilePath = L"data/";
            assetsFilePath += wcsstr(uri.get(), L"://") + 3;
            wil::com_ptr<IStream> stream;
            SHCreateStreamOnFileEx(
                assetsFilePath.c_str(), STGM_READ, FILE_ATTRIBUTE_NORMAL, FALSE,
                nullptr,
                &stream);
            if (stream)
            {
                CHECK_FAILURE(
                    m_appWindow->GetWebViewEnvironment()->CreateWebResourceResponse(
                        stream.get(), 200, L"OK", L"Content-Type: application/json\nAccess-Control-Allow-Origin: *",
                        &response));
                CHECK_FAILURE(args->put_Response(response.get()));
            }
            else
            {
                CHECK_FAILURE(
                    m_appWindow->GetWebViewEnvironment()->CreateWebResourceResponse(
                        nullptr, 404, L"Not Found", L"", &response));
                CHECK_FAILURE(args->put_Response(response.get()));
            }
            return S_OK;
        }

        return S_OK;
        })
        .Get(),
    &m_webResourceRequestedToken));

CHECK_FAILURE(m_webView->Navigate(L"https://www.example.com"));

// The following XHR will execute in the context of https://www.example.com page and will succeed.
// WebResourceRequested event will be raised for this request as *.example.com is in the allowed origin list of custom-scheme and
// the custom scheme has CORS enabled. Since the response header provided in WebResourceRequested handler allows all origins for CORS
// the XHR succeeds.
CHECK_FAILURE(m_webView->ExecuteScript(L"var oReq = new XMLHttpRequest();"
                                       L"oReq.addEventListener(\"load\", reqListener);"
                                       L"oReq.open(\"GET\", \"custom-scheme://example-data.json\");"
                                       L"oReq.send();",
                                      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                                          [](HRESULT error, PCWSTR result) -> HRESULT { return S_OK; })
                                          .Get()));
// The following XHR will fail because *.example.com is in the not allowed origin list of custom-scheme2.
// The WebResourceRequested event will not be raised for this request.
CHECK_FAILURE(m_webView->ExecuteScript(L"var oReq = new XMLHttpRequest();"
                                       L"oReq.addEventListener(\"load\", reqListener);"
                                       L"oReq.open(\"GET\", \"custom-scheme-not-in-allowed-origins://example-data.json\");"
                                       L"oReq.send();",
                                      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                                          [](HRESULT error, PCWSTR result) -> HRESULT { return S_OK; })
                                          .Get()));
// The following XHR will fail because CORS is disabled for custom-scheme-cors-disabled.
// The WebResourceRequested event will not be raised for this request.
CHECK_FAILURE(m_webView->ExecuteScript(L"var oReq = new XMLHttpRequest();"
                                       L"oReq.addEventListener(\"load\", reqListener);"
                                       L"oReq.open(\"GET\", \"custom-scheme-cors-disabled://example-data.json\");"
                                       L"oReq.send();",
                                      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                                          [](HRESULT error, PCWSTR result) -> HRESULT { return S_OK; })
                                          .Get()));
```

# API Details

## COM API

```c#
// This is the ICoreWebView2CustomSchemeRegistration interface
[uuid(d60ac92c-37a6-4b26-a39e-95cfe59047bb), object, pointer_default(unique)]
interface ICoreWebView2CustomSchemeRegistration : IUnknown {
  // Represents the registration of a custom scheme with the CoreWebView2Environment.
  // This allows the WebView2 app to be able to handle
  // WebResourceRequested event for requests with the specified scheme and
  // be able to navigate the WebView2 to the custom scheme. Once the environment
  // is created, the registrations are valid and immutable throughout the
  // lifetime of the associated WebView2s' browser process and any WebView2
  // environments sharing the browser process must be created with identical
  // custom scheme registrations, otherwise the environment creation will fail.
  // Any further attempts to register the same scheme will fail.
  // The URIs of registered custom schemes will be treated similar to http URIs for their origins.
  // They will have tuple origins for URIs with host and opaque origins for
  // URIs without host as specified in https://html.spec.whatwg.org/multipage/origin.html
  // Example:
  // custom-scheme-with-host://hostname/path/to/resource has origin of custom-scheme-with-host://hostname
  // custom-scheme-without-host:path/to/resource has origin of custom-scheme-without-host:path/to/resource
  // For WebResourceRequested event, the request URIs and filter URIs with custom schemes
  // will be normalized according to RFC3986.

  // The name of the custom scheme to register.
  [propget] HRESULT SchemeName([out, retval] LPCWSTR* schemeName);
  [propput] HRESULT SchemeName([in] LPCWSTR value);

  // Whether the scheme will be treated as a secure context like https.
  [propget] HRESULT IsSecure([out, retval] BOOL* isSecure);
  // Set if the scheme will be treated as a secure context.
  [propput] HRESULT IsSecure([in] BOOL value);

  // If `isCorsEnabled` is set, the scheme will be allowed for requests subject to
  // CORS rules as specified in https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS.
  // If it is not set, CORS requests with this scheme will be blocked.
  [propget] HRESULT IsCorsEnabled([out, retval] BOOL* isCorsEnabled);
  // Set CORS enabled for the scheme.
  [propput] HRESULT IsCorsEnabled([in] BOOL value);

  // List of origins that are allowed to use the scheme,
  // subject to cross origin restrictions.
  // Origins are specified as a string in the format of scheme://host:port.
  // `*` wildcard can also be used on origins.
  // For example, "http://*.example.com:80".
  // Any origin from the custom scheme itself is allowed by default. If the
  // array is empty, no other origin except origins from same scheme are allowed.
  HRESULT GetAllowedOrigins([out] UINT32* allowedOriginsCount, [out] LPCWSTR** allowedOrigins);
  // Set the list of origins that are allowed to use the scheme.
  HRESULT SetAllowedOrigins([in] UINT32 allowedOriginsCount, [in] LPCWSTR* allowedOrigins);
}

// This is the ICoreWebView2EnvironmentOptions3 interface
[uuid(ac52d13f-0d38-475a-9dca-876580d6793e), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : IUnknown {
  /// List of custom scheme registrations.
  HRESULT GetCustomSchemeRegistrations(
      [out] UINT32* count,
      [out] ICoreWebView2CustomSchemeRegistration*** schemeRegistrations);
  /// Set the list of custom scheme registrations to be used.
  HRESULT, SetCustomSchemeRegistrations(
      [in] UINT32 count,
      [in] const ICoreWebView2CustomSchemeRegistration** schemeRegistrations);
}
```

## .NET API
```c#
namespace Microsoft.Web.WebView2.Core
{
    // Represents the registration of a custom scheme with the CoreWebView2Environment.
    // This allows the WebView2 app to be able to handle
    // WebResourceRequested event for requests with the specified scheme and
    // be able to navigate the WebView2 to the custom scheme. Once the environment
    // is created, the registrations are valid and immutable throughout the
    // lifetime of the associated WebView2s' browser process and any WebView2
    // environments sharing the browser process must be created with identical
    // custom scheme registrations, otherwise the environment creation will fail.
    // Any further attempts to register the same scheme will fail.
    // The URIs of registered custom schemes will be treated similar to http URIs for their origins.
    // They will have tuple origins for URIs with host and opaque origins for
    // URIs without host as specified in [7.5 Origin - HTML Standard](https://html.spec.whatwg.org/multipage/origin.html)
    // Example:
    // `custom-scheme-with-host://hostname/path/to/resource` has origin of `custom-scheme-with-host://hostname`
    // `custom-scheme-without-host:path/to/resource` has origin of `custom-scheme-without-host:path/to/resource`
    // For WebResourceRequested event, the cases of request URIs and filter URIs with custom schemes
    // will be normalized according to generic URI syntax rules. Any non-ASCII characters will be preserved.
    runtimeclass CoreWebView2CustomSchemeRegistration
    {
        // Constructor
        CoreWebView2CustomSchemeRegistration(string schemeName, bool isSecure, bool isCorsEnabled, IList<String> allowedOrigins);

        // The name of the custom scheme to register.
        string SchemeName { get; set; };

        // Whether the scheme will be treated as a secure context like https.
        bool IsSecure { get; set; };

        // If `isCorsEnabled` is set, the scheme will be allowed for requests subject to
        // CORS rules as specified in [Cross-Origin Resource Sharing - MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS).
        // If it is not set, CORS requests with this scheme will be blocked.
        bool IsCorsEnabled { get; set; };

        // List of origins that are allowed to use the scheme,
        // subject to cross origin restrictions.
        // Origins are specified as a string in the format of scheme://host:port.
        // `*` wildcard can also be used on origins.
        // For example, "http://*.example.com:80".
        // Any origin from the custom scheme itself is always allowed. If the
        // list is empty, no other origin except origins from same scheme are allowed.
        IList<String> AllowedOrigins { get; };
    }

    runtimeclass CoreWebView2EnvironmentOptions
    {
        /// The registrations of custom schemes.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions3")]
        {
            IList<CoreWebView2CustomSchemeRegistration> CustomSchemeRegistrations { get; };
        }
    }
}
```

# Appendix