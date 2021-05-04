# Background
We have heard asks for a WebView2 API to easily track the WebView2 Runtime's
browser process exit. Manually waiting for the process to exit requires
additional work on the host app, so we are proposing the `BrowserProcessExited`
event. The `ProcessFailed` event already lets app developers handle unexpected
browser process exits for a WebView; this new API lets you listen to both
expected and unexpected termination of the collection of processes associated to
a `CoreWebView2Environment` so you can, for example, cleanup the user data folder when
it's no longer in use. In this document we describe the new API. We'd appreciate
your feedback.


# Description
The `BrowserProcessExited` event allows developers to subscribe event handlers
to be run when the collection of WebView2 Runtime processes associated to a
`CoreWebView2Environment` terminate. Key scenarios are cleanup of the user data
folder used by the WebView2 Runtime, which is locked while the runtime's browser
process is active, and moving to a new WebView2 Runtime version after a
`NewBrowserVersionAvailable` event.

This event is raised for both expected and unexpected termination of the
collection of processes, after all resources, including the user data folder,
used by the WebView2 Runtime have been released. The
`CoreWebView2BrowserProcessExitedEventArgs` lets app developers get
the `BrowserProcessExitKind` so they can decide how to handle different exit
kinds. For example, you might want to bypass handling if an event handler for
`CoreWebView2ProcessFailedKind.BrowserProcessFailed` cases of the
`CoreWebView2`s `ProcessFailed` event is already registered. In case of a
browser process crash, both `BrowserProcessExited` and `ProcessFailed` events
are raised, but the order is not guaranteed. These events are intended for
different scenarios. It is up to the app to coordinate the handlers so they do
not try to perform reliability recovery while also trying to move to a new
WebView2 Runtime version or remove the user data folder.

Multiple app processes can share a browser process by creating their webviews
from a `CoreWebView2Environment` with the same user data folder. When the entire
collection of WebView2Runtime processes for the browser process exit, all
associated `CoreWebView2Environment` objects receive the `BrowserProcessExited`
event. Multiple processes sharing the same browser process need to coordinate
their use of the shared user data folder to avoid race conditions and
unnecessary waits. For example, one process should not clear the user data
folder at the same time that another process recovers from a crash by recreating
its WebView controls; one process should not block waiting for the event if
other app processes are using the same browser process (the browser process will
not exit until those other processes have closed their webviews too).


# Examples
The following code snippets demonstrate how the `BrowserProcessExited` event can
be used:

