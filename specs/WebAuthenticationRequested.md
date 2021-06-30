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
  docs.microsoft.com (https://docs.microsoft.com/en-us/microsoft-edge/webview2/).
  Hopefully we'll be able to copy it mostly verbatim.
  So the second audience is everyone that reads there to learn how
  and why to use this API.
-->


# Background
By default HTTP basic authentication requests inside WebView2 show the authentication UI, which is a dialog prompt in which the user can type in user name and password credentials just like in the Edge browser. We have been requested by WebView2 app developers to provide finer granularity for managing HTTP Basic authentications inside WebView2, including the ability to hide the login UI and provide credentials.


# Description
We propose a new event for WebView2, CoreWebView2WebAuthenticationRequested that will allow developers to listen on and override the HTTP Basic authentication requests in WebView2. When there is a HTTP Basic authentication request in WebView2, the developer will have a choice to:
  1) Provide credentials
  2) Cancel the login altogether
  3) Ask the user for credentials via the default login prompt
We also propose CoreWebView2WebAuthenticationResponse, the runtime class that represents the app's response with credentials to the basic authentication request.

# Examples
## Provide credentials
The developer can provide the authentication credentials on behalf of the user when it encounters the Basic authentication request. In this case, the default login dialog prompt will no longer be shown to the user. If the developer provided credentials are wrong, the server may keep responding with Unauthorized, which will lead to an infinite loop so the developer should pay attention to this.

```cpp

    webview2->add_WebAuthenticationRequested(
        Callback<ICoreWebView2WebAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2WebAuthenticationRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2Environment> webviewEnvironment;
                m_appWindow->GetWebViewEnvironment()->QueryInterface(
                    IID_PPV_ARGS(&webviewEnvironment));
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                wil::com_ptr<ICoreWebView2WebAuthenticationRequestedEventArgs> web_auth_args = args;
                args->GetDeferral(&deferral);
                ShowCustomLoginUI().then([web_auth_args, deferral](LPCWSTR userName, LPCWSTR password) {
                    wil::com_ptr<ICoreWebView2WebAuthenticationResponse> webAuthenticationResponse;
                    args->get_Response(&webAuthenticationResponse);
                    webAuthenticationResponse->put_UserName(userName);
                    webAuthenticationResponse->put_Password(password);
                    deferral->Complete();
                }
                
                return S_OK;
            })
            .Get(),
        &m_webAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.WebAuthenticationRequested += delegate (object sender, CoreWebView2WebAuthenticationRequestedEventArgs args)
{
    CoreWebView2Deferral deferral = args.GetDeferral();
    Credential credential = await ShowCustomLoginUIAsync();
    args.Response.UserName = credential.UserName;
    args.Response.Password = credential.Password;
    deferral.Complete();
};
```

## Cancel authentication prompt
The developer can block the authentication request. In this case, the default login dialog prompt will no longer be shown to the user and the server will respond as if the user clicked cancel.

```cpp
    webview2->add_WebAuthenticationRequested(
        Callback<ICoreWebView2WebAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2WebAuthenticationRequestedEventArgs* args)
            {
                args->put_Cancel(true);

                return S_OK;
            })
            .Get(),
        &m_webAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.WebAuthenticationRequested += delegate (object sender, CoreWebView2WebAuthenticationRequestedEventArgs args)
{
    args.Cancel = true;
};
```

## Read authorization challenge string
Developer can read the authorization challenge string sent by server. Note that if the developer doesn't cancel or provide a response, the default login dialog prompt will be shown to the user.

