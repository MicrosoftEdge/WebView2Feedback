# Background
The WebView2 team has been asked for an API to get the response for a web
resource as it was received and to provide request headers not available when
`WebResourceRequested` event is raised (such as HTTP Authentication headers).
The `WebResourceResponseReceived` event provides such response representation
and exposes the request as committed. A web request is any URI resolution the
WebView performs. This includes declarative `<img src="...">` from HTML,
implicit `favicon.ico` lookups, and JavaScript in the document calling the
`fetch(...)` API.

In this document we describe the new API. We'd appreciate your feedback.

# Description
The `WebResourceResponseReceived` event allows developers to inspect the
response object from URL requests (such as HTTP/HTTPS, file and data). A key
scenario is to allow developers to get Auth headers from an HTTP response to
authenticate other tools they're using, since the Auth headers are not exposed
in the `WebResourceRequested` event.

This event is raised when the WebView receives the response for a request for a
web resource. It provides access to both the response as it was received and the
request as it was committed, including modifications made by the network stack
(such as the adding of HTTP Authorization headers). The app can use this event
to view the actual request and response for a web resource. Modifications to the
request object are set but have no effect on WebView processing it. There is no
ordering guarantee between WebView processing the response and the host app's
event handler running.

When the event is raised, the WebView will pass a
`WebResourceResponseReceivedEventArgs`, which lets the app view the request and
response. To get the response content, call `GetContent`/`GetContentAsync` on
the `CoreWebView2WebResourceResponseView` object from the event args.

# Examples
The following code snippets demonstrate how the `WebResourceResponseReceived`
event can be used:

## COM
```cpp
EventRegistrationToken m_webResourceResponseReceivedToken = {};

m_webview->add_WebResourceResponseReceived(
    Callback<ICoreWebView2WebResourceResponseReceivedEventHandler>(
        [this](ICoreWebView2* webview, ICoreWebView2WebResourceResponseReceivedEventArgs* args)
            -> HRESULT {
            // The request object as committed
            wil::com_ptr<ICoreWebView2WebResourceRequest> webResourceRequest;
            CHECK_FAILURE(args->get_Request(&webResourceRequest));
            // The response object as received
            wil::com_ptr<ICoreWebView2WebResourceResponseView> webResourceResponse;
            CHECK_FAILURE(args->get_Response(&webResourceResponse));
            
            // Get body content for the response
            webResourceResponse->GetContent(
                Callback<
                    ICoreWebView2WebResourceResponseViewGetContentCompletedHandler>(
                    [this, webResourceRequest, webResourceResponse](HRESULT result, IStream* content) {
                        // The response content might have failed to load.
                        bool getContentSucceeded = SUCCEEDED(result);

                        // The stream will be null if no content was found for the response.
                        if (content) {
                            DoSomethingWithContent(content);
                        }
                        
                        std::wstring message =
                            L"{ \"kind\": \"event\", \"name\": "
                            L"\"WebResourceResponseReceived\", \"args\": {"
                            L"\"request\": " +
                            RequestToJsonString(webResourceRequest.get()) +
                            L", "
                            L"\"response\": " +
                            ResponseToJsonString(webResourceResponse.get(), content) + L"}";

                        message +=
                            WebViewPropertiesToJsonString(m_webview.get());
                        message += L"}";
                        PostEventMessage(message);
                        return S_OK;
                    })
                    .Get());

            return S_OK;
        })
        .Get(),
    &m_webResourceResponseReceivedToken);
```

## C#
```c#
WebView.WebResourceResponseReceived += WebView_WebResourceResponseReceived;

// Note: modifications made to request are set but have no effect on WebView processing it.
private async void WebView_WebResourceResponseReceived(CoreWebView2 sender, CoreWebView2WebResourceResponseReceivedEventArgs e)
{
    // Actual headers sent with request
    foreach (var current in e.Request.Headers)
    {
        Console.WriteLine(current);
    }

    // Headers in response received
    foreach (var current in e.Response.Headers)
    {
        Console.WriteLine(current);
    }

    // Status code from response received
    int status = e.Response.StatusCode;
    if (status == 200)
    {
        // Handle
        Console.WriteLine("Request succeeded!");

        // Get response body
        try
        {
            System.IO.Stream content = await e.Response.GetContentAsync();
            // Null will be returned if no content was found for the response.
            if (content)
            {
                DoSomethingWithResponseContent(content);
            }
        }
        catch (COMException ex)
        {
            // A COMException will be thrown if the content failed to load.
        }
    }
}
```


