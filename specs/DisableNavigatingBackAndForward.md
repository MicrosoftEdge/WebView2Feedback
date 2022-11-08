# API spec for disable navigating back/forward

# Background
This problem was first proposed by a developer on GitHub, who wants to prevent mouse Xbutton1 and XButton2. The reason for their superior level is to prevent users navigating back or forward.
Afterwards, Teams made similar demands. They wanted a mechanism which could support them in controlling the behaviors of `go back` and `go forward` freely, like disabling them.

@Haichao Zhu has already finished some work on letting application developers handle all input and decide whether to suppress. This should be solvable in a generic way, as @Nic Champagne Williamson said. However, this feature hasn’t been released yet, and it might be better if we could provide a simpler and more direct way. 

Therefore, our job is to provide a mechanism for developers to disable navigating back and forward without effort. 


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
                int entry_offset;
                CHECK_FAILURE(stage_args->get_NavigationEntryOffset(&entry_offset));
                if (entry_offset == -1 || entry_offset == 1) {
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
    if (e.NavigationEntryOffset == -1 || e.NavigationEntryOffset == 1) {
        e.Cancel = true;
    }
}
```

# API Details
#### Win32 C++

```c++
/// Extend `NavigationStartingEventArgs` by adding more information.
[uuid(39A27807-2365-470B-AF28-885502121049), object, pointer_default(unique)]
interface ICoreWebView2NavigationStartingEventArgs3 : ICoreWebView2NavigationStartingEventArgs2 {

  /// Get the entry offset of this navigation, which contains information about whether for back or forward.
  ///
  /// MSOWNERS: pengyuanwang@microsoft.com
  [propget] HRESULT NavigationEntryOffset([out, retval] int* entry_offset);
}
```

#### .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2NavigationStartingEventArgs
    {
        /// 
        public int NavigationEntryOffset
        {
            get
            {
                try
                {
                    return
                    _nativeICoreWebView2NavigationStartingEventArgs3.NavigationEntryOffset;

                }
                catch (InvalidCastException ex)
                {
                    if (ex.HResult == -2147467262)  // UI_E_WRONG_THREAD
                        throw new InvalidOperationException($"{nameof(CoreWebView2)} members can only be accessed from the UI thread.", ex);

                    throw ex;
                }
                catch (System.Runtime.InteropServices.COMException ex)
                {
                    if (ex.HResult == -2147019873)  // 0x8007139F
                        throw new InvalidOperationException($"{nameof(CoreWebView2)} members cannot be accessed after the WebView2 control is disposed.", ex);

                    throw ex;
                }
            }
        }
    }
}
```


# Appendix
Relative scenario could be found here: https://dev.azure.com/microsoft/Edge/_workitems/edit/42081893.

Design doc and reviews could be found here: https://microsoftapc-my.sharepoint.com/:w:/g/personal/pengyuanwang_microsoft_com/Ecu4x6kcjqxNrmvqQW7jr0QBCbHzd1PJ7M3h895rt_l_lg?e=ydF6ez.
