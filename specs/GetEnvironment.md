# Background
When the WebView2 team was making design changes to the [WebResourceRequested API](https://github.com/MicrosoftEdge/WebView2Feedback/wiki/WebResourceRequested-API-Review-Spec) for .NET, we realized several caveats. It was not ideal to force all end developers to keep references back to the CoreWebView2Environment from their CoreWebView2 event handlers, and also in the case of WPF, WinForms and WinUI3.0 the UI framework can create the CoreWebView2Environment internally with no easy way for the end developers to obtain a reference to it. Thus providing a reference to the CoreWebView2Environment off of the CoreWebView2 solves both of those problems.

# Description
Get the `CoreWebView2Environment` used to create the `CoreWebView2` from that `CoreWebView2`'s `Environment` property


# Examples

The following code snippet demonstrates how the environment APIs can be use:

## Win32 C++

```cpp
// Turn on or off image blocking by adding or removing a WebResourceRequested handler
// which selectively intercepts requests for images.
void SettingsComponent::SetBlockImages(bool blockImages)
{
    if (blockImages != m_blockImages)
    {
        m_blockImages = blockImages;
        if (m_blockImages)
        {
            m_webView->AddWebResourceRequestedFilter(L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE);
            CHECK_FAILURE(m_webView->add_WebResourceRequested(
                Callback<ICoreWebView2WebResourceRequestedEventHandler>(
                    [this](
                        ICoreWebView2* sender,
                        ICoreWebView2WebResourceRequestedEventArgs* args) {
                        COREWEBVIEW2_WEB_RESOURCE_CONTEXT resourceContext;
                        CHECK_FAILURE(
                            args->get_ResourceContext(&resourceContext));
                        // Ensure that the type is image
                        if (resourceContext != COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE)
                        {
                            return E_INVALIDARG;
                        }
                        // Override the response with an empty one to block the image.
                        // If put_Response is not called, the request will continue as normal.
                        wil::com_ptr<ICoreWebView2WebResourceResponse> response;
                        // Environment Usage
                        wil::com_ptr<ICoreWebView2Environment> environment;
                        CHECK_FAILURE(m_webView->get_Environment(&environment));
                        CHECK_FAILURE(environment->CreateWebResourceResponse(
                            nullptr, 403 /*NoContent*/, L"Blocked", L"", &response));
                        CHECK_FAILURE(args->put_Response(response.get()));
                        return S_OK;
                    })
                    .Get(),
                &m_webResourceRequestedTokenForImageBlocking));
        }
        else
        {
            CHECK_FAILURE(m_webView->remove_WebResourceRequested(
                m_webResourceRequestedTokenForImageBlocking));
        }
    }
}
```

## .NET and WinRT

```c#
    private void CoreWebView2_WebResourceRequested(object sender, CoreWebView2WebResourceRequestedEventArgs e)
    {
        // Create response object for custom response and set it
        var environment = webView2Control.CoreWebView2.Environment;
        CoreWebView2WebResourceResponse response = environment.CreateWebResourceResponse(null, 403, "Blocked", "");
        e.Response = response;

        // statusCode will now be accessible and equal to 403
        var code = e.Response.StatusCode;
    }
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2;
interface ICoreWebView2_2;

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
    /// Exposes the CoreWebView2Environment used to create this CoreWebView2.
    [propget] HRESULT Environment([out, retval] ICoreWebView2Environment** environment);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public CoreWebView2Environment Environment { get; };
    }
}
```
