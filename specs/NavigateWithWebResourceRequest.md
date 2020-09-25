
# Background
Consumers of the old WebBrowser control that relied on the [Navigate](https://docs.microsoft.com/en-us/previous-versions/aa752133(v=vs.85) API that allowed them to specify HTTP POST data and extra headers as part of navigation, [requested](https://github.com/MicrosoftEdge/WebViewFeedback/issues/69) same ability in WebView2. 

# Description
We propose adding NavigateWithWebResourceRequest to CoreWebView2 as the API that allows a WebView2 to navigate with a specified [CoreWebView2WebResourceRequest](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/dotnet/0-9-628/microsoft-web-webview2-core-corewebview2). This allows the developer to specify extra headers and POST data as part of their request for navigation.
We also propose adding a CreateWebResourceRequest API to [CoreWebView2Environment](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/dotnet/0-9-515/microsoft-web-webview2-core-corewebview2environment) so that developers can create the WebResourceRequest object they'd like to use with NavigateWithWebResourceRequest.

# Examples

```cpp
    // Need to convert post data to UTF-8 as required by the application/x-www-form-urlencoded Content-Type 
    std::wstring postData = std::wstring(L"input=Hello");
    char* postDataString = new char[postData.length()];
    WideCharToMultiByte(
        CP_UTF8, 0, postData.c_str(), postData.length(), postDataString, postData.length(),
        nullptr, nullptr);

    wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest;
    wil::com_ptr<IStream> postDataStream = SHCreateMemStream(
        reinterpret_cast<const BYTE*>(postDataString), postData.length());

    // This acts as a HTML form submit to https://www.w3schools.com/action_page.php
    CHECK_FAILURE(webviewEnvironment->CreateWebResourceRequest(
        L"https://www.w3schools.com/action_page.php", L"POST", postDataStream.get(),
        L"Content-Type: application/x-www-form-urlencoded", &webResourceRequest));
    CHECK_FAILURE(webview->NavigateWithWebResourceRequest(webResourceRequest.get()));
```

```csharp
    UTF8Encoding utfEncoding = new UTF8Encoding();
    byte[] postData = utfEncoding.GetBytes("input=Hello");

    using (MemoryStream postDataStream = new MemoryStream(postData.Length))
    {
      postDataStream.Write(postData, 0, postData.Length);
      CoreWebView2WebResourceRequest webResourceRequest = 
        environment.CreateWebResourceRequest(
          "https://www.w3schools.com/action_page.php",
          "POST",
          postDataStream,
          "Content-Type: application/x-www-form-urlencoded");
      webView.CoreWebView2.NavigateWithWebResourceRequest(webResourceRequest);
    }
```

# Remarks
<!-- Explanation and guidance that doesn't fit into the Examples section. -->

<!-- APIs should only throw exceptions in exceptional conditions; basically,
only when there's a bug in the caller, such as argument exception.  But if for some
reason it's necessary for a caller to catch an exception from an API, call that
out with an explanation either here or in the Examples -->

# API Notes
<!-- Option 1: Give a one or two line description of each API (type
and member), or at least the ones that aren't obvious
from their name.  These descriptions are what show up
in IntelliSense. For properties, specify the default value of the property if it
isn't the type's default (for example an int-typed property that doesn't default to zero.) -->

<!-- Option 2: Put these descriptions in the below API Details section,
with a "///" comment above the member or type. -->

# API Details
<!-- The exact API, in MIDL3 format (https://docs.microsoft.com/en-us/uwp/midl-3/) -->
```idl
// This is the ICoreWebView2 Staging interface.
[uuid(9810c82b-8483-4f1c-b2f4-6244f1010c05), object, pointer_default(unique)]
interface ICoreWebView2Staging : IUnknown {
 ....
  /// Navigate using a constructed WebResourceRequest object. This let's you
  /// provide post data or additional request headers during navigation.
  /// The headers in the WebResourceRequest override headers
  /// added by WebView2 runtime except for Cookie headers. To override cookies
  /// please use the Cookie API.
  /// Method can only be either "GET" or "POST". Provided post data will only
  /// be sent only if the method is "POST" and the uri scheme is HTTP(S).
  /// \snippet ScenarioNavigateWithWebResourceRequest.cpp NavigateWithWebResourceRequest
  HRESULT NavigateWithWebResourceRequest([in] ICoreWebView2WebResourceRequest* request);
}

// This is the ICoreWebView2Environment Staging interface.
[uuid(512e6181-6e99-4744-9b75-183fbefb090b), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment : IUnknown {
  /// Create a new web resource request object.
  /// URI parameter must be absolute URI.
  /// The headers string is the raw request header string delimited by newline
  /// (\r\n). It's also possible to create this object with null headers string
  /// and then use the ICoreWebView2HttpRequestHeaders to construct the headers
  /// line by line.
  /// For information on other parameters see ICoreWebView2WebResourceRequest.
  ///
  /// \snippet ScenarioNavigateWithWebResourceRequest.cpp NavigateWithWebResourceRequest
  HRESULT CreateWebResourceRequest([in] LPCWSTR uri,
                                   [in] LPCWSTR method,
                                   [in] IStream* postData,
                                   [in] LPCWSTR headers,
                                   [out, retval] ICoreWebView2WebResourceRequest** request);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        ...
        /// Create a new web resource request object.
        /// URI parameter must be absolute URI.
        /// The headers string is the raw request header string delimited by newline
        /// (\r\n). It's also possible to create this object with null headers string
        /// and then use the ICoreWebView2HttpRequestHeaders to construct the headers
        /// line by line.
        /// For information on other parameters see ICoreWebView2WebResourceRequest.
        ///
        public CoreWebView2WebResourceRequest CreateWebResourceRequest(String uri,
                                                                String method,
                                                                Stream postData,
                                                                String headers);
    }
    runtimeclass CoreWebView2
    {
        ...
        /// Navigate using a constructed WebResourceRequest object. This let's you
        /// provide post data or additional request headers during navigation.
        /// The headers in the WebResourceRequest override headers
        /// added by WebView2 runtime except for Cookie headers. To override cookies
        /// please use the Cookie API.
        /// Method can only be either "GET" or "POST". Provided post data will only
        /// be sent only if the method is "POST" and the uri scheme is HTTP(S).
        public void NavigateWithWebResourceRequest(CoreWebView2WebResourceRequest request);
    }
}
```

# Appendix
<!-- Anything else that you want to write down for posterity, but 
that isn't necessary to understand the purpose and usage of the API.
For example, implementation details. -->
