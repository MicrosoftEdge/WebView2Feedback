# WebView2Find API

## Background

The WebView2Find API offers methods and events for text finding and navigation
within a WebView2 control. It enables developers to programmatically initiate find
operations, navigate find results, suppress default UI, and customize find configurations
like query and search direction. It also tracks the status of operations, indicating
completion, match count changes, and match index changes.

## Examples


#### Description

To initiate a find operation in a WebView2 control, use the `StartFind` method.
This method allows setting the search term and find parameters via the
`ICoreWebView2FindConfiguration` interface. Only one find session can be active per
webview environment. Starting another with the same configuration will adjust
the active match index based on the selected Find Direction.
### Create/Specify a Find Configuration
#### WIN32 C++

```cpp

//! [InitializeFindConfiguration]
wil::com_ptr<ICoreWebView2FindConfiguration> AppWindow::InitializeFindConfiguration(const std::wstring& searchTerm)
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

    // Query for the ICoreWebView2_17 interface to access the Find feature.
    auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
    CHECK_FEATURE_RETURN(webView2_17);

    return findConfiguration;
}
//! [InitializeFindConfiguration]
```

```cpp
//! [ExecuteFindWithDefaultUI]
bool AppWindow::ConfigureAndExecuteFind(const std::wstring& searchTerm) 
{
    auto findConfiguration = InitializeFindConfiguration(searchTerm);
    if (!findConfiguration)
    {
        return false;
    }
    // Query for the ICoreWebView2_17 interface to access the Find feature.
    auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
    CHECK_FEATURE_RETURN(webView2_17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2Find> webView2Find;
    CHECK_FAILURE(webView2_17->get_Find(&webView2Find));

    // Assuming you want to use the default UI, adjust as necessary.
    CHECK_FAILURE(webView2Find->put_SuppressDefaultDialog(false)); 
    CHECK_FAILURE(webView2Find->put_ShouldHighlightAllMatches(true));

    // Start the find operation with a callback for completion.
    CHECK_FAILURE(webView2Find->StartFind(
        findConfiguration.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, BOOL status) -> HRESULT
            {
                if (SUCCEEDED(result))
                {
                    // Optionally update UI elements here upon successful find operation.
                }
                else
                {
                    // Handle errors.
                }
                return S_OK;
            }).Get()));

    // End user interaction is handled via UI.
    return true;
}
//! [ExecuteFindWithDefaultUI]
```

```cpp
//! [ExecuteFindWithCustomUI]
bool AppWindow::ExecuteFindWithCustomUI(const std::wstring& searchTerm)
{
    auto findConfiguration = InitializeFindConfiguration(searchTerm);
    if (!findConfiguration)
    {
        return false;
    }
    // Query for the ICoreWebView2_17 interface to access the Find feature.
    auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
    CHECK_FEATURE_RETURN(webView2_17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2Find> webView2Find;
    CHECK_FAILURE(webView2_17->get_Find(&webView2Find));

    // Opt for using a custom UI for the find operation.
    CHECK_FAILURE(webView2Find->put_SuppressDefaultDialog(true));
    CHECK_FAILURE(webView2find->put_ShouldHighlightAllMatches(true));

    // Start the find operation with callback for completion.
    CHECK_FAILURE(webView2Find->StartFind(
        findConfiguration.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, BOOL status) -> HRESULT
            {
                if (SUCCEEDED(result) && status)
                {
                    // Optionally update UI elements here upon successful find operation.
                }
                else
                {
                    // Handle errors or unsuccessful search.
                }
                return S_OK;
            }).Get()));

    // Note: In this example, navigation through find results (FindNext/FindPrevious)
    // and stopping the find operation (StopFind) are assumed to be handled by
    // custom UI elements and user interaction, not directly in code here.
    // User could then connect functions such as FindNext, FindPrevious, and StopFind
    // to corresponding custom UI elements.

    return true;
}
//! [ExecuteFindWithCustomUI]
```
#### .NET C#
```csharp
//! [ConfigureAndExecuteFindWithDefaultUI]
async Task ConfigureAndExecuteFindWithDefaultUIAsync(string searchTerm)
{
    try
    {
        // Check if the webView is already initialized and is an instance of CoreWebView2.
        if (webView.CoreWebView2 == null)
        {
            throw new InvalidOperationException("WebView2 is not initialized.");
        }

        // Initialize the find configuration with specified settings.
        var findConfiguration = new CoreWebView2FindConfiguration
        {
            FindTerm = searchTerm,
            IsCaseSensitive = false,
            ShouldMatchWord = false,
            FindDirection = CoreWebView2FindDirection.Forward
        };

        // Use the default UI provided by WebView2 for the find operation.
        webView.CoreWebView2.FindController.SuppressDefaultDialog = false;
        webView.CoreWebView2.FindController.ShouldHighlightAllMatches = true;

        // Start the find operation with the specified configuration.
        await webView.CoreWebView2.FindController.StartFindAsync(findConfiguration);

        // End user interaction is handled via UI.
    }
    catch (Exception ex)
    {
        // Handle any errors that may occur during the find operation.
        Console.WriteLine($"An error occurred: {ex.Message}");
    }
}
//! [ConfigureAndExecuteFindWithDefaultUI]
```

