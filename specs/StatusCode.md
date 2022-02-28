# Background
In the `NavigationCompleted` event, the `WebErrorStatus` property provides information about why a
navigation may have failed.  However, this is more geared toward network failures, and doesn't
provide a comprehensive mapping of HTTP status codes.  And even if it did provide an enum value
for every common HTTP status code, it is still possible for a server to respond with a custom
status code, which an application might want to recognize and handle.

The `WebResourceResponseReceived` event does provide information about the response, including
its HTTP status, but it is difficult to correlate a `WebResourceResponse` with a given navigation.

There are various ways the API could be improved to provide this information, but for now we are
going with the simplest approach, and adding a new property that provides an HTTP status code in
the NavigationCompleted event.

# Description
The `NavigationCompletedEventArgs` interface will be given a new property, `StatusCode`, which has
the HTTP status code of the navigation if it involved an HTTP request.  For instance, this will
usually be 200 if the request was successful, 404 if page was not found, etc.

The `StatusCode` property will be 0 in the following cases:
* The navigation did not involve an HTTP request.  For instance, if it was a navigation to a
  file:// URL, or if it was a same-document navigation.
* The navigation failed before a response was received.  For instance, if the hostname was not
  found, or if there was a network error.

In those cases, you can get more information from the `IsSuccess` and `WebErrorStatus` properties.

If the navigation receives a successful HTTP response, but the navigated page calls
`window.stop()` before it finishes loading, then `StatusCode` may contain a success code like 200,
but `IsSuccess` will be false and `WebErrorStatus` will be `ConnectionAborted`.

Since WebView2 handles HTTP continuations and redirects automatically, it is unlikely for
`StatusCode` to ever be in the 1xx or 3xx ranges.

# Examples
## Win32 C++
```c++
void NavigationCompletedSample()
{
    m_webview->add_NavigationCompleted(
        Callback<ICoreWebView2NavigationCompletedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2NavigationCompletedEventArgs* args)
            {
                ICoreWebView2NavigationCompletedEventArgs2* args2;
                args->QueryInterface(IID_PPV_ARGS(&args2));
                if (args2)
                {
                    int status_code;
                    args2->get_StatusCode(&status_code);
                    if (status_code == 403)
                    {
                        ReportForbidden();
                    }
                    else if (status_code == 404)
                    {
                        ReportNotFound();
                    }
                    else if (status_code >= 500 && status_code <= 599)
                    {
                        ReportServerError(status_code);
                    }
                }
                return S_OK;
            }).Get(), nullptr);
}
```

## .NET C#
```c#
void NavigationCompletedSample()
{
    _webview.NavigationCompleted += (object sender, CoreWebView2NavigationCompletedEventArgs args) =>
    {
        int status_code = args.StatusCode;
        if (status_code == 403)
        {
            ReportForbidden();
        }
        else if (status_code == 404)
        {
            ReportNotFound();
        }
        else if (status_code >= 500 && status_code <= 599)
        {
            ReportServerError(status_code);
        }
    };
}
```

# API Details
## MIDL
```
[uuid(6ECF0A0D-D45D-4279-B17E-6E5DC496BA38), object, pointer_default(unique)]
interface ICoreWebViewNavigationCompletedEventArgs2 : ICoreWebView2NavigationCompletedEventArgs {
    [propget] HRESULT StatusCode([out, retval] int* status_code);
}
```

## MIDL3
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2NavigationCompletedEventArgs
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NavigationCompletedEventArgs2")]
        {
            int StatusCode { get; };
        }
    }
}
```
