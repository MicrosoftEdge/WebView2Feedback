# Background
The WebView2 team has been asked for an API to allow end developers to clear the browsing data that is stored in the User Data Folder. Developers want to be able to clear data between each of their customers, clear space, and to clear data on the fly. 

Currently developers can delete the entire User Data Folder to clear this data. This has a few drawbacks: it removes the entire user data folder instead of specific parts which incurs performance costs later on, the WebView must be shutdown fully and then re-initialized, and deleting the entire User Data Folder is a complex process. 
We are creating an API that will allow developers to clear the browsing data programatically in which the developer can specify the data kind to clear. 

In this document we describe the updated API. We'd appreciate your feedback.


# Description
We expose browsing data clearing in two different asynchronous APIs:
```IDL
HRESULT ClearBrowsingData(
      [in] uint64 dataKinds,
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler *handler); 

HRESULT ClearBrowsingDataInTimeRange(
      [in] uint64 dataKinds, 
      [in] double startTime,
      [in] double endTime, 
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler *handler);
```
The first method takes a uint64 parameter that consists of one or more COREWEBVIEW2_BROWSING_DATA_KIND passed in as well as a handler which will indicate if the proper data has been cleared successfully. The handler will respond with one of three results, which indicate that the method was successful, interrupted, or failed. This method clears the data for all time. 

The second method takes the same parameters for the dataKinds and handler, as well as a start and end time in which the API should clear the corresponding data between. The double time parameters correspond to how many seconds since the UNIX epoch. 
 
The browsing data kinds that are supported are listed below. These data kinds follow a hierarchical structure in which nested bullet points are included in their parent bullet point's data kind. 
Ex: DOM storage is included in site data which is included in the profile data. Each of the following bullets correspond to a COREWEBVIEW2_BROWSING_DATA_KIND. 

* Profile
  * Site Data
    * DOM Storage: App Cache, File Systems, Indexed DB, Local Storage, Web SQL, Cache Storage
        Storage
    * Cookies 
  * HTTP Cache 
  * Download History
  * General Autofill 
  * Password Autosave
  * Browsing History
  * Settings  

# Examples

## Win32 C++
```cpp

/// Function to clear the autofill data 
bool EnvironmentComponent::ClearAutofillData() 
{
    wil::com_ptr<ICoreWebView2Environment5> environment;
    webView->get_Environment(&environment);
    uint64_t data_kinds = COREWEBVIEW2_BROWSING_DATA_KIND_GENERAL_AUTOFILL |
            COREWEBVIEW2_BROWSING_DATA_KIND_PASSWORD_AUTOSAVE;
    CHECK_FAILURE(environment->ClearBrowsingData(
        data_kinds,
        Callback<ICoreWebView2ClearBrowsingDataCompletedHandler>(
            [this](HRESULT error, COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND result_kind)
                -> HRESULT {
                LPCWSTR result;
                switch (result_kind)
                {
                case COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_SUCCEEDED:
                    result = L"Succeeded";
                    break;
                case COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_INTERRUPTED:
                    result = L"Interrupted";
                    break;
                case COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_FAILED:
                    result = L"Failed";
                    break;
                default:
                    result = L"Failed";
                    break;
                }
                MessageBox(nullptr, result, L"Clear Browsing Data", MB_OK);
                return S_OK;
            })
            .Get()));
}
```

### .NET, WinRT
```c#

private void ClearAutofillData() 
{
    var environment = webView2Control.CoreWebView2.Environment;
    try
    {
        CoreWebView2BrowsingDataKind dataKinds = CoreWebView2BrowsingDataKind.GeneralAutofill | CoreWebView2BrowsingDataKind.PasswordAutosave;
        await environment.ClearBrowsingDataAsync((UInt64)dataKinds); 
    }
}

```

