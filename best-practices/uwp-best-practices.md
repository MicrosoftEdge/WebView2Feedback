# UWP Best Practices for WebView2

Guidance for hosting WebView2 inside Universal Windows Platform (UWP) apps.
Each entry uses the format:

- **Best practice** — what to do (with a code snippet).
- **Why?** — the problem this prevents.

---

## 1. Explicitly close the WebView2 controller on app shutdown

### Best practice

Call `Close()` on every `CoreWebView2Controller` you own from your UWP app's
suspend handler (for example `Application.Suspending`), and release your
references afterwards.

```cpp
// C++/WinRT — App.xaml.cpp
App::App()
{
    Suspending({ this, &App::OnSuspending });
}

void App::OnSuspending(IInspectable const&, SuspendingEventArgs const&)
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
// C# — App.xaml.cs
public App()
{
    this.Suspending += OnSuspending;
}

private void OnSuspending(object sender, SuspendingEventArgs e)
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
that the OS performs the activation. Gate the hand‑off on
`IsUserInitiated` and, where appropriate, an allow‑list of schemes and
initiating origins so that web content cannot silently activate other apps.

```csharp
// C#
private static readonly HashSet<string> AllowedSchemes =
    new(StringComparer.OrdinalIgnoreCase) { "mailto", "tel", "ms-settings" };

_webView.CoreWebView2.LaunchingExternalUriScheme += async (s, e) =>
{
    e.Cancel = true;

    if (!e.IsUserInitiated) return;
    if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri)) return;
    if (!AllowedSchemes.Contains(uri.Scheme)) return;

    try
    {
        await Windows.System.Launcher.LaunchUriAsync(uri);
    }
    catch
    {
        // Optional: surface a fallback UI to the user.
    }
};
```

```cpp
// C++/WinRT
m_webview.LaunchingExternalUriScheme([](auto&&, auto const& args)
{
    args.Cancel(true);

    if (!args.IsUserInitiated()) return;

    Uri uri{ nullptr };
    try { uri = Uri{ args.Uri() }; } catch (...) { return; }

    auto scheme = uri.SchemeName();
    if (scheme != L"mailto" && scheme != L"tel" && scheme != L"ms-settings")
        return;

    Windows::System::Launcher::LaunchUriAsync(uri);
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
