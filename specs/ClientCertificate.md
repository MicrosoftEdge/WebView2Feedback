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
## Win32 C++: Select a certificate with no UI
```cpp
// Turn on or off client certificate selection dialog by adding or removing a
// ClientCertificateRequested handler which intercepts when server requests client
// certificate for authentication.
// This example hides the default client certificate dialog and allows you to set
// the client certificate programmatically.
void SettingsComponent::SetClientCertificateRequested(bool raiseClientCertificate)
{
    if (raiseClientCertificate != m_raiseClientCertificate)
    {
        m_raiseClientCertificate = raiseClientCertificate;
        //! [ClientCertificateRequested1]
        if (m_raiseClientCertificate)
        {
            CHECK_FAILURE(m_webView->add_ClientCertificateRequested(
                Callback<ICoreWebView2ClientCertificateRequestedEventHandler>(
                    [this](
                        ICoreWebView2* sender,
                        ICoreWebView2ClientCertificateRequestedEventArgs* args) {
                        ICoreWebView2ClientCertificateList* certificateList;
                        CHECK_FAILURE(args->get_MutuallyTrustedCertificates(&certificateList));

                        // Certificate list count will always be greater than zero as this event is
                        // raised when there is atleast one mutually trusted certificate.
                        UINT certificateListCount = 0;
                        CHECK_FAILURE(certificateList->get_Count(&certificateListCount));

                        ICoreWebView2ClientCertificate* certificate = nullptr;

                        CHECK_FAILURE(certificateList->GetValueAtIndex(certificateListCount-1, &certificate));

                        CHECK_FAILURE(args->put_SelectedCertificate(certificate));
                        CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
                                COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_CERTIFICATE));

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
        //! [ClientCertificateRequested1]
    }
}
```
## Win32 C++: Custom certificate selection dialog
```cpp
ScenarioClientCertificateRequested::ScenarioClientCertificateRequested(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [ClientCertificateRequested2]
    // Register a handler for the `ClientCertificateRequested` event.
    // This example hides the default client certificate dialog and shows a custom dialog instead.
    // The dialog box displays mutually trusted certificates list and allows the user to select a certificate.
    // Selecting `OK` will continue the request with a certificate.
    // Selecting `CANCEL` will continue the request without a certificate.
    CHECK_FAILURE(m_webView->add_ClientCertificateRequested(
			Callback<ICoreWebView2ClientCertificateRequestedEventHandler>(
				[this](
					ICoreWebView2* sender,
					ICoreWebView2ClientCertificateRequestedEventArgs* args) {
						auto showDialog = [this, args] {
							ICoreWebView2ClientCertificateList* certificateList;
							CHECK_FAILURE(args->get_MutuallyTrustedCertificates(&certificateList));

							wil::unique_cotaskmem_string host;
							CHECK_FAILURE(args->get_Host(&host));

							INT port = FALSE;
							CHECK_FAILURE(args->get_Port(&port));

							UINT certificateListCount;
							CHECK_FAILURE(certificateList->get_Count(&certificateListCount));

							ICoreWebView2ClientCertificate* certificate = nullptr;

							ClientCertificate client_certificate;
							for (UINT i = 0; i < certificateListCount; i++)
							{
								CHECK_FAILURE(
									certificateList->GetValueAtIndex(i, &certificate));

								wil::unique_cotaskmem_string subject;
								CHECK_FAILURE(certificate->get_Subject(&subject));
								client_certificate.Subject = subject.get();

								wil::unique_cotaskmem_string displayName;
								CHECK_FAILURE(certificate->get_DisplayName(&displayName));
								client_certificate.DisplayName = displayName.get();

								wil::unique_cotaskmem_string issuer;
								CHECK_FAILURE(certificate->get_Issuer(&issuer));
								client_certificate.Issuer = issuer.get();

								wil::unique_cotaskmem_string serialNumber;
								CHECK_FAILURE(certificate->get_SerialNumber(&serialNumber));

								COREWEBVIEW2_CLIENT_CERTIFICATE_KIND certificateKind;
								CHECK_FAILURE(
									certificate->get_CertificateKind(&certificateKind));
								client_certificate.CertificateKind = NameOfCertificateKind(certificateKind);

								double startDate;
								CHECK_FAILURE(certificate->get_ValidStartDate(&startDate));
								client_certificate.StartDate = startDate;

								double expiryDate;
								CHECK_FAILURE(certificate->get_ValidExpiryDate(&expiryDate));
								client_certificate.ExpiryDate = expiryDate;

								client_certificates_.push_back(client_certificate);
							}

							// Display custom dialog box for the client certificate selection.
							ClientCertificateSelectionDialog dialog(
								m_appWindow->GetMainWindow(), L"Select a Certificate for authentication", host.get(), port, client_certificates_);

							if (dialog.confirmed)
							{
								int selectedCertificate = dialog.selectedItem;
								if (selectedCertificate >= 0)
								{
									CHECK_FAILURE(
										certificateList->GetValueAtIndex(selectedCertificate, &certificate));

									CHECK_FAILURE(args->put_SelectedCertificate(certificate));
									CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
										COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITH_CERTIFICATE));
								}
								else
								{
									CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
										COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITHOUT_CERTIFICATE));
								}
							}
							else
							{
								CHECK_FAILURE(args->put_ClientCertificateRequestResponseState(
									COREWEBVIEW2_CLIENT_CERTIFICATE_REQUEST_RESPONSE_STATE_CONTINUE_WITHOUT_CERTIFICATE));
							}
						};

						// Obtain a deferral for the event so that the CoreWebView2
						// doesn't examine the properties we set on the event args and
						// after we call the Complete method asynchronously later.
						wil::com_ptr<ICoreWebView2Deferral> deferral;
						CHECK_FAILURE(args->GetDeferral(&deferral));

						// This function can be called to show the custom client certificate dialog and
						// complete the event at a later time, allowing the developer to
						// perform async work before the event completes.
						m_completeDeferredCertificateRequestedEvent = [showDialog, deferral] {
							showDialog();
							CHECK_FAILURE(deferral->Complete());
						};

						return S_OK;
				})
			.Get(),
					&m_ClientCertificateRequestedToken));
	//! [ClientCertificateRequested2]
}
```

