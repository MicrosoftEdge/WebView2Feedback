# Background
The WebView2 team has been asked for an API to intercept client certificates when WebView2 is
making a request to an Http server that needs a `client certificate` for `Http authentication`.
This event allows you to show ui if desired, replace default client certificate dialog prompt,
programmatically query the certificates and select a certificate from the list to respond to the server.

In this document we describe the API. We'd appreciate your feedback.


# Description
We propose adding `ClientCertificateRequested` API that allows you to query the mutually trusted CA
certificates, and select the certificate from the list to respond to the server.

When the event is raised, WebView2 will pass a `CoreWebView2ClientCertificateRequestedEventArgs`, which lets
you to view the server information that requested client certificate authentication, list of certificates filtered
from issuers that the server trusts, inspect the certificate metadata and serveral options for responding to client certificate request.

- You can select a certificate from the list to respond to the server.
- You can choose to respond to the server without a certificate.
- You can choose to display default client certificate selection dialog prompt to let user to respond to the server.
- You can cancel the request.

# Examples
The following code snippets demonstrate how the ClientCertificateRequested event can be used:
## Win32 C++
```cpp
// Turn on or off client certificate selection dialog by adding or removing a
// ClientCertificateRequested handler which intercepts when server requests client
// certificate for authentication.
void SettingsComponent::SetClientCertificateRequested(bool raiseClientCertificate)
{
    if (raiseClientCertificate != m_raiseClientCertificate)
    {
        m_raiseClientCertificate = raiseClientCertificate;
        //! [ClientCertificateRequested]
        if (m_raiseClientCertificate)
        {
            CHECK_FAILURE(m_webView->add_ClientCertificateRequested(
                Callback<ICoreWebView2ClientCertificateRequestedEventHandler>(
                    [this](
                        ICoreWebView2* sender,
                        ICoreWebView2ClientCertificateRequestedEventArgs* args) {

                        ICoreWebView2ClientCertificateList* certificateList;
                        CHECK_FAILURE(args->get_MutuallyTrustedCertificates(&certificateList));

                        wil::unique_cotaskmem_string host;
                        CHECK_FAILURE(args->get_Host(&host));

                        BOOL isProxy = FALSE;
                        CHECK_FAILURE(args->get_IsProxy(&isProxy));

                        UINT cert_lst_size;
                        CHECK_FAILURE(certificateList->get_Count(&cert_lst_size));

                        ICoreWebView2ClientCertificate* certificate = nullptr;
                        if (cert_lst_size > 0)
                        {
                            for (int i = 0; i < cert_lst_size; i++)
                            {
                                CHECK_FAILURE(certificateList->GetValueAtIndex(i, &certificate));

                                wil::unique_cotaskmem_string subject;
                                CHECK_FAILURE(certificate->get_Subject(&subject));
                                wil::unique_cotaskmem_string issuer;
                                CHECK_FAILURE(certificate->get_Issuer(&issuer));
                                wil::unique_cotaskmem_string serialNumber;
                                CHECK_FAILURE(certificate->get_SerialNumber(&serialNumber));
                                COREWEBVIEW2_CLIENT_CERTIFICATE_KIND certificateKind;
                                CHECK_FAILURE(certificate->get_CertificateKind(&certificateKind));
                                INT64 startDate;
                                CHECK_FAILURE(certificate->get_ValidStartDate(&startDate));
                                INT64 expiryDate;
                                CHECK_FAILURE(certificate->get_ValidExpiryDate(&expiryDate));
                                ICoreWebView2ClientCertificateIssuerChainList* pemIssuerChainList;
                                CHECK_FAILURE(certificate->get_PEMEncodedIssuerChainData(&pemIssuerChainList));
                            }
                        }

                        if (certificate)
                        {
                            CHECK_FAILURE(args->put_SelectedCertificate(certificate));
                            CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
                                COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_CERTIFICATE));
                        }
                        else
                        {
                            CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
                                COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITHOUT_CERTIFICATE));
                        }
                        return S_OK;
                    })
                    .Get(),
                &m_ClientCertificateRequestedToken));
        }
        else
        {
            CHECK_FAILURE(m_webView->remove_ClientCertificateRequested(
                m_ClientCertificateRequestedToken));
        }
        //! [ClientCertificateRequested]
    }
}
```

