# Background
We have heard asks for a WebView2 API to easily track the WebView2 Runtime's
browser process exit. Manually waiting for the process to exit requires
additional work on the host app, so we are proposing the `BrowserProcessExited`
event. The `ProcessFailed` already lets app developers handle unexpected browser
process exits for a WebView, this new API lets you listen to both expected and
unexpected process termination from the `ICoreWebView2Environment3` interface so
you can, e.g., cleanup the user data folder when it's no longer in use. In this
document we describe the new API. We'd appreciate your feedback.


# Description
The `BrowserProcessExited` event allows developers to subscribe event handlers
to be run when the WebView2 Runtime's browser process associated to a
`CoreWebView2Environment` terminates. Key scenarios are cleanup of the use data
folder used by the WebView2 Runtime, which is locked while the runtime's
browser process is active, and moving to a new WebView2 Runtime version after
a `NewBrowserVersionAvailable` event.

This event is raised for both expected and unexpected browser process
termination, after all resources, including the user data folder, used by the
browser process (and related processes) have been released. The
`ICoreWebView2BrowserProcessExitedEventArgs` interface lets app developers get
the `BrowserProcessExitKind` so they can decide how to handle different exit
kinds or bypass handling if an event handler for the `CoreWebView2`s
`ProcessFailed` event (for `CoreWebView2ProcessFailedKind.BrowserProcessFailed`)
is already registered. In case of a browser process crash, both
`BrowserProcessExited` and `ProcessFailed` events are raised, but the order is
not guaranteed.

All `CoreWebView2Environment` objects across different app processes that use
the same browser process receive this event when the browser process exits.
If the browser process (and therefore the user data folder) in use by the app
process (through the `CoreWebView2Environment` options used) is shared with
other processes, these processes need to coordinate to handle the potential race
condition on the use of the resources. E.g., if one app process tries to clear
the user data folder, while other tries to recreate its WebViews on crash.


# Examples
The following code snippets demonstrate how the `BrowserProcessExited` event can
be used:

## Win32 C++
```cpp
// Before closing the WebView, register a handler with code to run once the
// browser process is terminated.
EventRegistrationToken browserExitedEventToken;

CHECK_FAILURE(m_webViewEnvironment->add_BrowserProcessExited(
    Callback<ICoreWebView2BrowserProcessExitedEventHandler>(
        [browserExitedEventToken, this](
            ICoreWebView2Environment* sender,
            ICoreWebView2BrowserProcessExitedEventArgs* args) {
        COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND kind;
        CHECK_FAILURE(args->get_BrowserProcessExitKind(&kind));

        // Watch for graceful browser process exit. Let ProcessFailed event
        // handler take care of failed browser process termination.
        if (kind == COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL)
        {
          CHECK_FAILURE(
              m_webViewEnvironment->remove_BrowserProcessExited(browserExitedEventToken));
          // Release the environment only after the handler is invoked.
          // Otherwise, there will be no environment to raise the event when
          // the process exits.
          m_webViewEnvironment = nullptr;
          CleanupUserDataFolder();
        }

        return S_OK;
    }).Get(),
    &browserExitedEventToken));
```

## .NET C#
```c#
// URI or other state to save/restore when the WebView is recreated.
private Uri _uriToRestore;

async void RegisterForNewVersion()
{
    // We need to make sure the CoreWebView2 property is not null, so we can get
    // the environment from it. Alternatively, if the WebView was created from
    // an environment provided to the control, we can use that environment
    // object directly.
    await webView.EnsureCoreWebView2Async();
    _coreWebView2Environment = webView.CoreWebView2.Environment;
    _coreWebView2Environment.NewBrowserVersionAvailable += Environment_NewBrowserVersionAvailable;
}

// A new version of the WebView2 Runtime is available, our handler gets called.
// We close our WebView and set a handler to reinitialize it once the browser
// process is gone, so we get the new version of the WebView2 Runtime.
void Environment_NewBrowserVersionAvailable(object sender, object e)
{
    StringBuilder messageBuilder = new StringBuilder(256);
    messageBuilder.Append("We detected there is a new version of the WebView2 Runtime installed. ");
    messageBuilder.Append("Do you want to switch to it now? This will re-create the WebView.");
    var selection = MessageBox.Show(this, messageBuilder.ToString(), "New WebView2 Runtime detected", MessageBoxButton.YesNo);
    if (selection == MessageBoxResult.Yes)
    {
        // Save URI or other state you want to restore when the WebView is recreated.
        _uriToRestore = webView.Source;
        _coreWebView2Environment.BrowserProcessExited += Environment_BrowserProcessExited;
        // We dispose of the control so the internal WebView objects are released
        // and the associated browser process exits. If there are any other WebViews
        // from the same environment configuration, they need to be closed too.
        webView.Dispose();
        webView = null;
    }
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
    webView.Source = (_uriToRestore != null) ? _uriToRestore : new Uri("https://www.bing.com");
    RegisterForNewVersion();
}
```


