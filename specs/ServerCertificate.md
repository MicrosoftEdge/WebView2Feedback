Server Certificate API
===
# Background

The WebView2 team has been asked for an API to intercept when WebView2 cannot verify server's digital certificate while loading a web page.
This API provides an option to trust the server's TLS certificate at the application level and render the page without prompting the user about the TLS error or can cancel the request.

# Description

We propose adding `ReceivingServerCertificateError` API that allows you to verify TLS certificate,  and either continue the request
to load the resource or cancel the request.

When the event is raised, WebView2 will pass a `CoreWebView2ReceivingServerCertificateErrorEventArgs` , which lets you view the TLS certificate request Uri, error information, inspect the certificate metadata and several options for responding to the TLS request.

* You can perform your own verification of the certificate and allow the navigation to proceed if you trust it.
* You can choose to cancel the request.
* You can choose to display the default TLS interstitial page to let user respond to the request.

We also propose adding a `ClearServerCertificateErrorOverrideCache` API that clears certificate decisions that were added in response to proceeding with TLS certificate errors.

# Examples

## Win32 C++
``` cpp
// When WebView2 doesn't trust a TLS certificate but host app does, this example bypasses
// the default TLS interstitial page using the ReceivingServerCertificateError event handler and
// continues the navigation to a server. Otherwise, cancel the request.
void SettingsComponent::EnableCustomServerCertificateError()
{
  if (m_webview)
  {
    if (m_ServerCertificateErrorToken.value == 0)
    {
         CHECK_FAILURE(m_webview->add_ReceivingServerCertificateError(
             Callback<ICoreWebView2ReceivingServerCertificateErrorEventHandler>(
             [this](
               ICoreWebView2* sender,
               ICoreWebView2ReceivingServerCertificateErrorEventArgs* args) {
               COREWEBVIEW2_WEB_ERROR_STATUS errorStatus;
               CHECK_FAILURE(args->get_ErrorStatus(&errorStatus));

               wil::com_ptr<ICoreWebView2Certificate> certificate = nullptr;
               CHECK_FAILURE(args->get_ServerCertificate(&certificate));

               // Continues with the navigation to a server with a TLS certificate if
               // the error status is of type `COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID`
               // and trusted by the host app.
               if (errorStatus == COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID &&
                            ValidateServerCertificate(certificate.get()))
               {
                 CHECK_FAILURE(args->put_Handled(TRUE));
               }
               else
               {
                 // Cancel the request for other TLS certificate error types or if untrusted by the host app.
                 CHECK_FAILURE(args->put_Cancel(TRUE));
               }
               return S_OK;
             })
             .Get(),
         &m_ServerCertificateErrorToken));
    }
    else
    {
      CHECK_FAILURE(m_webview->remove_ReceivingServerCertificateError(
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

// This example clears the TLS decision in response to proceeding with TLS certificate errors.
if (m_webview)
{
  CHECK_FAILURE(m_webView->ClearServerCertificateErrorOverrideCache(
        Callback<
            ICoreWebView2ClearServerCertificateErrorOverrideCacheCompletedHandler>(
            [](HRESULT error, PCWSTR result) -> HRESULT {
                CHECK_FAILURE(error);
                if (error != S_OK)
                {
                  ShowFailure( error,  L"Clear server certificate error override cache failed");
                }
                MessageBox(nullptr, L"Cleared", L"Clear server certificate error override cache", MB_OK);
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
void EnableCustomServerCertificateError()
{
  if (!_isServerCertificateError)
  {
    webView.CoreWebView2.ReceivingServerCertificateError += WebView_ReceivingServerCertificateError;
  }
  else
  {
    webView.CoreWebView2.ReceivingServerCertificateError -= WebView_ReceivingServerCertificateError;
  }
  _isServerCertificateError = !_isServerCertificateError;

  MessageBox.Show(this,
    _isServerCertificateError ? "Custom server certificate error has been enabled" : "Custom server certificate error has been disabled",
    "Custom server certificate error");
}

void WebView_ReceivingServerCertificateError(object sender, CoreWebView2ReceivingServerCertificateErrorEventArgs e)
{
  CoreWebView2Certificate certificate = e.ServerCertificate;

  // Continues with the navigation to a server with a TLS certificate if
  // the error status is of type `COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID`
  // and trusted by the host app.
  if (e.ErrorStatus == CoreWebView2WebErrorStatus.CertificateIsInvalid &&
                            ValidateServerCertificate(certificate))
  {
    e.Handled = true;
  }
  else
  {
    // Cancel the request for other TLS certificate error types or if untrusted by the host app.
    e.Cancel = true;
  }
}

// Function to validate the server certificate for untrusted root or self-signed certificate.
bool ValidateServerCertificate(CoreWebView2Certificate certificate)
{
    // Get the list of host app trusted certificates and its thumbprint.

    // Get last chain element using `PemEncodedIssuerCertificateChain` property of `CoreWebView2Certificate`
    // that contain raw data of untrusted root CA/self signed certificate. Get the untrusted
    // root CA/self signed certificate thumbprint from the raw certificate data and
    // validate thumbprint against the host app trusted certificate list.

    // Return true if it exist in host app certificate trusted list, otherwise return false.
    return true;
}

// This example clears the TLS decision in response to proceeding with TLS certificate errors.
async void ClearServerCertificateErrorOverrideCache()
{
  await webView.CoreWebView2.ClearServerCertificateErrorOverrideCacheAsync();
  MessageBox.Show(this, "Cleared", "Clear server certificate error override cache");
}
```

