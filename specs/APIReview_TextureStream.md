TextureStream
===============================================================================================

# Background
Many native apps use a native engine for real-time communication scenarios, which include video
capture, networking and video rendering.  However, often, these apps still use WebView or
Electron for UI rendering. The separation between real-time video rendering and UI rendering
prevents apps from rendering real-time video inside the web contents. This forces apps to
render the real-time video on top of the web contents, which is limiting. Rendering video on
top constrains the user experience and it may also cause performance problems.
We can ask the native apps to use web renderer for video handling because web standard already
provides these features through WebRTC APIs. The end developers, however, prefer to use
their existing engine such as capturing and composition, meanwhile using WebRTC API for rendering.

# Description
The proposed APIs will allow the end developers to stream the captured or composed video frame to
the WebView renderer where Javascript is able to insert the frame to the page through W3C standard
API of Video, MediaStream element for displaying it.
The API will use the shared GPU texture buffer so that it can minimize the overall cost with
regards to frame copy.

# Examples

## Javascript

This is Javascript code common to both of the following samples:

```js
// getTextureStream sample.

// Developer can stream from the host and its returned object is MediaStream
// that is same what getUserMedia returns. Technically, developer can do all
// what MediaStream and its video MediaStreamTrack provide.

// Scenario: User clicks the button and show stream from the host via video element.
document.querySelector('#showVideo').addEventListener('click',
  e => getStreamFromTheHost(e));
async function getStreamFromTheHost(e) {
  try {
    // Request stream to the host with unique stream id.
    // getTextureStream W3C standard MediaStream object that has only video
    // MediaStreamTrack.
    const stream = await window.chrome.webview.getTextureStream('webview2-abcd1234');
    // The MediaStream object is returned and it gets video MediaStreamTrack element from it.
    const video_tracks = stream.getVideoTracks();
    const videoTrack = video_tracks[0];
    window.videoTrack = videoTrack;
    // Show the video via Video Element.
    document.getElementById(video_id).srcObject = stream;
  } catch (error) {
    console.log(error);
  }
}

// Developer can use commands and events for MediaStream and MediaStreamTrack.

// It will completely stop the current streaming. If it restarts, it
// should call getTextureStream again.
function stopStreaming() {
  window.videoTrack.addEventListener('ended', () => {
    delete window.videoTrack;
  });

  window.videoTrack.stop();
}

// Most of events on the MediaStream/MediaStreamTrack will be supported.

// No video streaming from the host.
window.videoTrack.addEventListener('mute', () => {
  console.log('mute state);
});

// Sent to the track when data becomes available again, ending the muted state.
window.videoTrack.addEventListener('unmut', () => {
  console.log('unmute state);
});

```

```js
// registerTextureStream sample.

// Developer can even send back the processed video frame to the host.

// Scenario: User clicks to stream from the host and sends back them 1s late
// to the host.
document.querySelector('#sendBack').addEventListener('click',
  e => getStreamFromTheHost(e));
const transformer = new TransformStream({
  async transform(videoFrame, controller) {
    // Delay frame 100ms.
    await new Promise(resolve => setTimeout(resolve, 1000));

    // We can create new video frame and edit them, and pass them back here
    // if needed.
    controller.enqueue(videoFrame);
  },
});

async function SendBackToHost(stream_id) {
  console.log("stream_id:" + stream_id);
  const mediaStream = await window.chrome.webview.getTextureStream(stream_id);
  const videoStream = mediaStream.getVideoTracks()[0];

  const trackProcessor = new MediaStreamTrackProcessor(videoStream);
  const trackGenerator = new MediaStreamTrackGenerator('video');

  // Test purpose, we send it back what just received.
  window.chrome.webview.registerTextureStream(stream_id, trackGenerator);

  trackProcessor.readable.pipeThrough(transformer).pipeTo(trackGenerator.writable)
}

```