## Win32 C++
```cpp
class AppWindow {
  // ...

  wil::com_ptr<ICoreWebView2Controller> m_controller;
  EventRegistrationToken m_browserExitedEventToken = {};
  UINT32 m_newestBrowserPid = 0;
}

HRESULT AppWindow::OnCreateCoreWebView2ControllerCompleted(HRESULT result, ICoreWebView2Controller* controller)
{
  if (result == S_OK)
  {
    // ...

    // Save PID of the browser process serving last WebView created from our
    // CoreWebView2Environment. We know the controller was created with
    // S_OK, and it hasn't been closed (we haven't called Close and no
    // ProcessFailed event could have been raised yet) so the PID is
    // available.
    CHECK_FAILURE(m_webView->get_BrowserProcessId(&m_newestBrowserPid));

    // ...
  }
}

void AppWindow::CloseWebView(/* ... */) {
  // ...

  // Before closing the WebView, register a handler with code to run once the
  // browser process and associated processes are terminated.
  CHECK_FAILURE(m_webViewEnvironment->add_BrowserProcessExited(
      Callback<ICoreWebView2BrowserProcessExitedEventHandler>(
          [this](
              ICoreWebView2Environment* sender,
              ICoreWebView2BrowserProcessExitedEventArgs* args) {
          COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND kind;
          UINT32 pid;
          CHECK_FAILURE(args->get_BrowserProcessExitKind(&kind));
          CHECK_FAILURE(args->get_BrowserProcessId(&pid));

          // If a new WebView is created from this CoreWebView2Environment after
          // the browser has exited but before our handler gets to run, a new
          // browser process will be created and lock the user data folder
          // again. Do not attempt to cleanup the user data folder in these
          // cases. If this happens, the PID of the new browser process will be
          // different to the PID of the older process, we check against the
          // PID of the browser process to which our last CoreWebView2 attached.
          if (pid == m_newestBrowserPid)
          {
            // Watch for graceful browser process exit. Let ProcessFailed event
            // handler take care of failed browser process termination.
            if (kind == COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL)
            {
              CHECK_FAILURE(
                  m_webViewEnvironment->remove_BrowserProcessExited(m_browserExitedEventToken));
              // Release the environment only after the handler is invoked.
              // Otherwise, there will be no environment to raise the event when
              // the collection of WebView2 Runtime processes exit.
              m_webViewEnvironment = nullptr;
              CleanupUserDataFolder();
            }
          }
          else
          {
            // The exiting process is not the last in use. Do not attempt cleanup
            // as we might still have a webview open over the user data folder.
            // Do not block from event handler.
            RunAsync([this]() {
                MessageBox(
                    m_mainWindow,
                    L"A new browser process prevented cleanup of the user data folder.",
                    L"Cleanup User Data Folder", MB_OK);
            });
          }

          return S_OK;
      }).Get(),
      &m_browserExitedEventToken));

  // ...

  // Close the WebView from its controller.
  CHECK_FAILURE(m_controller->Close());

  // Other app state cleanup...
}

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
// URI or other state to save/restore when the WebView is recreated.
private Uri _uriToRestore;

async void RegisterForNewVersion()
{
    // We call EnsureCoreWebiew2Async so the CoreWebView2 property is
    // initialized and not null as we will access the environment from it.
    // Alternatively, if the WebView was created from an environment provided to
    // the control, we can use that environment object directly.
    await webView.EnsureCoreWebView2Async();
    _coreWebView2Environment = webView.CoreWebView2.Environment;
    _coreWebView2Environment.NewBrowserVersionAvailable += Environment_NewBrowserVersionAvailable;
}

// A new version of the WebView2 Runtime is available, our handler gets called.
// We close our WebView and set a handler to reinitialize it once the WebView2
// Runtime collection of processes are gone, so we get the new version of the
// WebView2 Runtime.
async void Environment_NewBrowserVersionAvailable(object sender, object e)
{
    StringBuilder messageBuilder = new StringBuilder(256);
    messageBuilder.Append("We detected there is a new version of the WebView2 Runtime installed. ");
    messageBuilder.Append("Do you want to switch to it now? This will re-create the WebView.");
    var selection = MessageBox.Show(this, messageBuilder.ToString(), "New WebView2 Runtime detected", MessageBoxButton.YesNo);
    if (selection == MessageBoxResult.Yes)
    {
        // If this or any other application creates additional WebViews from the same
        // environment configuration, all those WebViews need to be closed before
        // the browser process will exit. This sample creates a single WebView per
        // MainWindow, we let each MainWindow prepare to recreate and close its WebView.
        CloseAppWebViewsForUpdate();
    }
}

void CloseAppWebViewsForUpdate()
{
    foreach (Window window in Application.Current.Windows)
    {
        if (window is MainWindow mainWindow)
        {
            mainWindow.CloseWebViewForUpdate();
        }
    }
}

void CloseWebViewForUpdate()
{
    // Save URI or other state you want to restore when the WebView is recreated.
    _uriToRestore = webView.Source;
    _coreWebView2Environment.BrowserProcessExited += Environment_BrowserProcessExited;
    // We dispose of the control so the internal WebView objects are released
    // and the associated browser process exits.
    webView.Dispose();
    webView = null;
}

void Environment_BrowserProcessExited(object sender, CoreWebView2BrowserProcessExitedEventArgs e)
{
    ((CoreWebView2Environment)sender).BrowserProcessExited -= Environment_BrowserProcessExited;
    ReinitializeWebView();
}

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

    MyWindow.MyDockPanel.Children.Add(webView);
    webView.Source = _uriToRestore ?? new Uri("https://www.bing.com");
    RegisterForNewVersion();
}
```


