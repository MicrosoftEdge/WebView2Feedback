<!-- 
    Before submitting, delete all "<!-- TEMPLATE" marked comments in this file,
    and the following quote banner:
-->
> See comments in Markdown for how to use this spec template

<!-- TEMPLATE
    The purpose of this spec is to describe new APIs, in a way
    that will transfer to docs.microsoft.com (https://docs.microsoft.com/en-us/microsoft-edge/webview2/).

    There are two audiences for the spec. The first are people that want to evaluate and
    give feedback on the API, as part of the submission process.
    So the second audience is everyone that reads there to learn how and why to use this API.
    Some of this text also shows up in Visual Studio Intellisense.
    When the PR is complete, the content within the 'Conceptual Pages' section of the review spec will be incorporated into the public documentation at
    http://docs.microsoft.com (DMC).

    For example, much of the examples and descriptions in the `RadialGradientBrush` API spec
    (https://github.com/microsoft/microsoft-ui-xaml-specs/blob/master/active/RadialGradientBrush/RadialGradientBrush.md)
    were carried over to the public API page on DMC
    (https://docs.microsoft.com/windows/winui/api/microsoft.ui.xaml.media.radialgradientbrush?view=winui-2.5)

    Once the API is on DMC, that becomes the official copy, and this spec becomes an archive.
    For example if the description is updated, that only needs to happen on DMC and needn't
    be duplicated here.

    Examples:
    * New set of classes and APIs (Custom Downloads):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md
    * New member on an existing class (BackgroundColor):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/BackgroundColor.md

    Style guide:
    * Use second person; speak to the developer who will be learning/using this API.
    (For example "you use this to..." rather than "the developer uses this to...")
    * Use hard returns to keep the page width within ~100 columns.
    (Otherwise it's more difficult to leave comments in a GitHub PR.)
    * Talk about an API's behavior, not its implementation.
    (Speak to the developer using this API, not to the team implementing it.)
    * A picture is worth a thousand words.
    * An example is worth a million words.
    * Keep examples realistic but simple; don't add unrelated complications.
    (An example that passes a stream needn't show the process of launching the File-Open dialog.)
    * Use GitHub flavored Markdown: https://guides.github.com/features/mastering-markdown/

-->

Title
===

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
