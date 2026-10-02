Throttling Control - Script Throttling
===

# Background
Web content in WebView2 is generally subject to the same Web Platform
restrictions as in the Microsoft Edge browser. However, some of the scenarios
for WebView2 applications differ from the scenarios in the browser. For this
reason, we're providing a set of APIs to fine-tune performance of scripts
running in WebView2. These APIs allow WebView2 applications to achieve two
things:

* Customize script timers (`setTimeout` and `setInterval`) throttling under
different page states (foreground, background, and background with intensive
throttling)
* Throttle script timers in select hosted iframes

# Examples

## Throttle timers in visible WebView

Throttling Control APIs allow you to throttle JavaScript timers in scenarios
where the WebView2 control in your application needs to remain visible, but
consume less resources, for example, when the user is not interactive.

```c#
void OnNoUserInteraction()
{
    // User is not interactive, keep webview visible but throttle timers to 500ms.
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceForeground = 500;
}

void OnUserInteraction()
{
    // User is interactive again, unthrottle foreground timers.
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceForeground = 0;
}
```

```cpp
void ScenarioThrottlingControl::OnNoUserInteraction()
{
    wil::com_ptr<ICoreWebView2Settings> settings;
    m_webview->get_Settings(&settings);
    auto settings2 = settings.try_query<ICoreWebView2Settings9>();
    CHECK_FEATURE_RETURN_EMPTY(settings2);

    // User is not interactive, keep webview visible but throttle timers to
    // 500ms.
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceForeground(500));
}

void ScenarioThrottlingControl::OnUserInteraction()
{
    wil::com_ptr<ICoreWebView2Settings> settings;
    m_webview->get_Settings(&settings);
    auto settings2 = settings.try_query<ICoreWebView2Settings9>();
    CHECK_FEATURE_RETURN_EMPTY(settings2);

    // User is interactive again, unthrottle foreground timers.
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceForeground(0));
}
```

## Unthrottle timers in hidden WebView

Throttling Control APIs allow you to set a custom throttling interval for timers
on hidden WebViews. For example, if there's logic in your app that runs in
JavaScript but doesn't need to render content, you can keep the WebView hidden
and unthrottle its timers.

```C#
void SetupHiddenWebViewCore()
{
    // This WebView2 will remain hidden but needs to keep running timers.
    // Unthrottle background timers.
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceBackground = 0;
    // Effectively disable intensive throttling by overriding its timer interval.
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceIntensive = 0;
    webView.Visibility = System.Windows.Visibility.Hidden;
}

void DisableHiddenWebViewCore()
{
    webView.Visibility = System.Windows.Visibility.Visible;
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceBackground = 1000;
    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceIntensive = 60000;
}
```

```cpp
void ScenarioThrottlingControl::SetupHiddenWebViewCore()
{
    wil::com_ptr<ICoreWebView2Settings> settings;
    m_webview->get_Settings(&settings);
    auto settings2 = settings.try_query<ICoreWebView2Settings9>();
    CHECK_FEATURE_RETURN_EMPTY(settings2);

    // This WebView2 will remain hidden but needs to keep running timers.
    // Unthrottle background timers.
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceBackground(0));
    // Effectively disable intensive throttling by overriding its timer interval.
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceIntensive(0));

    CHECK_FAILURE(m_appWindow->GetWebViewController()->put_IsVisible(FALSE));
}

void ScenarioThrottlingControl::DisableHiddenWebViewCore()
{
    CHECK_FAILURE(m_appWindow->GetWebViewController()->put_IsVisible(TRUE));

    wil::com_ptr<ICoreWebView2Settings> settings;
    m_webview->get_Settings(&settings);
    auto settings2 = settings.try_query<ICoreWebView2Settings9>();
    CHECK_FEATURE_RETURN_EMPTY(settings2);

    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceBackground(1000));
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceIntensive(60000));
}
```

## Throttle timers in hosted iframes

Throttling Control APIs allow you to throttle timers in specific frames within
the WebView2 control. For example, if your application uses iframes to host 3rd
party content, you can select and mark these frames to be throttled separately
from the main frame and other regular, unmarked frames.

