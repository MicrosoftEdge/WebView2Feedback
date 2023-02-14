Custom Data Partition
===

# Background
For certain WebView host apps, there is a desire to have different contexts for
different WebViews using the same profile so that when the same websites run in
these WebViews, they will have different DOM storages and cookie jars. For example,
a content editing application might use one WebView to visit a site as signed in user
to modify content on the site, while using another WebView to visit the same site as
anonymous user to view the changes as seen by normal users.
Previously, the application can use different profiles for different contexts, but
that has 2 short comings:
- WebViews from different profiles are not allowed to have opener/opened window relationship.
- Using profiles means totally different storage for all files like http caches and less performance.

To help managing different application contexts while using the same profile, we are
introducing an API to set custom data partition and an API to clear all data in
a custom data partition.

When an application sets custom data partition for a WebView, the sites and iframes
running inside the WebView will act as if the site were running in a third party iframe
inside a top level site uniquely associated with the custom data partition id and have
separate [storage partition](https://developer.chrome.com/docs/privacy-sandbox/storage-partitioning/)
and [cookie partition](https://developer.chrome.com/docs/privacy-sandbox/chips/).

# Conceptual pages (How To)
This feature depends on [storage partition](https://developer.chrome.com/docs/privacy-sandbox/storage-partitioning/)
and [cookie partition](https://developer.chrome.com/docs/privacy-sandbox/chips/) browser
features which are currently experimental. Before those features are enabled by default,
the application must enable them by ensuring `--enable-features=ThirdPartyStoragePartitioning,PartitionedCookies`
is set in [CoreWebView2EnvironmentOptions.AdditionalBrowserArguments](https://learn.microsoft.com/microsoft-edge/webview2/reference/winrt/microsoft_web_webview2_core/corewebview2environmentoptions#additionalbrowserarguments)
used to create CoreWebView2Environment. If the features are not enabled, no custom data partition will be
created and all data will be treated as unpartitioned and stored in the global default
location for the profile.
The custom data partition APIs will remain experimental when related browser features
are still experimental.

# Examples

The example below illustrates how to set partition id on WebView and how to clear all
data stored in the custom data partition.

## Win32 C++
```cpp
        wil::com_ptr<ICoreWebView2_18> m_webView;
        
        void OnWebViewCreated()
        {
           // ...
           // other WebView setup like add event handlers, update settings.
           
           // Sets custom data partition identified by the partitionId. Used by app
           // to uniquely identify an application context, like for visiting the site
           // as anonymous user instead of the signed in user in other WebViews.
           PCWSTR partitionId = L"Partition 1";
           CHECK_FAILURE(m_webview->put_CustomDataPartitionId(partitionId));
           
           // Navigate to start page
           m_webview->Navigate(startPage);
        }
        
        // Clears all data in custom data partition identified by the partitionId.
        // Called when the custom data partition is no longer needed.
        HRESULT ClearPartitionData(PCWSTR partitionId)
        {
          wil::com_ptr<ICoreWebView2Profile> webView2Profile;
          CHECK_FAILURE(m_webview->get_Profile(&webView2Profile));
          auto webView2Profile8 = webView2Profile.try_query<ICoreWebView2Profile8>();
          CHECK_FEATURE_RETURN(webView2Profile8);
          CHECK_FAILURE(webView2Profile8->ClearCustomDataPartition(
            partitionId,
            Callback<ICoreWebView2ClearCustomDataPartitionCompletedHandler>(
                [this](HRESULT result) -> HRESULT
                {
                    if (SUCCEEDED(result))
                    {
                        AsyncMessageBox(L"Completed", L"Clear Custom Data Partition");
                    }
                    else
                    {
                        std::wstringstream message;
                        message << L"Failed: " << std::to_wstring(result) << L"(0x" << std::hex
                                << result << L")" << std::endl;
                        AsyncMessageBox(message.str(), L"Clear Custom Data Partition");
                    }
                    return S_OK;
                }).Get()));
          return S_OK;
        }
        
```

## .NET/WinRT
```c#
        private CoreWebView2 m_webview;
        
        void CoreWebView_Created()
        {
           // ...
           // other WebView setup like add event handlers, update settings.
           
           // Sets custom data partition identified by the partitionId. Used by app
           // to uniquely identify an application context, like for visiting the site
           // as anonymous user instead of the signed in user in other WebViews.
           string partitionId = "Partition 1";
           m_webview.CustomDataPartitionId = partitionId;
           
           // Navigate to start page
           m_webview.Navigate(startPage);
        }
        
        // Clears all data in custom data partition identified by the partitionId.
        // Called when the custom data partition is no longer needed.
        async void ClearPartitionData(string partitionId)
        {
          await m_webview.Profile.ClearCustomDataPartitionAsync(partitionId);
          MessageBox.Show(this, "Completed", "Clear Custom Data Partition");
        }

```

# API Details
## Win32 C++
```
interface ICoreWebView2_18 : ICoreWebView2_17 {
  /// Gets the `CustomDataPartitionId` property.
  [propget] HRESULT CustomDataPartitionId([out, retval] LPWSTR* customDataPartitionId);

  /// Sets the `CustomDataPartitionId` property.
  /// This API requires enabling 2 experimental browser features to work properly.
  /// These features will be enabled by default in the future.
  /// Before these features are enabled by default, please enable them by ensuring
  /// `--enable-features=ThirdPartyStoragePartitioning,PartitionedCookies` is set in
  /// `AdditionalBrowserArguments` in `CoreWebView2EnvironmentOptions` used to create
  /// CoreWebView2Environment. If these features are not enabled, all data are treated
  /// as unpartitioned and stored in the global default location for the profile.
  /// When it is set, the page in the WebView will act as if the page were hosted in a
  /// top level site uniquely associated with the `partitionId` and have a separate 
  /// storage partition as described in https://developer.chrome.com/docs/privacy-sandbox/storage-partitioning/
  /// and separete cookie partition as described in https://developer.chrome.com/docs/privacy-sandbox/chips/
  /// with all cookies partitioned.
  /// If `customDataPartitionId` is nullptr or empty string, the page inside the
  /// WebView will work normally with data treated as unpartitioned.
  /// The `customDataPartitionId` parameter is case sensitive. The default is
  /// an empty string. There is no restriction on the length or what characters
  /// can be used in partition id.
  /// The change of the custom data partition id will be applied to new 
  /// page or iframe navigations and not impact existing pages and iframes.
  /// To avoid accidentally using the new partition id for new page or iframe navigations
  /// started by the old page, it is recommended to create a new WebView for new partition
  /// instead of changing partition. If you really have to change partition, it is
  /// recommended to navigate to a blank page before setting the new partition
  /// id and navigating to a page with the new partition.
  /// 
  /// As setting custom data partition id does not change DOM security
  /// model, developers should be very careful for WebViews with opener and
  /// opened window relationship, especially when the pages in the WebViews
  /// have same origin, like when the opened window is the same website or
  /// about:blank. The pages in these WebViews can access each other’s DOM and
  /// therefore can potentially access DOM storage and cookies in different
  /// partition for the same website. It is recommended to set the same custom
  /// data partition id for these WebViews, unless there is an absolute need
  /// to set different partition ids and only trusted code is hosted in them.
  ///
  [propput] HRESULT CustomDataPartitionId([in] LPCWSTR customDataPartitionId);
}

interface ICoreWebView2Profile8 : ICoreWebView2Profile7 {
  /// Clears all DOM storage and cookies in the custom data partition 
  /// identified by the `customDataPartitionId`.
  /// If `customDataPartitionId` is nullptr or empty string, the API will fail with
  /// E_INVALIDARG. If no partition is found for the specified `customDataPartitionId`,
  /// the API succeeds without doing anything.
  /// As DOM storage and cookies in the custom data partition is also browsing
  /// data, they will also be cleared when `ClearBrowsingData`,
  /// `ClearBrowsingDataInTimeRange` or `ClearBrowsingDataAll` is called and
  /// the clearing condition is met.
  ///
  HRESULT ClearCustomDataPartition(
      [in] LPCWSTR customDataPartitionId,
      [in] ICoreWebView2ClearCustomDataPartitionCompletedHandler* handler);
}

interface ICoreWebView2ClearCustomDataPartitionCompletedHandler : IUnknown {

  /// Provide the completion status of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode);
}

```

## .NET/WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{

    class CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_18")]
        {
            public string CustomDataPartitionId { get; set; };
        }
    }

    class CoreWebView2Profile
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile8")]
        {
            public async Task ClearCustomDataPartitionAsync(string customDataPartitionId);
        }
    }
```
