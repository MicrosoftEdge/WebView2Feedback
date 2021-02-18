# Background
WebView2 provides applications with the [ProcessFailed](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed) event so they can react accordingly when a process failure occurs. However, this event does not currently provide additional information about the process failure, nor does it cover the cases in which only subframes within the CoreWebView2 are impacted by the failure, or the cases in which a process other than the browser/render process fails.

In this document we describe an extended version of the [PROCESS_FAILED_KIND](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#corewebview2_process_failed_kind) enum, which covers the new scenarios in which the event is raised: frame-only render process failure, and process failures for processes other than the browser/render process. We also include a new version of the [ProcessFailedEventArgs](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.705.50) that enables the host application to collect additional information about the process failure for their logging and telemetry purposes.

The updated API is detailed below. We'd appreciate your feedback.


# Description
We propose to add new cases for which the `ProcessFailed` event is raised:
  1. When a frame-only render process fails. Only subframes within the `CoreWebView2` are impacted in this case (the content is gone and replaced with a "sad face" layer).
  2. When a WebView2 Runtime child process other than the browser process or a render process fails. The app can use these process failures for logging and telemetry purposes.

We also propose extending the `ProcessFailedEventArgs` to provide additional information about the process failure:
  * Reason of the failure.
  * Exit code.
  * Process description.
  * Impacted frames for (1) above.


# Examples
The following code snippets demonstrate how the `ProcessFailedEventArgs2` can be used by the host application:

## Win32 C++
```cpp
// Get a string for the failure kind enum value.
std::wstring ProcessComponent::ProcessFailedKindToString(
    const COREWEBVIEW2_PROCESS_FAILED_KIND kind)
{
    switch (kind)
    {
#define KIND_ENTRY(kindValue)                                                                  \
    case kindValue:                                                                            \
        return L#kindValue;

        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_UTILITY_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_SANDBOX_HELPER_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_GPU_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_PPAPI_PLUGIN_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_PPAPI_BROKER_PROCESS_EXITED);
        KIND_ENTRY(COREWEBVIEW2_PROCESS_FAILED_KIND_UNKNOWN_PROCESS_EXITED);

#undef KIND_ENTRY
    }

    return L"PROCESS_FAILED";
}

// Get a string for the failure reason enum value.
std::wstring ProcessComponent::ProcessFailedReasonToString(
    const COREWEBVIEW2_PROCESS_FAILED_REASON reason)
{
    switch (reason)
    {
#define REASON_ENTRY(reasonValue)                                                              \
    case reasonValue:                                                                          \
        return L#reasonValue;

        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_UNEXPECTED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_UNRESPONSIVE);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_KILLED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_CRASHED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_LAUNCH_FAILED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_OUT_OF_MEMORY);

#undef REASON_ENTRY
    }

    return L"REASON";
}

//! [ProcessFailed]
// Register a handler for the ProcessFailed event.
// This handler checks the failure kind and tries to:
//   * Recreate the webview for browser failure and render unresponsive.
//   * Reload the webview for render failure.
//   * Reload the webview for frame-only render failure impacting app content.
//   * Log information about the failure for other failures.
CHECK_FAILURE(m_webView->add_ProcessFailed(
    Callback<ICoreWebView2ProcessFailedEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2ProcessFailedEventArgs* argsRaw)
            -> HRESULT {
            wil::com_ptr<ICoreWebView2ProcessFailedEventArgs> args = argsRaw;
            COREWEBVIEW2_PROCESS_FAILED_KIND failureKind;
            CHECK_FAILURE(args->get_ProcessFailedKind(&failureKind));
            if (failureKind == COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED)
            {
                int button = MessageBox(
                    m_appWindow->GetMainWindow(),
                    L"Browser process exited unexpectedly.  Recreate webview?",
                    L"Browser process exited", MB_YESNO);
                if (button == IDYES)
                {
                    m_appWindow->ReinitializeWebView();
                }
            }
            else if (failureKind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE)
            {
                int button = MessageBox(
                    m_appWindow->GetMainWindow(),
                    L"Browser render process has stopped responding.  Recreate webview?",
                    L"Web page unresponsive", MB_YESNO);
                if (button == IDYES)
                {
                    m_appWindow->ReinitializeWebView();
                }
            }
            else if (failureKind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED)
            {
                int button = MessageBox(
                    m_appWindow->GetMainWindow(),
                    L"Browser render process exited unexpectedly. Reload page?",
                    L"Web page unresponsive", MB_YESNO);
                if (button == IDYES)
                {
                    CHECK_FAILURE(m_webView->Reload());
                }
            }

            // Check the runtime event args implements the newer interface.
            auto args2 =
                args.try_query<ICoreWebView2ProcessFailedEventArgs2>();
            if (!args2)
            {
                return S_OK;
            }

            if (failureKind ==
                COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED)
            {
                // A frame-only renderer has exited unexpectedly. Check if reload is needed.
                wil::com_ptr<ICoreWebView2FrameInfoCollection> impactedFrames;
                wil::com_ptr<ICoreWebView2FrameInfoCollectionIterator> iterator;
                CHECK_FAILURE(args2->get_ImpactedFramesInfo(&impactedFrames));
                CHECK_FAILURE(impactedFrames->GetIterator(&iterator));

                BOOL hasCurrent = FALSE;
                while (SUCCEEDED(iterator->HasCurrentFrameInfo(&hasCurrent)) && hasCurrent)
                {
                    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo;
                    CHECK_FAILURE(iterator->GetCurrentFrameInfo(&frameInfo));

                    wil::unique_cotaskmem_string nameRaw;
                    wil::unique_cotaskmem_string sourceRaw;
                    CHECK_FAILURE(frameInfo->get_Name(&nameRaw));
                    CHECK_FAILURE(frameInfo->get_Source(&sourceRaw));
                    std::wstring source = sourceRaw.get();

                    // Content from our app uses a mapped host name.
                    const std::wstring mappedAppHostName = L"https://appassets.example/";
                    if (source.compare(0, mappedAppHostName.length(), mappedAppHostName) == 0)
                    {
                        int button = MessageBox(
                            m_appWindow->GetMainWindow(),
                            L"Browser render process for app frame exited unexpectedly. "
                            L"Reload page?",
                            L"App content frame unresponsive", MB_YESNO);
                        if (button == IDYES)
                        {
                            CHECK_FAILURE(m_webView->Reload());
                        }
                        break;
                    }

                    BOOL hasNext = FALSE;
                    CHECK_FAILURE(iterator->MoveNext(&hasNext));
                }
            }
            else
            {
                // Show the process failure details. Apps can collect info for their logging
                // purposes.
                COREWEBVIEW2_PROCESS_FAILED_REASON reason;
                wil::unique_cotaskmem_string processDescription;
                int exitCode;

                CHECK_FAILURE(args2->get_Reason(&reason));
                CHECK_FAILURE(args2->get_ProcessDescription(&processDescription));
                CHECK_FAILURE(args2->get_ExitCode(&exitCode));

                std::wstringstream message;
                message << L"Process kind:\t"        << ProcessFailedKindToString(failureKind) << L"\n"
                        << L"Reason:\t"              << ProcessFailedReasonToString(reason)    << L"\n"
                        << L"Exit code:\t"           << std::to_wstring(exitCode)              << L"\n"
                        << L"Process description:\t" << processDescription.get()               << std::endl;
                MessageBox(
                    m_appWindow->GetMainWindow(), message.str().c_str(),
                    L"Child process failed", MB_OK);
            }
            return S_OK;
        })
        .Get(),
    &m_processFailedToken));
//! [ProcessFailed]

```

## .NET C#
```xml
<Window x:Class="WebView2WpfBrowser.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:wv2="clr-namespace:Microsoft.Web.WebView2.Wpf;assembly=Microsoft.Web.WebView2.Wpf"
        xmlns:local="clr-namespace:WebView2WpfBrowser"
        x:Name="MyWindow"
        Title="MainWindow"
        Height="450"
        Width="800"
>

    <!-- ... -->

    <DockPanel
        x:Name="MyDockPanel"
    >
        <!-- ... -->

        <DockPanel DockPanel.Dock="Top">

            <!-- ... -->

            <TextBox x:Name="url" Text="{Binding ElementName=webView,Path=Source,Mode=OneWay}">
                <TextBox.InputBindings>
                    <KeyBinding Key="Return" Command="NavigationCommands.GoToPage" CommandParameter="{Binding ElementName=url,Path=Text}" />
                </TextBox.InputBindings>
            </TextBox>
        </DockPanel>

        <wv2:WebView2
            x:Name="webView"
            CreationProperties="{StaticResource EvergreenWebView2CreationProperties}"
            Source="https://www.bing.com/"
            NavigationStarting="WebView_NavigationStarting"
            NavigationCompleted="WebView_NavigationCompleted"
        />
    </DockPanel>
</Window>

```

```c#
// This re-instantiates the control and attaches properties as set in the XAML
// element. Replace once the control has reinit/uninitialize logic.
void ReinitializeWebView()
{
    webView = new WebView2();

    // Restore URI and other WebView state/setup.
    webView.CreationProperties = (CoreWebView2CreationProperties)this.FindResource("EvergreenWebView2CreationProperties");
    webView.NavigationStarting += WebView_NavigationStarting;
    webView.NavigationCompleted += WebView_NavigationCompleted;

    Binding urlBinding = new Binding()
    {
        Source = webView,
        Path = new PropertyPath("Source"),
        Mode = BindingMode.OneWay
    };
    url.SetBinding(TextBox.TextProperty, urlBinding);

    MyDockPanel.Children.Add(webView);
    webView.Source = _uriToRestore ?? new Uri("https://www.bing.com");
}

async void WebView_ProcessFailed(CoreWebView2 sender, CoreWebView2ProcessFailedEventArgs e)
{
    void AskForReinit(string message, string caption)
    {
        // Save URI or other state you want to restore when the WebView is recreated.
        _uriToRestore = webView.Source;
        // Work around. An exception will be thrown while trying to redraw the
        // control as its CoreWebView2 is in the closed state.
        webView.Dispose();
        webView = null;
        var selection = MessageBox.Show(message, caption, MessageBoxButton.YesNo);
        if (selection == MessageBoxResult.Yes)
        {
            // Replace once the control has reinit/uninitialize logic.
            ReinitializeWebView();
        }
        else
        {
            _uriToRestore = null;
        }
    }

    void AskForReload(string message, string caption)
    {
        var selection = MessageBox.Show(message, caption, MessageBoxButton.YesNo);
        if (selection == MessageBoxResult.Yes)
        {
            webView.Reload();
        }
    }

    string message;
    string caption;
    Debug.WriteLine(e.ProcessFailedKind);
    switch (e.ProcessFailedKind)
    {
        case CoreWebView2ProcessFailedKind.BrowserProcessExited:
            message = "Browser process exited unexpectedly.  Recreate webview?";
            caption = "Browser process exited";
            AskForReinit(message, caption);
            break;
        case CoreWebView2ProcessFailedKind.RenderProcessUnresponsive:
            message = "Browser render process has stopped responding.  Recreate webview?";
            caption = "Web page unresponsive";
            AskForReinit(message, caption);
            break;
        case CoreWebView2ProcessFailedKind.RenderProcessExited:
            message = "Browser render process exited unexpectedly. Reload page?";
            caption = "Web page unresponsive";
            AskForReload(message, caption);
            break;
        case CoreWebView2ProcessFailedKind.FrameRenderProcessExited:
            // A frame-only renderer has exited unexpectedly. Check if reload is needed.
            // In this sample we only reload if the app's content has been impacted.
            foreach (CoreWebView2FrameInfo frameInfo in e.ImpactedFramesInfo)
            {
                // Sample virtual host name for the app's content.
                string virtualAppHostName = "https://appassets.example/";
                if (frameInfo.Source.StartsWith(virtualAppHostName))
                {
                    message = "Browser render process for app frame exited unexpectedly. Reload page?";
                    caption = "App content frame unresponsive";
                    AskForReload(message, caption);
                    break;
                }
            }
            break;
        default:
            // Show the process failure details. Apps can collect info for their logging purposes.
            caption = "Child process failed";
            StringBuilder messageBuilder = new StringBuilder();
            messageBuilder.AppendLine($"Process kind: {e.ProcessFailedKind}");
            messageBuilder.AppendLine($"Reason: {e.Reason}");
            messageBuilder.AppendLine($"Exit code: {e.ExitCode}");
            messageBuilder.AppendLine($"Process description: {e.ProcessDescription}");
            MessageBox.Show(messageBuilder.ToString(), caption, MessageBoxButton.OK);
            break;
    }
}

```


# Remarks
* `ProcessFailedKind` in the event args will be `RENDER_PROCESS_EXITED` if the failed process is the main frame's renderer, even if there were subframes rendered by such process. All frames are gone when this happens and `ImpactedFrames` will be `null` as the attribute is intended for frame-only renderer failures only.

* `Reason` in the event args is always `UNEXPECTED` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `UNRESPONSIVE` when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.

* `ExitCode` is always `1` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.


# API Notes
See [API Details](#api-details) section below for API reference.

* Triple-slash (`///`) comments will appear in the public API documentation.
* Double-slash (`//`) comments are notes for this review only and will not show in public documentation.


# API Details
## COM
```cpp
```

## .NET and WinRT
```c#
```
