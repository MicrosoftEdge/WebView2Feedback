# WebView2Find API

## Background

The WebView2Find API provides methods and events to support text finding and navigation within a WebView2 control. 
It allows developers to programmatically initiate find operations, navigate between find results, supress default UI, customize various find configurations
such as query, direction of search, match case, match word, etc. Also enables developers to track the status of ongoing operations such as whether a find session has 
completed or not, whether the match count has changed, and whether the match index has changed.

## Examples


#### Description
To initiate a find operation within a WebView2 control, developers can utilize the `StartFindOnPage` method. 
This method allows specifying the find term and configuring other find parameters using the `ICoreWebView2FindConfiguration` interface.

#### Create/Specify a Find Configuration
```cpp
bool AppWindow::ConfigureAndExecuteFind(
    const std::wstring& searchTerm,
    bool caseSensitive,
    bool highlightAllMatches,
    COREWEBVIEW2_FIND_DIRECTION direction)
{
    // Query for the ICoreWebView2StagingEnvironment5 interface.
    auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2StagingEnvironment5>();
    CHECK_FEATURE_RETURN(webView2Environment5);

    // Create the find configuration.
    wil::com_ptr<ICoreWebView2StagingFindConfiguration> findConfiguration;
    CHECK_FAILURE(webView2Environment5->CreateFindConfiguration(&findConfiguration));

    // Apply the find operation configurations.
    CHECK_FAILURE(findConfiguration->put_FindTerm(searchTerm.c_str()));
    CHECK_FAILURE(findConfiguration->put_IsCaseSensitive(caseSensitive));
    CHECK_FAILURE(findConfiguration->put_ShouldHighlightAllMatches(highlightAllMatches));
    CHECK_FAILURE(findConfiguration->put_FindDirection(direction));

    // Proceed to execute the find operation with the configured settings.
    return ExecuteFindOperation(findConfiguration.get());
}
```
```csharp
bool AppWindow::ConfigureAndExecuteFind(
    const std::wstring& searchTerm,
    bool caseSensitive,
    bool highlightAllMatches,
    COREWEBVIEW2_FIND_DIRECTION direction)
{
    // Query for the ICoreWebView2StagingEnvironment5 interface.
    auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2StagingEnvironment5>();
    CHECK_FEATURE_RETURN(webView2Environment5);

    // Create the find configuration.
    wil::com_ptr<ICoreWebView2StagingFindConfiguration> findConfiguration;
    CHECK_FAILURE(webView2Environment5->CreateFindConfiguration(&findConfiguration));

    // Apply the find operation configurations.
    CHECK_FAILURE(findConfiguration->put_FindTerm(searchTerm.c_str()));
    CHECK_FAILURE(findConfiguration->put_IsCaseSensitive(caseSensitive));
    CHECK_FAILURE(findConfiguration->put_ShouldHighlightAllMatches(highlightAllMatches));
    CHECK_FAILURE(findConfiguration->put_FindDirection(direction));

    // Proceed to execute the find operation with the configured settings.
    return ExecuteFindOperation(findConfiguration.get());
}
```
### Start a Find Operation

