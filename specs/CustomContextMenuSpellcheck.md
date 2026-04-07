Custom Context Menu SpellCheck
===

# Background

When a host application renders a custom context menu via the `ContextMenuRequested` event, spellcheck
suggestions for misspelled words are not available. The browser's built-in spellcheck pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

This feature adds spellcheck support to custom context menus. Because spellcheck suggestions arrive
asynchronously (after the `ContextMenuRequested` event fires), the feature introduces a deferred
capability discovery pattern on `ICoreWebView2ContextMenuRequestedEventArgs2` that allows the host to
detect and acquire async capabilities at event time. SpellCheck is the first capability delivered
through this pattern; the same extensible mechanism will support future capabilities (emoji panel,
voice typing, etc.) without requiring additional EventArgs versions.

# Description

The `ContextMenuRequested` event is extended with `ICoreWebView2ContextMenuRequestedEventArgs2`.
This new interface provides:

- **`DeferredCapabilities`** — A flags bitmask indicating which async capabilities are available for
  this specific context menu invocation. For spellcheck, the host checks the `SPELL_CHECK` flag.
- **`GetDeferredCapability(REFIID, void**)`** — An IID-based accessor to acquire the capability
  interface. For spellcheck, the host passes `IID_ICoreWebView2ContextMenuSpellCheck`.

**Runtime version detection:** If `QueryInterface` for `EventArgs2` returns `E_NOINTERFACE`, the host
is running on an older runtime that doesn't support this feature.

The spellcheck capability interface (`ICoreWebView2ContextMenuSpellCheck`) provides:

- **`MisspelledWord`** — Read-only property returning the misspelled word under the cursor. Useful for
  displaying "Suggestions for 'teh':" headers in custom menus.
- **`GetSpellCheckSuggestionsAsync`** — Retrieves suggestions as `ICoreWebView2ContextMenuItem` objects.
  Each suggestion has a `Label` (display text) and `CommandId` (opaque identifier).

**Commanding model:** The host applies a suggestion by passing its `CommandId` to
`put_SelectedCommandId` on the EventArgs — the same execution path used for Cut, Copy, Paste, and
all other context menu items. No separate execution method is needed.

**Async contract:** The handler fires exactly once, always asynchronously (posted to the caller's
message loop, never invoked inline). Only one handler may be registered; a second call returns
`E_ILLEGAL_METHOD_CALL`.

**Availability:** If the `SPELL_CHECK` flag is not set in `DeferredCapabilities`, spellcheck is not
applicable (non-editable field, correctly-spelled word, or spellcheck disabled by policy).

# Examples

## Win32 C++

```cpp
// Inside ContextMenuRequested handler for an editable field:

// ── Step 1: Runtime version check ──
auto args2 = wil::try_com_query<
    ICoreWebView2ContextMenuRequestedEventArgs2>(args);
if (!args2)
    return S_OK;  // Old runtime — use default menu.

// ── Step 2: Discover deferred capabilities ──
COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES caps =
    COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_NONE;
CHECK_FAILURE(args2->get_DeferredCapabilities(&caps));

if (!(caps & COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_SPELL_CHECK))
    return S_OK;  // No misspelling — use default menu.

// ── Step 3: Acquire spellcheck interface ──
wil::com_ptr<ICoreWebView2ContextMenuSpellCheck> spellCheck;
CHECK_FAILURE(args2->GetDeferredCapability(IID_PPV_ARGS(&spellCheck)));

// ── Step 4: Take over menu rendering (only after confirming spellcheck) ──
CHECK_FAILURE(args->put_Handled(TRUE));
wil::com_ptr<ICoreWebView2Deferral> deferral;
CHECK_FAILURE(args->GetDeferral(&deferral));

// ── Step 5: Read misspelled word (synchronous) ──
wil::unique_cotaskmem_string misspelledWord;
spellCheck->get_MisspelledWord(&misspelledWord);

// ── Step 6: Get suggestions and build menu in the callback ──
// Build the menu inside the callback so all items are present before display.
wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
args->get_MenuItems(&items);

m_appWindow->RunAsync(
    [this, args, spellCheck, items, deferral,
     word = std::wstring(misspelledWord.get())]()
    {
        spellCheck->GetSpellCheckSuggestionsAsync(
            Callback<ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
                [this, args, items, deferral, word](
                    HRESULT errorCode,
                    ICoreWebView2ContextMenuItemCollection* suggestions) -> HRESULT
                {
                    HMENU hMenu = CreatePopupMenu();

                    // Add spellcheck suggestions at the top.
                    UINT32 sugCount = 0;
                    if (SUCCEEDED(errorCode) && suggestions)
                        suggestions->get_Count(&sugCount);

                    if (sugCount > 0)
                    {
                        AppendMenu(hMenu, MF_GRAYED | MF_STRING, 0,
                                   (L"Suggestions for '" + word + L"':").c_str());
                        for (UINT32 i = 0; i < sugCount; i++)
                        {
                            wil::com_ptr<ICoreWebView2ContextMenuItem> item;
                            suggestions->GetValueAtIndex(i, &item);
                            wil::unique_cotaskmem_string label;
                            item->get_Label(&label);
                            INT32 cmdId;
                            item->get_CommandId(&cmdId);
                            AppendMenu(hMenu, MF_STRING, cmdId, label.get());
                        }
                        AppendMenu(hMenu, MF_SEPARATOR, 0, nullptr);
                    }

                    // Add standard items (skip default spellcheck items by name).
                    AddMenuItems(hMenu, items.get());  // Your helper function

                    // Show popup and get user selection.
                    INT32 selectedCmd = ShowPopupAtCursor(hMenu, args);

                    // ── Unified commanding ──
                    // Works for spellcheck suggestions AND standard items alike.
                    if (selectedCmd > 0)
                        args->put_SelectedCommandId(selectedCmd);

                    DestroyMenu(hMenu);
                    deferral->Complete();
                    return S_OK;
                }).Get());
    });
return S_OK;
```

