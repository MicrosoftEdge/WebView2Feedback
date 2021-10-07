# Background
The WebView2 team has been asked for an API to allow end developers to clear the browsing data that is stored in the User Data Folder. Developers want to be able to clear data between each of their customers, clear space, and to clear data on the fly. 

Currently developers can delete the entire User Data Folder to clear this data. This has a few drawbacks: it removes the entire user data folder instead of specific parts which incurs performance costs later on, the WebView must be shutdown fully and then re-initialized, and deleting the entire User Data Folder is a complex process. 
We are creating an API that will allow developers to clear the browsing data programatically in which the developer can specify the data kind to clear. 

In this document we describe the updated API. We'd appreciate your feedback.


# Description
We expose browsing data clearing in two asynchronous APIs:
```IDL
HRESULT ClearBrowsingData(
      [in] COREWEBVIEW2_BROWSING_DATA_KINDS dataKinds,
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler* handler); 

HRESULT ClearBrowsingDataInTimeRange(
      [in] COREWEBVIEW2_BROWSING_DATA_KINDS dataKinds, 
      [in] double startTime,
      [in] double endTime, 
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler* handler);
```
The first method takes `COREWEBVIEW2_BROWSING_DATA_KINDS` which corresponds to the data type(s) to clear as well as a handler which will indicate if the proper data has been cleared successfully. This method clears the data for all time. 

The second method takes the same parameters for the dataKinds and handler, as well as a start and end time in which the API should clear the corresponding data between. The time parameters correspond to how many seconds have passed since the UNIX epoch. 

Both methods clear the data for the associated profile in which the method is called on.

# Examples

## Win32 C++
```cpp

/// Function to clear the autofill data from the last hour
void ClearAutofillData() 
{
    wwil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(m_controller->get_CoreWebView2(&coreWebView2));

    auto webview7 = coreWebView2.try_query<ICoreWebView2_7>();
    if (webview7)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webview7->get_Profile(&profile));
        double endTime = (double)std::time(nullptr);
        double startTime = endTime - 3600;
        /// Get the current time and offset the current time by 3600 seconds to clear the data 
        /// from the start time (one hour ago), until the end time (present time).
        /// This will clear the data for the last hour.
        COREWEBVIEW2_BROWSING_DATA_KINDS dataKinds = (COREWEBVIEW2_BROWSING_DATA_KINDS)
            (COREWEBVIEW2_BROWSING_DATA_KINDS_GENERAL_AUTOFILL |
            COREWEBVIEW2_BROWSING_DATA_KINDS_PASSWORD_AUTOSAVE));
        CHECK_FAILURE(profile->ClearBrowsingDataInTimeRange(
            dataKinds, startTime, endTime,
            Callback<ICoreWebView2StagingClearBrowsingDataCompletedHandler>(
                [this](HRESULT error)
                    -> HRESULT {
                    LPCWSTR result = error == S_OK ? L"Succeeded" : L"Failed";
                    RunAsync([this, result]() {
                        MessageBox(nullptr, result, L"Clear Browsing Data", MB_OK);
                    });
                    return S_OK;
                })
                .Get()));
    }
}
```

### .NET, WinRT
```c#

private void ClearAutofillData() 
{
    CoreWebView2Profile profile;
    if (webView.CoreWebView2 != null) 
    {
        profile = webView.CoreWebView2.Profile;
        double endTime = DateTimeOffset.Now.ToUnixTimeSeconds();
        // Get the current time which is the time in which the browsing data will be cleared until.
        double startTime = endTime - 3600;
        // Offset the current time by 3600 seconds to clear the browsing data from the last hour.
        CoreWebView2BrowsingDataKinds dataKinds = (CoreWebView2BrowsingDataKinds)(CoreWebView2BrowsingDataKinds.GeneralAutofill | CoreWebView2BrowsingDataKinds.PasswordAutosave);
        await profile.ClearBrowsingDataAsync(dataKinds, startTime, endTime);
    }
}

```

