# API spec for disable navigating back/forward

# Background
This problem was first identified by a developer on GitHub, who wants to prevent users navigating
back or forward using any of the built-in shortcut keys or special mouse buttons.

Afterwards, Teams made similar demands. They wanted a mechanism which could support them in
controlling the behaviors of `go back` and `go forward` freely, like disabling them.

@Haichao Zhu has already finished some work on letting application developers handle all input and
decide whether to suppress. 

This should be solvable in a generic way. However, this feature hasn’t been released yet, and it might
be better if we could provide a simpler and more direct way. 

Therefore, our job is to provide a mechanism for developers to disable navigating back and forward
without excessive effort.


# Examples
#### Win32 C++

##### Use `ICoreWebView2NavigationStartingEventArgs3` in `add_NavigationStarting`

```c++
//! [NavigationStarting]
// Register a handler for the NavigationStarting event.
// This handler will check the navigation status, and if the navigation is
// `GoBack` or `GoForward`, it will be canceled.
CHECK_FAILURE(m_webView->add_NavigationStarting(
    Callback<ICoreWebView2NavigationStartingEventHandler>(
        [this](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args)
        -> HRESULT {
            wil::com_ptr<ICoreWebView2NavigationStartingEventArgs3> args3;
            if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args3))))
            {
                COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND history_change =
                    COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND_OTHER;
                CHECK_FAILURE(args3->get_NavigationHistoryChange(&history_change));
                if (history_change != COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND_OTHER)
                {
                     CHECK_FAILURE(args->put_Cancel(true));
                }
            }
            return S_OK;
        })
    .Get(),
    &m_navigationStartingToken));
//! [NavigationStarting]
```

#### .NET and WinRT

#### Use `CoreWebView2NavigationStartingEventArgs` in `NavigationStarting`

```c#
// Register a handler for the NavigationStarting event.
// This handler will check the navigation status, and if the navigation is
// `GoBack` or `GoForward`, it will be canceled.
void WebView_NavigationStarting(object sender, CoreWebView2NavigationStartingEventArgs e)
{
    if (e.NavigationHistoryChange != CoreWebView2NavigationHistoryChangeKind.Other)
    {
        e.Cancel = true;
    }
}
```

# API Details
#### Win32 C++

```c++
// Enums and structs
[v1_enum]
typedef enum COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND {
  /// Indicates a navigation that is going back to a previous entry in the navigation history.
  /// For example, a navigation caused by `CoreWebView2.GoBack` or in script `window.history.go(-1)`.
  COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND_BACK,
  /// Indicates a navigation that is going forward to a later entry in the navigation history.
  /// For example, a navigation caused by `CoreWebView2.GoForward` or in script `window.history.go(1)`.
  COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND_FORWARD,
  /// Indicates a navigation that is not going back or forward to an existing entry in the navigation
  /// history. For example, a navigation caused by `CoreWebView2.Navigate`, or `CoreWebView2.Reload`
  /// or in script `window.location.href = 'https://example.com/'`.
  COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND_OTHER,
} COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND;

/// Extend `NavigationStartingEventArgs` by adding more information.
[uuid(39A27807-2365-470B-AF28-885502121049), object, pointer_default(unique)]
interface ICoreWebView2NavigationStartingEventArgs3 : ICoreWebView2NavigationStartingEventArgs2 {

  /// Indicates if this navigation is going back or forward to an existing entry in the navigation
  /// history.
  [propget] HRESULT NavigationHistoryChange(
      [out, retval] COREWEBVIEW2_NAVIGATION_HISTORY_CHANGE_KIND* history_change);
}
}
```

#### .NET and WinRT

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2NavigationHistoryChangeKind
    {
        Back = 0,
        Forward = 1,
        Other = 2,
    };
    // ..
    runtimeclass CoreWebView2NavigationStartingEventArgs
    {
        // ICoreWebView2NavigationStartingEventArgs members
        // ..
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NavigationStartingEventArgs3")]
        {
            // ICoreWebView2NavigationStartingEventArgs3 members
            CoreWebView2NavigationHistoryChangeKind NavigationHistoryChange { get; };
        }
    }
}
```


# Appendix
Relative scenario could be found here: https://dev.azure.com/microsoft/Edge/_workitems/edit/42081893.

Design doc and reviews could be found here: https://microsoftapc-my.sharepoint.com/:w:/g/personal/pengyuanwang_microsoft_com/Ecu4x6kcjqxNrmvqQW7jr0QBCbHzd1PJ7M3h895rt_l_lg?e=ydF6ez.
