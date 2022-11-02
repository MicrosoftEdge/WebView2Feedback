Direct Message Channel
===

# Background
Currently, WebView2 cross-platform (Windows, Mac) already have a set of post message APIs (native [PostWebMessageAsJson](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1418.22#postwebmessageasjson) and [PostWebMessageAsString](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1418.22#postwebmessageasstring) APIs, JavaScript [window.chrome.webview.postMessage](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1418.22#add_webmessagereceived) API), to allow WebView2 host app native code and WebView2 web code to post messages to each other. However, we can see 2 problems here:

1. Messages between renderer and host app main process are routed via the WebView2 runtime process (i.e., the browser process), which means 2 IPC hops.

2. Host app child processes cannot leverage WebView2 post message APIs, which means, if a child process wants to talk to a renderer, an additional IPC hop is needed between host app main process and the child process.

To overcome above problems, `Direct Message Channel`(DMC) is designed to enable host app native code and WebView2 web code to talk directly via a set of post message APIs. Here `directly` means all messages are transferred on a direct OS IPC channel (named pipe on Windows or Mach port on Mac) between the 2 peer processes (one is the host app main process or child process, the other is renderer process), with no need to involve other processes. You can create multiple direct message channels over same host<=>renderer process pair. Except main frame, direct message channel is also supported in IFrame.

Multiple interfaces/APIs are exposed to support the direct message channel. On web side, `window.chrome.webview.getDirectMessageChannel` is exposed to request direct message channel object. On this channel object, you can `postMessage` to native side or listening to `disconnect`|`message` events to receive native messages. On native side, you can capture DirectMessageChannelCreated event raised by the request from web code and then you can get the `DirectMessageChannel` channel from event args. Through this channel, you can `PostWebMessageAsJson|String` to web side or listen to `WebMessageReceived` event to receive messages from web side. You can listen to `ChannelClosed` event to get notified when the channel is closed from web side, for example, when navigating away from current page.

Direct message channel can also be transfered to host app child process to recreate and establish the direct communication tunnel between host app child process and WebView2 runtime renderer process.
You can call `TakeTransferableBlobAndInvalidate` API of DirectMessageChannel object to create a transferable blob that can be sent to child process. It will also invalidate current DirectMessageChannel object, and set it to transferable state. Please note that this API cannot be called on a direct message channel that has already been started. Recreating the DirectMessageChannel can be done by passing this blob to `ReCreateDirectMessageChannel` API of WebView2 environment. Please also note that direct message channel can be started on a different thread it's created, but it must be created on the same thread the WebView2 environment is created.

# Examples
## DirectMessageChannel
In WebView2 web code, you can call `window.chrome.webview.getDirectMessageChannel(name)` to request bidirectional
direct message channel communication tunnel to host app native code. Direct message channel is also
suported in IFrame and you can create dmc between IFrame and host app.
 ```html
</head>
  <script>
    // direct message channel object.
    let dmc = null;
    let dmc2 = null;

    function getDirectMessageChannelByName(name) {
        return new Promise((resolve, reject) => {
            window.chrome.webview.getDirectMessageChannel(name).then(channel => {
                // Register disconnect event listener on dmc to release object when the channel is disconnected.
                channel.addEventListener('disconnect', arg => {
                    if (dmc === channel) {
                        dmc = null;
                    } else if (dmc2 ===  channel) {
                        dmc2 = null;
                    }
                });
                // Register message event listener on dmc to receive messages from host app native
                // code.
                channel.addEventListener('message', arg => {
                    // arg.data is the received string or json data. Parse and process the data in
                    // web code.
                    document.getElementById("messages-from-host").value
                        += "From DMC " + channel.channelName + ": " + JSON.stringify(arg.data) + "\n";;
                    if ("WindowBounds" in arg.data) {
                        document.getElementById("window-bounds").value = arg.data.WindowBounds;
                    }
                });
                resolve(channel);
            }, error => {
                // The direct message channel request is rejected either by host app native code calling channel 
                // Reject function or with some other errors.
                reject(error);
            });

        });
    }

    // You can create multiple channels over the same host<=>renderer process pair. Please note that
    // the channel name is not identifier. You can even create different dmcs with same channel name.
    getDirectMessageChannelByName("Testing_Direct_Message_Channel").then(channel => {
        dmc = channel;
    });

    getDirectMessageChannelByName("Testing_Direct_Message_Channel2").then(channel => {
        dmc2 = channel;
    });

    // Create IFrame and all dmc APIs work in IFrame as well.
    createIFrame() {
        var i = document.createElement("iframe");
        i.src = "https://appassets.example/ScenarioDirectWebMessage.html";
        i.scrolling = "auto";
        i.frameborder = "0";
        i.height = "90%";
        i.width = "100%";
        i.name = "iframe_name";
        var div = document.getElementById("div_iframe");
        div.appendChild(i); div.style.display = 'block';
    };

    // Web code post message to native code to request setting host app title text via the dmc
    // communication tunnel.
    function SetTitleText() {
        dmc.postMessage("SetTitleText TitleFromWeb");
    }

    // Web code post message to native code to request getting the host app window bounds via the
    // dmc2 communication tunnel.
    function GetWindowBounds() {
        dmc2.postMessage("GetWindowBounds");
    }
  </script>
</head>
<body>
  <textarea id="messages-from-host" rows="10" cols="150" readonly></textarea><br>

  <input type="text" id="title-text" />
  <button onclick="SetTitleText()">Send</button>

  <button onclick="GetWindowBounds()">Get window bounds</button><br>
  <textarea id="window-bounds" rows="4" readonly></textarea>
</body>
```
In host app native code, you can register handlers to catch the `DirectMessageChannelCreated` event
on CoreWebView2 or CoreWebView2Frame which is raised by the getDirectMessageChannel request from web code.
Then you can get the direct message channel object from the event args and rely on this channel to
post web messages to web code. You can also register `WebMessageReceived` event handler on this channel
to receive messages from web code. Please note that you must call `channel->Start()` to start the
communication tunnel before you can really post or receive messages via the channel.
```cpp
static constexpr WCHAR c_samplePath[] = L"ScenarioDirectWebMessage.html";
static constexpr WCHAR c_testingChannelName1[] = L"Testing_Channel_1";
static constexpr WCHAR c_testingChannelName2[] = L"Testing_Channel_2";

ScenarioDirectWebMessage::ScenarioDirectWebMessage(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    m_sampleUri = m_appWindow->GetLocalUri(c_samplePath);

    ComPtr<ICoreWebView2Settings> settings;
    CHECK_FAILURE(m_webView->get_Settings(&settings));

    // Make sure web message is enabled.
    CHECK_FAILURE(settings->put_IsWebMessageEnabled(TRUE));

    wil::com_ptr<ICoreWebView2_16> webView2_16 =
        m_webView.try_query<ICoreWebView2_16>();
    if (!webView2_16)
    {
        return;
    }

    // Register a handler for the `DirectMessageChannelCreated` event. This example demonstrates
    // how to capture the direct message channel in native code and rely on the channel to post
    // messages to or receive messages from WebView2 web code.
    CHECK_FAILURE(webView2_16->add_DirectMessageChannelCreated(
        Microsoft::WRL::Callback<ICoreWebView2DirectMessageChannelCreatedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2DirectMessageChannelCreatedEventArgs* args) -> HRESULT
            {
                wil::com_ptr<ICoreWebView2DirectMessageChannel> channel;
                CHECK_FAILURE(args->get_DirectMessageChannel(&channel));
                wil::unique_cotaskmem_string url;
                CHECK_FAILURE(channel->get_Url(&url));
                if (url.get() != m_sampleUri)
                {
                    // Unexpected url, ignore the channel so that it gets destroyed.
                }
                wil::unique_cotaskmem_string channelNameRaw;
                CHECK_FAILURE(channel->get_ChannelName(&channelNameRaw));
                std::wstring channelName = channelNameRaw.get();
                if (channelName.compare(c_testingChannelName1) == 0)
                {
                    m_testingChannel1 = channel;
                }
                else if (channelName.compare(c_testingChannelName2) == 0)
                {
                    m_testingChannel2 = channel;
                }

                // The message tunnel gets connected only after calling dmc `Start` function,
                // otherwise, it is always in pending status. You can also call `Close`
                // function to reject or close the connection.
                channel->Start();

                // Post first string message to web via the channel.
                std::wstring helloMessage =
                    L"Hey, this is the first message from host app on DMC: " + channelName;
                channel->PostWebMessageAsString(helloMessage.c_str());

                // Register a handler for the `WebMessageReceived` event on the channel. You
                // will get the messages posted from web code via the channel in event args.
                channel->add_WebMessageReceived(
                    Microsoft::WRL::Callback<
                        ICoreWebView2DirectWebMessageReceivedEventHandler>(
                        [this](
                            ICoreWebView2DirectMessageChannel* sender,
                            ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT
                        {
                            wil::unique_cotaskmem_string uri;
                            CHECK_FAILURE(args->get_Source(&uri));

                            // Always validate that the origin of the message is what you
                            // expect.
                            if (uri.get() != m_sampleUri)
                            {
                                // Ignore messages from untrusted sources.
                                return S_OK;
                            }
                            wil::unique_cotaskmem_string messageRaw;
                            HRESULT hr = args->TryGetWebMessageAsString(&messageRaw);
                            if (hr == E_INVALIDARG)
                            {
                                // Was not a string message. Ignore.
                                return S_OK;
                            }
                            // Any other problems are fatal.
                            CHECK_FAILURE(hr);
                            std::wstring message = messageRaw.get();

                            if (message.compare(0, 13, L"SetTitleText ") == 0)
                            {
                                // Received `SetTitleText` message from web to set the app title.
                                m_appWindow->SetDocumentTitle(message.substr(13).c_str());
                            }
                            else if (message.compare(L"GetWindowBounds") == 0)
                            {
                                // Received `GetWindowBounds` message from web then post the
                                // host app window bounds info(json) back to web via the channel.
                                RECT bounds = m_appWindow->GetWindowBounds();
                                std::wstring reply =
                                    L"{\"WindowBounds\":\"Left:" +
                                    std::to_wstring(bounds.left) + L"\\nTop:" +
                                    std::to_wstring(bounds.top) + L"\\nRight:" +
                                    std::to_wstring(bounds.right) + L"\\nBottom:" +
                                    std::to_wstring(bounds.bottom) + L"\"}";
                                CHECK_FAILURE(sender->PostWebMessageAsJson(reply.c_str()));
                            }
                            return S_OK;
                        })
                        .Get(),
                    nullptr);

                // Register a handler for the `ChannelClosed` event on the channel to get
                // notified when dmc is closed from renderer process, e.g., navigating from
                // current page.
                channel->add_ChannelClosed(
                    Microsoft::WRL::Callback<
                        ICoreWebView2DirectMessageChannelClosedEventHandler>(
                        [this](ICoreWebView2DirectMessageChannel* sender, IUnknown* args)
                            -> HRESULT
                        {
                            // Do something regarding the dmc closd event.
                            return S_OK;
                        })
                        .Get(),
                    nullptr);

                return S_OK;
            })
            .Get(),
        &m_directMessageChannelCreatedToken));

    // Register a handler for the `DirectMessageChannelCreated` event on IFrame. This example
    // demonstrates how to capture the direct message channel in IFrame and rely on the channel
    // to post messages to or receive messages from web code.
    wil::com_ptr<ICoreWebView2_16> webview2_16 = m_webView.try_query<ICoreWebView2_16>();
    if (webview2_16)
    {
        CHECK_FAILURE(webview2_16->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](
                    ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    wil::com_ptr<ICoreWebView2Frame4> webviewFrame4 =
                        webviewFrame.try_query<ICoreWebView2Frame4>();
                    if (!webviewFrame4)
                    {
                        return S_OK;
                    }
                    CHECK_FAILURE(webviewFrame4->add_DirectMessageChannelCreated(
                        Microsoft::WRL::Callback<
                            ICoreWebView2FrameDirectMessageChannelCreatedEventHandler>(
                            [this](
                                ICoreWebView2Frame* sender,
                                ICoreWebView2DirectMessageChannelCreatedEventArgs* args)
                                -> HRESULT
                            {
                                wil::com_ptr<ICoreWebView2DirectMessageChannel> channel;
                                CHECK_FAILURE(args->get_DirectMessageChannel(&channel));
                                wil::unique_cotaskmem_string url;
                                CHECK_FAILURE(channel->get_Url(&url));
                                if (url.get() != m_sampleUri)
                                {
                                    // Unexpected url, ignore the channel so that it gets
                                    // destroyed.
                                    return S_OK;
                                }
                                wil::unique_cotaskmem_string channelNameRaw;
                                CHECK_FAILURE(channel->get_ChannelName(&channelNameRaw));
                                std::wstring channelName = channelNameRaw.get();
                                if (channelName.compare(c_testingChannelName1) == 0)
                                {
                                    m_testingChannel1InFrame = channel;
                                }
                                else if (channelName.compare(c_testingChannelName2) == 0)
                                {
                                    m_testingChannel2InFrame = channel;
                                }

                                // The message tunnel gets connected only after calling dmc
                                // `Start` function, otherwise, it is always in pending status.
                                channel->Start();

                                // Similar API usage as the examples in main page
                                // channel->PostWebMessageAsString(helloMessage);
                                // channel->add_WebMessageReceived(callback)
                                // channel->add_ChannelClosed(callback);

                                return S_OK;
                            })
                            .Get(),
                        &m_frameDirectMessageChannelCreatedToken));
                    return S_OK;
                })
                .Get(),
            &m_frameCreatedToken));
    }

    CHECK_FAILURE(m_webView->Navigate(m_sampleUri.c_str()));
}
```

## DirectMessageChannel in Host App Child Process
Except capturing the direct message channel on host app main process and setting up the direct communication
tunnel between host app main process and WebView2 runtime renderer process, you can also set up the direct
message channel between any child process of host app and renderer process via APIs exposed on channel
`TakeTransferableBlobAndInvalidate` and `ReCreateDirectMessageChannel`.
```cpp
// On host app main proces, call `channel->TakeTransferableBlobAndInvalidate(handle, &blob)` to get the direct message
// channel blob data and invalidate its state, then transfer the channel info blob data to child process via
// the host app main-child process inner communication tunnel.
void ScenarioDirectWebMessage::WriteChannelBlobToChildDMCPorcess(
    ICoreWebView2StagingDirectMessageChannel* channel)
{
    wil::unique_cotaskmem_string blob;
    // Take the channel info blob data and invalidate the channel state so that it's trasnferable with the handle of
    // target child process.
    CHECK_FAILURE(channel->TakeTransferableBlobAndInvalidate(handle, &blob));
    std::wstring channelInfo = (std::wstring)blob.get();

    // Rely on the host app main-child process inner communication tunnel(e.g., NamedPipe on Windows) to write
    // the channel info blob data to child process.
    DWORD dataWritten;
    HANDLE hPipe = CreateFile(
        TEXT(NAMED_PIPE_DMC), GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hPipe != INVALID_HANDLE_VALUE)
    {
        WriteFile(
            hPipe, channelInfo.c_str(), ((DWORD)channelInfo.length() + 1) * 2, &dataWritten,
            NULL);

        CloseHandle(hPipe);
    }
}

// In child process, you need to create WebView2 environment and in the environment creation
// completed callback, call environment's `ReCreateDirectMessageChannel` API with the channel info
// blob data to recreate the direct message channel.
HRESULT ChildProcessMessageChannel::OnCreateEnvironmentCompleted(
    HRESULT result,
    ICoreWebView2Environment* environment) {
  if (result != S_OK)
    return result;

  auto webViewEnvironment11 =
      ((wil::com_ptr<ICoreWebView2Environment>)environment)
          .try_query<ICoreWebView2Environment11>();

  if (webViewEnvironment11) {
    // Recreate the direct message channel object based on the blob data `m_directMessageChannelBlob`.
    // `m_directMessageChannel` is the recreated direct message channel in child process.
    CHECK_FAILURE(webViewEnvironment11->ReCreateDirectMessageChannel(
        const_cast<wchar_t*>(m_directMessageChannelBlob),
        &m_directMessageChannel));

    if (!m_directMessageChannel)
      return E_INVALIDARG;

    // Start the channel. The message tunnel gets really connected only after calling dmc `Start`
    // function, otherwise, it is always in pending status.
    m_directMessageChannel->Start();

    // Similar API usage as the examples in above main process
    // m_directMessageChannel->PostWebMessageAsString(helloMessage);
    // m_directMessageChannel->add_WebMessageReceived(callback)
    // m_directMessageChannel->add_ChannelClosed(callback);
  }

  return S_OK;
}
```
# API Details
```
/// This is the ICoreWebView2StagingDirectMessageChannel interface.
[uuid(D73691D4-BF9C-4536-8768-C0F3B73126D4), object, pointer_default(unique)]
interface ICoreWebView2StagingDirectMessageChannel : IUnknown {
  /// This is the |channel_name| specified by JS
  /// `window.chrome.webview.getDirectMessageChannel(channel_name)`.
  [propget] HRESULT ChannelName([out, retval] LPWSTR* channelName);

  /// The web page url.
  [propget] HRESULT Url([out, retval] LPWSTR* url);

  /// Starts the direct message channel.
  /// This will complete the connection to the named mojo pipe in the
  /// associated renderer process. Once this has been started, the
  /// message channel is bound to the thread, and cannot be transferred
  /// via `TakeTransferableBlobAndInvalidate`.
  HRESULT Start();

  /// Closes the direct message channel.
  /// The direct message channel cannot be restarted once it is closed.
  /// This call will behave differently depending on the current state:
  ///    1) if the channel has not yet been started, this will tell the
  ///       renderer side that this channel should be abandoned, i.e.,
  ///       rejecting the promise of JavaScript call
  ///       `chrome.webview.getDirectMessageChannel()`.
  ///    2) if the channel has already been started, this will lead the
  ///       renderer side JavaScript object `WebViewDirectMessageChannel`
  ///       to raise a `disconnect` event.
  HRESULT Close();

  /// Post the specified webMessage to the top level document or frame
  /// that this direct message channel is associated with.
  /// The document or frame receives the message via the corresponding
  /// JavaScript `WebViewDirectMessageChannel` object of this channel.
  ///
  /// Refer to ICoreWebView2::PostWebMessageAsJson for more information.
  HRESULT PostWebMessageAsJson([in] LPCWSTR webMessageAsJson);

  /// Posts a message that is a simple string rather than a JSON string
  /// representation of a JavaScript object.  This behaves in exactly the same
  /// manner as `PostWebMessageAsJson`, but the `data` property of the event
  /// arg of the direct message is a string with the
  /// same value as `webMessageAsString`.  Use this instead of
  /// `PostWebMessageAsJson` if you want to communicate using simple strings
  /// rather than JSON objects.
  HRESULT PostWebMessageAsString([in] LPCWSTR webMessageAsString);

  /// Creates a transferable blob that can be sent to another process to
  /// recreate the `DirectMessageChannel` with given handle of that process.
  /// This will invalidate the current direct message channel object, and prevent
  /// it from being started. This cannot be called on a direct message channel
  /// that has already been started, and is thus bound to the current thread.
  /// Recreating the DirectMessageChannel can be done by passing this blob
  /// to `ReCreateDirectMessageChannel' of the WebView environment.
  HRESULT TakeTransferableBlobAndInvalidate(
      [in] HANDLE handle,
      [out, retval] LPWSTR* directMessageChannelBlob);

  /// Add an event handler for the `WebMessageReceived` event.
  /// `WebMessageReceived` runs when the
  /// `ICoreWebView2Settings::IsWebMessageEnabled` setting is set and the
  /// top-level document of the WebView runs
  /// `WebViewDirectMessageChannel` object's `postMessage` method.  The `postMessage`
  /// function is `void postMessage(object)` where object is any object
  /// supported by JSON conversion.
  ///
  /// Refer to ICoreWebView2::add_WebMessageReceived for more information.
  HRESULT add_WebMessageReceived(
      [in] ICoreWebView2StagingDirectWebMessageReceivedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_WebMessageReceived`.
  HRESULT remove_WebMessageReceived(
      [in] EventRegistrationToken token);

  /// This event runs when the direct message channel is closed on WebView document, e.g., close
  /// the document or navigate away from the document.
  HRESULT add_ChannelClosed(
      [in] ICoreWebView2StagingDirectMessageChannelClosedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_ChannelClosed`.
  HRESULT remove_ChannelClosed(
      [in] EventRegistrationToken token);
}


/// Receives `WebMessageReceived` events for direct message channel.
[uuid(22D53EF3-1ED0-4532-B399-D3830D96EC7F), object, pointer_default(unique)]
interface ICoreWebView2StagingDirectWebMessageReceivedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingDirectMessageChannel* sender,
      [in] ICoreWebView2WebMessageReceivedEventArgs* args);
}

