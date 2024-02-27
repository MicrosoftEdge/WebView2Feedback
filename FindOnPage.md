# WebView2Find API

## Background

The WebView2Find API provides methods and events to support text finding and navigation within a WebView2 control. 
It allows developers to initiate find operations, navigate between find results, and customize various find configurations.

## Examples


#### Description
To initiate a find operation within a WebView2 control, developers can utilize the `StartFindOnPage` method. 
This method allows specifying the find term and configuring other find parameters using the `ICoreWebView2FindConfiguration` interface.

#### Create/Specify a Find Configuration



```cpp
ICoreWebView2FindConfiguration CreateFindConfiguration()
{
    ICoreWebView2Environment5 environment = webView2Control.GetEnvironment();
    ICoreWebView2FindConfiguration configuration;
    environment.CreateFindConfiguration(out configuration);
    configuration.FindTerm = "example";
    configuration.FindDirection = COREWEBVIEW2_FIND_DIRECTION.COREWEBVIEW2_FIND_DIRECTION_FORWARD;
    configuration.IsCaseSensitive = false;
    configuration.ShouldMatchWord = false;
    return configuration;
}
```

### Start a Find Operation


```cpp
//! [StartFindOnPage]
void AppWindow::StartFindOnPage(const std::wstring& findTerm)
{
    // Get the find interface
    auto find = webView2Control.GetFind();

    // Create find configuration
    auto configuration = CreateFindConfiguration();

    // Start the find operation
    find.StartFind(configuration, OnFindOperationCompleted);
}
//! [StartFindOnPage]
```
### Stop an existing find operation
#### Description
To stop an ongoing find operation within a WebView2 control, developers can use the `StopFind` method of the `ICoreWebView2Find` interface.
```cpp
//! [StopFind]
void AppWindow::StopFind()
{
    // Get the find interface
    auto find = webView2Control.GetFind();
    
    // Stop the find operation
    find.StopFind();
}
//! [StopFind]
```

### Retrieve the Number of Matches

#### Description
To retrieve the total number of matches found during a find operation within a WebView2 control, developers can utilize the `GetMatchCount` method.


```cpp
//! [GetMatchCount]
void AppWindow::GetMatchCount()
{
    // Get the find interface
    auto find = webView2Control.GetFind();

    // Get the match count
    LONG matchCount;
    find.GetMatchesCount(&matchCount);

    // Update UI or handle matchCount
}
//! [GetMatchCount]
```

### Retrieve the Index of the Active Match

#### Description
Developers can retrieve the index of the currently active match within a WebView2 control using the `GetActiveMatchIndex` method.


```cpp
//! [GetActiveMatchIndex]
void AppWindow::GetActiveMatchIndex()
{
    // Get the find interface
    auto find = webView2Control.GetFind();

    // Get the active match index
    LONG activeMatchIndex;
    find.GetActiveMatchIndex(&activeMatchIndex);

    // Update UI or handle activeMatchIndex
}
//! [GetActiveMatchIndex]
```

### Navigate to the Next Match

#### Description
To navigate to the next match found during a find operation within a WebView2 control, developers can use the `FindNext` method.


```cpp
//! [FindNext]
void AppWindow::FindNext()
{
    // Get the find interface
    auto find = webView2Control.GetFind();

    // Find the next occurrence
    find.FindNext();
}
//! [FindNext]
```

### Navigate to the Previous Match

#### Description
To navigate to the previous match found during a find operation within a WebView2 control, developers can use the `FindPrevious` method.


```cpp
//! [FindPrevious]
void AppWindow::FindPrevious()
{
    // Get the find interface
    auto find = webView2Control.GetFind();

    // Find the previous occurrence
    find.FindPrevious();
}
//! [FindPrevious]
```

#### Handle Match Count Changes

```cpp
void OnMatchCountChanged(LONG matchesCount)
{
    // Handle match count changes
    // Update UI elements or perform actions based on the new match count
}
```
#### Handle Active Match Index Changes
```cpp
void OnActiveMatchIndexChanged(ICoreWebView2* sender, ICoreWebView2StagingFindActiveMatchIndexChangedEventArgs* args)
{
    // Handle active match index changes
    // Update UI to reflect the change in the active match index
}
```

#### Handle Find Operation Completion

