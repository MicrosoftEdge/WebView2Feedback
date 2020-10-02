# Background

Cookie management in WebView has been one of the top feature requests. With that, the WebView2 team has introduced a new set of APIs allowing end developers to achieve goals such as authenticating the webview session, or retrieving cookies from webview to authenticate other tools.

# Description

One can get the `CookieManager` associated with a WebView to `GetCookies` via a `CookieList` collection, `AddOrUpdateCookie`, `DeleteCookies`, and `DeleteAllCookies` in a WebView environment.

# Examples

The following code snippet demonstrates how the cookie management APIs can be use:

## Win32 C++

```cpp
ScenarioCookieManagement::ScenarioCookieManagement(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [CookieManager]
    CHECK_FAILURE(m_webView->get_CookieManager(&m_cookieManager));
    //! [CookieManager]

    CHECK_FAILURE(m_webView->add_WebMessageReceived(
        Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) {
                wil::unique_cotaskmem_string uri;
                CHECK_FAILURE(args->get_Source(&uri));

                // Always validate that the origin of the message is what you expect.
                if (uri.get() != m_sampleUri)
                {
                    return S_OK;
                }
                wil::unique_cotaskmem_string messageRaw;
                CHECK_FAILURE(args->TryGetWebMessageAsString(&messageRaw));
                std::wstring message = messageRaw.get();
                std::wstring reply;

                if (message.compare(0, 11, L"GetCookies ") == 0)
                {
                    GetCookiesHelper(message.substr(11));
                    reply =
                        L"{\"CookiesGot\":\"" + GetCookiesHelper(message.substr(11)) + L"\"}";
                    CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                }
                else if (message.compare(0, 10, L"AddOrUpdateCookie ") == 0)
                {
                    message = message.substr(10);
                    std::wstring name = message.substr(0, message.find(' '));
                    std::wstring value = message.substr(message.find(' ') + 1);

                    //! [AddOrUpdateCookie]
                    wil::com_ptr<ICoreWebView2Cookie> cookie;
                    CHECK_FAILURE(m_cookieManager->CreateCookie(
                        name.c_str(), value.c_str(), L".bing.com", L"/", &cookie));
                    CHECK_FAILURE(m_cookieManager->AddOrUpdateCookie(cookie.get()));
                    reply = L"{\"CookieAddedOrUpdated\":\"Cookie added or updated successfully.\"}";
                    CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                    //! [AddOrUpdateCookie]
                }
                else if (message.compare(0, 16, L"ClearAllCookies ") == 0)
                {
                    CHECK_FAILURE(m_cookieManager->DeleteAllCookies());
                    reply = L"{\"CookiesDeleted\":\"Cookies all deleted.\"}";
                    CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                }
                return S_OK;
            })
            .Get(),
        &m_webMessageReceivedToken));
}

static std::wstring CookieToJsonString(ICoreWebView2Cookie* cookie)
{
    //! [CookieObject]
    wil::unique_cotaskmem_string name;
    CHECK_FAILURE(cookie->get_Name(&name));
    wil::unique_cotaskmem_string value;
    CHECK_FAILURE(cookie->get_Value(&value));
    wil::unique_cotaskmem_string domain;
    CHECK_FAILURE(cookie->get_Domain(&domain));
    wil::unique_cotaskmem_string path;
    CHECK_FAILURE(cookie->get_Path(&path));
    double expires;
    CHECK_FAILURE(cookie->get_Expires(&expires));
    BOOL httpOnly = FALSE;
    CHECK_FAILURE(cookie->get_IsHttpOnly(&httpOnly));
    COREWEBVIEW2_COOKIE_SAME_SITE_KIND same_site;
    std::wstring same_site_as_string;
    CHECK_FAILURE(cookie->get_SameSite(&same_site));
    switch (same_site)
    {
    case COREWEBVIEW2_COOKIE_SAME_SITE_KIND_NONE:
        same_site_as_string = L"None";
        break;
    case COREWEBVIEW2_COOKIE_SAME_SITE_KIND_LAX:
        same_site_as_string = L"Lax";
        break;
    case COREWEBVIEW2_COOKIE_SAME_SITE_KIND_STRICT:
        same_site_as_string = L"Strict";
        break;
    }
    BOOL secure = FALSE;
    CHECK_FAILURE(cookie->get_IsSecure(&secure));
    BOOL isSession = FALSE;
    CHECK_FAILURE(cookie->get_IsSession(&isSession));

    std::wstring result = L"{";
    result += L"\"Name\": " + EncodeQuote(name.get()) + L", " + L"\"Value\": " +
              EncodeQuote(value.get()) + L", " + L"\"Domain\": " + EncodeQuote(domain.get()) +
              L", " + L"\"Path\": " + EncodeQuote(path.get()) + L", " + L"\"HttpOnly\": " +
              BoolToString(httpOnly) + L", " + L"\"Secure\": " + BoolToString(secure) + L", " +
              L"\"SameSite\": " + EncodeQuote(same_site_as_string) + L", " + L"\"Expires\": ";
    if (!!isSession)
    {
        result += L"This is a session cookie.";
    }
    else
    {
        result += std::to_wstring(expires);
    }

    return result + L"\"}";
    //! [CookieObject]
}

void ScenarioCookieManagement::GetCookiesHelper(std::wstring uri)
{
    //! [GetCookies]
    if (m_cookieManager)
    {
        CHECK_FAILURE(m_cookieManager->GetCookies(
            uri.c_str(),
            Callback<ICoreWebView2GetCookiesCompletedHandler>(
                [this, uri](HRESULT error_code, ICoreWebView2CookieList* list) -> HRESULT {
                    CHECK_FAILURE(error_code);

                    std::wstring result;
                    UINT cookie_list_size;
                    CHECK_FAILURE(list->get_Count(&cookie_list_size));

                    if (cookie_list_size == 0)
                    {
                        result += L"No cookies found.";
                    }
                    else
                    {
                        result += std::to_wstring(cookie_list_size) + L" cookie(s) found on " +
                                  uri + L".";
                        result += L"\n\n[";
                        for (int i = 0; i < cookie_list_size; ++i)
                        {
                            wil::com_ptr<ICoreWebView2Cookie> cookie;
                            CHECK_FAILURE(list->GetValueAtIndex(i, &cookie));

                            if (cookie.get())
                            {
                                result += CookieToJsonString(cookie.get());
                                if (i != cookie_list_size - 1)
                                {
                                    result += L",\n";
                                }
                            }
                        }
                        result += L"]";
                    }
                    MessageBox(nullptr, result.c_str(), L"GetCookies Result", MB_OK);
                    return S_OK;
                })
                .Get()));
    }
    //! [GetCookies]
}
```