```csharp
//! [ConfigureAndExecuteFindWithCustomUI]
async Task ConfigureAndExecuteFindWithCustomUIAsync(string searchTerm)
{
    try
    {
        // Check if the webView is already initialized and is an instance of CoreWebView2.
        if (webView.CoreWebView2 == null)
        {
            throw new InvalidOperationException("WebView2 is not initialized.");
        }

        // Initialize the find configuration with specified settings.
        var findConfiguration = new CoreWebView2FindConfiguration
        {
            FindTerm = searchTerm,
            IsCaseSensitive = false,
            ShouldMatchWord = false,
            FindDirection = CoreWebView2FindDirection.Forward
        };

        // Specify that a custom UI will be used for the find operation.
        webView.CoreWebView2.FindController.SuppressDefaultDialog = true;
        webView.CoreWebView2.FindController.ShouldHighlightAllMatches = true;

        // Start the find operation with the specified configuration.
        await webView.CoreWebView2.FindController.StartFindAsync(findConfiguration);
        // It's expected that the custom UI for navigating between matches (next, previous)
        // and stopping the find operation will be managed by the developer's custom code.
    }
    catch (Exception ex)
    {
        // Handle any errors that may occur during the find operation.
        Console.WriteLine($"An error occurred: {ex.Message}");
    }
}
//! [ConfigureAndExecuteFindWithCustomUI]
```

### Retrieve the Index of the Active Match
    
#### Description
Developers can retrieve the index of the currently active match 
within a WebView2 control using the `GetActiveMatchIndex` method.
    
    
```cpp
    //! [GetActiveMatchIndex]
    bool AppWindow::GetActiveMatchIndex()
    {
        auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
        CHECK_FEATURE_RETURN(webView2_17);
        wil::com_ptr<ICoreWebView2Find> webView2find;
        CHECK_FAILURE(webView2_17->get_Find(&webView2Find));
        LONG activeMatchIndex;
        CHECK_FAILURE(webView2Find->get_ActiveMatchIndex(&activeMatchIndex));
    
        // Update UI or handle activeMatchIndex as you wish
        // For example, you could show a message box
        std::wstring activeMatchIndexStr =
            L"Active Match Index: " + std::to_wstring(activeMatchIndex);
        MessageBox(m_mainWindow, activeMatchIndexStr.c_str(), L"Find Operation", MB_OK);
    
        return true;
    }
    //! [GetActiveMatchIndex]

    // Register ActiveMatchIndexChanged event handler
    m_webView->add_ActiveMatchIndexChanged(
        Callback<ICoreWebView2FindActiveMatchIndexChangedEventHandler>(
            [this](LONG activeMatchIndex) -> HRESULT
            {
                // Update custom UI 
                wprintf(L"Active Match Index Changed: %ld\n", activeMatchIndex);
                return S_OK;
            }).Get(),
        &m_activeMatchIndexChangedToken);
```
#### .NET C#
```csharp
//! [GetActiveMatchIndex]
public async Task<int> GetActiveMatchIndexAsync()
{
    var webViewFind = webView.CoreWebView2.FindController; // Assuming webView is your WebView2 control
    var activeMatchIndex = webViewFind.ActiveMatchIndex();
    MessageBox.Show($"Active Match Index: {activeMatchIndex}", "Find Operation", MessageBoxButton.OK);
    return activeMatchIndex;
}

void ActiveMatchIndexChangedSample()
{
    webView.CoreWebView2.FindController.ActiveMatchIndexChanged += (object sender, EventArgs args) =>
    {
        int activeMatchIndex = webView.CoreWebView2.FindController.ActiveMatchIndex;
        // Update Custom UI based on the new active match index.
    };
}
//! [GetActiveMatchIndex]
```

