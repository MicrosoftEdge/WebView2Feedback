API spec for multiple profile support
===

# Background

Previously, all WebView2s can only use one fixed Edge profile in the browser process, which is
normally the **Default** profile by not specifying a profile path, or the profile specified by the
**--profile-directory** command line switch. It means different WebView2s share a single profile
directory on disk for data storage, which might bring security concerns over cookies, autofill data,
and password management etc.. Also, they might also interfere with each other in terms of user
preference settings.

Although you can make your WebView2s use different user data directories to achieve data separation,
in such way you'll have to be running multiple browser instances (each including a browser process
and a bunch of child processes), which means much more consumption for system resources including
memory, CPU footprint, disk space (profiles under a single user data directory share several types
of data, such as compiled shaders cached for a Skia GrContext and safebrowsing data) etc. so it is
not desirable.

With all above, we're adding these new APIs to support multiple profiles, so that you can have
multiple WebView2s running with separate profiles under a single user data directory (i.e. a single
browser instance at runtime), which means separate cookies, user preference settings, and various
data storage etc., to help you build a more wonderful experience for your application.

Providing the CookieManager from the profile is more logical, and it sets the groundwork for allowing
an app to manage the cookies of a profile without having to create a WebView2 first. In order to
manage cookies through the profile, we're adding a get_CookieManager interface into the profile.
Users can use this interface to get the cookie manager, which is shared by all WebView2s associated
with this profile. The cookie manager got from profile (CoreWebView2.Profile.CookieManager) is the
same as that got from CoreWebView2 (CoreWebView2.CookieManager).

# Examples

## Win32 C++

### Provide options to create WebView2 with a specific profile

```cpp
HRESULT AppWindow::CreateControllerWithOptions()
{
    auto webViewEnvironment4 =
        m_webViewEnvironment.try_query<ICoreWebView2Environment4>();
    if (!webViewEnvironment4)
    {
        FeatureNotAvailable();
        return S_OK;
    }

    wil::com_ptr<ICoreWebView2ControllerOptions> options;
    // The validation of parameters occurs when setting the properties.
    HRESULT hr = webViewEnvironment4->CreateCoreWebView2ControllerOptions(options.GetAddressOf());
    if (hr == E_INVALIDARG)
    {
        ShowFailure(hr, L"Unable to create WebView2 due to an invalid profile name.");
        CloseAppWindow();
        return S_OK;
    }
    CHECK_FAILURE(hr);

    // If call 'put_ProfileName' with an invalid profile name, the 'E_INVALIDARG' returned immediately. 
    // ProfileName could be reused.
    CHECK_FAILURE(options->put_ProfileName(m_webviewOption.profile.c_str()));
    CHECK_FAILURE(options->put_IsInPrivateModeEnabled(m_webviewOption.isInPrivate));

    if (m_dcompDevice || m_wincompCompositor)
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

### Access the profile property of WebView2

```cpp
HRESULT AppWindow::OnCreateCoreWebView2ControllerCompleted(HRESULT result, ICoreWebView2Controller* controller)
{
    // ...

    m_controller = controller;
    
    // Gets the webview object from controller.
    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(m_controller->get_CoreWebView2(&coreWebView2));

    auto webview7 = coreWebView2.try_query<ICoreWebView2_7>();
    if (webview7)
    {
        // Gets the profile property of webview.
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webview7->get_Profile(&profile));

        // Accesses the profile object.
        BOOL inPrivateModeEnabled = FALSE;
        CHECK_FAILURE(profile->get_IsInPrivateModeEnabled(&inPrivateModeEnabled));
        CHECK_FAILURE(profile->get_ProfileName(&m_profileName));
        
        // update window title with m_profileName
        UpdateAppTitle();

        // update window icon
        SetAppIcon(inPrivateModeEnabled);        
    }
  
    // ...
}
```

### Access and use cookie manager from profile

```cpp
wil::com_ptr<ICoreWebView2CookieManager> m_cookieManager;
ScenarioCookieManagement::ScenarioCookieManagement(ICoreWebView2Controller* controller)
{
    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(controller->get_CoreWebView2(&coreWebView2));
    auto webview7 = coreWebView2.try_query<ICoreWebView2_7>();
    if (webview7)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webview7->get_Profile(&profile));
        auto profile2 = profile.try_query<ICoreWebView2Profile2>;
        if (profile2)
        {
            CHECK_FAILURE(profile2->get_CookieManager(&m_cookieManager));
        }
    }
    // ...
}

// Use cookie manager to add or update a cookie
void ScenarioCookieManagement::AddOrUpdateCookie(const std::wstring& name, const std::wstring& value, const std::wstring& domain)
{
    CHECK(m_cookieManager);
    wil::com_ptr<ICoreWebView2Cookie> cookie;
    CHECK_FAILURE(m_cookieManager->CreateCookie(
        name.c_str(), value.c_str(), domain.c_str(), L"/", &cookie));
    CHECK_FAILURE(m_cookieManager->AddOrUpdateCookie(cookie.get()));
}

