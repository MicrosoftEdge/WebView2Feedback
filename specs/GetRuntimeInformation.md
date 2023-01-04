# Background
As you know, one single WV2 runtime instance can be shared by multiple host apps, e.g., office apps (excel, word, ppt) might share a single WV2 runtime. So, a given host app does not have a whole picture of what's happening in the runtime process, such as what profiles are active there and what webviews are under each profile.

We want to have a new API to help developers get such information.

In this document we describe the API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` to provide an `GetRuntimeInformation` method. The method returns a information object that can be used to
form an information view.

# Examples
The following code snippets demonstrate how the GetRuntimeInformation can be used:
## Win32 C++
```cpp
//! [GetRuntimeInformation]
void ProcessComponent::GetRuntimeInformation()
{
    webview2_20 = m_webView.try_query<ICoreWebView2Experimental20>();
    if (!webview2_20)
    {
        MessageBox(nullptr, L"Get webview2 failed!", L"GetRuntimeInformation Result", MB_OK);
        return;
    }

    webview2_20->GetRuntimeInformation(
        Callback<ICoreWebView2ExperimentalGetRuntimeInformationCompletedHandler>(
            [this](HRESULT errorCode, ICoreWebView2ExperimentalProfileInformationList* list)
                -> HRESULT
            {
                if (errorCode != S_OK || list == nullptr)
                {
                    MessageBox(
                        nullptr, L"Call interface failed!", L"GetRuntimeInformation Result",
                        MB_OK);
                    return S_OK;
                }
                else
                {
                    std::wstring str;
                    static const std::wstring blank = L"    ";
                    UINT profileInformationListCount;
                    CHECK_FAILURE(list->get_Count(&profileInformationListCount));
                    if (profileInformationListCount == 0)
                    {
                        str += L"No profile information found.";
                    }
                    else
                    {
                        str +=
                            std::to_wstring(profileInformationListCount) + L" profile(s) found";
                        str += L"\n\n";
                        for (UINT i = 0; i < profileInformationListCount; ++i)
                        {
                            wil::com_ptr<ICoreWebView2ExperimentalProfileInformation>
                                profileInformation;
                            CHECK_FAILURE(list->GetValueAtIndex(i, &profileInformation));
                            str += L"Profile:\n";

                            wil::unique_cotaskmem_string profileName;
                            CHECK_FAILURE(profileInformation->get_Name(&profileName));
                            str += blank + L"name: " + profileName.get() + L"\n";

                            wil::unique_cotaskmem_string profilePath;
                            CHECK_FAILURE(profileInformation->get_Path(&profilePath));
                            str += blank + L"path: " + profilePath.get() + L"\n";

                            wil::com_ptr<ICoreWebView2ExperimentalWebviewInformationList>
                                webviewInformationList;
                            CHECK_FAILURE(profileInformation->GetWebviewInformationList(
                                &webviewInformationList));
                            UINT webviewInformationListCount;
                            CHECK_FAILURE(webviewInformationList->get_Count(
                                &webviewInformationListCount));
                            if (webviewInformationListCount == 0)
                            {
                                str += L"\n";
                                continue;
                            }
                            else
                            {
                                for (UINT j = 0; j < webviewInformationListCount; ++j)
                                {
                                    wil::com_ptr<ICoreWebView2ExperimentalWebviewInformation>
                                        webviewInformation;
                                    CHECK_FAILURE(webviewInformationList->GetValueAtIndex(
                                        j, &webviewInformation));
                                    str += blank + L"Webview:\n";

                                    wil::unique_cotaskmem_string webviewTitle;
                                    CHECK_FAILURE(webviewInformation->get_Title(&webviewTitle));
                                    str +=
                                        blank + blank + L"title: " + webviewTitle.get() + L"\n";

                                    wil::unique_cotaskmem_string webviewUrl;
                                    CHECK_FAILURE(webviewInformation->get_Url(&webviewUrl));
                                    str += blank + blank + L"url: " + webviewUrl.get() + L"\n";

                                    BOOL isInprivateMode;
                                    CHECK_FAILURE(webviewInformation->get_IsInprivateMode(
                                        &isInprivateMode));
                                    str += blank + blank + L"is inprivate mode: " +
                                           ((isInprivateMode == false) ? L"false" : L"true") +
                                           L"\n";

                                    INT32 processId = 0;
                                    CHECK_FAILURE(
                                        webviewInformation->get_ProcessId(&processId));
                                    str += blank + blank + L"process id: " +
                                           std::to_wstring(processId) + L"\n";
                                }
                                str += L"\n";
                            }
                        }
                    }
                    MessageBox(nullptr, str.c_str(), L"Runtime Information", MB_OK);
                    return S_OK;
                }
            })
            .Get());

    //! [RuntimeInformationChanged]
    webview2_20->add_RuntimeInformationChanged(
        Callback<ICoreWebView2ExperimentalRuntimeInformationChangedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2ExperimentalProfileInformationList* list)
                -> HRESULT
            {
                if (sender == nullptr || list == nullptr)
                {
                    MessageBox(
                        nullptr, L"Call interface failed!", L"GetRuntimeInformation Result",
                        MB_OK);
                    return S_OK;
                }
                else
                {
                    std::wstring str = L"Runtime Information Changed\n";
                    static const std::wstring blank = L"    ";
                    UINT profileInformationListCount;
                    CHECK_FAILURE(list->get_Count(&profileInformationListCount));
                    if (profileInformationListCount == 0)
                    {
                        str += L"No profile information found.";
                    }
                    else
                    {
                        str +=
                            std::to_wstring(profileInformationListCount) + L" profile(s) found";
                        str += L"\n\n";
                        for (UINT i = 0; i < profileInformationListCount; ++i)
                        {
                            wil::com_ptr<ICoreWebView2ExperimentalProfileInformation>
                                profileInformation;
                            CHECK_FAILURE(list->GetValueAtIndex(i, &profileInformation));
                            str += L"Profile:\n";

                            wil::unique_cotaskmem_string profileName;
                            CHECK_FAILURE(profileInformation->get_Name(&profileName));
                            str += blank + L"name: " + profileName.get() + L"\n";

                            wil::unique_cotaskmem_string profilePath;
                            CHECK_FAILURE(profileInformation->get_Path(&profilePath));
                            str += blank + L"path: " + profilePath.get() + L"\n";

                            wil::com_ptr<ICoreWebView2ExperimentalWebviewInformationList>
                                webviewInformationList;
                            CHECK_FAILURE(profileInformation->GetWebviewInformationList(
                                &webviewInformationList));
                            UINT webviewInformationListCount;
                            CHECK_FAILURE(webviewInformationList->get_Count(
                                &webviewInformationListCount));
                            if (webviewInformationListCount == 0)
                            {
                                str += L"\n";
                                continue;
                            }
                            else
                            {
                                for (UINT j = 0; j < webviewInformationListCount; ++j)
                                {
                                    wil::com_ptr<ICoreWebView2ExperimentalWebviewInformation>
                                        webviewInformation;
                                    CHECK_FAILURE(webviewInformationList->GetValueAtIndex(
                                        j, &webviewInformation));
                                    str += blank + L"Webview:\n";

                                    wil::unique_cotaskmem_string webviewTitle;
                                    CHECK_FAILURE(webviewInformation->get_Title(&webviewTitle));
                                    str +=
                                        blank + blank + L"title: " + webviewTitle.get() + L"\n";

                                    wil::unique_cotaskmem_string webviewUrl;
                                    CHECK_FAILURE(webviewInformation->get_Url(&webviewUrl));
                                    str += blank + blank + L"url: " + webviewUrl.get() + L"\n";

                                    BOOL isInprivateMode;
                                    CHECK_FAILURE(webviewInformation->get_IsInprivateMode(
                                        &isInprivateMode));
                                    str += blank + blank + L"is inprivate mode: " +
                                           ((isInprivateMode == false) ? L"false" : L"true") +
                                           L"\n";

                                    INT32 processId = 0;
                                    CHECK_FAILURE(
                                        webviewInformation->get_ProcessId(&processId));
                                    str += blank + blank + L"process id: " +
                                           std::to_wstring(processId) + L"\n";
                                }
                                str += L"\n";
                            }
                        }
                    }
                    MessageBox(nullptr, str.c_str(), L"Runtime Information", MB_OK);
                    return S_OK;
                }
            })
            .Get(),
        &m_runtimeInformationChangedToken);
    //! [RuntimeInformationChanged]
}
//! [GetRuntimeInformation]
```

## .NET and WinRT
```c#
        void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
        {
            if (e.IsSuccess)
            {
                // ...
                // <RuntimeInformationChanged>
                webView.CoreWebView2.RuntimeInformationChanged += WebView_RuntimeInformationChanged;
                // </RuntimeInformationChanged>
            }
        }

        // <GetRuntimeInformation>
        void WebView_RuntimeInformationChanged(object sender, object e)
        {
            Debug.WriteLine($"Runtime Information Changed. The latest results have been returned.");
            var list = (CoreWebView2ProfileInformationList)e;
            if (sender == null || list == null)
            {
                MessageBox.Show(this, "Call interface failed!", "GetRuntimeInformation Result");
                return;
            }
            else
            {
                string str = "Runtime Information Changed\n";
                const string blank = "    ";
                var profileInformationListCount = list.Count;
                if (profileInformationListCount == 0)
                {
                    str += "No profile information found.";
                }
                else
                {
                    str += profileInformationListCount + " profile(s) found";
                    str += "\n\n";
                    for (uint i = 0; i < profileInformationListCount; ++i)
                    {
                        var profileInformation = list.GetValueAtIndex(i);
                        str += "Profile:\n";

                        var profileName = profileInformation.Name;
                        str += blank + "name: " + profileName + "\n";

                        var profilePath = profileInformation.Path;
                        str += blank + "path: " + profilePath + "\n";

                        var webviewInformationList = profileInformation.GetWebviewInformationList();
                        var webviewInformationListCount = webviewInformationList.Count;
                        if (webviewInformationListCount == 0)
                        {
                            str += "\n";
                            continue;
                        }
                        else
                        {
                            for (uint j = 0; j < webviewInformationListCount; ++j)
                            {
                                var webviewInformation = webviewInformationList.GetValueAtIndex(j);
                                str += blank + "Webview:\n";

                                var webviewTitle = webviewInformation.title;
                                str += blank + blank + "title: " + webviewTitle + "\n";

                                var webviewUrl = webviewInformation.Url;
                                str += blank + blank + "url: " + webviewUrl + "\n";

                                var isInprivateMode = webviewInformation.IsInprivateMode;
                                str += blank + blank + "is inprivate mode: " + ((isInprivateMode == false) ? "false" : "true") + "\n";

                                var processId = webviewInformation.ProcessId;
                                str += blank + blank + "process id: " + processId.ToString() + "\n";
                            }
                            str += "\n";
                        }
                    }
                }
                MessageBox.Show(this, str, "Runtime Information");
            }
        }

        async void GetRuntimeInformationCmdExecuted(object target, ExecutedRoutedEventArgs e)
        {
            var list = await webView.CoreWebView2.GetRuntimeInformationAsync();
            if (list == null)
            {
                MessageBox.Show(this, "Call interface failed!", "GetRuntimeInformation Result");
                return;
            }
            else
            {
                string str = "";
                const string blank = "    ";
                var profileInformationListCount = list.Count;
                if (profileInformationListCount == 0)
                {
                    str += "No profile information found.";
                }
                else
                {
                    str += profileInformationListCount + " profile(s) found";
                    str += "\n\n";
                    for (uint i = 0; i < profileInformationListCount; ++i)
                    {
                        var profileInformation = list.GetValueAtIndex(i);
                        str += "Profile:\n";

                        var profileName = profileInformation.Name;
                        str += blank + "name: " + profileName + "\n";

                        var profilePath = profileInformation.Path;
                        str += blank + "path: " + profilePath + "\n";

                        var webviewInformationList = profileInformation.GetWebviewInformationList();
                        var webviewInformationListCount = webviewInformationList.Count;
                        if (webviewInformationListCount == 0)
                        {
                            str += "\n";
                            continue;
                        }
                        else
                        {
                            for (uint j = 0; j < webviewInformationListCount; ++j)
                            {
                                var webviewInformation = webviewInformationList.GetValueAtIndex(j);
                                str += blank + "Webview:\n";

                                var webviewTitle = webviewInformation.title;
                                str += blank + blank + "title: " + webviewTitle + "\n";

                                var webviewUrl = webviewInformation.Url;
                                str += blank + blank + "url: " + webviewUrl + "\n";

                                var isInprivateMode = webviewInformation.IsInprivateMode;
                                str += blank + blank + "is inprivate mode: " + ((isInprivateMode == false) ? "false" : "true") + "\n";

                                var processId = webviewInformation.ProcessId;
                                str += blank + blank + "process id: " + processId.ToString() + "\n";
                            }
                            str += "\n";
                        }
                    }
                }
                MessageBox.Show(this, str, "Runtime Information");
            }
        }
        // </GetRuntimeInformation>
