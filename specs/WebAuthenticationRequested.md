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
We also propose CoreWebView2StagingWebAuthenticationResponse, the runtime class that represents the app's response with credentials to the basic authentication request.

# Examples
## Basic usage
CoreWebView2WebAuthenticationRequestedEvent follows the same event handling pattern as any other WebView2 event.

To add event handler:
```cpp
webviewStaging2->add_WebAuthenticationRequested(
    Callback<ICoreWebView2StagingWebAuthenticationRequestedEventHandler>(
        [this](
            ICoreWebView2Staging2* sender,
            ICoreWebView2StagingWebAuthenticationRequestedEventArgs* args) {
                // Handler code
                return S_OK;
            })
            .Get(),
        &m_webAuthenticationRequestedToken));
```

```c#
public OnWebAuthenticationRequested(object sender, CoreWebView2WebAuthenticationRequestedEventArgs args)
{
    // Handler code
};
webView.CoreWebView2.WebAuthenticationRequested += OnWebAuthenticationRequested;
```

To remove event handler:
```cpp
webViewStaging2->remove_WebAuthenticationRequested(m_webAuthenticationRequestedToken);
```

```c#
webView.CoreWebView2.WebAuthenticationRequested -= OnWebAuthenticationRequested;
```

## Provide credentials
The developer can provide the authentication credentials on behalf of the user when it encounters the Basic authentication request. In this case, the login dialog prompt will no longer be shown to the user. If the developer provided credentials are wrong, the server may keep responding with Unauthorized, which will lead to an infinite loop so the developer should pay attention to this.

```cpp
    webviewStaging2->add_WebAuthenticationRequested(
        Callback<ICoreWebView2StagingWebAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2Staging2* sender,
                ICoreWebView2StagingWebAuthenticationRequestedEventArgs* args) {
                wil::com_ptr<ICoreWebView2StagingEnvironment> webviewEnvironmentStaging;
                m_appWindow->GetWebViewEnvironment()->QueryInterface(
                    IID_PPV_ARGS(&webviewEnvironmentStaging));
                wil::com_ptr<ICoreWebView2StagingWebAuthenticationResponse> webAuthenticationResponse;
                webviewEnvironmentStaging->CreateWebAuthenticationResponse(
                    L"userName", L"password" , &webAuthenticationResponse);
                args->put_Response(webAuthenticationResponse.get());

                return S_OK;
            })
            .Get(),
        &m_webAuthenticationRequestedToken));
```

```c#
webView.CoreWebView2.WebAuthenticationRequested += delegate (object sender, CoreWebView2WebAuthenticationRequestedEventArgs args)
{
    CoreWebView2WebAuthenticationResponse response = _coreWebView2Environment.CreateWebAuthenticationResponse(
        "User", "Pass");
    args.Response = response;
};
```

## Cancel authentication prompt
The developer can block the authentication request. In this case, the login dialog prompt will no longer be shown to the user and the server will respond as if the user clicked cancel.

```cpp
    webviewStaging2->add_WebAuthenticationRequested(
        Callback<ICoreWebView2StagingWebAuthenticationRequestedEventHandler>(
            [this](
                ICoreWebView2Staging2* sender,
                ICoreWebView2StagingWebAuthenticationRequestedEventArgs* args) {
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
Developer can read the authorization challenge string sent by server. Note that if the developer doesn't cancel or provide a response, the login dialog prompt will be shown to the user.

```cpp
webviewStaging2->add_WebAuthenticationRequested(
    Callback<ICoreWebView2StagingWebAuthenticationRequestedEventHandler>(
        [this](
            ICoreWebView2Staging2* sender,
            ICoreWebView2StagingWebAuthenticationRequestedEventArgs* args) {
            args->get_Challenge(&challenge);
            if (wcsncmp(challenge.get(), L"Expected login credentials") != 0) {
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
/// This is the ICoreWebView2 Staging interface.
[uuid(9EAFB7D0-88C3-4450-BBFB-C05A46C40C72), object, pointer_default(unique)]
interface ICoreWebView2Staging2 : IUnknown {
  /// Add an event handler for the WebAuthenticationRequested event.
  /// WebAuthenticationRequested event fires when WebView encountered a Basic HTTP
  /// Authentication request.
  ///
  /// The host can provide a response with credentials for the authentication or
  /// cancel the request. If the host doesn't handle the event, WebView will show
  /// the authorization challenge dialog prompt to user.
  ///
  HRESULT add_WebAuthenticationRequested(
    [in] ICoreWebView2StagingWebAuthenticationRequestedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_WebResourceRequested.
  HRESULT remove_WebAuthenticationRequested(
      [in] EventRegistrationToken token);
}

/// This is the CoreWebView2WebAuthenticationRequestedEventHandler Staging interface
[uuid(f87e5d35-3248-406b-81dd-1c36aab8081d), object, pointer_default(unique)]
interface ICoreWebView2StagingWebAuthenticationRequestedEventHandler : IUnknown
{
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Staging2* sender,
      [in] ICoreWebView2StagingWebAuthenticationRequestedEventArgs* args);
}

/// Represents a Basic HTTP authentication response that contains a user name
/// and a password as according to RFC7617 (https://tools.ietf.org/html/rfc7617)
[uuid(bc9cfd60-29c4-4943-a83b-d0d2f3e7df03), object, pointer_default(unique)]
interface ICoreWebView2StagingWebAuthenticationResponse : IUnknown
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
interface ICoreWebView2StagingWebAuthenticationRequestedEventArgs : IUnknown
{
  /// The web resource request that led to the authorization challenge
  [propget] HRESULT Request([out, retval] ICoreWebView2WebResourceRequest** request);

  /// The authorization challenge string
  [propget] HRESULT Challenge([out, retval] LPWSTR* challenge);

  /// Response to the authentication request with credentials.
  [propget] HRESULT Response([out, retval] ICoreWebView2StagingWebAuthenticationResponse** response);
  /// Set the Response property.
  [propput] HRESULT Response([in] ICoreWebView2StagingWebAuthenticationResponse* response);

  /// Cancel the authentication request. False by default.
  /// If set to true, Response will be ignored.
  [propget] HRESULT Cancel([out, retval] BOOL* cancel);
  /// Set the Cancel property.
  [propput] HRESULT Cancel([in] BOOL cancel);
}

[uuid(0cec3e32-36aa-4859-9bbe-f9c116ad4721), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment : IUnknown {
  /// Create a WebAuthenticationResponse object used to provide credentials for
  /// WebAuthenticationRequested event
  HRESULT CreateWebAuthenticationResponse(
    [in] LPCWSTR userName,
    [in] LPCWSTR password,
    [out, retval] ICoreWebView2StagingWebAuthenticationResponse** response);
}

```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        ...

        /// Create a WebAuthenticationResponse object used to provide credentials for
        /// WebAuthenticationRequested event
        public CoreWebView2WebAuthenticationResponse CreateWebAuthenticationResponse(
            String userName,
            String password);
    }

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

        /// Response to the authentication request with credentials.
        CoreWebView2WebAuthenticationResponse Response { get; set; };
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
        /// WebAuthenticationRequested event fires when WebView encountered a Basic HTTP
        /// Authentication request.
        ///
        /// The host can provide a response with credentials for the authentication or
        /// cancel the request. If the host doesn't handle the event, WebView will show
        /// the authorization challenge dialog prompt to user.
        ///
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebViewWebAuthenticationRequestedEventArgs> WebAuthenticationRequested;
    }
}
```
