Sensitivity label support for Webview2
===

# Background
Web pages may contain content with sensitive information. Such information can be identified using data loss protection methods. The purpose of this API is to provide sensitivity label information, communicated by web pages through the [Page Interaction Restriction Manager](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/PageInteractionRestrictionManager/explainer.md), to the host application. This enables the host application to be informed of the presence of sensitive content.

# Description

We propose introducing a SensitivityLabelChanged event to the CoreWebView2 object, enabling applications to monitor changes in sensitivity labels within hosted content. This functionality is restricted to domains explicitly included in an allow list configured by the application. The allow list can be set at the profile level, thereby enabling the Page Interaction Restriction Manager for content within specified domains. By default, the allow list is empty, preventing hosted content from transmitting sensitivity label information.
The core features of this proposal are as follows:
* Configure the allowlist filter for Page Interaction Restriction Manager at the profile level.
* After setup, the manager is available on allowlisted pages. Content can send sensitivity labels to the platform via the API.
* When a label changes, an event notifies the platform of all labels on that page.
* Sensitivity labels are cleared when navigating away from the current WebView.

# Examples

## Setting Up an Allowlist

Configure the PageInteractionRestrictionManager allowlist to enable DLP functionality on trusted domains.

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

```cpp
void ConfigureAllowlist()
{
    // Get the WebView2 profile
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView->get_Profile(&profile));

    auto stagingProfile3 = profile.try_query<ICoreWebView2StagingProfile3>();
    if (stagingProfile3) {
        // Create allowlist with trusted URLs
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

            // Apply the allowlist
            CHECK_FAILURE(stagingProfile3->put_PageInteractionRestrictionManagerAllowlist(
                stringCollection.get()));
        }
    }
}
```

## Retrieving Current Allowlist

```c#
// Get current allowlist
var currentAllowlist = webView2Control.CoreWebView2.Profile.PageInteractionRestrictionManagerAllowlist;

Console.WriteLine($"Current allowlist contains {currentAllowlist.Count} entries:");
foreach (var url in currentAllowlist)
{
    Console.WriteLine($"  • {url}");
}
```

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
## Register for sensitivity label change

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

            if (sensitivityState == COREWEBVIEW2_SENSITIVITY_LABEL_STATE_NONE ||
                sensitivityState == COREWEBVIEW2_SENSITIVITY_LABEL_STATE_UNDETERMINED)
            {
                labelsString = L"<no labels>";
            }
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
              CHECK_FAILURE(args->get_SensitivityLabel(&sensitivityLabelsCollection));

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
                      CHECK_FAILURE(sensitivityLabel->GetLabelType(&labelType));

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
```
/// Enum for sensitivity label State.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_STATE {
  /// There are no allow listed pages loaded that report sensitivity label
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_NONE,
  /// There are allow listed pages in the WebView2 and the sensitivity label is not determined yet.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_UNDETERMINED,
  /// There are allow listed pages in the WebView2 and the sensitivity label is determined.
  COREWEBVIEW2_SENSITIVITY_LABEL_STATE_DETERMINED,
} COREWEBVIEW2_SENSITIVITY_LABEL_STATE;

/// Enum for sensitivity label types.
[v1_enum]
typedef enum COREWEBVIEW2_SENSITIVITY_LABEL_TYPE {
  /// Unknown or unsupported label type.
  COREWEBVIEW2_SENSITIVITY_LABEL_TYPE_UNKNOWN,
  /// Microsoft Information Protection label.
  COREWEBVIEW2_SENSITIVITY_LABEL_TYPE_MIP,
} COREWEBVIEW2_SENSITIVITY_LABEL_TYPE;

/// Base interface for all sensitivity label types.
[uuid(9112ece5-d54d-5d16-a595-275ae574c287), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabel : IUnknown {
  /// Gets the type of this sensitivity label.
  HRESULT GetLabelType(
      [out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_TYPE* value);


}


/// Interface for MIP Sensitivity Label with label ID and organization ID.
[uuid(1a562888-3031-5375-b8c5-8afd573e79c8), object, pointer_default(unique)]
interface ICoreWebView2StagingMipSensitivityLabel : IUnknown {
  /// The string representing the label ID.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  [propget] HRESULT LabelId([out, retval] LPWSTR* value);


  /// The string representing the organization ID.
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


/// Event args for the `SensitivityLabelChanged` event.
[uuid(36de2060-e013-5b03-939b-117d08d0abd5), object, pointer_default(unique)]
interface ICoreWebView2StagingSensitivityLabelEventArgs : IUnknown {
  /// The vector of Sensitivity Labels associated with the current document.
  [propget] HRESULT SensitivityLabels([out, retval] ICoreWebView2StagingSensitivityLabelCollectionView** value);


  /// The state of the sensitivity label.
  [propget] HRESULT SensitivityState([out, retval] COREWEBVIEW2_SENSITIVITY_LABEL_STATE* value);

}

/// A continuation of the ICoreWebView2 interface to notify changes in
/// web content sensitivity label.
[uuid(ac4543d5-f466-5622-8b3b-24d3b195525c), object, pointer_default(unique)]
interface ICoreWebView2Staging32 : IUnknown {
  /// Adds an event handler for the `SensitivityLabelChanged` event.
  /// This event is raised when the web content's sensitivity label changes.
  HRESULT add_SensitivityLabelChanged(
      [in] ICoreWebView2StagingSensitivityLabelChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_SensitivityLabelChanged`.
  HRESULT remove_SensitivityLabelChanged(
      [in] EventRegistrationToken token);


}
```