```cpp
//! [StartFindOnPage]
bool AppWindow::ExecuteFindOperation(ICoreWebView2StagingFindConfiguration* configuration)
{
    // Query for the ICoreWebView2Staging17 interface to access the Find feature.
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    // Apply custom UI settings and highlight configurations.
    CHECK_FAILURE(webView2stagingfind->put_UseCustomUI(false)); // Assuming you want to use the default UI, adjust as necessary.
    CHECK_FAILURE(webView2stagingfind->put_ShouldHighlightAllMatches(true)); // This should match the passed parameter if dynamic.
    CHECK_FAILURE(webView2stagingfind->PassHighlightSettings());

    // Start the find operation with the configured findConfiguration.
    HRESULT result = webView2stagingfind->StartFind(
        configuration,
        Callback<ICoreWebView2StagingFindOperationCompletedHandler>(
            [this](HRESULT result, LONG ActiveIdx, LONG MatchesCount) -> HRESULT
            {
                if (SUCCEEDED(result))
                {
                    // Handle successful find operation
                    // For example, updating UI elements to reflect the find results
                }
                else
                {
                    // Handle errors appropriately
                }
                return S_OK;
            }).Get());

    return SUCCEEDED(result);
}

//! [StartFindOnPage]
```
```csharp
//! [StartFindOnPage]
bool AppWindow::ExecuteFindOperation(ICoreWebView2StagingFindConfiguration* configuration)
{
    // Query for the ICoreWebView2Staging17 interface to access the Find feature.
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    // Apply custom UI settings and highlight configurations.
    CHECK_FAILURE(webView2stagingfind->put_UseCustomUI(false)); // Assuming you want to use the default UI, adjust as necessary.
    CHECK_FAILURE(webView2stagingfind->put_ShouldHighlightAllMatches(true)); // This should match the passed parameter if dynamic.
    CHECK_FAILURE(webView2stagingfind->PassHighlightSettings());

    // Start the find operation with the configured findConfiguration.
    HRESULT result = webView2stagingfind->StartFind(
        configuration,
        Callback<ICoreWebView2StagingFindOperationCompletedHandler>(
            [this](HRESULT result, LONG ActiveIdx, LONG MatchesCount) -> HRESULT
            {
                if (SUCCEEDED(result))
                {
                    // Handle successful find operation
                    // For example, updating UI elements to reflect the find results
                }
                else
                {
                    // Handle errors appropriately
                }
                return S_OK;
            }).Get());

    return SUCCEEDED(result);
}

//! [StartFindOnPage]
```
### Stop an existing find operation
#### Description
To stop an ongoing find operation within a WebView2 control, developers can use the `StopFind` method of the `ICoreWebView2Find` interface.
```cpp
//! [StopFind]
bool AppWindow::StopFind()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    CHECK_FAILURE(webView2stagingfind->StopFind());
    return true;
}
//! [StopFind]
```
```csharp
//! [StopFind]
bool AppWindow::StopFind()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    CHECK_FAILURE(webView2stagingfind->StopFind());
    return true;
}
//! [StopFind]
```

### Retrieve the Number of Matches

#### Description
To retrieve the total number of matches found during a find operation within a WebView2 control, developers can utilize the `GetMatchCount` method.


```cpp
//! [GetMatchCount]
bool AppWindow::GetMatchCount()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    LONG matchCount;
    CHECK_FAILURE(webView2stagingfind->get_MatchesCount(&matchCount));

    // Update UI or handle matchCount as you wish
    // For example, you could show a message box
    std::wstring matchCountStr = L"Match Count: " + std::to_wstring(matchCount);
    MessageBox(m_mainWindow, matchCountStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetMatchCount]
```
```csharp
//! [GetMatchCount]
bool AppWindow::GetMatchCount()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    LONG matchCount;
    CHECK_FAILURE(webView2stagingfind->get_MatchesCount(&matchCount));

    // Update UI or handle matchCount as you wish
    // For example, you could show a message box
    std::wstring matchCountStr = L"Match Count: " + std::to_wstring(matchCount);
    MessageBox(m_mainWindow, matchCountStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetMatchCount]
```
#### Handle Match Count Changes

```cpp
void OnMatchCountChanged(LONG matchesCount)
{
    // Handle match count changes
    // Update UI elements or perform actions based on the new match count
}
```

```csharp
void OnMatchCountChanged(LONG matchesCount)
{
    // Handle match count changes
    // Update UI elements or perform actions based on the new match count
}
```
### Retrieve the Index of the Active Match

#### Description
Developers can retrieve the index of the currently active match within a WebView2 control using the `GetActiveMatchIndex` method.


