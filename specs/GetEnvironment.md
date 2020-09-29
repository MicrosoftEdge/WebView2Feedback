# Background
When the WebView2 team was making design changes to the [WebResourceRequested API](https://github.com/MicrosoftEdge/WebView2Feedback/wiki/WebResourceRequested-API-Review-Spec) for .NET, we realized it was not intutive to create the WebView2 Environment. Thus it was not straightforward to use the CreateWebResourceResponse off the WebView2 Environment.
WebView2 team plans to introduce an easier way to get the Environment variable and CreateWebResourceResponse.

# Description
One can get WebView2 Environment from `Environment`. 


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
                        wil::com_ptr<ICoreWebView2Staging> m_webViewstaging =
                            m_webView.try_query<ICoreWebView2Staging>();
                        wil::com_ptr<ICoreWebView2Environment> environment;
                        CHECK_FAILURE(m_webViewstaging->get_Environment(&environment));
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
        CoreWebView2Environment environment = webView2Control.CoreWebView2.Environment;
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

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2 : IUnknown {
    [propget] HRESULT Environment([out, retval] ICoreWebView2Environment** environment);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2
    {
        public CoreWebView2Environment Environment { get; };
    }
}
```
