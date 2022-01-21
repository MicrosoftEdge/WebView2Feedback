sessionId support for DevToolsProtocol method call and event
===

# Background
A web page can have multiple DevToolsProtocol targets. Besides the default target for the top page, there are separate targets for iframes from different origin and web workers.

The underlying DevToolsProtocol supports interaction with other targets by calling the `Target.setAutoAttach` method or the `Target.attachToTarget` method with an explicit targetId which returns a sessionId. The sessionId is also part of `Target.attachedToTarget` event message. Regardless of how the sessionId is obtained, it can be used
in subsequent DevToolsProtocol methods to indicate which session (and therefore which target) the method applies to.
See [DevToolsProtocol Target domain](https://chromedevtools.github.io/devtools-protocol/tot/Target/) for more details.

The DevToolsProtocol event messages also have sessionId field to indicate which target the event comes from.

However, the current WebView2 DevToolsProtocol APIs like [CallDevToolsProtocolMethod](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2#calldevtoolsprotocolmethod)
and [DevToolsProtocolEventReceived](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2devtoolsprotocoleventreceivedeventargs)
don't support sessionId.

To support interaction with different parts of the page, we allow apps to specify a sessionId when calling DevToolsProtocol methods, as well as passing a sessionId to DevToolsProtocol event handlers, with empty string sessionId representing the default target of the top page.

# Conceptual pages (How To)

To use the sessionId support, you must attach to targets with with `flatten` set as `true` when calling `Target.attachToTarget` or `Target.setAutoAttach`. Setting `flatten` as `false` is not supported. If attaching to a target with `flatten` set as `false`, the complete handler will never be invoked when calling DevToolsProtocol methods, and no events will be received from that session.

You can listen to `Target.attachedToTarget` and `Target.detachedFromTarget` events to manage the sessionId for targets, and listen to `Target.targetInfoChanged` event to update target info like url of a target. To filter to specific frames or workers, you could use type, url and title of the target info.

There is also some nuance for DevToolsProtocol's target management. If you are interested in only top page and iframes from different origins on the page, it will be simple and straight forward. All related methods and events like `Target.getTargets`, `Target.attachToTarget`, and `Target.targetCreated` event work as expected.

However, dedicated web workers are not returned from `'Target.getTargets'`, and you have to call DevToolsProtocol method `Target.setAutoAttach` to be able to attach to them.

And shared worker is separate from any page or iframe target, and therefore will not be auto attached. You have to call `Target.attachToTarget` to attach to them. The shared workers can be enumerated with `Target.getTargets`. They are also discoverable, that is, you can call `Target.setDiscoverTargets` to receive `Target.targetCreated` event when a shared worker is created.

To summarize, there are two ways of finding the targets and neither covers all 3 scenarios.

|      | Web pages | Dedicated web workers | Shared workers |
| --- | --- | --- | --- |
| Target.getTargets, Target.setDiscoverTargets, Target.targetCreated, Target.attachToTarget | ✔ | | ✔ |
| Target.setAutoAttach, Target.attachedToTarget | ✔ | ✔ |  |

Also note that all of these methods apply only to direct children. To interact with grandchildren (like a different orign iframe inside a different origin iframe), you have to repeat recursively through the child targets.

# Examples

The example below illustrates how to collect messages logged by console.log calls by JavaScipt code from various parts of the web page, including dedicated web worker.

## Win32 C++
```cpp

void MyApp::AttachConsoleLogHandlers()
{
    // The sessions and targets descriptions are tracked by 2 maps:
    // SessionId to TargetId map:
    //   std::map<std::wstring, std::wstring> m_devToolsSessionMap;
    // TargetId to description label map, where the lable is "<target type>,<target url>".
    //   std::map<std::wstring, std::wstring> m_devToolsTargetLabelMap;
    // GetJSONStringField is a helper function that can retrieve a string field from a json message.
  
    wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver> receiver;
    // Listen to Runtime.consoleAPICalled event which is triggered when console.log is called by script code.
    CHECK_FAILURE(
        m_webView->GetDevToolsProtocolEventReceiver(L"Runtime.consoleAPICalled", &receiver));
    CHECK_FAILURE(receiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) noexcept -> HRESULT
            {
                // Get console.log message details and which target it comes from
                wil::unique_cotaskmem_string parameterObjectAsJson;
                CHECK_FAILURE(args->get_ParameterObjectAsJson(&parameterObjectAsJson));
                std::wstring eventSourceLabel;
                std::wstring eventDetails = parameterObjectAsJson.get();
                wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceivedEventArgs2> args2;
                if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args2))))
                {
                    wil::unique_cotaskmem_string sessionId;
                    CHECK_FAILURE(args2->get_SessionId(&sessionId));
                    if (*sessionId.get())
                    {
                        std::wstring targetId = m_devToolsSessionMap[sessionId.get()];
                        eventSourceLabel = m_devToolsTargetLabelMap[targetId];
                    }
                    // else, leave eventSourceLabel as empty string for the default target of top page.
                }
                // App code to log these events. Empty string eventSourceLabel means the default target of top page.
                // Note that eventSourceLabel is just a label string, no parsing is attempted in LogConsoleLogMessage.
                LogConsoleLogMessage(eventSourceLabel, eventDetails);
                return S_OK;
            })
            .Get(),
        &m_consoleAPICalledToken));
    receiver.reset();
  
    // Track Target and session info via CDP events.
    CHECK_FAILURE(
        m_webView->GetDevToolsProtocolEventReceiver(L"Target.attachedToTarget", &receiver));
    CHECK_FAILURE(receiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) noexcept -> HRESULT
            {
                // A new target is attached, add its info to maps.
                wil::unique_cotaskmem_string jsonMessage;
                CHECK_FAILURE(args->get_ParameterObjectAsJson(&jsonMessage));
                // Note that the sessionId and targetId are there even if the WebView2 Runtime version is old.
                std::wstring sessionId = GetJSONStringField(jsonMessage.get(), L"sessionId");
                std::wstring targetId = GetJSONStringField(jsonMessage.get(), L"targetId");
                m_devToolsSessionMap[sessionId] = targetId;
                std::wstring type = GetJSONStringField(jsonMessage.get(), L"type");
                std::wstring url = GetJSONStringField(jsonMessage.get(), L"url");
                m_devToolsTargetLabelMap.insert_or_assign(targetId, type + L"," + url);
                wil::com_ptr<ICoreWebView2_10> webview2 = m_webView.try_query<ICoreWebView2_10>();
                if (webview2)
                {
                    // Auto-attach to targets further created from this target (identified by its session ID).
                    webview2->CallDevToolsProtocolMethodForSession(
                        sessionId.c_str(), L"Target.setAutoAttach",
                        LR"({"autoAttach":true,"waitForDebuggerOnStart":false,"flatten":true})",
                        nullptr);
                    // Enable Runtime events for the target to receive Runtime.consoleAPICalled from it.
                    webview2->CallDevToolsProtocolMethodForSession(
                        sessionId.c_str(), L"Runtime.enable", L"{}", nullptr);
                }
                return S_OK;
            })
            .Get(),
        &m_targetAttachedToken));
    receiver.reset();
    CHECK_FAILURE(
        m_webView->GetDevToolsProtocolEventReceiver(L"Target.detachedFromTarget", &receiver));
    CHECK_FAILURE(receiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) noexcept -> HRESULT
            {
                // A target is detached, remove it from the maps.
                wil::unique_cotaskmem_string jsonMessage;
                CHECK_FAILURE(args->get_ParameterObjectAsJson(&jsonMessage));
                std::wstring sessionId = GetJSONStringField(jsonMessage.get(), L"sessionId");
                auto session = m_devToolsSessionMap.find(sessionId);
                if (m_devToolsSessionMap.Remove(sessionId, out string targetId))
                {
                    m_devToolsTargetLabelMap.erase(session->second);
                }
                return S_OK;
            })
            .Get(),
        &m_targetDetachedToken));
    receiver.reset();
    CHECK_FAILURE(
        m_webView->GetDevToolsProtocolEventReceiver(L"Target.targetInfoChanged", &receiver));
    CHECK_FAILURE(receiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) noexcept -> HRESULT
            {
                // A target's info like url changed, update it in the target description map.
                wil::unique_cotaskmem_string jsonMessage;
                CHECK_FAILURE(args->get_ParameterObjectAsJson(&jsonMessage));
                // Note that the targetId are there even if the WebView2 Runtime version is old.
                std::wstring targetId = GetJSONStringField(jsonMessage.get(), L"targetId");
                if (m_devToolsTargetLabelMap.find(targetId) !=
                    m_devToolsTargetLabelMap.end())
                {
                    // This is a target that we are interested in, update description.
                    std::wstring type = GetJSONStringField(jsonMessage.get(), L"type");
                    std::wstring url = GetJSONStringField(jsonMessage.get(), L"url");
                    m_devToolsTargetLabelMap[targetId] = type + L"," + url;
                }
                return S_OK;
            })
            .Get(),
        &m_targetInfoChangedToken));
    // Enable Runtime events for the default target of top page to receive Runtime.consoleAPICalled events, which is fired when console.log is called.
    m_webView->CallDevToolsProtocolMethod(L"Runtime.enable", L"{}", nullptr);
    // Auto attach to iframe and dedicated worker targets created from the default target of top page.
    m_webView->CallDevToolsProtocolMethod(
        L"Target.setAutoAttach",
        LR"({"autoAttach":true,"waitForDebuggerOnStart":false,"flatten":true})", nullptr);
}
```
## WinRT and .NET
Note that the sample code uses new APIs without try-catch, so it only works with latest version of Edge WebView2 Runtime.
```c#
// The sessions and targets descriptions are tracked by 2 dictionaries:
// SessionId to TargetId dictionary: m_devToolsSessionMap;
// TargetId to description label dictionary, where the label is "<target type>,<target url>": m_devToolsTargetLabelMap
// GetJSONStringField is a helper function that can retrieve a string field from a json message.

private void CoreWebView2_ConsoleAPICalled(CoreWebView2 sender, CoreWebView2DevToolsProtocolEventReceivedEventArgs args)
{
   // Figure out which target the console.log comes from
   string eventSourceLabel;
   string sessionId = args.SessionId;
   if (sessionId.Length > 0)
   {
      string targetId = m_devToolsSessionMap[sessionId];
      eventSourceLabel = m_devToolsTargetLabelMap[targetId];
   }
   else
   { // empty string means the default target of top page.
     eventSourceLabel = "";
   }
   // App code to log these events. Empty string eventSourceLabel means the default target of top page.
   // Note that eventSourceLabel is just a label string, no parsing is attempted in LogConsoleLogMessage.
   LogConsoleLogMessage(eventSourceLabel, args.ParameterObjectAsJson);
}

private void CoreWebView2_AttachedToTarget(CoreWebView2 sender, CoreWebView2DevToolsProtocolEventReceivedEventArgs args)
{
  // A new target is attached, add its info to maps.
  string jsonMessage = args.ParameterObjectAsJson;
  string sessionId = GetJSONStringField(jsonMessage, L"sessionId");
  string targetId = GetJSONStringField(jsonMessage, L"targetId");
  m_devToolsSessionMap[sessionId] = targetId;
  string type = GetJSONStringField(jsonMessage, L"type");
  string url = GetJSONStringField(jsonMessage, L"url");
  m_devToolsTargetLabelMap[targetId] = $"{type",{url}";
  // Auto-attach to targets further created from this target (identified by its session ID).
  _ = m_webview.CallDevToolsProtocolMethodForSessionAsync("Target.setAutoAttach", sessionId,
        @"{""autoAttach"":true,""waitForDebuggerOnStart"":false,""flatten"":true}");
  // Enable Runtime events to receive Runtime.consoleAPICalled from the target, which is triggered by console.log calls.
  m_webview.CallDevToolsProtocolMethodForSessionAsync(sessionId, "Runtime.enable", "{}");
}

private void CoreWebView2_DetachedFromTarget(CoreWebView2 sender, CoreWebView2DevToolsProtocolEventReceivedEventArgs args)
{
  // A target is detached, remove it from the maps
  string jsonMessage = args.ParameterObjectAsJson;
  string sessionId = GetJSONStringField(jsonMessage, L"sessionId");
  if (m_devToolsSessionMap.ContainsKey(sessionId))
  {
      m_devToolsTargetLabelMap.Remove(m_devToolsSessionMap[sessionId]);
      m_devToolsSessionMap.Remove(sessionId);
  }
}

private void CoreWebView2_TargetInfoChanged(CoreWebView2 sender, CoreWebView2DevToolsProtocolEventReceivedEventArgs args)
{
  // A target's info like url changed, update it in the target description map.
  string jsonMessage = args.ParameterObjectAsJson;
  string targetId = GetJSONStringField(jsonMessage, L"targetId");
  if (m_devToolsTargetLabelMap.ContainsKey(targetId))
  {
    // This is a target that we are interested in, update description.
    string type = GetJSONStringField(jsonMessage, L"type");
    string url = GetJSONStringField(jsonMessage, L"url");
    m_devToolsTargetLabelMap[targetId] = type + L"," + url;
  }
}
  private void AddConsoleLogHandlers()
  {
    m_webview.GetDevToolsProtocolEventReceiver("Runtime.consoleAPICalled").DevToolsProtocolEventReceived += CoreWebView2_ConsoleAPICalled;
    m_webview.GetDevToolsProtocolEventReceiver("Target.attachedToTarget").DevToolsProtocolEventReceived += CoreWebView2_AttachedToTarget;
    m_webview.GetDevToolsProtocolEventReceiver("Target.detachedFromTarget").DevToolsProtocolEventReceived += CoreWebView2_DetachedFromTarget;
    m_webview.GetDevToolsProtocolEventReceiver("Target.targetInfoChanged").DevToolsProtocolEventReceived += CoreWebView2_TargetInfoChanged;
    // Enable Runtime events for the default target of top page to receive Runtime.consoleAPICalled events, which is fired when console.log is called.
    _ = m_webview.CallDevToolsProtocolMethodAsync("Runtime.enable", "{}");
    // Auto attach to iframe and dedicated worker targets created from the default target of top page.
    _ = m_webview.CallDevToolsProtocolMethodAsync("Target.setAutoAttach",
        @"{""autoAttach"":true,""waitForDebuggerOnStart"":false,""flatten"":true}");
  }
```

# API Details
## Win32 C++
```
interface ICoreWebView2_10 : IUnknown {
  /// Runs an asynchronous `DevToolsProtocol` method for a specific session of
  /// an attached target.
  /// There could be multiple `DevToolsProtocol` targets in a WebView.
  /// Besides the top level page, iframes from different origin and web workers
  /// are also separate targets. Attaching to these targets allows interaction with them.
  /// When the DevToolsProtocol is attached to a target, the connection is identified
  /// by a sessionId.
  /// To use this API, you must set `flatten` parameter to true when calling
  /// `Target.attachToTarget` or `Target.setAutoAttach` `DevToolsProtocol` method.
  /// Using `Target.setAutoAttach` is recommended as that would allow you to attach
  /// to dedicated worker target, which is not discoverable via other APIs like
  /// `Target.getTargets`.
  /// For more information about targets and sessions, navigate to
  /// \[DevTools Protocol Viewer\]\[GithubChromedevtoolsDevtoolsProtocolTotTarget\].
  /// For more information about available methods, navigate to
  /// \[DevTools Protocol Viewer\]\[GithubChromedevtoolsDevtoolsProtocolTot\]
  /// The `sessionId` parameter is the sessionId for an attached target.
  /// nullptr or empty string is treated as the session for the default target for the top page.
  /// The `methodName` parameter is the full name of the method in the
  /// `{domain}.{method}` format.  The `parametersAsJson` parameter is a JSON
  /// formatted string containing the parameters for the corresponding method.
  /// The `Invoke` method of the `handler` is run when the method
  /// asynchronously completes.  `Invoke` is run with the return object of the
  /// method as a JSON string.
  ///
  /// \[GithubChromedevtoolsDevtoolsProtocolTot\]: https://chromedevtools.github.io/devtools-protocol/tot "latest (tip-of-tree) protocol - Chrome DevTools Protocol | GitHub"
  /// \[GithubChromedevtoolsDevtoolsProtocolTotTarget\]: https://chromedevtools.github.io/devtools-protocol/tot/Target "Chrome DevTools Protocol - Target domain"

  HRESULT CallDevToolsProtocolMethodForSession(
      [in] LPCWSTR sessionId,
      [in] LPCWSTR methodName,
      [in] LPCWSTR parametersAsJson,
      [in] ICoreWebView2CallDevToolsProtocolMethodCompletedHandler* handler);
}

interface ICoreWebView2DevToolsProtocolEventReceivedEventArgs2 : IUnknown {

  /// The sessionId of the target where the event originates from.
  /// Empty string is returned as sessionId if the event comes from the default session for the top page.
  /// \snippet ScriptComponent.cpp DevToolsProtocolEventReceivedSessionId
  [propget] HRESULT SessionId([out, retval] LPWSTR* sessionId);
}
```

## WinRT and .NET
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2
    {
        // ...
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_10")]
        {
            // ICoreWebView2_10 members
            // This is an overload for: public async Task<string> CallDevToolsProtocolMethodAsync(string methodName, string parametersAsJson);
            public async Task<string> CallDevToolsProtocolMethodForSessionAsync(string sessionId, string methodName, string parametersAsJson);
        }
    }
    
    runtimeclass CoreWebView2DevToolsProtocolEventReceivedEventArgs
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2DevToolsProtocolEventReceivedEventArgs2")]
        {
            String SessionId { get; };
        }
    }
}
```