# Remarks
Note this is an event from the `ICoreWebView2Environment3` interface, not the
`ICoreWebView2`. The difference between this `BrowserProcessExited` event and
the `CoreWebView2`'s `ProcessFailed` event is that `BrowserProcessExited` is
raised for any (expected and unexpected) **browser process** exits, while
`ProcessFailed` is raised only for **unexpected** browser process exits, or for
**render process** exits/unresponsiveness. To learn more about the WebView2
Process Model, go to [Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).

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
  /// The `BrowserProcessExited` event is raised when the browser process of the
  /// WebView2 Runtime associated to this environment terminates due to an error
  /// or normal shutdown (e.g., when all its WebViews are closed), after all
  /// resources (including the user data folder) used by the browser process
  /// (and related processes) have been released.
  ///
  /// A handler added with this method is called until removed with
  /// `remove_BrowserProcessExited`, even if a new browser process is bound to
  /// this environment after earlier `BrowserProcessExited` events are raised.
  ///
  /// All `CoreWebView2Environment` objects across different app processes that use
  /// the same browser process receive this event when the browser process exits.
  /// If the browser process (and therefore the user data folder) in use by the app
  /// process (through the `CoreWebView2Environment` options used) is shared with
  /// other processes, these processes need to coordinate to handle the potential race
  /// condition on the use of the resources. E.g., if one app process tries to clear
  /// the user data folder, while other tries to recreate its WebViews on crash.
  ///
  /// Note this is an event from the `ICoreWebView2Environment3` interface, not the
  /// `ICoreWebView2`. The difference between this `BrowserProcessExited` event and
  /// the `CoreWebView2`'s `ProcessFailed` event is that `BrowserProcessExited` is
  /// raised for any (expected and unexpected) **browser process** exits, while
  /// `ProcessFailed` is raised only for **unexpected** browser process exits, or for
  /// **render process** exits/unresponsiveness. To learn more about the WebView2
  /// Process Model, go to [Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).
  ///
  /// In the case the browser process crashes, both `BrowserProcessExited` and
  /// `ProcessFailed` events are raised, but the order is not guaranteed.
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

        /// `BrowserProcessExited` is raised when the browser process of the
        /// WebView2 Runtime associated to this `CoreWebView2Environment`
        /// terminates due to an error or normal shutdown (e.g., when all its
        /// WebViews are closed), after all resources (including the user data
        /// folder) used by the browser process (and related processes) have
        /// been released.
        ///
        /// All `CoreWebView2Environment` objects across different app processes that use
        /// the same browser process receive this event when the browser process exits.
        /// If the browser process (and therefore the user data folder) in use by the app
        /// process (through the `CoreWebView2Environment` options used) is shared with
        /// other processes, these processes need to coordinate to handle the potential race
        /// condition on the use of the resources. E.g., if one app process tries to clear
        /// the user data folder, while other tries to recreate its WebViews on crash.
        ///
        /// Note this is an event from `CoreWebView2Environment`, not the
        /// `CoreWebView2`. The difference between this `BrowserProcessExited` event and
        /// the `CoreWebView2`'s `ProcessFailed` event is that `BrowserProcessExited` is
        /// raised for any (expected and unexpected) **browser process** exits, while
        /// `ProcessFailed` is raised only for **unexpected** browser process exits, or for
        /// **render process** exits/unresponsiveness. To learn more about the WebView2
        /// Process Model, go to [Process model](https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model).
        ///
        /// In the case the browser process crashes, both `BrowserProcessExited` and
        /// `ProcessFailed` events are raised, but the order is not guaranteed.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Environment, CoreWebView2BrowserProcessExitedEventArgs> BrowserProcessExited;
    }

    /// Event args for the `CoreWebView2Environment.BrowserProcessExited` event.
    runtimeclass CoreWebView2BrowserProcessExitedEventArgs
    {
        /// The kind of browser process exit that has occurred.
        CoreWebView2BrowserProcessExitKind BrowserProcessExitKind { get; };
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
an async method instead (e.g., `RegisterWaitForBrowserProcessExit`).

While there would be no operation started on calling the async method, a handler
would be a added to be run (only) the next time the browser process associated
to the `CoreWebView2Environment` exits, which in turn would make API usage
easier for the two expected scenarios.

Alternatively, this could be kept an event and the registered handlers be
automatically removed the next time the event is raised.
