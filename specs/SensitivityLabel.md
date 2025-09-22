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
    auto webView32 = m_webView.try_query<ICoreWebView2Staging32>();
    if (webView32)
    {
        CHECK_FAILURE(webView32->add_SensitivityInfoChanged(
            Callback<ICoreWebView2StagingSensitivityInfoChangedEventHandler>(
                [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT
                {
                    auto webView32 = this->m_webView.try_query<ICoreWebView2Staging32>();
                    ICoreWebView2StagingSensitivityInfo* sensitivityInfo = nullptr;
                    webView32->get_SensitivityInfo(&sensitivityInfo);

                    COREWEBVIEW2_SENSITIVITY_LABELS_STATE sensitivityLabelsState;
                    CHECK_FAILURE(sensitivityInfo->get_SensitivityLabelsState(&sensitivityLabelsState));

                    // Block print action in case sensitivity state is yet to be available
                    bool shouldBlockPrint = (sensitivityLabelsState == COREWEBVIEW2_SENSITIVITY_LABELS_STATE_PENDING);

                    // If sensitivity state is available check with the DLP provider if print rights is available
                    if(sensitivityLabelsState == COREWEBVIEW2_SENSITIVITY_LABELS_STATE_AVAILABLE)
                    {
                        Microsoft::WRL::ComPtr<ICoreWebView2StagingSensitivityLabelCollectionView> sensitivityLabelsCollection;
                        CHECK_FAILURE(sensitivityInfo->get_SensitivityLabels(&sensitivityLabelsCollection));

                        // Get the count of labels
                        UINT32 labelCount = 0;
                        CHECK_FAILURE(sensitivityLabelsCollection->get_Count(&labelCount));

                        for (UINT32 i = 0; i < labelCount; ++i)
                        {
                            Microsoft::WRL::ComPtr<ICoreWebView2StagingSensitivityLabel> sensitivityLabel;
                            CHECK_FAILURE(sensitivityLabelsCollection->GetValueAtIndex(i, &sensitivityLabel));

                            // Get the label kind COREWEBVIEW2_SENSITIVITY_LABEL_KIND
                            COREWEBVIEW2_SENSITIVITY_LABEL_KIND labelKind;
                            CHECK_FAILURE(sensitivityLabel->get_LabelKind(&labelKind));
                            if (labelKind == COREWEBVIEW2_SENSITIVITY_LABEL_KIND_MIP)
                            {
                                // Try to get as MIP label
                                Microsoft::WRL::ComPtr<ICoreWebView2StagingMipSensitivityLabel> mipLabel;
                                if (SUCCEEDED(sensitivityLabel.As(&mipLabel)))
                                {
                                    wil::unique_cotaskmem_string labelId;
                                    wil::unique_cotaskmem_string organizationId;
                                    CHECK_FAILURE(mipLabel->get_LabelId(&labelId));
                                    CHECK_FAILURE(mipLabel->get_OrganizationId(&organizationId));

                                    // Query Purview for label metadata and check for Print rights
                                    bool isPrintAllowed = IsPrintRightsAllowedByPurview(labelId, organizationId)
                                    
                                    // Block print if any of the document blocks print
                                    shouldBlockPrint ||= isPrintAllowed;
                                }
                            }
                        }

                        if (shouldBlockPrint)
                        {
                            BlockPrintOption();
                        }
                    }  
                }).Get(),
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

```cpp
/// Represents the state of sensitivity label detection and processing
/// for web content loaded in the WebView2 control.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABELS_STATE {
  /// Indicates that none of the loaded pages are in the allow list. Hence
  /// sensitivity labels are not applicable.
  COREWEBVIEW2_SENSITIVITY_LABELS_STATE_NOT_APPLICABLE,
  /// Indicates that WebView2 has loaded pages from the allow list that
  /// can report sensitivity labels, but the label are not available
  /// yet complete.
  COREWEBVIEW2_SENSITIVITY_LABELS_STATE_PENDING,
  /// Indicates that WebView2 has loaded pages from the allow list,
  /// and the labels about the content are available now.
  COREWEBVIEW2_SENSITIVITY_LABELS_STATE_AVAILABLE,
} COREWEBVIEW2_SENSITIVITY_LABELS_STATE;

/// Specifies the kind of sensitivity label applied to web content.
/// Sensitivity labels are used to classify and protect content based on
/// its sensitivity level.
///
/// <remarks>
/// This enumeration is designed to be extensible. New values may be added
/// in future versions. Applications should not implement a default case
/// that assumes knowledge of all possible label kinds to ensure forward
/// compatibility.
/// </remarks>
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_KIND {
  /// Represents a Microsoft Information Protection (MIP) sensitivity label.
  COREWEBVIEW2_SENSITIVITY_LABEL_KIND_MIP,
} COREWEBVIEW2_SENSITIVITY_LABEL_KIND;


/// Interface for different sensitivity label kinds used in WebView2.
/// This interface provides functionality for accessing sensitivity
/// label information applied to web content. Different label types
/// (such as Microsoft Information Protection labels) provide
/// specific label information and metadata.
[uuid(5c27e6f2-baa6-5646-b726-db80a77b7345), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabel : IUnknown {
  /// Gets the type of the sensitivity label applied to the web content.
  /// This property identifies which sensitivity label system is being used
  /// (such as Microsoft Information Protection or other label providers).
  /// Applications can use this information to determine how to interpret
  /// and handle the label data, as different label types may have different
  /// metadata formats, protection requirements, and policy enforcement
  /// mechanisms.
  [propget] HRESULT LabelKind([out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_KIND* value);
}


/// Interface for Microsoft Information Protection (MIP) sensitivity labels.
/// This interface provides specific information about MIP labels, including
/// label identification and organizational context.
[uuid(1a562888-3031-5375-b8c5-8afd573e79c8), object, pointer_default(unique)]
interface ICoreWebView2MipSensitivityLabel : IUnknown {
  /// The unique identifier for the Microsoft Information Protection label.
  /// This string contains a GUID that uniquely identifies the specific
  /// sensitivity label within the organization's MIP policy configuration.
  /// The GUID follows the format:
  /// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
  /// eg: `3fa85f64-5717-4562-b3fc-2c963f66afa6`
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT LabelId([out, retval] LPWSTR* value);

  /// The unique identifier for the organization that owns the MIP label.
  /// This string contains a GUID that identifies the Azure Active Directory
  /// tenant or organization that configured and deployed the sensitivity label.
  /// The GUID follows the format:
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

/// This interface provides information about sensitivity of web page
/// loaded in the WebView2 control. It contains the current state of
/// sensitivity label detection and a collection of all sensitivity labels
/// that have been reported by the web page via
/// [`Page Interaction Restriction Manager`](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md).
[uuid(ac075f6f-3a2b-5701-ab52-9f01f1a61529), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityInfo : IUnknown {
  /// Gets a read-only collection of all sensitivity labels detected in the
  /// current web document. This collection contains instances of sensitivity
  /// labels that have been reported by the web content.
  /// `SensitivityLabels` are valid only if SensitivityState is
  /// `COREWEBVIEW2_SENSITIVITY_LABELS_STATE_AVAILABLE`.
  [propget] HRESULT SensitivityLabels([out, retval] ICoreWebView2StagingSensitivityLabelCollectionView** value);

  /// Gets the current state of sensitivity label detection.
  /// Refer `COREWEBVIEW2_SENSITIVITY_LABELS_STATE` for different states.
  [propget] HRESULT SensitivityLabelsState([out, retval] COREWEBVIEW2_SENSITIVITY_LABELS_STATE* value);
}

/// Receives `SensitivityInfoChanged` events.
[uuid(ada2e261-0e15-5b64-8422-f4373eb0d552), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityInfoChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] IUnknown* args);
}

/// Extension of the ICoreWebView2 interface that provides sensitivity label
/// change notification capabilities. This interface enables applications to
/// monitor and respond to changes in the sensitivity classification of web
/// content loaded in the WebView2 control. When sensitivity labels are
/// detected, updated, or removed from web pages, the SensitivityInfoChanged
/// event is raised.
[uuid(862c39a8-f64f-5a97-bae2-db5651020b34), object, pointer_default(unique)]
interface ICoreWebView2Staging32 : IUnknown {
  /// Gets the current state of sensitivity label detection for the content
  /// loaded in the WebView2 control.
  /// See `ICoreWebView2SensitivityInfo` for more details.
  [propget] HRESULT SensitivityInfo([out, retval] ICoreWebView2StagingSensitivityInfo** value);

  /// Adds an event handler for the `SensitivityInfoChanged` event.
  /// Event raised when the sensitivity label classification of web page changes.
  /// Web page may report sensitivity labels via
  /// [`Page Interaction Restriction Manager`](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md).
  /// This event is triggered when the WebView2 control detects a change in the
  /// sensitivity labels associated with the currently loaded web page.
  /// Changes can occur when navigating to a new page in the main frame,
  /// when the existing page updates its sensitivity label information.
  /// On navigation to a new page `SensitivityInfoChanged` event is raised
  /// just after the `NavigationStarting` event. Applications can subscribe
  /// to this event to receive notifications about sensitivity changes.
  /// The event handler can then query the `SensitivityInfo` property
  /// to get the latest sensitivity label information and take appropriate
  /// actions based on the updated sensitivity classification.
  HRESULT add_SensitivityInfoChanged(
      [in] ICoreWebView2StagingSensitivityInfoChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_SensitivityInfoChanged`.
  HRESULT remove_SensitivityInfoChanged(
      [in] EventRegistrationToken token);
}
```

### .NET/WinRT

```c#
enum CoreWebView2SensitivityLabelKind
{
    Mip = 0,
};

enum CoreWebView2SensitivityLabelsState
{
    NotApplicable = 0,
    Pending = 1,
    Available = 2,
};

runtimeclass CoreWebView2SensitivityLabel
{
    // ICoreWebView2StagingSensitivityLabel members
    CoreWebView2SensitivityLabelKind LabelKind { get; };
}

runtimeclass CoreWebView2SensitivityInfo
{
    // ICoreWebView2StagingSensitivityInfo members
    IVectorView<CoreWebView2SensitivityLabel>  SensitivityLabels { get; };

    CoreWebView2SensitivityLabelsState SensitivityState { get; };
}


runtimeclass CoreWebView2MipSensitivityLabel
{
    // ICoreWebView2StagingMipSensitivityLabel members
    String LabelId { get; };

    String OrganizationId { get; };
}
runtimeclass CoreWebView2
{
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Staging32")]
    {
        // ICoreWebView2Staging32 members
        CoreWebView2SensitivityInfo SensitivityInfo { get; };

        event Windows.Foundation.TypedEventHandler<CoreWebView2, IInspectable> SensitivityInfoChanged;
    }
}
```
