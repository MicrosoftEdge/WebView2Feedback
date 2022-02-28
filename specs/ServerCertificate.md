Server Certificate API
===
# Background

The WebView2 team has been asked for an API to intercept when WebView2 cannot verify a server's digital certificate while loading a web page.
This API provides an option to trust the server's TLS certificate at the application level and render the page without prompting the user about the TLS error or can cancel the request.

# Description

We propose adding `ServerCertificateErrorDetected` API that allows you to verify TLS certificates with errors, and either continue the request
to load the resource or cancel the request.

When the event is raised, WebView2 will pass a `CoreWebView2ServerCertificateErrorDetectedEventArgs` , which lets you view the TLS certificate request Uri, error information, inspect the certificate metadata and several options for responding to the TLS request.

* You can perform your own verification of the certificate and allow the request to proceed if you trust it.
* You can choose to cancel the request.
* You can choose to display the default TLS interstitial page to let user respond to the request for page navigations. For others TLS certificate is rejected and the request is cancelled.

We also propose adding a `ClearServerCertificateErrorActions` API which clears cached `COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_ALWAYS_ALLOW` response for proceeding with TLS certificate errors.

# Examples

## Win32 C++
``` cpp
// When WebView2 doesn't trust a TLS certificate but host app does, this example bypasses
// the default TLS interstitial page using the ReceivingServerCertificateError event handler and
// continues the navigation to a server. Otherwise, cancel the request.
void SettingsComponent::ToggleCustomServerCertificateSupport()
{
  auto m_webview11 = m_webview.query<ICoreWebView2_11>();
  if (m_webview11)
  {
    if (m_ServerCertificateErrorToken.value == 0)
    {
         CHECK_FAILURE(m_webview11->add_ServerCertificateErrorDetected(
             Callback<ICoreWebView2ServerCertificateErrorDetectedEventHandler>(
             [this](
               ICoreWebView2* sender,
               ICoreWebView2ServerCertificateErrorDetectedEventArgs* args) {
               COREWEBVIEW2_WEB_ERROR_STATUS errorStatus;
               CHECK_FAILURE(args->get_ErrorStatus(&errorStatus));

               wil::com_ptr<ICoreWebView2Certificate> certificate = nullptr;
               CHECK_FAILURE(args->get_ServerCertificate(&certificate));

               // Continues the request to a server with a TLS certificate if the error status   
               // is of type `COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID`
               // and trusted by the host app.
               if (errorStatus == COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID &&
                            ValidateServerCertificate(certificate.get()))
               {
                 CHECK_FAILURE(args->put_Action(
                                COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_ALWAYS_ALLOW));
               }
               else
               {
                 // Cancel the request for other TLS certificate error types or if untrusted by the host app.
                 CHECK_FAILURE(args->put_Action(
                                COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_CANCEL));
               }
               return S_OK;
             })
             .Get(),
         &m_ServerCertificateErrorToken));
    }
    else
    {
      CHECK_FAILURE(m_webview11->remove_ServerCertificateErrorDetected(
        m_ServerCertificateErrorToken));
      m_ServerCertificateErrorToken.value = 0;
    }
  }
  else
  {
    FeatureNotAvailable();
  }
}

// Function to validate the server certificate for untrusted root or self-signed certificate.
// You may also choose to defer server certificate validation.
bool ValidateServerCertificate(ICoreWebView2Certificate* certificate)
{
    // You may want to validate certificates in different ways depending on your app and scenario.
    // One way might be the following:
    // First, get the list of host app trusted certificates and its thumbprint.

    // Then get the last chain element using `ICoreWebView2Certificate::get_PemEncodedIssuerCertificateChain`
    // that contains the raw data of the untrusted root CA/self-signed certificate. Get the untrusted
    // root CA/self signed certificate thumbprint from the raw certificate data and
    // validate the thumbprint against the host app trusted certificate list.

    // Finally, return true if it exists in the host app's certificate trusted list, or otherwise return false.
    return true;
}

// This example clears `AlwaysAllow` response that are added for proceeding with TLS certificate errors.
if (m_webview11)
{
  CHECK_FAILURE(m_webview11->ClearServerCertificateErrorActions(
        Callback<
            ICoreWebView2ClearServerCertificateErrorActionsCompletedHandler>(
            [](HRESULT result) -> HRESULT {
                auto showDialog = [result] {
                                MessageBox(
                                    nullptr,
                                    (result == S_OK)
                                        ? L"Clear server certificate error actions are succeeded."
                                        : L"Clear server certificate error actions are failed.",
                                    L"Clear server certificate error actions",
                                    MB_OK);
                            };
                m_appWindow->RunAsync([showDialog]() { showDialog(); });
                return S_OK;
            })
            .Get()));
}
```
## . NET/ WinRT
```c#
// When WebView2 doesn't trust a TLS certificate but host app does, this example bypasses
// the default TLS interstitial page using the ReceivingServerCertificateError event handler and
// continues the navigation to a server. Otherwise, cancel the request.
private bool _isServerCertificateError = false;
void ToggleCustomServerCertificateSupport()
{
  if (!_isServerCertificateError)
  {
    webView.CoreWebView2.ServerCertificateErrorDetected += WebView_ServerCertificateErrorDetected;
  }
  else
  {
    webView.CoreWebView2.ServerCertificateErrorDetected -= WebView_ServerCertificateErrorDetected;
  }
  _isServerCertificateError = !_isServerCertificateError;

  MessageBox.Show(this, "Custom server certificate support has been" + 
                    (_isServerCertificateError ? "enabled" : "disabled"),
                    "Custom server certificate support");
}

void WebView_ServerCertificateErrorDetected(object sender, CoreWebView2ServerCertificateErrorDetectedEventArgs e)
{
  CoreWebView2Certificate certificate = e.ServerCertificate;

  // Continues the request to a server with a TLS certificate if the error status 
  // is of type `COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID`
  // and trusted by the host app.
  if (e.ErrorStatus == CoreWebView2WebErrorStatus.CertificateIsInvalid &&
                            ValidateServerCertificate(certificate))
  {
    e.Action = CoreWebView2ServerCertificateErrorAction.AlwaysAllow;
  }
  else
  {
    // Cancel the request for other TLS certificate error types or if untrusted by the host app.
    e.Action = CoreWebView2ServerCertificateErrorAction.Cancel;
  }
}

// Function to validate the server certificate for untrusted root or self-signed certificate.
// You may also choose to defer server certificate validation.
bool ValidateServerCertificate(CoreWebView2Certificate certificate)
{
    // You may want to validate certificates in different ways depending on your app and scenario.
    // One way might be the following:
    // First, get the list of host app trusted certificates and its thumbprint.

    // Then get the last chain element using `ICoreWebView2Certificate::get_PemEncodedIssuerCertificateChain`
    // that contains the raw data of the untrusted root CA/self-signed certificate. Get the untrusted
    // root CA/self signed certificate thumbprint from the raw certificate data and
    // validate the thumbprint against the host app trusted certificate list.

    // Finally, return true if it exists in the host app's certificate trusted list, or otherwise return false.
    return true;
}

// This example clears `AlwaysAllow` response that are added for proceeding with TLS certificate errors.
async void ClearServerCertificateErrorActions()
{
  bool isSuccessful = await webView.CoreWebView2.ClearServerCertificateErrorActionsAsync();
  MessageBox.Show(this, "message", "Clear server certificate error actions are succeeded");
}
```

