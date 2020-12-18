  The purpose of this spec is to describe the WebView2 Custom Download API - comprised of a DownloadStarted Handler and associated args.

# Background
<!-- TEMPLATE
    Use this section to provide background context for the new API(s)
    in this spec. 

    This section and the appendix are the only sections that likely
    do not get copied into any official documentation, they're just an aid
    to reading this spec. 
    
    If you're modifying an existing API, included a link here to the
    existing page(s) or spec documentation.

    For example, this section is a place to explain why you're adding this
    API rather than modifying an existing API.

    For example, this is a place to provide a brief explanation of some dependent
    area, just explanation enough to understand this new API, rather than telling
    the reader "go read 100 pages of background information posted at ...". 
-->
There have been multiple requests by WebView Developers to be able to customize/control the download experience within WebView2.  

Some of the requests we've heard, and want to solve with this API are:
- Developers want to be able to disable a download for the entire environment. 
- Developers want to be able to disable downloads based on a per-case basis. (Content Type, User).  
- Developers want to have access to downloaded file’s metadata, and be able to prevent downloads based on this information. 
   Ex. Dev wants to block downloads above 1GB. 
- Developers want to modify the download path. 
- Developer don’t want to see edge download UI if download is cancelled. 

In this document we describe the updated API. We'd appreciate your feedback.

# Description

Our proposed solution is to give developers an API to control the download experience.
We will do this by exposing a downloadStarting event, as well as a DownloadStartingEventHandler.

The downloadStarting event will fire when a download has begun. 
The host can then choose to cancel a download, change the save path, and hide the default download UI. 
If the event is not handled, downloads will complete normally with the default UI shown.

//Viktoria to verify and add info.


# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.

    The general format is:

    ## FirstFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    ## SecondFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    As an example of this section, see the Examples section for the PasswordBox
    control (https://docs.microsoft.com/windows/uwp/design/controls-and-patterns/password-box#examples). 
-->

ScenarioCustomDownloadExperience::ScenarioCustomDownloadExperience(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [DownloadStarting]
    // Register a handler for the `DownloadStarting` event.
    // This example hides the default downloads UI and shows a dialog box instead.
    // The dialog box displays the default save path and allows the user to specify a different path.
    // Selecting `OK` will save the download to the chosen path.
    // Selecting `CANCEL` will cancel the download.
    m_webViewStaging = m_webView.query<ICoreWebView2Staging2>();
    m_demoUri = L"https://demo.smartscreen.msft.net/";
     CHECK_FAILURE(m_webViewStaging->add_DownloadStarting(
         Callback<ICoreWebView2StagingDownloadStartingEventHandler>(
             [this](ICoreWebView2Staging2* sender, ICoreWebView2StagingDownloadStartingEventArgs* args)
                 -> HRESULT {

                   // Hide the default downloads UI.
                   CHECK_FAILURE(args->put_HideUI(TRUE));

                   UINT64 totalBytes = 0;
                   CHECK_FAILURE(args->get_TotalBytes(&totalBytes));

                   wil::unique_cotaskmem_string url;
                   CHECK_FAILURE(args->get_Url(&url));

                   wil::unique_cotaskmem_string mimeType;
                   CHECK_FAILURE(args->get_MimeType(&mimeType));

                   wil::unique_cotaskmem_string contentDisposition;
                   CHECK_FAILURE(args->get_ContentDisposition(&contentDisposition));

                   wil::unique_cotaskmem_string savePath;
                   CHECK_FAILURE(args->get_SavePath(&savePath));

                  std::wstring prompt =
                    std::wstring(L"Enter save path or select `OK` to use default path. ") +
                    L"Select `Cancel` to cancel the download.";

                  // Display the url, mime type, and total bytes of the download.
                  std::wstring description = std::wstring(L"Url: ") + url.get() + L"\r\n" +
                    L"Mime type: " + mimeType.get() + L"\r\n" +
                    L"Total bytes: " + std::to_wstring(totalBytes) + L"\r\n";

                   TextInputDialog dialog(
                       m_appWindow->GetMainWindow(), L"Download Starting", prompt.c_str(),
                       description.c_str(), savePath.get());
                   if (dialog.confirmed)
                   {
                       // If user selects `OK`, the download will complete normally.
                       // Save path will be updated if a new one was provided.
                       CHECK_FAILURE(args->put_SavePath(dialog.input.c_str()));
                   }
                   else if (dialog.canceled) {
                       // If user selects `Cancel`, the download will be cancelled.
                       CHECK_FAILURE(args->put_Cancel(TRUE));
                   }
                 return S_OK;
             })
             .Get(),
         &m_DownloadStartingToken));
    //! [DownloadStarting]

        // Turn off this scenario if we navigate away from the demo page.
     CHECK_FAILURE(m_webView->add_ContentLoading(
         Callback<ICoreWebView2ContentLoadingEventHandler>(
             [this](
                 ICoreWebView2* sender, ICoreWebView2ContentLoadingEventArgs* args) -> HRESULT {
                 wil::unique_cotaskmem_string uri;
                 sender->get_Source(&uri);
                 if (uri.get() != m_demoUri)
                 {
                     m_appWindow->DeleteComponent(this);
                 }
                 return S_OK;
             })
             .Get(),
         &m_contentLoadingToken));

    CHECK_FAILURE(m_appWindow->GetWebView()->Navigate(m_demoUri.c_str()));
}

# Remarks
<!-- TEMPLATE
    Explanation and guidance that doesn't fit into the Examples section.

    APIs should only throw exceptions in exceptional conditions; basically,
    only when there's a bug in the caller, such as argument exception.  But if for some
    reason it's necessary for a caller to catch an exception from an API, call that
    out with an explanation either here or in the Examples
-->


# API Notes
<!-- TEMPLATE
    Option 1: Give a one or two line description of each API (type and member),
        or at least the ones that aren't obvious from their name. These
        descriptions are what show up in IntelliSense. For properties, specify
        the default value of the property if it isn't the type's default (for
        example an int-typed property that doesn't default to zero.) 
        
    Option 2: Put these descriptions in the below API Details section,
        with a "///" comment above the member or type. 
-->


# API Details
<!-- TEMPLATE
    The exact API, in IDL format for our COM API and
    in MIDL3 format (https://docs.microsoft.com/en-us/uwp/midl-3/)
    when possible, or in C# if starting with an API sketch for our .NET and WinRT API.

    Include every new or modified type but use // ... to remove any methods,
    properties, or events that are unchanged.

    (GitHub's markdown syntax formatter does not (yet) know about MIDL3, so
    use ```c# instead even when writing MIDL3.)

    Example:
    
    ```
    /// Event args for the NewWindowRequested event. The event is fired when content
    /// inside webview requested to open a new window (through window.open() and so on.)
    [uuid(34acb11c-fc37-4418-9132-f9c21d1eafb9), object, pointer_default(unique)]
    interface ICoreWebView2NewWindowRequestedEventArgs : IUnknown
    {
        // ...

        /// Window features specified by the window.open call.
        /// These features can be considered for positioning and sizing of
        /// new webview windows.
        [propget] HRESULT WindowFeatures([out, retval] ICoreWebView2WindowFeatures** windowFeatures);
    }
    ```

    ```c# (but really MIDL3)
    public class CoreWebView2NewWindowRequestedEventArgs
    {
        // ...

	       public CoreWebView2WindowFeatures WindowFeatures { get; }
    }
    ```
-->


# Appendix
<!-- TEMPLATE
    Anything else that you want to write down for posterity, but
    that isn't necessary to understand the purpose and usage of the API.
    For example, implementation details or links to other resources.
-->
