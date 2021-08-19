API spec for multiple profile support
===

# Background

Previously, all WebView2s can only use one fixed Edge profile in the browser process, which is
normally the **Default** profile or the profile specified by the **--profile-directory** command
line switch. It means different WebView2s share a single profile directory on disk for data storage,
which might bring security concerns over cookies, autofill data, and password management etc.. Also,
they might also interfere with each other in terms of user preference settings.

Although you can make your WebView2s use different user data directories to achieve data separation,
in such way you'll have to be running multiple browser instances (each including a browser process
and a bunch of child processes), which means much more consumption for system resources including
memory, CPU footprint, disk space etc. so it is not desirable.

With all above, we're adding these new APIs to support multiple profiles, so that you can have
multiple WebView2s running with separate profiles under a single user data directory (i.e. a single
browser instance at runtime), which means separate cookies, user preference settings, and various
data storage etc., to help you build a more wonderful experience for your application.

# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.
    The sample code for C++ and C# should demonstrate the same thing.

    The general format is:

    ## FirstFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    ## SecondFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    As an example of this section, see the Examples section for the Custom Downloads
    APIs (https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md). 
-->

# API Details

## Win32 C++

```IDL
interface ICoreWebView2ControllerOptions;
interface ICoreWebView2Environment5;
interface ICoreWebView2_7;
interface ICoreWebView2Profile;

[uuid(C2669A3A-03A9-45E9-97EA-03CD55E5DC03), object, pointer_default(unique)]
interface ICoreWebView2ControllerOptions : IUnknown {
  /// `ProfileName` property is to specify a profile name, which is only allowed to contain
  /// the following ASCII characters with the maximum length as 64 and will be treated in a
  /// case insensitive way.
  ///    alphabet characters: a-z and A-Z
  ///    digit characters: 0-9
  ///    and '#', '@', '$', '(', ')', '+', '-', '_', '~', '.', ' ' (space).
  /// Note: the text must not end with a period '.' or ' ' (space). And, although upper case letters are
  /// allowed, they're treated just as lower case couterparts because the profile name will be mapped to
  /// the real profile directory path on disk and Windows file system handles path names in a case-insensitive way.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);
  /// Sets the `ProfileName` property.
  [propput] HRESULT ProfileName([in] LPCWSTR value);

  /// `InPrivateModeEnabled` property is to enable/disable InPrivate mode.
  [propget] HRESULT InPrivateModeEnabled([out, retval] BOOL* enabled);
  /// Sets the `InPrivateModeEnabled` property.
  [propput] HRESULT InPrivateModeEnabled([in] BOOL enabled);
}

[uuid(57FD205C-39D5-4BA1-8E7B-3E53C323EA87), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown
{
  /// Create a new ICoreWebView2ControllerOptions to be passed as a parameter of
  /// CreateCoreWebView2ControllerWithOptions and CreateCoreWebView2CompositionControllerWithOptions.
  HRESULT CreateCoreWebView2ControllerOptions(
      [in] LPCWSTR profileName,
      [in] BOOL inPrivateModeEnabled,
      [out, retval] ICoreWebView2ControllerOptions** options);

  /// Create a new WebView with options.
  HRESULT CreateCoreWebView2ControllerWithOptions(
      [in] HWND parentWindow,
      [in] ICoreWebView2ControllerOptions* options,
      [in] ICoreWebView2CreateCoreWebView2ControllerCompletedHandler* handler);

  /// Create a new WebView in visual hosting mode with options.
  HRESULT CreateCoreWebView2CompositionControllerWithOptions(
      [in] HWND parentWindow,
      [in] ICoreWebView2ControllerOptions* options,
      [in] ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler* handler);
}

[uuid(6E5CE5F0-16E6-4A05-97D8-4E256B3EB609), object, pointer_default(unique)]
interface ICoreWebView2_7 : IUnknown {
  /// The associated `ICoreWebView2Profile` object.
  [propget] HRESULT Profile([out, retval] ICoreWebView2Profile** profile);
}

[uuid(3B9A2AF2-E703-4C81-9D25-FCE44312E960), object, pointer_default(unique)]
interface ICoreWebView2Profile : IUnknown {
  /// Name of the profile.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);

  /// InPrivate mode is enabled or not.
  [propget] HRESULT InPrivateModeEnabled([out, retval] BOOL* enabled);

  /// Full path of the profile directory.
  [propget] HRESULT ProfilePath([out, retval] LPWSTR* value);

  // TODO: All profile-wide operations/settings will be put below in the future.
}
```

## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2ControllerOptions;
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2;
    runtimeclass CoreWebView2Profile;

    runtimeclass CoreWebView2ControllerOptions
    {        
        String ProfileName { get; set; };

        Int32 InPrivateModeEnabled { get; set; };
    }
    
    runtimeclass CoreWebView2Environment
    {
        // ...
    
        CoreWebView2ControllerOptions CreateCoreWebView2ControllerOptions(
            String ProfileName, Int32 InPrivateModeEnabled);
        
        Windows.Foundation.IAsyncOperation<CoreWebView2Controller>
        CreateCoreWebView2ControllerWithOptionsAsync(
            CoreWebView2ControllerWindowReference ParentWindow,
            CoreWebView2ControllerOptions options);
        
        Windows.Foundation.IAsyncOperation<CoreWebView2CompositionController>
        CreateCoreWebView2CompositionControllerWithOptionsAsync(
            CoreWebView2ControllerWindowReference ParentWindow,
            CoreWebView2ControllerOptions options);
    }
    
    runtimeclass CoreWebView2
    {
        // ...
        CoreWebView2Profile Profile { get; };
    }
    
    runtimeclass CoreWebView2Profile
    {
        String ProfileName { get; };

        Int32 InPrivateModeEnabled { get; };

        String ProfilePath { get; };
    }
}
```

# Appendix

Next we'll consolidate all profile-wide operations/settings into the interface
`ICoreWebView2Profile`, and will also add support for erasing a profile completely.
