# AreBrowserAcceleratorKeysEnabled

## Background
In general, WebView2 tries to behave as much like the browser as possible.
This includes allowing accelerator key access to features such as printing and
navigation.  However, in many apps these features are unnecessary or even
intrusive.  These accelerator keys can be disabled by handling the
`AcceleratorKeyPressed` event on `ICoreWebView2Controller`, but then the burden
is on the developer to correctly block the keys that trigger browser commands,
such as Ctrl-P, and not basic editing and movement keys such as Ctrl-C and the
arrow keys.  After that, if the underlying browser ever changes its set of
accelerator keys, apps may not be able to respond to those changes.

This illustrates the need for a single setting to disable all keyboard shortcuts
that correspond to browser-specific functionality, without disabling things like
copy and paste and movement.

In this document we describe the new setting. We'd appreciate your feedback.


## Description
When this setting is set to false, it disables all accelerator keys that access
features specific to the browser, including but not limited to:
- Ctrl-F and F3 for Find on Page
- Ctrl-P for Print
- Ctrl-R and F5 for Reload
- Ctrl-Plus and Ctrl-Minus for zooming
- Ctrl-Shift-C and F12 for DevTools
- Special keys for browser functions, such as Back, Forward, and Search

It does not disable accelerator keys related to movement and text editing, such
as:
- Home, End, Page Up, and Page Down
- Ctrl-X, Ctrl-C, Ctrl-V
- Ctrl-A for Select All
- Ctrl-Z for Undo

Those accelerator keys will always be enabled unless they are handled in the
`AcceleratorKeyPressed` event.

The default value for AreBrowserAcceleratorKeysEnabled is true.

## Examples
```c#
void ToggleBrowserKeysEnabled()
{
    var settings = _webView.CoreWebView2.Settings;
    settings.AreBrowserAcceleratorKeysEnabled = !settings.AreBrowserAcceleratorKeysEnabled;
}
```

```cpp
void SettingsComponent::ToggleBrowserKeysEnabled()
{
    BOOL enabled;
    CHECK_FAILURE(_coreWebView2Settings->get_AreBrowserAcceleratorKeysEnabled(&enabled));
    CHECK_FAILURE(_coreWebView2Settings->put_AreBrowserAcceleratorKeysEnabled(enabled ? FALSE : TRUE));
}
```


## Remarks
Some accelerator keys that don't make sense for WebViews are always disabled
regardless of this setting.  This includes things like opening and closing tabs,
viewing bookmarks and history, and selecting the location bar.

This setting will not prevent commands from being run through the context menu.
To disable the context menu, use `AreDefaultContextMenusEnabled`.


## API Details
```
[uuid(9aab8652-d89f-408d-8b2c-1ade3ab51d6d), object, pointer_default(unique)]
interface ICoreWebView2Settings2 : ICoreWebView2Settings {
    /// When this setting is set to false, it disables all accelerator keys
    /// that access features specific to the browser, including but not limited to:
    ///  - Ctrl-F and F3 for Find on Page
    ///  - Ctrl-P for Print
    ///  - Ctrl-R and F5 for Reload
    ///  - Ctrl-Plus and Ctrl-Minus for zooming
    ///  - Ctrl-Shift-C and F12 for DevTools
    ///  - Special keys for browser functions, such as Back, Forward, and Search
    ///
    /// It does not disable accelerator keys related to movement and text editing,
    /// such as:
    ///  - Home, End, Page Up, and Page Down
    ///  - Ctrl-X, Ctrl-C, Ctrl-V
    ///  - Ctrl-A for Select All
    ///  - Ctrl-Z for Undo
    ///
    /// Those accelerator keys will always be enabled unless they are handled in the
    /// `AcceleratorKeyPressed` event.
    /// The default value for AreBrowserAcceleratorKeysEnabled is true.
  [propget] HRESULT AreBrowserAcceleratorKeysEnabled(
      [out, retval] BOOL* areBrowserAcceleratorKeysEnabled);

  /// Sets the `AreBrowserAcceleratorKeysEnabled` property.
  [propput] HRESULT AreBrowserAcceleratorKeysEnabled(
      [in] BOOL areBrowserAcceleratorKeysEnabled);
}
```

```c#
runtimeclass ICoreWebViewSettings2 : ICoreWebView2Settings {
    Boolean AreBrowserAcceleratorKeysEnabled { get; set; }
}
```