[uuid(573B5EE5-21C7-4E9F-AE33-C65BD085ACEE), object, pointer_default(unique)]
interface ICoreWebView2StagingDirectMessageChannelClosedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke(
      [in] ICoreWebView2StagingDirectMessageChannel* sender,
      [in] IUnknown* args);
}

[uuid(D9C99C1D-E657-46D4-99E6-40D27464A086), object, pointer_default(unique)]
interface ICoreWebView2StagingDirectMessageChannelCreatedEventHandler : IUnknown {
  HRESULT Invoke(
    [in] ICoreWebView2* sender,
    [in] ICoreWebView2StagingDirectMessageChannelCreatedEventArgs* args);
}

[uuid(D1A53B0A-247A-4AAC-8A28-048F94DF55EC), object, pointer_default(unique)]
interface ICoreWebView2StagingDirectMessageChannelCreatedEventArgs : IUnknown {
  /// Provides the newly created channel object. Once a direct message channel
  /// has been created, Start() must be called to complete the mojo connection
  /// and begin posting and receiving web messages. If the direct message
  /// channel has not been started yet, then TakeTransferableBlobAndInvalidate
  /// may be used to transfer this direct message channel to a child process
  /// of the host app.
   [propget] HRESULT DirectMessageChannel(
      [out, retval] ICoreWebView2StagingDirectMessageChannel** channel);
}