```C#
void SetupIsolatedFramesHandler()
{
    // You can use the frame properties to determine whether it should be
    // marked to be throttled separately from main frame.
    webView.CoreWebView2.FrameCreated += (sender, args) =>
    {
        if (args.Frame.Name == "isolated")
        {
            args.Frame.ShouldUseIsolatedThrottling = true;
        }
    };

    webView.CoreWebView2.Settings.ThrottlingIntervalPreferenceIsolated = 500;
}
```

```cpp
void ScenarioThrottlingControl::SetupIsolatedFramesHandler()
{
    auto webview4 = m_webview.try_query<ICoreWebView2_4>();
    CHECK_FEATURE_RETURN_EMPTY(webview4);

    // You can use the frame properties to determine whether it should be
    // marked to be throttled separately from main frame.
    CHECK_FAILURE(webview4->add_FrameCreated(
        Callback<ICoreWebView2FrameCreatedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
            {
                wil::com_ptr<ICoreWebView2Frame> webviewFrame;
                CHECK_FAILURE(args->get_Frame(&webviewFrame));

                auto webviewFrame6 =
                    webviewFrame.try_query<ICoreWebView2Frame6>();
                CHECK_FEATURE_RETURN_HRESULT(webviewFrame6);

                wil::unique_cotaskmem_string name;
                CHECK_FAILURE(webviewFrame->get_Name(&name));
                if (wcscmp(name.get(), L"isolated") == 0)
                {
                    CHECK_FAILURE(webviewFrame6->put_ShouldUseIsolatedThrottling(TRUE));
                }

                return S_OK;
            })
            .Get(),
        &m_frameCreatedToken));

    wil::com_ptr<ICoreWebView2Settings> settings;
    m_webview->get_Settings(&settings);
    auto settings2 = settings.try_query<ICoreWebView2Settings9>();
    CHECK_FAILURE(settings2->put_ThrottlingIntervalPreferenceIsolated(500));
}
```

