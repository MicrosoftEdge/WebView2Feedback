IFrame Memory Usage API
===

# Background
The WebView2 team has been asked to provide support for monitoring iframe 
memory usage. The end developer needs to know how much memory each iframe 
consumes. To do that, they need to get the renderer process ID for each 
iframe. However, WebView2 only tracks the render frame host for top-level iframes. 
This limits the [ICoreWebView2Frame2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2frame?view=webview2-1.0.1518.46)
APIs for first-level iframes only. For instance, we raise the FrameCreated 
event for first-level iframes, but not for nested iframes with depth greater than 1. 
Also, WebView2 lacks an API to get the renderer process ID for iframes.
<pre>
                           main_frame  [depth:0]
                         /     |       \
      first_level_iframe_0     ...    first_level_iframe_n             [depth:1, first level iframe]
                |          \                     |
      second_level_iframe_0 ...       second_level_iframe_n ...        [depth:2, second level iframe]
               |
              ...                                                      
</pre> 

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` and `CoreWebView2Frame` to include the 
`RendererProcessId` property and  `RendererProcessIdChanged` event. This property 
stores the renderer process ID for its iframe. This event will be raised whenever 
the renderer process ID is changed for `CoreWebView2` or `CoreWebView2Frame`.

Additionally, we propose to add the `FrameCreated` event to `CoreWebView2Frame`. 
This event is raised when a new iframe is created.

# Examples
C++
```c++
void InitializeEventView(wil::com_ptr<ICoreWebView2> webview)
{
    auto webview2_18 = webview.try_query<ICoreWebView2_18>();
    if (webview2_18) 
    {
        webview2_18->add_FrameCreated(
            Callback<ICoreWebView2FrameCreatedEventHandler>(
                [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args)
                    -> HRESULT {
                    // ...
                    // The new frame created event can be recursively initialized
                    InitializeFrameEventView(webviewFrame);
                    // ...
                    return S_OK;
                })
                .Get(),
            NULL);
        //! [ICoreWebView2:add_RendererProcessIdChanged]
        webview2_18->add_RendererProcessIdChanged(
            Callback<ICoreWebView2RendererProcessIdChangedEventHandler>(
                [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2_18> webview2_18;
                    sender->QueryInterface(IID_PPV_ARGS(&webview2_18));
                    UINT32 processId;
                    //! [ICoreWebView2:get_RendererProcessId]
                    CHECK_FAILURE(webview2_18->get_RendererProcessId(&processId));
                    // Do something when renderer process id has been changed. 
                    // For instance, retrieve the updated memory usage information 
                    // for that main frame. 
                    return S_OK;
                })
                .Get(),
            NULL);
    }
}

void InitializeFrameEventView(
    wil::com_ptr<ICoreWebView2Frame> webviewFrame) 
{
    auto frame5 = webviewFrame.try_query<ICoreWebView2Frame5>();
    if (frame5)
    {
        //! [ICoreWebView2Frame:add_FrameCreated]
        frame5->add_FrameCreated(
            Callback<ICoreWebView2NestedFrameCreatedEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
                {
                    wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                    CHECK_FAILURE(args->get_Frame(&webviewFrame));
                    InitializeFrameEventView(webviewFrame);
                    auto frame5 = webviewFrame.try_query<ICoreWebView2Frame5>();
                    if (frame5)
                    {
                        //! [ICoreWebView2Frame:get_RendererProcessId]
                        UINT32 processId;
                        CHECK_FAILURE(frame5->get_RendererProcessId(&processId));
                        // Do something when renderer process id has been changed. 
                        // For instance, retrieve the updated memory usage information 
                        // for that iframe.  
                    }
                    return S_OK;
                })
                .Get(),
            NULL);
        //! [ICoreWebView2Frame:add_RendererProcessIdChanged]
        frame5->add_RendererProcessIdChanged(
            Callback<ICoreWebView2FrameRendererProcessIdChangedEventHandler>(
                [this](
                    ICoreWebView2Frame* sender,
                    IUnknown* args) -> HRESULT 
                {
                    wil::com_ptr<ICoreWebView2Frame5> frame5;
                    sender->QueryInterface(IID_PPV_ARGS(&frame5));
                    if (frame5) 
                    {
                        //! [ICoreWebView2Frame:get_RendererProcessId]
                        UINT32 processId;
                        CHECK_FAILURE(frame5->get_RendererProcessId(&processId));
                        // Do something when renderer process id has been changed. 
                        // For instance, retrieve the updated memory usage information
                        // for that iframe. 
                    }
                    return S_OK;
                    
                })
                .Get(),
            NULL);
    }
```
C#
```c#
void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
{
    if (e.IsSuccess)
    {
        // ...
        webView.CoreWebView2.FrameCreated += WebView_HandleIFrames;
        // </RendererProcessIdChanged>
        webView.CoreWebView2.RendererProcessIdChanged += WebView_RendererProcessIdChanged;
        // ...
    }
}
void WebView_HandleIFrames(object sender, CoreWebView2FrameCreatedEventArgs args)
{
    _webViewFrames.Add(args.Frame);
    args.Frame.FrameCreated += WebViewFrames_CreatedNestedIFrames;
    // </RendererProcessIdChanged>
    args.Frame.RendererProcessIdChanged += WebViewFrames_RendererProcessIdChanged;
    // ...
}

