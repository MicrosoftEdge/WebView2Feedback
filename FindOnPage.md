To improve the Markdown formatting of your document and ensure the C++ to C# conversion requests are clear, here's the reformatted version:

---

# WebView2Find API

## Background

The WebView2Find API enables developers to support text finding and navigation within a WebView2 control programmatically. This API allows for initiating find operations, navigating between find results, suppressing the default UI, and customizing various find configurations such as query, direction of search, match case, and match word. It also provides functionality to track the status of ongoing operations, including whether a find session has completed, whether the match count has changed, and whether the match index has changed.

## Examples

### Create/Specify a Find Configuration

#### C++

```cpp
bool AppWindow::ConfigureAndExecuteFind(const std::wstring& searchTerm) {
    // Query for the ICoreWebView2Environment5 interface.
    auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2Environment5>();
    CHECK_FEATURE_RETURN(webView2Environment5);

    // Initialize find configuration/settings.
    wil::com_ptr<ICoreWebView2StagingFindConfiguration> findConfiguration;
    CHECK_FAILURE(webView2Environment5->CreateFindConfiguration(&findConfiguration));
    CHECK_FAILURE(findConfiguration->put_FindTerm(searchTerm.c_str()));
    CHECK_FAILURE(findConfiguration->put_IsCaseSensitive(false));
    CHECK_FAILURE(findConfiguration->put_ShouldMatchWord(false));
    CHECK_FAILURE(findConfiguration->put_FindDirection(COREWEBVIEW2_FIND_DIRECTION_FORWARD));

    // Query for the ICoreWebView217 interface to access the Find feature.
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    // Apply custom UI settings and highlight configurations.
    CHECK_FAILURE(webView2find->put_UseCustomUI(false));
    CHECK_FAILURE(webView2find->put_ShouldHighlightAllMatches(true));

    // Start the find operation.
    HRESULT result = webView2find->StartFind(
        findConfiguration.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, LONG ActiveIdx, LONG MatchesCount) -> HRESULT {
                if (SUCCEEDED(result)) {
                    // For example, update UI elements here.
                } else {
                    // Handle errors.
                }
                return S_OK;
            }).Get());

    CHECK_FAILURE(result);
    CHECK_FAILURE(webView2find->FindNext());
    CHECK_FAILURE(webView2find->FindPrevious());

    return true;
}
```

#### C#

```csharp
public async Task<bool> ConfigureAndExecuteFindAsync(string searchTerm) {
    var findConfiguration = new CoreWebView2FindConfiguration() {
        FindTerm = searchTerm,
        IsCaseSensitive = false,
        ShouldMatchWord = false,
        FindDirection = CoreWebView2FindDirection.Forward
    };

    // Assume CoreWebView2 and CoreWebView2FindController have been appropriately implemented or wrapped.
    var webViewFind = webView.CoreWebView2.FindController;
    await webViewFind.StartFindAsync(findConfiguration);
    await webViewFind.FindNextAsync();
    await webViewFind.FindPreviousAsync();

    return true;
}
```

### Stop an Existing Find Operation

#### C++

```cpp
bool AppWindow::StopFind() {
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->StopFind());
    return true;
}
```

#### C#

```csharp
public void StopFindOperation() {
    var webViewFind = webView.CoreWebView2.FindController;
    webViewFind.StopFind();
}
```

### Retrieve the Number of Matches

#### C++

```cpp
bool AppWindow::GetMatchCount() {
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));
    LONG matchCount;
    CHECK_FAILURE(webView2find->get_MatchesCount(&matchCount));

    // Update UI or handle matchCount as you wish.
    std::wstring matchCountStr = L"Match Count: " + std::to_wstring(matchCount);
    MessageBox(m_mainWindow, matchCountStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
```

#### C#

```csharp
public async Task<int> GetMatchCountAsync() {
    var webViewFind = webView.CoreWebView2.FindController;
    var matchCount = await webViewFind.GetMatchesCountAsync();
    MessageBox.Show($"Match Count: {matchCount

}", "Find Operation", MessageBoxButton.OK);
    return matchCount;
}
```

### Navigate to the Next Match

#### C++

```cpp
bool AppWindow::FindNext() {
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindNext());
    return true;
}
```

#### C#

```csharp
public async Task<bool> FindNextAsync() {
    var webViewFind = webView.CoreWebView2.FindController;
    await webViewFind.FindNextAsync();
    return true;
}
```

### Navigate to the Previous Match

#### C++

```cpp
bool AppWindow::FindPrevious() {
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindPrevious());
    return true;
}
```

#### C#

```csharp
public async Task<bool> FindPreviousAsync() {
    var webViewFind = webView.CoreWebView2.FindController;
    await webViewFind.FindPreviousAsync();
    return true;
}
```

## API Details

The API details and event handling examples demonstrate how developers might interact with the WebView2Find API, managing find operations, configurations, and UI updates programmatically. The C# examples are designed to provide a basic understanding of how to implement these functionalities within a WebView2 control in a .NET environment, using asynchronous patterns for responsiveness and event subscription for dynamic updates. 

## Appendix

This API specification aims to equip developers with the tools needed to integrate text finding and navigation functionalities into WebView2 applications effectively. Developers are encouraged to refer to the official WebView2 documentation and sample code for detailed implementation notes and examples.
