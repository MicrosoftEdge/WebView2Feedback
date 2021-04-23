# Background
WebView2 provides applications with the [ProcessFailed](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed) event so they can react accordingly when a process failure occurs. However, this event does not currently provide additional information about the process failure, nor does it cover the cases in which only subframes within the CoreWebView2 are impacted by the failure, or the cases in which a process other than the browser/render process fails.

In this document we describe an extended version of the [PROCESS_FAILED_KIND](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#corewebview2_process_failed_kind) enum, which covers the new scenarios in which the event is raised: frame-only render process failure, and process failures for processes other than the browser/render process. We also include a new version of the [ProcessFailedEventArgs](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.705.50) that enables the host application to collect additional information about the process failure for their logging and telemetry purposes.

The updated API is detailed below. We'd appreciate your feedback.


# Description
We propose to add new cases for which the `ProcessFailed` event is raised:
  1. When a frame-only render process fails. Only subframes within the `CoreWebView2` are affected in this case (the content is gone and replaced with an error page).
  2. When a WebView2 Runtime child process other than the browser process or a render process fails. The app can use these process failures for logging and telemetry purposes.

We also propose extending the `ProcessFailedEventArgs` to provide additional information about the process failure:
  * Reason of the failure.
  * Exit code.
  * Process description.
  * Affected frames for (1) above.


# Examples
The following code snippets demonstrate how the updated `ProcessFailedEventArgs` can be used by the host application:

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

    return L"PROCESS FAILED: " + std::to_wstring(static_cast<uint32_t>(kind));
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
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_TERMINATED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_CRASHED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_LAUNCH_FAILED);
        REASON_ENTRY(COREWEBVIEW2_PROCESS_FAILED_REASON_OUT_OF_MEMORY);

#undef REASON_ENTRY
    }

    return L"REASON: " + std::to_wstring(static_cast<uint32_t>(reason));
}

bool ProcessComponent::IsAppContentUri(const std::wstring& source)
{
    wil::com_ptr<IUri> uri;
    CHECK_FAILURE(CreateUri(source.c_str(), Uri_CREATE_CANONICALIZE, 0, &uri));
    wil::unique_bstr domain;
    CHECK_FAILURE(uri->GetDomain(&domain));

    // Content from our app uses a mapped host name.
    const std::wstring mappedAppHostName = L"appassets.example";
    return domain.get() == mappedAppHostName;
}

void ProcessComponent::ScheduleReinitIfSelectedByUser(
    const std::wstring& message, const std::wstring& caption)
{
    // Do not block from event handler
    m_appWindow->RunAsync([this, message, caption]() {
        int selection = MessageBox(
            m_appWindow->GetMainWindow(), message.c_str(), caption.c_str(), MB_YESNO);
        if (selection == IDYES)
        {
            m_appWindow->ReinitializeWebView();
        }
    });
}