## .NET/ WinRT
```c#
void ClientCertificateRequestedCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
  try
  {
    webView.CoreWebView2.ClientCertificateRequested += delegate (
    object sender, CoreWebView2ClientCertificateRequestedEventArgs args)
    {
      List<CoreWebView2ClientCertificate> certificatesList = args.MutuallyTrustedCertificates;
      if (certificatesList.Count() > 0)
      {
        args.SelectedCertificate = certificatesList.FirstOrDefault();
        args.ClientCertificateRequestResponseState = CoreWebView2ClientCertificateRequestResponseState.ContinueWithCertificate;
      }
      else
      {
        args.ClientCertificateRequestResponseState = CoreWebView2ClientCertificateRequestResponseState.ContinueWithoutCertificate;
      }
    };
    webView.CoreWebView2.Navigate("uri that requires client certificate for authentication");
  }
  catch (NotImplementedException exception)
  {
    MessageBox.Show(this, "Client Certificate Requested Failed: " + exception.Message, "Client Certificate Requested");
  }
}
```
# Remarks

# API Notes

# API Details
See [API Details](#api-details) section below for API reference.

## Win32 C++
```cpp
interface ICoreWebView2_3;
interface ICoreWebView2ClientCertificate;
interface ICoreWebView2ClientCertificateIssuerChainList;
interface ICoreWebView2ClientCertificateList;
interface ICoreWebView2ClientCertificateRequestedEventArgs;
interface ICoreWebView2ClientCertificateRequestedEventHandler;

[v1_enum]
/// Question to reviewers if COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE
/// enum should be replaced with Cancel and Handled properties like below to match
/// with other WebView2 API conventions ????
/// * Cancel = true -> AbortRequest
/// * Handled = true -> ContinueWithoutCertificate
/// * Handled = true + SelectedCertificate -> ContinueWithCertificate
/// * Neither -> ContinueWithDefaultDialog
typedef enum COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE {
  /// Cancels the certificate selection and aborts the request.
  COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_ABORT_REQUEST,
  /// Continue without certificate to respond to the server.
  COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITHOUT_CERTIFICATE,
  /// Continue with the selected certificate to respond to the server.
  COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_CERTIFICATE,
  /// Display the default client certificate selection dialog prompt to allow the user
  /// to choose a certificate. The SelectedCertificate property is ignored in this case.
  COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_DEFAULT_DIALOG,
} COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE;

[v1_enum] typedef enum COREWEBVIEW2_CLIENT_CERTIFICATE_KIND {
  /// Specifies smart card certificate.
  COREWEBVIEW2_CLIENT_CERTIFICATE_KIND_SMART_CARD,
  /// Specifies PIN certificate.
  COREWEBVIEW2_CLIENT_CERTIFICATE_KIND_PIN,
  /// Specifies other certificate.
  COREWEBVIEW2_CLIENT_CERTIFICATE_KIND_OTHER,
} COREWEBVIEW2_CLIENT_CERTIFICATE_KIND;

[uuid(92d41f20-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2_3 : ICoreWebView2_2 {
  /// Add an event handler for the ClientCertificateRequested event.
  /// The ClientCertificateRequested event is raised when the WebView2
  /// is making a request to an HTTP server that needs a client certificate
  /// for HTTP authentication. Read more about HTTP client certificates at
  /// [RFC 8446 The Transport Layer Security (TLS) Protocol Version 1.3](https://tools.ietf.org/html/rfc8446).
  ///
  /// With this event you have several options for responding to client certificate requests:
  ///
  /// *  You can query the mutually trusted CA certificates, and select a certificate
  /// from the list to respond to the server.
  /// *  You can choose to respond to the server without a certificate.
  /// *  You can choose to display default client certificate selection dialog prompt
  /// to let user to respond to the server.
  /// *  You can cancel the request.
  ///
  /// If you doesn't handle the event, WebView2 will
  /// show the default client certificate selection dialog prompt to user.
  ///
  /// \snippet SettingsComponent.cpp ClientCertificateRequested
  HRESULT add_ClientCertificateRequested(
      [in] ICoreWebView2ClientCertificateRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_ClientCertificateRequested.
  HRESULT remove_ClientCertificateRequested([in] EventRegistrationToken token);
}

/// Provides access to the certificate metadata
[uuid(9ca02116-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificate : IUnknown {
  /// Subject of the certificate.
  [propget] HRESULT Subject([out, retval] LPWSTR* subject);
  /// Name of the certificate authority that issued the certificate.
  [propget] HRESULT Issuer([ out, retval ] LPWSTR* issuer);
  /// The valid start date and time for the certificate as the number of seconds since
  /// the UNIX epoch.
  [propget] HRESULT ValidStartDate([out, retval] INT64* validStartDate);
  /// The valid expiration date and time for the certificate as the number of seconds since
  /// the UNIX epoch.
  [propget] HRESULT ValidExpiryDate([out, retval] INT64* validExpiryDate);
  /// DER encoded serial number of the certificate.
  [propget] HRESULT SerialNumber([out, retval] LPWSTR* serialNumber);
  /// Display name for a certificate.
  [propget] HRESULT DisplayName([out, retval] LPWSTR* displayName);
  /// DER encoded data for the certificate.
  /// Returns encoded binary data of the certificate represented as a string.
  /// Read more about DER at [RFC 7468 DER]
  /// (https://tools.ietf.org/html/rfc7468#appendix-B).
  [propget] HRESULT DEREncodedData([out, retval] LPWSTR* derEncodedData);
  /// List of DER encoded client certificate issuer chain.
  /// This list contains the certificate and intermediate CA certificates.
  [propget] HRESULT DEREncodedIssuerChainData([out, retval]
      ICoreWebView2ClientCertificateIssuerChainList**
                                              derEncodedIssuerChainData);
  /// PEM encoded data for the certificate.
  /// Returns Base64 encoding of DER encoded certificate.
  /// Read more about PEM at [RFC 1421 Privacy Enhanced Mail]
  /// (https://tools.ietf.org/html/rfc1421).
  [propget] HRESULT PEMEncodedData([out, retval] LPWSTR* pemEncodedData);
  /// List of PEM encoded client certificate issuer chain.
  /// This list contains the certificate and intermediate CA certificates.
  [propget] HRESULT PEMEncodedIssuerChainData([out, retval]
      ICoreWebView2ClientCertificateIssuerChainList**
                                              pemEncodedIssuerChainData);
  /// Kind of a certificate (smart card, pin).
  [propget] HRESULT CertificateKind([out,retval]
      COREWEBVIEW2_CLIENT_CERTIFICATE_KIND* certificateKind);
}


/// A list of client certificate issuer chains.
[uuid(4271275e-9107-11eb-a8b3-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificateIssuerChainList : IUnknown {
  /// The number of issuer chains contained in
  /// ICoreWebView2ClientCertificate.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets encoded data of the issuer chain at the given index.
  /// Index 0 contains the certificate followed by intermediate CA certificates.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] LPWSTR* issuer);
}

/// A list of client certificate object.
[uuid(aedb012a-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificateList : IUnknown {
  /// The number of client certificates contained in the ICoreWebView2ClientCertificateList.
  [propget] HRESULT Count([out, retval] UINT* count);
  /// Gets the certificate object at the given index.
  HRESULT GetValueAtIndex([in] UINT index,
                          [out, retval] ICoreWebView2ClientCertificate** certificate);
}

/// Add an event handler for the `ClientCertificateRequested` event.
[uuid(c403d464-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificateRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke([in] ICoreWebView2* sender,
                 [in] ICoreWebView2ClientCertificateRequestedEventArgs* args);
}

/// Event args for the `ClientCertificateRequested` event.
[uuid(cb10ae1c-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificateRequestedEventArgs : IUnknown {
  /// Host name of the server that requested client certificate authentication.
  [propget] HRESULT Host([out, retval] LPWSTR * host);

  /// Port of the server that requested client certificate authentication.
  [propget] HRESULT Port([out, retval] int* port);

  /// Returns true if the server that issued this request is an http proxy.
  /// Returns false if the server is the origin server.
  [propget] HRESULT IsProxy([out, retval] BOOL* isProxy);

  /// Returns the `ICoreWebView2ClientCertificateList` when client
  /// certificate authentication is requested. The list contains mutually
  /// trusted CA certificates.
  [propget] HRESULT MutuallyTrustedCertificates([out, retval]
      ICoreWebView2ClientCertificateList** clientCertificateList);

  /// Returns the selected certificate.
  [propget] HRESULT SelectedCertificate([out, retval]
      ICoreWebView2ClientCertificate** certificate);

  /// Sets the certificate to respond to the server.
  [propput] HRESULT SelectedCertificate(
      [in] ICoreWebView2ClientCertificate* certificate);

  /// The state of the Client Certificate Request Response State.
  /// See `COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE` for descriptions of states.
  /// The default is COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_DEFAULT_DIALOG.
  [propget] HRESULT ClientCertificateRequestResponseState(
      [out, retval] COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE* state);

  /// Sets the `Client Certificate Request Response State` property.
  [propput] HRESULT ClientCertificateRequestResponseState(
      [in] COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE state);

  /// Returns an `ICoreWebView2Deferral` object.  Use this operation to
  /// complete the event at a later time.
  HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}
```

## .NET/ WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ClientCertificateRequestedEventArgs;
    runtimeclass CoreWebView2ClientCertificate;

    enum CoreWebView2ClientCertificateRequestResponseState
    {
        AbortRequest = 0,
        ContinueWithoutCertificate = 1,
        ContinueWithCertificate = 2,
        ContinueWithDefaultDialog = 3,
    };
    enum CoreWebView2ClientCertificateKind
    {
        SmartCard = 0,
        Pin = 1,
        Other = 2,
    };

    runtimeclass CoreWebView2ClientCertificateRequestedEventArgs
    {
        // ICoreWebView2ClientCertificateRequestedEventArgs members
        String Host { get; };
        Int32 Port { get; };
        Boolean IsProxy { get; };
        IVector<CoreWebView2ClientCertificate> MutuallyTrustedCertificates { get; };
        CoreWebView2ClientCertificate SelectedCertificate { get; set; };
        CoreWebView2ClientCertificateRequestResponseState ClientCertificateRequestResponseState { get; set; };

        Windows.Foundation.Deferral GetDeferral();
    }

    runtimeclass CoreWebView2ClientCertificate
    {
        // ICoreWebView2ClientCertificate members
        String Subject { get; };
        String Issuer { get; };
        Windows.Foundation.DateTime ValidStartDate { get; };
        Windows.Foundation.DateTime ValidExpiryDate { get; };
        String SerialNumber { get; };
        String DisplayName { get; };
        String DEREncodedData { get; };
        IVector<string> DEREncodedIssuerChainData { get; };
        String PEMEncodedData { get; };
        IVector<string> PEMEncodedIssuerChainData { get; };
        CoreWebView2ClientCertificateKind CertificateKind { get; };
    }

    runtimeclass CoreWebView2
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ClientCertificateRequestedEventArgs> ClientCertificateRequested;
    }
}
```

# Appendix
