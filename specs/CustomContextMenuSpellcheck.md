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

1. Query spellcheck suggestion readiness state and suggestions from the context menu target.
2. Subscribe to an asynchronous notification when spellcheck suggestions become available.
3. Apply a selected spellcheck suggestion to replace the misspelled word in the DOM.

Hosts opt in by calling `QueryInterface` for the new `ICoreWebView2ContextMenuTarget2` and
`ICoreWebView2ContextMenuRequestedEventArgs2` interfaces. Existing `ContextMenuRequested` consumers
are unaffected.

# Examples

## Win32 C++

```cpp
static constexpr INT32 kSuggestionBase = 50000;
static constexpr UINT32 kMaxSuggestions = 5;

// Shared state between the menu builder and the async handler
// that updates the live popup menu in-place.
struct SpellCheckMenuState
{
    HMENU hPopupMenu = nullptr;
    std::vector<std::wstring> suggestionLabels;
    bool suggestionsApplied = false;
};

void ShowCustomContextMenuWithSpellCheck(
    ICoreWebView2* webview,
    ICoreWebView2Controller* controller,
    ICoreWebView2ContextMenuRequestedEventArgs* args)
{
    wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
    CHECK_FAILURE(args->get_ContextMenuTarget(&target));

    BOOL isEditable = FALSE;
    CHECK_FAILURE(target->get_IsEditable(&isEditable));

    if (!isEditable)
        return;

    // Suppress the default context menu; the host will render its own.
    CHECK_FAILURE(args->put_Handled(TRUE));

    // Take a deferral so the runtime keeps the event args alive
    // while the popup menu is open.
    wil::com_ptr<ICoreWebView2Deferral> deferral;
    CHECK_FAILURE(args->GetDeferral(&deferral));

    auto spState = std::make_shared<SpellCheckMenuState>();
    spState->hPopupMenu = CreatePopupMenu();
    HMENU hPopupMenu = spState->hPopupMenu;

    auto target2 = target.try_query<ICoreWebView2ContextMenuTarget2>();
    auto args2 = args.try_query<ICoreWebView2ContextMenuRequestedEventArgs2>();

    // --- Query spellcheck state ---
    COREWEBVIEW2_SPELL_CHECK_READINESS spellState =
        COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_AVAILABLE;

    if (target2 && args2)
    {
        COREWEBVIEW2_SPELL_CHECK_READINESS readiness;
        HRESULT hr = target2->get_SpellCheckReadiness(&readiness);

        if (SUCCEEDED(hr))
            spellState = readiness;

        if (spellState == COREWEBVIEW2_SPELL_CHECK_READINESS_READY)
        {
            // Suggestions available — add them directly.
            wil::com_ptr<ICoreWebView2StringCollection> suggestions;
            target2->get_SpellCheckSuggestions(&suggestions);
            UINT32 count = 0;
            if (suggestions)
                suggestions->get_Count(&count);
            for (UINT32 i = 0; i < count && i < kMaxSuggestions; i++)
            {
                LPWSTR sugRaw = nullptr;
                suggestions->GetValueAtIndex(i, &sugRaw);
                if (sugRaw && sugRaw[0])
                {
                    spState->suggestionLabels.push_back(sugRaw);
                    AppendMenu(hPopupMenu, MF_STRING,
                               kSuggestionBase + i, sugRaw);
                }
                if (sugRaw)
                    CoTaskMemFree(sugRaw);
            }
            spState->suggestionsApplied = true;
        }
        else if (spellState == COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY)
        {
            // Suggestions pending — show placeholder.
            AppendMenu(hPopupMenu, MF_GRAYED | MF_STRING,
                       kSuggestionBase, L"Loading suggestions...");
        }
    }

    // --- Register async handler for in-place update if NOT_READY ---
    if (spellState == COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY
        && args2 && target2)
    {
        EventRegistrationToken token;
        args2->add_SpellCheckSuggestionsReady(
            Callback<ICoreWebView2SpellCheckSuggestionsReadyEventHandler>(
                [spState, target2](
                    ICoreWebView2ContextMenuRequestedEventArgs*,
                    IUnknown*) -> HRESULT
                {
                    if (spState->suggestionsApplied || !spState->hPopupMenu)
                        return S_OK;

                    // Re-query — should be READY now.
                    COREWEBVIEW2_SPELL_CHECK_READINESS st;
                    target2->get_SpellCheckReadiness(&st);

                    wil::com_ptr<ICoreWebView2StringCollection> sc;
                    target2->get_SpellCheckSuggestions(&sc);

                    UINT32 count = 0;
                    if (sc)
                        sc->get_Count(&count);

                    for (UINT32 i = 0; i < count && i < kMaxSuggestions; i++)
                    {
                        LPWSTR sr = nullptr;
                        sc->GetValueAtIndex(i, &sr);
                        if (sr && sr[0])
                        {
                            spState->suggestionLabels.push_back(sr);
                            if (i == 0)
                            {
                                // Replace placeholder with first suggestion.
                                MENUITEMINFOW mii = {};
                                mii.cbSize = sizeof(mii);
                                mii.fMask = MIIM_STRING | MIIM_STATE | MIIM_ID;
                                mii.fState = MFS_ENABLED;
                                mii.wID = kSuggestionBase;
                                mii.dwTypeData = sr;
                                SetMenuItemInfoW(spState->hPopupMenu,
                                                 kSuggestionBase, FALSE, &mii);
                            }
                            else
                            {
                                // Insert additional suggestions.
                                MENUITEMINFOW mii = {};
                                mii.cbSize = sizeof(mii);
                                mii.fMask =
                                    MIIM_STRING | MIIM_STATE | MIIM_ID | MIIM_FTYPE;
                                mii.fType = MFT_STRING;
                                mii.fState = MFS_ENABLED;
                                mii.wID = kSuggestionBase + i;
                                mii.dwTypeData = sr;
                                InsertMenuItemW(spState->hPopupMenu,
                                                i, TRUE, &mii);
                            }
                        }
                        if (sr)
                            CoTaskMemFree(sr);
                    }
                    spState->suggestionsApplied = true;

                    // Force redraw of the live popup menu.
                    HWND hMenuWnd = FindWindowW(L"#32768", nullptr);
                    if (hMenuWnd)
                    {
                        RedrawWindow(hMenuWnd, nullptr, nullptr,
                                     RDW_INVALIDATE | RDW_ERASE |
                                     RDW_FRAME | RDW_ALLCHILDREN);
                    }
                    return S_OK;
                })
                .Get(),
            &token);
    }

    // --- Add standard WebView2 context menu items ---
    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
    CHECK_FAILURE(args->get_MenuItems(&items));
    UINT32 itemCount;
    CHECK_FAILURE(items->get_Count(&itemCount));
    for (UINT32 i = 0; i < itemCount; i++)
    {
        wil::com_ptr<ICoreWebView2ContextMenuItem> current;
        items->GetValueAtIndex(i, &current);
        // ... add each item to hPopupMenu ...
    }

    // --- Show popup menu (blocks, but pumps messages so the
    // SpellCheckSuggestionsReady callback can fire during this) ---
    HWND hWnd;
    controller->get_ParentWindow(&hWnd);
    SetForegroundWindow(hWnd);

    // Convert WebView-relative coordinates to screen coordinates.
    RECT bounds;
    controller->get_Bounds(&bounds);
    RECT clientRect;
    GetClientRect(hWnd, &clientRect);
    POINT topLeft = {clientRect.left, clientRect.top};
    ClientToScreen(hWnd, &topLeft);

    POINT location;
    args->get_Location(&location);

    // Account for DPI scaling.
    double scale = 1.0;
    wil::com_ptr<ICoreWebView2Controller3> ctrl3;
    if (SUCCEEDED(controller->QueryInterface(IID_PPV_ARGS(&ctrl3))))
        ctrl3->get_RasterizationScale(&scale);

    int screenX = bounds.left + topLeft.x + static_cast<int>(location.x * scale);
    int screenY = bounds.top + topLeft.y + static_cast<int>(location.y * scale);

    INT32 selectedCmd = TrackPopupMenu(
        hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD,
        screenX, screenY, 0, hWnd, nullptr);

    spState->hPopupMenu = nullptr;

    // --- Handle selection ---
    if (selectedCmd >= kSuggestionBase &&
        selectedCmd < kSuggestionBase + (INT32)kMaxSuggestions)
    {
        UINT32 idx = selectedCmd - kSuggestionBase;
        if (idx < spState->suggestionLabels.size() && args2)
        {
            args2->ApplySpellCheckSuggestion(
                spState->suggestionLabels[idx].c_str());
        }
    }
    else if (selectedCmd > 0)
    {
        args->put_SelectedCommandId(selectedCmd);
    }

    DestroyMenu(hPopupMenu);
    CHECK_FAILURE(deferral->Complete());
}
```