```cpp
void OnFindOperationCompleted(HRESULT value, LONG activeMatchIndex, LONG matchesCount)
{
    // Handle find operation completion
    // Update UI elements, display search results, or handle errors
}
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
/// Interface defining the find configuration.
/// This interface provides the necessary methods and properties to configure a find operation.
[uuid(4A6ED732-DF08-4449-8949-3632A4DEBFCD), object, pointer_default(unique)] 
interface ICoreWebView2FindConfiguration : IUnknown {
    /// Gets the find term used for the find operation.
    /// \return The find term.
    [propget] HRESULT FindTerm([out, retval] LPWSTR* value);
    /// Sets the find term to be used for the find operation.
    /// \param[in] value The find term.
    [propput] HRESULT FindTerm([in] LPCWSTR value); 
    /// Gets the direction of the find operation (forward or backward).
    /// \return The find direction.
    [propget] HRESULT FindDirection([out, retval] COREWEBVIEW2_FIND_DIRECTION* value); 
    /// Sets the direction for the find operation.
    /// \param[in] value The find direction.
    [propput] HRESULT FindDirection([in] COREWEBVIEW2_FIND_DIRECTION value); 
    /// Determines if the find operation is case sensitive.
    /// \return TRUE if the find is case sensitive, FALSE otherwise.
    [propget] HRESULT IsCaseSensitive([out, retval] BOOL* value); 
    /// Sets whether the find operation should be case sensitive.
    /// \param[in] value TRUE to make the find case sensitive, FALSE otherwise.
    [propput] HRESULT IsCaseSensitive([in] BOOL value); 
    /// Determines if only whole words should be matched during the find operation.
    /// \return TRUE if only whole words should be matched, FALSE otherwise.
    [propget] HRESULT ShouldMatchWord([out, retval] BOOL* value); 
    /// Sets whether to only match whole words during the find operation.
    [propput] HRESULT ShouldMatchWord([in] BOOL value); 
    /// Gets the state of whether all matches are highlighted.
    /// \return TRUE if all matches are highlighted, FALSE otherwise.
    [propget] HRESULT ShouldHighlightAllMatches([out, retval] BOOL* value); 
    /// Sets the state to either highlight all matches or not.
    [propput] HRESULT ShouldHighlightAllMatches([in] BOOL value); 
    /// Determines if the currently active match is highlighted.
    /// \return TRUE if the active match is highlighted, FALSE otherwise.
    [propget] HRESULT ShouldHighlightActiveMatch([out, retval] BOOL* value); 
    /// Sets whether to highlight the currently active match.
    [propput] HRESULT ShouldHighlightActiveMatch([in] BOOL value); 
    /// Checks if a custom user interface is desired by end developer.
    /// If TRUE, the default Find bar is not displayed.
    /// \return TRUE if using a custom UI, FALSE if using the default.
    [propget] HRESULT UseCustomUI([out, retval] BOOL* value); 
    /// Sets whether to use a custom UI for the Find operation.
    [propput] HRESULT UseCustomUI([in] BOOL value); 
    /// Gets the index of the currently active match.
    /// If there's no active find session but an attempt is made to change the active match index:
    /// The function might crash if the global_match_id isn't found in the map.
    /// It will clear any active match highlighting if there's a previously active frame.
    /// It will either select a new active match or return an error through the callback if the frame associated with the match isn't valid.
    /// \return The active match index.
    [propget] HRESULT ActiveMatchIndex([out, retval] LONG* value); 
    /// Sets the index for the active match.
    [propput] HRESULT ActiveMatchIndex([in] LONG value);
    /// Gets the total count of matches found in the current document based on the last find criteria.
    /// \return The total count of matches.
    [propget] HRESULT MatchesCount([out, retval] LONG* value);
    /**
    * Passes the current highlighting settings to the underlying Mojo.
    *
    * This function retrieves the current text highlighting settings set by the user 
    * or the default system and ensures that they are used during any subsequent text 
    * find or highlight operations. This includes settings related to highlighting 
    * all matches, the active match, and any custom UI preferences. 
    * 
    * Users should call this function after changing any highlight settings to ensure 
    * that they are applied properly in the system.
    */
    HRESULT PassHighlightSettings();
}
/// Handles the event that's fired when the match count changes.
[uuid(623EFBFB-A19E-43C4-B309-D578511D24AB), object, pointer_default(unique)]
interface ICoreWebView2FindMatchCountChangedEventHandler : IUnknown {
    /// Provides the event args when the match count changes.
    HRESULT Invoke(LONG matchesCount);
}
/// Handles the event that's fired when the active match index changes.
[uuid(623EFBF9-A19E-43C4-B309-D578511D24A9), object, pointer_default(unique)]
interface ICoreWebView2FindActiveMatchIndexChangedEventHandler : IUnknown {
    /// Provides the event args when the active match index changes.
    /// \param sender The sender of this event, representing the current instance of ICoreWebView2Find.
    /// \param args The event args that contain the new active match index.
    HRESULT Invoke(
        [in] ICoreWebView2* sender,
        [in] ICoreWebView2FindActiveMatchIndexChangedEventArgs* args);
}
/// Handles the event that's fired when the find operation completes.
[uuid(2604789D-9553-4246-8E21-B9C74EFAD04F), object, pointer_default(unique)]
interface ICoreWebView2FindOperationCompletedHandler : IUnknown {
    /// Provides the event args when the find operation completes.
    HRESULT Invoke(HRESULT value, LONG activeMatchIndex, LONG matchesCount);
}
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
    // Determines if the currently active match is highlighted.
    // \return TRUE if the active match is highlighted, FALSE otherwise.
    [propget] HRESULT ShouldHighlightActiveMatch([out, retval] BOOL* value); 
    // Sets whether to highlight the currently active match.
    [propput] HRESULT ShouldHighlightActiveMatch([in] BOOL value); 
    // Checks if a custom user interface is desired by end developer.
    // If TRUE, the default Find bar is not displayed.
    // \return TRUE if using a custom UI, FALSE if using the default.
    [propget] HRESULT UseCustomUI([out, retval] BOOL* value); 
    // Sets whether to use a custom UI for the Find operation.
    [propput] HRESULT UseCustomUI([in] BOOL value); 
    // Gets the index of the currently active match.
    // If there's no active find session but an attempt is made to change the active match index:
    // The function might crash if the global_match_id isn't found in the map.
    // It will clear any active match highlighting if there's a previously active frame.
    // It will either select a new active match or return an error through the callback if the frame associated with the match isn't valid.
    // \return The active match index.
    [propget] HRESULT ActiveMatchIndex([out, retval] LONG* value); 
    // Sets the index for the active match.
    [propput] HRESULT ActiveMatchIndex([in] LONG value);
    // Gets the total count of matches found in the current document based on the last find criteria.
    // \return The total count of matches.
    [propget] HRESULT MatchesCount([out, retval] LONG* value);
    /**
    * Passes the current highlighting settings to the underlying Mojo.
    *
    * This function retrieves the current text highlighting settings set by the user 
    * or the default system and ensures that they are used during any subsequent text 
    * find or highlight operations. This includes settings related to highlighting 
    * all matches, the active match, and any custom UI preferences. 
    * 
    * Users should call this function after changing any highlight settings to ensure 
    * that they are applied properly in the system.
    */
    HRESULT PassHighlightSettings();
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
    // \param eventHandler The event handler to be added.
    // \return A token representing the added event handler. This token can be used to unregister the event handler.
    HRESULT add_FindOperationCompleted(
        [in] ICoreWebView2FindOperationCompletedHandler* eventHandler,
        [out] EventRegistrationToken* token);
    // Unregisters an event handler from the FindCompleted event.
    // \param token The token of the event handler to be removed, obtained during the registration of the event handler.
    HRESULT remove_FindOperationCompleted([in] EventRegistrationToken token);
    // Registers an event handler for the MatchCountChanged event.
    // This event is raised when the total count of matches in the document changes due to a new find operation or changes in the document.
    // \param eventHandler The event handler to be added.
    // \return A token representing the added event handler. This token can be used to unregister the event handler.
    HRESULT add_MatchCountChanged(
        [in] ICoreWebView2FindMatchCountChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);
    // Unregisters an event handler from the MatchCountChanged event.
    // \param token The token of the event handler to be removed, obtained during the registration of the event handler.
    HRESULT remove_MatchCountChanged([in] EventRegistrationToken token);
    // Registers an event handler for the ActiveMatchIndexChanged event.
    // This event is raised when the index of the currently active match changes.
    // This can happen when the user navigates to a different match or when the active match is changed programmatically.
    // \param eventHandler The event handler to be added.
    // \return A token representing the added event handler. This token can be used to unregister the event handler.
    HRESULT add_ActiveMatchIndexChanged(
        [in] ICoreWebView2FindActiveMatchIndexChangedEventHandler* eventHandler,
        [out] EventRegistrationToken* token);
    // Unregisters an event handler from the ActiveMatchIndexChanged event.
    // \param token The token of the event handler to be removed, obtained during the registration of the event handler.
    HRESULT remove_ActiveMatchIndexChanged([in] EventRegistrationToken token);
}
```

# Appendix

This API specification focuses on providing developers with the necessary information to integrate text finding and navigation functionalities into WebView2 applications. 
It emphasizes the usage of interfaces such as `ICoreWebView2Find` and `ICoreWebView2FindConfiguration` to perform find operations effectively. 
For more detailed implementation notes and examples, developers can refer to the WebView2 documentation and sample code provided by Microsoft.