```cpp
webview2->add_WebAuthenticationRequested(
    Callback<ICoreWebView2WebAuthenticationRequestedEventHandler>(
        [this](
            ICoreWebView2* sender,
            ICoreWebView2WebAuthenticationRequestedEventArgs* args)
        {
            args->get_Challenge(&challenge);
            if (!ValidateChallenge(challenge.get())) { // Check the challenge string
                args->put_Cancel(true);
            }
            return S_OK;
        })
        .Get(),
    &m_webAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.WebAuthenticationRequested += delegate (object sender, CoreWebView2WebAuthenticationRequestedEventArgs args)
{
    if (args.Challenge.Equals("Expected login credentials")) {
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

  /// Add an event handler for the WebAuthenticationRequested event.
  /// WebAuthenticationRequested event is raised when WebView encounters a Basic HTTP
  /// Authentication request as described in
  /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication.
  ///
  /// The host can provide a response with credentials for the authentication or
  /// cancel the request. If the host doesn't set the Cancel property to true or
  /// populate the Response property, then WebView2 will show the default
  /// authorization challenge dialog prompt to the user.
  ///
  HRESULT add_WebAuthenticationRequested(
    [in] ICoreWebView2WebAuthenticationRequestedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_WebResourceRequested.
  HRESULT remove_WebAuthenticationRequested(
      [in] EventRegistrationToken token);
}

/// This is the CoreWebView2WebAuthenticationRequestedEventHandler interface
[uuid(f87e5d35-3248-406b-81dd-1c36aab8081d), object, pointer_default(unique)]
interface ICoreWebView2WebAuthenticationRequestedEventHandler : IUnknown
{
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2WebAuthenticationRequestedEventArgs* args);
}

/// Represents a Basic HTTP authentication response that contains a user name
/// and a password as according to RFC7617 (https://tools.ietf.org/html/rfc7617)
[uuid(bc9cfd60-29c4-4943-a83b-d0d2f3e7df03), object, pointer_default(unique)]
interface ICoreWebView2WebAuthenticationResponse : IUnknown
{
  /// User name provided for authorization.
  [propget] HRESULT UserName([out, retval] LPWSTR* userName);
  /// Set user name property
  [propput] HRESULT UserName([in] LPCWSTR userName);

  /// Password provided for authorization
  [propget] HRESULT Password([out, retval] LPWSTR* password);
  /// Set password property
  [propput] HRESULT Password([in] LPCWSTR password);
}

/// Event args for the WebAuthorizationRequested event. Will contain the
/// request that led to the HTTP authorization challenge, the challenge
/// and allows the host to provide authentication response or cancel the request.
[uuid(51d3adaa-159f-4e48-ad39-a86beb2c1435), object, pointer_default(unique)]
interface ICoreWebView2WebAuthenticationRequestedEventArgs : IUnknown
{
  /// The web resource request that led to the authorization challenge
  [propget] HRESULT Request([out, retval] ICoreWebView2WebResourceRequest** request);

  /// The authorization challenge string
  [propget] HRESULT Challenge([out, retval] LPWSTR* challenge);

  /// Response to the authentication request with credentials. This object will be populated by the app
  /// if the host would like to provide authentication credentials.
  [propget] HRESULT Response([out, retval] ICoreWebView2WebAuthenticationResponse** response);
  
  /// Cancel the authentication request. False by default.
  /// If set to true, Response set will be ignored.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);
  /// Set the Cancel property.
  [propput] HRESULT Cancel([in] BOOL cancel);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}

```

```c#
namespace Microsoft.Web.WebView2.Core
{
    /// Event args for the WebAuthorizationRequested event. Will contain the
    /// request that led to the HTTP authorization challenge, the challenge
    /// and allows the host to provide authentication response or cancel the request.
    runtimeclass CoreWebViewWebAuthenticationRequestedEventArgs
    {
        /// The web resource request that led to the authorization challenge
        CoreWebView2WebResourceRequest Request { get; };

        /// The HTTP basic authorization challenge string
        String Challenge { get; };

        /// Cancel the authentication request. False by default.
        /// If set to true, Response will be ignored.
        bool Cancel { get; set; };

        /// Response to the authentication request with credentials. This object will be populated by the app
        /// if the host would like to provide authentication credentials.
        CoreWebView2WebAuthenticationResponse Response { get; };
    }

    /// Represents a Basic HTTP authentication response that contains a user name
    /// and a password as according to RFC7617 (https://tools.ietf.org/html/rfc7617)
    runtimeclass CoreWebView2WebAuthenticationResponse
    {
        /// User name provided for authorization.
        String UserName { get; set; }

        /// Password provided for authorization
        String Password { get; set; };
    }

    runtimeclass CoreWebView2
    {
        ...

        /// Add an event handler for the WebAuthenticationRequested event.
        /// WebAuthenticationRequested event is raised when WebView encountered a Basic HTTP
        /// Authentication request.
        ///
        /// The host can populate the response object with credentials it wants to use for the authentication or
        /// cancel the request. If the host doesn't handle the event, WebView will show
        /// the authorization challenge dialog prompt to user.
        ///
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebViewWebAuthenticationRequestedEventArgs> WebAuthenticationRequested;
    }
}
```
