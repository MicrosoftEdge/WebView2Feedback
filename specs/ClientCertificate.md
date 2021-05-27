# Background

The WebView2 team has been asked for an API to intercept client certificates when WebView2 is
making a request to an Http server that needs a client certificate for Http authentication.
This event allows you to show ui if desired, replace default client certificate dialog prompt,
programmatically query the certificates and select a certificate from the list to respond to the server.

In this document we describe the API. We'd appreciate your feedback.

# Description

We propose adding `ClientCertificateRequested` API that allows you to query the mutually trusted CA
certificates, and select the certificate from the list to respond to the server.

When the event is raised, WebView2 will pass a `CoreWebView2ClientCertificateRequestedEventArgs` , which lets
you to view the server information that requested client certificate authentication, list of certificates filtered
from issuers that the server trusts, inspect the certificate metadata and serveral options for responding to client certificate request.

* You can select a certificate from the list to respond to the server.
* You can choose to respond to the server without a certificate.
* You can choose to display default client certificate selection dialog prompt to let user to respond to the server.
* You can cancel the request.

# Examples

The following code snippets demonstrate how the ClientCertificateRequested event can be used:

## Win32 C++: Select a certificate with no UI

``` cpp
wil::com_ptr<ICoreWebView2> m_webView;
wil::com_ptr<ICoreWebView2_3> m_webView2_3;
EventRegistrationToken m_ClientCertificateRequestedToken = {};

// Turn off client certificate selection dialog using ClientCertificateRequested event handler
// that disables the dialog. This example hides the default client certificate dialog and
// always chooses the last certificate without prompting the user.
//! [ClientCertificateRequested1]
void SettingsComponent::EnableCustomClientCertificateSelection()
{
  m_webView2_3 = m_webView.try_query<ICoreWebView2_3>();
  if (m_webView2_3)
  {
    if (m_ClientCertificateRequestedToken.value == 0)
    {
      CHECK_FAILURE(m_webView2_3->add_ClientCertificateRequested(
        Callback<ICoreWebView2ClientCertificateRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ClientCertificateRequestedEventArgs* args) {
                   wil::com_ptr<ICoreWebView2ClientCertificateCollection> certificateCollection;
                   CHECK_FAILURE(args->get_MutuallyTrustedCertificates(&certificateCollection));

                   UINT certificateCollectionCount = 0;
                   CHECK_FAILURE(certificateCollection->get_Count(&certificateCollectionCount));

                   wil::com_ptr<ICoreWebView2ClientCertificate> certificate = nullptr;

                   if (certificateCollectionCount > 0)
                   {
                     // There is no significance to the order, picking a certificate arbitrarily.
                     CHECK_FAILURE(certificateCollection->GetValueAtIndex(certificateCollectionCount - 1, &certificate));
                     // Continue with the selected certificate to respond to the server.
                     CHECK_FAILURE(args->put_SelectedCertificate(certificate.get()));
                     CHECK_FAILURE(args->put_Handled(TRUE));
                   }
                   else
                   {
                     //Continue without a certificate to respond to the server if certificate collection is empty.
                     CHECK_FAILURE(args->put_Handled(TRUE));
                   }
                   return S_OK;
            }).Get(),
            &m_ClientCertificateRequestedToken));
    }
    else
    {
      CHECK_FAILURE(m_webView2_3->remove_ClientCertificateRequested(
          m_ClientCertificateRequestedToken));
      m_ClientCertificateRequestedToken.value = 0;
    }
  }
}
//! [ClientCertificateRequested1]
```

## Win32 C++: Custom certificate selection dialog