## .NET / C#

```csharp
webView.CoreWebView2.ContextMenuRequested += async (sender, args) =>
{
    // Step 1: Discover deferred capabilities.
    var caps = args.DeferredCapabilities;
    if (!caps.HasFlag(CoreWebView2ContextMenuDeferredCapabilities.SpellCheck))
        return;  // No misspelling — let default menu show.

    // Step 2: Take over menu rendering and hold deferral.
    args.Handled = true;
    var deferral = args.GetDeferral();

    // Step 3: Acquire spellcheck capability.
    var spellCheck = args.GetDeferredCapability<CoreWebView2ContextMenuSpellCheck>();

    // Step 4: Read misspelled word.
    string misspelledWord = spellCheck.MisspelledWord;  // e.g., "teh"

    // Step 5: Get suggestions.
    var suggestions = await spellCheck.GetSpellCheckSuggestionsAsync();

    // Step 6: Build custom menu.
    var contextMenu = new ContextMenuStrip();
    bool completed = false;

    contextMenu.Items.Add(new ToolStripMenuItem(
        $"Suggestions for '{misspelledWord}':") { Enabled = false });

    foreach (var suggestion in suggestions)
    {
        var item = new ToolStripMenuItem(suggestion.Label);
        var capturedId = suggestion.CommandId;
        item.Click += (_, _) =>
        {
            // Unified commanding — same as Cut, Copy, Paste.
            args.SelectedCommandId = capturedId;
        };
        contextMenu.Items.Add(item);
    }

    // Add standard items from args.MenuItems...

    // Complete deferral once on menu close (covers both selection and dismissal).
    contextMenu.Closed += (_, _) =>
    {
        if (!completed)
        {
            completed = true;
            deferral.Complete();
        }
    };
    contextMenu.Show(webView, new Point(args.Location.X, args.Location.Y));
};
```

## Future Capabilities (Extensibility Pattern)

When additional capabilities are added in the future, the same discovery pattern applies, no new
EventArgs versions are needed:

```cpp
COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES caps;
args2->get_DeferredCapabilities(&caps);

if (caps & COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_SPELL_CHECK)
{
    wil::com_ptr<ICoreWebView2ContextMenuSpellCheck> spellCheck;
    args2->GetDeferredCapability(IID_PPV_ARGS(&spellCheck));
    // ... use spellCheck ...
}

// Future: no new EventArgs versions needed, just new flag constants.
// if (caps & COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_EMOJI)
// {
//     wil::com_ptr<ICoreWebView2ContextMenuEmoji> emoji;
//     args2->GetDeferredCapability(IID_PPV_ARGS(&emoji));
//     // ... same pattern ...
// }
```

# API Details

## Win32 C++

