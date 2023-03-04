TextureStream
===============================================================================================

# Background
Many native apps use a native engine for real-time communication scenarios,
which include video capture, networking and video rendering.  However, often,
these apps still use WebView or Electron for UI rendering. The separation
between real-time video rendering and UI rendering prevents apps from rendering
real-time video inside the web contents. This forces apps to render the
real-time video on top of the web contents, which is limiting. Rendering video
on top constrains the user experience and it may also cause performance problems.
We can ask the native apps to use web renderer for video handling because web
standard already provides these features through WebRTC APIs. The end
developers, however, prefer to use their existing engine such as capturing
and composition, meanwhile using WebRTC API for rendering.

# Description
The proposed APIs allow end developers to stream captured or composed video
frames to the WebView2 where JavaScript can render or otherwise interact with
the frames via W3C standard DOM APIs including the Video element, and MediaStream.

The API aims to minimize the number of times a frame must be copied and so is
structured to allow reuse of frame objects which are implemented with GPU
textures that can be shared across processes.

The proposed APIs have dependency on the DirectX and its internal attributes
such as adapter LUID so the API is only exposed in the WebView2 COM APIs to
Win32/C++ consumers and as an Interop COM interface to allow C++/WinRT
consumers to access the interface.

# Examples

## Javascript

Render video stream in video HTML element

In this sample, the native code generates video in a texture stream, it is
sent to JavaScript, which renders it into a video HTML element.

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
  CHECK_FAILURE(webviewTextureStream->AddAllowedOrigin(
      L"https://edge-webscratch"), true);

  // Listen to Start request. The host will setup system video streaming and
  // start sending the texture.
  EventRegistrationToken start_token;
  CHECK_FAILURE(webviewTextureStream->add_StartRequested(Callback<ICoreWebView2StagingTextureStreamStartRequestedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* webview,
          IUnknown* eventArgs) -> HRESULT {
      // Capture video stream by using native API, for example,
      // Media Foundation on Windows.
      StartMediaFoundationCapture(hWnd);
      return S_OK;
    }).Get(), &start_token));

  // Listen to Stop request. The host end system provided video stream and
  // clean any operation resources.
  EventRegistrationToken stop_token;
  CHECK_FAILURE(webviewTextureStream->add_Stopped(
          Callback<ICoreWebView2StagingTextureStreamStoppedEventHandler>(
      [hWnd](ICoreWebView2StagingTextureStream* webview,
             IUnknown* eventArgs) -> HRESULT {
      StopMediaFoundationCapture();
      return S_OK;
    }).Get(), &stop_token));

  EventRegistrationToken texture_token;
  CHECK_FAILURE(webviewTextureStream->add_ErrorReceived(Callback<ICoreWebView2StagingTextureStreamErrorReceivedEventHandler>(
    [hWnd](ICoreWebView2StagingTextureStream* sender,
           ICoreWebView2StagingTextureStreamErrorReceivedEventArgs* args) {
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND kind;
      HRESULT hr = args->get_Kind(&kind);
      assert(SUCCEEDED(hr));
      switch (kind)
      {
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED:
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_TEXTURE_ERROR:
      case COREWEBVIEW2_TEXTURE_STREAM_ERROR_TEXTURE_IN_USE:
        assert(false);
        break;
      default:
        break;
      }
      return S_OK;
    }).Get(), &texture_token));

  // Add allowed origin for getTextureStream call.
  CHECK_FAILURE(webviewTextureStream->AddWebTextureAllowedOrigin(
      L"https://edge-webscratch"), false);
}  // CreateTextureStream

HRESULT StartMediaFoundationCapture() {
  // The video stream can come from the any sources, one of examples is to use
  // Windows Media Foundation by using IMFCaptureEngine.
  // The sample code is https://github.com/microsoft/Windows-classic-samples/tree/main/Samples/CaptureEngineVideoCapture.

  // Once stream engine setups, the engine will sends video stream. For Media
  // Foundation, it can send it with ID3D11Texture2D format.

  // Stream engine callback calls SendTextureToBrowserAfterReceivingFrameFromTheSystem
  // with captured image of ID3D11Texture2D format.
}

HRESULT StopMediaFoundationCapture() {
  // It stops video stream and clean any resources that were allocated for
  // streaming.
}

