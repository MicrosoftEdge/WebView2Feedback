Spellcheck Support for Custom Context Menus
===

# Background

When a host application renders a custom context menu via the `ContextMenuRequested` event, spellcheck
suggestions for misspelled words are not available. The browser's built-in spellcheck pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

This feature adds spellcheck support to custom context menus. Because spellcheck suggestions arrive
asynchronously (after the `ContextMenuRequested` event fires), the feature introduces a deferred
capability discovery pattern on `ICoreWebView2ContextMenuRequestedEventArgs2` that allows the host to
detect and acquire async capabilities at event time.

# Description

The `ContextMenuRequested` event is extended with `ICoreWebView2ContextMenuRequestedEventArgs2`.
This new interface provides:

- **`DeferredCapabilities`** — A flags bitmask indicating which async capabilities are available for
  this specific context menu invocation. For spellcheck, the host checks the `SPELL_CHECK` flag.
- **`GetDeferredCapability(REFIID, void**)`** — An IID-based accessor to acquire the capability
  interface. For spellcheck, the host passes `IID_ICoreWebView2ContextMenuSpellCheck`.

**Runtime version detection:** If `QueryInterface` for `EventArgs2` returns `E_NOINTERFACE`, the host
is running on an older runtime that does not support this feature.

The spellcheck capability interface (`ICoreWebView2ContextMenuSpellCheck`) provides:

- **`MisspelledWord`** — Read-only property returning the misspelled word under the cursor. Useful for
  displaying "Suggestions for 'teh':" headers in custom menus.
- **`GetSpellCheckSuggestions`** — Retrieves suggestions as `ICoreWebView2ContextMenuItem` objects.
  Each suggestion has a `Label` (display text) and `CommandId` (opaque identifier).

**Commanding model:** The host applies a suggestion by passing its `CommandId` to
`put_SelectedCommandId` on the EventArgs — the same execution path used for Cut, Copy, Paste, and
all other context menu items. No separate execution method is needed.

**Async contract:** This is a standard async method. The handler is invoked exactly once when
suggestions are available, always asynchronously (posted to the caller's message loop, never
invoked inline).

**Availability:** If the `SPELL_CHECK` flag is not set in `DeferredCapabilities`, spellcheck is not
applicable (non-editable field, correctly-spelled word, or spellcheck disabled by policy).

# Examples

## Win32 C++ — Display Custom Context Menu with Spellcheck Suggestions