## .NET/WinRT

```csharp
void ShowCustomContextMenuWithSpellCheck(
    object sender, CoreWebView2ContextMenuRequestedEventArgs args)
{
    var target = args.ContextMenuTarget;

    if (!target.IsEditable)
        return;

    // Suppress the default context menu.
    args.Handled = true;

    // Take a deferral so the runtime keeps the event args alive.
    var deferral = args.GetDeferral();

    try
    {
        CoreWebView2SpellCheckReadiness spellState = target.SpellCheckReadiness;
        IReadOnlyList<string> suggestions = target.SpellCheckSuggestions;

        var contextMenu = new ContextMenuStrip();

        if (spellState == CoreWebView2SpellCheckReadiness.Ready
            && suggestions.Count > 0)
        {
            // Suggestions available — add them directly.
            foreach (string suggestion in suggestions.Take(5))
            {
                var item = new ToolStripMenuItem(suggestion);
                item.Click += (s, e) =>
                {
                    args.ApplySpellCheckSuggestion(suggestion);
                };
                contextMenu.Items.Add(item);
            }
            contextMenu.Items.Add(new ToolStripSeparator());
        }
        else if (spellState == CoreWebView2SpellCheckReadiness.NotReady)
        {
            // Suggestions pending — show placeholder.
            var placeholder = new ToolStripMenuItem("Loading suggestions...")
            {
                Enabled = false
            };
            contextMenu.Items.Insert(0, placeholder);
            contextMenu.Items.Insert(1, new ToolStripSeparator());

            // Handler fires when suggestions resolve
            // or immediately if already resolved.
            args.SpellCheckSuggestionsReady += (s, e) =>
            {
                var readySuggestions = target.SpellCheckSuggestions;
                if (target.SpellCheckReadiness ==
                        CoreWebView2SpellCheckReadiness.Ready
                    && readySuggestions.Count > 0)
                {
                    int index = contextMenu.Items.IndexOf(placeholder);
                    contextMenu.Items.Remove(placeholder);
                    foreach (string suggestion in readySuggestions.Take(5))
                    {
                        var item = new ToolStripMenuItem(suggestion);
                        item.Click += (s2, e2) =>
                        {
                            args.ApplySpellCheckSuggestion(suggestion);
                        };
                        contextMenu.Items.Insert(index++, item);
                    }
                }
            };
        }

        // Add standard WebView2 context menu items.
        foreach (var menuItem in args.MenuItems)
        {
            // ... add each item to contextMenu ...
        }

        contextMenu.Show(webView, webView.PointToClient(Cursor.Position));
    }
    finally
    {
        deferral.Complete();
    }
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
/// spellcheck suggestions when rendering custom menus on editable fields.
[uuid(d3f7e01a-9b5c-4e8f-a1d2-7c6b3e4f5a80), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuTarget2 : ICoreWebView2ContextMenuTarget {
  /// Gets the readiness state of spellcheck suggestions for the current
  /// context menu target.
  ///
  /// When the value is `COREWEBVIEW2_SPELL_CHECK_READINESS_READY`, the
  /// `SpellCheckSuggestions` collection is populated with correction strings.
  /// When the value is `COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_READY`, the
  /// collection is empty; subscribe to `SpellCheckSuggestionsReady` on
  /// `ICoreWebView2ContextMenuRequestedEventArgs2` to be notified when
  /// suggestions become available.
  /// When the value is `COREWEBVIEW2_SPELL_CHECK_READINESS_NOT_AVAILABLE` or
  /// `COREWEBVIEW2_SPELL_CHECK_READINESS_ERROR`, no suggestions will arrive.
  [propget] HRESULT SpellCheckReadiness(
      [out, retval] COREWEBVIEW2_SPELL_CHECK_READINESS* value);

  /// Gets the collection of spellcheck suggestion strings for the misspelled
  /// word at the current context menu target. The collection is empty when
  /// `SpellCheckReadiness` is not `READY`.
  [propget] HRESULT SpellCheckSuggestions(
      [out, retval] ICoreWebView2StringCollection** value);
}

/// Extends ICoreWebView2ContextMenuRequestedEventArgs with methods to apply
/// spellcheck corrections and subscribe to asynchronous suggestion delivery.
[uuid(e4a8f3b2-6c1d-4e9a-b5f7-2d8c9a0e1b34), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuRequestedEventArgs2
    : ICoreWebView2ContextMenuRequestedEventArgs {
  /// Applies the selected spellcheck suggestion by replacing the misspelled
  /// word in the currently focused editable field. The `suggestion` parameter
  /// must be one of the strings obtained from the `SpellCheckSuggestions`
  /// collection on `ICoreWebView2ContextMenuTarget2`.
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

## .NET/WinRT

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
