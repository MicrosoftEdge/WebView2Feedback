<!-- USAGE
  * Fill in each of the sections (like Background) below
  * Wrap code with `single line of code` or ```code block```
  * Before submitting, delete all <!-- TEMPLATE marked comments in this file,
    and the following quote banner:
-->
> See comments in Markdown for how to use this spec template

<!-- TEMPLATE
  The purpose of this spec is to describe a new WebView2 feature and its APIs.

  There are two audiences for the spec. The first are people
  that want to evaluate and give feedback on the API, as part of
  the submission process. When it's complete
  it will be incorporated into the public documentation at
  learn.microsoft.com (https://learn.microsoft.com/microsoft-edge/webview2/).
  Hopefully we'll be able to copy it mostly verbatim.
  So the second audience is everyone that reads there to learn how
  and why to use this API.
-->


# Background
By default HTTP basic authentication and NTLM authentication requests inside WebView2 show the authentication UI, which is a dialog prompt in which the user can type in user name and password credentials just like in the Edge browser. We have been requested by WebView2 app developers to provide finer granularity for managing HTTP Basic/NTLM authentications inside WebView2, including the ability to hide the login UI and provide credentials.


# Description
We propose a new event for WebView2, CoreWebView2BasicAuthenticationRequested that will allow developers to listen on and override the HTTP Basic authentication requests in WebView2. When there is a HTTP Basic/NTLM authentication request in WebView2, the developer will have a choice to:
  1) Provide credentials
  2) Cancel the login altogether
  3) Ask the user for credentials via the default login prompt
We also propose CoreWebView2BasicAuthenticationResponse, the runtime class that represents the app's response with credentials to the basic authentication request.

# Examples
## Provide credentials
The developer can provide the authentication credentials on behalf of the user when it encounters the Basic authentication request. In this case, the default login dialog prompt will no longer be shown to the user. If the developer provided credentials are wrong, the server may keep responding with Unauthorized, which will lead to an infinite loop so the developer should pay attention to this.

```cpp

    CHECK_HRESULT(webview2->add_BasicAuthenticationRequested(
        Callback<ICoreWebView2BasicAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2BasicAuthenticationRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2Deferral> deferral;

                args->GetDeferral(&deferral);
                ShowCustomLoginUI().then([web_auth_args = wil::make_com_ptr(args), deferral](LPCWSTR userName, LPCWSTR password)
                {
                    wil::com_ptr<ICoreWebView2BasicAuthenticationResponse> basicAuthenticationResponse;
                    CHECK_HRESULT(web_auth_args->get_Response(&basicAuthenticationResponse));
                    CHECK_HRESULT(basicAuthenticationResponse->put_UserName(userName));
                    CHECK_HRESULT(basicAuthenticationResponse->put_Password(password));
                    deferral->Complete();
                });
                
                return S_OK;
            })
            .Get(),
        &m_BasicAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.BasicAuthenticationRequested += delegate (object sender, CoreWebView2BasicAuthenticationRequestedEventArgs args)
{
    using (CoreWebView2Deferral deferral = args.GetDeferral())
    {
        Credential credential = await ShowCustomLoginUIAsync();
        args.Response.UserName = credential.UserName;
        args.Response.Password = credential.Password;
        deferral.Complete();
    }
};
```

## Cancel authentication prompt
The developer can block the authentication request. In this case, the default login dialog prompt will no longer be shown to the user and the server will respond as if the user clicked cancel.

```cpp
    CHECK_HRESULT(webview2->add_BasicAuthenticationRequested(
        Callback<ICoreWebView2BasicAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2BasicAuthenticationRequestedEventArgs* args)
            {
                CHECK_HRESULT(args->put_Cancel(true));

                return S_OK;
            })
            .Get(),
        &m_BasicAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.BasicAuthenticationRequested += delegate (object sender, CoreWebView2BasicAuthenticationRequestedEventArgs args)
{
    args.Cancel = true;
};
```

## Read authentication challenge string
Developer can read the authentication challenge string sent by server. Note that if the developer doesn't cancel or provide a response, the default login dialog prompt will be shown to the user.

```cpp
webview2->add_BasicAuthenticationRequested(
    Callback<ICoreWebView2BasicAuthenticationRequestedEventHandler>(
        [this](
            ICoreWebView2* sender,
            ICoreWebView2BasicAuthenticationRequestedEventArgs* args)
        {
            CHECK_HRESULT(args->get_Challenge(&challenge));
            if (!ValidateChallenge(challenge.get()))
            { // Check the challenge string
                CHECK_HRESULT(args->put_Cancel(true));
            }
            return S_OK;
        })
        .Get(),
    &m_BasicAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.BasicAuthenticationRequested += delegate (object sender, CoreWebView2BasicAuthenticationRequestedEventArgs args)
{
    if (!ValidateChallenge(args.Challenge))
    {
        args.Cancel = true;
    }
};
```

# Remarks


# API Notes