```cpp
webView->add_ContextMenuRequested(
    Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ContextMenuRequestedEventArgs* args) -> HRESULT
        {
            // ── Step 1: Runtime version check ──
            auto args2 = wil::try_com_query<
                ICoreWebView2ContextMenuRequestedEventArgs2>(args);
            if (!args2)
                return S_OK; // Old runtime — use default menu.

            // ── Step 2: Discover deferred capabilities ──
            COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES caps =
                COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_NONE;
            CHECK_FAILURE(args2->get_DeferredCapabilities(&caps));

            if (!(caps &
                  COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_SPELL_CHECK))
                return S_OK; // No misspelling — use default menu.

            // ── Step 3: Acquire spellcheck interface ──
            wil::com_ptr<ICoreWebView2ContextMenuSpellCheck> spellCheck;
            CHECK_FAILURE(
                args2->GetDeferredCapability(IID_PPV_ARGS(&spellCheck)));

            // ── Step 4: Take over rendering (only after confirming spellcheck) ──
            CHECK_FAILURE(args->put_Handled(TRUE));
            wil::com_ptr<ICoreWebView2Deferral> deferral;
            CHECK_FAILURE(args->GetDeferral(&deferral));

            // ── Step 5: Read misspelled word (synchronous) ──
            wil::unique_cotaskmem_string misspelledWord;
            CHECK_FAILURE(spellCheck->get_MisspelledWord(&misspelledWord));

            // ── Step 6: Get suggestions and build menu in the callback ──
            wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
            CHECK_FAILURE(args->get_MenuItems(&items));

            m_appWindow->RunAsync(
                [this, args, spellCheck, items, deferral,
                 word = std::wstring(misspelledWord.get())]()
                {
                    spellCheck->GetSpellCheckSuggestions(
                        Callback<
                            ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
                            [this, args, items, deferral, word](
                                HRESULT errorCode,
                                ICoreWebView2ContextMenuItemCollection*
                                    suggestions) -> HRESULT
                            {
                                HMENU hMenu = CreatePopupMenu();

                                // Add spellcheck suggestions at the top.
                                UINT32 sugCount = 0;
                                if (SUCCEEDED(errorCode) && suggestions)
                                    suggestions->get_Count(&sugCount);

                                if (sugCount > 0)
                                {
                                    AppendMenuW(
                                        hMenu, MF_GRAYED | MF_STRING, 0,
                                        (L"Suggestions for '" + word + L"':")
                                            .c_str());
                                    for (UINT32 i = 0; i < sugCount; i++)
                                    {
                                        wil::com_ptr<
                                            ICoreWebView2ContextMenuItem>
                                            item;
                                        suggestions->GetValueAtIndex(i, &item);
                                        wil::unique_cotaskmem_string label;
                                        item->get_Label(&label);
                                        INT32 cmdId;
                                        item->get_CommandId(&cmdId);
                                        AppendMenuW(
                                            hMenu, MF_STRING, cmdId,
                                            label.get());
                                    }
                                    AppendMenuW(
                                        hMenu, MF_SEPARATOR, 0, nullptr);
                                }

                                // Add remaining standard context menu items.
                                // The MenuItems collection contains built-in
                                // spellcheck items (Name = "spellcheck") that
                                // duplicate the suggestions from
                                // GetSpellCheckSuggestions — filter them out
                                // to avoid showing duplicate entries.
                                UINT32 itemCount = 0;
                                items->get_Count(&itemCount);
                                for (UINT32 i = 0; i < itemCount; i++)
                                {
                                    wil::com_ptr<ICoreWebView2ContextMenuItem>
                                        cur;
                                    items->GetValueAtIndex(i, &cur);
                                    wil::unique_cotaskmem_string name;
                                    cur->get_Name(&name);
                                    // Filter out built-in spellcheck items
                                    // (Name = "spellcheck") — we render our
                                    // own from GetSpellCheckSuggestions above.
                                    if (wcsstr(name.get(), L"spellCheck"))
                                        continue;
                                    COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind;
                                    cur->get_Kind(&kind);
                                    if (kind ==
                                        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR)
                                    {
                                        AppendMenuW(
                                            hMenu, MF_SEPARATOR, 0, nullptr);
                                    }
                                    else
                                    {
                                        wil::unique_cotaskmem_string label;
                                        cur->get_Label(&label);
                                        INT32 cmdId;
                                        cur->get_CommandId(&cmdId);
                                        BOOL enabled = FALSE;
                                        cur->get_IsEnabled(&enabled);
                                        AppendMenuW(
                                            hMenu,
                                            MF_STRING |
                                                (enabled ? 0 : MF_GRAYED),
                                            cmdId, label.get());
                                    }
                                }

                                // Show popup at the context menu location.
                                HWND hWnd = m_appWindow->GetMainWindow();
                                POINT pt;
                                wil::com_ptr<ICoreWebView2ContextMenuTarget>
                                    target;
                                args->get_ContextMenuTarget(&target);
                                POINT location;
                                args->get_Location(&location);
                                RECT bounds;
                                GetWindowRect(hWnd, &bounds);
                                // location is in WebView client coordinates;
                                // convert to screen.
                                pt = {bounds.left + location.x,
                                      bounds.top + location.y};
                                INT32 selectedCmd = TrackPopupMenu(
                                    hMenu,
                                    TPM_TOPALIGN | TPM_LEFTALIGN |
                                        TPM_RETURNCMD,
                                    pt.x, pt.y, 0, hWnd, nullptr);

                                // ── Unified commanding ──
                                // Works for spellcheck suggestions AND
                                // standard items alike.
                                if (selectedCmd > 0)
                                    args->put_SelectedCommandId(selectedCmd);

                                DestroyMenu(hMenu);
                                deferral->Complete();
                                return S_OK;
                            })
                            .Get());
                });
            return S_OK;
        })
        .Get(),
    &m_contextMenuRequestedToken);
```

## .NET/WinRT — Display Custom Context Menu with Spellcheck Suggestions

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

    // Add standard items, skipping built-in spellcheck entries.
    foreach (var menuItem in args.MenuItems)
    {
        if (menuItem.Name.StartsWith("spellCheck"))
            continue;
        if (menuItem.Kind == CoreWebView2ContextMenuItemKind.Separator)
        {
            contextMenu.Items.Add(new ToolStripSeparator());
        }
        else
        {
            var stdItem = new ToolStripMenuItem(menuItem.Label);
            stdItem.Enabled = menuItem.IsEnabled;
            var stdCmdId = menuItem.CommandId;
            stdItem.Click += (_, _) =>
            {
                args.SelectedCommandId = stdCmdId;
            };
            contextMenu.Items.Add(stdItem);
        }
    }

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

