# Background
We have received feedbacks that there is a need to access local files in WebView2. In this document we describe the APIs for this scenario. We'd appreciate your feedback.


# Description
To access local files in WebView2, define a virtual host name to local folder mapping using the `SetVirtualHostNameToFolderMapping` API,
and then refer to local files under the folder with a normal http/https url with the virtual host name.

# Examples
Suppose the app has index.html file in `asset` sub folder in the folder where its exe file is. The following code snippet demonstrates how to define a mapping
for `appassets.webview2.microsoft.com` host name so that it can be accessed using normal http/https url like https://appassets.webview2.microsoft.com/index.html.

## Win32 C++
```cpp
webview2->SetVirtualHostNameToFolderMapping(
    L"appassets.webview2.microsoft.com", L"assets", COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
webview2->Navigate(L"https://appassets.webview2.microsoft.com/index.html");
```

## .Net
```c#
webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
    "appassets.webview2.microsoft.com",
    "assets", CoreWebView2HostResourceAccessKind.DenyCors);
webView.Source = new Uri("https://appassets.webview2.microsoft.com/index.html");
```

## WinRT
Suppose the app has index.html file in a `book1` sub folder of the app's LocalFolder folder. The following code snippet demonstrates how to define a mapping
for `book1.appassets.webview2.microsoft.com` host name so that it can be accessed using normal http/https url like https://book1.appassets.webview2.microsoft.com/index.html.
```c#
Windows.Storage.StorageFolder localFolder = Windows.Storage.ApplicationData.Current.LocalFolder;
string book1_path = localFolder.Path + @"\book1";
webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
    new Windows.Networking.HostName("book1.appassets.webview2.microsoft.com"),
    book1_path, CoreWebView2HostResourceAccessKind.DenyCors);
webView.Source = new Uri("https://book1.appassets.webview2.microsoft.com/index.html");
```


# Remarks
Choose a virtual host name that will not be used by real sites.  
If you own a domain (like example.com), an option is to use a sub domain reserved for the app (like my-app.example.com).  
We have also reserved a special domain appassets.webview2.microsoft.com for this usage.

The host name used in the APIs is canonicalized using Chromium's host name parsing logic
before being used internally.   
All host names that are canonicalized to the same string are considered identical.   
For example, `EXAMPLE.COM` and `example.com` are considered the same host name.
An international host name and its puny coded host name are considered the same host name.   
There is no DSN resolution for host name and trailing '.' is not normalized as part of canonicalization.
Therefore `example.com` and `example.com.` are treated as different host names. So are `virtual-host-name` and `virtual-host-name.example.com` when the DNS suffix of the machine is `example.com`.

Give only minimal cross origin access necessary to run the app. If there is no need to access local resources
from other origins, use COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
The following table illustrates the host resource cross origin access according to
access context and `COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND`.  
Cross Origin Access Context | DENY | ALLOW | DENY_CORS
--- | --- | --- | ---
From DOM like src of img, script or iframe element| Deny | Allow | Allow
From Script like Fetch or XMLHttpRequest| Deny | Allow | Deny
```IDL
/// Kind of cross origin resource access allowed for host resources during download.
/// Note that other normal access checks like same origin DOM access check and [Content
/// Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP) still apply.
/// The following table illustrates the host resource cross origin access according to
/// access context and `COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND`.  
/// Cross Origin Access Context | DENY | ALLOW | DENY_CORS
/// --- | --- | --- | ---
/// From DOM like src of img, script or iframe element| Deny | Allow | Allow
/// From Script like Fetch or XMLHttpRequest| Deny | Allow | Deny
[v1_enum]
typedef enum COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND {
  /// All cross origin resource access is denied, including normal sub resource access
  /// as src of a script or image element.
  COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY,

  /// All cross origin resource access is allowed, including accesses that are
  /// subject to Cross-Origin Resource Sharing(CORS) check. The behavior is similar to
  /// a web site sends back http header Access-Control-Allow-Origin: *.
  COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW,

  /// Cross origin resource access is allowed for normal sub resource access like
  /// as src of a script or image element, while any access that subjects to CORS check
  /// will be denied.
  /// See [Cross-Origin Resource Sharing](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
  /// for more information.
  COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS,
} COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND;

interface ICoreWebView2_2 : ICoreWebView2 {

  /// Set a mapping between a virtual host name and host resources in a folder.
  /// After setting the mapping, the app can then use http or https urls with the specified hostName as host name
  /// of the urls to access files in the local folder specified by folderPath.
  /// This applies to top level document and iframe navigations as well as sub resource references from a document.
  /// This also applies to dedicated and shared worker scripts, but does not apply to service worker scripts.
  /// accessKind specifies the kind of access control to the host resources from other sites.
  /// Both absolute and relative path are supported for folderPath. Relative path is interpreted as relative
  /// to the folder where the exe of the app is in.
  /// For example, after calling AddVirtualHostNameToFolderMapping(L"appassets.webview2.microsoft.com", L"assets",
  /// COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY), navigating to https://appassets.webview2.microsoft.com/my-local-file.html
  /// will show content from my-local-file.html in the assets sub folder of the folder that has the app's exe file.
  ///
  /// Choose a virtual host name that will not be used by real sites.
  /// If you own a domain (like example.com), an option is to use a sub domain reserved for
  /// the app (like my-app.example.com).
  /// We have also reserved a special domain appassets.webview2.microsoft.com for this usage.
  ///
  /// The host name used in the APIs is canonicalized using Chromium's host name parsing logic
  /// before being used internally.
  /// All host names that are canonicalized to the same string are considered identical.
  /// For example, `EXAMPLE.COM` and `example.com` are considered the same host name.
  /// An international host name and its puny coded host name are considered the same host name.
  /// There is no DSN resolution for host name and trailing '.' is not normalized as part of canonicalization.
  /// Therefore `example.com` and `example.com.` are treated as different host names. So are
  /// `virtual-host-name` and `virtual-host-name.example.com` when the DNS suffix of the machine is `example.com`.
  ///
  /// Give only minimal cross origin access necessary to run the app. If there is no need to
  /// access local resources from other origins, use COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY.
  ///
  HRESULT SetVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName,
      [in] LPCWSTR folderPath,
      [in] COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND accessKind);
  /// Clear a host name mapping for local folder that was added by SetVirtualHostNameToFolderMapping.
  HRESULT ClearVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName);
}
```

## .Net

```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2HostResourceAccessKind
    {
        Deny = 0,
        Allow = 1,
        DenyCors = 2
    }

    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public void SetVirtualHostNameToFolderMapping(string hostName, string folderPath, CoreWebView2HostResourceAccessKind accessKind);
        public void ClearVirtualHostNameToFolderMapping(string hostName);
    }
}
```

## WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public enum CoreWebView2HostResourceAccessKind
    {
        Deny = 0,
        Allow = 1,
        DenyCors = 2
    }

    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public void SetVirtualHostNameToFolderMapping(Windows.Networking.HostName hostName, string folderPath, CoreWebView2HostResourceAccessKind accessKind);
        public void ClearVirtualHostNameToFolderMapping(string hostName);
    }
}
```
