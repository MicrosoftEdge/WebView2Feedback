RegisterCustomScheme
===

# Background
Currently the WebResourceRequested event is not raised for non-http(s) URIs.
Spartan WebView has built-in support for ms-appx* URIs and support of providing
an IUriToStreamResolver parameter in NavigateToLocalStreamUri. Raising the
CoreWebView2.WebResourceRequested for custom scheme URIs would close the
functional gap between WebView1 and WebView2 as the app can just provide a
WebResourceResponse for a given custom scheme URI.

To be able to provide the ability to raise WebResourceRequested for custom
schemes, WebView2 needs to be able to know how to treat such custom scheme URIs.
By the W3C standard, custom schemes have opaque origins and do not participate
in security policies. However, in order to make web requests with custom schemes
useful, some of these URIs would need to act more like HTTP URIs, while keeping
security in mind. The following questions arise:

- Are custom scheme URIs considered secure contexts?
- Which origins should be able to issue requests for these custom schemes to
  prevent an untrusted origin from reading trusted data from the app?

As a result, we introduce a new API to be able to register custom schemes and
allow the end developer to answer these questions as a part of registration.

# Conceptual pages (How To)

WebResourceRequested event can also be raised for custom schemes. For this, the
app has to register the custom schemes it would like to be able to issue
resource requests for. With each registration, the app will specify whether the
URIs with such schemes are considered [secure
context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)
and it will also need to explicitly specify the origins that are allowed to make
requests to these custom scheme URIs to ensure that untrusted origins cannot
read trusted data from the app. The registrations are valid throughout the
lifetime of the CoreWebView2Environment and browser process and any other
CoreWebView2Environments that share the browser process must register exactly
same schemes to be able to create a CoreWebView2Environment. The registered
custom schemes also participate in
[CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) and
[CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP).

For each custom scheme the developer wants to register they can:
- Set it to be a secure context scheme to prevent insecure content warnings.
- Provide a list of origins that can make requests to the custom scheme.

# Examples

## CustomSchemeRegistrations

The following code sample registers 2 custom schemes on the
CoreWebView2EnvironmentOptions:

- Scheme 1 has https://*.example.com in its allowed origins list.
- Scheme 2 has a null allowed origins list.

It adds a WebResourceRequested handler for the requests to the custom schemes,
which will serve the requests locally. Then it navigates the WebView2 to
https://www.example.com and attempts to use XMLHttpRequest (XHR) with both
schemes. Only XHR to scheme 1 will succeed because it's the one that has
https://www.example.com in its allowed origin list.
``` c#
CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions();
string[] allowedOriginsList = new string[1];
allowedOriginsList[0] = "https://*.example.com";
string customScheme = "custom-scheme";
string customSchemeNotInAllowedOrigins = "custom-scheme-not-in-allowed-origins";

options.CustomSchemeRegistrations.Add(
  new CoreWebView2CustomSchemeRegistration(customScheme)
  {
    TreatAsSecure = true,
    AllowedOrigins = { "https://*.example.com" },
    HasAuthorityComponent = true
  });
options.CustomSchemeRegistrations.Add(
  new CoreWebView2CustomSchemeRegistration(customSchemeNotInAllowedOrigins)
  {
    TreatAsSecure = true
  });

// Custom scheme registrations are validated here. In case invalid array is
// passed, the environment creation task will throw InvalidArgumentException.
auto environmentCreation = CoreWebView2Environment.CreateAsync(
  CoreWebView2EnvironmentOptions options: options);
...

webView.CoreWebView2.AddWebResourceRequestedFilter(
        customScheme + ":*", CoreWebView2WebResourceContext.All);
webView.CoreWebView2.AddWebResourceRequestedFilter(
        customSchemeNotInAllowedOrigins + ":*",
        CoreWebView2WebResourceContext.All);
webView.CoreWebView2.WebResourceRequested += delegate (
            object sender, CoreWebView2WebResourceRequestedEventArgs e)
{
    CoreWebView2WebResourceRequest request = e.Request;
    String uri = request.Uri;
    if (uri.StartsWith(customScheme + ":") ||
        uri.StartsWith(customSchemeNotInAllowedOrigins))
    {
        String assetsFilePath = "data/";
        assetsFilePath += uri.Substring(customScheme.Length + 1);
        try {
            FileStream fileStream = new FileStream(assetsFilePath,
                                                FileMode.Open,
                                                FileAccess.Read);
            e.Response = webView.CoreWebView2.Environment.
              CreateWebResourceResponse(
                fileStream,
                200,
                "OK",
                @"Content-Type: application/json\n
                Access-Control-Allow-Origin: *");
        }
        catch (IOException) {
            e.Response = webView.CoreWebView2.Environment.
              CreateWebResourceResponse(
                null,
                404,
                "Not Found",
                "");
        }
    }
}

webView.CoreWebView2.Navigate("https://www.example.com");

// The following XHR will execute in the context of https://www.example.com page
// and will succeed.
// WebResourceRequested event will be raised for this request as *.example.com
// is in the allowed origin list of custom-scheme.
// Since the response header provided in WebResourceRequested handler allows all
// origins for CORS the XHR succeeds.
webView.CoreWebView2.ExecuteScriptAsync(
    @"var oReq = new XMLHttpRequest();
    oReq.addEventListener(""load"", reqListener);
    oReq.open(""GET\"", ""custom-scheme://domain/example-data.json"");
    oReq.send();");
// The following XHR will fail because *.example.com is in the not allowed
// origin list of custom-scheme2. The WebResourceRequested event will not be
// raised for this request.
webView.CoreWebView2.ExecuteScriptAsync(
    @"var oReq = new XMLHttpRequest();
    oReq.addEventListener(""load"", reqListener);
    oReq.open(""GET"", ""custom-scheme-not-in-allowed-origins:example-data.json"");
    oReq.send();");
```

