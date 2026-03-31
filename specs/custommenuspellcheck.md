Custom Context Menu SpellCheck
===

# Background

When a host application renders a custom context menu via the `ContextMenuRequested` event, spellcheck
suggestions for misspelled words are not available. The browser's built-in spellcheck pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

# Description

We propose extending the existing `ContextMenuRequested` API surface with spellcheck support for custom
context menus. This adds the ability to:

1. Query spellcheck information (misspelled word, readiness state, suggestions) from the context menu target.
2. Subscribe to an asynchronous notification when spellcheck suggestions become available.
3. Apply a selected spellcheck suggestion to replace the misspelled word in the DOM.

Hosts opt in by calling `QueryInterface` for the new `ICoreWebView2ContextMenuTarget2` and
`ICoreWebView2ContextMenuRequestedEventArgs2` interfaces. Existing `ContextMenuRequested` consumers
are unaffected.

# Examples

## Win32 C++

```cpp
void ShowCustomContextMenuWithSpellCheck(
    ICoreWebView2ContextMenuRequestedEventArgs* args)
{
    wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
    CHECK_FAILURE(args->get_ContextMenuTarget(&target));

    BOOL isEditable = FALSE;
    CHECK_FAILURE(target->get_IsEditable(&isEditable));

    HMENU hMenu = CreatePopupMenu();
    UINT menuIndex = 0;

    if (isEditable)
    {
        auto target2 = target.try_query<ICoreWebView2ContextMenuTarget2>();
        auto args2 = wil::com_ptr_query<ICoreWebView2ContextMenuRequestedEventArgs2>(args);

        if (target2 && args2)
        {
            wil::unique_cotaskmem_string misspelledWord;
            COREWEBVIEW2_SPELL_CHECK_READINESS spellState;
            wil::com_ptr<ICoreWebView2StringCollection> suggestions;
            CHECK_FAILURE(target2->GetSpellCheckInfo(
                &misspelledWord, &spellState, &suggestions));

            if (spellState == COREWEBVIEW2_SPELL_CHECK_READINESS_READY)
            {
                // Suggestions are available — add them to the menu.
                UINT32 count = 0;
                suggestions->get_Count(&count);
                for (UINT32 i = 0; i < count && i < 5; i++)
                {
                    wil::unique_cotaskmem_string suggestion;
                    suggestions->GetValueAtIndex(i, &suggestion);
                    MENUITEMINFO mii = {};
                    mii.cbSize = sizeof(mii);
                    mii.fMask = MIIM_STRING | MIIM_ID;
                    mii.wID = IDM_SPELL_SUGGESTION_BASE + i;
                    mii.dwTypeData = suggestion.get();
                    InsertMenuItem(hMenu, menuIndex++, TRUE, &mii);
                }
            }
            else if (spellState == COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY)
            {
                // Suggestions pending — show placeholder and register async handler.
                MENUITEMINFO mii = {};
                mii.cbSize = sizeof(mii);
                mii.fMask = MIIM_STRING | MIIM_ID | MIIM_STATE;
                mii.fState = MFS_DISABLED;
                mii.wID = IDM_SPELL_PLACEHOLDER;
                mii.dwTypeData = const_cast<LPWSTR>(L"Loading suggestions...");
                InsertMenuItem(hMenu, menuIndex++, TRUE, &mii);

                // Handler fires when suggestions arrive (or immediately if
                // already resolved). During TrackPopupMenu's modal loop,
                // the handler updates the menu in-place.
                CHECK_FAILURE(args2->add_SpellCheckSuggestionsReady(
                    Callback<ICoreWebView2SpellCheckSuggestionsReadyEventHandler>(
                        [hMenu, target2, args2](
                            ICoreWebView2ContextMenuRequestedEventArgs* sender,
                            IUnknown* eventArgs) -> HRESULT
                        {
                            wil::unique_cotaskmem_string word;
                            COREWEBVIEW2_SPELL_CHECK_READINESS state;
                            wil::com_ptr<ICoreWebView2StringCollection> suggs;
                            CHECK_FAILURE(target2->GetSpellCheckInfo(
                                &word, &state, &suggs));

                            if (state == COREWEBVIEW2_SPELL_CHECK_READINESS_READY)
                            {
                                UINT32 count = 0;
                                suggs->get_Count(&count);
                                if (count > 0)
                                {
                                    // Replace placeholder with first suggestion.
                                    wil::unique_cotaskmem_string first;
                                    suggs->GetValueAtIndex(0, &first);
                                    MENUITEMINFO mii = {};
                                    mii.cbSize = sizeof(mii);
                                    mii.fMask = MIIM_STRING | MIIM_ID | MIIM_STATE;
                                    mii.fState = MFS_ENABLED;
                                    mii.wID = IDM_SPELL_SUGGESTION_BASE;
                                    mii.dwTypeData = first.get();
                                    SetMenuItemInfo(
                                        hMenu, IDM_SPELL_PLACEHOLDER, FALSE, &mii);

                                    // Insert remaining suggestions.
                                    for (UINT32 i = 1; i < count && i < 5; i++)
                                    {
                                        wil::unique_cotaskmem_string s;
                                        suggs->GetValueAtIndex(i, &s);
                                        MENUITEMINFO item = {};
                                        item.cbSize = sizeof(item);
                                        item.fMask = MIIM_STRING | MIIM_ID;
                                        item.wID = IDM_SPELL_SUGGESTION_BASE + i;
                                        item.dwTypeData = s.get();
                                        InsertMenuItem(hMenu, i, TRUE, &item);
                                    }
                                }

                                // Repaint the popup menu.
                                HWND hPopup = FindWindow(L"#32768", nullptr);
                                if (hPopup)
                                {
                                    RedrawWindow(
                                        hPopup, nullptr, nullptr,
                                        RDW_INVALIDATE | RDW_UPDATENOW | RDW_ERASE);
                                }
                            }
                            return S_OK;
                        })
                        .Get(),
                    &m_spellCheckToken));
            }
        }
    }

    // Add standard WebView2 context menu items.
    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
    CHECK_FAILURE(args->get_MenuItems(&items));
    UINT32 itemCount;
    CHECK_FAILURE(items->get_Count(&itemCount));
    for (UINT32 i = 0; i < itemCount; i++)
    {
        wil::com_ptr<ICoreWebView2ContextMenuItem> item;
        CHECK_FAILURE(items->GetValueAtIndex(i, &item));
        // ... add each item to hMenu ...
    }

    // Show the menu.
    UINT selectedId = TrackPopupMenu(
        hMenu, TPM_RETURNCMD, pt.x, pt.y, 0, m_hWnd, nullptr);

    // Handle selection.
    if (selectedId >= IDM_SPELL_SUGGESTION_BASE &&
        selectedId < IDM_SPELL_SUGGESTION_BASE + 5)
    {
        // Apply the selected spellcheck suggestion.
        wil::unique_cotaskmem_string word;
        COREWEBVIEW2_SPELL_CHECK_READINESS state;
        wil::com_ptr<ICoreWebView2StringCollection> suggs;
        target2->GetSpellCheckInfo(&word, &state, &suggs);
        wil::unique_cotaskmem_string chosen;
        suggs->GetValueAtIndex(selectedId - IDM_SPELL_SUGGESTION_BASE, &chosen);
        args2->ApplySpellCheckSuggestion(chosen.get());
    }

    args->put_Handled(TRUE);
    DestroyMenu(hMenu);
}
```

