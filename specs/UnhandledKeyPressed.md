
# Background
Consumers of the old [WebBrowser](https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.webbrowser?view=windowsdesktop-7.0) control that relied on the [OnKeyDown](https://learn.microsoft.com/previous-versions/aa752133(v=vs.85)) API that allowed them to receive and handle key events not handled by the browser, [requested](https://github.com/MicrosoftEdge/WebViewFeedback/issues/468) same ability in WebView2. 

# Description
The `UnhandledKeyPressed` event allows developers to subscribe event handlers
to be run when a key event is not handled by the browser (including DOM and browser accelerators). It can be triggered by all keys, which is different from [AcceleratorKeyPressed](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2acceleratorkeypressedeventargs?view=webview2-dotnet-1.0.705.50) event.

`UnhandledKeyPressed` event is async, which means 'GetKeyStates' does not return the exact key state when the key event is fired. Use UnhandledKeyPressedEventArgs::GetKeyState()
instead to verify whether Ctrl or Alt is down in this situation.

# Examples

```cpp
  auto controller5 = m_controller.try_query<ICoreWebView2Controller5>();
  if (controller5)
  {
      CHECK_FAILURE(controller5->add_UnhandledKeyPressed(
          Callback<ICoreWebView2UnhandledKeyPressedEventHandler>(
              [this](
                  ICoreWebView2Controller* sender,
                  ICoreWebView2UnhandledKeyPressedEventArgs* args) -> HRESULT
              {
                  COREWEBVIEW2_KEY_EVENT_KIND kind;
                  CHECK_FAILURE(args->get_KeyEventKind(&kind));

                  // We only care about key down events.
                  if (kind == COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN ||
                      kind == COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN)
                  {
                      COREWEBVIEW2_KEY_PRESSED_FLAG_KIND flag;
                      CHECK_FAILURE(args->get_Modifiers(&flag));
                      if (flag & COREWEBVIEW2_KEY_EVENT_FLAG_CONTROL_DOWN)
                      {
                          UINT key;
                          CHECK_FAILURE(args->get_VirtualKey(&key));
                          // Check if the key is one we want to handle.
                          if (key == 'Z')
                          {
                              MessageBox(
                                  nullptr,
                                  L"Key combination Ctrl + Z unhandled by browser is "
                                  L"triggered.",
                                  L"", MB_OK);
                          }
                          else if (key >= 'A' && key <= 'Z')
                          {
                              OutputDebugString((std::wstring(L"Ctrl +") + (wchar_t)key +
                                                  L" not handled by browser is triggered.")
                                                    .c_str());
                          }
                      }
                  }
                  return S_OK;
              })
              .Get(),
          &m_unhandledKeyPressedToken));
  }
```

```csharp
private CoreWebView2Controller controller;
void RegisterKeyEventHandlers()
{
    // Disable external drop while navigating.
    if (controller != null)
    {
        controller.UnhandledKeyPressed += CoreWebView2Controller_UnhandledKeyPressed;
    }
}
void CoreWebView2Controller_UnhandledKeyPressed(object sender, CoreWebView2UnhandledKeyPressedEventArgs e)
{
  if (e.KeyEventKind == CoreWebView2KeyEventKind.KeyDown &&(e.Modifiers & CoreWebView2KeyEventFlagControlDown)){
    if (e.VirtualKey == 'z') {
      Debug.WriteLine($"Key combination Ctrl + Z unhandled by browser is triggered.");
    }
  }
}
```

# API Details
```idl
/// Flag bits representing the state of keyboard when a "UnhandledKeyPressed" Event happens.
[v1_enum]
typedef enum COREWEBVIEW2_KEY_PRESSED_FLAG_KIND {
    
  /// No additional keys pressed.
  COREWEBVIEW2_KEY_EVENT_FLAG_NONE = 0,

  /// SHIFT is down, VK_SHIFT.
  COREWEBVIEW2_KEY_EVENT_FLAG_SHIFT_DOWN = 1 << 1,

  /// Control is down, VK_CONTROL.
  COREWEBVIEW2_KEY_EVENT_FLAG_CONTROL_DOWN = 1 << 2,

  /// ALT is down, VK_MENU. 
  /// This bit is 0 when COREWEBVIEW2_KEY_EVENT_FLAG_ALTGR_DOWN bit is 1.
  COREWEBVIEW2_KEY_EVENT_FLAG_ALT_DOWN = 1 << 3,

  /// Windows key is down. VK_LWIN | VK_RWIN
  COREWEBVIEW2_KEY_EVENT_FLAG_COMMAND_DOWN = 1 << 4,

  /// Right ALT is down and AltGraph is enabled.
  COREWEBVIEW2_KEY_EVENT_FLAG_ALTGR_DOWN = 1 << 6,

  /// NUMLOCK is on. VK_NUMLOCK.
  COREWEBVIEW2_KEY_EVENT_FLAG_NUM_LOCK_ON = 1 << 8,

  /// CapsLock is on. VK_CAPITAL.
  COREWEBVIEW2_KEY_EVENT_FLAG_CAPS_LOCK_ON = 1 << 9,

  /// ScrollLock is On. VK_SCROLL.
  COREWEBVIEW2_KEY_EVENT_FLAG_SCROLL_LOCK_ON = 1 << 10,
} COREWEBVIEW2_KEY_PRESSED_FLAG_KIND;

[uuid(dd30e20c-d1b3-4e51-9bb6-1be7aaa3ce90), object, pointer_default(unique)]
interface ICoreWebView2UnhandledKeyPressedEventArgs : IUnknown {

  /// The key event type that caused the event to run.

  [propget] HRESULT KeyEventKind([out, retval] COREWEBVIEW2_KEY_EVENT_KIND* keyEventKind);

  /// The Win32 virtual key code of the key that was pressed or released.  It
  /// is one of the Win32 virtual key constants such as `VK_RETURN` or an
  /// (uppercase) ASCII value such as `A`.
  /// use ICoreWebView2UnhandledKeyPressedEventArgs::GetKeyState()
  /// instead of Win32 API ::GetKeyState() to verify whether Ctrl or Alt
  /// is pressed.

  [propget] HRESULT VirtualKey([out, retval] UINT* virtualKey);

  /// The `LPARAM` value that accompanied the window message.  For more
  /// information, navigate to [WM_KEYDOWN](/windows/win32/inputdev/wm-keydown)
  /// and [WM_KEYUP](/windows/win32/inputdev/wm-keyup).
  /// For visual hosting, only scan code and extended key (16-24bit) are provided.
  /// For other bits, check out the origin message from ::GetMessage().

  [propget] HRESULT KeyEventLParam([out, retval] INT* lParam);

  /// A structure representing the information passed in the `LPARAM` of the
  /// window message.

  [propget] HRESULT PhysicalKeyStatus(
      [out, retval] COREWEBVIEW2_PHYSICAL_KEY_STATUS* physicalKeyStatus);

  /// The `Handled` property will not influence the future WebView
  /// action. It can be used with other UnhandledKeyPressed
  /// Event handlers.

  [propget] HRESULT Handled([out, retval] BOOL* handled);

  /// Sets the `Handled` property.

  [propput] HRESULT Handled([in] BOOL handled);

  /// Retrieves the status of the keyboard when the key event is triggered.
  /// Use this instead of ::GetKeyState().
  /// See COREWEBVIEW2_KEY_PRESSED_FLAG_KIND for details.
  [propget] HRESULT Modifiers([out, retval] COREWEBVIEW2_KEY_PRESSED_FLAG_KIND* modifiers);
}

/// Receives `KeyPressed` events.

[uuid(dc83113b-ce7a-47bb-9661-16b03ff8aac1), object, pointer_default(unique)]
interface ICoreWebView2UnhandledKeyPressedEventHandler : IUnknown {

  /// Provides the event args for the corresponding event.

  HRESULT Invoke(
      [in] ICoreWebView2Controller* sender,
      [in] ICoreWebView2UnhandledKeyPressedEventArgs* args);
}

[uuid(053b9a5d-7033-4515-9898-912977d2fde8), object, pointer_default(unique)]
interface ICoreWebView2Controller : IUnknown {
  /// Adds an event handler for the `UnhandledKeyPressed` event.
  /// `UnhandledKeyPressed` runs when an key is not handled in
  /// the DOM.

  HRESULT add_UnhandledKeyPressed(
    [in] ICoreWebView2UnhandledKeyPressedEventHandler* eventHandler,
    [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with
  /// `add_UnhandledKeyPressed`.

  HRESULT remove_UnhandledKeyPressed(
    [in] EventRegistrationToken token);
}
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    public class CoreWebView2Controller
    {
        event EventHandler<CoreWebView2UnhandledKeyPressedEventArgs> UnhandledKeyPressed;
    }

    [Flags] enum CoreWebView2KeyPressedFlagKind
    {
        CoreWebView2KeyEventFlagNone = 0,
        CoreWebView2KeyEventFlagShiftDown = 2,
        CoreWebView2KeyEventFlagControlDown = 4,
        CoreWebView2KeyEventFlagAltDown = 8,
        CoreWebView2KeyEventFlagCommandDown = 16,
        CoreWebView2KeyEventFlagAltgrDown = 64,
        CoreWebView2KeyEventFlagNumLockOn = 256,
        CoreWebView2KeyEventFlagCapsLockOn = 512,
        CoreWebView2KeyEventFlagScrollLockOn = 1024,
    }

    /// Event args for the `CoreWebView2Controller.UnhandledKeyPressed` event.
    runtimeclass CoreWebView2UnhandledKeyPressedEventArgs
    {
        CoreWebView2KeyEventKind KeyEventKind { get; };

        uint VirtualKey { get; };

        int KeyEventLParam { get; };
        
        CoreWebView2PhysicalKeyStatus PhysicalKeyStatus { get; };
        
        bool Handled { get; set; };

        CoreWebView2KeyPressedFlagKind Modifiers { get; };
    }
}
```