# API Details

## Win32 COM IDL

```idl
// ─── EventArgs2: Deferred Capability Discovery (introduced for spellcheck) ───

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
} COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES;

/// Extends `ICoreWebView2ContextMenuRequestedEventArgs` with deferred capability
/// discovery and acquisition for spellcheck.
///
/// The host checks `DeferredCapabilities` flags to discover what async
/// capabilities exist for this invocation, then calls `GetDeferredCapability`
/// with the desired interface IID to acquire it.
[uuid(54ab63d2-9c3b-45a1-88d8-6c5a561784c9), object, pointer_default(unique)]
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
  ///
  /// The returned interface is valid for the lifetime of the event
  /// (until the deferral is completed).
  HRESULT GetDeferredCapability(
      [in] REFIID riid,
      [out, iid_is(riid), retval] void** capability);
}

// ─── Spellcheck Capability ───

/// Receives the result of `GetSpellCheckSuggestions`.
/// The handler is invoked exactly once, always asynchronously (posted to the
/// caller's message loop, never invoked inline during the call to
/// `GetSpellCheckSuggestions`).
[uuid(d73832f9-d05b-438d-bb6d-644124521fe3), object, pointer_default(unique)]
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
[uuid(aa742569-d944-4510-8924-c2c0583fa320), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuSpellCheck : IUnknown {
  /// Gets the misspelled word at the current context menu target location.
  /// This is the word that spellcheck flagged as incorrect and for which
  /// suggestions are available via `GetSpellCheckSuggestions`.
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
  HRESULT GetSpellCheckSuggestions(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}
```