```cpp
//! [GetActiveMatchIndex]
bool AppWindow::GetActiveMatchIndex()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    LONG activeMatchIndex;
    CHECK_FAILURE(webView2stagingfind->get_ActiveMatchIndex(&activeMatchIndex));

    // Update UI or handle activeMatchIndex as you wish
    // For example, you could show a message box
    std::wstring activeMatchIndexStr =
        L"Active Match Index: " + std::to_wstring(activeMatchIndex);
    MessageBox(m_mainWindow, activeMatchIndexStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetActiveMatchIndex]
```

```csharp
//! [GetActiveMatchIndex]
bool AppWindow::GetActiveMatchIndex()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));
    LONG activeMatchIndex;
    CHECK_FAILURE(webView2stagingfind->get_ActiveMatchIndex(&activeMatchIndex));

    // Update UI or handle activeMatchIndex as you wish
    // For example, you could show a message box
    std::wstring activeMatchIndexStr =
        L"Active Match Index: " + std::to_wstring(activeMatchIndex);
    MessageBox(m_mainWindow, activeMatchIndexStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetActiveMatchIndex]
```

#### Handle Active Match Index Changes
```cpp
void OnActiveMatchIndexChanged(ICoreWebView2* sender, ICoreWebView2StagingFindActiveMatchIndexChangedEventArgs* args)
{
    // Handle active match index changes
    // Update UI to reflect the change in the active match index
}
```

```csharp
void OnActiveMatchIndexChanged(ICoreWebView2* sender, ICoreWebView2StagingFindActiveMatchIndexChangedEventArgs* args)
{
    // Handle active match index changes
    // Update UI to reflect the change in the active match index
}
```

### Navigate to the Next Match

#### Description
To navigate to the next match found during a find operation within a WebView2 control, developers can use the `FindNext` method.


```cpp
//! [FindNext]
bool AppWindow::FindNext()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    CHECK_FAILURE(webView2stagingfind->FindNext());
    CHECK_FAILURE(webView2stagingfind->remove_ActiveMatchIndexChanged(
        m_ActiveMatchIndexChangedEventToken));

    return true;
}
//! [FindNext]
```

```csharp
//! [FindNext]
bool AppWindow::FindNext()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    CHECK_FAILURE(webView2stagingfind->FindNext());
    CHECK_FAILURE(webView2stagingfind->remove_ActiveMatchIndexChanged(
        m_ActiveMatchIndexChangedEventToken));

    return true;
}
//! [FindNext]
```

### Navigate to the Previous Match

#### Description
To navigate to the previous match found during a find operation within a WebView2 control, developers can use the `FindPrevious` method.


```cpp
//! [FindPrevious]
bool AppWindow::FindPrevious()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    CHECK_FAILURE(webView2stagingfind->FindPrevious());

    return true;
}
//! [FindPrevious]
```

```csharp
//! [FindPrevious]
bool AppWindow::FindPrevious()
{
    auto webView2staging17 = m_webView.try_query<ICoreWebView2Staging17>();
    CHECK_FEATURE_RETURN(webView2staging17);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging17->get_Find(&webView2stagingfind));

    CHECK_FAILURE(webView2stagingfind->FindPrevious());

    return true;
}
//! [FindPrevious]
```

