Sensitivity label support for Webview2
===

# Background
Web pages may contain content with sensitive information. Such information can be identified using data loss protection (DLP) methods. The purpose of this API is to provide sensitivity label information, communicated by web pages through the [PageInteractionRestrictionManager](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md), to the host application. This enables the host application to be informed of the presence of sensitive content.

# Description

This API introduces a SensitivityLabelChanged event to the CoreWebView2 object, enabling applications to monitor changes in sensitivity labels within hosted content. This functionality is restricted to domains explicitly included in an allow list configured by the application. The allow list can be set at the profile level, thereby enabling the Page Interaction Restriction Manager for content within specified domains. By default, the allow list is empty, preventing hosted content from transmitting sensitivity label information.

The core features of this proposal are as follows:
* Configure the allow list filter for Page Interaction Restriction Manager at the profile level.
* After the setup, the `Page Interaction Restriction Manager` is available on pages in the allow list. Content can send sensitivity labels to the platform via the API.
* When a label changes, an event is raised by WebView2 to hosted app with all the labels on that page.
* Sensitivity labels are cleared when navigating away from the current WebView.

# Examples

## Setting up an allow list

Configure the PageInteractionRestrictionManager allow list to enable Sensitivity label functionality on trusted domains.

### C++ Sample
```cpp
void ConfigureAllowlist()
{
    // Get the WebView2 profile
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView->get_Profile(&profile));

    auto stagingProfile3 = profile.try_query<ICoreWebView2StagingProfile3>();
    if (stagingProfile3) {
        // Create allow list with trusted URLs
        std::vector<std::wstring> allowlist = {
            L"https://intranet.company.com/*",
            L"https://*.company.com/*",
            L"https://trusted-partner.com/*"
        };

        // Convert to LPCWSTR array for COM interface
        std::vector<LPCWSTR> items;
        for (const auto& url : allowlist) {
            items.push_back(url.c_str());
        }

        // Get environment to create string collection
        wil::com_ptr<ICoreWebView2Environment> environment;
        CHECK_FAILURE(m_webView->get_Environment(&environment));

        auto stagingEnvironment15 = environment.try_query<ICoreWebView2StagingEnvironment15>();
        if (stagingEnvironment15) {
            wil::com_ptr<ICoreWebView2StringCollection> stringCollection;
            CHECK_FAILURE(stagingEnvironment15->CreateStringCollection(
                static_cast<UINT32>(items.size()),
                items.data(),
                &stringCollection));

            // Apply the allow list
            CHECK_FAILURE(stagingProfile3->put_PageInteractionRestrictionManagerAllowlist(
                stringCollection.get()));
        }
    }
}
```
### .NET/WinRT
```c#
// Configure allowlist for trusted company URLs
var allowlist = new List<string>
{
    "https://intranet.company.com/*",
    "https://*.company.com/*",           // Wildcard for all company subdomains
    "https://trusted-partner.com/*",
    "https://secure.vendor.net/*"
};

// Set the allowlist on the profile
webView2Control.CoreWebView2.Profile.PageInteractionRestrictionManagerAllowlist = allowlist;

MessageBox.Show($"Allowlist configured with {allowlist.Count} URLs");
```


## Retrieving current allow list
### C++ Sample
```cpp
void GetCurrentAllowlist()
{
    auto stagingProfile3 = m_profile.try_query<ICoreWebView2StagingProfile3>();
    if (stagingProfile3) {
        wil::com_ptr<ICoreWebView2StringCollection> allowlist;
        HRESULT hr = stagingProfile3->get_PageInteractionRestrictionManagerAllowlist(&allowlist);

        if (SUCCEEDED(hr) && allowlist) {
            UINT count = 0;
            CHECK_FAILURE(allowlist->get_Count(&count));

            wprintf(L"Current allowlist contains %u entries:\n", count);
            for (UINT i = 0; i < count; ++i) {
                wil::unique_cotaskmem_string item;
                CHECK_FAILURE(allowlist->GetValueAtIndex(i, &item));
                wprintf(L"  • %s\n", item.get());
            }
        }
    }
}
```

