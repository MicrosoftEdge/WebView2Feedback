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
  read-only `ICoreWebView2SpellCheckSuggestion` objects. Each suggestion has a `SuggestionText`
  and `CommandId` (opaque identifier).

**Runtime version detection:** If `QueryInterface` (QI) for `Target2` returns `E_NOINTERFACE`, the host
is running on an older runtime that does not support this feature.

**Why async?** When `ContextMenuRequested` fires, spell check suggestions may not yet be available.
`GetSpellCheckSuggestions` handles this transparently — the handler may be invoked before the
method returns if suggestions are ready, or later when they become available.

**Commanding model:** The host applies a suggestion by passing its `CommandId` to
`put_SelectedCommandId` on the EventArgs — the same execution path used for Cut, Copy, Paste, and
all other context menu items. No separate execution method is needed.

# Examples

## Win32 C++

```cpp
webView->add_ContextMenuRequested(
    Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
        [this](ICoreWebView2* sender,
               ICoreWebView2ContextMenuRequestedEventArgs* eventArgs) -> HRESULT
        {
            wil::com_ptr<ICoreWebView2ContextMenuRequestedEventArgs> args =
                eventArgs;
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
                        ICoreWebView2SpellCheckSuggestionCollectionView*
                            suggestions) -> HRESULT
                    {
                        // Enumerate suggestions.
                        UINT32 count = 0;
                        if (SUCCEEDED(errorCode) && suggestions)
                            suggestions->get_Count(&count);

                        HMENU hPopupMenu = CreatePopupMenu();
                        for (UINT32 i = 0; i < count; i++)
                        {
                            wil::com_ptr<ICoreWebView2SpellCheckSuggestion>
                                suggestion;
                            suggestions->GetValueAtIndex(i, &suggestion);
                            wil::unique_cotaskmem_string suggestionText;
                            suggestion->get_SuggestionText(&suggestionText);
                            INT32 cmdId;
                            suggestion->get_CommandId(&cmdId);
                            AppendMenu(
                                hPopupMenu, MF_STRING,
                                static_cast<UINT_PTR>(cmdId),
                                suggestionText.get());
                        }

                        // Show hPopupMenu with TrackPopupMenu. Its return value
                        // is the selected suggestion's CommandId.
                        // INT32 selectedCmdId = TrackPopupMenu(...);
                        // args->put_SelectedCommandId(selectedCmdId);

                        DestroyMenu(hPopupMenu);
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
    IReadOnlyList<CoreWebView2SpellCheckSuggestion> suggestions =
        await target.GetSpellCheckSuggestionsAsync();

    // Build custom menu with suggestions.
    var contextMenu = new ContextMenuStrip();
    foreach (var suggestion in suggestions)
    {
        var item = new ToolStripMenuItem(suggestion.SuggestionText);
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
/// To apply a suggestion, pass the selected suggestion's `CommandId` to
/// `ICoreWebView2ContextMenuRequestedEventArgs::put_SelectedCommandId`.
[uuid(f7a3b8c1-2d4e-5f6a-8b9c-0d1e2f3a4b5c), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuTarget2 : ICoreWebView2ContextMenuTarget {
  /// Returns TRUE if the context menu target contains a spelling error.
  /// When TRUE, call `GetSpellCheckSuggestions` to retrieve the available
  /// spelling correction suggestions asynchronously.
  [propget] HRESULT HasSpellingError([out, retval] BOOL* value);

  /// Asynchronously retrieves spell check suggestions as a read-only
  /// collection. The handler is invoked immediately if suggestions are already
  /// available, or when they become available from the platform spell check
  /// engine. Each suggestion's `SuggestionText` is the correction text and its
  /// `CommandId` can be passed to `put_SelectedCommandId` to apply the
  /// correction. The handler receives an empty collection if no suggestions are
  /// available, if `HasSpellingError` is FALSE, or if the underlying spell
  /// check service does not respond within an internal timeout.
  /// Multiple concurrent calls are supported; each handler will be invoked
  /// with the same result when suggestions become available.
  /// Returns `E_POINTER` if `handler` is null.
  HRESULT GetSpellCheckSuggestions(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}

/// Represents a spelling correction that can be applied through
/// `ICoreWebView2ContextMenuRequestedEventArgs::put_SelectedCommandId`.
/// UUID will be generated after the API shape is approved.
interface ICoreWebView2SpellCheckSuggestion : IUnknown {
  /// Gets the spelling correction text.
  /// The caller must free the returned string with `CoTaskMemFree`.
  [propget] HRESULT SuggestionText([out, retval] LPWSTR* value);

  /// Gets the opaque command ID used to apply this correction.
  [propget] HRESULT CommandId([out, retval] INT32* value);
}

/// Represents a read-only collection of spell check suggestions.
/// UUID will be generated after the API shape is approved.
interface ICoreWebView2SpellCheckSuggestionCollectionView : IUnknown {
  /// Gets the number of suggestions in the collection.
  [propget] HRESULT Count([out, retval] UINT32* value);

  /// Gets the suggestion at the specified index.
  HRESULT GetValueAtIndex(
      [in] UINT32 index,
      [out, retval] ICoreWebView2SpellCheckSuggestion** value);
}

/// Receives the result of the `GetSpellCheckSuggestions` method.
[uuid(d73832f9-d05b-438d-bb6d-6441245221e3), object, pointer_default(unique)]
interface ICoreWebView2GetSpellCheckSuggestionsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  /// To apply a suggestion, pass its `CommandId` to
  /// `ICoreWebView2ContextMenuRequestedEventArgs.put_SelectedCommandId`.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2SpellCheckSuggestionCollectionView* suggestions);
}
```

## .NET/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2SpellCheckSuggestion
    {
        /// <summary>
        /// Gets the spelling correction text.
        /// </summary>
        String SuggestionText { get; };

        /// <summary>
        /// Gets the opaque command ID used to apply this correction.
        /// </summary>
        Int32 CommandId { get; };
    }

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
            /// Asynchronously retrieves a read-only collection of spell check
            /// suggestions. Each suggestion's CommandId can be passed to
            /// SelectedCommandId to apply the correction.
            /// </summary>
            Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2SpellCheckSuggestion>>
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

## Async Timing

When `ContextMenuRequested` fires, the suggestions may be:

| State | Meaning | `GetSpellCheckSuggestions` behavior |
|-------|---------|-------------------------------------|
| **Ready** | Suggestions are available | Handler may be invoked before the method returns |
| **Not Ready** | Suggestions are still being retrieved | Handler is invoked when suggestions become available |

The host does **not** need to check readiness — `GetSpellCheckSuggestions` handles both cases
transparently.

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

Either pattern is valid. Pattern 1 is recommended for most hosts because it is simpler. Pattern 2
is appropriate for hosts that require guaranteed instant menu appearance.

# Appendix

## Relationship to Existing APIs

| Existing API | This Feature |
|-------------|-------------|
| `EventArgs.MenuItems` | Synchronous snapshot of menu items |
| `EventArgs.SelectedCommandId` | Execution path — now also used for spell check suggestions |
| `SpellCheckSuggestion.CommandId` | Opaque command ID used to apply a spelling correction |
| `SpellCheckSuggestion.SuggestionText` | Browser-provided spell check suggestion |
| `EventArgs.GetDeferral()` | Must be held across the async `GetSpellCheckSuggestions` gap |
| `ContextMenuTarget` | Base target — QI to `Target2` for spell check support |
