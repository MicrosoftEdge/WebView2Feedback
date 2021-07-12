# Background
The WebView2 team has been asked to provide an API to expose the Browser Task
Manager. The Browser Task Manager is a window helpful for debugging that 
displays the different processes associated with the current browser process and 
what they're used for. For instance, it could denote that a particular process 
is a renderer process and would show the different web pages rendered by that 
process. In a chromium browser it can be opened by the end user by pressing 
`Shift+Esc` or from the browser's title bar's context menu's 
`Browser task manager` entry.

At the current time, it is expected that the user will close the Task 
Manager manually, so we do not need to provide an API to close it.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` to provide a `ShowTaskManager` method.
This method will open a new window containing the task manager. If the task 
manager is already opened, this method will do nothing.

# Examples
## C++: Show Task Manager

``` cpp
wil::com_ptr<ICoreWebView2_5> m_webview;

// This method could be called from a menu bar item, such as 
// [Script -> Show Task Manager]. 
void ScriptComponent::ShowTaskManager()
{
    CHECK_FAILURE(m_webview->ShowTaskManager());
}


```

## C#: Show Task Manager
```c#
private WebView2 m_webview;

// This method could be called from a menu bar item, such as 
// [Script -> Show Task Manager]. 
void ShowTaskManager()
{
    m_webview.CoreWebView2.ShowTaskManager();
}
```

# API Details
## C++
```
/// This is a continuation of the `ICoreWebView2_4` interface
[uuid(20d02d59-6df2-42dc-bd06-f98a694b1302), object, pointer_default(unique)]
interface ICoreWebView2_5 : ICoreWebView2_4 {
    /// Shows the Browser Task Manager view as a new window. Does nothing
    /// if run when the Browser Task Manager is already open.
    HRESULT ShowTaskManager();
}
```

## C#
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2
    {
        // There are many methods and properties of ICoreWebView2_* which I am
        // not including here for simplicity. 

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_5")]
        {
            // ICoreWebView2_5 members
            void ShowTaskManager();
        }
    }
}
```