# Remarks
Note this is an event from `CoreWebView2Environment`, not `CoreWebView2`. The
difference between `BrowserProcessExited` and `CoreWebView2`'s `ProcessFailed`
is that `BrowserProcessExited` is raised for any **browser process** exit
(expected or unexpected, after all associated processes have exited too), while
`ProcessFailed` is raised for **unexpected** process exits of any kind (browser,
render, GPU, and all other types), or for main frame **render process**
unresponsiveness. To learn more about the WebView2 Process Model, go to
[Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).

In the case the browser process crashes, both `BrowserProcessExited` and
`ProcessFailed` events are raised, but the order is not guaranteed.


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details

## COM
```cpp
library WebView2
{
// ...

/// Specifies the browser process exit type used in the
/// `ICoreWebView2BrowserProcessExitedEventArgs` interface.
typedef enum COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND {
  /// Indicates that the browser process ended normally.
  COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL,

  /// Indicates that the browser process ended unexpectedly.
  /// A `ProcessFailed` event will also be sent to listening WebViews from the
  /// `ICoreWebView2Environment` associated to the failed process.
  COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_FAILED
} COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND;

interface ICoreWebView2Environment3 : ICoreWebView2Environment2
{
  // ...

  /// Add an event handler for the `BrowserProcessExited` event.
  /// The `BrowserProcessExited` event is raised when the collection of WebView2
  /// Runtime processes associated to this environment terminate due to a
  /// browser process error or normal shutdown (for example, when all associated
  /// WebViews are closed), after all resources (including the user data folder)
  /// have been released.
  ///
  /// A handler added with this method is called until removed with
  /// `remove_BrowserProcessExited`, even if a new browser process is bound to
  /// this environment after earlier `BrowserProcessExited` events are raised.
  ///
  /// Multiple app processes can share a browser process by creating their webviews
  /// from a `ICoreWebView2Environment` with the same user data folder. When the entire
  /// collection of WebView2Runtime processes for the browser process exit, all
  /// associated `ICoreWebView2Environment` objects receive the `BrowserProcessExited`
  /// event. Multiple processes sharing the same browser process need to coordinate
  /// their use of the shared user data folder to avoid race conditions and
  /// unnecessary waits. For example, one process should not clear the user data
  /// folder at the same time that another process recovers from a crash by recreating
  /// its WebView controls; one process should not block waiting for the event if
  /// other app processes are using the same browser process (the browser process will
  /// not exit until those other processes have closed their webviews too).
  ///
  /// Note this is an event from the `ICoreWebView2Environment3` interface, not
  /// the `ICoreWebView2` one. The difference between `BrowserProcessExited` and
  /// `ICoreWebView2`'s `ProcessFailed` is that `BrowserProcessExited` is
  /// raised for any **browser process** exit (expected or unexpected, after all
  /// associated processes have exited too), while `ProcessFailed` is raised for
  /// **unexpected** process exits of any kind (browser, render, GPU, and all
  /// other types), or for main frame **render process** unresponsiveness. To
  /// learn more about the WebView2 Process Model, go to
  /// [Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).
  ///
  /// In the case the browser process crashes, both `BrowserProcessExited` and
  /// `ProcessFailed` events are raised, but the order is not guaranteed. These
  /// events are intended for different scenarios. It is up to the app to
  /// coordinate the handlers so they do not try to perform reliability recovery
  /// while also trying to move to a new WebView2 Runtime version or remove the
  /// user data folder.
  HRESULT add_BrowserProcessExited(
		  [in] ICoreWebView2BrowserProcessExitedEventHandler* eventHandler,
		  [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_BrowserProcessExited`.
  HRESULT remove_BrowserProcessExited([in] EventRegistrationToken token);
}

/// Receives `BrowserProcessExited` events.
interface ICoreWebView2BrowserProcessExitedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
		  [in] ICoreWebView2Environment* sender,
		  [in] ICoreWebView2BrowserProcessExitedEventArgs* args);
}