void ProcessComponent::ScheduleReloadIfSelectedByUser(
    const std::wstring& message, const std::wstring& caption)
{
    // Do not block from event handler
    m_appWindow->RunAsync([this, message, caption]() {
        int selection = MessageBox(
            m_appWindow->GetMainWindow(), message.c_str(), caption.c_str(), MB_YESNO);
        if (selection == IDYES)
        {
            CHECK_FAILURE(m_webView->Reload());
        }
    });
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
            COREWEBVIEW2_PROCESS_FAILED_KIND kind;
            CHECK_FAILURE(args->get_ProcessFailedKind(&kind));
            if (kind == COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED)
            {
                // Do not run a message loop from within the event handler
                // as that could lead to reentrancy and leave the event
                // handler in stack indefinitely. Instead, schedule the
                // appropriate work to take place after completion of the
                // event handler.
                ScheduleReinitIfSelectedByUser(
                    L"Browser process exited unexpectedly. Recreate webview?",
                    L"Browser process exited");
            }
            else if (kind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE)
            {
                ScheduleReinitIfSelectedByUser(
                    L"Browser render process has stopped responding. Recreate webview?",
                    L"Web page unresponsive");
            }
            else if (kind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED)
            {
                // Reloading the page will start a new render process if
                // needed.
                ScheduleReloadIfSelectedByUser(
                    L"Browser render process exited unexpectedly. Reload page?",
                    L"Web page unresponsive");
            }
            // Check the runtime event args implements the newer interface.
            auto args2 = args.try_query<ICoreWebView2ProcessFailedEventArgs2>();
            if (!args2)
            {
                return S_OK;
            }
            if (kind == COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED)
            {
                // A frame-only renderer has exited unexpectedly. Check if
                // reload is needed.
                wil::com_ptr<ICoreWebView2FrameInfoCollection> frameInfos;
                wil::com_ptr<ICoreWebView2FrameInfoCollectionIterator> iterator;
                CHECK_FAILURE(args2->get_FrameInfosForFailedProcess(&frameInfos));
                CHECK_FAILURE(frameInfos->GetIterator(&iterator));

                BOOL hasCurrent = FALSE;
                while (SUCCEEDED(iterator->get_HasCurrent(&hasCurrent)) && hasCurrent)
                {
                    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo;
                    CHECK_FAILURE(iterator->GetCurrent(&frameInfo));

                    wil::unique_cotaskmem_string nameRaw;
                    wil::unique_cotaskmem_string sourceRaw;
                    CHECK_FAILURE(frameInfo->get_Name(&nameRaw));
                    CHECK_FAILURE(frameInfo->get_Source(&sourceRaw));
                    if (IsAppContentUri(sourceRaw.get()))
                    {
                        ScheduleReloadIfSelectedByUser(
                            L"Browser render process for app frame exited unexpectedly. "
                            L"Reload page?",
                            L"App content frame unresponsive");
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
                message << L"Kind: "                << ProcessFailedKindToString(kind) << L"\n"
                        << L"Reason: "              << ProcessFailedReasonToString(reason) << L"\n"
                        << L"Exit code: "           << std::to_wstring(exitCode) << L"\n"
                        << L"Process description: " << processDescription.get() << std::endl;
                m_appWindow->RunAsync([this, message = message.str()]() {
                    MessageBox(
                        m_appWindow->GetMainWindow(), message.c_str(),
                        L"Child process failed", MB_OK);
                });
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

    <DockPanel>
        <!-- ... -->

        <DockPanel DockPanel.Dock="Top">

            <!-- ... -->

            <TextBox x:Name="url" Text="{Binding ElementName=webView,Path=Source,Mode=OneWay}">
                <TextBox.InputBindings>
                    <KeyBinding Key="Return" Command="NavigationCommands.GoToPage" CommandParameter="{Binding ElementName=url,Path=Text}" />
                </TextBox.InputBindings>
            </TextBox>
        </DockPanel>

        <Grid x:Name="Layout">
            <wv2:WebView2
                x:Name="webView"
                CreationProperties="{StaticResource EvergreenWebView2CreationProperties}"
                Source="https://www.bing.com/"
            />
            <!-- The control event handlers are set in code behind so they can be reused when replacing the control after
            a WebView2 Runtime's browser process failure
            -->
        </Grid>
    </DockPanel>
</Window>

```

```c#
public MainWindow()
{
    InitializeComponent();
    AttachControlEventHandlers(webView);
}

void AttachControlEventHandlers(WebView2 control) {
    control.NavigationStarting += WebView_NavigationStarting;
    control.NavigationCompleted += WebView_NavigationCompleted;
    control.CoreWebView2InitializationCompleted += WebView_CoreWebView2InitializationCompleted;
    control.KeyDown += WebView_KeyDown;
}

// The WPF WebView2 control is first added to the visual tree from the webView
// element in the XAML for this class. When we want to replace this instance,
// we need to remove it from the visual tree first.
private bool _isControlInVisualTree = true;

void RemoveControlFromVisualTree(WebView2 control)
{
    Layout.Children.Remove(control);
    _isControlInVisualTree = false;
}

void AttachControlToVisualTree(WebView2 control)
{
    Layout.Children.Add(control);
    _isControlInVisualTree = true;
}

WebView2 GetReplacementControl()
{
    WebView2 replacementControl = new WebView2();
    ((System.ComponentModel.ISupportInitialize)(replacementControl)).BeginInit();
    // Setup properties and bindings
    replacementControl.CreationProperties = webView.CreationProperties;

    Binding urlBinding = new Binding()
    {
        Source = replacementControl,
        Path = new PropertyPath("Source"),
        Mode = BindingMode.OneWay
    };
    url.SetBinding(TextBox.TextProperty, urlBinding);

    AttachControlEventHandlers(replacementControl);
    replacementControl.Source = webView.Source ?? new Uri("https://www.bing.com");
    ((System.ComponentModel.ISupportInitialize)(replacementControl)).EndInit();

    return replacementControl;
}

void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        webView.CoreWebView2.ProcessFailed += WebView_ProcessFailed;
        return;
    }

    MessageBox.Show($"WebView2 creation failed with exception = {e.InitializationException}");
}

void WebView_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
{
    void ReinitIfSelectedByUser(CoreWebView2ProcessFailedKind kind)
    {
        string caption;
        string message;
        if (kind == CoreWebView2ProcessFailedKind.BrowserProcessExited)
        {
            caption = "Browser process exited";
            message = "WebView2 Runtime's browser process exited unexpectedly. Recreate WebView?";
        }
        else
        {
            caption = "Web page unresponsive";
            message = "WebView2 Runtime's render process stopped responding. Recreate WebView?";
        }

        var selection = MessageBox.Show(message, caption, MessageBoxButton.YesNo);
        if (selection == MessageBoxResult.Yes)
        {
            // The control cannot be re-initialized so we setup a new instance to replace it.
            // Note the previous instance of the control has been disposed of and removed from
            // the visual tree before attaching the new one.
            WebView2 replacementControl = GetReplacementControl();
            if (_isControlInVisualTree)
            {
                RemoveControlFromVisualTree(webView);
            }
            // Dispose of the control so additional resources are released. We do this only
            // after creating the replacement control as properties for the replacement
            // control are taken from the existing instance.
            webView.Dispose();
            webView = replacementControl;
            AttachControlToVisualTree(webView);
        }
    }

    void ReloadIfSelectedByUser(CoreWebView2ProcessFailedKind kind)
    {
        string caption;
        string message;
        if (kind == CoreWebView2ProcessFailedKind.RenderProcessExited)
        {
            caption = "Web page unresponsive";
            message = "WebView2 Runtime's render process exited unexpectedly. Reload page?";
        }
        else
        {
            caption = "App content frame unresponsive";
            message = "WebView2 Runtime's render process for app frame exited unexpectedly. Reload page?";
        }

        var selection = MessageBox.Show(message, caption, MessageBoxButton.YesNo);
        if (selection == MessageBoxResult.Yes)
        {
            webView.Reload();
        }
    }

    bool IsAppContentUri(Uri source)
    {
        // Sample virtual host name for the app's content.
        // See CoreWebView2.SetVirtualHostNameToFolderMapping: https://docs.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.setvirtualhostnametofoldermapping
        return source.Host == "appassets.example";
    }

    switch (e.ProcessFailedKind)
    {
        case CoreWebView2ProcessFailedKind.BrowserProcessExited:
            // Once the WebView2 Runtime's browser process has crashed,
            // the control becomes virtually unusable as the process exit
            // moves the CoreWebView2 to its Closed state. Most calls will
            // become invalid as they require a backing browser process.
            // Remove the control from the visual tree so the framework does
            // not atempt to redraw it, which would call the invalid methods.
            RemoveControlFromVisualTree(webView);
            goto case CoreWebView2ProcessFailedKind.RenderProcessUnresponsive;
        case CoreWebView2ProcessFailedKind.RenderProcessUnresponsive:
            System.Threading.SynchronizationContext.Current.Post((_) =>
            {
                ReinitIfSelectedByUser(e.ProcessFailedKind);
            }, null);
            break;
        case CoreWebView2ProcessFailedKind.RenderProcessExited:
            System.Threading.SynchronizationContext.Current.Post((_) =>
            {
                ReloadIfSelectedByUser(e.ProcessFailedKind);
            }, null);
            break;
        case CoreWebView2ProcessFailedKind.FrameRenderProcessExited:
            // A frame-only renderer has exited unexpectedly. Check if reload is needed.
            // In this sample we only reload if the app's content has been impacted.
            foreach (CoreWebView2FrameInfo frameInfo in e.FrameInfosForFailedProcess)
            {
                if (IsAppContentUri(new System.Uri(frameInfo.Source)))
                {
                    goto case CoreWebView2ProcessFailedKind.RenderProcessExited;
                }
            }
            break;
        default:
            // Show the process failure details. Apps can collect info for their logging purposes.
            StringBuilder messageBuilder = new StringBuilder();
            messageBuilder.AppendLine($"Process kind: {e.ProcessFailedKind}");
            messageBuilder.AppendLine($"Reason: {e.Reason}");
            messageBuilder.AppendLine($"Exit code: {e.ExitCode}");
            messageBuilder.AppendLine($"Process description: {e.ProcessDescription}");
            System.Threading.SynchronizationContext.Current.Post((_) =>
            {
                MessageBox.Show(messageBuilder.ToString(), "Child process failed", MessageBoxButton.OK);
            }, null);
            break;
    }
}

```


# Remarks
* `ProcessFailedKind` in the event args will be `RENDER_PROCESS_EXITED` if the failed process is the main frame's renderer, even if there were subframes rendered by such process. All frames are gone when this happens and `FrameInfosForFailedProcess` will be `null` as the attribute is intended for frame-only renderer failures only.

* `Reason` in the event args is always `UNEXPECTED` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `UNRESPONSIVE` when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.

* `ExitCode` is always `1` when `ProcessFailedKind` is `BROWSER_PROCESS_EXITED`, and `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is `RENDER_PROCESS_UNRESPONSIVE`.


# API Notes
See [API Details](#api-details) section below for API reference.

* Triple-slash (`///`) comments will appear in the public API documentation.
* Double-slash (`//`) comments are notes for this review only and will not show in public documentation.


# API Details
## COM
```cpp
library WebView2
{
// ...

/// Specifies the process failure type used in the
/// `ICoreWebView2ProcessFailedEventHandler` interface. The values in this enum
/// make reference to the process kinds in the Chromium architecture. For more
/// information about what these processes are and what they do, see
/// [Browser Architecture - Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1).
[v1_enum]
typedef enum COREWEBVIEW2_PROCESS_FAILED_KIND {
  // Existing stable values.

  // Note: docs for this enum value remain unchanged.
  /// Indicates that the browser process ended unexpectedly.  The WebView
  /// automatically moves to the Closed state.  The app has to recreate a new
  /// WebView to recover from this failure.
  COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED,

  /// Indicates that the main frame's render process ended unexpectedly.  A new
  /// render process is created automatically and navigated to an error page.
  /// You can use the `Reload` method to try to reload the page that failed.
  COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED,

  /// Indicates that the main frame's render process is unresponsive.
  COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE,

  // New values.

  /// Indicates that a frame-only render process ended unexpectedly. The process
  /// exit does not affect the top-level document, only a subset of the
  /// subframes within it. The content in these frames is replaced with an error
  /// page in the frame.
  COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED,

  /// Indicates that a utility process ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_UTILITY_PROCESS_EXITED,

  /// Indicates that a sandbox helper process ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_SANDBOX_HELPER_PROCESS_EXITED,

  /// Indicates that the GPU process ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_GPU_PROCESS_EXITED,

  /// Indicates that a PPAPI plugin process ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_PPAPI_PLUGIN_PROCESS_EXITED,

  /// Indicates that a PPAPI plugin broker process ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_PPAPI_BROKER_PROCESS_EXITED,

  /// Indicates that a process of unspecified kind ended unexpectedly.
  COREWEBVIEW2_PROCESS_FAILED_KIND_UNKNOWN_PROCESS_EXITED,
} COREWEBVIEW2_PROCESS_FAILED_KIND;


/// Specifies the process failure reason used in the
/// `ICoreWebView2ProcessFailedEventHandler` interface.
[v1_enum]
typedef enum COREWEBVIEW2_PROCESS_FAILED_REASON {
  /// An unexpected process failure occurred.
  COREWEBVIEW2_PROCESS_FAILED_REASON_UNEXPECTED,

  /// The process became unresponsive.
  /// This only applies to the main frame's render process.
  COREWEBVIEW2_PROCESS_FAILED_REASON_UNRESPONSIVE,

  /// The process was terminated. For example, from Task Manager.
  COREWEBVIEW2_PROCESS_FAILED_REASON_TERMINATED,

  /// The process crashed.
  COREWEBVIEW2_PROCESS_FAILED_REASON_CRASHED,

  /// The process failed to launch.
  COREWEBVIEW2_PROCESS_FAILED_REASON_LAUNCH_FAILED,

  /// The process died due to running out of memory.
  COREWEBVIEW2_PROCESS_FAILED_REASON_OUT_OF_MEMORY,
} COREWEBVIEW2_PROCESS_FAILED_REASON;

/// A continuation of `ICoreWebView2ProcessFailedEventArgs` interface.
[uuid(4dab9422-46fa-4c3e-a5d2-41d2071d3680), object, pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs2 : ICoreWebView2ProcessFailedEventArgs {
  // The ProcessFailedKind property below is already in
  // ICoreWebView2ProcessFailedEventArgs. The changes to this interface extend
  // its return enum so it can now specify additional process kinds: gpu process
  // exited, utility process exited, etc. The property is included here to show
  // the updated docs.

  /// The kind of process failure that has occurred. `processFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED` if the
  /// failed process is the main frame's renderer, even if there were subframes
  /// rendered by such process; all frames are gone when this happens.
  // [propget] HRESULT ProcessFailedKind(
  //     [out, retval] COREWEBVIEW2_PROCESS_FAILED_KIND* processFailedKind);

  /// The reason for the process failure. The reason is always
  /// `COREWEBVIEW2_PROCESS_FAILED_REASON_UNEXPECTED` when `ProcessFailedKind`
  /// is `COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED`, and
  /// `COREWEBVIEW2_PROCESS_FAILED_REASON_UNRESPONSIVE` when `ProcessFailedKind`
  /// is `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE`.
  /// For other process failure kinds, the reason may be any of the reason
  /// values.
  [propget] HRESULT Reason(
      [out, retval] COREWEBVIEW2_PROCESS_FAILED_REASON* reason);

  /// The exit code of the failing process, for telemetry purposes. The exit
  /// code is always `1` when `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED`, and
  /// `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE`.
  [propget] HRESULT ExitCode(
      [out, retval] int* exitCode);

  /// Description of the process assigned by the WebView2 Runtime. This is a
  /// technical English term appropriate for logging or development purposes,
  /// and not localized for the end user. It applies to utility processes (for
  /// example, "Audio Service", "Video Capture") and plugin processes (for
  /// example, "Flash"). The returned `processDescription` is empty if the
  /// WebView2 Runtime did not assign a description to the process.
  [propget] HRESULT ProcessDescription(
      [out, retval] LPWSTR* processDescription);

  /// The collection of `FrameInfo`s for frames in the `CoreWebView2` that were
  /// being rendered by the failed process. The content in these frames is
  /// replaced with an error page.
  /// This is only available when `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED`;
  /// `frames` is `null` for all other process failure kinds, including the case
  /// in which the failed process was the renderer for the main frame and
  /// subframes within it, for which the failure kind is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED`.
  [propget] HRESULT FrameInfosForFailedProcess(
      [out, retval] ICoreWebView2FrameInfoCollection** frames);
}

/// Collection of `FrameInfo`s (name and source). Used to list the affected
/// frames' info when a frame-only render process failure occurs in the
/// `ICoreWebView2`.
[uuid(8f834154-d38e-4d90-affb-6800a7272839), object, pointer_default(unique)]
interface ICoreWebView2FrameInfoCollection : IUnknown {
  /// Gets an iterator over the collection of `FrameInfo`s.
  HRESULT GetIterator(
      [out, retval] ICoreWebView2FrameInfoCollectionIterator** iterator);
}

/// Iterator for a collection of `FrameInfo`s. For more info, see
/// `ICoreWebView2ProcessFailedEventArgs2` and
/// `ICoreWebView2FrameInfoCollection`.
[uuid(1bf89e2d-1b2b-4629-b28f-05099b41bb03), object, pointer_default(unique)]
interface ICoreWebView2FrameInfoCollectionIterator : IUnknown {
  /// `TRUE` when the iterator has not run out of `FrameInfo`s.  If the
  /// collection over which the iterator is iterating is empty or if the
  /// iterator has gone past the end of the collection, then this is `FALSE`.
  [propget] HRESULT HasCurrent([out, retval] BOOL* hasCurrent);

  /// Get the current `ICoreWebView2FrameInfo` of the iterator.
  HRESULT GetCurrent([out, retval] ICoreWebView2FrameInfo** frameInfo);

  /// Move the iterator to the next `FrameInfo` in the collection.
  HRESULT MoveNext([out, retval] BOOL* hasNext);
}

/// Provides a set of properties for a frame in the `ICoreWebView2`.
[uuid(da86b8a1-bdf3-4f11-9955-528cefa59727), object, pointer_default(unique)]
interface ICoreWebView2FrameInfo : IUnknown {
  /// The name attribute of the frame, as in `<iframe name="frame-name" ...>`.
  /// The returned string is empty when the frame has no name attribute.
  [propget] HRESULT Name([out, retval] LPWSTR* name);

  /// The URI of the document in the frame.
  [propget] HRESULT Source([out, retval] LPWSTR* source);
}

}

```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    /// Specifies the process failure type used in the
    /// `CoreWebView2ProcessFailedEventArgs`.
    /// The values in this enum make reference to the process kinds in the
    /// Chromium architecture. For more information about what these processes
    /// are and what they do, see [Browser Architecture - Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1).
    enum CoreWebView2ProcessFailedKind
    {
        // Existing stable values

        // Note: docs for this enum value remain unchaged.
        /// Indicates that the browser process ended unexpectedly.  The WebView
        /// automatically moves to the Closed state.  The app has to recreate a new
        /// WebView to recover from this failure.
        BrowserProcessExited,
        /// Indicates that the main frame's render process ended unexpectedly.  A new
        /// render process is created automatically and navigated to an error page.
        /// You can use the `Reload` method to try to reload the page that failed.
        RenderProcessExited,
        /// Indicates that the main frame's render process is unresponsive.
        RenderProcessUnresponsive,

        // New values.

        /// Indicates that a frame-only render process ended unexpectedly. The process
        /// exit does not impact the top-level document, only a subset of the
        /// subframes within it. The content in these frames is replaced with an
        /// error page in the frame.
        FrameRenderProcessExited,
        /// Indicates that a utility process ended unexpectedly.
        UtilityProcessExited,
        /// Indicates that a sandbox helper process ended unexpectedly.
        SandboxHelperProcessExited,
        /// Indicates that the GPU process ended unexpectedly.
        GpuProcessExited,
        /// Indicates that a PPAPI plugin process ended unexpectedly.
        PpapiPluginProcessExited,
        /// Indicates that a PPAPI plugin broker process ended unexpectedly.
        PpapiBrokerProcessExited,
        /// Indicates that a process of unspecified kind ended unexpectedly.
        UnknownProcessExited,
    };

    /// Specifies the process failure reason used in the
    /// `CoreWebView2ProcessFailedEventArgs`.
    enum CoreWebView2ProcessFailedReason
    {
        /// An unexpected process failure occurred.
        Unexpected,
        /// The process became unresponsive.
        /// This only applies to the main frame's render process.
        Unresponsive,
        /// The process was terminated. For example, from Task Manager.
        Terminated,
        /// The process crashed.
        Crashed,
        /// The process failed to launch.
        LaunchFailed,
        /// The process died due to running out of memory.
        OutOfMemory,
    };

    runtimeclass CoreWebView2ProcessFailedEventArgs
    {
        // The property below is already in the event args and included here
        // just to show the updated docs.

        /// The kind of process failure that has occurred. Returns
        /// `CoreWebView2ProcessFailedKind.RenderProcessExited` if the
        /// failed process is the main frame's renderer, even if there were subframes
        /// rendered by such process; all frames are gone when this happens.
        // CoreWebView2ProcessFailedKind ProcessFailedKind { get; };


        /// The reason for the process failure. The reason is always
        /// `CoreWebView2ProcessFailedReason.Unexpected` when `ProcessFailedKind`
        /// is `CoreWebView2ProcessFailedKind.BrowserProcessExited`, and
        /// `CoreWebView2ProcessFailedReason.Unresponsive` when `ProcessFailedKind`
        /// is `CoreWebView2ProcessFailedKind.RenderProcessUnresponsive`.
        /// For other process failure kinds, the reason may be any of the reason
        /// values.
        CoreWebView2ProcessFailedReason Reason { get; };

        /// The exit code of the failing process, for telemetry purposes. The
        /// exit code is always `1` when `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.BrowserProcessExited`, and
        /// `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.RenderProcessUnresponsive`.
        Int32 ExitCode { get; };

        /// Description of the process assigned by the WebView2 Runtime. This is a
        /// technical English term appropriate for logging or development purposes,
        /// and not localized for the end user. It applies to utility processes (for
        /// example, "Audio Service", "Video Capture") and plugin processes (for
        /// example, "Flash"). The returned string is empty if the WebView2 Runtime
        /// did not assign a description to the process.
        String ProcessDescription { get; };

        /// The collection of frames in the `CoreWebView2` that were being rendered by the
        /// failed process. The content in these frames is replaced with an error page.
        /// This is only available when `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.FrameRenderProcessExited`;
        /// it is empty for all other process failure kinds, including the case
        /// in which the failed process was the renderer for the main frame and
        /// subframes within it, for which the failure kind is
        /// `CoreWebView2ProcessFailedKind.RenderProcessExited`.
        IVectorView<CoreWebView2FrameInfo> FrameInfosForFailedProcess { get; };
    }

    /// Provides a set of properties for a frame in the `CoreWebView2`.
    runtimeclass CoreWebView2FrameInfo
    {
        /// The name attribute of the frame, as in `<iframe name="frame-name" ...>`.
        /// The returned string is empty when the frame has no name attribute.
        String Name { get; };

        /// The URI of the document in the frame.
        String Source { get; };
    }
}

```