## C#/.NET

```csharp
void ShowCustomContextMenuWithSpellCheck(
    object sender, CoreWebView2ContextMenuRequestedEventArgs args)
{
    var target = args.ContextMenuTarget;
    var menuItems = new List<ToolStripItem>();

    if (target.IsEditable)
    {
        string misspelledWord = target.MisspelledWord;
        CoreWebView2SpellCheckReadiness spellState = target.SpellCheckReadiness;
        IReadOnlyList<string> suggestions = target.SpellCheckSuggestions;

        if (spellState == CoreWebView2SpellCheckReadiness.Ready && suggestions.Count > 0)
        {
            // Suggestions available — add them directly.
            foreach (string suggestion in suggestions.Take(5))
            {
                var item = new ToolStripMenuItem(suggestion);
                item.Click += (s, e) =>
                {
                    args.ApplySpellCheckSuggestion(suggestion);
                };
                menuItems.Add(item);
            }
            menuItems.Add(new ToolStripSeparator());
        }
        else if (spellState == CoreWebView2SpellCheckReadiness.NotReady)
        {
            // Suggestions pending — show placeholder.
            var placeholder = new ToolStripMenuItem("Loading suggestions...")
            {
                Enabled = false
            };
            menuItems.Add(placeholder);
            menuItems.Add(new ToolStripSeparator());

            // Register async handler. Fires when suggestions resolve
            // or immediately if already resolved.
            args.SpellCheckSuggestionsReady += (s, e) =>
            {
                string word = target.MisspelledWord;
                var readySuggestions = target.SpellCheckSuggestions;
                if (target.SpellCheckReadiness == CoreWebView2SpellCheckReadiness.Ready
                    && readySuggestions.Count > 0)
                {
                    // Replace placeholder with actual suggestions.
                    int index = menuItems.IndexOf(placeholder);
                    menuItems.Remove(placeholder);
                    foreach (string suggestion in readySuggestions.Take(5))
                    {
                        var item = new ToolStripMenuItem(suggestion);
                        item.Click += (s2, e2) =>
                        {
                            args.ApplySpellCheckSuggestion(suggestion);
                        };
                        menuItems.Insert(index++, item);
                    }
                }
            };
        }
    }

    // Add standard WebView2 context menu items.
    foreach (var menuItem in args.MenuItems)
    {
        // ... add each item to menuItems ...
    }

    // Show the context menu.
    var contextMenu = new ContextMenuStrip();
    contextMenu.Items.AddRange(menuItems.ToArray());
    contextMenu.Show(webView, webView.PointToClient(Cursor.Position));

    args.Handled = true;
}
```