```idl
// ─── EventArgs2: Deferred Capability Discovery (introduced for SpellCheck) ───

/// Flags indicating which deferred capabilities are available for a given
/// context menu invocation. Treat as a bitmask — test individual flags
/// with bitwise AND.
[v1_enum]
typedef enum COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES {
  /// No deferred capabilities are available.
  COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_NONE = 0x0,
  /// Spellcheck is available — the target is an editable field with a
  /// misspelled word and spellcheck is enabled.
  COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_SPELL_CHECK = 0x1,
  // Future capabilities add new flag constants here. No interface changes.
  // COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_EMOJI = 0x2,
  // COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_VOICE_TYPING = 0x4,
} COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES;

/// Extends `ICoreWebView2ContextMenuRequestedEventArgs` with deferred capability
/// discovery and acquisition. Introduced as part of the SpellCheck feature, this
/// extensible pattern supports all current and future deferred capabilities —
/// new capabilities add a flag constant and an interface definition, not new
/// EventArgs versions.
///
/// The host checks `DeferredCapabilities` flags to discover what async
/// capabilities exist for this invocation, then calls `GetDeferredCapability`
/// with the desired interface IID to acquire it.
[uuid(f1b2c3d4-5e6f-7a8b-9c0d-e1f2a3b4c5d6), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuRequestedEventArgs2
    : ICoreWebView2ContextMenuRequestedEventArgs {

  /// Returns a bitmask of deferred capabilities available for this context
  /// menu invocation. The host checks individual flags to determine which
  /// capability interfaces can be acquired via `GetDeferredCapability`.
  ///
  /// A flag being set means the corresponding capability is applicable AND
  /// enabled for this invocation. Flags not set means either the capability
  /// is not applicable (e.g., no misspelling) or the capability is disabled
  /// (e.g., spellcheck off by policy).
  [propget] HRESULT DeferredCapabilities(
      [out, retval] COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES* value);

  /// Retrieves the capability-specific interface for a deferred capability.
  ///
  /// Pass the IID of the desired capability interface. Returns `S_OK` and
  /// the interface pointer if the capability is available. Returns
  /// `E_NOINTERFACE` if the capability is not applicable for this invocation.
  ///
  /// Supported IIDs:
  ///   `IID_ICoreWebView2ContextMenuSpellCheck`
  ///   (future: emoji, voice typing, writing direction, etc.)
  ///
  /// The returned interface is valid for the lifetime of the event
  /// (until the deferral is completed).
  HRESULT GetDeferredCapability(
      [in] REFIID riid,
      [out, iid_is(riid), retval] void** capability);
}

// ─── SpellCheck Capability ───

/// Receives the result of `GetSpellCheckSuggestionsAsync`.
/// The handler is invoked exactly once, always asynchronously (posted to the
/// caller's message loop, never invoked inline during the call to
/// `GetSpellCheckSuggestionsAsync`).
[uuid(c5d6e7f8-9a0b-1c2d-3e4f-5a6b7c8d9e0f), object, pointer_default(unique)]
interface ICoreWebView2GetSpellCheckSuggestionsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  /// Each item in the `suggestions` collection is an
  /// `ICoreWebView2ContextMenuItem` whose `Label` is the suggestion text
  /// and whose `CommandId` uniquely identifies it. To apply a suggestion,
  /// pass the selected item's `CommandId` to
  /// `ICoreWebView2ContextMenuRequestedEventArgs.put_SelectedCommandId`.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2ContextMenuItemCollection* suggestions);
}

/// Provides spellcheck capabilities for custom context menus. Acquired via
/// `ICoreWebView2ContextMenuRequestedEventArgs2::GetDeferredCapability`
/// when the `SPELL_CHECK` flag is set in `DeferredCapabilities`.
///
/// To apply a suggestion, retrieve the `CommandId` from the desired
/// `ICoreWebView2ContextMenuItem` in the suggestions collection and pass it
/// to `ICoreWebView2ContextMenuRequestedEventArgs.put_SelectedCommandId`.
/// This follows the same commanding model used for all other context menu
/// items (Cut, Copy, Paste, etc.).
[uuid(e4a8f3b2-6c1d-4e9a-b5f7-2d8c9a0e1b34), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuSpellCheck : IUnknown {
  /// Gets the misspelled word at the current context menu target location.
  /// This is the word that spellcheck flagged as incorrect and for which
  /// suggestions are available via `GetSpellCheckSuggestionsAsync`.
  /// The caller must free the returned string using `CoTaskMemFree`.
  ///
  /// Use this to display contextual headers like "Suggestions for 'teh':"
  /// in your custom context menu.
  [propget] HRESULT MisspelledWord([out, retval] LPWSTR* value);

  /// Asynchronously retrieves spellcheck suggestions for the misspelled word
  /// at the current context menu target. The `handler` is invoked exactly once
  /// when suggestions become available, always asynchronously (posted to the
  /// caller's message loop, never invoked inline during this call).
  ///
  /// The handler receives `S_OK` and a collection of
  /// `ICoreWebView2ContextMenuItem` objects on success, or an error HRESULT
  /// and `nullptr` on failure. Each item's `Label` is the suggestion text
  /// and its `CommandId` can be passed to `put_SelectedCommandId` to apply
  /// the correction.
  ///
  /// Only one handler may be registered per event invocation. A second call
  /// returns `E_ILLEGAL_METHOD_CALL`.
  HRESULT GetSpellCheckSuggestionsAsync(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}
```