## Win32 C++
```cpp
HRESULT CreateTextureStream(ICoreWebView2Staging3* coreWebView)
  UINT32 luid;

  // Get the LUID (Graphic adapter) that the WebView renderer uses.
  CHECK_FAILURE(coreWebView->get_RenderAdapterLUID(&luid));

  // Create D3D device based on the WebView's LUID.
  ComPtr<D3D11Device> d3d_device = MyCreateD3DDevice(luid);

  // Register unique texture stream that the host can provide.
  ComPtr<ICoreWebView2TextureStream> webviewTextureStream;
  CHECK_FAILURE(g_webviewStaging3->CreateTextureStream(L"webview2-abcd1234",
      d3d_device.Get(),  &webviewTextureStream));

  // Register the Origin URL that the target renderer could stream of the registered stream id. The request from not registered origin will fail to stream.
  CHECK_FAILURE(webviewTextureStream->AddRequestedFilter(L"https://edge-webscratch"));

  // Listen to Start request. The host will setup system video streaming and
  // start sending the texture.
  EventRegistrationToken start_token;
  CHECK_FAILURE(webviewTextureStream->add_StartRequested(Callback<ICoreWebView2StagingTextureStreamStartRequestedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* webview, IUnknown* eventArgs) -> HRESULT {
      // Capture video stream by using native API, for example, Media Foundation on Windows.
      StartMediaFoundationCapture(hWnd);
      return S_OK;
    }).Get(), &start_token));

  // Listen to Stop request. The host end system provided video stream and
  // clean any operation resources.
  EventRegistrationToken stop_token;
  CHECK_FAILURE(webviewTextureStream->add_StopRequested(Callback<ICoreWebView2StagingTextureStreamStopRequestedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* webview, IUnknown* eventArgs) -> HRESULT {
      StopMediaFoundationCapture();
      return S_OK;
    }).Get(), &stop_token));

  EventRegistrationToken texture_token;
  CHECK_FAILURE(webviewTextureStream->add_TextureError(Callback<ICoreWebView2StagingTextureStreamTextureErrorEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* sender, ICoreWebView2StagingTextureStreamTextureErrorEventArgs* args) {
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND kind;
      HRESULT hr = args->get_Kind(&kind);
      assert(SUCCEEDED(hr));
      switch (kind)
      {
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED:
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_NOT_FOUND:
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_IN_USE:
        // assert(false);
        break;
      default:
        break;
      }
      return S_OK;
    }).Get(), &texture_token));

  // Add allowed origin for registerTextureStream call. 'registerTextureStream'
  // call from the Javascript will fail if the requested origin is not registered
  // with AddWebTextureRequestedFilter.
  CHECK_FAILURE(webviewTextureStream->AddWebTextureRequestedFilter(L"https://edge-webscratch"));

  // Registers listener for video streaming from Javascript.
  EventRegistrationToken post_token;
  CHECK_FAILURE(webviewTextureStream->add_WebTextureReceived(Callback<ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler>(
    [&](ICoreWebView2StagingTextureStream* sender, ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs* args) {
      // Javascript send a texture stream.
      ComPtr<ICoreWebView2StagingWebTexture> texture_received;
      args->GetWebTexture(&texture_received);

      ULONGLONG timestamp;
      texture_received->get_Timestamp(&timestamp);
      HANDLE handle;
      texture_received->get_Handle(&handle);
      DrawTextureWithWICBitmap(handle, timestamp);

      return S_OK;
    }).Get(), &post_token));

  // Register listener of video stream from the Javascript end.
  EventRegistrationToken stopped_token;
  CHECK_FAILURE(webviewTextureStream->add_WebTextureStreamStopped(Callback<ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler>(
    [&](ICoreWebView2StagingTextureStream* sender, IUnknown* args) {

      return S_OK;
    }).Get(), &stopped_token));
}  // CreateTextureStream

HRESULT CallWebView2API(bool createBuffer,
                        UINT32 width,
                        UINT32 height,
                        bool requestAvailableBufer,
                        bool sendTexture,
                        ICoreWebView2StagingTexture* send_texture,
                        UINT64 timestamp,
                        ICoreWebView2StagingTexture** texture) {
  if (createBuffer) {
    // Create shared buffer.
    return webviewTextureStream->CreateSharedBuffer(width, height, &texture);
  }

  if (requestAvailableBufer) {
    return webviewTextureStream->GetAvailableBuffer(&texture);
  }

  if (sendTexture) {
    // Notify the renderer for updated texture on the shared buffer.
    webviewTextureStream->SetBuffer(send_texture, timestamp);
    webviewTextureStream->Present();
  }
}
```