```

# API Details
The spec file for `GetRuntimeInformation`.
## Win32 C++
```c++
/// This is the WebviewInformation.
/// This is the data structure for GetRuntimeInformation
[uuid(19DAB45B-4404-495E-27AC-0EE4089516F6), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalWebviewInformation : IUnknown {
  /// This is the Webview's title.
  [propget] HRESULT Title([out, retval] LPWSTR* value);
  /// This is the Webview's url.
  [propget] HRESULT Url([out, retval] LPWSTR* value);
  /// If IsInprivate is true, it is in Inprivate mode.
  /// If IsInprivate is false, it is not in Inprivate mode.
  [propget] HRESULT IsInprivateMode([out, retval] BOOL* isInprivate);
  /// This is the Webview's process id.
  [propget] HRESULT ProcessId([out, retval] INT32* value);
}

/// This is the WebviewInformation list.
/// This is the data structure for GetRuntimeInformation
[uuid(BD45F67C-18A5-7775-9E3F-F2A73F0CC82A), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalWebviewInformationList : IUnknown {
  /// The number of Webview information in the list.
  [propget] HRESULT Count([out, retval] UINT* count);
  /// Gets the Webview information located in the Webview information List at the given index.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] ICoreWebView2ExperimentalWebviewInformation** webviewInformation);
}

/// This is the ProfileInformation.
/// This is the data structure for GetRuntimeInformation
[uuid(FAD186F6-003F-1159-9431-F826BDC481B6), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalProfileInformation : IUnknown {
  /// This is the Profile's name.
  [propget] HRESULT Name([out, retval] LPWSTR* value);
  /// This is the Profile's path.
  [propget] HRESULT Path([out, retval] LPWSTR* value);
  /// This is the Profile's Webview information list.
  HRESULT GetWebviewInformationList([out, retval] ICoreWebView2ExperimentalWebviewInformationList** webviewInformationList);
}

/// This is the ProfileInformation list.
/// This is the data structure for GetRuntimeInformation
[uuid(E2D78650-E79B-0B35-1198-38F6D26EECE9), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalProfileInformationList : IUnknown {
  /// The number of Profile information in the list.
  [propget] HRESULT Count([out, retval] UINT* count);
  /// Gets the Profile information located in the Profile information List at the given index.
  HRESULT GetValueAtIndex([in] UINT index, [out, retval] ICoreWebView2ExperimentalProfileInformation** profileInformation);
}

/// A continuation of the `ICoreWebView2Experimental20` interface that supports
/// the `RuntimeInformationChanged` event.
[uuid(17527F0B-D8DA-3591-603F-45319A241743), object, pointer_default(unique)]
interface ICoreWebView2Experimental20 : IUnknown {
  /// Adds an event handler for the `RuntimeInformationChanged` event.
  HRESULT add_RuntimeInformationChanged(
      [in] ICoreWebView2ExperimentalRuntimeInformationChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);
  /// Remove an event handler previously added with `add_RuntimeInformationChanged`.
  HRESULT remove_RuntimeInformationChanged(
      [in] EventRegistrationToken token);
  /// Gets a list of ProfileInformationList.
  HRESULT GetRuntimeInformation([in] ICoreWebView2ExperimentalGetRuntimeInformationCompletedHandler* handler);
}

/// This is the callback for GetRuntimeInformation
[uuid(05090A3B-D12E-3791-65E0-C2C9058AC26C), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalGetRuntimeInformationCompletedHandler : IUnknown {
  /// Provides the result of GetRuntimeInformation
  HRESULT Invoke(
      [in] HRESULT errorCode,
      [in] ICoreWebView2ExperimentalProfileInformationList* result);
}

/// An event handler for the `RuntimeInformationChanged` event.
[uuid(8EFE7E01-902C-FFB9-F25C-BC033DCCA0AB), object, pointer_default(unique)]
interface ICoreWebView2ExperimentalRuntimeInformationChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] ICoreWebView2ExperimentalProfileInformationList* result);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public class CoreWebView2
    {
        public async Task<CoreWebView2ProfileInformationList> GetRuntimeInformationAsync() {}
        public event EventHandler<CoreWebView2ProfileInformationList> RuntimeInformationChanged {}
    }

    public class CoreWebView2ProfileInformationList
    {
        public uint Count { get; };
        public CoreWebView2ProfileInformation GetValueAtIndex(uint index) {}
    }

    public class CoreWebView2ProfileInformation
    {
        public string Name { get; };
        public string Path { get; };
        public CoreWebView2WebviewInformationList GetWebviewInformationList() {}
    }

    public class CoreWebView2WebviewInformationList
    {
        public uint Count { get; };
        public CoreWebView2WebviewInformation GetValueAtIndex(uint index) {}
    }

    public class CoreWebView2WebviewInformation
    {
        public string title { get; };
        public string Url { get; };
        public bool IsInprivateMode { get; };
        public int ProcessId { get; };
    }
}
```