# Remarks
`ICoreWebView2WebResourceResponseViewGetContentCompletedHandler` will be
invoked with a failure errorCode if the content failed to load.
Calling `CoreWebView2WebResourceResponseView.GetContentAsync` will throw a
`COMException` if the content failed to load.


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details
## COM
```cpp
library WebView2
{
// ...

interface ICoreWebView2 : IUnknown
{
  // ...

  /// Add an event handler for the WebResourceResponseReceived event.
  /// WebResourceResponseReceived is raised when the WebView receives the
  /// response for a request for a web resource (any URI resolution performed by
  /// the WebView; such as HTTP/HTTPS, file and data requests from redirects,
  /// navigations, declarations in HTML, implicit favicon lookups, and fetch API
  /// usage in the document). The host app can use this event to view the actual
  /// request and response for a web resource. There is no guarantee about the
  /// order in which the WebView processes the response and the host app's
  /// handler runs. The app's handler will not block the WebView from processing
  /// the response.
  HRESULT add_WebResourceResponseReceived(
      [in] ICoreWebView2WebResourceResponseReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with
  /// add_WebResourceResponseReceived.
  HRESULT remove_WebResourceResponseReceived(
      [in] EventRegistrationToken token);
}

/// The caller implements this interface to receive WebResourceResponseReceived
/// events.
interface ICoreWebView2WebResourceResponseReceivedEventHandler : IUnknown
{
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2* sender,
      [in] ICoreWebView2WebResourceResponseReceivedEventArgs* args);
}

/// Event args for the WebResourceResponseReceived event.
interface ICoreWebView2WebResourceResponseReceivedEventArgs : IUnknown
{
  /// The request object for the web resource, as committed. This includes
  /// headers added by the network stack that were not be included during the
  /// associated WebResourceRequested event, such as Authentication headers.
  /// Modifications to this object have no effect on how the request is
  /// processed as it has already been sent.
  [propget] HRESULT Request(
      [out, retval] ICoreWebView2WebResourceRequest** request);
  /// View of the response object received for the web resource.
  [propget] HRESULT Response(
      [out, retval] ICoreWebView2WebResourceResponseView** response);
}

/// View of the HTTP representation for a web resource response. The properties
/// of this object are not mutable. This response view is used with the
/// WebResourceResponseReceived event.
interface ICoreWebView2WebResourceResponseView : IUnknown
{
  /// The HTTP response headers as received.
  [propget] HRESULT Headers(
      [out, retval] ICoreWebView2HttpResponseHeaders** headers);
  /// The HTTP response status code.
  [propget] HRESULT StatusCode([out, retval] int* statusCode);
  /// The HTTP response reason phrase.
  [propget] HRESULT ReasonPhrase([out, retval] LPWSTR* reasonPhrase);

  /// Get the response content asynchronously. The handler will receive the
  /// response content stream.
  /// If this method is being called again before a first call has completed,
  /// the handler will be invoked at the same time the handlers from prior calls
  /// are invoked.
  /// If this method is being called after a first call has completed, the
  /// handler will be invoked immediately.
  HRESULT GetContent(
      [in] ICoreWebView2WebResourceResponseViewGetContentCompletedHandler* handler);
}

/// The caller implements this interface to receive the result of the
/// ICoreWebView2WebResourceResponseView::GetContent method.
interface ICoreWebView2WebResourceResponseViewGetContentCompletedHandler : IUnknown
{
  /// Called to provide the implementer with the completion status and result of
  /// the corresponding asynchronous method call. A failure errorCode will be
  /// passed if the content failed to load. Null means no content was found.
  /// Note content (if any) for redirect responses is ignored.
  HRESULT Invoke([in] HRESULT errorCode, [in] IStream* content);
}

}
```

## WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    runtimeclass CoreWebView2
    {
        // ...

        /// WebResourceResponseReceived is raised when the WebView receives the
        /// response for a request for a web resource (any URI resolution performed by
        /// the WebView; such as HTTP/HTTPS, file and data requests from redirects,
        /// navigations, declarations in HTML, implicit favicon lookups, and fetch API
        /// usage in the document). The host app can use this event to view the actual
        /// request and response for a web resource. There is no guarantee about the
        /// order in which the WebView processes the response and the host app's
        /// handler runs. The app's handler will not block the WebView from processing
        /// the response.
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2WebResourceResponseReceivedEventArgs> WebResourceResponseReceived;
    }

    /// Event args for the WebResourceResponseReceived event.
    runtimeclass CoreWebView2WebResourceResponseReceivedEventArgs
    {
        /// The request object for the web resource, as committed. This includes
        /// headers added by the network stack that were not be included during the
        /// associated WebResourceRequested event, such as Authentication headers.
        /// Modifications to this object have no effect on how the request is
        /// processed as it has already been sent.
        CoreWebView2WebResourceRequest Request { get; };
        /// View of the response object received for the web resource.
        CoreWebView2WebResourceResponseView Response { get; };
    }

    /// View of the HTTP representation for a web resource response. The properties
    /// of this object are not mutable. This response view is used with the
    /// WebResourceResponseReceived event.
    runtimeclass CoreWebView2WebResourceResponseView
    {
        /// The HTTP response headers as received.
        CoreWebView2HttpResponseHeaders Headers { get; };
        /// The HTTP response status code.
        Int32 StatusCode { get; };
        /// The HTTP response reason phrase.
        String ReasonPhrase { get; };
        /// Get the response content stream asynchronously.
        /// This method will throw a COM exception if the content failed to load.
        /// A null stream means no content was found. Note content (if any) for
        /// redirect responses is ignored.
        /// If this method is being called again before a first call has completed,
        /// it will complete at the same time all prior calls do.
        /// If this method is being called after a first call has completed, it will
        /// return immediately (asynchronously).
        Windows.Foundation.IAsyncOperation<Windows.Storage.Streams.IRandomAccessStream> GetContentAsync();
    }
}
```