## API Details
```cpp

/// Specifies the direction of Search Parameters.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[v1_enum]
typedef enum COREWEBVIEW2_FIND_DIRECTION {
  /// Specifies a forward search in the document.
  COREWEBVIEW2_FIND_DIRECTION_FORWARD,
  /// Specifies a backwards search in the document.
  COREWEBVIEW2_FIND_DIRECTION_BACKWARD,
} COREWEBVIEW2_FIND_DIRECTION;


/// Interface that provides methods related to the environment settings of CoreWebView2.
/// This interface allows for the creation of new find configuration objects.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(f10bddd3-bb59-5d5b-8748-8a1a53f65d0c), object, pointer_default(unique)]
interface ICoreWebView2StagingEnvironment5 : IUnknown {
  /// Creates a new instance of a FindConfiguration object.
  /// This configuration object can be used to define parameters for a search operation.
  /// Returns the newly created FindConfiguration object.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT CreateFindConfiguration(
      [out, retval] ICoreWebView2StagingFindConfiguration** value
  );


}


/// Receives the result of the `StartFind` method.
[uuid(7c20f8b0-c14e-5135-a099-6c9d11d59dd1), object, pointer_default(unique)]
interface ICoreWebView2StagingFindStartFindCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode);
}

/// Receives `FindActiveMatchIndexChanged` events.
[uuid(8d3422bf-66df-5bae-9916-71fd23d5bef6), object, pointer_default(unique)]
interface ICoreWebView2StagingFindActiveMatchIndexChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingFind* sender,
      [in] IUnknown* args);
}
/// Receives `FindMatchCountChanged` events.
[uuid(cecb8e8f-b6c8-55c3-98b1-68fd1e2b9eea), object, pointer_default(unique)]
interface ICoreWebView2StagingFindMatchCountChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2StagingFind* sender,
      [in] IUnknown* args);
}


/// Interface providing methods and properties for finding and navigating through text in the web view.
/// This interface allows for finding text, navigation between matches, and customization of the find UI.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(9c494a0a-c5d8-5fee-b7e6-4926d8d7b391), object, pointer_default(unique)]
interface ICoreWebView2StagingFind : IUnknown {
  /// Retrieves the index of the currently active match in the find session. Returns the index of the currently active match, or -1 if there is no active match.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT ActiveMatchIndex([out, retval] UINT32* value);


  /// Gets the total count of matches found in the current document based on the last find sessions criteria. Returns the total count of matches.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT MatchCount([out, retval] UINT32* value);


  /// Gets the `ShouldHighlightAllMatches` property.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT ShouldHighlightAllMatches([out, retval] BOOL* value);


  /// Gets or sets the state of whether all matches are highlighted. Returns TRUE if all matches are highlighted, FALSE otherwise.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT ShouldHighlightAllMatches([in] BOOL value);


  /// Gets the `SuppressDefaultFindDialog` property.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT SuppressDefaultFindDialog([out, retval] BOOL* value);


  /// Checks if a custom user interface is desired by the end developer. Returns TRUE if using a custom UI, FALSE if using the default.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT SuppressDefaultFindDialog([in] BOOL value);



  /// Adds an event handler for the `ActiveMatchIndexChanged` event.
  /// Registers an event handler for the ActiveMatchIndexChanged event. This event is raised when the index of the currently active match changes. This can happen when the user navigates to a different match or when the active match is changed programmatically. The parameter is the event handler to be added. Returns a token representing the added event handler. This token can be used to unregister the event handler.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT add_ActiveMatchIndexChanged(
      [in] ICoreWebView2StagingActiveMatchIndexChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_ActiveMatchIndexChanged`.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT remove_ActiveMatchIndexChanged(
      [in] EventRegistrationToken token);

  /// Adds an event handler for the `MatchCountChanged` event.
  /// Registers an event handler for the MatchCountChanged event. This event is raised when the total count of matches in the document changes due to a new find operation or changes in the document. The parameter is the event handler to be added. Returns a token representing the added event handler. This token can be used to unregister the event handler.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT add_MatchCountChanged(
      [in] ICoreWebView2StagingMatchCountChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_MatchCountChanged`.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT remove_MatchCountChanged(
      [in] EventRegistrationToken token);


  /// Initiates a find using the specified configuration.
  /// Displays the Find bar and starts the find operation. If a find session was already ongoing, it will be stopped and replaced with this new instance.
  /// If called with an empty string, the Find bar is displayed but no finding occurs. Changing the configuration object after initiation won't affect the ongoing find session.
  /// To change the ongoing find session, StartFind must be called again with a new or modified configuration object.
  /// This method is primarily designed for HTML document queries.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT StartFind(
      [in] ICoreWebView2StagingFindConfiguration* configuration
      , [in] ICoreWebView2StagingFindStartFindCompletedHandler* handler
  );

  /// Navigates to the next match in the document.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT FindNext(
  );

  /// Navigates to the previous match in the document.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT FindPrevious(
  );

  /// Stops the current 'Find' operation and hides the Find bar.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT StopFind(
  );


}



/// Interface defining the find configuration.
/// This interface provides the necessary methods and properties to configure a search operation.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(52a04b23-acc8-5659-aa2f-26dbe9faafde), object, pointer_default(unique)]
interface ICoreWebView2StagingFindConfiguration : IUnknown {
  /// Gets the `FindDirection` property.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT FindDirection([out, retval] COREWEBVIEW2_FIND_DIRECTION* value);


  /// 
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT FindDirection([in] COREWEBVIEW2_FIND_DIRECTION value);


  /// Gets the `FindTerm` property.
  ///
  /// The caller must free the returned string with `CoTaskMemFree`.  See
  /// [API Conventions](/microsoft-edge/webview2/concepts/win32-api-conventions#strings).
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT FindTerm([out, retval] LPWSTR* value);


  /// 
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT FindTerm([in] LPCWSTR value);


  /// Gets the `IsCaseSensitive` property.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT IsCaseSensitive([out, retval] BOOL* value);


  /// 
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT IsCaseSensitive([in] BOOL value);


  /// Gets the `ShouldMatchWord` property.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT ShouldMatchWord([out, retval] BOOL* value);


  /// 
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propput] HRESULT ShouldMatchWord([in] BOOL value);



}

///  
/// Interface providing methods to access the find operation functionalities in the CoreWebView2.
/// 
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(c9a130ca-a807-549c-9d76-8e09ccee3973), object, pointer_default(unique)]
interface ICoreWebView2Staging17 : IUnknown {
  /// Retrieves the find operation interface for the current web view.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT Find([out, retval] ICoreWebView2StagingFind** value);



}
```


