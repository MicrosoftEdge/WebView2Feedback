# Background
The WebView2 team has been asked for an API to get the response for a web
resource as it was received and to provide request headers not available when
`WebResourceRequested` event is raised (such as HTTP Authentication headers).
The `WebResourceResponseReceived` event provides such response representation
and exposes the request as committed.

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
to view the actual request and response for a web resource. Modifications to
these objects are set but have no effect on WebView processing them.

When the event is raised, the WebView will pass a
`WebResourceResponseReceivedEventArgs`, which lets the app view the request and
response. The additional `PopulateResponseContent` API is exposed from the event
arguments so the app can get the response's body (if it has one). If the app
tries to get the response content before the first call to
`PopulateResponseContent` completes, the stream object returned will be null.

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
            wil::com_ptr<ICoreWebView2WebResourceResponse> webResourceResponse;
            CHECK_FAILURE(args->get_Response(&webResourceResponse));
            
            // Get body content for the response. Redirect responses will
            // return an error HRESULT as their body (if any) is ignored.
            HRESULT populateCallResult = args->PopulateResponseContent(
                Callback<
                    ICoreWebView2WebResourceResponseReceivedEventArgsPopulateResponseContentCompletedHandler>(
                    [this, webResourceRequest, webResourceResponse](HRESULT result) {
                        // The response might not have a body.
                        bool populatedBody = SUCCEEDED(result);
                        
                        std::wstring message =
                            L"{ \"kind\": \"event\", \"name\": "
                            L"\"WebResourceResponseReceived\", \"args\": {"
                            L"\"request\": " +
                            RequestToJsonString(webResourceRequest.get()) +
                            L", "
                            L"\"response\": " +
                            ResponseToJsonString(webResourceResponse.get()) + L"}";

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

// Note: modifications made to request and response are set but have no effect on WebView processing the objects.
private async void WebView_WebResourceResponseReceived(CoreWebView2 sender, CoreWebView2WebResourceResponseReceivedEventArgs e)
{
    // Actual headers sent with request
    foreach (var current in e.Request.Headers)
        Console.WriteLine(current);

    // Headers in response received
    foreach (var current in e.Response.Headers)
        Console.WriteLine(current);

    // Status code from response received
    int status = e.Response.StatusCode;
    if (status == 200)
    {
        // Handle
        Console.WriteLine("Request succeeded!");

        // Get response body
        try
        {
            await e.PopulateResponseContentAsync();
            DoSomethingWithResponseBody(e.Response.Content);
        }
        catch (COMException ex)
        {
            // A COMException will be thrown if the request has no body.
        }
    }
}
```


# Remarks
Calling `PopulateResponseContent` will fail/throw a COMException if the response
has no body. Note the body for redirect responses is ignored.


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details
## COM
```cpp
library WebView2
{
    interface ICoreWebView2 : IUnknown
    {
        // ...

        /// Add an event handler for the WebResourceResponseReceived event.
        /// WebResourceResponseReceived event is raised after the WebView has received
        /// and processed the response for a WebResource request. The event args
        /// include the WebResourceRequest as committed and the WebResourceResponse
        /// received, not including the Content, but including any additional headers
        /// added by the network stack that were not be included as part of the
        /// associated WebResourceRequested event, such as Authentication headers.
        HRESULT add_WebResourceResponseReceived(
            [in] ICoreWebView2WebResourceResponseReceivedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);
        /// Removes the WebResourceResponseReceived event handler previously added
        /// with add_WebResourceResponseReceived
        HRESULT remove_WebResourceResponseReceived(
            [in] EventRegistrationToken token);
    }

    /// Raised when a response for a request is received for a Web resource in the webview.
    /// Host can use this event to view the actual request and response for a Web resource.
    /// This includes any request or response modifications made by the network stack (such as
    /// the adding of Authorization headers) after the WebResourceRequested event for
    /// the associated request has been raised. Modifications made to the request or
    /// response objects are set but have no effect on WebView processing them.
    interface ICoreWebView2WebResourceResponseReceivedEventHandler : IUnknown
    {
        /// Called to provide the implementer with the event args for the
        /// corresponding event.
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2WebResourceResponseReceivedEventArgs* args);
    }

    /// Completion handler for PopulateResponseContent async method. It's invoked
    /// when the Content stream of the Response of a WebResourceResponseReceieved
    /// event is available.
    interface ICoreWebView2WebResourceResponseReceivedEventArgsPopulateResponseContentCompletedHandler : IUnknown
    {
        /// Called to provide the implementer with the completion status
        /// of the corresponding asynchronous method call.
        HRESULT Invoke([in] HRESULT errorCode);
    }

    /// Event args for the WebResourceResponseReceived event. Will contain the
    /// request as it was sent and the response as it was received.
    /// Note: To get the response content stream, first call PopulateResponseContent
    /// and wait for the async call to complete, otherwise the content stream object
    /// returned will be null.
    interface ICoreWebView2WebResourceResponseReceivedEventArgs : IUnknown
    {
        /// Web resource request object. Any modifications to this object will be ignored.
        [propget] HRESULT Request([out, retval] ICoreWebView2WebResourceRequest** request);
        /// Web resource response object. Any modifications to this object
        /// will be ignored.
        [propget] HRESULT Response([out, retval] ICoreWebView2WebResourceResponse** response);

        /// Async method to ensure that the Content property of the response contains the actual response body content.
        /// If this method is being called again before a first call has completed, all handlers are invoked at the same time.
        /// If this method is being called after a first call has completed, the handler is invoked immediately.
        HRESULT PopulateResponseContent(ICoreWebView2WebResourceResponseReceivedEventArgsPopulateResponseContentCompletedHandler* handler);
    }
}
```

## WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2
    {
        // ...

        /// WebResourceResponseReceived event is raised after the WebView has received and processed the response for a WebResource request.
        /// The event args include the WebResourceRequest as committed and the WebResourceResponse received,
        /// including any additional headers added by the network stack that were not be included as part of
        /// the associated WebResourceRequested event, such as Authentication headers.
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2WebResourceResponseReceivedEventArgs> WebResourceResponseReceived;
    }

    /// Event args for the WebResourceResponseReceived event.
    /// Note: To get the response content stream, first call PopulateResponseContentAsync and
    /// wait for the call to complete, otherwise the content stream object returned will be null.
    runtimeclass CoreWebView2WebResourceResponseReceivedEventArgs
    {
        /// Web resource request object.
        /// Any modifications to this object will be ignored.
        CoreWebView2WebResourceRequest Request { get; };
        /// Web resource response object.
        /// Any modifications to this object will be ignored.
        CoreWebView2WebResourceResponse Response { get; };

        /// Async method to ensure that the Content property of the response contains the actual response body content.
        /// If this method is being called again before a first call has completed, it will complete at the same time all prior calls do.
        /// If this method is being called after a first call has completed, it will return immediately (asynchronously).
        Windows.Foundation.IAsyncAction PopulateResponseContentAsync();
    }
}
```
