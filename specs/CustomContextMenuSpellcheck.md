Custom Context Menu SpellCheck
===

# Background
When a host application renders a custom context menu via the `ContextMenuRequested` event, spellcheck
suggestions for misspelled words are not available. The browser's built-in spellcheck pipeline resolves
suggestions asynchronously, but there is no mechanism for custom context menu hosts to retrieve or apply
these suggestions.

# Description
We propose a separate `ICoreWebView2ContextMenuSpellCheck` interface, discoverable via `QueryInterface`
from `ICoreWebView2ContextMenuRequestedEventArgs`, that provides spellcheck support for custom context
menus. This adds the ability to:

1. Asynchronously retrieve spellcheck suggestions via a one-shot completion handler.
2. Apply a selected spellcheck suggestion by zero-based index (opaque identifier), preventing arbitrary
   text injection.

The design uses a purely asynchronous approach: the host calls `GetSpellCheckSuggestionsAsync` which
fires the handler exactly once, always asynchronously (posted to the caller's message loop, never
invoked inline). There is no synchronous readiness query.

`QueryInterface` for `ICoreWebView2ContextMenuSpellCheck` returns `E_NOINTERFACE` when spellcheck is
not applicable (e.g., right-click on a correctly-spelled word or non-editable field). This serves as
the availability check. Existing `ContextMenuRequested` consumers are unaffected.

# Examples

## Win32 C++

```cpp
// Inside the ContextMenuRequested handler for an editable target:
args->put_Handled(TRUE);
wil::com_ptr<ICoreWebView2Deferral> deferral;
args->GetDeferral(&deferral);

HMENU hMenu = CreatePopupMenu();

auto spellCheck =
    wil::try_com_query<ICoreWebView2ContextMenuSpellCheck>(args);

if (spellCheck)
{
    AppendMenu(hMenu, MF_GRAYED | MF_STRING, IDM_SUGGESTION_BASE,
               L"Loading suggestions...");

    // Handler always fires asynchronously, never inline.
    spellCheck->GetSpellCheckSuggestionsAsync(
        Callback<ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
            [hMenu](HRESULT errorCode,
                    ICoreWebView2StringCollection* suggestions)
                -> HRESULT
            {
                if (FAILED(errorCode) || !suggestions)
                    return S_OK;

                UINT32 count = 0;
                suggestions->get_Count(&count);

                // Replace placeholder and add suggestion items.
                for (UINT32 i = 0; i < count && i < 5; i++)
                {
                    LPWSTR word = nullptr;
                    suggestions->GetValueAtIndex(i, &word);
                    // ... update menu items with word ...
                    CoTaskMemFree(word);
                }
                return S_OK;
            })
            .Get());
}

// ... add other menu items, show popup with TrackPopupMenu ...

// When the user picks suggestion at index `idx`:
spellCheck->ApplySpellCheckSuggestion(idx);

deferral->Complete();
```

## .NET/WinRT

```csharp
// Inside the ContextMenuRequested handler for an editable target:
args.Handled = true;
var deferral = args.GetDeferral();

var contextMenu = new ContextMenuStrip();
var placeholder = new ToolStripMenuItem("Loading...") { Enabled = false };
contextMenu.Items.Add(placeholder);

// QI returns null if spellcheck is not applicable.
var spellCheck = args as ICoreWebView2ContextMenuSpellCheck;
if (spellCheck != null)
{
    // Handler always fires asynchronously.
    spellCheck.GetSpellCheckSuggestionsAsync().Completed = (op, status) =>
    {
        if (status != AsyncStatus.Completed) return;
        var suggestions = op.GetResults();

        contextMenu.Invoke(() =>
        {
            contextMenu.Items.Remove(placeholder);
            for (int i = 0; i < Math.Min(suggestions.Count, 5); i++)
            {
                int idx = i;
                var item = new ToolStripMenuItem(suggestions[i]);
                item.Click += (_, _) => spellCheck.ApplySpellCheckSuggestion((uint)idx);
                contextMenu.Items.Insert(idx, item);
            }
        });
    };
}

// ... add other menu items, show contextMenu ...
deferral.Complete();
```

# API Details

## Win32 C++

```idl
/// Receives the result of `GetSpellCheckSuggestionsAsync`.
/// The handler is invoked exactly once, always asynchronously (posted to the
/// caller's message loop, never invoked inline during the call to
/// `GetSpellCheckSuggestionsAsync`).
[uuid(c5d6e7f8-9a0b-1c2d-3e4f-5a6b7c8d9e0f), object, pointer_default(unique)]
interface ICoreWebView2GetSpellCheckSuggestionsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2StringCollection* suggestions);
}

/// Provides spellcheck capabilities for custom context menus. Obtained via
/// `QueryInterface` from `ICoreWebView2ContextMenuRequestedEventArgs` when
/// spellcheck is applicable (editable target with a misspelled word and
/// spellcheck enabled). If QI returns `E_NOINTERFACE`, spellcheck is not
/// applicable for this context menu invocation.
[uuid(e4a8f3b2-6c1d-4e9a-b5f7-2d8c9a0e1b34), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuSpellCheck : IUnknown {
  /// Applies the selected spellcheck suggestion by replacing the misspelled
  /// word in the currently focused editable field. The `suggestionIndex`
  /// parameter is a zero-based index into the suggestions collection
  /// delivered by `GetSpellCheckSuggestionsAsync`. Returns `E_INVALIDARG`
  /// if the index is out of range or suggestions have not been resolved yet.
  /// The runtime handles all editing internally, including routing to the
  /// correct frame for nested iframes.
  HRESULT ApplySpellCheckSuggestion([in] UINT32 suggestionIndex);

  /// Asynchronously retrieves spellcheck suggestions for the misspelled word
  /// at the current context menu target. The `handler` is invoked exactly once
  /// when suggestions become available, always asynchronously (posted to the
  /// caller's message loop, never invoked inline during this call).
  /// The handler receives `S_OK` and the suggestions collection on success,
  /// or an error HRESULT and `nullptr` on failure.
  /// Only one handler may be registered. Returns `E_ILLEGAL_METHOD_CALL`
  /// if a handler is already registered.
  HRESULT GetSpellCheckSuggestionsAsync(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}
```

## .NET/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ContextMenuSpellCheck
    {
        void ApplySpellCheckSuggestion(UInt32 suggestionIndex);
        Windows.Foundation.IAsyncOperation<IVectorView<String>>
            GetSpellCheckSuggestionsAsync();
    }
}
```