``` cpp
#include <WebView2EnvironmentOptions.h> // CoreWebView2CustomSchemeRegistration
                                        // is implemented here

...

Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions3> options3;
if (options.As(&options3) == S_OK) {
  std::vector<Microsoft::WRL::ComPtr<ICoreWebView2CustomSchemeRegistration>>
    schemeRegistrations;

  const WCHAR* allowedOrigins[1] = {L"https://*.example.com"};
  schemeRegistrations.push_back(
    Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(
          L"custom-scheme",
          TRUE /* treatAsSecure*/,
          1,
          allowedOrigins,
          TRUE /* hasAuthorityComponent */));
  schemeRegistrations.push_back(
    Microsoft::WRL::Make<CoreWebView2CustomSchemeRegistration>(
          L"custom-scheme-not-in-allowed-origins-list",
          TRUE /* treatAsSecure*/,
          nullptr,
          FALSE /* hasAuthorityComponent */));
  CHECK_FAILURE(options3->SetCustomSchemeRegistrations(
    schemeRegistrations.size(), schemeRegistrations.data()));
}

// Custom scheme registrations are validated here. In case invalid array is
// passed, this will return E_INVALIDARGS and fail to create the environment.
HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        subFolder, m_userDataFolder.c_str(), options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get());

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
        if (wcsncmp(
          uri.get(),
          L"custom-scheme",
          ARRAYSIZE(L"custom-scheme")-1) == 0)
        {
            std::wstring assetsFilePath = L"data/";
            assetsFilePath += wcsstr(uri.get(), L":") + 1;
            wil::com_ptr<IStream> stream;
            SHCreateStreamOnFileEx(
                assetsFilePath.c_str(), STGM_READ, FILE_ATTRIBUTE_NORMAL, FALSE,
                nullptr,
                &stream);
            if (stream)
            {
                CHECK_FAILURE(
                    m_appWindow->GetWebViewEnvironment()->
                      CreateWebResourceResponse(
                        stream.get(),
                        200,
                        L"OK",
                        L"Content-Type: application/json\n"
                        L"Access-Control-Allow-Origin: *",
                        &response));
                CHECK_FAILURE(args->put_Response(response.get()));
            }
            else
            {
                CHECK_FAILURE(
                    m_appWindow->GetWebViewEnvironment()->
                      CreateWebResourceResponse(
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

// The following XHR will execute in the context of https://www.example.com page
// and will succeed. WebResourceRequested event will be raised for this request
// as *.example.com is in the allowed origin list of custom-scheme.
// Since the response header provided in WebResourceRequested handler allows all
// origins for CORS the XHR succeeds.
CHECK_FAILURE(m_webView->ExecuteScript(
                  L"var oReq = new XMLHttpRequest();"
                  L"oReq.addEventListener(\"load\", reqListener);"
                  L"oReq.open(\"GET\", \"custom-scheme://domain/example-data.json\");"
                  L"oReq.send();",
                  Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                    [](HRESULT error, PCWSTR result) -> HRESULT {
                      return S_OK;
                    }).Get()));
// The following XHR will fail because *.example.com is not in the allowed
// origin list of custom-scheme2. The WebResourceRequested event will not be
// raised for this request.
CHECK_FAILURE(m_webView->ExecuteScript(
                  L"var oReq = new XMLHttpRequest();"
                  L"oReq.addEventListener(\"load\", reqListener);"
                  L"oReq.open(\"GET\",\"custom-scheme-not-in-allowed-origins:example-data.json\");"
                  L"oReq.send();",
                  Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                    [](HRESULT error, PCWSTR result) -> HRESULT {
                      return S_OK;
                    }).Get()));
```

