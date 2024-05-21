Critical Update Available
===

# Background
WebView2 developers often have to author ECS configurations to toggle feature flags. However, once these payloads are received, there is no way to restart the WebView2 and apply the payload. The purpose of this API is to detect such critical payloads and inform the developer so they may restart their app or their WebView2 or other appropriate action.

# Examples
## WinRT and .NET   
```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.Environment.CriticalUpdateAvaliable += WebView_CriticalUpdateAvaliable;
    }
}

void WebView_CriticalUpdateAvaliable(object sender, object e)
{
    System.Threading.SynchronizationContext.Current.Post((_) =>
    {
        UpdateIfSelectedByUser();
    }, null);
}
```

## Win32 C++
```cpp
    wil::com_ptr<ICoreWebView2Environment> m_webViewEnvironment;
    auto env10 = m_webViewEnvironment.try_query<ICoreWebView2Environment10>();
    CHECK_FAILURE(env10->add_CriticalUpdateAvaliable(
        Callback<ICoreWebView2CriticalUpdateAvaliableEventHandler>(
            [this](ICoreWebView2Environment* sender, IUnknown* args) -> HRESULT
            {
                // Don't block the event handler with a message box
                RunAsync(
                    [this]
                    {
                        std::wstring message =
                            L"We detected there is a critical update for WebView2 runtime.";
                        if (m_webView)
                        {
                            message += L"Do you want to restart the app? \n\n";
                            message +=
                                L"Click No if you only want to re-create the webviews. \n";
                            message += L"Click Cancel for no action. \n";
                        }
                        int response = MessageBox(
                            m_mainWindow, message.c_str(), L"Critical Update Avaliable",
                            m_webView ? MB_YESNOCANCEL : MB_OK);

                        if (response == IDYES)
                        {
                            RestartApp();
                        }
                        else if (response == IDNO)
                        {
                            ReinitializeWebViewWithNewBrowser();
                        }
                        else
                        {
                            // do nothing
                        }
                    });

                return S_OK;
            })
            .Get(),
        nullptr));
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++

```IDL
interface ICoreWebView2Environment10;
interface ICoreWebView2CriticalUpdateAvaliableEventHandler;

[uuid(62cb67c6-b6a9-4209-8a12-72ca093b9547), object, pointer_default(unique)]
interface ICoreWebView2CriticalUpdateAvaliableEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Environment* sender, [in] IUnknown* args);
}

[uuid(ef7632ec-d86e-46dd-9d59-e6ffb5c87878), object, pointer_default(unique)]
interface ICoreWebView2Environment10 : IUnknown {
  HRESULT add_CriticalUpdateAvaliable(
      [in] ICoreWebView2CriticalUpdateAvaliableEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  HRESULT remove_CriticalUpdateAvaliable(
      [in] EventRegistrationToken token);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        // ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, Object> CriticalUpdateAvaliable;
    }
}
```