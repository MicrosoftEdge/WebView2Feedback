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

## Provide options to create WebView2 with a specific profile

### Win32 C++

```cpp
HRESULT AppWindow::CreateControllerWithOptions()
{
    auto webViewEnvironment4 =
        m_webViewEnvironment.try_query<ICoreWebView2Environment4>();

    Microsoft::WRL::ComPtr<ICoreWebView2ControllerOptions> options;
    HRESULT hr = webViewEnvironment4->CreateCoreWebView2ControllerOptions(
        m_webviewOption.profile.c_str(), m_webviewOption.isInPrivate, options.GetAddressOf());
    if (hr == E_INVALIDARG)
    {
        ShowFailure(hr, L"Unable to create WebView2 due to an invalid profile name.");
        CloseAppWindow();
        return S_FALSE;
    }
    CHECK_FAILURE(hr);

#ifdef USE_WEBVIEW2_WIN10
    if (webViewEnvironment4 && (m_dcompDevice || m_wincompCompositor))
#else
    if (webViewEnvironment4 && m_dcompDevice)
#endif
    {
        CHECK_FAILURE(webViewEnvironment4->CreateCoreWebView2CompositionControllerWithOptions(
            m_mainWindow, options.Get(),
            Callback<ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler>(
                [this](
                    HRESULT result,
                    ICoreWebView2CompositionController* compositionController) -> HRESULT {
                    auto controller =
                        wil::com_ptr<ICoreWebView2CompositionController>(compositionController)
                            .query<ICoreWebView2Controller>();
                    return OnCreateCoreWebView2ControllerCompleted(result, controller.get());
                })
                .Get()));
    }
    else
    {
        CHECK_FAILURE(webViewEnvironment4->CreateCoreWebView2ControllerWithOptions(
            m_mainWindow, options.Get(),
            Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                this, &AppWindow::OnCreateCoreWebView2ControllerCompleted)
                .Get()));
    }

    return S_OK;
}
```

## Access the profile property of WebView2

### Win32 C++

```cpp
HRESULT AppWindow::OnCreateCoreWebView2ControllerCompleted(HRESULT result, ICoreWebView2Controller* controller)
{
    // ...

    m_controller = controller;
    
    // Gets the webview object from controller.
    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(m_controller->get_CoreWebView2(&coreWebView2));
    coreWebView2.query_to(&m_webView);
    m_webView3 = coreWebView2.try_query<ICoreWebView2_3>();
    
    // Gets the profile property of webview.
    wil::com_ptr<ICoreWebView2Profile> profile;
    CHECK_FAILURE(m_webView3->get_Profile(&profile));
    
    // Accesses the profile object.
    wil::unique_cotaskmem_string name;
    CHECK_FAILURE(profile->get_ProfileName(&name));
    BOOL inPrivateModeEnabled;
    CHECK_FAILURE(profile->get_InPrivateModeEnablede(&inPrivateModeEnabled));
    wil::unique_cotaskmem_string path;
    CHECK_FAILURE(profile->get_ProfilePath(&path));
    
    // ...
}
```

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
  /// the following ASCII characters. It has a maximum length of 64 characters excluding the null terminator. It is
  /// ASCII case insensitive.
  ///    alphabet characters: a-z and A-Z
  ///    digit characters: 0-9
  ///    and '#', '@', '$', '(', ')', '+', '-', '_', '~', '.', ' ' (space).
  /// Note: the text must not end with a period '.' or ' ' (space). And, although upper case letters are
  /// allowed, they're treated just as lower case couterparts because the profile name will be mapped to
  /// the real profile directory path on disk and Windows file system handles path names in a case-insensitive way.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);
  /// Sets the `ProfileName` property.
  [propput] HRESULT ProfileName([in] LPCWSTR value);

  /// `IsInPrivateModeEnabled` property is to enable/disable InPrivate mode.
  [propget] HRESULT IsInPrivateModeEnabled([out, retval] BOOL* value);
  /// Sets the `IsInPrivateModeEnabled` property.
  [propput] HRESULT IsInPrivateModeEnabled([in] BOOL value);
}

[uuid(57FD205C-39D5-4BA1-8E7B-3E53C323EA87), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown
{
  /// Create a new ICoreWebView2ControllerOptions to be passed as a parameter of
  /// CreateCoreWebView2ControllerWithOptions and CreateCoreWebView2CompositionControllerWithOptions.
  HRESULT CreateCoreWebView2ControllerOptions(
      [in] LPCWSTR profileName,
      [in] BOOL isInPrivateModeEnabled,
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
  [propget] HRESULT Profile([out, retval] ICoreWebView2Profile** value);
}

[uuid(3B9A2AF2-E703-4C81-9D25-FCE44312E960), object, pointer_default(unique)]
interface ICoreWebView2Profile : IUnknown {
  /// Name of the profile.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);

  /// InPrivate mode is enabled or not.
  [propget] HRESULT IsInPrivateModeEnabled([out, retval] BOOL* value);

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

        Boolean IsInPrivateModeEnabled { get; set; };
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

        Boolean IsInPrivateModeEnabled { get; };

        String ProfilePath { get; };
    }
}
```

# Appendix

Next we'll consolidate all profile-wide operations/settings into the interface
`ICoreWebView2Profile`, and will also add support for erasing a profile completely.
