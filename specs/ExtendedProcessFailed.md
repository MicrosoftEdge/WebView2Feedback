# Background
WebView2 provides applications with the [ProcessFailed](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#add_processfailed) event so they can react accordingly when a process failure occurs. However, this event does not currently provide additional information about the process failure, nor does it cover the cases in which only subframes within the CoreWebView2 are impacted by the failure, or the cases in which a process other than the browser/render process fails.

In this document we describe an extended version of the [PROCESS_FAILED_KIND](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#corewebview2_process_failed_kind) enum, which covers the new scenarios in which the event is raised: frame-only render process failure, and process failures for processes other than the browser/render process. We also include a new version of the [ProcessFailedEventArgs](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2processfailedeventargs?view=webview2-1.0.705.50) that enables the host application to collect additional information about the process failure for their logging and telemetry purposes.

The updated API is detailed below. We'd appreciate your feedback.


# Description
We propose to add new cases for which the `ProcessFailed` event is raised:
  1. When a frame-only render process fails. Only subframes within the `CoreWebView2` are impacted in this case (the content is gone and replaced with an error page).
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
library WebView2
{
// ...

/// Specifies the process failure type used in the
/// `ICoreWebView2ProcessFailedEventHandler` interface. The values in this enum
/// make reference to the process kinds in the Chromium architecture. For more
/// information about what these processes are and what they do, see
/// [Browser Architecture - Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1)
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
  /// The app runs `Reload()` to try to recover from the failure.
  COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED,

  /// Indicates that the main frame's render process is unresponsive.
  COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE,

  // New values.
  
  /// Indicates that a frame-only render process ended unexpectedly. The process
  /// exit does not impact the top-level document, only a subset of the
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

  /// The process was killed. For example, from Task Manager.
  COREWEBVIEW2_PROCESS_FAILED_REASON_KILLED,

  /// The process crashed.
  COREWEBVIEW2_PROCESS_FAILED_REASON_CRASHED,

  /// The process failed to launch.
  COREWEBVIEW2_PROCESS_FAILED_REASON_LAUNCH_FAILED,

  /// The process died due to running out of memory.
  COREWEBVIEW2_PROCESS_FAILED_REASON_OUT_OF_MEMORY,
} COREWEBVIEW2_PROCESS_FAILED_REASON;

/// A continuation of `ICoreWebView2ProcessFailedEventArgs` interface.
[uuid(c62f5687-2f09-481b-b6e4-2c0620bc95a2), object, pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs2 : IUnknown {
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

  /// The exit code of the failing process. The exit code is always `1` when
  /// `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED`, and
  /// `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE`.
  [propget] HRESULT ExitCode(
      [out, retval] int* exitCode);

  /// Description of the process assigned by the WebView2 Runtime. This is a
  /// technical English term appropriate for logging or development purposes,
  /// and not localized for the end user. It applies to utility processes (for example,
  /// "Audio Service" or "Video Capture") and plugin processes (for example, "Flash").
  /// The returned `processDescription` is `null` if the WebView2 Runtime did
  /// not assign a description to the process.
  [propget] HRESULT ProcessDescription(
      [out, retval] LPWSTR* processDescription);

  /// The list of frames in the `CoreWebView2` that were being rendered by the
  /// failed process. The content in these frames is replaced with an error page.
  /// This is only available when `ProcessFailedKind` is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_FRAME_RENDER_PROCESS_EXITED`;
  /// `frames` is `null` for all other process failure kinds, including the case
  /// in which the failed process was the renderer for the main frame and
  /// subframes within it, for which the failure kind is
  /// `COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED`.
  [propget] HRESULT ImpactedFramesInfo(
      [out, retval] ICoreWebView2FrameInfoCollection** frames);
}

/// Collection of frame details (name and source). Used to list the impacted
/// frames' info when a frame-only render process failure occurs in the
/// `ICoreWebView2`.
[uuid(4bedeef8-3de7-4a3a-aadc-e9437bfb3e92), object, pointer_default(unique)]
interface ICoreWebView2FrameInfoCollection : IUnknown {
  /// Gets an iterator over the collection of frames' info.
  HRESULT GetIterator(
      [out, retval] ICoreWebView2FrameInfoCollection** iterator);
}

/// Iterator for a collection of frames' info. For more info, see
/// `ICoreWebView2ProcessFailedEventArgs2` and
/// `ICoreWebView2FrameInfoCollection`.
[uuid(0e2367b9-c725-4696-bb8a-75b97af32330), object, pointer_default(unique)]
interface ICoreWebView2FrameInfoCollectionIterator : IUnknown {
  /// Get the current `ICoreWebView2FrameInfo` of the iterator.
  HRESULT GetCurrentFrameInfo([out, retval] ICoreWebView2FrameInfo** frameInfo);

  /// `TRUE` when the iterator has not run out of frames' info.  If the
  /// collection over which the iterator is iterating is empty or if the
  /// iterator has gone past the end of the collection, then this is `FALSE`.
  [propget] HRESULT HasCurrentFrameInfo([out, retval] BOOL* hasCurrent);

  /// Move the iterator to the next frame's info in the collection.
  HRESULT MoveNext([out, retval] BOOL* hasNext);
}

/// Provides a set of properties for a frame in the `ICoreWebView2`.
[uuid(b41e743b-ab1a-4054-bafa-d3347ddc4ddc), object, pointer_default(unique)]
interface ICoreWebView2FrameInfo : IUnknown {
  /// The name attribute of the frame, as in `<iframe name="frame-name" ...>`.
  /// This is `null` when the frame has no name attribute.
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
    /// are and what they do, see [Browser Architecture - Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1)
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
        /// The app runs `Reload()` to try to recover from the failure.
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
        /// The process was killed. For example, from Task Manager.
        Killed,
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

        /// The exit code of the failing process. The exit code is always `1` when
        /// `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.BrowserProcessExited`, and
        /// `STILL_ACTIVE` (`259`) when `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.RenderProcessUnresponsive`.
        Int32 ExitCode { get; };

        /// Description of the process assigned by the WebView2 Runtime. This is a
        /// technical English term appropriate for logging or development purposes,
        /// and not localized for the end user. It applies to utility processes (for example,
        /// "Audio Service" or "Video Capture") and plugin processes (for example, "Flash").
        /// The returned string is `null` if the WebView2 Runtime did
        /// not assign a description to the process.
        String ProcessDescription { get; };

        /// The list of frames in the `CoreWebView2` that were being rendered by the
        /// failed process. The content in these frames is replaced with an error page.
        /// This is only available when `ProcessFailedKind` is
        /// `CoreWebView2ProcessFailedKind.FrameRenderProcessExited`;
        /// it is `null` for all other process failure kinds, including the case
        /// in which the failed process was the renderer for the main frame and
        /// subframes within it, for which the failure kind is
        /// `CoreWebView2ProcessFailedKind.RenderProcessExited`.
        CoreWebView2FrameInfoCollection ImpactedFramesInfo { get; };
    }

    /// Collection of frame details (name and source). Used to list the impacted
    /// frames' info when a frame-only render process failure occurs in the
    /// `CoreWebView2`.
    runtimeclass CoreWebView2FrameInfoCollection
    {
        /// Gets an iterator over the collection of frames' info.
        CoreWebView2FrameInfoCollection GetIterator();
    }

    /// Iterator for a collection of frames' info. For more info, see
    /// `CoreWebView2ProcessFailedEventArgs` and
    /// ICoreWebView2FrameInfoCollection`.
    runtimeclass CoreWebView2FrameInfoCollectionIterator
    {
        /// `true` when the iterator has not run out of frames' info.  If the
        /// collection over which the iterator is iterating is empty or if the
        /// iterator has gone past the end of the collection, then this is `false`.
        Boolean HasCurrentFrameInfo { get; };

        /// Get the current `CoreWebView2FrameInfo` of the iterator.
        CoreWebView2FrameInfo GetCurrentFrameInfo();

        /// Move the iterator to the next frame's info in the collection.
        Boolean MoveNext();
    }

    /// Provides a set of properties for a frame in the `CoreWebView2`.
    runtimeclass CoreWebView2FrameInfo
    {
        /// The name attribute of the frame, as in `<iframe name="frame-name" ...>`.
        /// This is `null` when the frame has no name attribute.
        String Name { get; };

        /// The URI of the document in the frame.
        String Source { get; };
    }
}

```
