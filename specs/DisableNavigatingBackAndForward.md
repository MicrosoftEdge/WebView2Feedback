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
                COREWEBVIEW2_NAVIGATION_KIND kind;
                CHECK_FAILURE(args3->get_NavigationKind(&kind));
                // disable navigation if it is back/forward
                if (kind == COREWEBVIEW2_NAVIGATION_KIND_BACKORFORWARD)
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
    if (e.NavigationKind == CoreWebView2NavigationKind.BackOrForward)
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
typedef enum COREWEBVIEW2_NAVIGATION_KIND {
  /// A navigation caused by CoreWebView2.Reload(), location.reload(), the end user using F5 or other UX, or other reload mechanisms to reload the current document without modifying the navigation history.
  COREWEBVIEW2_NAVIGATION_KIND_RELOAD,
  /// A navigation back or forward to a different entry in the session navigation history. For example via CoreWebView2.Back(), location.back(), the end user pressing Alt+Left or other UX, or other mechanisms to navigate forward or backward in the current session navigation history.
  COREWEBVIEW2_NAVIGATION_KIND_BACKORFORWARD,
  /// A navigation to a different document. This can be caused by CoreWebView2.Navigate(), window.location.href = '...', or other WebView2 or DOM APIs that navigate to a specific URI.
  COREWEBVIEW2_NAVIGATION_KIND_DIFFERENT,
} COREWEBVIEW2_NAVIGATION_KIND;

/// Extend `NavigationStartingEventArgs` by adding more information.
[uuid(39A27807-2365-470B-AF28-885502121049), object, pointer_default(unique)]
interface ICoreWebView2NavigationStartingEventArgs3 : ICoreWebView2NavigationStartingEventArgs2 {

  /// Indicates if this navigation is reload, back/forward or navigating to a different document 
  [propget] HRESULT NavigationKind(
      [out, retval] COREWEBVIEW2_NAVIGATION_KIND* kind);
}
}
```

#### .NET and WinRT

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    enum CoreWebView2NavigationKind
    {
        Reload = 0,
        BackOrForward = 1,
        Different = 2,
    };
    // ..
    runtimeclass CoreWebView2NavigationStartingEventArgs
    {
        // ICoreWebView2NavigationStartingEventArgs members
        // ..
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2NavigationStartingEventArgs3")]
        {
            // ICoreWebView2NavigationStartingEventArgs3 members
            CoreWebView2NavigationKind NavigationKind { get; };
        }
    }
}
```


# Appendix
Relative scenario could be found here: https://dev.azure.com/microsoft/Edge/_workitems/edit/42081893.

Design doc and reviews could be found here: https://microsoftapc-my.sharepoint.com/:w:/g/personal/pengyuanwang_microsoft_com/Ecu4x6kcjqxNrmvqQW7jr0QBCbHzd1PJ7M3h895rt_l_lg?e=ydF6ez.
