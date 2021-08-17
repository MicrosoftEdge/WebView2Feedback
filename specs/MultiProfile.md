API spec for multiple profile support
===

# Background

Currently, all WebView2s can only use one fixed Edge profile in the browser process, which is
normally the **Default** profile or the profile specified by the **--profile-directory** command
line switch. Regarding this we have got a bunch of requests to support multiple profiles, so we're
adding these new APIs.

With this you can have different WebView2s running with separate profiles under a given user data
directory, which means separate cookies, user preference settings, and various data storage etc.,
to enable you to build a more wonderful experience for your application.

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
interface ICoreWebView2Staging6;
interface ICoreWebView2StagingCreateControllerOptions;
interface ICoreWebView2StagingEnvironment4;
interface ICoreWebView2StagingProfile;

[uuid(57FD205C-39D5-4BA1-8E7B-3E53C323EA87), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment4 : IUnknown
{
  /// Create a new ICoreWebView2StagingCreateControllerOptions to be passed as a parameter of
  /// CreateCoreWebView2ControllerWithOptions and CreateCoreWebView2CompositionControllerWithOptions.
  HRESULT CreateCoreWebView2CreateControllerOptions(
      [in] LPCWSTR profileName,
      [in] BOOL inPrivateModeEnabled,
      [out, retval] ICoreWebView2StagingCreateControllerOptions** options);

  /// Create a new WebView with options.
  HRESULT CreateCoreWebView2ControllerWithOptions(
      [in] HWND parentWindow,
      [in] ICoreWebView2StagingCreateControllerOptions* options,
      [in] ICoreWebView2CreateCoreWebView2ControllerCompletedHandler* handler);

  /// Create a new WebView in visual hosting mode with options.
  HRESULT CreateCoreWebView2CompositionControllerWithOptions(
      [in] HWND parentWindow,
      [in] ICoreWebView2StagingCreateControllerOptions* options,
      [in] ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler* handler);
}

[uuid(C2669A3A-03A9-45E9-97EA-03CD55E5DC03), object, pointer_default(unique)]
interface ICoreWebView2StagingCreateControllerOptions : IUnknown {
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

[uuid(6E5CE5F0-16E6-4A05-97D8-4E256B3EB609), object, pointer_default(unique)]
interface ICoreWebView2Staging6 : IUnknown {
  /// The associated `ICoreWebView2StagingProfile` object.
  [propget] HRESULT Profile([out, retval] ICoreWebView2StagingProfile** profile);
}

[uuid(3B9A2AF2-E703-4C81-9D25-FCE44312E960), object, pointer_default(unique)]
interface ICoreWebView2StagingProfile : IUnknown {
  /// Name of the profile.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);

  /// InPrivate mode is enabled or not.
  [propget] HRESULT InPrivateModeEnabled([out, retval] BOOL* enabled);

  /// Full path of the profile directory.
  [propget] HRESULT ProfilePath([out, retval] LPWSTR* value);

  /// TODO: All profile-wide operations/settings will be put below.
}
```

# Appendix

Next we'll consolidate all profile-wide operations/settings into the interface
`ICoreWebView2StagingProfile`, and will also add support for erasing a profile completely.
