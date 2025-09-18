Sensitivity label support for Webview2
===

# Background
Web pages may contain content with sensitive information. Such information can
be identified using data loss protection (DLP) methods. The purpose of this API
is to provide sensitivity label information, communicated by web pages through
the [PageInteractionRestrictionManager](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md),
to the host application. This enables the host application to be informed of the
presence of sensitive content.

# Description

This API introduces a SensitivityLabelChanged event to the CoreWebView2 object,
enabling applications to monitor changes in sensitivity labels within hosted
content. This functionality is restricted to domains explicitly included in an
allow list configured by the application. The allow list can be set at the
profile level, thereby enabling the Page Interaction Restriction Manager for
content within specified domains. By default, the allow list is empty,
preventing hosted content from transmitting sensitivity label information.

The core features of this proposal are as follows:
* Configure the allow list filter for Page Interaction Restriction Manager at
  the profile level.
* After the setup, the `Page Interaction Restriction Manager` is available on
  pages in the allow list. Content can send sensitivity labels to the platform
  via the API.
* When a label changes, an event is raised by WebView2 to hosted app with all
  the labels on that page.
* Sensitivity labels are cleared when navigating away from the current WebView.

# Examples

## Setting up an allow list

Configure the PageInteractionRestrictionManager allow list to enable Sensitivity
label functionality on trusted domains.

### C++ Sample
```cpp
void ConfigureAllowlist()
{
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView->get_Profile(&profile));

    auto profile9 = profile.try_query<ICoreWebView2Profile9>();
    if (profile9) {
        LPCWSTR allowlist[] = {
            L"https://intranet.company.com/*",
            L"https://*.company.com/*",
            L"https://trusted-partner.com/*"
        };

        CHECK_FAILURE(profile9->SetPageInteractionRestrictionManagerAllowlist(
            static_cast<UINT32>(std::size(allowlist)),
            allowlist));
    }
}


```
### .NET/WinRT Sample
```csharp
var profile = webView2.CoreWebView2.Profile;

var allowlist = new List<string>
{
    "https://intranet.company.com/*",
    "https://*.company.com/*", 
    "https://trusted-partner.com/*"
};

profile.PageInteractionRestrictionManagerAllowlist = allowlist;
```


