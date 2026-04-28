Spellcheck Support for Custom Context Menus
===

# Background

When a host application renders a custom context menu via the `ContextMenuRequested` event, spellcheck
suggestions for misspelled words are not available. The browser's built-in spellcheck pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

This feature adds spellcheck support to custom context menus by extending
`ICoreWebView2ContextMenuTarget` with a new `ICoreWebView2ContextMenuTarget2` interface. The host
checks whether a misspelled word is present, then asynchronously retrieves spelling suggestions.

# Description

The `ICoreWebView2ContextMenuTarget` is extended with `ICoreWebView2ContextMenuTarget2`.
This new interface provides:

- **`HasMisspelledWord`** — Read-only BOOL property indicating whether the context menu target
  contains a misspelled word. This is always available synchronously when the event fires.
- **`GetSpellCheckSuggestions(handler)`** — Asynchronously retrieves spellcheck suggestions as
  `ICoreWebView2ContextMenuItem` objects. Each suggestion has a `Label` (display text) and
  `CommandId` (opaque identifier).

**Runtime version detection:** If `QueryInterface` for `Target2` returns `E_NOINTERFACE`, the host
is running on an older runtime that does not support this feature.

**Why async?** Spellcheck suggestions are resolved asynchronously by the platform spellchecker
(e.g., Windows `ISpellChecker`). When `ContextMenuRequested` fires, suggestions may not yet be
available. `GetSpellCheckSuggestions` handles this transparently — it invokes the handler
immediately if suggestions are ready, or waits for the platform spellchecker to deliver them.
If the platform spellchecker does not respond within an internal timeout, the handler is invoked
with an empty collection.

**Commanding model:** The host applies a suggestion by passing its `CommandId` to
`put_SelectedCommandId` on the EventArgs — the same execution path used for Cut, Copy, Paste, and
all other context menu items. No separate execution method is needed.

# Examples

## Win32 C++ — Display Custom Context Menu with Spellcheck Suggestions

```cpp
webView->add_ContextMenuRequested(
    Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ContextMenuRequestedEventArgs* args) -> HRESULT
        {
            // ── Step 1: Get context menu target ──
            wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
            CHECK_FAILURE(args->get_ContextMenuTarget(&target));

            // ── Step 2: Check for Target2 (runtime version check) ──
            auto target2 = wil::try_com_query<
                ICoreWebView2ContextMenuTarget2>(target);
            if (!target2)
                return S_OK; // Old runtime — use default menu.

            // ── Step 3: Check for misspelled word ──
            BOOL hasMisspelledWord = FALSE;
            CHECK_FAILURE(target2->get_HasMisspelledWord(&hasMisspelledWord));
            if (!hasMisspelledWord)
                return S_OK; // No misspelling — use default menu.

            // ── Step 4: Take over rendering and hold deferral ──
            CHECK_FAILURE(args->put_Handled(TRUE));
            wil::com_ptr<ICoreWebView2Deferral> deferral;
            CHECK_FAILURE(args->GetDeferral(&deferral));

            // ── Step 5: Get menu items for later use ──
            wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
            CHECK_FAILURE(args->get_MenuItems(&items));

            // ── Step 6: Get suggestions asynchronously and build menu ──
            CHECK_FAILURE(target2->GetSpellCheckSuggestions(
                Callback<
                    ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
                    [this, args, items, deferral](
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
                                L"Spelling suggestions:");
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
                        else
                        {
                            AppendMenuW(
                                hMenu, MF_GRAYED | MF_STRING, 0,
                                L"No suggestions available");
                            AppendMenuW(
                                hMenu, MF_SEPARATOR, 0, nullptr);
                        }

                        // Add remaining standard context menu items.
                        AddMenuItems(hMenu, items.get());

                        // Show popup at the context menu location.
                        HWND hWnd = m_appWindow->GetMainWindow();
                        POINT location;
                        args->get_Location(&location);
                        RECT bounds;
                        GetWindowRect(hWnd, &bounds);
                        POINT pt = {bounds.left + location.x,
                                    bounds.top + location.y};
                        INT32 selectedCmd = TrackPopupMenu(
                            hMenu,
                            TPM_TOPALIGN | TPM_LEFTALIGN |
                                TPM_RETURNCMD,
                            pt.x, pt.y, 0, hWnd, nullptr);

                        // ── Unified commanding ──
                        if (selectedCmd > 0)
                            args->put_SelectedCommandId(selectedCmd);

                        DestroyMenu(hMenu);
                        deferral->Complete();
                        return S_OK;
                    })
                    .Get()));
            return S_OK;
        })
        .Get(),
    &m_contextMenuRequestedToken);
```

