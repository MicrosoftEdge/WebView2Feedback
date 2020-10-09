# Background
We have received feedbacks that there is a need to access local files in WebView2. In this document we describe the APIs for this scenario. We'd appreciate your feedback.


# Description
To access local files in WebView2, define a virutal host name to local folder mapping using the `AddVirtualHostNameToFolderMapping` API,
and then refer to local files under the folder with a normal http/https url with the virtual host name.

# Examples
Suppose the app has index.html file next to its exe file. The following code snippet demonstrates how to define a mapping
for `app-file.invalid` host name so that it can be accessed from pages using normal http/https url like https://app-file.invalid/index.html.

## Win32 C++
```cpp
webview2->AddVirtualHostNameToFolderMapping(
    L"app-file.invalid", L".", COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
webview2->Navigate("https://app-file.invalid/index.html");
```

## .Net and WinRT
```c#
webView.CoreWebView2.AddVirtualHostNameToFolderMapping(
    "app-file.invalid", ".", CoreWebView2HostResourceAccessKind.DenyCors);
webView.Navigate("https://app-file.invalid/index.html");
```

# Remarks
Choose a virtual host name that will not be used by real sites.  
If you own a domain (like example.com), an option is to use a sub domain reserved for the app (like my-app.example.com).  
If you don't own a domain, [RFC 6761](https://tools.ietf.org/html/rfc6761) has reserved several special-use domain names that would
not be used by real sites, like .example, .test, and .invalid.

Give only minimal cross orign access neccessary to run the app. If there is no need to access local resources
from other origins, use COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++
The follow table illustrates the host resource cross origin access according to access context and `COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND`.  
Cross Origin Access Context | DENY | ALLOW | DENY_CORS
--- | --- | --- | ---
From DOM like src of img or script element| Deny | Allow | Allow
From Script like Fetch or XMLHttpRequest| Deny | Allow | Deny
```IDL
/// Kind of cross origin resource access allowed for host resources during download.
/// Note that other normal access checks like same origin DOM access check and [Content
/// Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP) still apply.
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

  /// Add a host name mapping for host resources in a folder.
  /// After adding the mapping, the app can then use http or https urls with the specified hostName as host name
  /// of the urls to access files in the local folder specified by folderPath.
  /// This applies to top level document and iframe navigations as well as sub resource references from a document.
  /// accessKind specifies the kind of access control to the host resources from other sites.
  /// Relative folderPath is supported and interpreted as relative to the exe path of the app.
  /// For example, after calling AddVirtualHostNameToFolderMapping(L"app-file.invalid", L".",
  /// COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY), navigating to https://app-file.invalid/my-local-file.html
  /// will show content from my-local-file.html in the same folder as the app's exe file.
  HRESULT AddVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName,
      [in] LPCWSTR folderPath,
      [in] COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND accessKind);
  /// Remove a host name mapping for local folder that was added by AddVirtualHostNameToFolderMapping.
  HRESULT RemoveVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName);
}
```

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
        public void AddVirtualHostNameToFolderMapping(string hostName, string folderPath, CoreWebView2HostResourceAccessKind accessKind);
        public void RemoveVirtualHostNameToFolderMapping(string hostName);
    }
}
```