## Register for sensitivity label change
### C++ Sample
  ```cpp
AppWindow* m_appWindow;
wil::com_ptr<ICoreWebView2> m_webView;
EventRegistrationToken m_sensitivityLabelChangedToken = {};

void RegisterForSensitivityLabelChange()
{
  auto m_webView32 = m_webView.try_query<ICoreWebView2_32>();
  if (m_webView32)
  {
    CHECK_FAILURE(m_webView32->add_SensitivityLabelChanged(
    Callback<ICoreWebView2SensitivityLabelChangedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2SensitivityLabelEventArgs* args)
            -> HRESULT
        {
            std::wstring labelsString;
            COREWEBVIEW2_SENSITIVITY_LABEL_STATE sensitivityState;
            CHECK_FAILURE(args->get_SensitivityState(&sensitivityState));

            switch (sensitivityState)
            {
              case COREWEBVIEW2_SENSITIVITY_LABEL_STATE_UNDETERMINED:
                labelsString = L"<Labels undetermined>";
                break;

              case COREWEBVIEW2_SENSITIVITY_LABEL_STATE_DETERMINED:
                labelsString = L"<Labels determined>";
                break;

              default:
                labelsString = L"<No sensitivity state>";
                break;
            }

            if(sensitivityState == COREWEBVIEW2_SENSITIVITY_LABEL_STATE_DETERMINED)
            {
              Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabelCollectionView> 
                  sensitivityLabelsCollection;
              CHECK_FAILURE(args->get_SensitivityLabels(
                  &sensitivityLabelsCollection));

              // Get the count of labels
              UINT32 labelCount = 0;
              CHECK_FAILURE(sensitivityLabelsCollection->get_Count(&labelCount));


              if (labelCount == 0)
              {
                  labelsString = L"No label present";
              }
              else
              {
                  for (UINT32 i = 0; i < labelCount; ++i)
                  {
                      Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabel> 
                          sensitivityLabel;
                      CHECK_FAILURE(sensitivityLabelsCollection->GetValueAtIndex(
                          i, &sensitivityLabel));

                      // Get the label type
                      COREWEBVIEW2_SENSITIVITY_LABEL_KIND labelKind;
                      CHECK_FAILURE(sensitivityLabel->get_LabelKind(&labelKind));

                      if (i > 0)
                      {
                          labelsString += L", ";
                      }

                      // Handle different label types
                      switch (labelType)
                      {
                      case COREWEBVIEW2_SENSITIVITY_LABEL_KIND_MIP:
                      {
                          Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabelMip> 
                              microsoftLabel;
                          if (SUCCEEDED(sensitivityLabel.As(&microsoftLabel)))
                          {
                              wil::unique_cotaskmem_string labelId;
                              wil::unique_cotaskmem_string organizationId;
                              CHECK_FAILURE(microsoftLabel->get_LabelId(
                                  &labelId));
                              CHECK_FAILURE(microsoftLabel->get_OrganizationId(
                                  &organizationId));

                              labelsString += L"Microsoft Label (ID: " +
                                  std::wstring(labelId.get() ? 
                                      labelId.get() : L"<empty>") +
                                  L", Org: " +
                                  std::wstring(organizationId.get() ? 
                                      organizationId.get() : L"<empty>") +
                                  L")";
                          }
                          break;
                      }
                      default:
                          labelsString += L"Unknown Label";
                          break;
                      }
                  }
              }
            }

            // Show the sensitivity labels in a popup dialog
            RunAsync([this, labelsString]() {
                MessageBox(
                    m_appWindow,
                    labelsString,
                    L"Sensitivity Label State", MB_OK);
            });

            return S_OK;
        })
        .Get(),
    &m_sensitivityLabelChangedToken));
  }

}

  ```
### .NET/WinRT Sample

```c#
void RegisterForSensitivityLabelChange()
{
    webView2.CoreWebView2.SensitivityLabelChanged += WebView_SensitivityLabelChanged;
}

void WebView_SensitivityLabelChanged(object sender, CoreWebView2SensitivityLabelEventArgs args)
{
    string message = $"Sensitivity Label Changed!\n" +
                    $"SensitivityState: {args.SensitivityState}\n";

    if (args.SensitivityLabels != null && args.SensitivityLabels.Count > 0)
    {
        message += $"Number of Sensitivity Labels: {args.SensitivityLabels.Count}\n";
        for (int i = 0; i < args.SensitivityLabels.Count; i++)
        {
            CoreWebView2SensitivityLabel label = args.SensitivityLabels[i];
            message += $"Label {i + 1}:\n";
            message += $"  Type: {label.LabelType}\n";

            switch(label.LabelType)
            {
                case CoreWebView2SensitivityLabelType.Mip:
                    CoreWebView2MipSensitivityLabel mipLabel = (CoreWebView2MipSensitivityLabel)label;
                    message += $" Label Id: {mipLabel.LabelId}\n";
                    message += $"  Org Id: {mipLabel.OrganizationId}\n";
                    break;

                default:
                    message += "  Unknown Label Type\n";
                    break;
            }
        }
    }
    else
    {
        message += "No Sensitivity Labels found.\n";
    }

    this.Dispatcher.Invoke(() =>
    {
        MessageBox.Show(message, "Sensitivity Label Changed Event", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
    });
}
```
# API Details

## Allow listing
### C++