/// Event args for the `BrowserProcessExited` event.
interface ICoreWebView2BrowserProcessExitedEventArgs : IUnknown
{
  /// The kind of browser process exit that has occurred.
  [propget] HRESULT BrowserProcessExitKind(
      [out, retval] COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND* browserProcessExitKind);
  /// The process ID of the browser process that has exited.
  [propget] HRESULT BrowserProcessId([out, retval] UINT32* value);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    // ...

    /// Specifies the browser process exit kind used in
    /// `CoreWebView2BrowserProcessExitedEventArgs`.
    enum CoreWebView2BrowserProcessExitKind
    {
        /// Indicates that the browser process ended normally.
        Normal,
        /// Indicates that the browser process ended unexpectedly.
        /// A `CoreWebView2.ProcessFailed` event will also be raised to
        /// listening WebViews from the `CoreWebView2Environment` associated to
        /// the failed process.
        Failed
    };

    runtimeclass CoreWebView2Environment
    {
        // ...

        /// `BrowserProcessExited` is raised when the collection of WebView2
        /// Runtime processes associated to this `CoreWebView2Environment` terminate due to a
        /// browser process error or normal shutdown (for example, when all associated
        /// WebViews are closed), after all resources (including the user data folder)
        /// have been released.
        ///
        /// Multiple app processes can share a browser process by creating their webviews
        /// from a `CoreWebView2Environment` with the same user data folder. When the entire
        /// collection of WebView2Runtime processes for the browser process exit, all
        /// associated `CoreWebView2Environment` objects receive the `BrowserProcessExited`
        /// event. Multiple processes sharing the same browser process need to coordinate
        /// their use of the shared user data folder to avoid race conditions and
        /// unnecessary waits. For example, one process should not clear the user data
        /// folder at the same time that another process recovers from a crash by recreating
        /// its WebView controls; one process should not block waiting for the event if
        /// other app processes are using the same browser process (the browser process will
        /// not exit until those other processes have closed their webviews too).
        ///
        /// Note this is an event from `CoreWebView2Environment`, not `CoreWebView2`. The
        /// difference between `BrowserProcessExited` and `CoreWebView2`'s 
        /// `ProcessFailed` is that `BrowserProcessExited` is raised for any **browser process** exit
        /// (expected or unexpected, after all associated processes have exited too), while
        /// `ProcessFailed` is raised  for **unexpected** process exits of any kind (browser,
        /// render, GPU, and all other types), or for main frame **render process**
        /// unresponsiveness. To learn more about the WebView2
        /// Process Model, go to [Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).
        ///
        /// In the case the browser process crashes, both `BrowserProcessExited` and
        /// `ProcessFailed` events are raised, but the order is not guaranteed. These
        /// events are intended for different scenarios. It is up to the app to
        /// coordinate the handlers so they do not try to perform reliability recovery
        /// while also trying to move to a new WebView2 Runtime version or remove the
        /// user data folder.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, CoreWebView2BrowserProcessExitedEventArgs> BrowserProcessExited;
    }

    /// Event args for the `CoreWebView2Environment.BrowserProcessExited` event.
    runtimeclass CoreWebView2BrowserProcessExitedEventArgs
    {
        /// The kind of browser process exit that has occurred.
        CoreWebView2BrowserProcessExitKind BrowserProcessExitKind { get; };

        /// The process ID of the browser process that has exited.
        UInt32 BrowserProcessId { get; };
    }
}
```

# Appendix
We expect that for the two scenarios this API is designed for, namely cleanup of
the user data folder and upgrading the WebView2 Runtime, an app adding a
handler for `BrowserProcessExited` will only be interested in the next single
time the browser process exits (even if there could be more browser processes
being created and exiting throughout the lifetime of a
`CoreWebView2Environment`). For this reason, we also consider making this event
an async method instead (for example, `RegisterWaitForBrowserProcessExit`).

While there would be no operation started on calling the async method, a handler
would be a added to be run (only) the next time the browser process associated
to the `CoreWebView2Environment` exits, which in turn would make API usage
easier for the two expected scenarios.

Alternatively, this could be kept an event and the registered handlers be
automatically removed the next time the event is raised.
