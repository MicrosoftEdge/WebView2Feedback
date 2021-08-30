# Background
WebView2 is a control that developers can implement for part of, or for the entirety of their app. In the either case, developers may need the ability to control the media within the webview's bounds. This API will allow developers to control the sound of each webview2 instance by enabling the mute/unmute of the media within the webview. There will also be the ability to check if the sound is muted or audible.

# Description
Enable end developer to `Mute`, `Unmute` a webview content. And ability to check for the `IsMuted` and `IsAudioPlaying`.

# Examples

The following code snippet demonstrates how the Media related API can be used:

## Win32 C++

```cpp
 //! [IsDocumentPlayingAudioChanged] [IsDocumentPlayingAudio] [IsMuted] [Mute] [Unmute]
AudioComponent::AudioComponent(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    webview6 = m_webView.try_query<ICoreWebView2_6>();
    // Register a handler for the IsDocumentPlayingAudioChanged event.
    // This handler just announces the audible state on the window's title bar.
    CHECK_FAILURE(webview6->add_IsDocumentPlayingAudioChanged(
        Callback<ICoreWebView2StagingIsDocumentPlayingAudioChangedEventHandler>(
            [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
                BOOL isDocumentPlayingAudio;
                CHECK_FAILURE(sender->get_IsDocumentPlayingAudio(&isDocumentPlayingAudio));

                BOOL isMuted;
                CHECK_FAILURE(sender->get_IsMuted(&isMuted));

                wil::unique_cotaskmem_string title;
                CHECK_FAILURE(m_webView->get_DocumentTitle(&title));
                std::wstring result = L"";

                if (isDocumentPlayingAudio)
                {
                    if (isMuted)
                    {
                        result = L"🔇 " + std::wstring(title.get());
                    }
                    else
                    {
                        result = L"🔊 " + std::wstring(title.get());
                    }
                }
                else
                {
                    result = std::wstring(title.get());
                }

                SetWindowText(m_appWindow->GetMainWindow(), result.c_str());
                return S_OK;
            })
            .Get(),
        &m_isDocumentPlayingAudioChangedToken));
}

// Mute the current window and show a mute icon on the title bar
 void AudioComponent::Mute()
 {
    CHECK_FAILURE(webview6->Mute());
 }

// Unmute the current window and hide the mute icon on the title bar
 void AudioComponent::Unmute()
 {
    CHECK_FAILURE(webview6->Unmute());
 }
 //! [IsDocumentPlayingAudioChanged] [IsDocumentPlayingAudio] [IsMuted] [Mute] [Unmute]
```

## .NET and WinRT

```c#
    void WebView_IsDocumentPlayingAudioChanged(object sender, object e)
    {
        bool isDocumentPlayingAudio = webView.CoreWebView2.IsDocumentPlayingAudio;
        bool isMuted = webView.CoreWebView2.IsMuted;
        string currentDocumentTitle = webView.CoreWebView2.DocumentTitle;
        if (isDocumentPlayingAudio)
        {
            if (isMuted)
            {
                this.Title = "🔇 " + currentDocumentTitle;
            }
            else
            {
                this.Title = "🔊 " + currentDocumentTitle;
            }
        }
        else
        {
            this.Title = currentDocumentTitle;
        }
    }
    
    void MuteCmdExecuted(object target, ExecutedRoutedEventArgs e)
    {
        webView.CoreWebView2.Mute();
    }

    void UnmuteCmdExecuted(object target, ExecutedRoutedEventArgs e)
    {
        webView.CoreWebView2.Unmute();
    }
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2StagingIsDocumentPlayingAudioChangedEventHandler;

[uuid(71c906d9-4a4d-4dbe-aa1b-db64f4de594e), object, pointer_default(unique)]
interface ICoreWebView2_6 : ICoreWebView2_5 {
  /// Mutes all audio output from this CoreWebView2.
  ///
  /// \snippet AudioComponent.cpp Mute
  HRESULT Mute();

  /// Unmutes all audio output from this CoreWebView2.
  ///
  /// \snippet AudioComponent.cpp Unmute
  HRESULT Unmute();

  /// Indicates whether all audio output from this CoreWebView2 is muted or not.
  ///
  /// \snippet AudioComponent.cpp IsMuted
  [propget] HRESULT IsMuted([out, retval] BOOL* value);
  
  /// Adds an event handler for the `IsDocumentPlayingAudioChanged` event.
  /// `IsDocumentPlayingAudioChanged` is raised when the IsDocumentPlayingAudio property changes value.
  ///
  /// \snippet AudioComponent.cpp IsDocumentPlayingAudioChanged
  HRESULT add_IsDocumentPlayingAudioChanged(
      [in] ICoreWebView2IsDocumentPlayingAudioChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_IsDocumentPlayingAudioChanged`.
  HRESULT remove_IsDocumentPlayingAudioChanged(
      [in] EventRegistrationToken token);
  
  /// Indicates whether any audio output from this CoreWebView2 is playing.
  /// This property will be true if audio is playing even if IsMuted is true.
  /// if there are audio currently playing.
  ///
  /// \snippet AudioComponent.cpp IsDocumentPlayingAudio
  [propget] HRESULT IsDocumentPlayingAudio([out, retval] BOOL* value);
}

/// Implements the interface to receive `IsDocumentPlayingAudioChanged` events.  Use the
/// IsDocumentPlayingAudio method to get the audible state.
[uuid(5DEF109A-2F4B-49FA-B7F6-11C39E513328), object, pointer_default(unique)]
interface ICoreWebView2StagingIsDocumentPlayingAudioChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] IUnknown* args);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2
    {
        // ...
            Boolean IsMuted { get; };
            Boolean IsDocumentPlayingAudio { get; };

            event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> IsDocumentPlayingAudioChanged;
            void Mute();
            void Unmute();

        // ...
    }
}
```
