# Background
WebView2 is a control that developers can implement for part of, or for the entirety of their app. In the either case, developers may need the ability to control the media within the webview's bounds. This API will allow developers to control the sound of each webview2 instance by enabling the mute/unmute of the media within the webview. There will also be the ability to check if the sound is muted or audible.

# Description
Enable end developer to `Mute`, `Unmute` a webview content. And ability to check for the `IsMuted` and `IsAudioPlaying`.

# Examples

The following code snippet demonstrates how the Media related API can be used:

## Win32 C++

```cpp
AudioComponent::AudioComponent(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [IsAudioPlayingChanged]
    // Register a handler for the IsAudioPlayingChanged event.
    // This handler just announces the audible state on the window's title bar.
    CHECK_FAILURE(m_webView->add_IsAudioPlayingChanged(
        Callback<ICoreWebView2StagingIsAudioPlayingChangedEventHandler>(
            [this](ICoreWebView2Staging2* sender, IUnknown* args) -> HRESULT {
                BOOL isAudioPlaying;
                CHECK_FAILURE(sender->get_IsAudioPlaying(&isAudioPlaying));

                BOOL isMuted;
                CHECK_FAILURE(sender->get_IsMuted(&isMuted));

                wil::unique_cotaskmem_string title;
                m_webView->get_DocumentTitle(&title);
                std::wstring result = L"";

                //! [IsAudioPlaying]
                if (isAudioPlaying)
                {
                    //! [IsMuted]
                    if (isMuted)
                    {
                        result = L"🔇 " + std::wstring(title.get());
                    }
                    else
                    {
                        result = L"🔊 " + std::wstring(title.get());
                    }
                    //! [IsMuted]
                }
                else
                {
                    result = std::wstring(title.get());
                }
                //! [IsAudioPlaying]

                SetWindowText(m_appWindow->GetMainWindow(), result.c_str());
                return S_OK;
            })
            .Get(),
        &m_isAudioPlayingChangedToken));
    //! [IsAudioPlayingChanged]
}

//! [Mute]
// Mute the current window and show a mute icon on the title bar
 void AudioComponent::Mute()
 {
     m_webView->Mute();
 }
//! [Mute]

//! [Unmute]
// Unmute the current window and hide the mute icon on the title bar
 void AudioComponent::Unmute()
 {
     m_webView->Unmute();
 }
 //! [Unmute]
```

## .NET and WinRT

```c#
    void WebView_IsAudioPlayingChanged(object sender, object e)
    {
        bool is_audio_playing = webView.CoreWebView2.IsAudioPlaying;
        bool is_muted = webView.CoreWebView2.IsMuted;
        string currentDocumentTitle = webView.CoreWebView2.DocumentTitle;
        if (is_audio_playing)
        {
            if (is_muted)
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
interface ICoreWebView2StagingIsAudioPlayingChangedEventHandler;

  /// Mutes all audio output from this CoreWebView2.
  ///
  /// \snippet AudioComponent.cpp Mute
  HRESULT Mute();

  /// Unmutes all audio output from this CoreWebView2.
  ///
  /// \snippet AudioComponent.cpp Unmute
  HRESULT Unmute();
  
  /// Adds an event handler for the `IsAudioPlayingChanged` event.
  /// `IsAudioPlayingChanged` runs when the audible state changes.
  ///
  /// \snippet AudioComponent.cpp IsAudioPlayingChanged
  HRESULT add_IsAudioPlayingChanged(
      [in] ICoreWebView2StagingIsAudioPlayingChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_IsAudioPlayingChanged`.
  HRESULT remove_IsAudioPlayingChanged(
      [in] EventRegistrationToken token);
  
  /// Indicates whether any audio output from this CoreWebView2 is audible.
  /// CoreWebView2 can be audible when muted, IsAudioPlaying is used to indicate
  /// if there are audio currently playing.
  ///
  /// \snippet AudioComponent.cpp IsAudioPlaying
  [propget] HRESULT IsAudioPlaying([out, retval] BOOL* value);
}

/// Implements the interface to receive `IsAudioPlayingChanged` events.  Use the
/// IsAudioPlaying method to get the audible state.
[uuid(5DEF109A-2F4B-49FA-B7F6-11C39E513328), object, pointer_default(unique)]
interface ICoreWebView2StagingIsAudioPlayingChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Staging2* sender, [in] IUnknown* args);
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
            Boolean IsAudioPlaying { get; };

            event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> IsAudioPlayingChanged;
            void Mute();
            void Unmute();

        // ...
    }
}
```