# API Notes
See [API Details](#api-details) section below for API reference.


# API Details

## Win32 C++

```IDL
interface ICoreWebView2Environment5
interface ICoreWebView2ClearBrowsingDataCompletedHandler;

[v1_enum]
typedef enum COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND {
  /// Specifies success, all of the specified data kinds
  /// were cleared. 
  COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_SUCCEEDED, 

  /// Specifies interruption, not all of the specified data kinds
  /// were cleared, although a subset of the data kinds may 
  /// have been cleared before the method call was interrupted.  
  COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_INTERRUPTED,
  
  /// Specifies failure, not all of the specified data kinds were
  /// cleared. 
  COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND_FAILED,
} COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND;

/// Specifies the datatype for the
/// `ICoreWebView2Environment2::ClearBrowsingData` method.
[v1_enum]
typedef enum COREWEBVIEW2_BROWSING_DATA_KIND {
  /// Specifies data stored by the AppCache DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_APP_CACHE = 1<<0,

  /// Specifies data stored by the FileSystems DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_FILE_SYSTEMS = 1<<1,

  /// Specifies data stored by the IndexedDB DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_INDEXED_DB = 1<<2,

  /// Specifies data stored by the LocalStorage DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_LOCAL_STORAGE = 1<<3,

  /// Specifies data stored by the Web SQL database DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_WEB_SQL = 1<<4,

  /// Specifies cache storage which stores the network requests
  /// and responses from the CacheStorage DOM API.
  COREWEBVIEW2_BROWSING_DATA_KIND_CACHE_STORAGE = 1<<5,

  /// Specifies DOM storage data. This browsing data kind is inclusive 
  /// of COREWEBVIEW2_BROWSING_DATA_KIND_APP_CACHE, 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_FILE_SYSTEMS,
  /// COREWEBVIEW2_BROWSING_DATA_KIND_INDEXED_DB, 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_LOCAL_STORAGE,
  /// COREWEBVIEW2_BROWSING_DATA_KIND_WEB_SQL, 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_CACHE_STORAGE.
  COREWEBVIEW2_BROWSING_DATA_KIND_DOM_STORAGE = COREWEBVIEW2_BROWSING_DATA_KIND_APP_CACHE|
      COREWEBVIEW2_BROWSING_DATA_KIND_FILE_SYSTEMS | COREWEBVIEW2_BROWSING_DATA_KIND_INDEXED_DB |
      COREWEBVIEW2_BROWSING_DATA_KIND_LOCAL_STORAGE | COREWEBVIEW2_BROWSING_DATA_KIND_WEB_SQL |
      COREWEBVIEW2_BROWSING_DATA_KIND_CACHE_STORAGE,

  /// Specifies HTTP cookies data.
  COREWEBVIEW2_BROWSING_DATA_KIND_COOKIES = 1<<6,

  /// Specifies site data. This browsing data kind
  /// is inclusive of COREWEBVIEW2_BROWSING_DATA_KIND_DOM_STORAGE and
  /// COREWEBVIEW2_BROWSING_DATA_KIND_COOKIES. 
  COREWEBVIEW2_BROWSING_DATA_KIND_SITE = COREWEBVIEW2_BROWSING_DATA_KIND_DOM_STORAGE | 
      COREWEBVIEW2_BROWSING_DATA_KIND_COOKIES, 

  /// Specifies content in the HTTP cache including images and other files. 
  COREWEBVIEW2_BROWSING_DATA_KIND_HTTP_CACHE = 1<<7,

  /// Specifies download history data. 
  COREWEBVIEW2_BROWSING_DATA_KIND_DOWNLOAD_HISTORY = 1<<8, 

  /// Specifies general autofill form data. 
  /// This excludes password information and includes information like: 
  /// names, street and email addresses, phone numbers, and arbitrary input. 
  /// This also includes payment data. 
  COREWEBVIEW2_BROWSING_DATA_KIND_GENERAL_AUTOFILL = 1<<9, 

  /// Specifies password autosave data. 
  COREWEBVIEW2_BROWSING_DATA_KIND_PASSWORD_AUTOSAVE = 1<<10,

  /// Specifies browsing history data. 
  COREWEBVIEW2_BROWSING_DATA_KIND_BROWSING_HISTORY = 1<<11,

  /// Specifies settings data.
  COREWEBVIEW2_BROWSING_DATA_KIND_SETTINGS = 1<<12,

  /// Specifies profile data that should be wiped to make it look like a new profile.
  /// This browsing data kind is inclusive of COREWEBVIEW2_BROWSING_DATA_KIND_SITE,
  /// COREWEBVIEW2_BROWSING_DATA_KIND_HTTP_CACHE, 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_DOWNLOAD_HISTORY,
  /// COREWEBVIEW2_BROWSING_DATA_KIND_GENERAL_AUTOFILL, 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_PASSWORD_AUTOSAVE,
  /// COREWEBVIEW2_BROWSING_DATA_KIND_BROWSING_HISTORY, and 
  /// COREWEBVIEW2_BROWSING_DATA_KIND_SETTINGS.
  COREWEBVIEW2_BROWSING_DATA_KIND_PROFILE =  COREWEBVIEW2_BROWSING_DATA_KIND_SITE |
    COREWEBVIEW2_BROWSING_DATA_KIND_HTTP_CACHE | COREWEBVIEW2_BROWSING_DATA_KIND_DOWNLOAD_HISTORY |
    COREWEBVIEW2_BROWSING_DATA_KIND_GENERAL_AUTOFILL | COREWEBVIEW2_BROWSING_DATA_KIND_PASSWORD_AUTOSAVE
  | COREWEBVIEW2_BROWSING_DATA_KIND_BROWSING_HISTORY | COREWEBVIEW2_BROWSING_DATA_KIND_SETTINGS,
} COREWEBVIEW2_BROWSING_DATA_KIND;

[uuid(4ecfcb16-dd09-4464-9a71-fd8e2d3ac0a2), object, pointer_default(unique)]
interface ICoreWebView2Environment2 : ICoreWebView2Environment {
  /// Clear browsing data based on a data type. This method takes two parameters, 
  /// the first being a mask of one or more COREWEBVIEW2_BROWSING_DATAKIND. Multiple 
  /// COREWEBVIEW2_BROWSING_DATA_KIND values can be orred together to create a mask 
  /// representing multiple data types. The browsing data kinds that are supported 
  /// are listed below. These data kinds follow a hierarchical structure in which 
  /// nested bullet points are included in their parent bullet point's data kind.
  /// Ex: DOM storage is encompassed in site data which is encompassed in the profile data. 
  /// Each of the following bullets correspond to a COREWEBVIEW2_BROWSING_DATA_KIND. 
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
  /// ClearBrowsingData clears the dataKinds for all time. 
  HRESULT ClearBrowsingData(
      [in] uint64 dataKinds,
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler *handler);
      
  /// ClearBrowsingDataInTimeRange takes in two additional parameters for the 
  /// start and end time for which it should clear the data between.  The startTime and endTime 
  /// parameters correspond to the number of seconds since the UNIX epoch. 
  HRESULT ClearBrowsingDataInTimeRange(
      [in] uint64 dataKinds, 
      [in] double startTime,
      [in] double endTime, 
      [in] ICoreWebView2ClearBrowsingDataCompletedHandler *handler);
}

/// The caller implements this interface to receive the ClearBrowsingData result.
[uuid(c2b78e49-5bf5-4d38-a535-668a8a8a30d9), object, pointer_default(unique)]
interface ICoreWebView2ClearBrowsingDataCompletedHandler : IUnknown {
  /// Provide the completion status and result of the corresponding
  /// asynchronous method. The result indicates if the ClearBrowsingData 
  /// call succeeded, was interrupted, or failed. 
  HRESULT Invoke(
      [in] HRESULT errorCode, 
      [in] COREWEBVIEW2_CLEAR_BROWSING_DATA_RESULT_KIND result);
}
```
### .NET, WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2ClearBrowsingDataResultKind
    {
        Succeeded = 0,
        Interrupted = 1, 
        Failed = 2,
    };

    [Flags] enum CoreWebView2BrowsingDataKind
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

    public partial class CoreWebView2Environment
    {
        public async Task<CoreWebView2ClearBrowsingDataResultKind> ClearBrowsingDataAsync(ulong dataKinds);
        public async Task<CoreWebView2ClearBrowsingDataResultKind> ClearBrowsingDataInTimeRangeAsync(ulong dataKinds, double startTime, double endTime);
    }
}
```
