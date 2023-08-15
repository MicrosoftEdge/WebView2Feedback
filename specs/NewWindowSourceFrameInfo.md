Source Frame Info for New Window Requested
===

# Background
Currently there is no way to determine the source frame of a new window request. This information
can be useful when deciding how to open the content. For example, you may want to open requests
that originate in a 3rd party frame in the default browser instead of in a new WebView. The
WebView2 team is extending `NewWindowRequestedEventArgs` with a `SourceFrameInfo` property to make this easier. Here we described the updated API.

# Examples
## SourceFrameInfo on NewWindowRequestedEventArgs
```c#
webView.CoreWebView2.NewWindowRequested += delegate (
    object webView, CoreWebView2NewWindowRequestedEventArgs args)
{
    // The host can decide how to open based on source frame info,
    // such as URI. For example, if the source is a 3rd party frame, open using
    // the default browser.
    if (IsThirdPartySource(args.SourceFrameInfo.Source))
    {
        ProcessStartInfo startInfo = new ProcessStartInfo
        {
            FileName = args.SourceFrameInfo.Source,
            // Open the URI in the default browser.
            UseShellExecute = true
        };
        Process.Start(startInfo);
        args.Handled = true;
    }
};
```
```cpp
// Register a handler for the NewWindowRequested event.
// This handler will defer the event and check the source frame info to determine
// how to open the request. Depending on the source frame URI, it will provide
// a new app window or open using the default browser.
CHECK_FAILURE(m_webView->add_NewWindowRequested(
    Callback<ICoreWebView2NewWindowRequestedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args)
        {
            bool useDefaultBrowser = true;

            Microsoft::WRL::ComPtr<ICoreWebView2NewWindowRequestedEventArgs3> args3;
            if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args3)))) {
                Microsoft::WRL::ComPtr<ICoreWebView2FrameInfo> frame_info;
                if (SUCCEEDED(args3->get_SourceFrameInfo(&frame_info))
                    && frame_info)
                {

                    CHECK_FAILURE(frame_info->get_Source(&source));
                    useDefaultBrowser = IsThirdPartySource(source.get());
                }
            }
            if (useDefaultBrowser)
            {
                // Open the URI in the default browser.
                ShellExecute(
                    nullptr, L"open", source.get(), nullptr, nullptr, SW_SHOWNORMAL);
                CHECK_FAILURE(args->put_Handled(TRUE));
            }
            else
            {
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));
                AppWindow* newAppWindow = new AppWindow(
                    m_creationModeId, GetWebViewOption(), L"none", m_userDataFolder, false,
                    nullptr, true, windowRect, !!shouldHaveToolbar);
                            newAppWindow->m_isPopupWindow = true;
                newAppWindow->m_onWebViewFirstInitialized =
                    [args, deferral, newAppWindow]()
                {
                    CHECK_FAILURE(args->put_NewWindow(newAppWindow->m_webView.get()));
                    CHECK_FAILURE(args->put_Handled(TRUE));
                    CHECK_FAILURE(deferral->Complete());
                };
            }
            return S_OK;
        })
        .Get(),
    nullptr));
```

# API Details

```
/// This is a continuation of the `ICoreWebView2NewWindowRequestedEventArgs` interface.
[uuid(92f08d94-70bd-4d2b-8332-18bd7d3b2b7c), object, pointer_default(unique)]
interface ICoreWebView2NewWindowRequestedEventArgs3 :
    ICoreWebView2NewWindowRequestedEventArgs2 {
  /// The frame info associated with the frame where the new window request
  /// originated. See `ICoreWebView2FrameInfo` for details on frame
  /// properties, such as `Name` and `Source`.
  [propget] HRESULT SourceFrameInfo([out, retval] ICoreWebView2FrameInfo** frameInfo);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2NewWindowRequestedEventArgs
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NewWindowRequestedEventArgs3")]
        {
            // The frame info associated with the frame where the new window request
            // originated. See `CoreWebView2FrameInfo` for details on frame
            // properties, such as `Name` and `Source`.
            CoreWebView2FrameInfo SourceFrameInfo { get; };
        }
    }
}
```