## .NET/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    /// <summary>
    /// Flags indicating which deferred capabilities are available for a given
    /// context menu invocation.
    /// </summary>
    [Flags]
    enum CoreWebView2ContextMenuDeferredCapabilities
    {
        None       = 0x0,
        SpellCheck = 0x1,
    }

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        // Existing members unchanged.

        [interface_name("ICoreWebView2ContextMenuRequestedEventArgs2")]
        {
            /// <summary>
            /// Returns a bitmask of deferred capabilities available for this
            /// context menu invocation.
            /// </summary>
            CoreWebView2ContextMenuDeferredCapabilities DeferredCapabilities { get; };

            /// <summary>
            /// Retrieves the capability-specific interface for a deferred
            /// capability. Returns null if the capability is not applicable.
            /// </summary>
            T GetDeferredCapability<T>();
        }
    }

    runtimeclass CoreWebView2ContextMenuSpellCheck
    {
        /// <summary>
        /// The misspelled word under the cursor.
        /// </summary>
        String MisspelledWord { get; };

        /// <summary>
        /// Asynchronously retrieves spellcheck suggestions. Each item's
        /// CommandId can be passed to SelectedCommandId to apply the correction.
        /// </summary>
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

Each `ICoreWebView2ContextMenuItem` returned by `GetSpellCheckSuggestions` has:

| Property | Value |
|----------|-------|
| `Label` | Suggestion text (e.g., "the") |
| `CommandId` | WebView2-allocated opaque ID (e.g., 50001) |
| `Name` | `"spellCheckSuggestion"` |
| `Kind` | `COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND` |
| `IsEnabled` | `TRUE` |
| `IsChecked` | `FALSE` |
| `Icon` | `nullptr` |
| `ShortcutKeyDescription` | `L""` |
| `Children` | `nullptr` |

## Relationship to Built-in Spellcheck Menu Items

When a misspelled word is present, the `MenuItems` collection (from `get_MenuItems`) already
contains Chromium's **built-in** spellcheck suggestion items with `Name = "spellcheck"`. These
are the same suggestions that appear in the browser's default context menu.

The items returned by `GetSpellCheckSuggestions` are **separate objects** with
`Name = "spellCheckSuggestion"` and different `CommandId` values. They represent the same
underlying suggestions but are delivered through the new async API with full
`ICoreWebView2ContextMenuItem` semantics.

**Why both exist:** The built-in `"spellcheck"` items are part of the synchronous `MenuItems`
snapshot that all hosts already receive. The new `"spellCheckSuggestion"` items are delivered
asynchronously via `GetSpellCheckSuggestions` for hosts that want explicit control over
spellcheck rendering. Hosts using `GetSpellCheckSuggestions` should **filter out** the built-in
`"spellcheck"` items from `MenuItems` to avoid showing duplicate suggestions.

**Placement guidance:** The built-in `"spellcheck"` items appear at the top of `MenuItems`
(matching browser default behavior). Hosts may insert the new suggestion items at the same
position by scanning `MenuItems` for the first `"spellcheck"` entry's index, or simply place
them at the top of their custom menu as shown in the examples above.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| QI for EventArgs2 fails | Old runtime — use default menu |
| `SPELL_CHECK` flag not set | No misspelling — skip spellcheck UI |
| `GetDeferredCapability` returns `E_NOINTERFACE` | Capability not available (consistent with flags) |
| `MisspelledWord` returns empty string | Unexpected — indicates a runtime bug. Host should treat as "no spellcheck" and skip spellcheck UI |
| Second call to `GetSpellCheckSuggestions` | Standard async behavior — each call registers its own handler |
| Suggestions handler — no suggestions available | `count == 0` — show "No suggestions" or skip |
| User dismisses menu without selecting | Do not set `SelectedCommandId` (its default value of −1 indicates no selection) and complete the deferral |

## Async Timing

Spellcheck suggestions are resolved asynchronously by the platform spellchecker in the browser
process. When `ContextMenuRequested` fires, the `spellCheckState` may be:

| State | Meaning | `GetSpellCheckSuggestions` behavior |
|-------|---------|-------------------------------------|
| **Ready** | Suggestions already resolved before the event fired | Handler fires on next message loop iteration (sub-millisecond) |
| **Not Ready** | Platform spellchecker still working | Handler is stored; fires when browser delivers results via IPC |

The host does **not** need to check readiness — `GetSpellCheckSuggestions` handles both cases
transparently. However, the host should be aware that the handler may fire with a variable delay
in the Not Ready case, depending on the platform spellchecker's response time.

### Host Patterns

**Pattern 1: Wait-then-show** (simpler — used in the examples above)

The host defers the context menu, calls `GetSpellCheckSuggestions`, and builds/shows the menu
only after the handler fires. This produces a complete menu in one shot but delays appearance
if suggestions are not yet ready.

```
ContextMenuRequested → put_Handled(TRUE) + GetDeferral → GetSpellCheckSuggestions
    → [handler fires] → build & show menu → complete deferral
```

**Pattern 2: Show-then-update** (responsive — mirrors browser built-in behavior)

The host shows the context menu immediately with a placeholder (e.g., "Loading suggestions…")
and updates it in-place when the handler fires. This keeps menu appearance instant at the cost
of added complexity.

```
ContextMenuRequested → put_Handled(TRUE) + GetDeferral → show menu with placeholder
    → GetSpellCheckSuggestions → [handler fires] → update menu items in-place
    → [user selects] → complete deferral
```

# Appendix

## Extensibility

The deferred capability pattern introduced by this feature is designed for zero-versioning extension:

| To add a new capability | Required changes |
|------------------------|-----------------|
| New flag constant | `COREWEBVIEW2_CONTEXT_MENU_DEFERRED_CAPABILITIES_EMOJI = 0x2` |
| New capability interface | `ICoreWebView2ContextMenuEmoji : IUnknown { ... }` |

Example of how a host would check multiple capabilities in the future:

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
// }
```

## Planned Spellcheck Extensions

The following actions will be added as additional `ICoreWebView2ContextMenuItem` entries in the
collection returned by `GetSpellCheckSuggestions`. No new interfaces or methods are required:

| Action | `Name` value |
|--------|-------------|
| Add to Dictionary | `"spellCheckAddToDictionary"` |
| Ignore (session) | `"spellCheckIgnore"` |

These follow the same commanding model: the host renders them like any other item and applies via
`SelectedCommandId`. A `Language` property (BCP-47 tag of the dictionary that flagged the misspelling)
will also be added to `ICoreWebView2ContextMenuSpellCheck` in a follow-up version. Profile-level
spellcheck configuration (`IsSpellCheckEnabled`, `SpellCheckLanguages`) is tracked as a separate
follow-up.

## Relationship to Existing APIs

| Existing API | This Feature |
|-------------|-------------|
| `EventArgs.MenuItems` | Synchronous snapshot of menu items | 
| `EventArgs.SelectedCommandId` | Execution path — now also used for spellcheck suggestions |
| `ContextMenuItem.CommandId` | Already used for all items — spellcheck items join this pool |
| `ContextMenuItem.Label` | Display text — spellcheck suggestions use this for the suggestion word |
| `EventArgs.GetDeferral()` | Must be held across the async `GetSpellCheckSuggestions` gap |
