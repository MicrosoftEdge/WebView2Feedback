# Background
We have heard asks for a WebView2 API to easily track the `WebView2 Runtime`'s
browser process exit. Manually waiting for the process to exit requires
additional work on the host app, so we are proposing the `BrowserProcessExited`
event. The `ProcessFailed` already lets app developers handle unexpected browser
process exits for a WebView, this new API lets you listen to both expected and
unexpected process termination from the `ICoreWebView2Environment` interface so
you can, e.g., cleanup the user data folder when it's no longer in use. In this
document we describe the new API. We'd appreciate your feedback.


# Description
The `BrowserProcessExited` event allows developers to subscribe event handlers
to be run when the `WebView2 Runtime`'s browser process associated to a
`CoreWebView2Environment` terminates. A key scenario is cleanup of the use data
folder used by the `WebView2 Runtime`, which is locked while the runtime's
browser process is active.

This event is raised for both expected and unexpected browser process
termination. The `ICoreWebView2BrowserProcessExitedEventArgs` interfaces lets
app developers get the `BrowserProcessExitKind` so they can decide how to handle
different exit kinds or bypass handling if an event handler for the
`CoreWebView2`s `ProcessFailed` event (for
`CoreWebView2ProcessFailedKind.BrowserProcessFailed`) is already registered.


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
        if (kind == COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL_EXIT)
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
// Get the environment from the CoreWebView2 and add a handler.
webView.CoreWebView2.Environment.BrowserProcessExited += Environment_BrowserProcessExited;

// Check and report browser process exit kind.
void Environment_BrowserProcessExited(object sender, CoreWebView2BrowserProcessExitedEventArgs e)
{
    var exitKind = (e.BrowserProcessExitKind == CoreWebView2BrowserProcessExitKind.NormalExit) ? "normally" : "unexpectedly";
    MessageBox.Show(this, $"The browser process has exited {exitKind}.", "Browser Process Exited");
}
```


# Remarks
Note this is an event from the `ICoreWebView2Environment` interface, not the
`ICoreWebView2`. The difference between this `BrowserProcessExited` event and
the `CoreWebView2`'s `ProcessFailed` event is that `BrowserProcessExited` is
raised for any (expected and unexpected) **browser process** exits, while
`ProcessFailed` is raised only for **unexpected** browser process exits, or for
**render process** exits/unresponsiveness. To learn more about the WebView2
Process Model, go to (Process model)[https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model].


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details

## COM
```cpp
library WebView2
{
// ...

/// Specifies the browser process exit type used in the
/// `ICoreWebView2StagingBrowserProcessExitedEventArgs` interface.
typedef enum COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND {
  /// Indicates that the browser process ended normally.
  COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL_EXIT,

  /// Indicates that the browser process ended unexpectedly.
  /// A `ProcessFailed` event will also be sent to listening WebViews from the
  /// `ICoreWebView2Environment` associated to the failed process.
  COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_FAILED_EXIT
} COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND;

interface ICoreWebView2Environment : IUnknown
{
  // ...

  /// Add an event handler for the `BrowserProcessExited` event.
  /// The `BrowserProcessExited` event is raised when the browser process of the
  /// WebView2 Runtime associated to this environment terminates due to an error
  /// or normal shutdown (e.g., when all its WebViews are closed).
  ///
  /// A handler added with this method is called until removed with
  /// `remove_BrowserProcessExited`, even if a new browser process is bound to
  /// this environment after earlier `BrowserProcessExited` events are raised.
  HRESULT add_BrowserProcessExited(
		  [in] ICoreWebView2StagingBrowserProcessExitedEventHandler* eventHandler,
		  [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_BrowserProcessExited`.
  HRESULT remove_BrowserProcessExited([in] EventRegistrationToken token);
}

/// Receives `BrowserProcessExited` events.
interface ICoreWebView2StagingBrowserProcessExitedEventHandler : IUnknown
{
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
		  [in] ICoreWebView2Environment* sender,
		  [in] ICoreWebView2StagingBrowserProcessExitedEventArgs* args);
}

/// Event args for the `BrowserProcessExited` event.
interface ICoreWebView2StagingBrowserProcessExitedEventArgs : IUnknown
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
        NormalExit,
        /// Indicates that the browser process ended unexpectedly.
        /// A `CoreWebView2.ProcessFailed` event will also be raised to
        /// listening WebViews from the `CoreWebView2Environment` associated to
        /// the failed process.
        FailedExit
    };

    runtimeclass CoreWebView2Environment
    {
        // ...

        /// `BrowserProcessExited` is raised when the browser process of the
        /// `WebView2 Runtime` associated to this `CoreWebView2Environment`
        /// terminates due to an error or normal shutdown (e.g., when all its
        /// WebViews are closed).
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
