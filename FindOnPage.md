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

//! [ConfigureAndExecuteFind]
bool AppWindow::ConfigureAndExecuteFind(const std::wstring& searchTerm)
{
    // Query for the ICoreWebView2Environment5 interface.
    auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2Environment5>();
    CHECK_FEATURE_RETURN(webView2Environment5);

    // Initialize find configuration/settings
    wil::com_ptr<ICoreWebView2FindConfiguration> findConfiguration;
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

    // Determine if custom UI will be usedsettings and highlight configurations.

    // Assuming you want to use the default UI, adjust as necessary.
    CHECK_FAILURE(webView2find->put_UseCustomUI(false)); 
    CHECK_FAILURE(webView2find->put_ShouldHighlightAllMatches(true));

    // Start the find operation
    CHECK_FAILURE(webView2find->StartFind(
        findConfiguration.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, LONG ActiveIdx, LONG MatchesCount) -> HRESULT
            {
                if (SUCCEEDED(result))
                {
                    // For example, you could update UI elements here
                }
                else
                {
                    // Handle errors
                }
                return S_OK;
            })
            .Get()));
    CHECK_FAILURE(webView2find->FindNext());
    CHECK_FAILURE(webView2find->FindNext());
    CHECK_FAILURE(webView2find->FindPrevious());
    CHECK_FAILURE(webView2find->StopFind());

    return true;
}
//! [ConfigureAndExecuteFind]
```
```csharp
//! [ConfigureAndExecuteFind]
public async Task<bool> ConfigureAndExecuteFindAsync(string searchTerm)
    {
        try
        {
            // Assuming 'webView' is already initialized and is an instance of CoreWebView2

            // Initialize find configuration/settings
            var findConfiguration = new CoreWebView2FindConfiguration
            {
                FindTerm = searchTerm,
                IsCaseSensitive = false,
                ShouldMatchWord = false,
                FindDirection = CoreWebView2FindDirection.Forward
            };

            // Use the FindController to start the find operation
            var findController = webView.FindController;

            // Assuming you want to use the default UI, adjust as necessary
            findController.UseCustomUI = false;
            findController.ShouldHighlightAllMatches = true;

            // Start the find operation
            await findController.StartFindAsync(findConfiguration);

            // Perform FindNext operations
            await findController.FindNextAsync();
            await findController.FindNextAsync();
            await findController.FindPreviousAsync();
            findController.StopFind();

            return true;
        }
        catch (Exception ex)
        {
            // Handle errors
            Console.WriteLine($"An error occurred: {ex.Message}");
            return false;
        }
    }
}
//! [ConfigureAndExecuteFind]
```

//! [StopFind]
bool AppWindow::StopFind()
{
    auto webView2staging11 = m_webView.try_query<ICoreWebView2Staging11>();
    CHECK_FEATURE_RETURN(webView2staging11);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging11->get_Find(&webView2stagingfind));

    return true;
}
//! [StopFind]

//! [GetMatchCount]
bool AppWindow::GetMatchCount()
{
    auto webView2staging11 = m_webView.try_query<ICoreWebView2Staging11>();
    CHECK_FEATURE_RETURN(webView2staging11);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging11->get_Find(&webView2stagingfind));
    LONG matchCount;
    CHECK_FAILURE(webView2stagingfind->get_MatchesCount(&matchCount));

    // Update UI or handle matchCount as you wish
    // For example, you could show a message box
    std::wstring matchCountStr = L"Match Count: " + std::to_wstring(matchCount);
    MessageBox(m_mainWindow, matchCountStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetMatchCount]

//! [GetActiveMatchIndex]
bool AppWindow::GetActiveMatchIndex()
{
    auto webView2staging11 = m_webView.try_query<ICoreWebView2Staging11>();
    CHECK_FEATURE_RETURN(webView2staging11);
    wil::com_ptr<ICoreWebView2StagingFind> webView2stagingfind;
    CHECK_FAILURE(webView2staging11->get_Find(&webView2stagingfind));
    LONG activeMatchIndex;
    CHECK_FAILURE(webView2stagingfind->get_ActiveMatchIndex(&activeMatchIndex));

    // Update UI or handle activeMatchIndex as you wish
    // For example, you could show a message box
    std::wstring activeMatchIndexStr = L"Active Match Index: " + std::to_wstring(activeMatchIndex);
    MessageBox(m_mainWindow, activeMatchIndexStr.c_str(), L"Find Operation", MB_OK);

    return true;
}
//! [GetActiveMatchIndex]
#endif

    bool AppWindow::ConfigureAndExecuteFind(
        const std::wstring& searchTerm,
        bool caseSensitive,
        bool highlightAllMatches,
        COREWEBVIEW2_FIND_DIRECTION direction)
    {
        // Query for the ICoreWebView2Environment5 interface.
        auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2Environment5>();
        CHECK_FEATURE_RETURN(webView2Environment5);
    
        // Create the find configuration.
        wil::com_ptr<ICoreWebView2FindConfiguration> findConfiguration;
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
    public async Task<bool> ConfigureAndExecuteFindAsync(
        string searchTerm,
        bool caseSensitive,
        bool highlightAllMatches,
        CoreWebView2FindDirection direction)
    {
        var findConfiguration = new CoreWebView2FindConfiguration
        {
            FindTerm = searchTerm,
            IsCaseSensitive = caseSensitive,
            ShouldHighlightAllMatches = highlightAllMatches,
            FindDirection = direction
        };
        return await ExecuteFindOperationAsync(findConfiguration);
    }
```
### Start a Find Operation
    