# API Details

## Win32 C++

```idl
/// Indicates the readiness of spellcheck suggestions for the context menu
/// target. Used by hosts rendering custom context menus.
[v1_enum]
typedef enum COREWEBVIEW2_SPELL_CHECK_READINESS {
  /// Spellcheck suggestions are available and ready to display.
  COREWEBVIEW2_SPELL_CHECK_READINESS_READY,
  /// Spellcheck is active but suggestions have not yet been resolved
  /// (asynchronous retrieval in progress).
  COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY,
  /// Spellcheck suggestions are not applicable for the current context
  /// (not editable, no misspelling, or spellcheck disabled).
  COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_AVAILABLE,
  /// Spellcheck resolution failed due to an internal error.
  /// No suggestions will arrive.
  COREWEBVIEW2_SPELL_CHECK_READINESS_ERROR,
} COREWEBVIEW2_SPELL_CHECK_READINESS;

/// Receives `SpellCheckSuggestionsReady` events from
/// ICoreWebView2ContextMenuRequestedEventArgs2.
[uuid(c5d6e7f8-9a0b-1c2d-3e4f-5a6b7c8d9e0f), object, pointer_default(unique)]
interface ICoreWebView2SpellCheckSuggestionsReadyEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2ContextMenuRequestedEventArgs* sender,
      [in] IUnknown* args);
}

/// Extends ICoreWebView2ContextMenuTarget with spellcheck information
/// for custom context menu integration. Allows host applications to retrieve
/// spellcheck suggestions and metadata when rendering custom menus
/// on editable fields.
[uuid(d3f7e01a-9b5c-4e8f-a1d2-7c6b3e4f5a80), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuTarget2 : ICoreWebView2ContextMenuTarget {
  /// Gets spellcheck information for the current context menu target in a
  /// single call. Returns the misspelled word (empty if none), the readiness
  /// state of suggestions, and a collection of suggestion strings.
  ///
  /// The caller must free `misspelledWord` with `CoTaskMemFree`.
  ///
  /// When `state` is `COREWEBVIEW2_SPELL_CHECK_READINESS_READY`, the
  /// `suggestions` collection is populated with correction strings.
  /// When `state` is `COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY`, the
  /// collection is empty; subscribe to `SpellCheckSuggestionsReady` on
  /// `ICoreWebView2ContextMenuRequestedEventArgs2` to be notified when
  /// suggestions become available, then call this method again.
  /// When `state` is `COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_AVAILABLE` or
  /// `COREWEBVIEW2_SPELL_CHECK_READINESS_ERROR`, no suggestions will arrive.
  HRESULT GetSpellCheckInfo(
      [out] LPWSTR* misspelledWord,
      [out] COREWEBVIEW2_SPELL_CHECK_READINESS* state,
      [out, retval] ICoreWebView2StringCollection** suggestions);
}

/// Extends ICoreWebView2ContextMenuRequestedEventArgs with methods to apply
/// spellcheck corrections and subscribe to asynchronous suggestion delivery.
[uuid(e4a8f3b2-6c1d-4e9a-b5f7-2d8c9a0e1b34), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuRequestedEventArgs2
    : ICoreWebView2ContextMenuRequestedEventArgs {
  /// Applies the selected spellcheck suggestion by replacing the misspelled
  /// word in the currently focused editable field. The `suggestion` parameter
  /// must be one of the strings obtained from the `suggestions` collection
  /// returned by `ICoreWebView2ContextMenuTarget2::GetSpellCheckInfo`.
  /// The runtime handles all editing internally, including routing to the
  /// correct frame for nested iframes.
  HRESULT ApplySpellCheckSuggestion([in] LPCWSTR suggestion);

  /// Registers an event handler for `SpellCheckSuggestionsReady`. This fires
  /// when asynchronous spellcheck suggestions become available. If suggestions
  /// are already in `READY` state at registration time, the handler fires
  /// immediately and synchronously.
  HRESULT add_SpellCheckSuggestionsReady(
      [in] ICoreWebView2SpellCheckSuggestionsReadyEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes the event handler previously added with
  /// `add_SpellCheckSuggestionsReady`.
  HRESULT remove_SpellCheckSuggestionsReady(
      [in] EventRegistrationToken token);
}
```

## .NET/C#

```csharp
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2SpellCheckReadiness
    {
        Ready = 0,
        NotReady = 1,
        NotAvailable = 2,
        Error = 3,
    };

    runtimeclass CoreWebView2ContextMenuTarget
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ContextMenuTarget2")]
        {
            String MisspelledWord { get; };
            CoreWebView2SpellCheckReadiness SpellCheckReadiness { get; };
            IVectorView<String> SpellCheckSuggestions { get; };
        }
    }

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ContextMenuRequestedEventArgs2")]
        {
            void ApplySpellCheckSuggestion(String suggestion);
            event Windows.Foundation.TypedEventHandler<
                CoreWebView2ContextMenuRequestedEventArgs, Object>
                SpellCheckSuggestionsReady;
        }
    }
}
```
