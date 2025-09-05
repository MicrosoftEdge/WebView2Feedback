Sensitivity label support for Webview2
===

# Background
Web pages may contain content with sensitive information. Such information can be identified using data loss protection methods. The purpose of this API is to provide sensitivity label information, communicated by web pages through the Page Interaction Restriction Manager (see details here), to the host application. This enables the host application to be informed of the presence of sensitive content.

# Description

We propose introducing a SensitivityLabelChanged event to the CoreWebView2 object, enabling applications to monitor changes in sensitivity labels within hosted content. This functionality is restricted to URLs explicitly included in an allow list configured by the application. The allow list can be set at the profile level, thereby enabling the Page Interaction Restriction Manager for content within specified URLs. By default, the allow list is empty, preventing hosted content from transmitting sensitivity label information.
The core features of this proposal are as follows:
•	Configure the allowlist filter for Page Interaction Restriction Manager at the profile level.
•	After setup, the manager is available on allowlisted pages. Content can send sensitivity labels to the platform via the API.
•	When a label changes, an event notifies the platform of all labels on that page.
•	Sensitivity labels are cleared when navigating away from the current WebView.

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

# API Details

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