``` cpp
wil::com_ptr<ICoreWebView2> m_webView;
wil::com_ptr<ICoreWebView2_3> m_webView2_3;
EventRegistrationToken m_ClientCertificateRequestedToken = {};
std::vector<ClientCertificate> clientCertificates_;

struct ClientCertificate
{
    wil::unique_cotaskmem_string Subject;
    wil::unique_cotaskmem_string DisplayName;
    wil::unique_cotaskmem_string Issuer;
    double ValidFrom;
    double ValidTo;
    PCWSTR CertificateKind;
};

ScenarioClientCertificateRequested::ScenarioClientCertificateRequested(SampleWindow* sampleWindow)
  : m_sampleWindow(sampleWindow), m_webView(sampleWindow->GetWebView())
{
  // Register a handler for the `ClientCertificateRequested` event.
  // This example hides the default client certificate dialog and shows a custom dialog instead.
  // The dialog box displays mutually trusted certificates list and allows the user to select a certificate.
  // Selecting `OK` will continue the request with a certificate.
  // Selecting `CANCEL` will continue the request without a certificate.
  //! [ClientCertificateRequested2]
  m_webView2_3 = m_webView.try_query<ICoreWebView2_3>();
  if (m_webView2_3)
  {
    CHECK_FAILURE(m_webView2_3->add_ClientCertificateRequested(
    Callback<ICoreWebView2ClientCertificateRequestedEventHandler>(
      [this](
        ICoreWebView2* sender,
        ICoreWebView2ClientCertificateRequestedEventArgs* args) {
          auto showDialog = [this, args] {
            wil::com_ptr<ICoreWebView2ClientCertificateCollection> certificateCollection;
            CHECK_FAILURE(args->get_MutuallyTrustedCertificates(&certificateCollection));

            wil::unique_cotaskmem_string host;
            CHECK_FAILURE(args->get_Host(&host));

            INT port = FALSE;
            CHECK_FAILURE(args->get_Port(&port));

            UINT certificateCollectionCount;
            CHECK_FAILURE(certificateCollection->get_Count(&certificateCollectionCount));

            wil::com_ptr<ICoreWebView2ClientCertificate> certificate = nullptr;

            if (certificateCollectionCount > 0)
            {
              ClientCertificate clientCertificate;
              for (UINT i = 0; i < certificateCollectionCount; i++)
              {
                CHECK_FAILURE(certificateCollection->GetValueAtIndex(i, &certificate));

                CHECK_FAILURE(certificate->get_Subject(&clientCertificate.Subject));

                CHECK_FAILURE(certificate->get_DisplayName(&clientCertificate.DisplayName));

                CHECK_FAILURE(certificate->get_Issuer(&clientCertificate.Issuer));

                COREWEBVIEW2_CLIENT_CERTIFICATE_KIND Kind;
                CHECK_FAILURE(certificate->get_Kind(&Kind));
                clientCertificate.CertificateKind = NameOfCertificateKind(Kind);

                CHECK_FAILURE(certificate->get_ValidFrom(&clientCertificate.ValidFrom));

                CHECK_FAILURE(certificate->get_ValidTo(&clientCertificate.ValidTo));

                clientCertificates_.push_back(clientCertificate);
              }

              // Display custom dialog box for the client certificate selection.
              ClientCertificateSelectionDialog dialog(
              m_sampleWindow->GetMainWindow(), L"Select a Certificate for authentication",
              host.get(), port, clientCertificates_);

              if (dialog.confirmed)
              {
                int selectedIndex = dialog.selectedItem;
                if (selectedIndex >= 0)
                {
                  CHECK_FAILURE(certificateCollection->GetValueAtIndex(selectedIndex, &certificate));
                  // Continue with the selected certificate to respond to the server if `OK` is selected.
                  CHECK_FAILURE(args->put_SelectedCertificate(certificate.get()));
                }
              }
              // Continue without a certificate to respond to the server if `CANCEL` is selected.
              CHECK_FAILURE(args->put_Handled(TRUE));
            }
            else
            {
              // Continue without a certificate to respond to the server if certificate collection is empty.
              CHECK_FAILURE(args->put_Handled(TRUE));
            }
          };

          // Obtain a deferral for the event so that the CoreWebView2
          // doesn't examine the properties we set on the event args and
          // after we call the Complete method asynchronously later.
          wil::com_ptr<ICoreWebView2Deferral> deferral;
          CHECK_FAILURE(args->GetDeferral(&deferral));

          // complete the deferral asynchronously.
          m_sampleWindow->RunAsync([deferral, showDialog]() {
            showDialog();
            CHECK_FAILURE(deferral->Complete());
          });

          return S_OK;
    }).Get(),
    &m_ClientCertificateRequestedToken));

  MessageBox(
      nullptr, L"Custom Client Certificate selection dialog will be used next when WebView2 "
      L"is making a request to an HTTP server that needs a client certificate.",
      L"Client certificate selection", MB_OK);
  }
  //! [ClientCertificateRequested2]
}
```