# API Details

## Win32 C++
``` cpp
[v1_enum] typedef enum COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION {
  /// Indicates to ignore the warning and continue the request with the TLS
  /// certificate. This decision is cached for the RequestUri's host and the server
  /// certificate in the session.
  COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_ALWAYS_ALLOW,

  /// Indicates to reject the certificate and cancel the request.
  COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_CANCEL,

  /// Indicates to display the default TLS interstitial page to user for page navigations.
  /// For others TLS certificate is rejected and the request is cancelled.
  COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_DEFAULT
} COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION;

[uuid(4B7FF0D2-8203-48B0-ACBF-ED9CFF82567A), object, pointer_default(unique)]
interface ICoreWebView2_11 : ICoreWebView2_10 {
  /// Add an event handler for the ServerCertificateErrorDetected event.
  /// The ServerCertificateErrorDetected event is raised when the WebView2
  /// cannot verify server's digital certificate while loading a web page.
  /// 
  /// This event will raise for all web resources and follows the `WebResourceRequested` event.
  ///
  /// If you don't handle the event, WebView2 will show the default TLS interstitial page to user.
  /// 
  /// WebView2 caches the response when action is `COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_ALWAYS_ALLOW`
  /// for the RequestUri's host and the server certificate in the session and the `ServerCertificateErrorDetected` 
  /// event won't be raised again.
  /// 
  /// To raise the event again you must clear the cache using `ClearServerCertificateErrorActions`.
  ///
  /// \snippet SettingsComponent.cpp ServerCertificateErrorDetected1
  HRESULT add_ServerCertificateErrorDetected(
      [in] ICoreWebView2ServerCertificateErrorDetectedEventHandler*
          eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_ServerCertificateErrorDetected.
  HRESULT remove_ServerCertificateErrorDetected([in] EventRegistrationToken token);

  /// Clears all cached decisions to proceed with TLS certificate errors from the 
  /// ServerCertificateErrorDetected event for all WebView2's sharing the same session.
  HRESULT ClearServerCertificateErrorActions(
      [in] ICoreWebView2ClearServerCertificateErrorActionsCompletedHandler*
      handler);
}

/// Receives the result of the `ClearServerCertificateErrorActions` method. 
[uuid(2F7B173D-3CE1-4945-BDE6-94F4C57B7209), object, pointer_default(unique)]
interface ICoreWebView2ClearServerCertificateErrorActionsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode);
}

/// An event handler for the `ServerCertificateErrorDetected` event.
[uuid(AAC28793-11FC-4EE5-A8D4-25A0279B1551), object, pointer_default(unique)] 
interface ICoreWebView2ServerCertificateErrorDetectedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke([in] ICoreWebView2* sender,
                 [in] ICoreWebView2ServerCertificateErrorDetectedEventArgs*
                     args);
}

/// Event args for the `ServerCertificateErrorDetected` event.
[uuid(24EADEE7-31F9-447F-9FE7-7C13DC738C32), object, pointer_default(unique)]
interface ICoreWebView2ServerCertificateErrorDetectedEventArgs : IUnknown {
  /// The TLS error code for the invalid certificate.
  [propget] HRESULT ErrorStatus([out, retval] COREWEBVIEW2_WEB_ERROR_STATUS* value);

  /// URI associated with the request for the invalid certificate.
  [propget] HRESULT RequestUri([out, retval] LPWSTR* value);

  /// Returns the server certificate.
  [propget] HRESULT ServerCertificate([out, retval] ICoreWebView2Certificate** value);

  /// The action of the server certificate error detection.
  /// The default value is `COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION_DEFAULT`.
  [propget] HRESULT Action([out, retval] COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION* value);

  /// Sets the `Action` property.
  [propput] HRESULT Action([in] COREWEBVIEW2_SERVER_CERTIFICATE_ERROR_ACTION value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ServerCertificateErrorAction
    {
        AlwaysAllow = 0,
        Cancel = 1,
        Default = 2
    };

    runtimeclass CoreWebView2ServerCertificateErrorDetectedEventArgs
    {
        CoreWebView2WebErrorStatus ErrorStatus { get; };
        String RequestUri { get; };
        CoreWebView2Certificate ServerCertificate { get; };
        CoreWebView2ServerCertificateErrorAction Action { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_11")]
        {
          event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ServerCertificateErrorDetectedEventArgs> ServerCertificateErrorDetected;
          Windows.Foundation.IAsyncAction ClearServerCertificateErrorActionsAsync();
        }
    }
}
```
