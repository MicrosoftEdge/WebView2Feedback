Spell Check Support for Custom Context Menus
===

# Background

When a host application renders a custom context menu via the `ContextMenuRequested` event, spell check
suggestions for misspelled words are not available. The browser's built-in spell check pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

This feature adds spell check support to custom context menus by extending
`ICoreWebView2ContextMenuTarget` with a new `ICoreWebView2ContextMenuTarget2` interface. The host
checks whether a misspelled word is present, then asynchronously retrieves spelling suggestions.

# Description

The `ICoreWebView2ContextMenuTarget` is extended with `ICoreWebView2ContextMenuTarget2`.
This new interface provides:

- **`HasSpellingError`** — Read-only BOOL property indicating whether the context menu target
  contains a spelling error. This is always available synchronously when the event fires.
- **`GetSpellCheckSuggestions(handler)`** — Asynchronously retrieves spell check suggestions as
  `ICoreWebView2ContextMenuItem` objects. Each suggestion has a `Label` (display text) and
  `CommandId` (opaque identifier).

**Runtime version detection:** If `QueryInterface` (QI) for `Target2` returns `E_NOINTERFACE`, the host
is running on an older runtime that does not support this feature.

**Why async?** Spell check suggestions are resolved asynchronously by the platform spell checker
(e.g., Windows `ISpellChecker`). When `ContextMenuRequested` fires, suggestions may not yet be
available. `GetSpellCheckSuggestions` handles this transparently — it invokes the handler
immediately if suggestions are ready, or waits for the platform spell checker to deliver them.
If the platform spell checker does not respond within an internal timeout, the handler is invoked
with an empty collection.

**Commanding model:** The host applies a suggestion by passing its `CommandId` to
`put_SelectedCommandId` on the EventArgs — the same execution path used for Cut, Copy, Paste, and
all other context menu items. No separate execution method is needed.

# Examples

## Win32 C++

```cpp
webView->add_ContextMenuRequested(
    Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ContextMenuRequestedEventArgs* args) -> HRESULT
        {
            wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
            CHECK_FAILURE(args->get_ContextMenuTarget(&target));

            // QI for Target2 — returns E_NOINTERFACE on older runtimes.
            auto target2 = wil::try_com_query<
                ICoreWebView2ContextMenuTarget2>(target);
            if (!target2)
                return S_OK;

            // Check if the context menu target has a spelling error.
            BOOL hasSpellingError = FALSE;
            CHECK_FAILURE(target2->get_HasSpellingError(&hasSpellingError));
            if (!hasSpellingError)
                return S_OK;

            // Take deferral — menu will be shown after async callback.
            wil::com_ptr<ICoreWebView2Deferral> deferral;
            CHECK_FAILURE(args->GetDeferral(&deferral));
            CHECK_FAILURE(args->put_Handled(true));

            // Asynchronously retrieve spell check suggestions.
            CHECK_FAILURE(target2->GetSpellCheckSuggestions(
                Callback<
                    ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
                    [args, deferral](
                        HRESULT errorCode,
                        ICoreWebView2ContextMenuItemCollection*
                            suggestions) -> HRESULT
                    {
                        // Enumerate suggestions — each has Label and CommandId.
                        UINT32 count = 0;
                        if (SUCCEEDED(errorCode) && suggestions)
                            suggestions->get_Count(&count);

                        for (UINT32 i = 0; i < count; i++)
                        {
                            wil::com_ptr<ICoreWebView2ContextMenuItem> item;
                            suggestions->GetValueAtIndex(i, &item);
                            wil::unique_cotaskmem_string label;
                            item->get_Label(&label);
                            INT32 cmdId;
                            item->get_CommandId(&cmdId);
                            // ... add to custom menu using label and cmdId ...
                        }

                        // Apply selection via unified commanding.
                        // args->put_SelectedCommandId(selectedCmdId);

                        deferral->Complete();
                        return S_OK;
                    })
                    .Get()));
            return S_OK;
        })
        .Get(),
    &m_contextMenuRequestedToken);
```

## .NET/WinRT

```csharp
webView.CoreWebView2.ContextMenuRequested += async (sender, args) =>
{
    var target = args.ContextMenuTarget;

    // Check if the context menu target has a spelling error.
    if (!target.HasSpellingError)
        return;

    // Take deferral — menu will be shown after async call completes.
    var deferral = args.GetDeferral();
    args.Handled = true;

    // Asynchronously retrieve spell check suggestions.
    IReadOnlyList<CoreWebView2ContextMenuItem> suggestions =
        await target.GetSpellCheckSuggestionsAsync();

    // Build custom menu with suggestions.
    var contextMenu = new ContextMenuStrip();
    foreach (var suggestion in suggestions)
    {
        var item = new ToolStripMenuItem(suggestion.Label);
        var capturedId = suggestion.CommandId;
        item.Click += (_, _) =>
        {
            // Apply selection via unified commanding.
            args.SelectedCommandId = capturedId;
        };
        contextMenu.Items.Add(item);
    }

    // Show menu and complete deferral when closed.
    contextMenu.Closed += (_, _) => deferral.Complete();
    contextMenu.Show(webView, new Point(args.Location.X, args.Location.Y));
};
```