HRESULT SendTextureToBrowserAfterReceivingFrameFromTheSystem(
        ID3D11DeviceContext* deviceContext,
        ID3D11Texture2D* inputTexture,
        UINT64 timestamp) {

  ComPtr<ICoreWebView2StagingTexture> texture;
  HRESULT hr = webviewTextureStream->GetAvailableTexture(&texture);
  if (FAILED(hr)) {
    // Create TextureTexture.
    hr = webviewTextureStream->CreateTexture(width, height, &texture);
    if (FAILED(hr))
      return hr;

    hr = webviewTextureStream->GetAvailableTexture(&texture);
    assert(SUCCEEDED(hr));
  }

  ComPtr<IUnknown> dxgiResource;
  CHECK_FAILURE(texture->get_Resource(&dxgiResource));
  CHECK_FAILURE(texture->put_Timestamp(timestamp));
  ComPtr<ID3D11Texture2D> sharedTexture;
  CHECK_FAILURE(dxgiResource.As(&sharedTexture));
  CHECK_FAILURE(deviceContext->CopyResource(sharedTexture.Get(), inputTexture.Get()));

  // Notify the renderer for updated texture on the TextureTexture.
  CHECK_FAILURE(webviewTextureStream->PresentTexture(texture.Get()));
}
```

Edit video in JavaScript and send back to native

In this sample, the native code generates video in a texture stream,
it is sent to JavaScript, JavaScript edits the video, and sends it back
to native code.

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
HRESULT RegisterTextureStream(ICoreWebView2TextureStream* webviewTextureStream)
  UINT32 luid;

  // It uses same code of getTextureStream's CreateTextureStream API where
  // it creates ICoreWebView2TextureStream.

  // Add allowed origin for registerTextureStream call by providing `true` on
  // AddWebTextureAllowedOrigin 'registerTextureStream'.
  // Call from the Javascript will fail if the requested origin is not registered
  // for registerTextureStream.
  CHECK_FAILURE(webviewTextureStream->AddWebTextureAllowedOrigin(
        L"https://edge-webscratch"), true);

  // Registers listener for video streaming from Javascript.
  EventRegistrationToken post_token;
  CHECK_FAILURE(webviewTextureStream->add_WebTextureReceived(Callback<ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler>(
    [&](ICoreWebView2StagingTextureStream* sender,
        ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs* args) {
      // Javascript send a texture stream.
      ComPtr<ICoreWebView2StagingWebTexture> texture_received;
      args->GetWebTexture(&texture_received);

      UINT64 timestamp;
      texture_received->get_Timestamp(&timestamp);
      ComPtr<IUnknown> dxgiResource;
      CHECK_FAILURE(texture->get_Resource(&dxgiResource));
      ComPtr<ID3D11Texture2D> sharedTexture;
      CHECK_FAILURE(dxgiResource.As(&sharedTexture));
      DrawTextureWithWICBitmap(sharedTexture.Get(), timestamp);

      return S_OK;
    }).Get(), &post_token));

  // Register listener of video stream from the Javascript end.
  EventRegistrationToken stopped_token;
  CHECK_FAILURE(webviewTextureStream->add_WebTextureStreamStopped(Callback<ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler>(
    [&](ICoreWebView2StagingTextureStream* sender, IUnknown* args) {

      return S_OK;
    }).Get(), &stopped_token));
}  // CreateTextureStream

HRESULT DrawTextureWithWICBitmap(ID3D11Texture2D* 2dTexture, UINT64 timestamp) {
  // It draws 2dTexture by using DirectX APIs.

  // `timestamp` can be used to find out the delta between sent (by
  // SendTextureToBrowserAfterReceivingFrameFromTheSystem) and received texture.
}
```