```
/// This is the ICoreWebView2Profile interface for PageInteractionRestrictionManager allowlist management.
[uuid(a15dadcf-8924-54c2-9624-1b765abdb796), object, pointer_default(unique)]
interface ICoreWebView2Profile9 : IUnknown {
  /// Gets the allowlist of URLs that are allowed to access the PageInteractionRestrictionManager API.
  /// 
  /// This method retrieves the current allowlist configured for this profile.
  /// The returned allowlist contains URL patterns that determine which web pages
  /// can access the PageInteractionRestrictionManager functionality.
  ///
  /// The caller must free the returned string array with `CoTaskMemFree`.
  HRESULT GetPageInteractionRestrictionManagerAllowlist(
      [out] UINT32* allowlistCount,
      [out] LPWSTR** allowlist
  );

  /// Sets the allowlist of URLs that are allowed to access the PageInteractionRestrictionManager API.
  ///
  /// This method configures an allowlist of URLs that determines which web pages
  /// can use the PageInteractionRestrictionManager API. Only URLs that match 
  /// entries in this allowlist (either exact matches or wildcard patterns) will
  /// have access to the PageInteractionRestrictionManager functionality.
  /// 
  /// URL Matching Logic:
  /// The allowlist accepts both exact URL strings and wildcard patterns.
  /// For wildcard patterns, `*` matches zero or more characters.
  /// 
  /// | URL Filter | Page URL | Access Granted | Notes |
  /// | ---- | ---- | ---- | ---- |
  /// | `https://example.com` | `https://example.com/page` | No | Exact match required |
  /// | `https://example.com` | `https://example.com` | No | The URI is normalized before filter matching so the actual URI used for comparison is https://example.com/ |
  /// | `https://example.com/*` | `https://example.com/page` | Yes | Wildcard matches any path |
  /// | `*://example.com/*` | `https://example.com/page` | Yes | Wildcard matches any scheme |
  /// | `*` | `https://any-site.com` | Yes | Wildcard matches all URLs |
  ///
  /// Setting the allowlist to an empty array will disable access to the
  /// PageInteractionRestrictionManager API for all pages.
  ///
  /// Changes take effect immediately for all WebView2 instances using this profile.
  /// The allowlist is persisted across sessions.
  HRESULT SetPageInteractionRestrictionManagerAllowlist(
      [in] UINT32 allowlistCount,
      [in] LPCWSTR* allowlist
  );
}
```
### .NET/WinRT
```idl
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Profile
    {
        /// Controls which URLs are allowed to access the PageInteractionRestrictionManager API.
        /// 
        /// This property manages an allowlist of URLs that determines which web pages
        /// can use the PageInteractionRestrictionManager API. Only URLs that match 
        /// entries in this allowlist (either exact matches or wildcard patterns) will
        /// have access to the PageInteractionRestrictionManager functionality.
        /// 
        /// The allowlist accepts both exact URL strings and wildcard patterns.
        /// For wildcard patterns, `*` matches zero or more characters.
        /// 
        /// | URL Filter | Page URL | Access Granted | Notes |
        /// | ---- | ---- | ---- | ---- |
        /// | `https://example.com` | `https://example.com/page` | No | Exact match required |
        /// | `https://example.com` | `https://example.com` | No | The URI is normalized before filter matching so the actual URI used for comparison is https://example.com/ |
        /// | `https://example.com/*` | `https://example.com/page` | Yes | Wildcard matches any path |
        /// | `*://example.com/*` | `https://example.com/page` | Yes | Wildcard matches any scheme |
        /// | `*` | `https://any-site.com` | Yes | Wildcard matches all URLs |
        IVectorView<String> PageInteractionRestrictionManagerAllowlist { get; set; };
    }
}
```

## Sensitivity label change event
### C++ 
```
/// Represents the state of sensitivity label detection and processing
/// for web page loaded in the WebView2 control. This enum indicates
/// whether sensitivity labels have been detected, are being processed,
/// or are fully determined for the current web page content.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_STATE {
  /// Indicates that none of the loaded pages are in the allow list. Hence 
  /// none will report sensitivity labels. 
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_NONE,
  /// Indicates that WebView2 has loaded pages from the allow list that can
  /// report sensitivity labels, but the label determination is not yet 
  /// complete.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_UNDETERMINED,
  /// Indicates that WebView2 has loaded pages from the allow list,
  /// and those pages have provided label information.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_DETERMINED,
} COREWEBVIEW2_SENSITIVITY_LABEL_STATE;