```cpp
    //! [StartFindOnPage]
    bool AppWindow::ExecuteFindOperation(ICoreWebView2FindConfiguration* configuration)
    {
        // Query for the ICoreWebView217 interface to access the Find feature.
        auto webView217 = m_webView.try_query<ICoreWebView217>();
        CHECK_FEATURE_RETURN(webView217);
    
        // Get the Find interface.
        wil::com_ptr<ICoreWebView2Find> webView2find;
        CHECK_FAILURE(webView217->get_Find(&webView2find));
    
        // Apply custom UI settings and highlight configurations.
        CHECK_FAILURE(webView2find->put_UseCustomUI(false)); // Assuming you want to use the default UI, adjust as necessary.
        CHECK_FAILURE(webView2find->put_ShouldHighlightAllMatches(true)); // This should match the passed parameter if dynamic.
        CHECK_FAILURE(webView2find->PassHighlightSettings());
    
        // Start the find operation with the configured findConfiguration.
        HRESULT result = webView2find->StartFind(
            configuration,
            Callback<ICoreWebView2FindOperationCompletedHandler>(
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
    public async Task<bool> ExecuteFindOperationAsync(CoreWebView2FindConfiguration configuration)
    {
        var webViewFind = webView.CoreWebView2.FindController; // Assuming webView is your WebView2 control
    
        // Assume CoreWebView2.FindController has been appropriately implemented or wrapped to expose async tasks.
        // This example assumes such an implementation for illustration.
        await webViewFind.StartFindAsync(configuration);
    
        // Optionally, handle completion or results with events or further async operations.
        return true;
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
        auto webView217 = m_webView.try_query<ICoreWebView217>();
        CHECK_FEATURE_RETURN(webView217);
        wil::com_ptr<ICoreWebView2Find> webView2find;
        CHECK_FAILURE(webView217->get_Find(&webView2find));
        CHECK_FAILURE(webView2find->StopFind());
        return true;
    }
    //! [StopFind]
```

```csharp
    //! [StopFind]
    public void StopFindOperation()
    {
        var webViewFind = webView.CoreWebView2.FindController; // Assuming webView is your WebView2 control
        webViewFind.StopFind();
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
        auto webView217 = m_webView.try_query<ICoreWebView217>();
        CHECK_FEATURE_RETURN(webView217);
        wil::com_ptr<ICoreWebView2Find> webView2find;
        CHECK_FAILURE(webView217->get_Find(&webView2find));
        LONG matchCount;
        CHECK_FAILURE(webView2find->get_MatchesCount(&matchCount));
    
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
    public async Task<int> GetMatchCountAsync()
    {
        var webViewFind = webView.CoreWebView2.FindController; // Assuming webView is your WebView2 control
        var matchCount = await webViewFind.GetMatchesCountAsync();
        MessageBox.Show($"Match Count: {matchCount}", "Find Operation", MessageBoxButton.OK);
        return matchCount;
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
    private void OnMatchCountChanged(object sender, EventArgs e)
    {
        // Assuming EventArgs or a derived type carries the new match count
        MessageBox.Show($"Match count changed. New count: {e.MatchCount}", "Find Operation");
    }
    ```
    ### Retrieve the Index of the Active Match
    
    #### Description
    Developers can retrieve the index of the currently active match within a WebView2 control using the `GetActiveMatchIndex` method.
    
    
    ```cpp
    //! [GetActiveMatchIndex]
    bool AppWindow::GetActiveMatchIndex()
    {
        auto webView217 = m_webView.try_query<ICoreWebView217>();
        CHECK_FEATURE_RETURN(webView217);
        wil::com_ptr<ICoreWebView2Find> webView2find;
        CHECK_FAILURE(webView217->get_Find(&webView2find));
        LONG activeMatchIndex;
        CHECK_FAILURE(webView2find->get_ActiveMatchIndex(&activeMatchIndex));
    
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
    public async Task<int> GetActiveMatchIndexAsync()
    {
        var webViewFind = webView.CoreWebView2.FindController; // Assuming webView is your WebView2 control
        var activeMatchIndex = await webViewFind.GetActiveMatchIndexAsync();
        MessageBox.Show($"Active Match Index: {activeMatchIndex}", "Find Operation", MessageBoxButton.OK);
        return activeMatchIndex;
    }
    
    //! [GetActiveMatchIndex]
    ```
    
    #### Handle Active Match Index Changes
    ```cpp
    void OnActiveMatchIndexChanged(ICoreWebView2* sender, ICoreWebView2FindActiveMatchIndexChangedEventArgs* args)
{
    // Handle active match index changes
    // Update UI to reflect the change in the active match index
}
```

