Custom Storage Partition
===

# Background
For certain WebView host apps, there is a desire to have different contexts for
different WebViews using the same profile so that when the same websites run in
these WebViews, they will have different DOM storages and cookie jars. An example
is different accounts within an application.
Previosly, the application can use different profiles for different contexts, but
that has 2 short comings:
- WebViews from different profiles are not allowed to have opener/opened window relationship.
- Using profiles means totally different storage for all files like http caches and less performance.

To help managing different application contexts while using the same profile, we are
introducing an API to set custom storage parition and an API to clear all data in
a custom storage partition.

When an application sets custom storage parition for a WebView, the sites and iframes
running inside the WebView will act as if the site were running in a third party iframe
inside a top level site uniquelly associated with the custom storage partition id and have
separate [storage partition](https://developer.chrome.com/docs/privacy-sandbox/storage-partitioning/)
and [cookie partition](https://developer.chrome.com/docs/privacy-sandbox/chips/).

# Conceptual pages (How To)
This feature depends on [storage partition](https://developer.chrome.com/docs/privacy-sandbox/storage-partitioning/)
and [cookie partition](https://developer.chrome.com/docs/privacy-sandbox/chips/) browser
features which are currently experimental. Before those features are enabled by default,
the application must enable them by ensuring `--enable-features=ThirdPartyStoragePartitioning,PartitionedCookies`
is set in [CoreWebView2EnvironmentOptions.AdditionalBrowserArguments](https://learn.microsoft.com/microsoft-edge/webview2/reference/winrt/microsoft_web_webview2_core/corewebview2environmentoptions#additionalbrowserarguments)
used to create CoreWebView2Environment. If not set, no custom storage partition will be
created and all data will be treated as unpartitioned and stored in the global default
location for the profile.
The custom storage partition APIs will remain experiemental when related browser features
are still experimental.

# Examples

The example below illustrates how to set partition id on WebView and how to clear all
data stored in the custom storage partition.

## Win32 C++
```cpp
        
        void OnWebViewCreated()
        {
           // ...
           // other WebView setup like add event handlers, update settings.
           
           // Sets custom storage partition identified by the partitionId, which uniquely
           // identifies an application context.
           PCWSTR partitionId = L"Partition 1";
           CHECK_FAILURE(m_webview->put_CustomStoragePartitionId(partitionId));
           
           // Navigate to start page
           m_webview->Navigation(startPage);
        }
        
        // Clears all data in custom storage partition identified by the partitionId.
        // Called when the application context is removed.
        HRESULT ClearPartitionData(PCWSTR partitionId)
        {
          wil::com_ptr<ICoreWebView2Profile> webView2Profile;
          CHECK_FAILURE(m_webview->get_Profile(&webView2Profile));
          auto webView2Profile8 = webView2Profile.try_query<ICoreWebView2Profile8>();
          CHECK_FEATURE_RETURN(webView2Profile8);
          CHECK_FAILURE(webView2Profile8->ClearCustomStoragePartitionData(
            partitionId,
            Callback<ICoreWebView2StagingClearCustomStoragePartitionDataCompletedHandler>(
                [this](HRESULT result) -> HRESULT
                {
                    if (SUCCEEDED(result))
                    {
                        AsyncMessageBox(L"Completed", L"Clear Custom Partition Data");
                    }
                    else
                    {
                        std::wstringstream message;
                        message << L"Failed: " << std::to_wstring(result) << L"(0x" << std::hex
                                << result << L")" << std::endl;
                        AsyncMessageBox(message.str(), L"Clear Custom Partition Data");
                    }
                    return S_OK;
                }).Get()));
          return S_OK;
        }
        
```

## .NET/WinRT
```c#
        // Sets custom storage partition identified by the partitionId, which uniquely
        // identifies an application context.
        void CoreWebView_Created()
        {
           // ...
           // other WebView setup like add event handlers, update settings.
           
           // Sets custom storage partition identified by the partitionId, which uniquely
           // identifies an application context.
           string partitionId = "Partition 1";
           m_webview.CustomStoragePartitionId = partitionId;
           
           // Navigate to start page
           m_webview.Navigation(startPage);
        }
        
        // Clears all data in custom storage partition identified by the partitionId.
        // Called when the application context is removed.
        async void ClearPartitionData(string partitionId)
        {
          await m_webview.Profile.ClearCustomStoragePartitionDataAsync(partitionId);
          MessageBox.Show(this, "Completed", "Clear Custom Partition Data");
        }

```

# API Details
## Win32 C++
```
interface ICoreWebView2_18 : IUnknown {
  /// Gets the `CustomStoragePartitionId` property.
  [propget] HRESULT CustomStoragePartitionId([out, retval] LPWSTR* customStoragePartitionId);

  /// Sets the `CustomStoragePartitionId` property.
  /// This feature requires enabling 2 experimental browser features to work properly.
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
  /// If `customStoragePartitionId` is nullptr or empty string, the
  /// `CustomStoragePartitionId` will be reset and the page inside the WebView
  /// will work normally with data treated as unpartitioned.
  /// The `customStoragePartitionId` parameter is case sensitive. The default is
  /// an empty string. There is no restriction on the length or what characters
  /// can be used in partition id.
  /// The change of the custom storage partition id will be applied to new 
  /// page or iframe navigations and not impact existing pages and iframes.
  /// To avoid accidentally use new partition id for pending navigations of old page
  /// or iframe, it is recommended to create a new WebView for new partition instead
  /// of changing partition. If you really have to change partition, it is
  /// recommended to navigate to a blank page before setting the new partition
  /// id and navigate to a page for the new partition.
  /// 
  /// As setting custom storage partition id does not change DOM security
  /// model, developers should be very careful for WebViews with opener and
  /// opened window relationship, especially when the pages in the WebViews
  /// have same origin, like when the opened window is the same site or
  /// about:blank. The pages in these WebViews can access each other’s DOM and
  /// therefore can potentially access DOM storage and cookies in different
  /// partition for the same site. It is recommended to set the same custom
  /// storage partition id for these WebViews, unless there is an absolute need
  /// to set different partition ids and only trusted code is hosted in them.
  ///
  [propput] HRESULT CustomStoragePartitionId([in] LPCWSTR customStoragePartitionId);
}

interface ICoreWebView2Profile8 : IUnknown {
  /// Clears all DOM storage and cookies in the custom storage partition 
  /// identified by the `customStoragePartitionId`.
  /// As DOM storage and cookies in the custom storage partition is also browsing
  /// data, they will also be cleared when `ClearBrowsingData`,
  /// `ClearBrowsingDataInTimeRange` or `ClearBrowsingDataAll` is called and
  /// the clearing condition is met.
  ///
  HRESULT ClearCustomStoragePartitionData(
      [in] LPCWSTR customStoragePartitionId,
      [in] ICoreWebView2ClearCustomStoragePartitionDataCompletedHandler* handler);
}

interface ICoreWebView2ClearCustomStoragePartitionDataCompletedHandler : IUnknown {

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
            public string CustomStoragePartitionId { get; set; };
        }
    }

    class CoreWebView2Profile
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile8")]
        {
            public async Task ClearCustomStoragePartitionDataAsync(string CustomStoragePartitionId);
        }
    }
```