/// Represents the kind of sensitivity label applied to web page.
/// Sensitivity labels are used to classify and protect content based on
/// its sensitivity level.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_KIND {
  /// Represents an unknown or unsupported sensitivity label.
  COREWEBVIEW2_SENSITIVITY_LABEL_KIND_UNKNOWN,
  /// Represents a Microsoft Information Protection (MIP) sensitivity label.
  COREWEBVIEW2_SENSITIVITY_LABEL_KIND_MIP,
} COREWEBVIEW2_SENSITIVITY_LABEL_KIND;

/// Interface for different sensitivity label kinds used in WebView2.
/// This interface provides functionality for accessing sensitivity
/// label information applied to web page. Different label types
/// (such as Microsoft Information Protection labels) provide
/// specific label information and metadata.
[uuid(5c27e6f2-baa6-5646-b726-db80a77b7345), object, pointer_default(unique)]
interface ICoreWebView2SensitivityLabel : IUnknown {
  /// Gets the type of the sensitivity label applied to the web page.
  /// This property identifies which sensitivity label system is being used
  /// (such as Microsoft Information Protection or other label providers).
  /// Applications can use this information to determine how to interpret
  /// and handle the label data, as different label types may have different
  /// metadata formats, protection requirements, and policy enforcement
  /// mechanisms.
  [propget] HRESULT LabelKind(
      [out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_KIND* value);
}

/// Interface for Microsoft Information Protection (MIP) sensitivity labels.
/// This interface provides specific information about MIP labels, including
/// label identification and organizational context.
[uuid(1a562888-3031-5375-b8c5-8afd573e79c8), object, pointer_default(unique)]
interface ICoreWebView2MipSensitivityLabel : IUnknown {
  /// The unique identifier for the Microsoft Information Protection label.
  /// This string contains a GUID that uniquely identifies the specific
  /// sensitivity label within the organization's MIP policy configuration.
  /// The GUID is of type GUIDv4 and follows the format:
  /// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
  /// eg: `3fa85f64-5717-4562-b3fc-2c963f66afa6`
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT LabelId([out, retval] LPWSTR* value);

  /// The unique identifier for the organization that owns the MIP label.
  /// This string contains a GUID that identifies the Azure Active Directory
  /// tenant or organization that configured and deployed the sensitivity label.
  /// The GUID is of type GUIDv4 and follows the format:
  /// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
  /// eg: `44567f64-8712-1789-ac3f-15aa3f66ab12`
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT OrganizationId([out, retval] LPWSTR* value);
}


/// A collection of ICoreWebView2SensitivityLabel.
[uuid(2cb85219-0878-5f38-b7e9-769fab6ff887), object, pointer_default(unique)]
interface ICoreWebView2SensitivityLabelCollectionView : IUnknown {
  /// The number of elements contained in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the element at the given index.
  HRESULT GetValueAtIndex(
      [in] UINT32 index, 
      [out, retval] ICoreWebView2SensitivityLabel** value);
}

/// Event arguments for the `SensitivityLabelChanged` event.
/// This interface provides information about sensitivity label changes
/// that occur when web page is loaded or updated in the WebView2 control.
/// The event args contain the current state of sensitivity label detection
/// and a collection of all sensitivity labels that have been reported by
/// the web page via 
/// [`Page Interaction Restriction Manager`](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md). 
[uuid(36de2060-e013-5b03-939b-117d08d0abd5), object, pointer_default(unique)]
interface ICoreWebView2SensitivityLabelEventArgs : IUnknown {
  /// Gets a read-only collection of all sensitivity labels detected in the
  /// current web document. This collection contains instances of sensitivity
  /// labels that have been reported by the web page.
  [propget] HRESULT SensitivityLabels(
      [out, retval] ICoreWebView2SensitivityLabelCollectionView** value);