## . NET/ WinRT: Select a certificate with no UI

```c#
// Turn off client certificate selection dialog using ClientCertificateRequested event handler
// that disables the dialog. This example hides the default client certificate dialog and
// always chooses the last certificate without prompting the user.
private bool _isCustomClientCertificateSelection = false;
void EnableCustomClientCertificateSelection()
{
  // Safeguarding the handler when unsupported runtime is used.
  try
  {

    if (!_isCustomClientCertificateSelection)
    {
      webView. CoreWebView2. ClientCertificateRequested += WebView_ClientCertificateRequested;
    }
    else
    {
      webView. CoreWebView2. ClientCertificateRequested -= WebView_ClientCertificateRequested;
    }
    _isCustomClientCertificateSelection = !_isCustomClientCertificateSelection;

    MessageBox.Show(this,
      _isCustomClientCertificateSelection ? "Custom client certificate selection has been enabled" : "Custom client certificate selection has been disabled",
      "Custom client certificate selection");

  }
  catch (NotImplementedException exception)
  {

    MessageBox.Show(this, "Custom client certificate selection Failed: " + exception.Message, "Custom client certificate selection");

  }
}

void WebView_ClientCertificateRequested(object sender, CoreWebView2ClientCertificateRequestedEventArgs e)
{
  IReadOnlyList<CoreWebView2ClientCertificate> certificateList = e.MutuallyTrustedCertificates;
  if (certificateList. Count() > 0)
  {

    // There is no significance to the order, picking a certificate arbitrarily.
    e.SelectedCertificate = certificateList.LastOrDefault();
    // Continue with the selected certificate to respond to the server.
    e.Handled = true;

  }
  else
  {

    // Continue without a certificate to respond to the server if certificate list is empty.
    e.Handled = true;

  }
}

```

## .NET/ WinRT: Custom certificate selection dialog

```c#
// This example hides the default client certificate dialog and shows a custom dialog instead.
// The dialog box displays mutually trusted certificates list and allows the user to select a certificate.
// Selecting `OK` will continue the request with a certificate.
// Selecting `CANCEL` will continue the request without a certificate
private bool _isCustomClientCertificateSelectionDialog = false;
void DeferredCustomClientCertificateSelectionDialog()
{
  // Safeguarding the handler when unsupported runtime is used.
  try
  {
    if (!_isCustomClientCertificateSelectionDialog)
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
            IReadOnlyList<CoreWebView2ClientCertificate> certificateList = args.MutuallyTrustedCertificates;
            if (certificateList.Count() > 0)
            {
              // Display custom dialog box for the client certificate selection.
              var dialog = new ClientCertificateSelectionDialog(
                                        title: "Select a Certificate for authentication",
                                        host: args.Host,
                                        port: args.Port,
                                        client_cert_list: certificateList);
              if (dialog.ShowDialog() == true)
              {
                // Continue with the selected certificate to respond to the server if `OK` is selected.
                args.SelectedCertificate = (CoreWebView2ClientCertificate)dialog.CertificateDataBinding.SelectedItem;
              }
              // Continue without a certificate to respond to the server if `CANCEL` is selected.
              args.Handled = true;
            }
            else
            {
              // Continue without a certificate to respond to the server if certificate list is empty.
              args.Handled = true;
            }
          }

        }, null);
      };
      _isCustomClientCertificateSelectionDialog = true;
      MessageBox.Show("Custom Client Certificate selection dialog will be used next when WebView2 is making a " +
          "request to an HTTP server that needs a client certificate.", "Client certificate selection");
    }
  }
  catch (NotImplementedException exception)
  {
    MessageBox.Show(this, "Custom client certificate selection dialog Failed: " + exception.Message, "Client certificate selection");
  }
}
```

# Remarks

# API Notes

# API Details