## .NET/WinRT — Display Custom Context Menu with Spellcheck Suggestions

```csharp
webView.CoreWebView2.ContextMenuRequested += async (sender, args) =>
{
    // Step 1: Get context menu target.
    var target = args.ContextMenuTarget;

    // Step 2: Check for misspelled word (Target2 property).
    if (!target.HasMisspelledWord)
        return;  // No misspelling — let default menu show.

    // Step 3: Take over menu rendering and hold deferral.
    args.Handled = true;
    var deferral = args.GetDeferral();

    // Step 4: Get suggestions asynchronously.
    IReadOnlyList<CoreWebView2ContextMenuItem> suggestions =
        await target.GetSpellCheckSuggestionsAsync();

    // Step 5: Build custom menu.
    var contextMenu = new ContextMenuStrip();
    bool completed = false;

    if (suggestions.Count > 0)
    {
        contextMenu.Items.Add(new ToolStripMenuItem(
            "Spelling suggestions:") { Enabled = false });

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
        contextMenu.Items.Add(new ToolStripSeparator());
    }
    else
    {
        contextMenu.Items.Add(new ToolStripMenuItem(
            "No suggestions available") { Enabled = false });
        contextMenu.Items.Add(new ToolStripSeparator());
    }

    // Add standard items.
    foreach (var menuItem in args.MenuItems)
    {
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

    // Complete deferral on menu close.
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
// ─── ContextMenuTarget2: Spellcheck support ───

/// Extends `ICoreWebView2ContextMenuTarget` with spellcheck support for
/// custom context menus.
///
/// The host can `QueryInterface` the `ICoreWebView2ContextMenuTarget` returned
/// by `ICoreWebView2ContextMenuRequestedEventArgs::get_ContextMenuTarget` to
/// obtain this interface. Check `HasMisspelledWord` to determine whether
/// the context menu was invoked on a misspelled word, then call
/// `GetSpellCheckSuggestions` to asynchronously retrieve spelling corrections.
///
/// To apply a suggestion, pass the selected item's `CommandId` to
/// `ICoreWebView2ContextMenuRequestedEventArgs::put_SelectedCommandId`.
[uuid(f7a3b8c1-2d4e-5f6a-8b9c-0d1e2f3a4b5c), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuTarget2 : ICoreWebView2ContextMenuTarget {
  /// Returns TRUE if the context menu target contains a misspelled word.
  /// When TRUE, call `GetSpellCheckSuggestions` to retrieve the available
  /// spelling correction suggestions asynchronously.
  [propget] HRESULT HasMisspelledWord([out, retval] BOOL* value);

  /// Asynchronously retrieves spellcheck suggestion options as a collection
  /// of context menu items. The handler is invoked immediately if suggestions
  /// are already available, or when they become available from the platform
  /// spellcheck engine. Each item's `Label` is the suggestion text and its
  /// `CommandId` can be passed to `put_SelectedCommandId` to apply the
  /// correction. The handler receives an empty collection if no suggestions
  /// are available, if `HasMisspelledWord` is FALSE, or if the underlying
  /// spellcheck service does not respond within an internal timeout.
  /// Only one outstanding request is allowed; calling this method while a
  /// previous request is pending returns `E_ILLEGAL_METHOD_CALL`.
  HRESULT GetSpellCheckSuggestions(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}

/// Receives the result of the `GetSpellCheckSuggestions` method.
[uuid(d73832f9-d05b-438d-bb6d-6441245221e3), object, pointer_default(unique)]
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
```