// Use cookie manager to delete all cookies
void ScenarioCookieManagement::DeleteAllCookies()
{
    CHECK(m_cookieManager);
    CHECK_FAILURE(m_cookieManager->DeleteAllCookies();
}
```

### Delete profile

```cpp
HRESULT AppWindow::DeleteProfile(ICoreWebView2Controller* controller)
{
    wil::com_ptr<ICoreWebView2> coreWebView2;
    CHECK_FAILURE(controller->get_CoreWebView2(&coreWebView2));
    auto webview7 = coreWebView2.try_query<ICoreWebView2_7>();
    if (webview7)
    {
        wil::com_ptr<ICoreWebView2Profile> profile;
        CHECK_FAILURE(webview7->get_Profile(&profile));
        auto profile2 = profile.try_query<ICoreWebView2StagingProfile4>();
        if (profile2)
        {
            CHECK_FAILURE(profile2->Delete());
        }
    }
}
```

## .NET and WinRT

### Create WebView2 with a specific profile, then access the profile property of WebView2

```csharp
CoreWebView2Environment _webViewEnvironment;
WebViewCreationOptions _creationOptions;
public CreateWebView2Controller(IntPtr parentWindow)
{
    CoreWebView2ControllerOptions controllerOptions = new CoreWebView2ControllerOptions();
    controllerOptions.ProfileName = _creationOptions.profileName;
    controllerOptions.IsInPrivateModeEnabled = _creationOptions.IsInPrivateModeEnabled;

    CoreWebView2Controller controller = null;

    if (_creationOptions.entry == WebViewCreateEntry.CREATE_WITH_OPTION)
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow, options);
    }
    else
    {
        controller = await _webViewEnvironment.CreateCoreWebView2ControllerAsync(parentWindow);
    }

    string profileName = controller.CoreWebView2.Profile.ProfileName;
    bool inPrivate = controller.CoreWebView2.Profile.IsInPrivateModeEnabled;

    // update window title with profileName
    UpdateAppTitle(profileName);

    // update window icon
    SetAppIcon(inPrivate);
}
```

### Access and use the cookie manager from profile. 

```csharp
CoreWebView2CookieManager _cookieManager;
public ScenarioCookieManagement(CoreWebView2Controller controller){
    // get the cookie manager from controller
    _cookieManager = controller.CoreWebView2.Profile.CookieManager;
    // ...
}

// Use cookie manager to add or update a cookie
public AddOrUpdateCookie(string name, string value, string Domain)
{
    // create cookie with given parameters and default path
    CoreWebView2Cookie cookie = cookieManager.CreateCookie(name, value, Domain, "/");
    // add or update cookie
    _cookieManager.AddOrUpdateCookie(cookie);
}

// Use cookie manager to delete all cookies
void DeleteAllCookies()
{
    _cookieManager.DeleteAllCookies();
}
```

```csharp
public DeleteProfile(CoreWebView2Controller controller)
{
    // Get the profile object.
    CoreWebView2Profile profile = controller.CoreWebView2.Profile;
    
    // Delete current profile.
    profile.Delete();
}
```

# API Details

## Win32 C++

```IDL
interface ICoreWebView2ControllerOptions;
interface ICoreWebView2Environment5;
interface ICoreWebView2_7;
interface ICoreWebView2Profile;
interface ICoreWebView2Profile2;
interface ICoreWebView2Profile3;

/// This interface is used to manage profile options that created by 'CreateCoreWebView2ControllerOptions'.
[uuid(C2669A3A-03A9-45E9-97EA-03CD55E5DC03), object, pointer_default(unique)]
interface ICoreWebView2ControllerOptions : IUnknown {
  /// The `ProfileName` property specifies the profile's name. It has a maximum length of 64 
  /// characters excluding the null terminator and must be a valid file name.
  /// See [Naming Files, Paths, and Namespaces](https://learn.microsoft.com/windows/win32/fileio/naming-a-file)
  /// for more information on file names. It must contain only the following ASCII characters:
  ///
  ///  * alphabet characters: a-z and A-Z
  ///  * digit characters: 0-9
  ///  * and '#', '@', '$', '(', ')', '+', '-', '_', '~', '.', ' ' (space).
  ///
  /// Note: the text must not end with a period '.' or ' ' (space) nor start with a ' ' (space). And, although upper
  /// case letters are allowed, they're treated the same as their lower case counterparts because the profile name
  /// will be mapped to the real profile directory path on disk and Windows file system handles path names in a 
  /// case-insensitive way.
  [propget] HRESULT ProfileName([out, retval] LPWSTR* value);
  /// Sets the `ProfileName` property.
  [propput] HRESULT ProfileName([in] LPCWSTR value);