See [API Details](#api-details) section below for API reference.

## Win32 C++

``` cpp
interface ICoreWebView2_3;
interface ICoreWebView2ClientCertificate;
interface ICoreWebView2StringCollection;
interface ICoreWebView2ClientCertificateCollection;
interface ICoreWebView2ClientCertificateRequestedEventArgs;
interface ICoreWebView2ClientCertificateRequestedEventHandler;

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
  /// for HTTP authentication.
  /// Read more about HTTP client certificates at
  /// [RFC 8446 The Transport Layer Security (TLS) Protocol Version 1.3](https://tools.ietf.org/html/rfc8446).
  ///
  /// With this event you have several options for responding to client certificate requests:
  ///
  /// Scenario                                                   | Handled | Cancel | SelectedCertificate
  /// ---------------------------------------------------------- | ------- | ------ | -------------------
  /// Respond to server with a certificate                       | True    | False  | MutuallyTrustedCertificate value
  /// Respond to server without certificate                      | True    | False  | null
  /// Display default client certificate selection dialog prompt | False   | False  | n/a
  /// Cancel the request                                         | n/a     | True   | n/a
  ///
  /// If you don't handle the event, WebView2 will
  /// show the default client certificate selection dialog prompt to user.
  ///
  /// \snippet SettingsComponent.cpp ClientCertificateRequested1
  /// \snippet ScenarioClientCertificateRequested.cpp ClientCertificateRequested2
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
    [propget] HRESULT Subject([out, retval] LPWSTR* value);
    /// Name of the certificate authority that issued the certificate.
    [propget] HRESULT Issuer([out, retval] LPWSTR* value);
    /// The valid start date and time for the certificate as the number of seconds since
    /// the UNIX epoch.
    [propget] HRESULT ValidFrom([out, retval] double* value);
    /// The valid expiration date and time for the certificate as the number of seconds since
    /// the UNIX epoch.
    [propget] HRESULT ValidTo([out, retval] double* value);
    /// DER encoded serial number of the certificate.
    /// Read more about DER at [RFC 7468 DER]
    /// (https://tools.ietf.org/html/rfc7468#appendix-B).
    [propget] HRESULT DerEncodedSerialNumber([out, retval] LPWSTR* value);
    /// Display name for a certificate.
    [propget] HRESULT DisplayName([out, retval] LPWSTR* value);
    /// PEM encoded data for the certificate.
    /// Returns Base64 encoding of DER encoded certificate.
    /// Read more about PEM at [RFC 1421 Privacy Enhanced Mail]
    /// (https://tools.ietf.org/html/rfc1421).
    HRESULT ToPemEncoding([out, retval] LPWSTR* pemEncodedData);
    /// Collection of PEM encoded client certificate issuer chain.
    /// In this collection first element is the current certificate followed by
    /// intermediate1, intermediate2...intermediateN-1. Root certificate is the
    /// last element in collection.
    [propget] HRESULT PemEncodedIssuerCertificateChain([out, retval]
        ICoreWebView2StringCollection** value);
    /// Kind of a certificate (eg., smart card, pin, other).
    [propget] HRESULT Kind([out, retval]
        COREWEBVIEW2_CLIENT_CERTIFICATE_KIND* value);
}

/// A collection of client certificate object.
[uuid(aedb012a-8e92-11eb-8dcd-0242ac130003), object, pointer_default(unique)]
interface ICoreWebView2ClientCertificateCollection : IUnknown {
    /// The number of client certificates contained in the
    /// ICoreWebView2ClientCertificateCollection.
    [propget] HRESULT Count([out, retval] UINT* value);
    /// Gets the certificate object at the given index.
    HRESULT GetValueAtIndex([in] UINT index,
        [out, retval] ICoreWebView2ClientCertificate** certificate);
}

/// A collection of strings.
[uuid(c87bb63e-a3f4-11eb-bcbc-0242ac130002), object, pointer_default(unique)]
interface ICoreWebView2StringCollection : IUnknown {
    /// The number of strings contained in ICoreWebView2StringCollection.
    [propget] HRESULT Count([out, retval] UINT* value);

    /// Gets the value at a given index.
    HRESULT GetValueAtIndex([in] UINT index, [out, retval] LPWSTR* value);
}

/// An event handler for the `ClientCertificateRequested` event.
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
    /// Normalization rules applied to the hostname are:
    /// * Convert to lowercase characters for ascii characters.
    /// * Punycode is used for representing non ascii characters.
    /// * Strip square brackets for IPV6 address.
    [propget] HRESULT Host([out, retval] LPWSTR* value);

    /// Port of the server that requested client certificate authentication.
    [propget] HRESULT Port([out, retval] int* value);

    /// Returns true if the server that issued this request is an http proxy.
    /// Returns false if the server is the origin server.
    [propget] HRESULT IsProxy([out, retval] BOOL* value);

    /// Returns the `ICoreWebView2StringCollection`.
    /// The collection contains distinguished names of certificate authorities
    /// allowed by the server.
    [propget] HRESULT AllowedCertificateAuthorities([out, retval]
        ICoreWebView2StringCollection** value);

    /// Returns the `ICoreWebView2ClientCertificateCollection` when client
    /// certificate authentication is requested. The collection contains mutually
    /// trusted CA certificates.
    [propget] HRESULT MutuallyTrustedCertificates([out, retval]
        ICoreWebView2ClientCertificateCollection** value);

    /// Returns the selected certificate.
    [propget] HRESULT SelectedCertificate([out, retval]
        ICoreWebView2ClientCertificate** value);

    /// Sets the certificate to respond to the server.
    [propput] HRESULT SelectedCertificate(
        [in] ICoreWebView2ClientCertificate* value);

    /// You may set this flag to cancel the certificate selection. If canceled,
    /// the request is aborted regardless of the `Handled` property. By default the
    /// value is `FALSE`.
    [propget] HRESULT Cancel([out, retval] BOOL* value);

    /// Sets the `Cancel` property.
    [propput] HRESULT Cancel([in] BOOL value);

    /// You may set this flag to `TRUE` to respond to the server with or
    /// without a certificate. If this flag is `TRUE` with a `SelectedCertificate`
    /// it responds to the server with the selected certificate otherwise respond to the
    /// server without a certificate. By default the value of `Handled` and `Cancel` are `FALSE`
    /// and display default client certificate selection dialog prompt to allow the user to
    /// choose a certificate. The `SelectedCertificate` is ignored unless `Handled` is set `TRUE`.
    [propget] HRESULT Handled([out, retval] BOOL* value);

    /// Sets the `Handled` property.
    [propput] HRESULT Handled([in] BOOL value);

    /// Returns an `ICoreWebView2Deferral` object. Use this operation to
    /// complete the event at a later time.
    HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
}
```

## . NET/ WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2ClientCertificateRequestedEventArgs;
    runtimeclass CoreWebView2ClientCertificate;

    enum CoreWebView2ClientCertificateKind
    {
        SmartCard = 0,
        Pin = 1,
        Other = 2,
    };

    runtimeclass CoreWebView2ClientCertificateRequestedEventArgs
    {
        // CoreWebView2ClientCertificateRequestedEventArgs members
        String Host { get; };
        Int32 Port { get; };
        Boolean IsProxy { get; };
        IVectorView<String> AllowedCertificateAuthorities { get; };
        IVectorView<CoreWebView2ClientCertificate> MutuallyTrustedCertificates { get; };
        CoreWebView2ClientCertificate SelectedCertificate { get; set; };
        Boolean Cancel { get; set; };
        Boolean Handled { get; set; };

        Windows. Foundation. Deferral GetDeferral();
    }

    runtimeclass CoreWebView2ClientCertificate
    {
        // CoreWebView2ClientCertificate members
        String Subject { get; };
        String Issuer { get; };
        Double ValidFrom { get; };
        Double ValidTo { get; };
        String DerEncodedSerialNumber { get; };
        String DisplayName { get; };
        IVectorView<String> PemEncodedIssuerCertificateChain { get; };
        CoreWebView2ClientCertificateKind Kind { get; };

        String ToPemEncoding();
        /// Converts this to a System.Security.Cryptography.X509Certificates.X509Certificate2.
        // This is only for the .NET API, not the WinRT API.
        System.Security.Cryptography.X509Certificates.X509Certificate2 ToX509Certificate2(CoreWebView2ClientCertificate coreWebView2ClientCertificate);

        /// Converts this to a Windows.Security.Cryptography.Certificates.Certificate.
        // This is only for the WinRT API, not the .NET API.
        Windows.Security.Cryptography.Certificates.Certificate ToCertificate(CoreWebView2ClientCertificate coreWebView2ClientCertificate);
    }

    runtimeclass CoreWebView2
    {
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ClientCertificateRequestedEventArgs> ClientCertificateRequested;
    }

}
```

# Appendix
