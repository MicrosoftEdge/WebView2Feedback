Server Certificate API
===
# Background

The WebView2 team has been asked for an API to intercept when WebView2 notifies a user about the risk of loading a web page.
This API provides an option to trust the certificate at application level to render the page without prompting the user
about the SSL error or can cancel the request.

# Description

We propose adding `ReceivingServerCertificateError` API that allows you to verify SSL certificate,  and either continue the request
to load the resource or cancel the request.

When the event is raised, WebView2 will pass a `CoreWebView2ReceivingServerCertificateErrorEventArgs` , which lets
you to view the SSL certificate request URL, error information, inspect the certificate metadata and several options
for responding to the SSL request.

* You can verify the certificate and proceed the request if you trust.
* You can choose to cancel the request.
* You can choose to display default SSL interstitial page to let user to respond to the request.

We also propose adding `ClearSSLDecision` API that clears certificate decisions that were added in response to proceeding with SSL certificate errors.

# Examples

## Win32 C++
``` cpp
// This example bypass default SSL interstitial page using ReceivingServerCertificateError
// event handler and to continue with the SSL certificate that is signed by an authority
// that WebView2 don't trust. Otherwise, cancel the request.
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

               if (errorStatus == COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID)
               {
                 // Continue the request with the SSL certificate.
                 CHECK_FAILURE(args->put_Handled(TRUE));
               }
               else
               {
                 // Cancel the request.
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

// This example clears the SSL decision in response to proceeding with SSL certificate errors.
if (m_webview)
{
  CHECK_FAILURE(m_webView->ClearSSLDecision());
  MessageBox(nullptr, L"Cleared", L"Clear SSL Decision", MB_OK);
}
```
## . NET/ WinRT
```c#
// This example bypass default SSL interstitial page using ReceivingServerCertificateError
// event handler and to continue with the SSL certificate that is signed by an authority
// that WebView2 don't trust. Otherwise, cancel the request.
private bool _isServerCertificateError = false;
void EnableCustomServerCertificateError()
{
  // Safeguarding the handler when unsupported runtime is used.
  try
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
  catch (NotImplementedException exception)
  {
    MessageBox.Show(this, "Custom server certificate error Failed: " + exception.Message, "Custom server certificate error");
  }
}

void WebView_ReceivingServerCertificateError(object sender, CoreWebView2ReceivingServerCertificateErrorEventArgs e)
{
  if (e.ErrorStatus == CoreWebView2WebErrorStatus.CertificateIsInvalid)
  {
    // Continue the request with the SSL certificate.
    e.Handled = true;
  }
  else
  {
    // Cancel the request.
    e.Cancel = true;
  }
}

// This example clears the SSL decision in response to proceeding with SSL certificate errors.
void ClearSSLDecision()
{
  webView.CoreWebView2.ClearSSLDecision();
  MessageBox.Show(this, "Cleared", "Clear SSL Decision");
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
  /// With this event you have several options for responding to server
  /// certificate error requests:
  ///
  /// Scenario                                                   | Handled | Cancel
  /// ---------------------------------------------------------- | ------- | ------
  /// Ignore the warning and continue the request                | True    | False
  /// Cancel the request                                         | n/a     | True
  /// Display default SSL interstitial page                      | False   | False
  ///
  /// If you don't handle the event, WebView2 will show the default SSL interstitial page to user.
  ///
  /// \snippet SettingsComponent.cpp ServerCertificateError1
  HRESULT add_ReceivingServerCertificateError(
      [in] ICoreWebView2ReceivingServerCertificateErrorEventHandler* eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_ReceivingServerCertificateError.
  HRESULT remove_ReceivingServerCertificateError([in] EventRegistrationToken token);

  /// Clears the SSL decision in response to proceeding with SSL certificate errors.
  HRESULT ClearSSLDecision();
}

/// An event handler for the `ReceivingServerCertificateError` event.
[uuid(AAC28793-11FC-4EE5-A8D4-25A0279B1551), object, pointer_default(unique)]
interface ICoreWebView2ReceivingServerCertificateErrorEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke([in] ICoreWebView2 * sender,
                 [in] ICoreWebView2ReceivingServerCertificateErrorEventArgs *
                     args);
}

/// Event args for the `ReceivingServerCertificateError` event.
[uuid(24EADEE7-31F9-447F-9FE7-7C13DC738C32), object, pointer_default(unique)]
interface ICoreWebView2ReceivingServerCertificateErrorEventArgs : IUnknown {
  /// The SSL error code for the invalid certificate.
  [propget] HRESULT ErrorStatus([out, retval] COREWEBVIEW2_WEB_ERROR_STATUS* value);

  /// URL associated with the request for the invalid certificate.
  [propget] HRESULT RequestURL([out, retval] LPWSTR* value);

  /// Returns the server certificate.
  [propget] HRESULT ServerCertificate([out, retval] ICoreWebView2Certificate** value);

  /// You may set this flag to cancel the request. The request is canceled regardless
  /// of the `Handled` property. By default the value is `FALSE`.
  [propget] HRESULT Cancel([out, retval] BOOL* value);

  /// Sets the `Cancel` property.
  [propput] HRESULT Cancel([in] BOOL value);

  /// You may set this flag to `TRUE` to continue the request with the SSL certificate.
  /// By default the value of `Handled` and `Cancel` are `FALSE` and display default SSL
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
        String RequestURL { get; };
        CoreWebView2Certificate ServerCertificate { get; };
        Boolean Cancel { get; set; };
        Boolean Handled { get; set; };
        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2")]
        {
          event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ReceivingServerCertificateErrorEventArgs> ReceivingServerCertificateError;
          void ClearSSLDecision();
        }
    }
}
```
