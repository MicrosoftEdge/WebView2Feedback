# Background
We have received feedbacks that there is a need to access local files in WebView2. In this document we describe the APIs for this scenario. We'd appreciate your feedback.


# Description
To access local files in WebView2, define a virtual host name to local folder mapping using the `SetVirtualHostNameToFolderMapping` API,
and then refer to local files under the folder with a normal http/https url with the virtual host name.

# Examples
Suppose the app has index.html file in `asset` subfolder located on disk under the same path as the app's executable file.
The following code snippet demonstrates how to define a mapping for `appassets.example` host name so that it can be accessed
using normal http/https url like https://appassets.example/index.html.

## Win32 C++
```cpp
webview2->SetVirtualHostNameToFolderMapping(
    L"appassets.example", L"assets", COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
webview2->Navigate(L"https://appassets.example/index.html");
```

## .Net
```c#
webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
    "appassets.example",
    "assets", CoreWebView2HostResourceAccessKind.DenyCors);
webView.Source = new Uri("https://appassets.example/index.html");
```

## WinRT
Suppose the app has index.html file in a `book1` subfolder under the app's LocalFolder folder. The following code snippet demonstrates how to define a mapping
for `book1.example` host name so that it can be accessed using normal http/https url like https://book1.example/index.html.
```c#
Windows.Storage.StorageFolder localFolder = Windows.Storage.ApplicationData.Current.LocalFolder;
string book1Path = localFolder.Path + @"\book1";
webView.CoreWebView2.SetVirtualHostNameToFolderMapping(
    "book1.example",
    book1Path, CoreWebView2HostResourceAccessKind.DenyCors);
webView.Source = new Uri("https://book1.example/index.html");
```


# Remarks
You should typically choose virtual host names that are never used by real sites.
If you own a domain such as example.com, another option is to use a subdomain reserved for the app (like my-app.example.com).   
[RFC 6761](https://tools.ietf.org/html/rfc6761) has reserved several special-use domain
names that are guaranteed to not be used by real sites (for example, .example, .test, and
.invalid.)   
Apps should use distinct domain names when mapping folder from different sources that
should be isolated from each other. For instance, the app might use app-file.example for
files that ship as part of the app, and book1.example might be used for files containing
books from a less trusted source that were previously downloaded and saved to the disk by
the app.   
The host name used in the APIs is canonicalized using Chromium's host name parsing logic
before being used internally.   
All host names that are canonicalized to the same string are considered identical.
For example, `EXAMPLE.COM` and `example.com` are treated as the same host name.
An international host name and its Punycode-encoded host name are considered the same host
name. There is no DNS resolution for host name and the trailing '.' is not normalized as
part of canonicalization.   
Therefore `example.com` and `example.com.` are treated as different host names. Similarly,
`virtual-host-name` and `virtual-host-name.example.com` are treated as different host names
even if the machine has a DNS suffix of `example.com`.   
Specify the minimal cross-origin access necessary to run the app. If there is not a need to
access local resources from other origins, use COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY.

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

  /// Set a mapping between a virtual host name and a folder path to make available to web sites
  /// via that host name.
  ///
  /// After setting the mapping, documents loaded in the WebView can use HTTP or HTTPS URLs at
  /// the specified host name specified by hostName to access files in the local folder specified
  /// by folderPath.
  ///
  /// This mapping applies to both top-level document and iframe navigations as well as subresource
  /// references from a document. This also applies to dedicated and shared worker scripts but does
  /// not apply to service worker scripts.
  ///
  /// accessKind specifies the level of access to resources under the virtual host from other sites.
  /// Both absolute and relative paths are supported for folderPath. Relative paths are interpreted
  /// as relative to the folder where the exe of the app is in.
  ///
  /// For example, after calling
  /// ```
  ///    SetVirtualHostNameToFolderMapping(
  ///        L"appassets.example", L"assets",
  ///        COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY);
  /// ```
  /// navigating to `https://appassets.example/my-local-file.html` will
  /// show content from my-local-file.html in the assets subfolder located on disk under the same
  /// path as the app's executable file.
  ///
  /// You should typically choose virtual host names that are never used by real sites.
  /// If you own a domain such as example.com, another option is to use a subdomain reserved for
  /// the app (like my-app.example.com).
  ///
  /// [RFC 6761](https://tools.ietf.org/html/rfc6761) has reserved several special-use domain
  /// names that are guaranteed to not be used by real sites (for example, .example, .test, and
  /// .invalid.)
  ///
  /// Apps should use distinct domain names when mapping folder from different sources that
  /// should be isolated from each other. For instance, the app might use app-file.example for
  /// files that ship as part of the app, and book1.example might be used for files containing
  /// books from a less trusted source that were previously downloaded and saved to the disk by
  /// the app.
  ///
  /// The host name used in the APIs is canonicalized using Chromium's host name parsing logic
  /// before being used internally.
  ///
  /// All host names that are canonicalized to the same string are considered identical.
  /// For example, `EXAMPLE.COM` and `example.com` are treated as the same host name.
  /// An international host name and its Punycode-encoded host name are considered the same host
  /// name. There is no DNS resolution for host name and the trailing '.' is not normalized as
  /// part of canonicalization.
  ///
  /// Therefore `example.com` and `example.com.` are treated as different host names. Similarly,
  /// `virtual-host-name` and `virtual-host-name.example.com` are treated as different host names
  /// even if the machine has a DNS suffix of `example.com`.
  ///
  /// Specify the minimal cross-origin access necessary to run the app. If there is not a need to
  /// access local resources from other origins, use COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY.
  HRESULT SetVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName,
      [in] LPCWSTR folderPath,
      [in] COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND accessKind);
  /// Clear a host name mapping for local folder that was added by SetVirtualHostNameToFolderMapping.
  HRESULT ClearVirtualHostNameToFolderMapping(
      [in] LPCWSTR hostName);
}
```

## .Net WinRT

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