## API Details
```csharp

/// Specifies the direction of find Parameters.
[v1_enum]
typedef enum COREWEBVIEW2_FIND_DIRECTION { 
    /// Specifies a forward find in the document.
    COREWEBVIEW2_FIND_DIRECTION_FORWARD, 
    /// Specifies a backwards find in the document.
    COREWEBVIEW2_FIND_DIRECTION_BACKWARD 
} COREWEBVIEW2_FIND_DIRECTION; 

// Interface defining the find configuration.
[uuid(4A6ED732-DF08-4449-8949-3632A4DEBFCD), object, pointer_default(unique)] 
interface ICoreWebView2FindConfiguration : IUnknown {

    // Gets or sets the find term used for the find operation.
    [propget] HRESULT FindTerm([out, retval] LPWSTR* value);
    [propput] HRESULT FindTerm([in] LPCWSTR value);

    // Gets or sets the direction of the find operation (forward or backward).
    [propget] HRESULT FindDirection([out, retval] COREWEBVIEW2_FIND_DIRECTION* value); 
    [propput] HRESULT FindDirection([in] COREWEBVIEW2_FIND_DIRECTION value);

    // Gets or sets whether the find operation is case sensitive.
    [propget] HRESULT IsCaseSensitive([out, retval] BOOL* value); 
    [propput] HRESULT IsCaseSensitive([in] BOOL value);

    // Gets or sets whether to only match whole words during the find operation.
    [propget] HRESULT ShouldMatchWord([out, retval] BOOL* value); 
    [propput] HRESULT ShouldMatchWord([in] BOOL value);

    // Gets the state of whether all matches are highlighted.
    // \return TRUE if all matches are highlighted, FALSE otherwise.
    [propget] HRESULT ShouldHighlightAllMatches([out, retval] BOOL* value); 
    // Sets the state to either highlight all matches or not.
    [propput] HRESULT ShouldHighlightAllMatches([in] BOOL value);
 
    // Checks if a custom user interface is desired by end developer.
    // If TRUE, the default Find bar is not displayed.
    // Returns TRUE if using a custom UI, FALSE if using the default.
    [propget] HRESULT SuppressDefaultDialog([out, retval] BOOL* value); 
    // Sets whether to use a custom UI for the Find operation.
    [propput] HRESULT SuppressDefaultDialog([in] BOOL value);

    // Gets the index of the currently active match.
    // If there's no active find session but an attempt is made to get the active match index:
    // The function will return -1.
    // Returns The active match index.
    [propget] HRESULT ActiveMatchIndex([out, retval] LONG* value); 

    // Gets the total count of matches found in the current document based on the last find criteria.
    // \return The total count of matches.
    [propget] HRESULT MatchesCount([out, retval] LONG* value);

}

/// Handles the event that's fired when the match count changes.
[uuid(623EFBFB-A19E-43C4-B309-D578511D24AB), object, pointer_default(unique)]
interface ICoreWebView2FindMatchCountChangedEventHandler : IUnknown {
    /// Parameter is the match count.
    HRESULT Invoke(LONG matchesCount);
}

/// Handles the event that's fired when the active match index changes.
[uuid(623EFBF9-A19E-43C4-B309-D578511D24A9), object, pointer_default(unique)]
interface ICoreWebView2FindActiveMatchIndexChangedEventHandler : IUnknown {
    /// Parameter is the active match index.
    HRESULT Invoke(LONG activeMatchIndex);
}
/// Handles the event that's fired when the find operation completes.
[uuid(2604789D-9553-4246-8E21-B9C74EFAD04F), object, pointer_default(unique)]
interface ICoreWebView2FindOperationCompletedHandler : IUnknown {
    /// Provides the event args when the find operation completes.
    HRESULT Invoke(HRESULT errorCode, BOOL status);
}

// Interface providing methods and properties for finding and navigating through text in the web view.
[uuid(7C49A8AA-2A17-4846-8207-21D1520AABC0), object, pointer_default(unique)] 
interface ICoreWebView2Find : IUnknown {
 
    // Initiates a find using the specified configuration.
    HRESULT StartFind([in] ICoreWebView2FindConfiguration* configuration, 
                      ICoreWebView2FindOperationCompletedHandler* handler);

    // Navigates to the next match in the document.
    HRESULT FindNext();

    // Navigates to the previous match in the document.
    HRESULT FindPrevious();

    // Stops the current 'Find' operation and hides the Find bar.
    HRESULT StopFind();

    // Registers an event handler for the FindCompleted event.
    // This event is raised when a find operation completes, either by finding all matches, navigating to a match, or by being stopped.
    // Parameter is the event handler to be added.
    // Returns a token representing the added event handler. This token can be used to unregister the event handler.
    HRESULT add_MatchCountChanged(
        [in] ICoreWebView2FindMatchCountChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);
    // Unregisters an event handler from the MatchCountChanged event.
    // Parameter is the token of the event handler to be removed, obtained during the registration of the event handler.
    HRESULT remove_MatchCountChanged([in] EventRegistrationToken token);

    // Registers an event handler for the ActiveMatchIndexChanged event.
    // This event is raised when the index of the currently active match changes.
    // This can happen when the user navigates to a different match or when the active match is changed programmatically.
    // Parameter is the event handler to be added.
    // Returns a token representing the added event handler. This token can be used to unregister the event handler.
    HRESULT add_ActiveMatchIndexChanged(
        [in] ICoreWebView2FindActiveMatchIndexChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);
    // Unregisters an event handler from the ActiveMatchIndexChanged event.
    // parameter is the token of the event handler to be removed, obtained during the registration of the event handler.
    HRESULT remove_ActiveMatchIndexChanged([in] EventRegistrationToken token);
}
```


