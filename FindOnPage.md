# WebView2Find API

## Background

The WebView2Find API offers methods and events for text finding and navigation
within a WebView2 control. It enables developers to programmatically initiate Find
operations, navigate Find results, suppress default UI, and customize Find options
like find query. It also tracks the status of operations, indicating
completion, match count changes, and match index changes.

## Examples

### Default UI:

#### Without filter options
![image](https://github.com/user-attachments/assets/a71ba66b-8402-4e9d-a2fa-9437fce4a118)



#### With filter options
![image](https://github.com/user-attachments/assets/9817353b-e758-4b55-8c13-81fd036ec22a)



#### Description

To initiate a Find operation in a WebView2 control, use the `StartAsync` method.
This method allows setting the Find term and Find parameters via the
`ICoreWebView2FindOptions` interface. Only one Find session can be active per
WebView2 environment.
### Create/Specify a Find Option
#### WIN32 C++

```cpp

wil::com_ptr<ICoreWebView2FindOptions> AppWindow::InitializeFindOptions(const std::wstring& findTerm)
{
    // Query for the ICoreWebView2Environment5 interface.
    auto webView2Environment5 = m_webViewEnvironment.try_query<ICoreWebView2Environment5>();
    CHECK_FEATURE_RETURN(webView2Environment5);

    // Initialize Find options
    wil::com_ptr<ICoreWebView2FindOptions> find_options;
    CHECK_FAILURE(webView2Environment5->CreateFindOptions(&find_options));
    CHECK_FAILURE(find_options->put_FindTerm(findTerm.c_str()));

    return find_options;
}
```

```cpp
bool AppWindow::ConfigureAndExecuteFind(const std::wstring& findTerm) 
{
    auto find_options = InitializeFindOptions(findTerm);
    if (!find_options)
    {
        return false;
    }
    // Query for the ICoreWebView2_17 interface to access the Find feature.
    auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
    CHECK_FEATURE_RETURN(webView2_17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2Find> webView2Find;
    CHECK_FAILURE(webView2_17->get_Find(&webView2Find));

    // By default Find will use the default UI and highlight all matches. If you want different behavior
    // you can change the SuppressDefaultDialog and ShouldHighlightAllMatches properties here.

    // Start the Find operation with a callback for completion.
    CHECK_FAILURE(webView2Find->StartFind(
        find_options.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, BOOL status) -> HRESULT
            {
                if (SUCCEEDED(result))
                {
                    // Optionally update UI elements here upon successful Find operation.
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
```

```cpp
bool AppWindow::ExecuteFindWithCustomUI(const std::wstring& findTerm)
{
    auto find_options = InitializeFindOptions(findTerm);
    if (!find_options)
    {
        return false;
    }
    // Query for the ICoreWebView2_17 interface to access the Find feature.
    auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
    CHECK_FEATURE_RETURN(webView2_17);

    // Get the Find interface.
    wil::com_ptr<ICoreWebView2Find> webView2Find;
    CHECK_FAILURE(webView2_17->get_Find(&webView2Find));

    // Opt for using a custom UI for the Find operation.
    CHECK_FAILURE(webView2Find->put_SuppressDefaultDialog(true));

    // Start the Find operation with callback for completion.
    CHECK_FAILURE(webView2Find->StartFind(
        find_options.get(),
        Callback<ICoreWebView2FindOperationCompletedHandler>(
            [this](HRESULT result, BOOL status) -> HRESULT
            {
                if (SUCCEEDED(result) && status)
                {
                    // Optionally update UI elements here upon successful Find operation.
                }
                else
                {
                    // Handle errors or unsuccessful Find.
                }
                return S_OK;
            }).Get()));

    // Note: In this example, navigation through Find results (FindNext/FindPrevious)
    // and stopping the Find operation (StopFind) are assumed to be handled by
    // custom UI elements and user interaction, not directly in code here.
    // User could then connect functions such as FindNext, FindPrevious, and StopFind
    // to corresponding custom UI elements.

    return true;
}
```
#### .NET C#
```csharp
async Task ConfigureAndExecuteFindWithDefaultUIAsync(string findTerm)
{
    try
    {
        // Check if the webView is already initialized and is an instance of CoreWebView2.
        if (webView.CoreWebView2 == null)
        {
            throw new InvalidOperationException("WebView2 is not initialized.");
        }

        // Initialize the Find options with specified settings.
        var find_options = new CoreWebView2FindOptions
        {
            FindTerm = findTerm
        };

        // By default Find will use the default UI and highlight all matches. If you want different behavior
        // you can change the SuppressDefaultDialog and ShouldHighlightAllMatches properties here.

        // Start the Find operation with the specified options.
        await webView.CoreWebView2.Find.StartAsync(find_options);

        // End user interaction is handled via UI.
    }
    catch (Exception ex)
    {
        // Handle any errors that may occur during the Find operation.
        Console.WriteLine($"An error occurred: {ex.Message}");
    }
}
```

```csharp
async Task ConfigureAndExecuteFindWithCustomUIAsync(string findTerm)
{
    try
    {
        // Check if the webView is already initialized and is an instance of CoreWebView2.
        if (webView.CoreWebView2 == null)
        {
            throw new InvalidOperationException("WebView2 is not initialized.");
        }

        // Initialize the Find options.
        var find_options = new CoreWebView2FindOptions
        {
            FindTerm = findTerm
        };

        // Specify that a custom UI will be used for the Find operation.
        webView.CoreWebView2.Find.SuppressDefaultDialog = true;
        webView.CoreWebView2.Find.ShouldHighlightAllMatches = true;

        // Start the Find operation with the specified options.
        await webView.CoreWebView2.Find.StartAsync(find_options);
        // It's expected that the custom UI for navigating between matches (next, previous)
        // and stopping the Find operation will be managed by the developer's custom code.
    }
    catch (Exception ex)
    {
        // Handle any errors that may occur during the Find operation.
        Console.WriteLine($"An error occurred: {ex.Message}");
    }
}
```

### Retrieve the Index of the Active Match
    
#### Description
Developers can retrieve the index of the currently active match 
within a WebView2 control using the `ActiveMatchIndex` property.
    
    
```cpp
    bool AppWindow::GetActiveMatchIndex()
    {
        auto webView2_17 = m_webView.try_query<ICoreWebView2_17>();
        CHECK_FEATURE_RETURN(webView2_17);
        wil::com_ptr<ICoreWebView2Find> webView2Find;
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
public Task<int> GetActiveMatchIndex()
{
    var webViewFind = webView.CoreWebView2.Find; // Assuming webView is your WebView2 control
    var activeMatchIndex = webViewFind.ActiveMatchIndex();
    MessageBox.Show($"Active Match Index: {activeMatchIndex}", "Find Operation", MessageBoxButton.OK);
    return activeMatchIndex;
}

void ActiveMatchIndexChangedSample()
{
    webView.CoreWebView2.Find.ActiveMatchIndexChanged += (object sender, EventArgs args) =>
    {
        int activeMatchIndex = webView.CoreWebView2.Find.ActiveMatchIndex;
        // Update Custom UI based on the new active match index.
    };
}
```

## API Details
```cpp


/// Interface that provides methods related to the environment settings of CoreWebView2.
/// This interface allows for the creation of new Find options objects.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(f10bddd3-bb59-5d5b-8748-8a1a53f65d0c), object, pointer_default(unique)]
interface ICoreWebView2Environment5 : IUnknown {
  /// Creates a new instance of a FindOptions object.
  /// This options object can be used to define parameters for a Find operation.
  /// Returns the newly created FindOptions object.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT CreateFindOptions(
      [out, retval] ICoreWebView2FindOptions** value
  );


}


/// Receives the result of the `StartFind` method.
[uuid(7c20f8b0-c14e-5135-a099-6c9d11d59dd1), object, pointer_default(unique)]
interface ICoreWebView2indStartFindCompletedHandler : IUnknown {

  /// Provides the result of the corresponding asynchronous method.
  HRESULT Invoke([in] HRESULT errorCode);
}

/// Receives `FindActiveMatchIndexChanged` events.
[uuid(8d3422bf-66df-5bae-9916-71fd23d5bef6), object, pointer_default(unique)]
interface ICoreWebView2FindActiveMatchIndexChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Find* sender,
      [in] IUnknown* args);
}
/// Receives `FindMatchCountChanged` events.
[uuid(cecb8e8f-b6c8-55c3-98b1-68fd1e2b9eea), object, pointer_default(unique)]
interface ICoreWebView2FindMatchCountChangedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.
  HRESULT Invoke(
      [in] ICoreWebView2Find* sender,
      [in] IUnknown* args);
}


/// Interface providing methods and properties for finding and navigating through text in the WebView2.
/// This interface allows for finding text, navigation between matches, and customization of the Find UI.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(9c494a0a-c5d8-5fee-b7e6-4926d8d7b391), object, pointer_default(unique)]
interface ICoreWebView2Find : IUnknown {
  /// Retrieves the index of the currently active match in the Find session. Returns the index of the currently active match, or -1 if there is no active match.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT ActiveMatchIndex([out, retval] UINT32* value);


  /// Gets the total count of matches found in the current document based on the last Find sessions criteria. Returns the total count of matches.
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
      [in] ICoreWebView2ActiveMatchIndexChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_ActiveMatchIndexChanged`.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT remove_ActiveMatchIndexChanged(
      [in] EventRegistrationToken token);

  /// Adds an event handler for the `MatchCountChanged` event.
  /// Registers an event handler for the MatchCountChanged event. This event is raised when the total count of matches in the document changes due to a new Find operation or changes in the document.    /// The parameter is the event handler to be added. Returns a token representing the added event handler. This token can be used to unregister the event handler.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT add_MatchCountChanged(
      [in] ICoreWebView2MatchCountChangedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Removes an event handler previously added with `add_MatchCountChanged`.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT remove_MatchCountChanged(
      [in] EventRegistrationToken token);


  /// Initiates a Find using the specified Find option.
  /// Displays the Find bar and starts the Find operation. If a Find session was already ongoing, it will be stopped and replaced with this new instance.
  /// If called with an empty string, the Find bar is displayed but no finding occurs. Changing the Find options object after initiation won't affect the ongoing Find session.
  /// To change the ongoing Find session, Start must be called again with a new or modified Find options object.
  /// This method is primarily designed for HTML document queries.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  HRESULT StartFind(
      [in] ICoreWebView2FindOptions* options
      , [in] ICoreWebView2FindStartFindCompletedHandler* handler
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



/// Interface defining the Find options.
/// This interface provides the necessary methods and properties to configure a Find operation.
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(52a04b23-acc8-5659-aa2f-26dbe9faafde), object, pointer_default(unique)]
interface ICoreWebView2FindOptions : IUnknown {
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
/// Interface providing methods to access the Find operation functionalities in the CoreWebView2.
/// 
// MSOWNERS: core (maxwellmyers@microsoft.com)
[uuid(c9a130ca-a807-549c-9d76-8e09ccee3973), object, pointer_default(unique)]
interface ICoreWebView2_17 : IUnknown {
  /// Retrieves the Find operation interface for the current WebView2.
  // MSOWNERS: core (maxwellmyers@microsoft.com)
  [propget] HRESULT Find([out, retval] ICoreWebView2Find** value);



}
```


### Setting Up Find Options with MIDL3

### CoreWebView2 Find Configuration



### CoreWebView2 Find Interface

```csharp
namespace Microsoft.Web.WebView2.Core
{
    /// <com> 
    /// Interface providing methods to access the find session functionalities in the CoreWebView2.
    /// </com>
    [com_interface("staging=ICoreWebView2_17")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    interface ICoreWebView2_25
    {
        /// Retrieves the find session interface for the current web view.
        CoreWebView2Find Find { get; };
    }

    /// Interface that provides methods related to the environment settings of CoreWebView2.
    /// This interface allows for the creation of new `FindOptions` objects.
    [com_interface("staging=ICoreWebView2Environment5")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    interface ICoreWebView2Environment15
    {
        /// Creates a new instance of a CoreWebView2FindOptions object.
        /// This Find options object can be used to define parameters for a Find operation.
        /// Returns the newly created FindOptions object.
        CoreWebView2FindOptions CreateFindOptions();
    };

    runtimeclass CoreWebView2FindOptions : [default]ICoreWebView2FindOptions {}

    /// Interface defining the find options.
    /// This interface provides the necessary methods and properties to configure a find session.
    [com_interface("experimental=ICoreWebView2ExperimentalFindOptions")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    [availability("experimental")]
    interface ICoreWebView2FindOptions
    {
        /// Gets or sets the word or phrase to be searched in the current page.
        /// You can set `FindTerm` to any text you want to find on the page. 
        /// This will take effect the next time you call the `Start()` method.
        String FindTerm { get; set; };

        /// Determines if the find session is case sensitive. Returns TRUE if the find is case sensitive, FALSE otherwise.
        /// When toggling case sensitivity, the behavior can vary by locale, which may be influenced by both the browser's UI locale and the document's language settings. The browser's UI locale
        /// typically provides a default handling approach, while the document's language settings (e.g., specified using the HTML lang attribute) can override these defaults to apply locale-specific rules. This dual consideration
        /// ensures that text is processed in a manner consistent with user expectations and the linguistic context of the content.
        Boolean IsCaseSensitive { get; set; };

        /// Similar to case sensitivity, word matching also can vary by locale, which may be influenced by both the browser's UI locale and the document's language settings. The browser's UI locale
        /// typically provides a default handling approach, while the document's language settings (e.g., specified using the HTML lang attribute) can override these defaults to apply locale-specific rules. This dual consideration
        /// ensures that text is processed in a manner consistent with user expectations and the linguistic context of the content.
        /// ShouldMatchWord determines if only whole words should be matched during the find session. Returns TRUE if only whole words should be matched, FALSE otherwise.
        Boolean ShouldMatchWord { get; set; };

        /// Gets or sets the state of whether all matches are highlighted.
        /// Returns TRUE if all matches are highlighted, FALSE otherwise.
        /// Note: Changes to this property take effect only when Start, FindNext, or FindPrevious is called.
        /// Preferences for the session cannot be updated unless another call to the Start function on the server-side is made.
        /// Therefore, changes will not take effect until one of these functions is called.
        Boolean ShouldHighlightAllMatches { get; set; };

        /// Sets this property to hide the default Find UI.
        /// You can use this to hide the default UI so that you can show your own custom UI or programmatically interact with the Find API while showing no Find UI.
        /// Returns TRUE if hiding the default Find UI and FALSE if using showing the default Find UI.
        /// Note: Changes to this property take effect only when Start, FindNext, or FindPrevious is called.
        /// Preferences for the session cannot be updated unless another call to the Start function on the server-side is made.
        /// Therefore, changes will not take effect until one of these functions is called.
        Boolean SuppressDefaultFindDialog { get; set; };
    };
    
   runtimeclass CoreWebView2Find : [default]ICoreWebView2Find {}

    /// Interface providing methods and properties for finding and navigating through text in the web view.
    /// This interface allows for finding text, navigation between matches, and customization of the find UI.
    [com_interface("experimental=ICoreWebView2ExperimentalFind")]
    [ms_owner("core", "maxwellmyers@microsoft.com")]
    [availability("experimental")]
    interface ICoreWebView2Find
    {
        /// Initiates a find using the specified find options asynchronously.
        /// Displays the Find bar and starts the find session. If a find session was already ongoing, it will be stopped and replaced with this new instance.
        /// If called with an empty string, the Find bar is displayed but no finding occurs. Changing the FindOptions object after initiation won't affect the ongoing find session.
        /// To change the ongoing find session, Start must be called again with a new or modified FindOptions object.
        /// Start supports HTML and TXT document queries. In general, this API is designed for text-based find sessions.
        /// If you start a find session programmatically on another file format that doesn't have text fields, the find session will try to execute but will fail to find any matches. (It will silently fail)
        /// Note: The asynchronous action completes when the UI has been displayed with the find term in the UI bar, and the matches have populated on the counter on the find bar.
        /// There may be a slight latency between the UI display and the matches populating in the counter.
        /// The MatchCountChanged and ActiveMatchIndexChanged events are only raised after Start has completed; otherwise, they will have their default values (-1 for active match index and 0 for match count).
        /// To start a new find session (beginning the search from the first match), call `Stop` before invoking `Start`.
        /// If `Start` is called consecutively with the same options and without calling `Stop`, the find session
        /// will continue from the current position in the existing session.
        /// Calling `Start` without altering its parameters will behave either as `FindNext` or `FindPrevious`, depending on the most recent search action performed.
        /// Start will default to forward if neither have been called.
        /// However, calling Start again during an ongoing find session does not resume from the point
        /// of the current active match. For example, given the text "1 1 A 1 1" and initiating a find session for "A",
        /// then starting another find session for "1", it will start searching from the beginning of the document,
        /// regardless of the previous active match. This behavior indicates that changing the find query initiates a
        /// completely new find session, rather than continuing from the previous match index.
        Windows.Foundation.IAsyncAction StartAsync(CoreWebView2FindOptions options);

        /// Navigates to the next match in the document.
        /// If there are no matches to find, FindNext will wrap around to the first match's index.
        /// If called when there is no find session active, FindPrevious will silently fail.
        void FindNext();

        /// Navigates to the previous match in the document.
        /// If there are no matches to find, FindPrevious will wrap around to the last match's index.
        /// If called when there is no find session active, FindPrevious will silently fail.
        void FindPrevious();

        /// Stops the current 'Find' session and hides the Find bar.
        /// If called with no Find session active, it will silently do nothing.
        void Stop();

        /// Retrieves the index of the currently active match in the find session. Returns the index of the currently active match, or -1 if there is no active match.
        /// The index starts at 1 for the first match.
        Int32 ActiveMatchIndex { get; };

        /// Gets the total count of matches found in the current document based on the last find sessions criteria. Returns the total count of matches.
        Int32 MatchCount { get; };

        /// Registers an event handler for the MatchCountChanged event.
        /// This event is raised when the total count of matches in the document changes due to a new find session or changes in the document.
        /// The parameter is the event handler to be added. Returns a token representing the added event handler. This token can be used to unregister the event handler.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Find, Object> MatchCountChanged;

        /// Registers an event handler for the ActiveMatchIndexChanged event. This event is raised when the index of the currently active match changes.
        /// This can happen when the user navigates to a different match or when the active match is changed programmatically.
        /// The parameter is the event handler to be added. Returns a token representing the added event handler.
        /// This token can be used to unregister the event handler.
        event Windows.Foundation.TypedEventHandler<CoreWebView2Find, Object> ActiveMatchIndexChanged;
    };
    



    }
    }
```

# Appendix

This API specification focuses on providing developers with the necessary information 
to integrate text finding and navigation functionalities into WebView2 applications. 
It emphasizes the usage of interfaces such as `ICoreWebView2Find` and 
`ICoreWebView2FindOptions` to perform Find operations effectively. 