# API Details
```
[v1_enum]
typedef enum COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND {
  /// The host can't create a TextureStream instance more than once
  /// for a specific stream id.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_STREAM_ID_ALREADY_REGISTERED,
  /// Occurs when the host calls CreateBuffer or Present
  /// APIs without being called of Start event. Or, 10 seconds passed before
  /// calling these APIs since the OnStart event.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED,
  /// The buffer has been removed using RemoveBuffer.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_NOT_FOUND,
  /// The texture to be presented is already in use for rendering.
  /// Call GetAvailableBuffer to determine an available buffer to present.
  /// The developer can technically call SetBuffer multiple times.
  /// But once they call Present, the buffer becomes "in use" until
  /// they call SetBuffer and Present on a different buffer and wait a bit
  /// for the original buffer to stop being used.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_IN_USE,
} COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND;
/// This is ICoreWebView2Staging3 that returns the texture stream interface.
[uuid(96c27a45-f142-4873-80ad-9d0cd899b2b9), object, pointer_default(unique)]
interface ICoreWebView2Staging3 : IUnknown {
  /// Registers the stream id that the host can handle, providing a
  /// texture stream when requested from the WebView2's JavaScript code.
  /// The host can register multiple unique stream instances, each with
  /// a unique stream ID, enabling the host to stream from different sources
  /// concurrently.
  /// The host should call this only once for unique streamId. The second
  /// call of already created streamId without destroying
  /// ICoreWebView2StagingTextureStream object will return an error.
  /// 'd3dDevice' is used for creating shared IDXGI resource and NT shared
  /// of it. The host should use Adapter of the LUID from the GetRenderAdapterLUID
  /// for creating the D3D Device.
  HRESULT CreateTextureStream(
      [in] LPCWSTR streamId,
      [in] IUnknown* d3dDevice,
      [out, retval ] ICoreWebView2StagingTextureStream** value);
  /// Get the graphics adapter LUID of the renderer. The host should use this
  /// LUID adapter when creating D3D device to use with CreateTextureStream().
  [propget] HRESULT RenderAdapterLUID([out, retval] LUID* luid);
  /// Listens for change of graphics adapter LUID of the browser.
  /// The host can get the updated LUID by RenderAdapterLUID. It is expected
  /// that the host updates texture's d3d Device with UpdateD3DDevice,
  /// removes existing buffers and creates new buffer.
  HRESULT add_RenderAdapterLUIDChanged(
      [in] ICoreWebView2StagingRenderAdapterLUIDChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for start stream request.
  HRESULT remove_RenderAdapterLUIDChanged(
      [in] EventRegistrationToken token);
}
/// This is the interface that handles texture streaming.
/// The most of APIs have to be called on UI thread.
[uuid(afca8431-633f-4528-abfe-7fc3bedd8962), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStream : IUnknown {
  /// Get the stream ID of the object that is used when calling CreateTextureStream.
  /// The caller must free the returned string with CoTaskMemFree. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  // MSOWNERS: TBD (wv2core@microsoft.com)
  [propget] HRESULT StreamId([out, retval] LPWSTR* id);
  /// Adds an allowed url origin for the given stream id. The stream requests
  /// could be made from any frame, including iframes, but these origins
  /// must be registered first in order for the request to succeed.
  /// The added filter will be persistent until
  /// ICoreWebView2StagingTextureStream is destroyed or
  /// RemoveRequestedFilter is called.
  /// The renderer does not support wildcard so it will compare
  /// literal string input to the requesting frame origin. So, the input string
  /// should have a scheme like https://.
  /// For example, https://www.valid-host.com, http://www.valid-host.com are
  /// valid origins but  www.valid-host.com, or *.valid-host.com. are not
  /// valid origins.
  /// getTextureStream() will fail unless the requesting frame's origin URL is
  /// added to the request filter.
  HRESULT AddRequestedFilter([in] LPCWSTR origin);
  /// Remove added origin, which was added by AddRequestedFilter.
  HRESULT RemoveRequestedFilter([in] LPCWSTR origin);
  /// Listens for stream requests from the Javascript's getTextureStream call
  /// for the given stream id. It is called for the first request only, the
  /// subsequent requests of same stream id will not be called.
  /// It is expected that the host provides the stream within 10s after
  /// being requested. The first call to Present() fulfills the stream request.
  HRESULT add_StartRequested(
      [in] ICoreWebView2StagingTextureStreamStartRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for start stream request.
  HRESULT remove_StartRequested(
      [in] EventRegistrationToken token);
  /// Listen to stop stream request once the stream started.
  /// It is called when user stop all streaming requests from
  /// the renderers (Javascript) or the host calls the Stop API. The renderer
  /// can stream again by calling the streaming request API.
  /// The renderer cleared all registered buffers before sending
  /// the stop request event so that the callback of the next start request
  /// should register the textures again.
  /// The event is triggered when all requests for given stream id closed
  /// by the Javascript, or the host's Stop API call.
  HRESULT add_StopRequested(
      [in] ICoreWebView2StagingTextureStreamStopRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for stop stream request.
  HRESULT remove_StopRequested(
      [in] EventRegistrationToken token);
  /// Creates shared buffer that will be referenced by the host and the browser.
  /// By using the shared buffer mechanism, the host does not have to
  /// send respective texture to the renderer, instead it notifies it
  /// with internal buffer id, which is the identity of the shared buffer.
  /// The shared buffer is 2D texture, IDXGIResource, format and will be
  /// exposed through shared HANDLE or IUnknown type through ICoreWebView2StagingTexture.
  /// Whenever the host has new texture to write, it should ask
  /// reusable ICoreWebView2StagingTexture from the GetAvailableBuffer,
  /// which returns ICoreWebView2StagingTexture.
  /// If the GetAvailableBuffer returns an error, then the host calls the
  /// CreateBuffer to allocate new shared buffer.
  /// The API also registers created shared handle to the browser once it
  /// created the resource.
  HRESULT CreateBuffer(
    [in] UINT32 width,
    [in] UINT32 height,
    [out, retval] ICoreWebView2StagingTexture** buffer);
  /// GetAvailableBuffer can be called on any thread like SetBuffer.
  HRESULT GetAvailableBuffer([out, retval] ICoreWebView2StagingTexture** buffer);
  /// Remove texture buffer when the host removes the backed 2D texture.
  /// The host can save the existing resources by deleting 2D textures
  /// when it changes the frame sizes.
  HRESULT RemoveBuffer([in] ICoreWebView2StagingTexture* buffer);
  /// Indicates that the buffer is ready to present.
  /// The buffer must be retrieved from the GetAvailableBuffer.
  /// The host writes new texture to the local shared 2D texture of
  /// the buffer id, which is created via CreateBuffer.
  /// SetBuffer API can be called in any thread.
  HRESULT SetBuffer([in] ICoreWebView2StagingTexture* buffer,
    [in] ULONGLONG timestamp);
  /// Render texture that is current set ICoreWebView2StagingTexture.
  HRESULT Present();
  /// Stop streaming of the current stream id.
  /// API calls of Present, CreateBuffer will fail after this
  /// with an error of COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED.
  /// The Javascript can restart the stream with getTextureStream.
  HRESULT Stop();
  /// Event handler for those that occur at the Renderer side, the example
  /// are CreateBuffer, Present, or Stop.
  HRESULT add_TextureError(
      [in] ICoreWebView2StagingTextureStreamTextureErrorEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for texture error event.
  HRESULT remove_TextureError([in] EventRegistrationToken token);
  /// Updates d3d Device when it is updated by RenderAdapterLUIDChanged
  /// event.
  HRESULT UpdateD3DDevice([in] IUnknown* d3dDevice);
  /// Event handler for receiving texture by Javascript.
  /// There is no Start event for web texture. Whenever texture are sent
  /// from the Javascript, the event is triggered.
  HRESULT add_WebTextureReceived(
      [in] ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  HRESULT remove_WebTextureReceived([in] EventRegistrationToken token);

  /// Event handler for stopping of the receiving texture stream.
  HRESULT add_WebTextureStreamStopped(
      [in] ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  HRESULT remove_WebTextureStreamStopped([in] EventRegistrationToken token);

  /// Adds an allowed url origin for the given stream id for web texture
  /// operation.  Javascript can send texture stream to the host only when
  /// the origin it runs are allowed by the host.
  HRESULT AddWebTextureRequestedFilter([in] LPCWSTR origin);

  /// Remove added origin, which was added by AddWebTextureRequestedFilter.
  HRESULT RemoveWebTextureRequestedFilter([in] LPCWSTR origin);
}
/// Texture stream buffer that the host writes to so that the Renderer
/// will render on it.
[uuid(0836f09c-34bd-47bf-914a-99fb56ae2d07), object, pointer_default(unique)]
interface ICoreWebView2StagingTexture : IUnknown {
    /// Returns shared Windows NT handle. The caller expected to open it with
    /// ID3D11Device1::OpenSharedResource1 and writes the incoming texture to it.
    [propget] HRESULT Handle([out, retval] HANDLE* handle);
    /// Returns IUnknown type that could be query interface to IDXGIResource.
    /// The caller can write incoming texture to it.
    [propget] HRESULT Resource([out, retval] IUnknown** resource);
}
/// This is the callback for new texture stream request.
[uuid(62d09330-00a9-41bf-a9ae-55aaef8b3c44), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamStartRequestedEventHandler : IUnknown {
  //// Called to provide the implementer with the event args for the
  //// corresponding event. There are no event args and the args
  //// parameter will be null.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}
/// This is the callback for stop request of texture stream.
[uuid(4111102a-d19f-4438-af46-efc563b2b9cf), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamStopRequestedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event. There are no event args and the args
  /// parameter will be null.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}
/// This is the callback for texture stream rendering error.
[uuid(52cb8898-c711-401a-8f97-3646831ba72d), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamTextureErrorEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] ICoreWebView2StagingTextureStreamTextureErrorEventArgs* args);
}
/// This is the event args interface for texture stream error callback.
[uuid(0e1730c1-03df-4ad2-b847-be4d63adf700), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamTextureErrorEventArgs : IUnknown {
  /// Error kind.
  [propget] HRESULT Kind([out, retval]
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND* value);
  // Texture buffer that the error is associated with.
  HRESULT GetBuffer([out, retval] ICoreWebView2StagingTexture** buffer);
}
[uuid(431721e0-0f18-4d7b-bd4d-e5b1522bb110), object, pointer_default(unique)]
interface ICoreWebView2StagingRenderAdapterLUIDChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}
[uuid(431721e0-0f18-4d7b-bd4d-e5b1522bb110), object, pointer_default(unique)]
interface ICoreWebView2StagingRenderAdapterLUIDChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Staging3 * sender,
      [in] IUnknown* args);
}
/// This is the callback for web texture.
[uuid(9ea4228c-295a-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs* args);
}

/// This is the event args interface for web texture.
[uuid(a4c2fa3a-295a-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs : IUnknown {
  // Return ICoreWebView2StagingWebTexture object.
  // The call does not create new ICoreWebView2StagingWebTexture object, instead
  // returns the same object.

  // The shared buffer handle will be reused when ICoreWebView2StagingWebTexture
  // object is released. So, the host should not refer handle or resource of
  // the ICoreWebView2StagingWebTexture after its release.

  HRESULT GetWebTexture([out, retval] ICoreWebView2StagingWebTexture** value);
}

/// Texture received stream buffer that the renderer writes to so that the host
/// will read on it.
[uuid(b94265ae-4c1e-11ed-bdc3-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingWebTexture : IUnknown {
  /// Texture buffer handle. The handle's lifetime is owned by the
  /// ICoreWebView2StagingTextureStream object so the host must not close it.
  /// The same handle value will be used for same buffer so the host can use
  /// handle value as a unique buffer key.
  /// If the host opens its own resources by handle, then it is suggested
  /// that the host removes those resources when the handle's texture size
  /// is changed because the browser also removed previously allocated different
  /// sized buffers when image size is changed.
  [propget] HRESULT Handle([out, retval] HANDLE* handle);

  /// Texture buffer resource.
  /// The same resource value will be used for same buffer so the host can use
  /// resource value as a unique buffer key.
  /// ICoreWebView2StagingTextureStream object has a reference of the resource
  /// so ICoreWebView2StagingWebTexture holds same resource object for
  /// the same buffer.
  [propget] HRESULT Resource([out, retval] IUnknown** resource);

  /// It is timestamp of the web texture. Javascript can set this value
  /// with any value, but it is suggested to use same value of its original
  /// video frame that is a value of SetBuffer so that the host is able to
  /// tell the receiving texture delta.
  [propget] HRESULT Timestamp([out, retval] ULONGLONG* value);
}

/// This is the callback for web texture stop.
[uuid(77eb4638-2f05-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}/// This is the callback for web texture.
[uuid(9ea4228c-295a-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs* args);
}

/// This is the event args interface for web texture.
[uuid(a4c2fa3a-295a-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs : IUnknown {
  // Return ICoreWebView2StagingWebTexture object.
  // The call does not create new ICoreWebView2StagingWebTexture object, instead
  // returns the same object.

  // The shared buffer handle will be reused when ICoreWebView2StagingWebTexture
  // object is released. So, the host should not refer handle or resource of
  // the ICoreWebView2StagingWebTexture after its release.

  HRESULT GetWebTexture([out, retval] ICoreWebView2StagingWebTexture** value);
}

/// Texture received stream buffer that the renderer writes to so that the host
/// will read on it.
[uuid(b94265ae-4c1e-11ed-bdc3-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingWebTexture : IUnknown {
  /// Texture buffer handle. The handle's lifetime is owned by the
  /// ICoreWebView2StagingTextureStream object so the host must not close it.
  /// The same handle value will be used for same buffer so the host can use
  /// handle value as a unique buffer key.
  /// If the host opens its own resources by handle, then it is suggested
  /// that the host removes those resources when the handle's texture size
  /// is changed because the browser also removed previously allocated different
  /// sized buffers when image size is changed.
  [propget] HRESULT Handle([out, retval] HANDLE* handle);

  /// Texture buffer resource.
  /// The same resource value will be used for same buffer so the host can use
  /// resource value as a unique buffer key.
  /// ICoreWebView2StagingTextureStream object has a reference of the resource
  /// so ICoreWebView2StagingWebTexture holds same resource object for
  /// the same buffer.
  [propget] HRESULT Resource([out, retval] IUnknown** resource);

  /// It is timestamp of the web texture. Javascript can set this value
  /// with any value, but it is suggested to use same value of its original
  /// video frame that is a value of SetBuffer so that the host is able to
  /// tell the receiving texture delta.
  [propget] HRESULT Timestamp([out, retval] ULONGLONG* value);
}

/// This is the callback for web texture stop.
[uuid(77eb4638-2f05-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}
```