## .NET/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ContextMenuTarget
    {
        // Existing members unchanged.

        [interface_name("ICoreWebView2ContextMenuTarget2")]
        {
            /// <summary>
            /// Returns TRUE if the context menu target contains a misspelled word.
            /// </summary>
            Boolean HasMisspelledWord { get; };

            /// <summary>
            /// Asynchronously retrieves spellcheck suggestions. Each item's
            /// CommandId can be passed to SelectedCommandId to apply the correction.
            /// </summary>
            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ContextMenuItem>>
                GetSpellCheckSuggestionsAsync();
        }
    }
}
```

# Behavioral Details

## Discovery Flow

| Step | Action | Result |
|------|--------|--------|
| 1 | QI for `Target2` from `ContextMenuTarget` | `E_NOINTERFACE` → old runtime, fall back to default menu |
| 2 | Read `HasMisspelledWord` | `TRUE` → misspelling present; `FALSE` → no misspelling |
| 3 | Call `GetSpellCheckSuggestions(handler)` | Handler invoked when suggestions are available |

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

## Error Handling

| Scenario | Behavior |
|----------|----------|
| QI for Target2 fails | Old runtime — use default menu |
| `HasMisspelledWord` is FALSE | No misspelling — skip spellcheck UI |
| `GetSpellCheckSuggestions` with null handler | Returns `E_POINTER` |
| Concurrent call to `GetSpellCheckSuggestions` | Returns `E_ILLEGAL_METHOD_CALL` |
| Suggestions handler — no suggestions available | `count == 0` — show "No suggestions" or skip |
| Platform spellchecker does not respond | Handler invoked with empty collection after internal timeout |
| User dismisses menu without selecting | Do not set `SelectedCommandId` (default −1) and complete the deferral |

## Async Timing

Spellcheck suggestions are resolved asynchronously by the platform spellchecker in the browser
process. When `ContextMenuRequested` fires, the suggestions may be:

| State | Meaning | `GetSpellCheckSuggestions` behavior |
|-------|---------|-------------------------------------|
| **Ready** | Suggestions already resolved before the event fired | Handler invoked immediately |
| **Not Ready** | Platform spellchecker still working | Handler stored; invoked when browser delivers results via IPC, or after internal timeout with empty collection |

The host does **not** need to check readiness — `GetSpellCheckSuggestions` handles both cases
transparently. In the typical case, the platform spellchecker responds within a few milliseconds.
The internal timeout is a conservative safeguard for edge cases where the platform spellchecker
is slow or unresponsive.

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
of added complexity. Since the host owns the custom context menu UI, it can modify the menu
while it is open.

```
ContextMenuRequested → put_Handled(TRUE) + GetDeferral → show menu with placeholder
    → GetSpellCheckSuggestions → [handler fires] → update menu items in-place
    → [user selects] → complete deferral
```

Either pattern is valid. Pattern 1 is recommended for most hosts because the delay is typically
imperceptible (suggestions often resolve before the event fires or within a few milliseconds
after). Pattern 2 is appropriate for hosts that require guaranteed instant menu appearance.

# Appendix

## Planned Spellcheck Extensions

The following actions will be added as additional `ICoreWebView2ContextMenuItem` entries in the
collection returned by `GetSpellCheckSuggestions`. No new interfaces or methods are required:

| Action | `Name` value |
|--------|-------------|
| Add to Dictionary | `"spellCheckAddToDictionary"` |
| Ignore (session) | `"spellCheckIgnore"` |

These follow the same commanding model: the host renders them like any other item and applies via
`SelectedCommandId`. A `Language` property (BCP-47 tag of the dictionary that flagged the misspelling)
may also be added to `ICoreWebView2ContextMenuTarget2` in a follow-up version. Profile-level
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
| `ContextMenuTarget` | Base target — QI to `Target2` for spellcheck support |
