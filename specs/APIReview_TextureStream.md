TextureStream
===============================================================================================

# Background
Many native apps use a native engine for real-time communication scenarios, which include video capture, networking and video rendering.  However, often, these apps still use WebView or Electron for UI rendering. The separation between real-time video rendering and UI rendering prevents apps from rendering real-time video inside the web contents. This forces apps to render the real-time video on top of the web contents, which is limiting. Rendering video on top constrains the user experience and it may also cause performance problems. We can ask the native apps to use web renderer for video handling because web standard already provides these features through WebRTC APIs. The end developers, however, prefer to use their existing engine such as capturing and composition, meanwhile using WebRTC API for rendering.

# Description
The proposed APIs will allow the end developers to stream the captured or composed video frame to the WebView renderer where Javascript is able to insert the frame to the page through W3C standard API of Video, MediaStream element for displaying it.
The API will use the shared GPU texture buffer so that it can minimize the overall cost with regards to frame copy.

The proposed APIs have dependency on the DirectX and its internal attributes such as
adapter LUID so it supports only Win32/C++ APIs at this time.

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
    const videoTracks = stream.getVideoTracks();
    const videoTrack = videoTracks[0];
    window.videoTrack = videoTrack;
    // Show the video via Video Element.
    const videoElement = document.createElement('video');
    videoElement.srcObject = stream;
    document.body.appendChild(videoElement);
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
  console.log('mute state');
});

// Sent to the track when data becomes available again, ending the muted state.
window.videoTrack.addEventListener('unmut', () => {
  console.log('unmut state');
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
    function appSpecificCreateTransformedVideoFrame(originalVideoFrame) {
      // At this point the app would create a new video frame based on the original
      // video frame. For this sample we just delay for 1000ms and return the
      // original.
      await new Promise(resolve => setTimeout(resolve, 1000));
      return originalVideoFrame;
    }

    // Delay frame 1000ms.
    let transformedVideoFrame =
      await appSpecificCreateTransformedVideoFrame(originalVideoFrame);

    // We can create new video frame and edit them, and pass them back here
    // if needed.
    controller.enqueue(transformedVideoFrame);
  },
});

async function SendBackToHost(streamId) {
  console.log("streamId:" + streamId);
  const trackGenerator = new MediaStreamTrackGenerator('video');
  await window.chrome.webview.registerTextureStream(streamId, trackGenerator);

  const mediaStream = await window.chrome.webview.getTextureStream(streamId);
  const videoStream = mediaStream.getVideoTracks()[0];

  const trackProcessor = new MediaStreamTrackProcessor(videoStream);
  trackProcessor.readable.pipeThrough(transformer).pipeTo(trackGenerator.writable)
}