## .NET and WinRT

```c#
void AddOrUpdateCookieCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    CoreWebView2Cookie cookie = webView.CoreWebView2.CookieManager.CreateCookie("CookieName", "CookieValue", ".bing.com", "/");
    cookie.SameSite = CoreWebView2CookieSameSiteKind.None;
    webView.CoreWebView2.CookieManager.AddOrUpdateCookie(cookie);
}

async void GetCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    IList<CoreWebView2Cookie> cookieList = await webView.CoreWebView2.CookieManager.GetCookiesAsync("https://www.bing.com");
    for (uint i = 0; i < cookieList.Count; ++i)
    {
        CoreWebView2Cookie cookie = cookieList[i];
        Cookie systemNetCookie = cookie.ToSystemNetCookie();
        Console.WriteLine(systemNetCookie.ToString());
    }
}

void DeleteAllCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.CookieManager.DeleteAllCookies();
}

void DeleteCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    webView.CoreWebView2.CookieManager.DeleteCookies("CookieName", "https://www.bing.com");
}
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2_2;
interface ICoreWebView2Cookie;
interface ICoreWebView2CookieList;
interface ICoreWebView2CookieManager;
interface ICoreWebView2GetCookiesCompletedHandler;

/// Kind of cookie SameSite status used in the ICoreWebView2Cookie interface.
/// These fields match those as specified in https://developer.mozilla.org/docs/Web/HTTP/Cookies#.
/// Learn more about SameSite cookies here: https://tools.ietf.org/html/draft-west-first-party-cookies-07
[v1_enum]
typedef enum COREWEBVIEW2_COOKIE_SAME_SITE_KIND {
  /// None SameSite type. No restrictions on cross-site requests.
  COREWEBVIEW2_COOKIE_SAME_SITE_KIND_NONE,
  /// Lax SameSite type. The cookie will be sent with "same-site" requests, and with "cross-site" top level navigation.
  COREWEBVIEW2_COOKIE_SAME_SITE_KIND_LAX,
  /// Strict SameSite type. The cookie will only be sent along with "same-site" requests.
  COREWEBVIEW2_COOKIE_SAME_SITE_KIND_STRICT,
} COREWEBVIEW2_COOKIE_SAME_SITE_KIND;

[uuid(20113081-93BD-4F2A-86B9-ADF92DEAAF10), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
  // ...

  /// Gets the cookie manager object associated with this ICoreWebView2.
  [propget] HRESULT CookieManager([out, retval] ICoreWebView2CookieManager** cookieManager);
}

/// Provides a set of properties that are used to manage an
/// ICoreWebView2Cookie.
[uuid(0AD66B3B-316F-4F54-8472-F5FF54360A60), object, pointer_default(unique)]
interface ICoreWebView2Cookie : IUnknown {
  /// Cookie name.
  [propget] HRESULT Name([out, retval] LPWSTR* name);

  /// Cookie value.
  [propget] HRESULT Value([out, retval] LPWSTR* value);
  /// Set the cookie value property.
  [propput] HRESULT Value([in] LPCWSTR value);

  /// The domain for which the cookie is valid.
  /// The default is the host that this cookie has been received from.
  /// Note that, for instance, ".bing.com", "bing.com", and "www.bing.com" are
  /// considered different domains.
  [propget] HRESULT Domain([out, retval] LPWSTR* domain);

  /// The path for which the cookie is valid. The default is "/", which means
  /// this cookie will be sent to all pages on the Domain.
  [propget] HRESULT Path([out, retval] LPWSTR* path);

  /// The expiration date and time for the cookie as the number of seconds since the UNIX epoch.
  /// The default is -1.0, which means cookies are session cookies by default.
  [propget] HRESULT Expires([out, retval] double* expires);
  /// Set the Expires property. Cookies are session cookies
  /// and will not be persistent if Expires is negative.
  [propput] HRESULT Expires([in] double expires);

  /// Whether this cookie is http-only.
  /// True if a page script or other active content cannot access this
  /// cookie. The default is false.
  [propget] HRESULT IsHttpOnly([out, retval] BOOL* isHttpOnly);
  /// Set the IsHttpOnly property.
  [propput] HRESULT IsHttpOnly([in] BOOL isHttpOnly);

  /// SameSite status of the cookie which represents the enforcement mode of the cookie.
  /// The default is COREWEBVIEW2_COOKIE_SAME_SITE_KIND_LAX.
  [propget] HRESULT SameSite([out, retval] COREWEBVIEW2_COOKIE_SAME_SITE_KIND* sameSite);
  /// Set the SameSite property.
  [propput] HRESULT SameSite([in] COREWEBVIEW2_COOKIE_SAME_SITE_KIND sameSite);

  /// The security level of this cookie. True if the client is only to return
  /// the cookie in subsequent requests if those requests use HTTPS.
  /// The default is false.
  /// Note that cookie that requests COREWEBVIEW2_COOKIE_SAME_SITE_KIND_NONE but
  /// is not marked Secure will be rejected.
  [propget] HRESULT IsSecure([out, retval] BOOL* isSecure);
  /// Set the IsSecure property.
  [propput] HRESULT IsSecure([in] BOOL isSecure);

  /// Whether this is a session cookie. The default is false.
  [propget] HRESULT IsSession([out, retval] BOOL* isSession);
}

/// Creates, adds or updates, gets, or or view the cookies. The changes would
/// apply to the context of the user profile. That is, other WebViews under the
/// same user profile could be affected.
[uuid(588C8A15-A28A-4FFD-926B-5E6EE7449E7C), object, pointer_default(unique)]
interface ICoreWebView2CookieManager : IUnknown {
  /// Create a cookie object with a specified name, value, domain, and path.
  /// One can set other optional properties after cookie creation.
  /// This only creates a cookie object and it is not added to the cookie
  /// manager until you call AddOrUpdateCookie.
  /// See ICoreWebView2Cookie for more details.
  HRESULT CreateCookieWithDetails(
    [in] LPCWSTR name,
    [in] LPCWSTR value,
    [in] LPCWSTR domain,
    [in] LPCWSTR path,
    [out, retval] ICoreWebView2Cookie** cookie);

  /// Creates a cookie whose params matches those of the specified cookie.
  HRESULT CreateCookie(
    [in] ICoreWebView2Cookie* cookieParam,
    [out, retval] ICoreWebView2Cookie** cookie);

  /// Gets a list of cookies matching the specific URI.
  /// If uri is empty string or null, all cookies under the same profile are
  /// returned.
  /// You can modify the cookie objects, call
  /// ICoreWebView2CookieManager::AddOrUpdateCookie, and the changes
  /// will be applied to the webview.
  HRESULT GetCookies(
    [in] LPCWSTR uri,
    [in] ICoreWebView2GetCookiesCompletedHandler* handler);

  /// Adds or updates a cookie with the given cookie data; may overwrite
  /// cookies with matching name, domain, and path if they exist.
  HRESULT AddOrUpdateCookie([in] ICoreWebView2Cookie* cookie);

  /// Deletes a cookie whose name and domain/path pair
  /// match those of the specified cookie.
  HRESULT DeleteCookie([in] ICoreWebView2Cookie* cookie);

  /// Deletes cookies with matching name and uri.
  /// Cookie name is required.
  /// If uri is specified, deletes all cookies with the given name where domain
  /// and path match provided URI.
  HRESULT DeleteCookies([in] LPCWSTR name, [in] LPCWSTR uri);

  /// Deletes cookies with matching name and domain/path pair.
  /// Cookie name is required.
  /// If domain is specified, deletes only cookies with the exact domain.
  /// If path is specified, deletes only cookies with the exact path.
  HRESULT DeleteCookiesWithDomainAndPath([in] LPCWSTR name, [in] LPCWSTR domain, [in] LPCWSTR path);

  /// Deletes all cookies under the same profile.
  /// This could affect other WebViews under the same user profile.
  HRESULT DeleteAllCookies();
}

/// A list of cookie objects. See ICoreWebView2Cookie.
[uuid(02F758AF-2F1C-4263-A5F8-37CA875B40D1), object, pointer_default(unique)]
interface ICoreWebView2CookieList : IUnknown {
  /// The number of cookies contained in the ICoreWebView2CookieList.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Get the cookie object at the given index.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] ICoreWebView2Cookie** cookie);
}

/// The caller implements this method to receive the result of the
/// GetCookies method. The result is written to the cookie list provided in
/// the GetCookies method call.
[uuid(0AD3D432-69E9-4223-9CC4-460C20BDCEF5), object, pointer_default(unique)]
interface ICoreWebView2GetCookiesCompletedHandler : IUnknown {
  /// Called to provide the implementer with the completion status
  /// of the corresponding asynchronous method call.
  HRESULT Invoke(HRESULT result, ICoreWebView2CookieList* cookieList);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    /// Kind of cookie SameSite status used in the CoreWebView2Cookie class.
    /// These fields match those as specified in https://developer.mozilla.org/docs/Web/HTTP/Cookies#.
    /// Learn more about SameSite cookies here: https://tools.ietf.org/html/draft-west-first-party-cookies-07
    enum CoreWebView2CookieSameSiteKind
    {
        /// None SameSite type. No restrictions on cross-site requests.
        None = 0,
        /// Lax SameSite type. The cookie will be sent with "same-site" requests, and with "cross-site" top level navigation.
        Lax = 1,
        /// Strict SameSite type. The cookie will only be sent along with "same-site" requests.
        Strict = 2,
    };

    runtimeclass CoreWebView2
    {
        /// Gets the cookie manager object associated with this CoreWebView2.
        CoreWebView2CookieManager CookieManager { get; };

        // ...
    }

    /// Creates, adds or updates, gets, or or view the cookies. The changes would
    /// apply to the context of the user profile. That is, other WebViews under the
    /// same user profile could be affected.
    runtimeclass CoreWebView2CookieManager
    {
        /// Create a cookie object with a specified name, value, domain, and path.
        /// One can set other optional properties after cookie creation.
        /// This only creates a cookie object and it is not added to the cookie
        /// manager until you call AddOrUpdateCookie.
        CoreWebView2Cookie CreateCookieWithDetails(String name, String value, String Domain, String Path);

        /// Creates a cookie whose params matches those of the specified cookie.
        CoreWebView2Cookie CreateCookie(CoreWebView2 cookie);

        /// Gets a list of cookies matching the specific URI.
        /// If uri is empty string or null, all cookies under the same profile are
        /// returned.
        /// You can modify the cookie objects, call
        /// CoreWebView2CookieManager.AddOrUpdateCookie, and the changes
        /// will be applied to the webview.
        Windows.Foundation.IAsyncOperation<IVectorView> GetCookiesAsync(String uri);

        /// Adds or updates a cookie with the given cookie data; may overwrite
        /// cookies with matching name, domain, and path if they exist.
        void AddOrUpdateCookie(CoreWebView2Cookie cookie);

        /// Deletes a cookie whose name and domain/path pair
        /// match those of the specified cookie.
        void DeleteCookie(CoreWebView2Cookie cookie);

        /// Deletes cookies with matching name and uri.
        /// Cookie name is required.
        /// If uri is specified, deletes all cookies with the given name where domain
        /// and path match provided URI.
        void DeleteCookies(String name, String uri);

        /// Deletes cookies with matching name and domain/path pair.
        /// Cookie name is required.
        /// If domain is specified, deletes only cookies with the exact domain.
        /// If path is specified, deletes only cookies with the exact path.
        void DeleteCookiesWithDomainAndPath(String name, String Domain, String Path);

        /// Deletes all cookies under the same profile.
        /// This could affect other WebViews under the same user profile.
        void DeleteAllCookies();
    }

    /// Provides a set of properties that are used to manage a CoreWebView2Cookie.
    runtimeclass CoreWebView2Cookie
    {
        /// Cookie name.
        String Name { get; };

        /// Cookie value.
        String Value { get; set; };

        /// The domain for which the cookie is valid.
        /// The default is the host that this cookie has been received from.
        /// Note that, for instance, ".bing.com", "bing.com", and "www.bing.com" are
        /// considered different domains.
        String Domain { get; };

        /// The path for which the cookie is valid. The default is "/", which means
        /// this cookie will be sent to all pages on the Domain.
        String Path { get; };

        /// The expiration date and time for the cookie as the number of seconds since the UNIX epoch.
        /// The default is -1.0, which means cookies are session cookies by default.
        Windows.Foundation.DateTime Expires { get; set; };

        /// Whether this cookie is http-only.
        /// True if a page script or other active content cannot access this
        /// cookie. The default is false.
        Boolean IsHttpOnly { get; set; };

        /// SameSite status of the cookie which represents the enforcement mode of the cookie.
        /// The default is CoreWebView2CookieSameSiteKind.Lax.
        CoreWebView2CookieSameSiteKind SameSite { get; set; };

        /// The security level of this cookie. True if the client is only to return
        /// the cookie in subsequent requests if those requests use HTTPS.
        /// The default is false.
        /// Note that cookie that requests CoreWebView2CookieSameSiteKind.None but
        /// is not marked Secure will be rejected.
        Boolean IsSecure { get; set; };

        /// Whether this is a session cookie. The default is false.
        Boolean IsSession { get; };

        /// Converts a System.Net.Cookie to a CoreWebView2Cookie.
        /// This is only for the .NET API, not the WinRT API.
        static CoreWebView2Cookie FromSystemNetCookie(System.Net.Cookie dotNetCookie);

        /// Converts a CoreWebView2Cookie to a System.Net.Cookie.
        /// This is only for the .NET API, not the WinRT API.
        System.Net.Cookie ToSystemNetCookie(CoreWebView2Cookie coreWebView2Cookie);
    }

    // ...
}
```