  /// `IsInPrivateModeEnabled` property is to enable/disable InPrivate mode.
  [propget] HRESULT IsInPrivateModeEnabled([out, retval] BOOL* value);
  /// Sets the `IsInPrivateModeEnabled` property.
  [propput] HRESULT IsInPrivateModeEnabled([in] BOOL value);
}

/// This interface is used to create 'CreateCoreWebView2ControllerOptions' object, which
/// can be passed as a parameter in 'CreateCoreWebView2ControllerWithOptions' and
/// 'CreateCoreWebView2CompositionControllerWithOptions' function for multiple profile support.
/// The profile will be created on disk or opened when calling 'CreateCoreWebView2ControllerWithOptions' or
/// 'CreateCoreWebView2CompositionControllerWithOptions' no matter InPrivate mode is enabled or not, and it will be
/// released in memory when the corresponding controller is closed but still remain on disk.
/// If create a WebView2Controller with {ProfileName="name", InPrivate=false} and then later create another one with
/// one with {ProfileName="name", InPrivate=true}, these two controllers using the same profile would be allowed to
/// run at the same time.
/// As WebView2 is built on top of Edge browser, it follows Edge's behavior pattern. To create an InPrivate WebView,
/// we gets an off-the-record profile (an InPrivate profile) from a regular profile, then create the WebView with the 
/// off-the-record profile.
[uuid(57FD205C-39D5-4BA1-8E7B-3E53C323EA87), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown {
  /// Create a new ICoreWebView2ControllerOptions to be passed as a parameter of
  /// CreateCoreWebView2ControllerWithOptions and CreateCoreWebView2CompositionControllerWithOptions.
  /// The 'options' is settable and in it the default value for profile name is the empty string,
  /// and the default value for IsInPrivateModeEnabled is false.
  /// Also the profile name can be reused.
  HRESULT CreateCoreWebView2ControllerOptions(
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

/// Used to get ICoreWebView2Profile object.
[uuid(6E5CE5F0-16E6-4A05-97D8-4E256B3EB609), object, pointer_default(unique)]
interface ICoreWebView2_7 : IUnknown {
  /// The associated `ICoreWebView2Profile` object. If this CoreWebView2 was created with a
  /// CoreWebView2ControllerOptions, the CoreWebView2Profile will match those specified options.
  /// Otherwise if this CoreWebView2 was created without a CoreWebView2ControllerOptions, then
  /// this will be the default CoreWebView2Profile for the corresponding CoreWebView2Environment.
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

[uuid(B93875C2-D6B0-434D-A2BE-93BC06CCC469), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : ICoreWebView2Profile {
  /// Get the cookie manager object for the profile. All CoreWebView2s associated with this profile share this same cookie manager and will have the same CoreWebView2.CookieManager property value.
  /// See ICoreWebView2CookieManager.
  [propget] HRESULT CookieManager([out, retval] ICoreWebView2CookieManager** cookieManager);
}

[uuid(1c1ae2cc-d5c2-ffe3-d3e7-7857035d23b7), object, pointer_default(unique)]
interface ICoreWebView2Profile3 : ICoreWebView2Profile2 {
  /// All webviews on this profile will be closed, and the profile will be marked for deletion.
  /// After the Delete() call completes, The render process of webviews on this profile will
  /// asynchronously exit with the reason:`COREWEBVIEW2_PROCESS_FAILED_REASON_PROFILE_DELETED`.
  /// See 'COREWEBVIEW2_PROCESS_FAILED_REASON::COREWEBVIEW2_PROCESS_FAILED_REASON_PROFILE_DELETED'
  /// for more details. The profile directory on disk will be actually deleted when the browser
  /// process exits. Webview2 creation will fail with the HRESULT is ERROR_INVALID_STATE(0x8007139FL)
  /// if you create it with the same name as a profile that is being deleted.
  HRESULT Delete(); 
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
    
        CoreWebView2ControllerOptions CreateCoreWebView2ControllerOptions();

        Windows.Foundation.IAsyncOperation<CoreWebView2Controller>
        CreateCoreWebView2ControllerAsync(
            CoreWebView2ControllerWindowReference ParentWindow,
            CoreWebView2ControllerOptions options);
        
        Windows.Foundation.IAsyncOperation<CoreWebView2CompositionController>
        CreateCoreWebView2CompositionControllerAsync(
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

        CoreWebView2CookieManager CookieManager { get; };
        
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile3")]
        {
            // ICoreWebView2Profile3 members
            void Delete();
        }
    }
}
```

# Appendix

Next we'll consolidate all profile-wide operations/settings into the interface
`ICoreWebView2Profile`, and will also add support for erasing a profile completely
if strongly requested.
