Extended DownloadStartingEventArgs: DidPromptUser
===

# Background
When handling the `DownloadStarting` event, you may want to implement different
behavior depending on whether the user interacted wih the Save As dialog prior to
the event.

The Save As dialog is shown when the user selects to save from the
context menu, or clicks the Save icon in the PDF viewer. In these cases, the
`ResultFilePath` on the [`DownloadStartingEventArgs`](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2downloadstartingeventargs?view=webview2-1.0.1020.30) reflects the
user's decision: either the user accepted the system default download path, or
the user chose a new path.

To support this scenario, we are extending the `DownloadStartingEventArgs` to
include a `DidPromptUser` property that is `TRUE` if the user was shown the Save
As dialog. In this document we describe the updated API. We'd appreciate your feedback.

# Examples
```cpp
// In this example we change a download's `ResultFilePath` to a custom default path
// only if the user did not already choose a path through the Save As dialog.
CHECK_FAILURE(m_webView2_4->add_DownloadStarting(
    Callback<ICoreWebView2DownloadStartingEventHandler>(
        [this](
            ICoreWebView2* sender,
            ICoreWebView2DownloadStartingEventArgs* args) -> HRESULT
            {
                BOOL didPromptUser = FALSE;
                wil::com_ptr<ICoreWebView2DownloadStartingEventArgs2> args2;
                if(SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args2))))
                {
                    CHECK_FAILURE(args2->get_DidPromptUser(&didPromptUser));
                }
                if (!didPromptUser)
                {
                    wil::unique_cotaskmem_string resultFilePath;
                    CHECK_FAILURE(args->get_ResultFilePath(&resultFilePath));
                    CHECK_FAILURE(args->put_ResultFilePath(
                        GetCustomPath(resultFilePath.get()));
                }
            }
            return S_OK;
        })
    .Get(),
&m_downloadStartingToken));
```
```c#
// In this example we change a download's `ResultFilePath` to a custom default path
// only if the user did not already choose a path through the Save As dialog.
webView.CoreWebView2.DownloadStarting += delegate (object sender,
    CoreWebView2DownloadStartingEventArgs args)
{
    if (!args.DidPromptUser)
    {
        args.ResultFilePath = GetCustomPath(args.ResultFilePath);
    }
};
```
# API Details
```c#
/// This is a continuation of the `ICoreWebView2DownloadStartingEventArgs`
/// interface.
[uuid(04c31392-ebf7-4210-ba25-a4f856359b3b), object, pointer_default(unique)]
interface ICoreWebView2StagingDownloadStartingEventArgs2 :
    ICoreWebView2DownloadStartingEventArgs {
  /// `TRUE` if the user was shown the Save As dialog prior to the
  /// `DownloadStarting` event. From the Save As dialog, the user either
  /// changed the `ResultFilePath` or accepted the system default path for
  /// downloads.
  [propget] HRESULT DidPromptUser([out, retval] BOOL* value);
}
```
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2DownloadStartingEventArgs
    {
        // The following properties already exist.
        // CoreWebView2DownloadOperation DownloadOperation { get; };
        // Boolean Cancel { get; set; };
        // String ResultFilePath { get; set; };
        // Boolean Handled { get; set; };

        Boolean DidPromptUser { get; };

        // The following method already exists.
        // Windows.Foundation.Deferral GetDeferral();
    }
}
```