### Setting Up Find Configuration with MIDL3

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

### CoreWebView2 Find Interface

```csharp
namespace Microsoft.Web.WebView2.Core
{
    /// Specifies the direction of Search Parameters.
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    [availability("staging")]
    enum CoreWebView2FindDirection
    {
        /// Specifies a forward search in the document.
        Forward, 
        /// Specifies a backwards search in the document.
        Backward, 
    };

    runtimeclass CoreWebView2FindConfiguration : [default]ICoreWebView2FindConfiguration {}

    /// Interface defining the find configuration.
    /// This interface provides the necessary methods and properties to configure a search operation.
    [com_interface("staging=ICoreWebView2StagingFindConfiguration")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    [availability("staging")]
    interface ICoreWebView2FindConfiguration 
    {
        // Gets or sets the search term used for the find operation. Returns the search term.
        String FindTerm { get; set; };
        // Gets or sets the direction of the search operation (forward or backward). Returns the search direction.
        CoreWebView2FindDirection FindDirection { get; set; };
        // Determines if the search operation is case sensitive. Returns TRUE if the search is case sensitive, FALSE otherwise.
        Boolean IsCaseSensitive { get; set; };
        // Determines if only whole words should be matched during the find operation. Returns TRUE if only whole words should be matched, FALSE otherwise.
        Boolean ShouldMatchWord { get; set; };
    };

    runtimeclass CoreWebView2Find : [default]ICoreWebView2Find {}

    /// Interface providing methods and properties for finding and navigating through text in the web view.
    /// This interface allows for finding text, navigation between matches, and customization of the find UI.
    [com_interface("staging=ICoreWebView2StagingFind")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    [availability("staging")]
    interface ICoreWebView2Find 
    {
        [completed_handler("")]
        /// Initiates a find using the specified configuration.
        /// Displays the Find bar and starts the find operation. If a find session was already ongoing, it will be stopped and replaced with this new instance.
        /// If called with an empty string, the Find bar is displayed but no finding occurs. Changing the configuration object after initiation won't affect the ongoing find session.
        /// To change the ongoing find session, StartFind must be called again with a new or modified configuration object.
        /// This method is primarily designed for HTML document queries.
        Windows.Foundation.IAsyncAction StartFindAsync(CoreWebView2FindConfiguration configuration);

        /// Navigates to the next match in the document.
        void FindNext();

        /// Navigates to the previous match in the document.
        void FindPrevious();

        /// Stops the current 'Find' operation and hides the Find bar.
        void StopFind();

        /// Gets or sets the state of whether all matches are highlighted. Returns TRUE if all matches are highlighted, FALSE otherwise.
        Boolean ShouldHighlightAllMatches { get; set; };

        /// Set this property to hide the default Find UI. You can use this to hide the default UI so that you can show your own custom UI or programmatically interact with the Find API while showing no Find UI. Returns TRUE if hiding the default Find UI and FALSE if using showing the default Find UI.
        Boolean SuppressDefaultFindDialog { get; set; };

        /// Retrieves the index of the currently active match in the find session. Returns the index of the currently active match, or -1 if there is no active match.
        Int32 ActiveMatchIndex { get; };

        /// Gets the total count of matches found in the current document based on the last find sessions criteria. Returns the total count of matches.
        Int32 MatchCount { get; };
        
        /// Registers an event handler for the MatchCountChanged event. 
        This event is raised when the total count of matches in the document changes due to a new find operation or changes in the document. 
        The parameter is the event handler to be added. Returns a token representing the added event handler. This token can be used to unregister the event handler.
        [event_handler("", "", "")]
        event Windows.Foundation.TypedEventHandler<CoreWebView2Find, Object> MatchCountChanged;

        /// Registers an event handler for the ActiveMatchIndexChanged event. This event is raised when the index of the currently active match changes.
        This can happen when the user navigates to a different match or when the active match is changed programmatically. 
        The parameter is the event handler to be added. Returns a token representing the added event handler. 
        This token can be used to unregister the event handler.
        [event_handler("", "", "")]
        event Windows.Foundation.TypedEventHandler<CoreWebView2Find, Object> ActiveMatchIndexChanged;
    };
}
```

# Appendix

This API specification focuses on providing developers with the necessary information 
to integrate text finding and navigation functionalities into WebView2 applications. 
It emphasizes the usage of interfaces such as `ICoreWebView2Find` and 
`ICoreWebView2FindConfiguration` to perform find operations effectively. 

Additional Info:
Starting a find session when one is in progress will result in the active match index
being moved forward or backwards depending on what find configuration has been used
(forward,backward).