## .NET / WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    [Flags]
    enum CoreWebView2ContextMenuDeferredCapabilities
    {
        None       = 0x0,
        SpellCheck = 0x1,
        // Future: Emoji = 0x2, VoiceTyping = 0x4, ...
    }

    // Extended event args — includes deferred capability discovery for spellcheck.
    runtimeclass CoreWebView2ContextMenuRequestedEventArgs2
        : CoreWebView2ContextMenuRequestedEventArgs
    {
        CoreWebView2ContextMenuDeferredCapabilities DeferredCapabilities { get; };

        // Generic accessor — returns null if capability is not applicable.
        T GetDeferredCapability<T>();
    }

    runtimeclass CoreWebView2ContextMenuSpellCheck
    {
        // The misspelled word under the cursor.
        String MisspelledWord { get; };

        // Returns suggestions as ContextMenuItem objects.
        // Apply via args.SelectedCommandId = suggestion.CommandId.
        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ContextMenuItem>>
            GetSpellCheckSuggestionsAsync();
    }
}
```

# Behavioral Details

## Discovery and Acquisition Flow

| Step | Action | Result |
|------|--------|--------|
| 1 | QI for `EventArgs2` from EventArgs | `E_NOINTERFACE` → old runtime, fall back to default menu |
| 2 | Read `DeferredCapabilities` flags | Bitmask of available capabilities for this invocation |
| 3 | Check `SPELL_CHECK` flag | Flag set → misspelling present; flag not set → no misspelling |
| 4 | Call `GetDeferredCapability(IID_SpellCheck)` | Returns spellcheck interface with `AddRef` |

## Suggestion Item Properties

Each `ICoreWebView2ContextMenuItem` returned by `GetSpellCheckSuggestionsAsync` has:

| Property | Value |
|----------|-------|
| `Label` | Suggestion text (e.g., "the") |
| `CommandId` | WebView2-allocated opaque ID (e.g., 50001) |
| `Name` | `"spellcheck"` |
| `Kind` | `COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND` |
| `IsEnabled` | `TRUE` |
| `IsChecked` | `FALSE` |
| `Icon` | `nullptr` |
| `ShortcutKeyDescription` | `L""` |
| `Children` | `nullptr` |

## Error Handling

| Scenario | Behavior |
|----------|----------|
| QI for EventArgs2 fails | Old runtime — use default menu |
| `SPELL_CHECK` flag not set | No misspelling — skip spellcheck UI |
| `GetDeferredCapability` returns `E_NOINTERFACE` | Capability not available (consistent with flags) |
| `MisspelledWord` returns empty string | Spellcheck applicable but word is empty — defensive check recommended |
| Second call to `GetSpellCheckSuggestionsAsync` | Returns `E_ILLEGAL_METHOD_CALL` |
| Suggestions handler — no suggestions available | `count == 0` — show "No suggestions" or skip |
| User dismisses menu without selecting | Set `SelectedCommandId` to 0 or simply complete the deferral |

# Appendix

## Extensibility

The deferred capability pattern introduced by this feature is designed for zero-versioning extension:

| To add a new capability | Required changes |
|------------------------|-----------------|
| New flag constant | for example - `COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_EMOJI = 0x2` |
| New capability interface | `ICoreWebView2ContextMenuEmoji : IUnknown { ... }` |

## Relationship to Existing APIs

| Existing API | This Feature |
|-------------|-------------|
| `EventArgs.MenuItems` | Synchronous snapshot of menu items | 
| `EventArgs.SelectedCommandId` | Execution path — now also used for spellcheck suggestions |
| `ContextMenuItem.CommandId` | Already used for all items — spellcheck items join this pool |
| `ContextMenuItem.Label` | Display text — spellcheck suggestions use this for the suggestion word |
| `EventArgs.GetDeferral()` | Must be held across the async `GetSpellCheckSuggestionsAsync` gap |