# API Notes
See [API Details](#api-details) section below for API reference.


# API Details

## Win32 C++

```IDL
interface ICoreWebView2ClearBrowsingDataCompletedHandler;

/// Specifies the datatype for the
/// `ICoreWebView2Profile::ClearBrowsingData` method.
[v1_enum]
typedef enum COREWEBVIEW2_BROWSING_DATA_KINDS {
  /// Specifies data stored by the AppCache DOM feature.
  COREWEBVIEW2_BROWSING_DATA_KINDS_APP_CACHE = 1 << 0,

  /// Specifies file systems data.
  COREWEBVIEW2_BROWSING_DATA_KINDS_FILE_SYSTEMS = 1 << 1,

  /// Specifies data stored by the IndexedDB DOM feature.
  COREWEBVIEW2_BROWSING_DATA_KINDS_INDEXED_DB = 1 << 2,

  /// Specifies data stored by the localStorage DOM API.
  COREWEBVIEW2_BROWSING_DATA_KINDS_LOCAL_STORAGE = 1 << 3,

  /// Specifies data stored by the Web SQL database DOM API.
  COREWEBVIEW2_BROWSING_DATA_KINDS_WEB_SQL = 1 << 4,

  /// Specifies cache storage which stores the network requests
  /// and responses. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_CACHE_STORAGE = 1 << 5,

  /// Specifies DOM storage data. This browsing data kind is inclusive 
  /// of COREWEBVIEW2_BROWSING_DATA_KINDS_APP_CACHE, 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_FILE_SYSTEMS,
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_INDEXED_DB, 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_LOCAL_STORAGE,
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_WEB_SQL, 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_CACHE_STORAGE.
  COREWEBVIEW2_BROWSING_DATA_KINDS_DOM_STORAGE = 
      COREWEBVIEW2_BROWSING_DATA_KINDS_APP_CACHE|
      COREWEBVIEW2_BROWSING_DATA_KINDS_FILE_SYSTEMS | 
      COREWEBVIEW2_BROWSING_DATA_KINDS_INDEXED_DB |
      COREWEBVIEW2_BROWSING_DATA_KINDS_LOCAL_STORAGE | 
      COREWEBVIEW2_BROWSING_DATA_KINDS_WEB_SQL |
      COREWEBVIEW2_BROWSING_DATA_KINDS_CACHE_STORAGE,

  /// Specifies HTTP cookies data.
  COREWEBVIEW2_BROWSING_DATA_KINDS_COOKIES = 1 << 6,

  /// Specifies site data. This browsing data kind
  /// is inclusive of COREWEBVIEW2_BROWSING_DATA_KINDS_DOM_STORAGE and
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_COOKIES. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_SITE = COREWEBVIEW2_BROWSING_DATA_KINDS_DOM_STORAGE | 
      COREWEBVIEW2_BROWSING_DATA_KINDS_COOKIES, 

  /// Specifies content in the HTTP cache including images and other files. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_HTTP_CACHE = 1 << 7,

  /// Specifies download history data. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_DOWNLOAD_HISTORY = 1 << 8, 

  /// Specifies general autofill form data. 
  /// This excludes password information and includes information like: 
  /// names, street and email addresses, phone numbers, and arbitrary input. 
  /// This also includes payment data. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_GENERAL_AUTOFILL = 1 << 9, 

  /// Specifies password autosave data. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_PASSWORD_AUTOSAVE = 1 << 10,

  /// Specifies browsing history data. 
  COREWEBVIEW2_BROWSING_DATA_KINDS_BROWSING_HISTORY = 1 << 11,

  /// Specifies settings data.
  COREWEBVIEW2_BROWSING_DATA_KINDS_SETTINGS = 1 << 12,

  /// Specifies profile data that should be wiped to make it look like a new profile.
  /// This browsing data kind is inclusive of COREWEBVIEW2_BROWSING_DATA_KINDS_SITE,
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_HTTP_CACHE, 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_DOWNLOAD_HISTORY,
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_GENERAL_AUTOFILL, 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_PASSWORD_AUTOSAVE,
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_BROWSING_HISTORY, and 
  /// COREWEBVIEW2_BROWSING_DATA_KINDS_SETTINGS.
  COREWEBVIEW2_BROWSING_DATA_KINDS_PROFILE =  
    COREWEBVIEW2_BROWSING_DATA_KINDS_SITE |
    COREWEBVIEW2_BROWSING_DATA_KINDS_HTTP_CACHE | 
    COREWEBVIEW2_BROWSING_DATA_KINDS_DOWNLOAD_HISTORY |
    COREWEBVIEW2_BROWSING_DATA_KINDS_GENERAL_AUTOFILL | 
    COREWEBVIEW2_BROWSING_DATA_KINDS_PASSWORD_AUTOSAVE |
    COREWEBVIEW2_BROWSING_DATA_KINDS_BROWSING_HISTORY | 
    COREWEBVIEW2_BROWSING_DATA_KINDS_SETTINGS,
} COREWEBVIEW2_BROWSING_DATA_KINDS;

[uuid(DAF8B1F9-276D-410C-B481-58CBADF85C9C), object, pointer_default(unique)]
interface ICoreWebView2Profile : IUnknown {

  /// Clear browsing data based on a data type. This method takes two parameters, 
  /// the first being a mask of one or more `COREWEBVIEW2_BROWSING_DATA_KINDS`. OR operation(s) 
  /// can be applied to multiple `COREWEBVIEW2_BROWSING_DATA_KINDS` to create a mask 
  /// representing those data types. The browsing data kinds that are supported 
  /// are listed below. These data kinds follow a hierarchical structure in which 
  /// nested bullet points are included in their parent bullet point's data kind.
  /// Ex: DOM storage is encompassed in site data which is encompassed in the profile data. 
  /// * Profile
  ///   * Site Data
  ///     * DOM Storage: App Cache, File Systems, Indexed DB, Local Storage, Web SQL, Cache 
  ///         Storage
  ///     * Cookies 
  ///   * HTTP Cache 
  ///   * Download History
  ///   * General Autofill 
  ///   * Password Autosave
  ///   * Browsing History
  ///   * Settings  
  /// The completed handler will be invoked when the browsing data has been cleared and will 
  /// indicate if the specified data was properly cleared.
  /// If the WebView object is closed before the clear browsing data operation 
  /// has completed, the handler will be released, but not invoked. In this case 
  /// the clear browsing data operation may or may not be completed. 
  /// ClearBrowsingData clears the `dataKinds` for all time. 
  HRESULT ClearBrowsingData(
      [in] COREWEBVIEW2_BROWSING_DATA_KINDS dataKinds,
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler* handler);
  
  /// ClearBrowsingDataInTimeRange behaves like ClearBrowsingData except that it
  /// takes in two additional parameters for the start and end time for which it 
  /// should clear the data between.  The `startTime` and `endTime` 
  /// parameters correspond to the number of seconds since the UNIX epoch. 
  ///
  /// \snippet AppWindow.cpp ClearBrowsingData
  HRESULT ClearBrowsingDataInTimeRange(
      [in] COREWEBVIEW2_BROWSING_DATA_KINDS dataKinds, 
      [in] double startTime,
      [in] double endTime, 
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler* handler);
}

/// The caller implements this interface to receive the `ClearBrowsingData` result.
[uuid(27676699-FE17-4E2B-8C1B-267395A04ED5), object, pointer_default(unique)]
interface ICoreWebView2ClearBrowsingDataCompletedHandler : IUnknown {
  /// Provide the completion status of the corresponding asynchronous method. 
  HRESULT Invoke([in] HRESULT errorCode);
}

```
### .NET, WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    [Flags] enum CoreWebView2BrowsingDataKinds
    {
        AppCache = 1,
        FileSystems = 2,
        IndexedDb = 4,
        LocalStorage = 8,
        WebSql = 16,
        CacheStorage = 32,
        DomStorage = 63,
        Cookies = 64,
        Site = 127,
        HttpCache = 128,
        DownloadHistory = 256,
        GeneralAutofill = 512,
        PasswordAutosave = 1024,
        BrowsingHistory = 2048,
        Settings = 4096,
        Profile = 8191,
    };

    public partial class CoreWebView2Profile
    {
        public async Task<bool> ClearBrowsingDataAsync(CoreWebView2BrowsingDataKinds dataKinds);
        public async Task<bool> ClearBrowsingDataAsync(CoreWebView2BrowsingDataKinds dataKinds, double startTime, double endTime);
    }
}
```