### Setting Up Find Configuration

```csharp
public enum CoreWebView2FindDirection
{
    Forward,
    Backward
}

public class CoreWebView2FindConfiguration
{
    public string FindTerm { get; set; }
    public CoreWebView2FindDirection FindDirection { get; set; }
    public bool IsCaseSensitive { get; set; }
    public bool ShouldMatchWord { get; set; }
}
```

### Starting a Find Operation

```csharp
public interface ICoreWebView2StagingFind
{
    Task StartFindAsync(CoreWebView2FindConfiguration configuration);
    void FindNext();
    void FindPrevious();
    void StopFind();
    bool ShouldHighlightAllMatches { get; set; }
    bool ShouldHighlightActiveMatch { get; set; }
    bool UseCustomUI { get; set; }
    int ActiveMatchIndex { get; }
    int MatchesCount { get; }
    void PassHighlightSettings();
}

// Usage example:
public async Task PerformFindOperation(ICoreWebView2StagingFind webViewFind)
{
    var findConfig = new CoreWebView2FindConfiguration
    {
        FindTerm = "example",
        FindDirection = CoreWebView2FindDirection.Forward,
        IsCaseSensitive = false,
        ShouldMatchWord = true
    };
    
    await webViewFind.StartFindAsync(findConfig);
    webViewFind.FindNext();
    // Further operations...
}
```

### Handling Find Operation Events

```csharp
public interface ICoreWebView2StagingFindMatchCountChangedEventHandler
{
    void OnMatchCountChanged(ICoreWebView2StagingFind sender);
}

public interface ICoreWebView2StagingFindActiveMatchIndexChangedEventHandler
{
    void OnActiveMatchIndexChanged(ICoreWebView2StagingFind sender);
}

public interface ICoreWebView2StagingFindOperationCompletedHandler
{
    void OnFindOperationCompleted(ICoreWebView2StagingFind sender);
}

public void SubscribeToFindEvents(ICoreWebView2StagingFind webViewFind)
{
    webViewFind.MatchCountChanged += OnMatchCountChanged;
    webViewFind.ActiveMatchIndexChanged += OnActiveMatchIndexChanged;
    webViewFind.FindOperationCompleted += OnFindOperationCompleted;
}

private void OnMatchCountChanged(ICoreWebView2StagingFind sender)
{
    Console.WriteLine($"Match count changed. New count: {sender.MatchesCount}");
}

private void OnActiveMatchIndexChanged(ICoreWebView2StagingFind sender)
{
    Console.WriteLine($"Active match index changed. New index: {sender.ActiveMatchIndex}");
}

private void OnFindOperationCompleted(ICoreWebView2StagingFind sender)
{
    Console.WriteLine("Find operation completed.");
}
```

# Appendix

This API specification focuses on providing developers with the necessary information to integrate text finding and navigation functionalities into WebView2 applications. 
It emphasizes the usage of interfaces such as `ICoreWebView2Find` and `ICoreWebView2FindConfiguration` to perform find operations effectively. 
For more detailed implementation notes and examples, developers can refer to the WebView2 documentation and sample code provided by Microsoft.