# API Details

## COM API

```c#
// This is the ICoreWebView2CustomSchemeRegistration interface
// This represents the registration of a custom scheme with the
// CoreWebView2Environment.
// This allows the WebView2 app to be able to handle
// WebResourceRequested event for requests with the specified scheme and
// be able to navigate the WebView2 to the custom scheme. Once the environment
// is created, the registrations are valid and immutable throughout the
// lifetime of the associated WebView2s' browser process and any WebView2
// environments sharing the browser process must be created with identical
// custom scheme registrations (order does not matter), otherwise the
// environment creation will fail.
// If there are multiple entries for the same scheme in the registrations
// list, the environment creation will also fail.
// The URIs of registered custom schemes will be treated similar to http URIs
// for their origins.
// They will have tuple origins for URIs with authority component and opaque origins for
// URIs without authority component as specified in
/// [7.5 Origin - HTML Living Standard](https://html.spec.whatwg.org/multipage/origin.html)
// Example:
// custom-scheme-with-authority://hostname/path/to/resource has origin of
// custom-scheme-with-authority://hostname
// custom-scheme-without-authority:path/to/resource has origin of
// custom-scheme-without-authority:path/to/resource
// For WebResourceRequested event, the cases of request URIs and filter URIs
// with custom schemes will be normalized according to generic URI syntax
// rules. Any non-ASCII characters will be preserved.
// The registered custom schemes also participate in
// [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) and adheres
// to [CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP). The app
// needs to set the appropriate access headers in its WebResourceRequested
// event handler to allow CORS requests.
[uuid(d60ac92c-37a6-4b26-a39e-95cfe59047bb), object, pointer_default(unique)]
interface ICoreWebView2CustomSchemeRegistration : IUnknown {
  // The name of the custom scheme to register.
  [propget] HRESULT SchemeName([out, retval] LPCWSTR* schemeName);
  [propput] HRESULT SchemeName([in] LPCWSTR value);

  // Whether the sites with this scheme will be treated as a
  // [Secure Context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)
  // like a HTTPS site.
  // `false` by default.
  [propget] HRESULT TreatAsSecure([out, retval] BOOL* treatAsSecure);
  // Set if the scheme will be treated as a Secure Context.
  [propput] HRESULT TreatAsSecure([in] BOOL value);

  // List of origins that are allowed to issue requests with the custom
  // scheme.
  // Except origins with this same custom scheme, which are always
  // allowed, the origin of any request (requests that have the
  // [Origin header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin))
  // to the custom scheme URI needs to be in this list. No-origin requests
  // are requests that do not have an Origin header, such as link
  // navigations, embedded images and are always allowed.
  // Note that cross-origin restrictions still apply.
  // If the list is empty, no cross-origin request to this scheme is
  // allowed.
  // Origins are specified as a string in the format of
  // scheme://host:port.
  // The origins are string pattern matched with `*` (matches 0 or more
  // characters) and `?` (matches 0 or 1 character) wildcards just like
  // the URI matching in the
  // [AddWebResourceRequestedFilter API](https://docs.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addwebresourcerequestedfilter).
  // For example, "http://*.example.com:80".
  // The returned strings and the array itself must be deallocated with
  // CoTaskMemFree.
  HRESULT GetAllowedOrigins(
    [out] UINT32* allowedOriginsCount,
    [out] LPCWSTR** allowedOrigins);
  // Set the array of origins that are allowed to use the scheme.
  HRESULT SetAllowedOrigins(
    [in] UINT32 allowedOriginsCount,
    [in] LPCWSTR* allowedOrigins);

  // Set this property to `true` if the URIs with this custom
  // scheme will have an authority component (a host for custom schemes).
  // Specifically, if you have a URI of the following form you should set the
  // `HasAuthorityComponent` value as listed.
  // | URI | Recommended HasAuthorityComponent value |
  // | -- | -- |
  // | ` custom-scheme-with-authority://host/path` | `true` |
  // | `custom-scheme-without-authority:path` | `false` |
  // When this property is set to `true`, the URIs with this scheme will be
  // interpreted as having a
  // [scheme and host](https://html.spec.whatwg.org/multipage/origin.html#concept-origin-tuple)
  // origin similar to an http URI. Note that the port and user
  // information are never included in the computation of origins for
  // custom schemes.
  // If this property is set to `false`, URIs with this scheme will have an
  // [opaque origin](https://html.spec.whatwg.org/multipage/origin.html#concept-origin-opaque)
  // similar to a data URI.
  // This property is `false` by default.
  //
  // Note: For custom schemes registered as having authority component,
  // navigations to URIs without authority of such custom schemes will fail.
  // However, if the content inside WebView2 references
  // a subresource with a URI that does not have
  // an authority component, but of a custom scheme that is registered as
  // having authority component, the URI will be interpreted as a relative path
  // as specified in [RFC3986](https://www.rfc-editor.org/rfc/rfc3986).
  // For example, custom-scheme-with-authority:path will be interpreted
  // as custom-scheme-with-authority://host/path
  // However, this behavior cannot be guaranteed to remain in future
  // releases so it is recommended not to rely on this behavior.
  [propget] HRESULT HasAuthorityComponent([out, retval] BOOL* hasAuthorityComponent);
  // Get has authority component
  [propput] HRESULT HasAuthorityComponent([in] BOOL  hasAuthorityComponent);
}