# API Details
```idl
/// WebView2 enables you to host web content using the latest Microsoft Edge
/// browser and web technology.

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2_4 : ICoreWebView2_3
{
  /// ...

  /// Add an event handler for the BasicAuthenticationRequested event.
  /// BasicAuthenticationRequested event is raised when WebView encounters a Basic HTTP
  /// Authentication request as described in
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication or an NTLM authentication request.
  ///
  /// The host can provide a response with credentials for the authentication or
  /// cancel the request. If the host doesn't set the Cancel property to true or
  /// set either UserName or Password properties on the Response property, then WebView2 will show the default
  /// authentication challenge dialog prompt to the user.
  ///
  HRESULT add_BasicAuthenticationRequested(
    [in] ICoreWebView2BasicAuthenticationRequestedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_WebResourceRequested.
  HRESULT remove_BasicAuthenticationRequested(
      [in] EventRegistrationToken token);
}

/// This is the CoreWebView2BasicAuthenticationRequestedEventHandler interface
[uuid(f87e5d35-3248-406b-81dd-1c36aab8081d), object, pointer_default(unique)]
interface ICoreWebView2BasicAuthenticationRequestedEventHandler : IUnknown
{
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2BasicAuthenticationRequestedEventArgs* args);
}

/// Represents a Basic HTTP authentication response that contains a user name
/// and a password as according to RFC7617 (https://tools.ietf.org/html/rfc7617)
[uuid(bc9cfd60-29c4-4943-a83b-d0d2f3e7df03), object, pointer_default(unique)]
interface ICoreWebView2BasicAuthenticationResponse : IUnknown
{
  /// User name provided for authentication.
  [propget] HRESULT UserName([out, retval] LPWSTR* userName);
  /// Set user name property
  [propput] HRESULT UserName([in] LPCWSTR userName);

  /// Password provided for authentication.
  [propget] HRESULT Password([out, retval] LPWSTR* password);
  /// Set password property
  [propput] HRESULT Password([in] LPCWSTR password);
}

/// Event args for the BasicAuthenticationRequested event. Will contain the
/// request that led to the HTTP authentication challenge, the challenge
/// and allows the host to provide credentials response or cancel the request.
[uuid(51d3adaa-159f-4e48-ad39-a86beb2c1435), object, pointer_default(unique)]
interface ICoreWebView2BasicAuthenticationRequestedEventArgs : IUnknown
{
  /// The URI that led to the authentication challenge
  [propget] HRESULT Uri([out, retval] LPWSTR* value);

  /// The authentication challenge string
  [propget] HRESULT Challenge([out, retval] LPWSTR* challenge);

  /// Response to the authentication request with credentials. This object will be populated by the app
  /// if the host would like to provide authentication credentials.
  [propget] HRESULT Response([out, retval] ICoreWebView2BasicAuthenticationResponse** response);
  
  /// Cancel the authentication request. False by default.
  /// If set to true, Response set will be ignored.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);
  /// Set the Cancel property.
  [propput] HRESULT Cancel([in] BOOL cancel);

  /// Returns an `ICoreWebView2Deferral` object. Use this deferral to
  /// defer the decision to show the Basic Authentication dialog.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

```

```c#
namespace Microsoft.Web.WebView2.Core
{
    /// Event args for the BasicAuthenticationRequested event. Will contain the
    /// request that led to the HTTP authentication challenge, the challenge
    /// and allows the host to provide authentication response or cancel the request.
    runtimeclass CoreWebViewBasicAuthenticationRequestedEventArgs
    {
        /// The web resource request that led to the authentication challenge
        CoreWebView2WebResourceRequest Request { get; };

        /// The HTTP basic authentication challenge string
        String Challenge { get; };

        /// Cancel the authentication request. False by default.
        /// If set to true, Response will be ignored.
        bool Cancel { get; set; };

        /// Response to the authentication request with credentials. This object will be populated by the app
        /// if the host would like to provide authentication credentials.
        CoreWebView2BasicAuthenticationResponse Response { get; };

        /// Returns an `ICoreWebView2Deferral` object. Use this deferral to
        /// defer the decision to show the Basic Authentication dialog.
        CoreWebView2Deferral GetDeferral();
    }

    /// Represents a Basic HTTP authentication response that contains a user name
    /// and a password as according to RFC7617 (https://tools.ietf.org/html/rfc7617)
    runtimeclass CoreWebView2BasicAuthenticationResponse
    {
        /// User name provided for authentication.
        String UserName { get; set; }

        /// Password provided for authentication
        String Password { get; set; };
    }

    runtimeclass CoreWebView2
    {
        ...

        /// Add an event handler for the BasicAuthenticationRequested event.
        /// BasicAuthenticationRequested event is raised when WebView encountered a Basic HTTP
        /// Authentication request.
        ///
        /// The host can populate the response object with credentials it wants to use for the authentication or
        /// cancel the request. If the host doesn't handle the event, WebView will show
        /// the authentication challenge dialog prompt to user.
        ///
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebViewBasicAuthenticationRequestedEventArgs> BasicAuthenticationRequested;
    }
}
```
