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

1. Asynchronously retrieve spellcheck suggestions via a one-shot completion handler.
2. Apply a selected spellcheck suggestion to replace the misspelled word in the DOM.

The design uses a purely asynchronous approach: the host always calls `GetSpellCheckSuggestionsAsync`
which fires the handler exactly once  either immediately (if suggestions are already resolved) or
when they become available. There is no synchronous readiness query.

Hosts opt in by calling `QueryInterface` for the new `ICoreWebView2ContextMenuRequestedEventArgs2`
interface. Existing `ContextMenuRequested` consumers are unaffected.

# Examples

## Win32 C++

```cpp
// Inside the ContextMenuRequested handler for an editable target:
args->put_Handled(TRUE);
wil::com_ptr<ICoreWebView2Deferral> deferral;
args->GetDeferral(&deferral);

HMENU hMenu = CreatePopupMenu();

auto args2 =
    wil::try_com_query<ICoreWebView2ContextMenuRequestedEventArgs2>(args);

if (args2)
{
    // Show placeholder while suggestions load.
    AppendMenu(hMenu, MF_GRAYED | MF_STRING, IDM_SUGGESTION_BASE,
               L"Loading suggestions...");

    // Handler fires immediately if resolved, or when ready.
    args2->GetSpellCheckSuggestionsAsync(
        Callback<ICoreWebView2GetSpellCheckSuggestionsCompletedHandler>(
            [hMenu, args2](HRESULT errorCode,
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

// When the user picks a suggestion:
LPWSTR chosenSuggestion = /* label from selected menu item */;
args2->ApplySpellCheckSuggestion(chosenSuggestion);

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

// Handler fires immediately if resolved, or when ready.
args.GetSpellCheckSuggestionsAsync().Completed = (op, status) =>
{
    if (status != AsyncStatus.Completed) return;
    var suggestions = op.GetResults();

    contextMenu.Invoke(() =>
    {
        contextMenu.Items.Remove(placeholder);
        foreach (string s in suggestions.Take(5))
        {
            var item = new ToolStripMenuItem(s);
            item.Click += (_, _) => args.ApplySpellCheckSuggestion(s);
            contextMenu.Items.Insert(0, item);
        }
    });
};

// ... add other menu items, show contextMenu ...
deferral.Complete();
```

# API Details

## Win32 C++

```idl
/// Receives the result of `GetSpellCheckSuggestionsAsync`.
/// The handler is invoked exactly once — either immediately (if suggestions
/// are already resolved when `GetSpellCheckSuggestionsAsync` is called) or
/// when the spellcheck pipeline finishes resolving suggestions.
[uuid(c5d6e7f8-9a0b-1c2d-3e4f-5a6b7c8d9e0f), object, pointer_default(unique)]
interface ICoreWebView2GetSpellCheckSuggestionsCompletedHandler : IUnknown {
  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2StringCollection* suggestions);
}

/// Extends ICoreWebView2ContextMenuRequestedEventArgs with methods to apply
/// spellcheck corrections and asynchronously retrieve suggestions for custom
/// context menus.
[uuid(e4a8f3b2-6c1d-4e9a-b5f7-2d8c9a0e1b34), object, pointer_default(unique)]
interface ICoreWebView2ContextMenuRequestedEventArgs2
    : ICoreWebView2ContextMenuRequestedEventArgs {
  /// Applies the selected spellcheck suggestion by replacing the misspelled
  /// word in the currently focused editable field. The `suggestion` parameter
  /// should be one of the strings obtained from the completion handler passed
  /// to `GetSpellCheckSuggestionsAsync`.
  /// The runtime handles all editing internally, including routing to the
  /// correct frame for nested iframes.
  HRESULT ApplySpellCheckSuggestion([in] LPCWSTR suggestion);

  /// Asynchronously retrieves spellcheck suggestions for the misspelled word
  /// at the current context menu target. The `handler` is invoked exactly once
  /// when suggestions become available. If suggestions are already resolved,
  /// the handler is invoked immediately and synchronously.
  /// The handler receives `S_OK` and the suggestions collection on success,
  /// or an error HRESULT and `nullptr` on failure.
  /// Only one handler can be registered at a time; calling this method again
  /// replaces any previously registered handler.
  HRESULT GetSpellCheckSuggestionsAsync(
      [in] ICoreWebView2GetSpellCheckSuggestionsCompletedHandler* handler);
}
```

## .NET/WinRT

```csharp
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ContextMenuRequestedEventArgs2")]
        {
            void ApplySpellCheckSuggestion(String suggestion);
            Windows.Foundation.IAsyncOperation<IVectorView<String>>
                GetSpellCheckSuggestionsAsync();
        }
    }
}
```