## .NET/ WinRT
```c#
private bool _isClientCertificateRequested = false;
void ClientCertificateRequestedCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
  try
  {
    if (!_isClientCertificateRequested)
    {
      webView.CoreWebView2.ClientCertificateRequested += delegate (
      object sender, CoreWebView2ClientCertificateRequestedEventArgs args)
      {
        // Developer can obtain a deferral for the event so that the WebView2
        // doesn't examine the properties we set on the event args until
        // after the deferral completes asynchronously.
        CoreWebView2Deferral deferral = args.GetDeferral();

        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
          using (deferral)
          {
            List<CoreWebView2ClientCertificate> certificatesList = args.MutuallyTrustedCertificates;
            if (certificatesList.Count() > 0)
            {
              var dialog = new ClientCertificateSelectionDialog(
                           title: "Client Certificate Selection",
                           host: args.Host,
                           port: args.Port,
                           client_cert_list: certificatesList);
              if (dialog.ShowDialog() == true)
              {
                args.SelectedCertificate = (CoreWebView2ClientCertificate)dialog.CertificateDataBinding.SelectedItem;
                args.ClientCertificateRequestResponseState = CoreWebView2ClientCertificateRequestResponseState.ContinueWithCertificate;
              }
              else
              {
                args.ClientCertificateRequestResponseState = CoreWebView2ClientCertificateRequestResponseState.ContinueWithoutCertificate;
              }
            }
            else
            {
              args.ClientCertificateRequestResponseState = CoreWebView2ClientCertificateRequestResponseState.ContinueWithoutCertificate;
            }
          }
        }, null);
      };
      _isClientCertificateRequested = true;
    }
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
interface ICoreWebView2CertificateAuthorityList;
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
  /// for HTTP authentication and when there is atleast one mutually trusted certitifcate.
  /// Read more about HTTP client certificates at
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
  [propget] HRESULT ValidStartDate([out, retval] double* validStartDate);
  /// The valid expiration date and time for the certificate as the number of seconds since
  /// the UNIX epoch.
  [propget] HRESULT ValidExpiryDate([out, retval] double* validExpiryDate);
  /// DER encoded serial number of the certificate.
  [propget] HRESULT SerialNumber([out, retval] LPWSTR* serialNumber);
  /// Display name for a certificate.
  [propget] HRESULT DisplayName([out, retval] LPWSTR* displayName);
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

/// A list of distinguished certificate authorities.
[uuid(c87bb63e-a3f4-11eb-bcbc-0242ac130002), object, pointer_default(unique)]
interface ICoreWebView2CertificateAuthorityList : IUnknown {
  /// The number of certificate authorities contained in
  /// ICoreWebView2CertificateAuthorityList.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the certificate authority at the given index.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] LPWSTR* certificateAuthority);
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

  /// Returns the `ICoreWebView2CertificateAuthorityList`.
  /// The list contains distinguished name of certificate authorities
  /// allowed by the server.
  [propget] HRESULT CertificateAuthorities([out, retval]
      ICoreWebView2CertificateAuthorityList** certificateAuthorityList);

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
        IVector<string> CertificateAuthorities { get; };
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