# API Details

## Win32 COM IDL

```idl
// ─── ContextMenuTarget2: Spell check support ───

/// Extends `ICoreWebView2ContextMenuTarget` with spell check support for
/// custom context menus.
///
/// The host can `QueryInterface` the `ICoreWebView2ContextMenuTarget` returned
/// by `ICoreWebView2ContextMenuRequestedEventArgs::get_ContextMenuTarget` to
/// obtain this interface. Check `HasSpellingError` to determine whether
/// the context menu was invoked on a misspelled word, then call
/// `GetSpellCheckSuggestions` to asynchronously retrieve spelling corrections.
///
/// To apply a suggestion, pass the selected item's `CommandId` to
/// `ICoreWebView2ContextMenuRequestedEventArgs::put_SelectedCommandId`.
[uuid(f7a3b8c1-2d4e-5f6a-8b9c-0d1e2f3a4b5c), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuTarget2 : ICoreWebView2ContextMenuTarget {
  /// Returns TRUE if the context menu target contains a spelling error.
  /// When TRUE, call `GetSpellCheckSuggestions` to retrieve the available
  /// spelling correction suggestions asynchronously.
  [propget] HRESULT HasSpellingError([out, retval] BOOL* value);

  /// Asynchronously retrieves spell check suggestion options as a collection
  /// of context menu items. The handler is invoked immediately if suggestions
  /// are already available, or when they become available from the platform
  /// spell check engine. Each item's `Label` is the suggestion text and its
  /// `CommandId` can be passed to `put_SelectedCommandId` to apply the
  /// correction. The handler receives an empty collection if no suggestions
  /// are available, if `HasSpellingError` is FALSE, or if the underlying
  /// spell check service does not respond within an internal timeout.
  /// Multiple concurrent calls are supported; each handler will be invoked
  /// with the same result when suggestions become available.
  /// Returns `E_POINTER` if `handler` is null.
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
            /// Returns TRUE if the context menu target contains a spelling error.
            /// </summary>
            Boolean HasSpellingError { get; };

            /// <summary>
            /// Asynchronously retrieves spell check suggestions. Each item's
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
| 2 | Read `HasSpellingError` | `TRUE` → spelling error present; `FALSE` → no spelling error |
| 3 | Call `GetSpellCheckSuggestions(handler)` | Handler invoked when suggestions are available |

## Suggestion Item Properties

Each `ICoreWebView2ContextMenuItem` returned by `GetSpellCheckSuggestions` has:

| Property | Value |
|----------|-------|
| `Label` | Suggestion text (e.g., "the") |
| `CommandId` | WebView2-allocated opaque ID (e.g., 50001) |
| `Name` | `"spellCheckSuggestion"` |
| `Kind` | `COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND` |
| `IsEnabled` | true |
| `IsChecked` | false |
| `Icon` | null |
| `ShortcutKeyDescription` | empty string |
| `Children` | null |

## Async Timing

Spell check suggestions are resolved asynchronously by the platform spell checker in the browser
process. When `ContextMenuRequested` fires, the suggestions may be:

| State | Meaning | `GetSpellCheckSuggestions` behavior |
|-------|---------|-------------------------------------|
| **Ready** | Suggestions already resolved before the event fired | Handler invoked immediately |
| **Not Ready** | Platform spell checker still working | Handler stored; invoked when browser delivers results via IPC, or after internal timeout with empty collection |

The host does **not** need to check readiness — `GetSpellCheckSuggestions` handles both cases
transparently. In the typical case, the platform spell checker responds within a few milliseconds.
The internal timeout is a conservative safeguard for rare scenarios where the platform spell checker
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

## Planned Spell Check Extensions

The following actions will be added as additional `ICoreWebView2ContextMenuItem` entries in the
collection returned by `GetSpellCheckSuggestions`. No new interfaces or methods are required:

| Action | `Name` value |
|--------|-------------|
| Add to Dictionary | `"spellCheckAddToDictionary"` |
| Ignore (session) | `"spellCheckIgnore"` |

These follow the same commanding model: the host renders them like any other item and applies via
`SelectedCommandId`. A `Language` property (BCP-47 tag of the dictionary that flagged the misspelling)
may also be added to `ICoreWebView2ContextMenuTarget2` in a follow-up version. Profile-level
spell check configuration (`IsSpellCheckEnabled`, `SpellCheckLanguages`) is tracked as a separate
follow-up.

## Relationship to Existing APIs

| Existing API | This Feature |
|-------------|-------------|
| `EventArgs.MenuItems` | Synchronous snapshot of menu items |
| `EventArgs.SelectedCommandId` | Execution path — now also used for spell check suggestions |
| `ContextMenuItem.CommandId` | Already used for all items — spell check items join this pool |
| `ContextMenuItem.Label` | Display text — spell check suggestions use this for the suggestion word |
| `EventArgs.GetDeferral()` | Must be held across the async `GetSpellCheckSuggestions` gap |
| `ContextMenuTarget` | Base target — QI to `Target2` for spell check support |