# API Details
```
/// Kinds of errors that can be reported by the
/// `ICoreWebView2ExperimentalTextureStream ErrorReceived` event.
[v1_enum]
typedef enum COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND {
  /// CreateTexture/PresentTexture and so on should return failed HRESULT if
  /// the texture stream is in the stopped state rather than using the
  /// error event. But there can be edge cases where the browser process
  /// knows the texture stream is in the stopped state and the host app
  /// process texture stream doesn't yet know that. Like the 10 second issue
  /// or if the script side has stopped the stream.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED,
  /// The texture already has been removed using CloseTexture.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_TEXTURE_ERROR,
  /// The texture to be presented is already in use for rendering.
  /// Call GetAvailableTexture to determine an available texture to present.
  /// The developer can technically call PresentTexture multiple times,
  /// but the first call make input texture "in use" until the browser
  /// renders it and returns the texture as "recycle" so that it can be a member
  /// of available textures.
  COREWEBVIEW2_TEXTURE_STREAM_ERROR_TEXTURE_IN_USE,
} COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND;

/// This is ICoreWebView2StagingEnvironment that returns the texture
/// stream interface.
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
  [propget] HRESULT RenderAdapterLUID([out, retval] UINT64* value);
  /// Listens for change of graphics adapter LUID of the browser.
  /// The host can get the updated LUID by RenderAdapterLUID. It is expected
  /// that the host updates texture's d3d Device with SetD3DDevice,
  /// removes existing textures and creates new texture.
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
  [propget] HRESULT Id([out, retval] LPWSTR* value);
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

  /// The texture stream becomes 'Started' state once it starts sending a texture
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
  /// The renderer cleared all registered Textures before sending
  /// the stop request event so that the callback of the next start request
  /// should register the textures again.
  /// The event is triggered when all requests for given stream id closed
  /// by the Javascript, or the host's Stop API call.
  /// texture related API calls after this event will return an error
  /// of HRESULT_FROM_WIN32(ERROR_INVALID_STATE).
  HRESULT add_Stopped(
      [in] ICoreWebView2StagingTextureStreamStoppedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for Stopped event.
  HRESULT remove_Stopped(
      [in] EventRegistrationToken token);
  /// Creates texture that will be referenced by the host and the browser.
  /// By using the texture mechanism, the host does not have to
  /// send respective texture to the renderer, instead it notifies it
  /// with internal texture id, which is the identity of the texture.
  /// The texture is 2D texture, IDXGIResource, format and will be
  /// exposed through shared HANDLE or IUnknown type through ICoreWebView2StagingTexture.
  /// Whenever the host has new texture to write, it should ask
  /// reusable ICoreWebView2StagingTexture from the GetAvailableTexture,
  /// which returns ICoreWebView2StagingTexture.
  /// If the GetAvailableTexture returns an error, then the host calls the
  /// CreateTexture to allocate new texture.
  /// The API also registers created shared handle to the browser once it
  /// created the resource.

  /// Unit for width and height is texture unit (in texels).
  /// 'https://learn.microsoft.com/en-us/windows/win32/api/d3d11ns-d3d11-d3d11_texture2d_desc'
  HRESULT CreateTexture(
    [in] UINT32 widthInTexels,
    [in] UINT32 heightInTexels,
    [out, retval] ICoreWebView2StagingTexture** texture);
  /// Returns reuseable texture for video frame rendering.
  /// Once the renderer finishes rendering of texture's video frame, which
  /// was requested by Present, the renderer informs the host so that it can
  /// be reused. The host has to create new texture with CreateTexture
  /// if the API return an error HRESULT_FROM_WIN32(ERROR_NO_MORE_ITEMS).
  HRESULT GetAvailableTexture([out, retval] ICoreWebView2StagingTexture** texture);
  /// Removes texture when the host removes the backed 2D texture.
  /// The host can save the resources by deleting 2D textures
  /// when it changes the frame sizes. The API will send a message
  /// to the browser where it will remove texture.
  HRESULT CloseTexture([in] ICoreWebView2StagingTexture* texture);
  /// Adds the provided `ICoreWebView2Texture` to the video stream as the
  /// next frame. The `ICoreWebView2Texture` must not be closed.
  /// The `ICoreWebView2Texture` must have been obtained via a call to
  /// `ICoreWebView2TextureStream::GetAvailableTexture` or `
  /// ICoreWebView2TextureStream::CreateTexture` from this `ICoreWebView2TextureStream`.
  /// If the `ICoreWebView2Texture` is closed or was created from a different
  /// `ICoreWebView2TextureStream` this method will return `E_INVALIDARG`.
  /// You should write your video frame data to the `ICoreWebView2Texture`
  /// before calling this method.

  /// After this method completes WebView2 will take some time asynchronously
  /// to send the texture to the WebView2 processes to be added to the video stream.
  /// Do not close or otherwise change the provided `ICoreWebView2Texture` after
  /// calling this method. Doing so may result in the texture not being added to
  /// the texture stream and the `ErrorReceived` event may be raised.
  HRESULT PresentTexture([in] ICoreWebView2StagingTexture* texture);

  /// Stops this texture stream from streaming and moves it into the stopped state.
  /// When moving to the stopped state the `ICoreWebView2TextureStream Stopped`
  /// event will be raised and in script the `MediaStreamTrack ended` event will
  /// be raised. Once stopped, script may again call `Webview.getTextureStream`
  /// moving the texture stream back to the start requested state.
  /// See the `StartRequested` event for details.

  /// Once stopped, calls to CreateTexture, GetAvailableTexture,
  /// PresentTexture, and CloseTexture will fail with
  /// HRESULT_FROM_WIN32(ERROR_INVALID_STATE).
  /// The `Stop` method is implicitly called when the texture stream object is
  /// destroyed.
  HRESULT Stop();
  /// The `ErrorReceived` event is raised when an error with this texture
  /// stream occurs asynchronously.
  HRESULT add_ErrorReceived(
      [in] ICoreWebView2StagingTextureStreamErrorReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for ErrorReceived event.
  HRESULT remove_ErrorReceived([in] EventRegistrationToken token);
  /// Set the D3D device this texture stream should use for creating shared
  /// texture resources. When the RenderAdapterLUIDChanged event is raised you
  /// should create a new D3D device using the RenderAdapterLUID property and
  /// call SetD3DDevice with the new D3D device.
  /// See the `CreateTextureStream` `d3dDevice` parameter for more details.
  HRESULT SetD3DDevice([in] IUnknown* d3dDevice);
  /// Event handler for receiving texture by Javascript.
  /// The WebTextureReceived event is raised when script sends a video frame to
  /// this texture stream. Allowed script will call `chrome.webview.
  /// registerTextureStream` to register a MediaStream with a specified texture
  /// stream. Video frames added to that MediaStream will be raised in the
  /// WebTextureReceived event. See `registerTextureStream` for details.
  /// Script is allowed to call registerTextureStream if it is from an HTML
  /// document with an origin allowed via
  /// `ICoreWebView2TextureStream::AddAllowedOrigin` with the
  /// `alllowWebTexture` parameter set. See `AddAllowedOrigin` for details.
  HRESULT add_WebTextureReceived(
      [in] ICoreWebView2StagingTextureStreamWebTextureReceivedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for WebTextureReceived event.
  HRESULT remove_WebTextureReceived([in] EventRegistrationToken token);
  /// The WebTextureStreamStopped event is raised when script unregisters its
  /// MediaStream from this texture stream. Script that has previously called
  /// `chrome.webview.registerTextureStream`, can call `chrome.webview.
  /// unregisterTextureStream` which will raise this event and then close
  /// associated ICoreWebView2WebTexture objects in the browser side. You should
  /// ensure that you release any references to associated
  /// ICoreWebView2WebTexture objects and their underlying resources.

  /// Once stopped, script may start again by calling `chrome.webview.
  /// registerTextureStream` and sending more frames. In this case the
  /// `ICoreWebView2TextureStream WebTextureReceived` event will be raised again.
  HRESULT add_WebTextureStreamStopped(
      [in] ICoreWebView2StagingTextureStreamWebTextureStreamStoppedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove listener for WebTextureStreamStopped event.
  HRESULT remove_WebTextureStreamStopped([in] EventRegistrationToken token);
}
/// texture that the host writes to so that the Renderer
/// will render on it.
[uuid(0836f09c-34bd-47bf-914a-99fb56ae2d07), object, pointer_default(unique)]
interface ICoreWebView2StagingTexture : IUnknown {
  /// A handle to OS shared memory containing the texture. You can open it
  /// with `ID3D11Device1::OpenSharedResource1` and write your texture data
  /// to it. Do not close it yourself. The underlying texture will be closed
  /// by WebView2. Do not change the texture after calling
  /// `ICoreWebView2TextureStream::PresentTexture` before you can retrieve it
  /// again with `GetAvailableTexture`, or you the frame may not be
  /// rendered and the `ICoreWebView2TextureStream ErrorReceived` event will
  /// be raised.
  [propget] HRESULT Handle([out, retval] HANDLE* value);
  /// Returns IUnknown type that could be query interface to IDXGIResource.
  /// The caller can write incoming texture to it.
  [propget] HRESULT Resource([out, retval] IUnknown** value);
  /// Gets timestamp of presenting texture.
  [propget] HRESULT Timestamp([out, retval] UINT64* value);
  /// Sets timestamp of presenting texture.
  /// `value` is video capture time with microseconds units.
  /// The value does not have to be exact captured time, but it should be
  /// increasing order because renderer (composition) ignores incoming
  /// video frame (texture) if its timestamp is equal or prior to
  /// the current compositing video frame. It also will be exposed to the
  /// JS with `VideoFrame::timestamp`.
  /// (https://docs.w3cub.com/dom/videoframe/timestamp.html).
  [propput] HRESULT Timestamp([in] UINT64 value);
}
/// This is the callback for new texture stream request.
[uuid(62d09330-00a9-41bf-a9ae-55aaef8b3c44), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamStartRequestedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event. There are no event args and the args
  /// parameter will be null.
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
/// The event args for the `ICoreWebViewTextureStream ErrorReceived` event.
[uuid(0e1730c1-03df-4ad2-b847-be4d63adf700), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamErrorReceivedEventArgs : IUnknown {
  /// The kind of error that has occurred.
  [propget] HRESULT Kind([out, retval]
      COREWEBVIEW2_TEXTURE_STREAM_ERROR_KIND* value);
  /// The texture with which this error is associated. For the
  /// `COREWEBVIEW2_TEXTURE_STREAM_ERROR_NO_VIDEO_TRACK_STARTED` error kind,
  /// this property will be `nullptr`.
  [propget] HRESULT Texture([out, retval] ICoreWebView2StagingTexture** value);
}
/// This is the callback for the browser process's display LUID change.
[uuid(431721e0-0f18-4d7b-bd4d-e5b1522bb110), object, pointer_default(unique)]
interface ICoreWebView2StagingRenderAdapterLUIDChangedEventHandler : IUnknown {
  /// Called to provide the implementer with the event args for the
  /// corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingTextureStream* sender,
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

/// The event args for the `ICoreWebView2TextureStream WebTextureReceived` event.
[uuid(a4c2fa3a-295a-11ed-a261-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingTextureStreamWebTextureReceivedEventArgs : IUnknown {
  /// Return ICoreWebView2StagingWebTexture object.
  [propget] HRESULT WebTexture([out, retval] ICoreWebView2StagingWebTexture** value);
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

/// Received texture that the renderer writes to so that the host
/// will read on it.
[uuid(b94265ae-4c1e-11ed-bdc3-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2StagingWebTexture : IUnknown {
  /// texture handle. The handle's lifetime is owned by the
  /// ICoreWebView2StagingTextureStream object so the host must not close it.
  /// The same handle value will be used for same texture so the host can use
  /// handle value as a unique texture key.
  /// If the host opens its own resources by handle, then it is suggested
  /// that the host removes those resources when the handle's texture size
  /// is changed because the browser also removed previously allocated different
  /// sized textures when image size is changed.
  [propget] HRESULT Handle([out, retval] HANDLE* value);

  /// Direct2D texture resource.
  /// The same resource value will be used for same texture so the host can use
  /// resource value as a unique texture key.
  /// ICoreWebView2StagingTextureStream object has a reference of the resource
  /// so ICoreWebView2StagingWebTexture holds same resource object for
  /// the same texture.
  [propget] HRESULT Resource([out, retval] IUnknown** value);

  /// It is timestamp of the web texture. Javascript can set this value
  /// with any value, but it is suggested to use same value of its original
  /// video frame that is a value of PresentTexture so that the host is able to
  /// tell the receiving texture delta.
  [propget] HRESULT Timestamp([out, retval] UINT64* value);
}

```

```ts
interface WebView extends EventTarget {
    // ... leaving out existing methods

    /// Request video stream to the WebView2 native host. The API call will
    /// trigger StartRequested event in the native host, then the native host
    /// will setup video frame from the Web cam or any other source, and provide
    /// stream with PresentTexture.

    /// The API returns Promise that will return MediaStream object when the first
    /// video stream arrive from the native host's PresentTexture.

    /// The API will return an exception of `CONSTRAINT_NOT_SATISFIED` if the
    /// requested `textureStreamId` is not supported by the native host.
    getTextureStream(textureStreamId: string): MediaStream;

    /// Provides video stream to the WebView2 native host. When JS creates new
    /// video frame from the receiving video frame by getTextureStream, it can
    /// sends it back to the native host with the API call.
    registerTextureStream(textureStreamId: string, textureStream: MediaStreamTrack): void;

    /// Stops sending video stream to the native host, which was started by
    /// registerTextureStream.
    unregisterTextureStream(textureStreamId: string): void;
}

```