[uuid(276f1679-c5ce-4739-b0f0-615196a1b65e), object, pointer_default(unique)]
interface ICoreWebView2Staging4 : IUnknown {
  /// This event runs when the top-level document of the WebView runs
  /// `chrome.webview.getDirectMessageChannel()`.
  /// A direct message channel is to allow for single hop IPC between host app and a renderer process.
  HRESULT add_DirectMessageChannelCreated(
      [in] ICoreWebView2StagingDirectMessageChannelCreatedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DirectMessageChannelCreated`.
  HRESULT remove_DirectMessageChannelCreated(
      [in] EventRegistrationToken token);
}

[uuid(B0C00DA1-0297-4B80-BA70-54BF40AF4835), object, pointer_default(unique)]
interface ICoreWebView2StagingFrame3 : IUnknown {
  /// This event runs when the document of the frame runs `chrome.webview.getDirectMessageChannel()`.
  /// A direct message channel is to allow for single hop IPC between host app and a renderer process.
  HRESULT add_DirectMessageChannelCreated(
      [in] ICoreWebView2StagingFrameDirectMessageChannelCreatedEventHandler* handler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_DirectMessageChannelCreated`.
  HRESULT remove_DirectMessageChannelCreated(
      [in] EventRegistrationToken token);
}

[uuid(DA0CACDF-E470-4827-B7F0-D7767AE46BF3), object, pointer_default(unique)]
interface ICoreWebView2StagingFrameDirectMessageChannelCreatedEventHandler : IUnknown {
  HRESULT Invoke(
    [in] ICoreWebView2Frame* sender,
    [in] ICoreWebView2StagingDirectMessageChannelCreatedEventArgs* args);
}

[uuid(bc308ed0-fcd2-4f79-a0e4-5e7b2f109bb9), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment3 : IUnknown {
  /// Recreates a direct message channel from a blob to allow for single hop IPC
  /// between host app's child process and a renderer process.
  HRESULT ReCreateDirectMessageChannel(
    [in] LPCWSTR directMessageChannelBlob,
    [out, retval] ICoreWebView2StagingDirectMessageChannel** directMessageChannel);
}

/// Additional options used to create WebView2 Environment. A default implementation is
/// provided in `WebView2EnvironmentOptions.h`.
[uuid(FF85C98A-1BA7-4A6B-90C8-2B752C89E9E2), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions3 : IUnknown {

  /// Gets the `OnlyUsedForDirectMessageChannel` property.
  /// The property indicates whether the environment is only used to recreate direct message
  /// channel. Once set to true, the environment created with this option can only be used to
  /// recreate direct message channel and cannot be used to create WebView controller. Default to
  /// false.
  [propget] HRESULT OnlyUsedForDirectMessageChannel([out, retval] BOOL* value);

  /// Sets the `OnlyUsedForDirectMessageChannel` property.
  [propput] HRESULT OnlyUsedForDirectMessageChannel([in] BOOL value);
}
```