# API Details

## Win32 C++
``` cpp
[uuid(4B7FF0D2-8203-48B0-ACBF-ED9CFF82567A), object, pointer_default(unique)]
interface ICoreWebView2_11 : ICoreWebView2_10 {
  /// Add an event handler for the ServerCertificateError event.
  /// The ServerCertificateError event is raised when the WebView2
  /// cannot verify server's digital certificate while loading a web page.
  ///
  /// This event will raise only for top-level navigations as WebView2 block or cancel the
  /// request for sub resources with server certificate error. Also, this event follows
  /// the `NavigationStarting` event and comes before the `SourceChanged` event.
  ///
  /// With this event you have several options for responding to server
  /// certificate error requests:
  ///
  /// Scenario                                                   | Handled | Cancel
  /// ---------------------------------------------------------- | ------- | ------
  /// Ignore the warning and continue the request                | True    | False
  /// Cancel the request                                         | n/a     | True
  /// Display default TLS interstitial page                      | False   | False
  ///
  /// If you don't handle the event, WebView2 will show the default TLS interstitial page to user.
  ///
  /// WebView2 caches the response when `Handled` is `TRUE` for the RequestUri's host and the server certificate in the session
  /// and the `ReceivingServerCertificateError` event won't be raised again for this host and certificate.
  ///
  /// To raise the event again you must clear the cache using `ClearServerCertificateErrorOverrideCache`.
  ///
  ///
  /// \snippet SettingsComponent.cpp ServerCertificateError1
  HRESULT add_ReceivingServerCertificateError(
      [in] ICoreWebView2ReceivingServerCertificateErrorEventHandler* eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_ReceivingServerCertificateError.
  HRESULT remove_ReceivingServerCertificateError([in] EventRegistrationToken token);

  /// Clears all cached decisions to proceed with TLS certificate errors from the
  /// ReceivingServerCertificateError event for all WebView2's sharing the same session.
  HRESULT ClearServerCertificateErrorOverrideCache(
      [in] ICoreWebView2ClearServerCertificateErrorOverrideCacheCompletedHandler*
      handler);
}

/// Receives the result of the `ClearServerCertificateErrorOverrideCache` method.
[uuid(2F7B173D-3CE1-4945-BDE6-94F4C57B7209), object, pointer_default(unique)]
interface ICoreWebView2ClearServerCertificateErrorOverrideCacheCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode, BOOL isSuccessful);
}

/// An event handler for the `ReceivingServerCertificateError` event.
[uuid(AAC28793-11FC-4EE5-A8D4-25A0279B1551), object, pointer_default(unique)]
interface ICoreWebView2ReceivingServerCertificateErrorEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke([in] ICoreWebView2* sender,
                 [in] ICoreWebView2ReceivingServerCertificateErrorEventArgs*
                     args);
}

/// Event args for the `ReceivingServerCertificateError` event.
[uuid(24EADEE7-31F9-447F-9FE7-7C13DC738C32), object, pointer_default(unique)]
interface ICoreWebView2ReceivingServerCertificateErrorEventArgs : IUnknown {
  /// The TLS error code for the invalid certificate.
  [propget] HRESULT ErrorStatus([out, retval] COREWEBVIEW2_WEB_ERROR_STATUS* value);

  /// URI associated with the request for the invalid certificate.
  [propget] HRESULT RequestUri([out, retval] LPWSTR* value);

  /// Returns the server certificate.
  [propget] HRESULT ServerCertificate([out, retval] ICoreWebView2Certificate** value);

  /// You may set this flag to cancel the request. The request is canceled regardless
  /// of the `Handled` property. By default the value is `FALSE`.
  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL value);

  /// You may set this flag to `TRUE` to continue the request with the TLS certificate.
  /// By default the value of `Handled` and `Cancel` are `FALSE` and display default TLS
  /// interstitial page to allow the user to take the decision.
  [propget] HRESULT Handled([out, retval] BOOL* value);

  /// Sets the `Handled` property.
  [propput] HRESULT Handled([in] BOOL value);

  /// Returns an `ICoreWebView2Deferral` object. Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ReceivingServerCertificateErrorEventArgs
    {
        CoreWebView2WebErrorStatus ErrorStatus { get; };
        String RequestUri { get; };
        CoreWebView2Certificate ServerCertificate { get; };
        Boolean Cancel { get; set; };
        Boolean Handled { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        // ...
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_11")]
        {
          event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ReceivingServerCertificateErrorEventArgs> ReceivingServerCertificateError;
          void ClearServerCertificateErrorOverrideCacheAsync();
        }
    }
}
```