void WebViewFrames_CreatedNestedIFrames(object sender, CoreWebView2FrameCreatedEventArgs args)
{
    // Add frame created event for webViewFrames
    _webViewFrames.Add(args.Frame);
    // </FrameCreated>
    args.Frame.FrameCreated += WebViewFrames_CreatedNestedIFrames;
    // </RendererProcessIdChanged>
    args.Frame.RendererProcessIdChanged += WebViewFrames_RendererProcessIdChanged;
    // ...
}

void WebView_RendererProcessIdChanged(object sender, object args) 
{
    // </RendererProcessId>
    var processId = webView.CoreWebView2.RendererProcessId;
    // Do something when renderer process id has been changed. 
    // For instance, retrieve the updated memory usage information 
    // for that main frame. 
}
void WebViewFrames_RendererProcessIdChanged(object sender, object args)
{
    bool isWebviewFrame = (sender is CoreWebView2Frame);
    if (isWebviewFrame) 
    {
        // </RendererProcessId>
        var processId = ((CoreWebView2Frame)sender).RendererProcessId;
        // Do something when renderer process id has been changed. 
        // For instance, retrieve the updated memory usage information  
        // for that iframe.
    }
}
```

# API Details
## C++
```c++
interface ICoreWebView2_18;
interface ICoreWebView2Frame5;
interface ICoreWebView2NestedFrameCreatedEventHandler;
interface ICoreWebView2RendererProcessIdChangedEventHandler;
interface ICoreWebView2FrameRendererProcessIdChangedEventHandler;

/// Receives `FrameCreated` event.
// MSOWNERS: wangsongjin@microsoft.com
[uuid(c0e55260-a1bb-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2NestedFrameCreatedEventHandler : IUnknown {
  /// Provides the result for the iframe created event.
  HRESULT Invoke([in] ICoreWebView2Frame* sender,
                 [in] ICoreWebView2FrameCreatedEventArgs* args);
}

/// Receives `RendererProcessIdChanged` event.
// MSOWNERS: wangsongjin@microsoft.com
[uuid(012a41fe-a41f-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2RendererProcessIdChangedEventHandler : IUnknown {
  /// Provides the result for the process changed event.
  /// No event args exist and the args parameter is set to null.
  HRESULT Invoke([in] ICoreWebView2 * sender,
                 [in] IUnknown* args);
}

/// Receives `RendererProcessIdChanged` event.
// MSOWNERS: wangsongjin@microsoft.com
[uuid(c1e0a3d2-a74b-11ed-afa1-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2FrameRendererProcessIdChangedEventHandler : IUnknown {
  /// Provides the result for the process changed event.
  HRESULT Invoke([in] ICoreWebView2Frame* sender,
                 [in] IUnknown* args);
}

/// This is an extension of the ICoreWebView2Frame interface.
// MSOWNERS: wangsongjin@microsoft.com
[uuid(04baa798-a0e9-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2Frame5 : ICoreWebView2Frame4 {
  /// Raised when a new iframe is created.
  /// Handle this event to get access to ICoreWebView2Frame objects.
  /// Use ICoreWebView2Frame.add_Destroyed to listen for when this iframe goes
  /// away.
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT add_FrameCreated(
      [in] ICoreWebView2NestedFrameCreatedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with add_FrameCreated.
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT remove_FrameCreated([in] EventRegistrationToken token);

  /// Get the renderer process id of the iframe.
  /// The renderer process ID can change when navigating to a new document 
  /// and you can use the RendererProcessIdChanged event to know when it changes. 
  /// Child frames may have different renderer processes. 
  // MSOWNERS: wangsongjin@microsoft.com
  [propget] HRESULT RendererProcessId([out, retval] UINT32* value);

  /// Subscribe to renderer process Id changed event.
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT add_RendererProcessIdChanged(
      [in] ICoreWebView2FrameRendererProcessIdChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with add_RendererProcessIdChanged.
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT remove_RendererProcessIdChanged([in] EventRegistrationToken token);
}

/// A continuation of the `ICoreWebView2` interface to support get 
/// renderer process id and handle render process change event
[uuid(ad712504-a66d-11ed-afa1-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2_18 : ICoreWebView2_17 {
  /// Get the renderer process id of the main frame
  /// The renderer process ID can change when navigating to a new document.
  //  
  // MSOWNERS: wangsongjin@microsoft.com
    [propget] HRESULT RendererProcessId([out, retval] UINT32* value);

  /// Subscribe to renderer process id changed event
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT add_RendererProcessIdChanged(
      [in] ICoreWebView2RendererProcessIdChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with add_RendererProcessIdChanged.
  // MSOWNERS: wangsongjin@microsoft.com
  HRESULT remove_RendererProcessIdChanged([in] EventRegistrationToken token);
}
```

C#
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{   
    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_18")]
        {
            // ICoreWebView2_18 members
            UInt32 RendererProcessId { get; };
            event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> RendererProcessIdChanged;
        }
    }

    runtimeclass CoreWebView2Frame
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame5")]
        {
            // ICoreWebView2Frame5 members
            UInt32 RendererProcessId { get; };
            event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2FrameCreatedEventArgs> FrameCreated;
            event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, Object> RendererProcessIdChanged;
        }
    }
}
```

# Appendix
See here for more details about the process model documentation: <a href="https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model?tabs=csharp">Here</a>