```csharp
private void OnActiveMatchIndexChanged(object sender, EventArgs e)
{
    // Assuming EventArgs or a derived type carries the new active match index
    MessageBox.Show($"Active match index changed. New index: {e.ActiveMatchIndex}", "Find Operation");
}
```

### Navigate to the Next Match

#### Description
To navigate to the next match found during a find operation within a WebView2 control, developers can use the `FindNext` method.


```cpp
//! [FindNext]
bool AppWindow::FindNext()
{
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindNext());
    CHECK_FAILURE(webView2find->remove_ActiveMatchIndexChanged(
        m_ActiveMatchIndexChangedEventToken));

    return true;
}
//! [FindNext]
```

```csharp
//! [FindNext]
bool AppWindow::FindNext()
{
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindNext());
    CHECK_FAILURE(webView2find->remove_ActiveMatchIndexChanged(
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
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindPrevious());

    return true;
}
//! [FindPrevious]
```

```csharp
//! [FindPrevious]
bool AppWindow::FindPrevious()
{
    auto webView217 = m_webView.try_query<ICoreWebView217>();
    CHECK_FEATURE_RETURN(webView217);
    wil::com_ptr<ICoreWebView2Find> webView2find;
    CHECK_FAILURE(webView217->get_Find(&webView2find));

    CHECK_FAILURE(webView2find->FindPrevious());

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


### Setting Up Find Configuration with MIDL3

To represent the given C# examples in a manner consistent with the behavior demonstrated earlier in the chat and align them with an API design that could be described using MIDL3 (noted as C# for formatting), let's formalize the design for a hypothetical WebView2 Find operation API. This design will incorporate setting up a find configuration, starting a find operation, handling find operation events, and navigating through find matches.

### CoreWebView2 Find Configuration and Direction

```csharp
namespace Microsoft.Web.WebView2.Core
{
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
}
```

### CoreWebView2 Find Interface and Usage

```csharp
namespace Microsoft.Web.WebView2.Core
{

    enum CoreWebView2FindDirection
    {
        Forward, 
        Backward, 
    };

    runtime CoreWebView2Find
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Find")]
        {
            void StartFindAsync(CoreWebView2FindConfiguration configuration);
            void FindNextAsync();
            void FindPreviousAsync();
            void StopFindAsync();
            bool ShouldHighlightAllMatches { get; set; }
            bool ShouldHighlightActiveMatch { get; set; }
            bool UseCustomUI { get; set; }
            int GetActiveMatchIndexAsync();
            int GetMatchesCountAsync();
        }
    }

    runtimeclass CoreWebView2FindConfiguration {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2StagingFindConfiguration")]
        {
            String FindTerm { get; set; };
            CoreWebView2FindDirection FindDirection { get; set; };
            Boolean IsCaseSensitive { get; set; };
            Boolean ShouldMatchWord { get; set; };
        };
    }

    

    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment14")]

    {
        CoreWebView2FindConfiguration CreateFindConfiguration();
    };

    interface ICoreWebView2Environment14
    {
        CoreWebView2FindConfiguration CreateFindConfiguration();
    };


    // Example usage:
    public async Task PerformFindOperationAsync(ICoreWebView2Find webViewFind)
    {
        var findConfig = new CoreWebView2FindConfiguration
        {
            FindTerm = "example",
            FindDirection = CoreWebView2FindDirection.Forward,
            IsCaseSensitive = false,
            ShouldMatchWord = true
        };

        await webViewFind.StartFindAsync(findConfig);
        await webViewFind.FindNextAsync();
        // Additional operations...
    }
}
```

These examples demonstrate how you might conceptualize and implement a Find API within the Microsoft WebView2 environment, focusing on async patterns for responsive UI interactions and event handling for dynamic UI updates based on the results of find operations. This design emphasizes asynchronous task-based APIs, event handling for UI updates, and modular API design for clear separation of concerns.

# Appendix

This API specification focuses on providing developers with the necessary information to integrate text finding and navigation functionalities into WebView2 applications. 
It emphasizes the usage of interfaces such as `ICoreWebView2Find` and `ICoreWebView2FindConfiguration` to perform find operations effectively. 
Additional Info:
Starting a find session when one is in progress will result in the active match index being moved forward or backwards depending on what find configuration has been used
(forward,backward).