# API Details
```cpp
/// A continuation of the `ICoreWebView2Settings` interface to support
/// ThrottlingPreference.
[uuid(00f1b5fb-91ed-4722-9404-e0f8fd1e6b0a), object, pointer_default(unique)]
interface ICoreWebView2Settings9 : ICoreWebView2Settings8 {
  /// The preferred wake up interval (in milliseconds) to use for throttleable
  /// JavaScript tasks (`setTimeout` and `setInterval`), when the WebView is in
  /// foreground state. A WebView is in foreground state when its `IsVisible`
  /// property is `TRUE`.
  ///
  /// A wake up interval is the amount of time that needs to pass before the
  /// WebView2 Runtime checks for new timer tasks to run.
  ///
  /// The WebView2 Runtime will try to respect the preferred interval set by the
  /// application, but the effective value will be constrained by resource and
  /// platform limitations. Setting a value of `0` means a preference of no
  /// throttling to be applied. The default value is a constant determined by
  /// the running version of the WebView2 Runtime.
  ///
  /// For example, an application might use a foreground value of 30 ms for
  /// moderate throttling scenarios, or match the default background value
  /// (usually 1000 ms).
  [propget] HRESULT ThrottlingIntervalPreferenceForeground([out, retval] UINT32* value);
  /// Sets the `ThrottlingIntervalPreferenceForeground` property.
  [propput] HRESULT ThrottlingIntervalPreferenceForeground([in] UINT32 value);

  /// The preferred wake up interval (in milliseconds) to use for throttleable
  /// JavaScript tasks (`setTimeout` and `setInterval`), when the WebView is in
  /// background state, with no intensive throttling. A WebView is in background
  /// state when its `IsVisible` property is `FALSE`. Intensive throttling is a
  /// substate of background state. For more details about intensive throttling,
  /// see [Intensive throttling of Javascript timer wake ups](https://chromestatus.com/feature/4718288976216064).
  ///
  /// A wake up interval is the amount of time that needs to pass before the
  /// WebView2 Runtime checks for new timer tasks to run.
  ///
  /// The WebView2 Runtime will try to respect the preferred interval set by the
  /// application, but the effective value will be constrained by resource and
  /// platform limitations. Setting a value of `0` means a preference of no
  /// throttling to be applied. The default value is a constant determined by
  /// the running version of the WebView2 Runtime. All other background state
  /// policies (including intensive throttling) are effective independently of
  /// this setting.
  ///
  /// For example, an application might use a background value of 100 ms to
  /// relax the default background value (usually 1000 ms).
  [propget] HRESULT ThrottlingIntervalPreferenceBackground([out, retval] UINT32* value);
  /// Sets the `ThrottlingIntervalPreferenceBackground` property.
  [propput] HRESULT ThrottlingIntervalPreferenceBackground([in] UINT32 value);

  /// The preferred wake up interval (in milliseconds) to use for throttleable
  /// JavaScript tasks (`setTimeout` and `setInterval`), when the WebView is in
  /// background state with intensive throttling. Intensive throttling is a
  /// substate of background state. For more details about intensive
  /// throttling, see
  /// [Intensive throttling of Javascript timer wake ups](https://chromestatus.com/feature/4718288976216064).
  ///
  /// A wake up interval is the amount of time that needs to pass before the
  /// WebView2 Runtime checks for new timer tasks to run.
  ///
  /// The WebView2 Runtime will try to respect the preferred interval set by the
  /// application, but the effective value will be constrained by resource and
  /// platform limitations. Setting a value of `0` means a preference of no
  /// throttling to be applied. The default value is a constant determined by
  /// the running version of the WebView2 Runtime.
  [propget] HRESULT ThrottlingIntervalPreferenceIntensive([out, retval] UINT32* value);
  /// Sets the `ThrottlingIntervalPreferenceIntensive` property.
  [propput] HRESULT ThrottlingIntervalPreferenceIntensive([in] UINT32 value);

  /// The preferred wake up interval (in milliseconds) to use for throttleable
  /// JavaScript tasks (`setTimeout` and `setInterval`), in frames whose
  /// `ShouldUseIsolatedThrottling` property is set to `TRUE`. This is a category
  /// specific to WebView2 with no corresponding state in the Chromium tab state
  /// model.
  ///
  /// A wake up interval is the amount of time that needs to pass before the
  /// WebView2 Runtime checks for new timer tasks to run.
  ///
  /// The WebView2 Runtime will try to respect the preferred interval set by the
  /// application, but the effective value will be constrained by resource and
  /// platform limitations. Setting a value of `0` means a preference of no
  /// throttling to be applied. The default value is a constant determined by
  /// the running version of the WebView2 Runtime.
  ///
  /// For example, an application might use an isolated throttling value of 30
  /// ms to reduce resource consumption from third party frames in the WebView.
  [propget] HRESULT ThrottlingIntervalPreferenceIsolated([out, retval] UINT32* value);
  /// Sets the `ThrottlingIntervalPreferenceIsolated` property.
  [propput] HRESULT ThrottlingIntervalPreferenceIsolated([in] UINT32 value);
}

/// A continuation of the `ICoreWebView2Frame` interface to support
/// ShouldUseIsolatedThrottling property.
[uuid(5b7d1b96-699b-44a2-b9f1-b8e88f9ac2be), object, pointer_default(unique)]
interface ICoreWebView2Frame6 : ICoreWebView2Frame5 {
  /// Indicates whether the frame has been marked for isolated throttling by the
  /// host app. When `TRUE`, the frame will receive the throttling interval set
  /// by `ThrottlingIntervalPreferenceIsolated`. When `FALSE`, and for main
  /// frame, throttling interval will be determined by page state and the
  /// interval through their corresponding properties in the
  /// `CoreWebView2Settings` object. Defaults to `FALSE` unless set otherwise.
  [propget] HRESULT ShouldUseIsolatedThrottling([out, retval] BOOL* value);

  /// Sets the `ShouldUseIsolatedThrottling` property.
  [propput] HRESULT ShouldUseIsolatedThrottling([in] BOOL value);
}

```

```C#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings9")]
        {
            UInt32 ThrottlingIntervalPreferenceForeground { get; set; };

            UInt32 ThrottlingIntervalPreferenceBackground { get; set; };

            UInt32 ThrottlingIntervalPreferenceIntensive { get; set; };

            UInt32 ThrottlingIntervalPreferenceIsolated { get; set; };
        }
    }

    runtimeclass CoreWebView2Frame
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame6")]
        {
            Boolean ShouldUseIsolatedThrottling { get; set; };
        }
    }
}

```

# Appendix
