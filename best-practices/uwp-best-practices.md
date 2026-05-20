# UWP Best Practices for WebView2

Guidance for hosting WebView2 inside Universal Windows Platform (UWP) apps.
Each entry uses the format:

- **Best practice** — what to do (with a code snippet).
- **Why?** — the problem this prevents.

---

## 1. Explicitly close the WebView2 controller on app shutdown

### Best practice

Call `Close()` on every `CoreWebView2Controller` you own before your UWP app
exits, and release your references afterwards.

```cpp
// C++/WinRT
void App::OnClosed()
{
    if (m_controller)
    {
        m_controller.Close();
        m_controller = nullptr;
        m_webview = nullptr;
    }
}
```

```csharp
// C#
private void OnClosed(object sender, WindowEventArgs e)
{
    if (_controller != null)
    {
        _controller.Close();
        _controller = null;
        _webView = null;
    }
}
```

### Why?

Without an explicit `Close()`, the WebView2 instance is torn down without
going through the normal browser shutdown procedure. As a result, state such
as cookies is not flushed correctly, which can lead to data loss or
inconsistent state on the next launch.

---

## 2. Handle external URI schemes via the OS launcher

### Best practice

Subscribe to `CoreWebView2.LaunchingExternalUriScheme`, cancel the default
launch, and forward the URI to `Windows.System.Launcher.LaunchUriAsync` so
that the OS performs the activation.

```csharp
// C#
_webView.CoreWebView2.LaunchingExternalUriScheme += async (s, e) =>
{
    e.Cancel = true;
    await Windows.System.Launcher.LaunchUriAsync(new Uri(e.Uri));
};
```

```cpp
// C++/WinRT
m_webview.LaunchingExternalUriScheme([](auto&&, auto const& args)
{
    args.Cancel(true);
    Windows::System::Launcher::LaunchUriAsync(Uri{ args.Uri() });
});
```

### Why?

WebView2 inside a UWP app does not automatically activate external protocol
handlers (for example `mailto:`, `tel:`, `ms-settings:`, store, or custom
`myapp:` schemes). Without this handler, clicks on such links silently do
nothing, which appears as a broken link to the user. `LaunchUriAsync` is the
supported UWP activation path, and `LaunchingExternalUriScheme` is the
purpose‑built event for this hand‑off — it fires only for external schemes,
so the app does not need to filter `http`/`https` navigations itself.