### .NET/WinRT
```c#
// Get current allowlist
var currentAllowlist = webView2Control.CoreWebView2.Profile.PageInteractionRestrictionManagerAllowlist;

Console.WriteLine($"Current allowlist contains {currentAllowlist.Count} entries:");
foreach (var url in currentAllowlist)
{
    Console.WriteLine($"  • {url}");
}
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
              Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabelCollectionView> sensitivityLabelsCollection;
              CHECK_FAILURE(args->get_SensitivityLabels(&sensitivityLabelsCollection));

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
                      Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabel> sensitivityLabel;
                      CHECK_FAILURE(sensitivityLabelsCollection->GetValueAtIndex(i, &sensitivityLabel));

                      // Get the label type
                      COREWEBVIEW2_SENSITIVITY_LABEL_TYPE labelType;
                      CHECK_FAILURE(sensitivityLabel->get_LabelType(&labelType));

                      if (i > 0)
                      {
                          labelsString += L", ";
                      }

                      // Handle different label types
                      switch (labelType)
                      {
                      case COREWEBVIEW2_SENSITIVITY_LABEL_TYPE_MIP:
                      {
                          Microsoft::WRL::ComPtr<ICoreWebView2SensitivityLabelMip> microsoftLabel;
                          if (SUCCEEDED(sensitivityLabel.As(&microsoftLabel)))
                          {
                              wil::unique_cotaskmem_string labelId;
                              wil::unique_cotaskmem_string organizationId;
                              CHECK_FAILURE(microsoftLabel->get_LabelId(&labelId));
                              CHECK_FAILURE(microsoftLabel->get_OrganizationId(&organizationId));

                              labelsString += L"Microsoft Label (ID: " +
                                  std::wstring(labelId.get() ? labelId.get() : L"<empty>") +
                                  L", Org: " +
                                  std::wstring(organizationId.get() ? organizationId.get() : L"<empty>") +
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

# API Details

## Allow listing
### C++

```
[uuid(764ffcc6-b341-5307-8ca4-58face289427), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment15 : IUnknown {
    /// Create an ICoreWebView2StringCollection from an array of strings.
    /// This provides a convenient way to create string collections for use
    /// with WebView2 APIs that require ICoreWebView2StringCollection objects.
    HRESULT CreateStringCollection(
        [in] UINT32 count,
        [in] LPCWSTR* items,
        [out, retval] ICoreWebView2StringCollection** value);
}
```

```
[uuid(7b0ade48-e6a9-5038-b7f7-496ad426d907), object, pointer_default(unique)]
interface ICoreWebView2StagingProfile3 : IUnknown {
    /// Gets the `PageInteractionRestrictionManagerAllowlist` property.
    [propget] HRESULT PageInteractionRestrictionManagerAllowlist([out, retval] ICoreWebView2StringCollection** value);

    /// Sets the `PageInteractionRestrictionManagerAllowlist` property.
    [propput] HRESULT PageInteractionRestrictionManagerAllowlist([in] ICoreWebView2StringCollection* value);
}
```
### .NET/WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Profile
    {
        /// <summary>
        /// Gets or sets the PageInteractionRestrictionManager allowlist.
        /// </summary>
        /// <value>A collection of URL patterns that are exempt from page interaction restrictions.
        /// Pass an empty collection to clear the allowlist.</value>
        public IReadOnlyList<string> PageInteractionRestrictionManagerAllowlist { get; set; }
    }
}
```

## Sensitivity label change event
### C++ 
```
/// Represents the state of sensitivity label detection and processing
/// for web content loaded in the WebView2 control. This enum indicates
/// whether sensitivity labels have been detected, are being processed,
/// or are fully determined for the current web page content.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_STATE {
  /// Indicates that none of the loaded pages are in the allow list. Hence 
  /// none will report sensitivity labels. 
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_NONE,
  /// Indicates that WebView2 has loaded pages from the allow list that can
  /// report sensitivity labels, but the label determination is not yet complete.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_UNDETERMINED,
  /// Indicates that WebView2 has loaded pages from the allow list,
  /// and those pages have provided label information.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_DETERMINED,
} COREWEBVIEW2_SENSITIVITY_LABEL_STATE;

/// Represents the type of sensitivity label applied to web content.
/// Sensitivity labels are used to classify and protect content based on
/// its sensitivity level. 
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_TYPE {
  /// Represents an unknown or unsupported sensitivity label type.
  COREWEBVIEW2_SENSITIVITY_LABEL_TYPE_UNKNOWN,
  /// Represents a Microsoft Information Protection (MIP) sensitivity label.
  COREWEBVIEW2_SENSITIVITY_LABEL_TYPE_MIP,
} COREWEBVIEW2_SENSITIVITY_LABEL_TYPE;

/// Base interface for all sensitivity label types used in WebView2.
/// This interface provides common functionality for accessing sensitivity
/// label information applied to web content. Different label types 
/// (such as Microsoft Information Protection labels) can implement 
/// this interface to provide specific label information and metadata.
[uuid(e0288585-9f8c-5b29-bca8-5de14e024557), object, pointer_default(unique)]
interface ICoreWebView2SensitivityLabel : IUnknown {
  /// Gets the type of the sensitivity label applied to the web content.
  /// This property identifies which sensitivity label system is being used
  /// (such as Microsoft Information Protection or other label providers).
  /// Applications can use this information to determine how to interpret
  /// and handle the label data, as different label types may have different
  /// metadata formats, protection requirements, and policy enforcement
  /// mechanisms.
  [propget] HRESULT LabelType([out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_TYPE* value);
}

/// Interface for Microsoft Information Protection (MIP) sensitivity labels.
/// This interface provides specific information about MIP labels, including
/// label identification and organizational context. 
[uuid(1a562888-3031-5375-b8c5-8afd573e79c8), object, pointer_default(unique)]
interface ICoreWebView2StagingMipSensitivityLabel : IUnknown {
  /// Gets the unique identifier for the Microsoft Information Protection label.
  /// This string contains a GUID that uniquely identifies the specific
  /// sensitivity label within the organization's MIP policy configuration.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT LabelId([out, retval] LPWSTR* value);


  /// Gets the unique identifier for the organization that owns the MIP label.
  /// This string contains a GUID that identifies the Azure Active Directory
  /// tenant or organization that configured and deployed the sensitivity label.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT OrganizationId([out, retval] LPWSTR* value);

}

/// A collection of ICoreWebView2StagingSensitivityLabel.
[uuid(2cb85219-0878-5f38-b7e9-769fab6ff887), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabelCollectionView : IUnknown {
  /// The number of elements contained in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the element at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index, [out, retval] ICoreWebView2StagingSensitivityLabel** value);
}

/// Event arguments for the `SensitivityLabelChanged` event.
/// This interface provides information about sensitivity label changes
/// that occur when web content is loaded or updated in the WebView2 control.
/// The event args contain the current state of sensitivity label detection
/// and a collection of all sensitivity labels that have been reported by
/// the web content via 
/// [`Page Interaction Restriction Manager`](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md). 
[uuid(36de2060-e013-5b03-939b-117d08d0abd5), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabelEventArgs : IUnknown {
  /// Gets a read-only collection of all sensitivity labels detected in the
  /// current web document. This collection contains instances of sensitivity
  /// labels that have been reported by the web content.
  [propget] HRESULT SensitivityLabels([out, retval] ICoreWebView2StagingSensitivityLabelCollectionView** value);


  /// Gets the current state of sensitivity label detection.
  [propget] HRESULT SensitivityState([out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_STATE* value);

}

/// Receives `SensitivityLabelChanged` events.
[uuid(927a011d-bbf3-546b-ba28-1fc0ef4c1f4a), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabelChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2StagingSensitivityLabelEventArgs* args);
}

/// Extension of the ICoreWebView2 interface that provides sensitivity label
/// change notification capabilities. This interface enables applications to
/// monitor and respond to changes in the sensitivity classification of web
/// content loaded in the WebView2 control. When sensitivity labels are
/// detected, updated, or removed from web pages, the SensitivityLabelChanged
/// event is raised.
[uuid(ac4543d5-f466-5622-8b3b-24d3b195525c), object, pointer_default(unique)]
interface ICoreWebView2Staging32 : IUnknown {
  /// Adds an event handler for the `SensitivityLabelChanged` event.
  /// Event raised when the sensitivity label classification of web content changes.
  /// This event is triggered when the WebView2 control detects a change in the
  /// sensitivity labels associated with the currently loaded web content. 
  /// Applications can subscribe to this event to receive notifications
  /// about sensitivity changes. The event args provide the current label state and
  /// the complete collection of detected sensitivity labels.
  HRESULT add_SensitivityLabelChanged(
      [in] ICoreWebView2StagingSensitivityLabelChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_SensitivityLabelChanged`.
  HRESULT remove_SensitivityLabelChanged(
      [in] EventRegistrationToken token);

}
```
### .NET/WinRT
```c#
enum CoreWebView2SensitivityLabelType
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
    // ICoreWebView2StagingSensitivityLabelEventArgs members
    IVectorView<CoreWebView2SensitivityLabel>  SensitivityLabels { get; };

    CoreWebView2SensitivityLabelState SensitivityState { get; };
}

runtimeclass CoreWebView2SensitivityLabelCollectionView
{
    // ICoreWebView2StagingSensitivityLabelCollectionView members
    UInt32 Count { get; };

    CoreWebView2SensitivityLabel GetValueAtIndex(UInt32 index);
}

runtimeclass CoreWebView2SensitivityLabel
{
    // ICoreWebView2StagingSensitivityLabel members
    CoreWebView2SensitivityLabelType LabelType { get; };
}

runtimeclass CoreWebView2MipSensitivityLabel
{
    // ICoreWebView2StagingMipSensitivityLabel members
    String LabelId { get; };

    String OrganizationId { get; };
}

runtimeclass CoreWebView2SensitivityLabelEventArgs
{
    // ICoreWebView2StagingSensitivityLabelEventArgs members
    IVectorView<CoreWebView2SensitivityLabel>  SensitivityLabels { get; };

    CoreWebView2SensitivityLabelState SensitivityState { get; };
}

runtimeclass CoreWebView2
{
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Staging32")]
    {
        // ICoreWebView2Staging32 members
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2SensitivityLabelEventArgs> SensitivityLabelChanged;
    }
}
```
