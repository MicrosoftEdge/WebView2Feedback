# Background

Cookie management in WebView has been one of the top feature requests. With that, the WebView2 team has introduced a new set of APIs allowing end developers to achieve goals such as authenticating the webview session, or retrieving cookies from webview to authenticate other tools.

# Description

One can create a `CookieManager` off a WebView to `GetCookies` via a `CookieList` collection, `SetCookie`, `DeleteCookies`, and `ClearAllCookies` in a WebView environment.

# Examples

The following code snippet demonstrates how the cookie management APIs can be use:

## Win32 C++

```cpp
ScenarioCookieManagement::ScenarioCookieManagement(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [CreateCookieManager]
    CHECK_FAILURE(m_webView->CreateCookieManager(&m_cookieManager));
    //! [CreateCookieManager]

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
                else if (message.compare(0, 10, L"SetCookie ") == 0)
                {
                    message = message.substr(10);
                    std::wstring name = message.substr(0, message.find(' '));
                    std::wstring value = message.substr(message.find(' ') + 1);

                    //! [SetCookie]
                    wil::com_ptr<ICoreWebView2Cookie> cookie;
                    CHECK_FAILURE(m_cookieManager->CreateCookie(
                        name.c_str(), value.c_str(), L".bing.com", L"/", &cookie));
                    CHECK_FAILURE(m_cookieManager->SetCookie(cookie.get()));
                    reply = L"{\"CookieSet\":\"Cookie set successfully.\"}";
                    CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                    //! [SetCookie]
                }
                else if (message.compare(0, 16, L"ClearAllCookies ") == 0)
                {
                    CHECK_FAILURE(m_cookieManager->ClearAllCookies());
                    reply = L"{\"CookiesCleared\":\"Cookies cleared.\"}";
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
    BOOL httpOnly;
    CHECK_FAILURE(cookie->get_HttpOnly(&httpOnly));
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
    BOOL secure;
    CHECK_FAILURE(cookie->get_Secure(&secure));

    std::wstring result = L"{";
    result += L"\"Name\": " + EncodeQuote(name.get()) + L", " + L"\"Value\": " +
              EncodeQuote(value.get()) + L", " + L"\"Domain\": " + EncodeQuote(domain.get()) +
              L", " + L"\"Path\": " + EncodeQuote(path.get()) + L", " + L"\"HttpOnly\": " +
              BoolToString(httpOnly) + L", " + L"\"Secure\": " + BoolToString(secure) + L", " +
              L"\"SameSite\": " + EncodeQuote(same_site_as_string) + L", " + L"\"Expires\": ";
    if (expires == -1)
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
                    CHECK_FAILURE(list->get_Size(&cookie_list_size));

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
CoreWebView2CookieManager _cookieManager;

private void WebView_CoreWebView2Ready(object sender, EventArgs e)
{
    _cookieManager = webView.CoreWebView2.CreateCookieManager();
}

void SetCookieCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    CoreWebView2Cookie cookie = _cookieManager.CreateCookie("CookieName", "CookieValue", ".bing.com", "/");
    cookie.SameSite = CoreWebView2CookieSameSiteKind.None;
    _cookieManager.SetCookie(cookie);
}

async void GetCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    CoreWebView2CookieList cookieList = await _cookieManager.GetCookiesAsync("https://www.bing.com");
    for (uint i = 0; i < cookieList.Size; ++i)
    {
        CoreWebView2Cookie cookie = cookieList.GetValueAtIndex(i);
        Console.WriteLine(CookieAsString(cookie));
    }

}

void ClearAllCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    _cookieManager.ClearAllCookies();
}

void DeleteCookiesCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    _cookieManager.DeleteCookies("CookieName", "https://www.bing.com", "", "");
}
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2;
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
interface ICoreWebView2 : IUnknown {
  /// Create a new cookie manager object. See ICoreWebView2CookieManager.
  HRESULT CreateCookieManager([out, retval] ICoreWebView2CookieManager** cookieManager);
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
  [propget] HRESULT Domain([out, retval] LPWSTR* domain);

  /// The path for which the cookie is valid. If not specified, this cookie
  /// will be sent to all pages on the Domain.
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
  [propget] HRESULT HttpOnly([out, retval] BOOL* httpOnly);
  /// Set the HttpOnly property.
  [propput] HRESULT HttpOnly([in] BOOL httpOnly);

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
  [propget] HRESULT Secure([out, retval] BOOL* secure);
  /// Set the Secure property.
  [propput] HRESULT Secure([in] BOOL secure);
}

/// Add or delete an ICoreWebView2Cookie or ICoreWebView2Cookies,
/// or view the cookies. The changes would apply to the context of the user profile.
/// That is, other WebViews under the same user profile could be affected.
[uuid(588C8A15-A28A-4FFD-926B-5E6EE7449E7C), object, pointer_default(unique)]
interface ICoreWebView2CookieManager : IUnknown {
  /// Create a cookie object with a specified name, value, domain, and path.
  /// One can set other optional properties after cookie creation.
  /// See ICoreWebView2Cookie for more details.
  HRESULT CreateCookie(
    [in] LPCWSTR name,
    [in] LPCWSTR value,
    [in] LPCWSTR domain,
    [in] LPCWSTR path,
    [out, retval] ICoreWebView2Cookie** cookie);

  /// Gets a list of cookies matching the specific URI.
  /// You can modify the cookie objects, call
  /// ICoreWebView2CookieManager::SetCookie, and the changes
  /// will be applied to the webview.
  HRESULT GetCookies(
    [in] LPCWSTR uri,
    [in] ICoreWebView2GetCookiesCompletedHandler* handler);

  /// Sets a cookie with the given cookie data; may overwrite equivalent cookies
  /// if they exist.
  HRESULT SetCookie([in] ICoreWebView2Cookie* cookie);

  /// Deletes browser cookies with matching name and uri or domain/path pair.
  /// Cookie name is required.
  /// If uri is specified, deletes all cookies with the given name where domain
  /// and path match provided URI.
  /// If domain is specified, deletes only cookies with the exact domain.
  /// If path is specified, deletes only cookies with the exact path.
  HRESULT DeleteCookies([in] LPCWSTR name, [in] LPCWSTR uri, [in] LPCWSTR domain, [in] LPCWSTR path);

  /// Clears all cookies under the same profile.
  /// This could affect other WebViews under the same user profile.
  HRESULT ClearAllCookies();
}

/// A list of cookie objects. See ICoreWebView2Cookie.
[uuid(02F758AF-2F1C-4263-A5F8-37CA875B40D1), object, pointer_default(unique)]
interface ICoreWebView2CookieList : IUnknown {
  /// The number of cookies contained in the ICoreWebView2CookieList.
  [propget] HRESULT Size([out, retval] UINT* size);

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
        /// Create a new cookie manager object.
        CoreWebView2CookieManager CreateCookieManager();
    }

    /// Add or delete an CoreWebView2Cookie or CoreWebView2Cookies,
    /// or view the cookies. The changes would apply to the context of the user profile.
    /// That is, other WebViews under the same user profile could be affected.
    runtimeclass CoreWebView2CookieManager
    {
        /// Create a cookie object with a specified name, value, domain, and path.
        /// One can set other optional properties after cookie creation.
        CoreWebView2Cookie CreateCookie(String name, String value, String Domain, String Path);

        /// Gets a list of cookies matching the specific URI.
        /// You can modify the cookie objects, call
        /// CoreWebView2CookieManager.SetCookie, and the changes
        /// will be applied to the webview.
        Windows.Foundation.IAsyncOperation<CoreWebView2CookieList> GetCookiesAsync(String uri);

        /// Sets a cookie with the given cookie data; may overwrite equivalent cookies
        /// if they exist.
        void SetCookie(CoreWebView2Cookie cookie);

        /// Deletes browser cookies with matching name and uri or domain/path pair.
        /// Cookie name is required.
        /// If uri is specified, deletes all cookies with the given name where domain
        /// and path match provided URI.
        /// If domain is specified, deletes only cookies with the exact domain.
        /// If path is specified, deletes only cookies with the exact path.
        void DeleteCookies(String name, String uri, String Domain, String Path);

        /// Clears all cookies under the same profile.
        /// This could affect other WebViews under the same user profile.
        void ClearAllCookies();
    }

    /// A list of cookie objects.
    runtimeclass CoreWebView2CookieList
    {
        /// The number of cookies contained in the CoreWebView2CookieList.
        UInt32 Size { get; };

        /// Get the cookie object at the given index.
        CoreWebView2Cookie GetValueAtIndex(UInt32 index);
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
        String Domain { get; };

        /// The path for which the cookie is valid. If not specified, this cookie
        /// will be sent to all pages on the Domain.
        String Path { get; };

        /// The expiration date and time for the cookie as the number of seconds since the UNIX epoch.
        /// The default is -1.0, which means cookies are session cookies by default.
        Double Expires { get; set; };

        /// Whether this cookie is http-only.
        /// True if a page script or other active content cannot access this
        /// cookie. The default is false.
        Int32 HttpOnly { get; set; };

        /// SameSite status of the cookie which represents the enforcement mode of the cookie.
        /// The default is CoreWebView2CookieSameSiteKind.Lax.
        CoreWebView2CookieSameSiteKind SameSite { get; set; };

        /// The security level of this cookie. True if the client is only to return
        /// the cookie in subsequent requests if those requests use HTTPS.
        /// The default is false.
        /// Note that cookie that requests CoreWebView2CookieSameSiteKind.None but
        /// is not marked Secure will be rejected.
        Int32 Secure { get; set; };
    }
}
```
