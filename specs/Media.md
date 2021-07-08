# Background


# Description
Enable user ability to play, pause, mute, unmute, get the volume of a media content.

# Examples

The following code snippet demonstrates how the Media related API can be used:

## Win32 C++

```cpp
// sample usage
```

## .NET and WinRT

```c#
// sample usage
```

# API Notes

See [API Details](#api-details) section below for API reference.

# API Details

## Win32 C++

```IDL
interface ICoreWebView2;
interface ICoreWebView2_2;
interface ICoreWebView2VolumeChangedEventHandler;

[uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
interface ICoreWebView2_2 : ICoreWebView2 {
  /// 
  HRESULT add_VolumeChanged(
      [in] ICoreWebView2StagingVolumeChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with add_VolumeChanged.
  HRESULT remove_VolumeChanged(
      [in] EventRegistrationToken token);

  ///
  [propget] HRESULT Volume([out, retval] double* volume);
  [propput] HRESULT Volume([in] double volume);

  ///
  HRESULT Play();
  HRESULT Pause();
  
  ///
  HRESULT Mute();
  HRESULT UnMute();

  ///
  [propget] HRESULT IsCurrentlyAudible([out, retval] BOOL* isAudible);
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2
    {
        // There are other API in this interface that we are not showing 
        public void Play();
        public void Pause();
        public double Volume { get; set; };
        public void Mute();
        public void UnMute();
        public bool IsCurrentlyAudible { get; };
    }
}
```