// This is the ICoreWebView2EnvironmentOptions3 interface
[uuid(ac52d13f-0d38-475a-9dca-876580d6793e), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : IUnknown {
  // Array of custom scheme registrations. The returned
  // ICoreWebView2CustomSchemeRegistration pointers must be released, and the
  // array itself must be deallocated with CoTaskMemFree.
  HRESULT GetCustomSchemeRegistrations(
      [out] UINT32* count,
      [out] ICoreWebView2CustomSchemeRegistration*** schemeRegistrations);
  // Set the array of custom scheme registrations to be used.
  HRESULT SetCustomSchemeRegistrations(
      [in] UINT32 count,
      [in] const ICoreWebView2CustomSchemeRegistration** schemeRegistrations);
}
```

## WinRT API
```c#
namespace Microsoft.Web.WebView2.Core
{
    // Represents the registration of a custom scheme with the
    // CoreWebView2Environment.
    // This allows the WebView2 app to be able to handle WebResourceRequested
    // event for requests with the specified scheme and be able to navigate the
    // WebView2 to the custom scheme. Once the environment is created, the
    // registrations are valid and immutable throughout the lifetime of the
    // associated WebView2s' browser process and any WebView2 environments
    // sharing the browser process must be created with identical custom scheme
    // registrations, otherwise the environment creation will fail.
    // Any further attempts to register the same scheme will fail during environment creation.
    // The URIs of registered custom schemes will be treated similar to http
    // URIs for their origins.
    // They will have tuple origins for URIs with host and opaque origins for
    // URIs without host as specified in
    // [7.5 Origin - HTML Living Standard](https://html.spec.whatwg.org/multipage/origin.html)
    // Example:
    // `custom-scheme-with-host://hostname/path/to/resource` has origin of
    // `custom-scheme-with-host://hostname`
    // `custom-scheme-without-host:path/to/resource` has origin of
    // `custom-scheme-without-host:path/to/resource`
    // For WebResourceRequested event, the cases of request URIs and filter URIs
    // with custom schemes will be normalized according to generic URI syntax
    // rules. Any non-ASCII characters will be preserved.
    // The registered custom schemes also participate in
    // [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) and
    // adheres to [CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP).
    // The app needs to set the appropriate access headers in its
    // WebResourceRequested event handler to allow CORS requests.
    runtimeclass CoreWebView2CustomSchemeRegistration
    {
        // Constructor
        CoreWebView2CustomSchemeRegistration(String schemeName);

        // The name of the custom scheme to register.
        String SchemeName { get; };

        // Whether the scheme will be treated as a
        // [Secure Context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)
        // like https.
        Boolean TreatAsSecure { get; set; } = false;

        // List of origins that are allowed to issue requests with the custom
        // scheme.
        // Except origins with this same custom scheme, which are always
        // allowed, the origin of any request (requests that have the
        // [Origin header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin))
        // to the custom scheme URI needs to be in this list. No-origin requests
        // are requests that do not have an Origin header, such as link
        // navigations, embedded images and are always allowed.
        // Note that cross-origin restrictions still apply.
        // If the list is empty, no cross-origin request to this scheme is
        // allowed.
        // Origins are specified as a string in the format of
        // scheme://host:port.
        // The origins are string pattern matched with `*` (matches 0 or more
        // characters) and `?` (matches 0 or 1 character) wildcards just like
        // the URI matching in the
        // [AddWebResourceRequestedFilter API](https://docs.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.addwebresourcerequestedfilter).
        // For example, "http://*.example.com:80".
        IVector<String> AllowedOrigins { get; } = {};

        // Set this property to `true` if the URIs with this custom
        // scheme will have an authority component (a host for custom schemes).
        // Specifically, if you have a URI of the following form you should set the
        // `HasAuthorityComponent` value as listed.
        // | URI | Recommended HasAuthorityComponent value |
        // | -- | -- |
        // | ` custom-scheme-with-authority://host/path` | `true` |
        // | `custom-scheme-without-authority:path` | `false` |
        // When this property is set to `true`, the URIs with this scheme will be
        // interpreted as having a
        // [scheme and host](https://html.spec.whatwg.org/multipage/origin.html#concept-origin-tuple)
        // origin similar to an http URI. Note that the port and user
        // information are never included in the computation of origins for
        // custom schemes.
        // If this property is set to `false`, URIs with this scheme will have an
        // [opaque origin](https://html.spec.whatwg.org/multipage/origin.html#concept-origin-opaque)
        // similar to a data URI.
        // This property is `false` by default.
        //
        // Note: For custom schemes registered as having authority component,
        // navigations to URIs without authority of such custom schemes will fail.
        // However, if the content inside WebView2 references
        // a subresource with a URI that does not have
        // an authority component, but of a custom scheme that is registered as
        // having authority component, the URI will be interpreted as a relative path
        // as specified in [RFC3986](https://www.rfc-editor.org/rfc/rfc3986).
        // For example, custom-scheme-with-authority:path will be interpreted
        // as custom-scheme-with-authority://host/path
        // However, this behavior cannot be guaranteed to remain in future
        // releases so it is recommended not to rely on this behavior.
        Boolean HasAuthorityComponent {get; set; } = false;
    }

    runtimeclass CoreWebView2EnvironmentOptions
    {
        /// The registrations of custom schemes.
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions3")]
        {
            // List of custom scheme registrations.
            IVector<CoreWebView2CustomSchemeRegistration>
              CustomSchemeRegistrations { get; };
        }
    }
}
```

# Appendix