```

## Win32 C++
```cpp
HRESULT CreateTextureStream(ICoreWebView2StagingEnvironment* environment)
  UINT32 luid;

  // Get the LUID (Graphic adapter) that the WebView renderer uses.
  CHECK_FAILURE(environment->get_RenderAdapterLUID(&luid));

  // Create D3D device based on the WebView's LUID.
  ComPtr<D3D11Device> d3d_device = MyCreateD3DDevice(luid);

  // Register unique texture stream that the host can provide.
  ComPtr<ICoreWebView2TextureStream> webviewTextureStream;
  CHECK_FAILURE(environment->CreateTextureStream(L"webview2-abcd1234",
      d3d_device.Get(),  &webviewTextureStream));

  // Register the Origin URI that the target renderer could stream of the registered
  // stream id. The request from not registered origin will fail to stream.

  // `true` boolean value will add allowed origin for registerTextureStream as well.
  CHECK_FAILURE(webviewTextureStream->AddAllowedOrigin(L"https://edge-webscratch"), true);

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
  CHECK_FAILURE(webviewTextureStream->add_Stopped(Callback<ICoreWebView2StagingTextureStreamStoppedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* webview, IUnknown* eventArgs) -> HRESULT {
      StopMediaFoundationCapture();
      return S_OK;
    }).Get(), &stop_token));

  EventRegistrationToken texture_token;
  CHECK_FAILURE(webviewTextureStream->add_ErrorReceived(Callback<ICoreWebView2StagingTextureStreamErrorReceivedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* sender, ICoreWebView2StagingTextureStreamErrorReceivedEventArgs* args) {
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND kind;
      HRESULT hr = args->get_Kind(&kind);
      assert(SUCCEEDED(hr));
      switch (kind)
      {
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED:
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_ERROR:
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
  // with AddWebTextureAllowedOrigin.
  CHECK_FAILURE(webviewTextureStream->AddWebTextureAllowedOrigin(L"https://edge-webscratch"));

  // Registers listener for video streaming from Javascript.
  EventRegistrationToken post_token;
  CHECK_FAILURE(webviewTextureStream->add_WebTextureReceived(Callback<ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler>(
    [&](ICoreWebView2StagingTextureStream* sender, ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs* args) {
      // Javascript send a texture stream.
      ComPtr<ICoreWebView2StagingWebTexture> texture_received;
      args->GetWebTexture(&texture_received);

      UINT64 timestamp;
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

HRESULT SendTextureToBrowserAfterReceivingFrameFromTheSystem(
        ID3D11DeviceContext* deviceContext,
        ID3D11Texture2D* inputTexture,
        UINT64 timestamp) {

  ComPtr<ICoreWebView2StagingTexture> textureBuffer;
  HRESULT hr = webviewTextureStream->GetAvailableBuffer(&textureBuffer);
  if (FAILED(hr)) {
    // Create TextureBuffer.
    hr = webviewTextureStream->CreateBuffer(width, height, &texture);
    if (FAILED(hr))
      return hr;

    hr = webviewTextureStream->GetAvailableBuffer(&textureBuffer);
    assert(SUCCEEDED(hr));
  }

  ComPtr<IUnknown> dxgiResource;
  CHECK_FAILURE(textureBuffer->get_Resource(&dxgiResource));
  ComPtr<ID3D11Texture2D> sharedBuffer;
  CHECK_FAILURE(dxgiResource.As(&sharedBuffer));
  CHECK_FAILURE(deviceContext->CopyResource(sharedBuffer.Get(), inputTexture.Get()));

  // Notify the renderer for updated texture on the TextureBuffer.
  CHECK_FAILURE(webviewTextureStream->PresentBuffer(textureBuffer.Get(), timestamp));
}
```

# API Details
```
[v1_enum]
typedef enum COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND {
  /// CreateBuffer/Present and so on should return failed HRESULT if
  /// the texture stream is in the stopped state rather than using the
  /// error event. But there can be edge cases where the browser process
  /// knows the texture stream is in the stopped state and the host app
  /// process texture stream doesn't yet know that. Like the 10 second issue
  /// or if the script side has stopped the stream.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED,
  /// The TextureBuffer already has been removed using CloseBuffer.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_ERROR,
  /// The texture to be presented is already in use for rendering.
  /// Call GetAvailableBuffer to determine an available TextureBuffer to present.
  /// The developer can technically call PresentBuffer multiple times,
  /// but the first call make input TextureBuffer "in use" until the browser
  /// renders it and returns the buffer as "recycle" so that it can be a member of
  /// available buffers.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_BUFFER_IN_USE,
} COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND;

/// This is ICoreWebView2StagingEnvironment that returns the texture stream interface.
[uuid(96c27a45-f142-4873-80ad-9d0cd899b2b9), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment : IUnknown {
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
  /// that the host updates texture's d3d Device with SetD3DDevice,
  /// removes existing buffers and creates new TextureBuffer.
  HRESULT add_RenderAdapterLUIDChanged(
      [in] ICoreWebView2StagingRenderAdapterLUIDChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for RenderAdapterLUIDChange event.
  HRESULT remove_RenderAdapterLUIDChanged(
      [in] EventRegistrationToken token);
}
/// This is the interface that handles texture streaming.
[uuid(afca8431-633f-4528-abfe-7fc3bedd8962), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStream : IUnknown {
  /// Get the stream ID of the object that is used when calling CreateTextureStream.
  /// The caller must free the returned string with CoTaskMemFree. See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  /// MSOWNERS: TBD (wv2core@microsoft.com)
  [propget] HRESULT Id([out, retval] LPWSTR* id);
  /// Adds an allowed URI origin. The stream requests could be made from
  /// any frame, including iframes, but the origin of the page in the frames
  /// must be registered first in order for the request to succeed.
  /// The added origin will be persistent until
  /// ICoreWebView2StagingTextureStream is destroyed or
  /// RemoveAllowedOrigin is called.
  /// The renderer does not support wildcard so it will compare
  /// literal string input to the requesting frame's page's origin after
  /// normalization. The page origin will be normalized so ASCII characters
  /// in the scheme and hostname will be lowercased, and non-ASCII characters
  /// in the hostname will be normalized to their punycode form.
  /// For example `HTTPS://WWW.ㄓ.COM` will be normalized to
  /// `https://www.xn--kfk.com` for comparison. So, the input string
  /// should have a scheme like https://. For example,
  /// https://www.valid-host.com, http://www.valid-host.com are
  /// valid origins but www.valid-host.com, or https://*.valid-host.com. are not
  /// valid origins. If invalid origin is provided, the API will return an error
  /// of E_INVALIDARG.
  /// getTextureStream() will fail unless the requesting frame's origin URI is
  /// added to the allowed origins.
  /// If `value` is TRUE, then the origin will also be added to WebTexture's
  /// allowed origin.
  HRESULT AddAllowedOrigin([in] LPCWSTR origin, [in] BOOL value);
  /// Remove added origin, which was added by AddAllowedOrigin.
  /// The allowed or disallowed origins will take effect only when Javascript
  /// request a streaming. So, once the streaming started, it does not stop
  /// streaming.
  HRESULT RemoveAllowedOrigin([in] LPCWSTR origin);
  /// Listens for stream requests from the Javascript's getTextureStream call
  /// for this stream's id. It is called for the first request only, and will
  /// not be called with subsequent requests of same stream id from any pages
  /// in the middle of request handling or after it returns success.
  /// The request is regarded as success only when the host provides the stream,
  /// Present API call, within 10s after being requested.

  /// The Texture stream becomes 'Started' state once it starts sending a texture
  /// until it calls Stop API or receives 'Stopped' event.
  HRESULT add_StartRequested(
      [in] ICoreWebView2StagingTextureStreamStartRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for StartRequest event.
  HRESULT remove_StartRequested(
      [in] EventRegistrationToken token);
  /// Listen to stop stream request once the stream started.
  /// It is called when user stop all streaming requests from
  /// the renderers (Javascript) or the host calls the Stop API. The renderer
  /// can stream again by calling the streaming request API.
  /// The renderer cleared all registered TextureBuffers before sending
  /// the stop request event so that the callback of the next start request
  /// should register the textures again.
  /// The event is triggered when all requests for given stream id closed
  /// by the Javascript, or the host's Stop API call.
  /// TextureBuffer related API calls after this event will return an error
  /// of HRESULT_FROM_WIN32(ERROR_INVALID_STATE).
  HRESULT add_Stopped(
      [in] ICoreWebView2StagingTextureStreamStoppedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for Stopped event.
  HRESULT remove_Stopped(
      [in] EventRegistrationToken token);
  /// Creates TextureBuffer that will be referenced by the host and the browser.
  /// By using the TextureBuffer mechanism, the host does not have to
  /// send respective texture to the renderer, instead it notifies it
  /// with internal TextureBuffer id, which is the identity of the TextureBuffer.
  /// The TextureBuffer is 2D texture, IDXGIResource, format and will be
  /// exposed through shared HANDLE or IUnknown type through ICoreWebView2StagingTexture.
  /// Whenever the host has new texture to write, it should ask
  /// reusable ICoreWebView2StagingTexture from the GetAvailableBuffer,
  /// which returns ICoreWebView2StagingTexture.
  /// If the GetAvailableBuffer returns an error, then the host calls the
  /// CreateBuffer to allocate new TextureBuffer.
  /// The API also registers created shared handle to the browser once it
  /// created the resource.

  /// Unit for width and height is texture unit (in texels).
  /// 'https://learn.microsoft.com/en-us/windows/win32/api/d3d11ns-d3d11-d3d11_texture2d_desc'
  HRESULT CreateBuffer(
    [in] UINT32 widthInTexels,
    [in] UINT32 heightInTexels,
    [out, retval] ICoreWebView2StagingTexture** buffer);
  /// Returns reuseable TextureBuffer for video frame rendering.
  /// Once the renderer finishes rendering of TextureBuffer's video frame, which
  /// was requested by Present, the renderer informs the host so that it can
  /// be reused. The host has to create new TextureBuffer with CreateBuffer
  /// if the API return an error HRESULT_FROM_WIN32(ERROR_NO_MORE_ITEMS).
  HRESULT GetAvailableBuffer([out, retval] ICoreWebView2StagingTexture** buffer);
  /// Removes TextureBuffer when the host removes the backed 2D texture.
  /// The host can save the resources by deleting 2D textures
  /// when it changes the frame sizes. The API will send a message
  /// to the browser where it will remove TextureBuffer.
  HRESULT CloseBuffer([in] ICoreWebView2StagingTexture* buffer);
  /// Sets rendering image/resource through ICoreWebView2StagingTexture.
  /// The TextureBuffer must be retrieved from the GetAvailableBuffer or
  /// created via CreateBuffer.
  /// It is expected that hhe host writes new image/resource to the local
  /// shared 2D texture of the TextureBuffer (handle/resource).

  /// `timestampInMicroseconds` is video capture time with microseconds units.
  /// The value does not have to be exact captured time, but it should be
  /// increasing order because renderer (composition) ignores incoming
  /// video frame (texture) if its timestampInMicroseconds is equal or prior to
  /// the current compositing video frame. It also will be exposed to the
  /// JS with `VideoFrame::timestamp`.
  /// (https://docs.w3cub.com/dom/videoframe/timestamp.html).
  HRESULT PresentBuffer([in] ICoreWebView2StagingTexture* buffer,
    [in] UINT64 timestampInMicroseconds);
  /// Stop streaming of the current stream id.
  /// The Javascript will receive `MediaStreamTrack::ended` event when the API
  /// is called.
  /// The Javascript can restart the stream with getTextureStream.
  /// The API call will release any internal resources on both of WebView2 host
  /// and the browser processes.
  /// API calls of Present, CreateBuffer will fail after this
  /// with an error of COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED.
  /// The Stop API will be called implicitly when ICoreWebView2StagingTextureStream
  /// object is destroyed.
  HRESULT Stop();
  /// Event handler for those that occur at the Renderer side, the example
  /// are CreateBuffer, Present, or Stop.
  HRESULT add_ErrorReceived(
      [in] ICoreWebView2StagingTextureStreamErrorReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for ErrorReceived event.
  HRESULT remove_ErrorReceived([in] EventRegistrationToken token);
  /// Updates d3d Device when it is updated by RenderAdapterLUIDChanged
  /// event.
  HRESULT SetD3DDevice([in] IUnknown* d3dDevice);
  /// Event handler for receiving texture by Javascript.
  /// `window.chrome.webview.registerTextureStream` call by Javascript will
  /// request sending video frame to the host where it will filter requested
  /// page's origin against allowed origins. If allowed, the Javascript will
  /// send a video frame (web texture), through MediaStreamTrack insertable APIs,
  /// MediaStreamTrackGenerator.
  /// https://www.w3.org/TR/mediacapture-transform/.
  /// WebTextureReceived event will be called only when it receives
  /// a web texture. There is no start event for receiving web texture.
  HRESULT add_WebTextureReceived(
      [in] ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for WebTextureReceived event.
  HRESULT remove_WebTextureReceived([in] EventRegistrationToken token);
  /// Event handler for stopping of the receiving texture stream.
  /// It is expected that the host releases any holding handle/resource from
  /// the WebTexture before an event handler returns.
  HRESULT add_WebTextureStreamStopped(
      [in] ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for WebTextureStreamStopped event.
  HRESULT remove_WebTextureStreamStopped([in] EventRegistrationToken token);
}
/// TextureBuffer that the host writes to so that the Renderer
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
interface ICoreWebView2StagingTextureStreamStoppedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event. There are no event args and the args
  /// parameter will be null.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] IUnknown* args);
}
/// This is the callback for texture stream rendering error.
[uuid(52cb8898-c711-401a-8f97-3646831ba72d), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamErrorReceivedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
      [in] ICoreWebView2StagingTextureStreamErrorReceivedEventArgs* args);
}
/// This is the event args interface for texture stream error callback.
[uuid(0e1730c1-03df-4ad2-b847-be4d63adf700), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamErrorReceivedEventArgs : IUnknown {
  /// Error kind.
  [propget] HRESULT Kind([out, retval]
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND* value);
  /// TextureBuffer that the error is associated with.
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
      [in] ICoreWebView2StagingEnvironment * sender,
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
  /// Return ICoreWebView2StagingWebTexture object.
  /// The call does not create new ICoreWebView2StagingWebTexture object, instead
  /// returns the same object.

  /// The TextureBuffer handle will be reused when ICoreWebView2StagingWebTexture
  /// object is released. So, the host should not refer handle or resource of
  /// the ICoreWebView2StagingWebTexture after its release.

  HRESULT GetWebTexture([out, retval] ICoreWebView2StagingWebTexture** value);
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

/// Received TextureBuffer that the renderer writes to so that the host
/// will read on it.
[uuid(b94265ae-4c1e-11ed-bdc3-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingWebTexture : IUnknown {
  /// TextureBuffer handle. The handle's lifetime is owned by the
  /// ICoreWebView2StagingTextureStream object so the host must not close it.
  /// The same handle value will be used for same TextureBuffer so the host can use
  /// handle value as a unique TextureBuffer key.
  /// If the host opens its own resources by handle, then it is suggested
  /// that the host removes those resources when the handle's texture size
  /// is changed because the browser also removed previously allocated different
  /// sized buffers when image size is changed.
  [propget] HRESULT Handle([out, retval] HANDLE* handle);

  /// TextureBuffer resource.
  /// The same resource value will be used for same TextureBuffer so the host can use
  /// resource value as a unique TextureBuffer key.
  /// ICoreWebView2StagingTextureStream object has a reference of the resource
  /// so ICoreWebView2StagingWebTexture holds same resource object for
  /// the same TextureBuffer.
  [propget] HRESULT Resource([out, retval] IUnknown** resource);

  /// It is timestamp of the web texture. Javascript can set this value
  /// with any value, but it is suggested to use same value of its original
  /// video frame that is a value of PresentBuffer so that the host is able to
  /// tell the receiving texture delta.
  [propget] HRESULT Timestamp([out, retval] UINT64* timestampInMicroseconds);
}

```
