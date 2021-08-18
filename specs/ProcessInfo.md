Process Info
===

# Background
<!-- TEMPLATE
    Use this section to provide background context for the new API(s)
    in this spec. Try to briefly provide enough information to be able to read
    the rest of the document.

    This section and the appendix are the only sections that likely
    do not get copied into any official documentation, they're just an aid
    to reading this spec. If you find useful information in the background
    or appendix consider moving it to documentation.
    
    If you're modifying an existing API, included a link here to the
    existing page(s) or spec documentation.

    For example, this section is a place to explain why you're adding this
    API rather than modifying an existing API.

    For example, this is a place to provide a brief explanation of some dependent
    area, just explanation enough to understand this new API, rather than telling
    the reader "go read 100 pages of background information posted at ...". 
-->

# Conceptual pages (How To)

_(This is conceptual documentation that will go to docs.microsoft.com "how to" page)_

<!-- TEMPLATE
    (Optional)

    All APIs have reference docs, but some APIs or groups of APIs have an additional high level,
    conceptual page (called a "how-to" page). This section can be used for that content.

    For example, there are several navigation events each with their own reference doc, but then
    there's also a concept doc on navigation
    (https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/navigation-events).

    Sometimes it's difficult to decide if text belongs on a how-to page or an API page.
    Because our API reference documentation is automatically turned into reference docs you can
    lean towards including text in the API documentation below instead of in this conceptual
    section.
-->


# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.
    The sample code for C++ and C# should demonstrate the same thing.

    The general format is:

    ## FirstFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    ## SecondFeatureName

    Feature explanation text goes here, including why an app would use it, how it
    replaces or supplements existing functionality.

    ```c#
    void SampleMethod()
    {
        var show = new AnExampleOf();
        show.SomeMembers = AndWhyItMight(be, interesting)
    }
    ```
    
    ```cpp
    void SampleClass::SampleMethod()
    {
        winrt::com_ptr<ICoreWebView2> webview2 = ...
    }
    ```

    As an example of this section, see the Examples section for the Custom Downloads
    APIs (https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md). 
-->

# API Details    
```
interface ICoreWebView2StagingProcessCollection;
interface ICoreWebView2StagingProcessRequestedEventHandler;

[v1_enum]
typedef enum COREWEBVIEW2_PROCESS_KIND {
  /// Indicates the browser process kind.
  COREWEBVIEW2_PROCESS_KIND_BROWSER_PROCESS,

  /// Indicates the render process kind.
  COREWEBVIEW2_PROCESS_KIND_RENDERER_PROCESS,

  /// Indicates the utility process kind.
  COREWEBVIEW2_PROCESS_KIND_UTILITY_PROCESS,

  /// Indicates the sandbox helper process kind.
  COREWEBVIEW2_PROCESS_KIND_SANDBOX_HELPER_PROCESS,

  /// Indicates the GPU process kind.
  COREWEBVIEW2_PROCESS_KIND_GPU_PROCESS,

  /// Indicates the PPAPI plugin process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_PLUGIN_PROCESS,

  /// Indicates the PPAPI plugin broker process kind.
  COREWEBVIEW2_PROCESS_KIND_PPAPI_BROKER_PROCESS,

  /// Indicates the process of unspecified kind.
  COREWEBVIEW2_PROCESS_KIND_UNKNOWN_PROCESS,
} COREWEBVIEW2_PROCESS_KIND;

[uuid(B625A89E-368F-43F5-BCBA-39AA6234CCF8), object, pointer_default(unique)]
interface ICoreWebView2Staging2 : ICoreWebView2Staging {
  /// Adds an event handler for the `ProcessRequested` event.
  /// 
  /// \snippet ProcessComponent.cpp ProcessRequested
  HRESULT add_ProcessRequested(
      [in] ICoreWebView2StagingProcessRequestedEventHandler* eventHandler,
      [out] EventRegistrationToken* token);

  /// Remove an event handler previously added with `add_ProcessRequested`.
  HRESULT remove_ProcessRequested(
      [in] EventRegistrationToken token);

  /// Returns the `ICoreWebView2StagingProcessCollection`
  [propget] HRESULT ProcessInfo([out, retval]ICoreWebView2StagingProcessCollection** value);
}

/// A list containing process id and corresponding process type.
/// \snippet ProcessComponent.cpp get_ProcessInfo
[uuid(5356F3B3-4859-4763-9C95-837CDEEE8912), object, pointer_default(unique)]
interface ICoreWebView2StagingProcessCollection : IUnknown {
  /// The number of process contained in the ICoreWebView2StagingProcessCollection.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the process id at the given index.
  HRESULT GetProcessIdAtIndex([in] UINT index, [out, retval] UINT32* value);

  /// Gets the process type at the given index.
  HRESULT GetProcessTypeAtIndex([in] UINT index, [out, retval] COREWEBVIEW2_PROCESS_KIND* processKind);
}

/// An event handler for the `ProcessRequested` event.
[uuid(CFF13C72-2E3B-4812-96FB-DFDDE67FBE90), object, pointer_default(unique)]
interface ICoreWebView2StagingProcessRequestedEventHandler : IUnknown {
  /// Provides the event args for the corresponding event.  No event args exist
  /// and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2* sender, [in] IUnknown* args);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    // ...
    runtimeclass CoreWebView2ProcessCollection;

    /// Kind of process type used in the CoreWebView2ProcessCollection.
    enum CoreWebView2ProcessKind
    {
        BrowserProcess = 0,
        RendererProcess = 1,
        UtilityProcess = 2,
        SandboxHelperProcess = 3,
        GpuProcess = 4,
        PpapiPluginProcess = 5,
        PpapiBrokerProcess = 6,
        UnknownProcess = 7,
    };

    runtimeclass CoreWebView2
    {
        /// Gets a list of process.
        CoreWebView2ProcessCollection ProcessInfo { get; };
        event Windows.Foundation.TypedEventHandler<CoreWebView2, Object> ProcessRequested;

        // ...
    }

    runtimeclass CoreWebView2ProcessCollection
    {
        // ICoreWebView2ProcessCollection members
        /// Process count.
        UInt32 Count { get; };

        /// Process id.
        UInt32 GetProcessIdAtIndex(UInt32 index);

        /// Process type.
        CoreWebView2ProcessKind GetProcessTypeAtIndex(UInt32 index);
    }

    // ...
}
```

