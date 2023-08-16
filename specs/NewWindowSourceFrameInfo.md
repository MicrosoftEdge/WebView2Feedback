Source Frame Info for New Window Requested
===

# Background
Currently there is no way to determine the source frame of a new window request. This information
can be useful when deciding how to open the content. For example, you may want to open requests
that originate in a 3rd party frame in the default browser instead of in a new WebView. The
WebView2 team is extending `NewWindowRequestedEventArgs` with a `OriginalSourceFrameInfo` property
to make this easier. Here we described the updated API.

# Examples
## OriginalSourceFrameInfo on NewWindowRequestedEventArgs
```c#
// Register a handler for the NewWindowRequested event.
// This handler will check the source frame info to determine how to open the
// request. Depending on the source frame URI, it will provide a new app window
// or open using the default browser.
webView.CoreWebView2.NewWindowRequested += delegate (
    object webView, CoreWebView2NewWindowRequestedEventArgs args)
{
    // The host can decide how to open based on source frame info,
    // such as URI. For example, if the source is a 3rd party frame, open using
    // the default browser.
    bool useDefaultBrowser = IsThirdPartySource(
        args.OriginalSourceFrameInfo.Source);
    if (useDefaultBrowser)
    {
        ProcessStartInfo startInfo = new ProcessStartInfo
        {
            FileName = args.OriginalSourceFrameInfo.Source,
            // Open the URI in the default browser.
            UseShellExecute = true
        };
        Process.Start(startInfo);
        args.Handled = true;
    }
    else
    {
        CoreWebView2Deferral deferral = args.GetDeferral();
        MainWindow main_window = new MainWindow(
            webView.CreationProperties, args.Uri);
        main_window.OnWebViewFirstInitialized = () =>
        {
            using (deferral)
            {
                args.Handled = true;
                args.NewWindow = main_window.webView.CoreWebView2;
            }
        };
        main_window.Show();
    }
};
```
```cpp
// Register a handler for the NewWindowRequested event.
// This handler will check the source frame info to determine how to open the
// request. Depending on the source frame URI, it will provide a new app window
// or open using the default browser.
CHECK_FAILURE(m_webView->add_NewWindowRequested(
    Callback<ICoreWebView2NewWindowRequestedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args)
        {
            bool useDefaultBrowser = false;
            Microsoft::WRL::ComPtr<ICoreWebView2NewWindowRequestedEventArgs3> args3;
            if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args3))))
            {
                Microsoft::WRL::ComPtr<ICoreWebView2FrameInfo> frame_info;
                if (SUCCEEDED(args3->get_OriginalSourceFrameInfo(&frame_info))
                    && frame_info)
                {
                    // The host can decide how to open based on source frame info,
                    // such as URI. For example, if the source is a 3rd party frame,
                    // open using the default browser.
                    wil::unique_cotaskmem_string source;
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
                Microsoft::WRL::ComPtr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));
                AppWindow* newAppWindow = new AppWindow(
                    m_creationModeId, GetWebViewOption(), L"none", m_userDataFolder,
                    false, nullptr, true, windowRect, !!shouldHaveToolbar);
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
  /// The frame info of the frame where the new window request originated. The
  /// `OriginalSourceFrameInfo` is a snapshot of frame information at the time when the
  /// new window was requested. See `ICoreWebView2FrameInfo` for details on frame
  /// properties.
  [propget] HRESULT OriginalSourceFrameInfo([out, retval] ICoreWebView2FrameInfo** frameInfo);
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
            // The frame info of the frame where the new window request originated. The
            // `OriginalSourceFrameInfo` is a snapshot of frame information at the time when the
            // new window was requested. See `CoreWebView2FrameInfo` for details on frame
            // properties.
            CoreWebView2FrameInfo OriginalSourceFrameInfo { get; };
        }
    }
}
```