  /// Gets the current state of sensitivity label detection.
  [propget] HRESULT SensitivityState(
      [out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_STATE* value);

}

/// Receives `SensitivityLabelChanged` events.
[uuid(927a011d-bbf3-546b-ba28-1fc0ef4c1f4a), object, pointer_default(unique)]
interface ICoreWebView2SensitivityLabelChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2SensitivityLabelEventArgs* args);
}

/// Extension of the ICoreWebView2 interface that provides sensitivity label
/// change notification capabilities. This interface enables applications to
/// monitor and respond to changes in the sensitivity classification of web
/// content loaded in the WebView2 control. When sensitivity labels are
/// detected, updated, or removed from web pages, the SensitivityLabelChanged
/// event is raised.
[uuid(ac4543d5-f466-5622-8b3b-24d3b195525c), object, pointer_default(unique)]
interface ICoreWebView2_32 : IUnknown {
  /// Adds an event handler for the `SensitivityLabelChanged` event.
  /// Event raised when the sensitivity label classification of web page 
  /// changes. web pages may report sensitivity labels via
  /// [`Page Interaction Restriction Manager`](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md).
  /// This event is triggered when the WebView2 control detects a change in 
  /// the sensitivity labels associated with the currently loaded web page.
  /// Changes can occur when navigating to a new page in the main frame,
  /// when the existing page updates its sensitivity label information.
  /// On navigation to a new page `SensitivityLabelChanged` event is raised
  /// after the `NavigationCompleted` event. Applications can subscribe to
  /// this event to receive notifications about sensitivity changes. The
  /// event args provide the current label state and the complete collection
  /// of detected sensitivity labels. the complete collection of detected
  /// sensitivity labels.
  HRESULT add_SensitivityLabelChanged(
      [in] ICoreWebView2SensitivityLabelChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with 
  /// `add_SensitivityLabelChanged`.
  HRESULT remove_SensitivityLabelChanged(
      [in] EventRegistrationToken token);

}
```
### .NET/WinRT
```c#
enum CoreWebView2SensitivityLabelKind
{
    Unknown = 0,
    Mip = 1,
};

enum CoreWebView2SensitivityLabelState
{
    None = 0,
    Undetermined = 1,
    Determined = 2,
};

runtimeclass CoreWebView2SensitivityLabelEventArgs
{
    // ICoreWebView2SensitivityLabelEventArgs members
    IVectorView<CoreWebView2SensitivityLabel>  SensitivityLabels { get; };

    CoreWebView2SensitivityLabelState SensitivityState { get; };
}

runtimeclass CoreWebView2SensitivityLabelCollectionView
{
    // ICoreWebView2SensitivityLabelCollectionView members
    UInt32 Count { get; };

    CoreWebView2SensitivityLabel GetValueAtIndex(UInt32 index);
}

runtimeclass CoreWebView2SensitivityLabel
{
    // ICoreWebView2SensitivityLabel members
    CoreWebView2SensitivityLabelType LabelType { get; };
}

runtimeclass CoreWebView2MipSensitivityLabel
{
    // ICoreWebView2MipSensitivityLabel members
    String LabelId { get; };

    String OrganizationId { get; };
}

runtimeclass CoreWebView2SensitivityLabelEventArgs
{
    // ICoreWebView2SensitivityLabelEventArgs members
    IVectorView<CoreWebView2SensitivityLabel>  SensitivityLabels { get; };

    CoreWebView2SensitivityLabelState SensitivityState { get; };
}

runtimeclass CoreWebView2
{
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_32")]
    {
        // ICoreWebView2_32 members
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2SensitivityLabelEventArgs> SensitivityLabelChanged;
    }
}
```
