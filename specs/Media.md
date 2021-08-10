# Background
WebView2 is a control that developers can implement for part of, or for the entirety of their app. In the either case, developers may need the ability to control the media within the webview's bounds. This API will allow developers to control the sound of each webview2 instance by enabling the mute/unmute of the media within the webview. There will also be the ability to check if the sound is muted or audible.

# Description
Enable end developer to `Mute`, `Unmute` a webview content. And ability to check for the `IsMuted` and `IsCurrentlyAudible`.

# Examples

The following code snippet demonstrates how the Media related API can be used:

## Win32 C++

```cpp
AudioComponent::AudioComponent(AppWindow* appWindow)
    : m_appWindow(appWindow), m_webView(appWindow->GetWebView())
{
    //! [IsCurrentlyAudibleChanged]
    // Register a handler for the IsCurrentlyAudibleChanged event.
    // This handler just announces the audible state on the window's title bar.
    CHECK_FAILURE(m_webView->add_IsCurrentlyAudibleChanged(
        Callback<ICoreWebView2StagingIsCurrentlyAudibleChangedEventHandler>(
            [this](ICoreWebView2Staging2* sender, IUnknown* args) -> HRESULT {
                BOOL isAudible;
                CHECK_FAILURE(sender->get_IsCurrentlyAudible(&isAudible));

                BOOL isMuted;
                CHECK_FAILURE(sender->get_IsMuted(&isMuted));

                wil::unique_cotaskmem_string title;
                m_webView->get_DocumentTitle(&title);
                std::wstring result = (isAudible ? L"🔊 " : L"") + std::wstring(title.get()) +
                                      (isMuted ? L" 🔇" : L"");

                SetWindowText(m_appWindow->GetMainWindow(), result.c_str());
                return S_OK;
            })
            .Get(),
        &m_isCurrentlyAudibleChangedToken));
    //! [IsCurrentlyAudibleChanged]

    //! [IsMutedChanged]
    // Register a handler for the IsMutedChanged event.
    // This handler just announces the mute state on the window's title bar.
    CHECK_FAILURE(m_webView->add_IsMutedChanged(
        Callback<ICoreWebView2StagingIsMutedChangedEventHandler>(
            [this](ICoreWebView2Staging2* sender, IUnknown* args) -> HRESULT {
                BOOL isAudible;
                CHECK_FAILURE(sender->get_IsCurrentlyAudible(&isAudible));
                
                BOOL isMuted;
                CHECK_FAILURE(sender->get_IsMuted(&isMuted));

                wil::unique_cotaskmem_string title;
                m_webView->get_DocumentTitle(&title);
                std::wstring result = (isAudible ? L"🔊 " : L"") + std::wstring(title.get()) + 
                    (isMuted ? L" 🔇" : L"");

                SetWindowText(m_appWindow->GetMainWindow(), result.c_str());
                return S_OK;
            })
            .Get(),
        &m_isMutedChangedToken));
    //! [IsMutedChanged]
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
    void WebView_IsMutedChanged(object sender, object e)
    {
        bool is_muted = webView.CoreWebView2.IsMuted;
        string currentDocumentTitle = webView.CoreWebView2.DocumentTitle;
        _isMuted = is_muted;
        this.Title = (_isAudible ? "🔊 " : "") + currentDocumentTitle + (is_muted ? " 🔇" : "");

    }

    void WebView_IsCurrentlyAudibleChanged(object sender, object e)
    {
        bool is_currently_audible = webView.CoreWebView2.IsCurrentlyAudible;
        string currentDocumentTitle = webView.CoreWebView2.DocumentTitle;
        _isAudible = is_currently_audible;
        this.Title = (is_currently_audible ? "🔊 " : "") + currentDocumentTitle + (_isMuted ? " 🔇" : "");
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
interface ICoreWebView2StagingIsMutedChangedEventHandler;
interface ICoreWebView2StagingIsCurrentlyAudibleChangedEventHandler;

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
  /// Adds an event handler for the `IsMutedChanged` event.
  /// `IsMutedChanged` runs when the mute state changes. The event may run 
  /// when `Mute` and `Unmute` are called.
  HRESULT add_IsMutedChanged(
      [in] ICoreWebView2StagingIsMutedChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_IsMutedChanged`.
  HRESULT remove_IsMutedChanged(
      [in] EventRegistrationToken token);

  /// Mutes all audio output from this CoreWebView2.
  HRESULT Mute();
  /// Unmutes all audio output from this CoreWebView2.
  HRESULT Unmute();
  /// Indicates whether all audio output from this CoreWebView2 is muted or not.
  [propget] HRESULT IsMuted([out, retval] BOOL* isMuted);
  
  /// Adds an event handler for the `IsCurrentlyAudibleChanged` event.
  /// `IsCurrentlyAudibleChanged` runs when the audible state changes.
  HRESULT add_IsCurrentlyAudibleChanged(
      [in] ICoreWebView2StagingIsCurrentlyAudibleChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_IsCurrentlyAudibleChanged`.
  HRESULT remove_IsCurrentlyAudibleChanged(
      [in] EventRegistrationToken token);
  
  /// Indicates whether any audio output from this CoreWebView2 is audible.
  /// IsCurrentlyAudible is used to indicate if there is audio or media currently playing and can be true even if IsMuted is true or the volume is turned off.
  /// if there are audio/media currently playing.
  [propget] HRESULT IsCurrentlyAudible([out, retval] BOOL* isAudible);
}

/// Implements the interface to receive `IsMutedChanged` events.  Use the
/// IsMuted method to get the mute state.
[uuid(B357DC3B-D4C3-4FDE-BF45-C11ECE606B98), object, pointer_default(unique)]
interface ICoreWebView2StagingIsMutedChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Staging2* sender, [in] IUnknown* args);
}

/// Implements the interface to receive `IsCurrentlyAudibleChanged` events.  Use the
/// IsCurrentlyAudible method to get the audible state.
[uuid(5DEF109A-2F4B-49FA-B7F6-11C39E513328), object, pointer_default(unique)]
interface ICoreWebView2StagingIsCurrentlyAudibleChangedEventHandler : IUnknown {
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
        Boolean IsCurrentlyAudible { get; };
        void Mute();
        void Unmute();

        // ...
    }
}
```
