<!-- 
    Before submitting, delete all "<!-- TEMPLATE" marked comments in this file,
    and the following quote banner:
-->
> See comments in Markdown for how to use this spec template

<!-- TEMPLATE
    The purpose of this spec is to describe new APIs, in a way
    that will transfer to learn.microsoft.com (https://learn.microsoft.com/microsoft-edge/webview2/).

    There are two audiences for the spec. The first are people that want to evaluate and
    give feedback on the API, as part of the submission process.
    So the second audience is everyone that reads there to learn how and why to use this API.
    Some of this text also shows up in Visual Studio Intellisense.
    When the PR is complete, the content within the 'Conceptual Pages' section of the review spec will be incorporated into the public documentation at
    http://learn.microsoft.com (LMC).

    For example, much of the examples and descriptions in the `RadialGradientBrush` API spec
    (https://github.com/microsoft/microsoft-ui-xaml-specs/blob/master/active/RadialGradientBrush/RadialGradientBrush.md)
    were carried over to the public API page on LMC
    (https://learn.microsoft.com/windows/winui/api/microsoft.ui.xaml.media.radialgradientbrush?view=winui-2.5)

    Once the API is on LMC, that becomes the official copy, and this spec becomes an archive.
    For example if the description is updated, that only needs to happen on LMC and needn't
    be duplicated here.

    Examples:
    * New set of classes and APIs (Custom Downloads):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md
    * New member on an existing class (BackgroundColor):
      https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/BackgroundColor.md

    Style guide:
    * Use second person; speak to the developer who will be learning/using this API.
    (For example "you use this to..." rather than "the developer uses this to...")
    * Use hard returns to keep the page width within ~100 columns.
    (Otherwise it's more difficult to leave comments in a GitHub PR.)
    * Talk about an API's behavior, not its implementation.
    (Speak to the developer using this API, not to the team implementing it.)
    * A picture is worth a thousand words.
    * An example is worth a million words.
    * Keep examples realistic but simple; don't add unrelated complications.
    (An example that passes a stream needn't show the process of launching the File-Open dialog.)
    * Use GitHub flavored Markdown: https://guides.github.com/features/mastering-markdown/

-->

Sensitivity label support for Webview2
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
Web pages may contain content with sensitive information. Such information can be identified using data loss protection methods. The purpose of this API is to provide sensitivity label information, communicated by web pages through the Page Interaction Restriction Manager (see details here), to the host application. This enables the host application to be informed of the presence of sensitive content.

# Description

_(This is conceptual documentation that will go to learn.microsoft.com "how to" page)_

<!-- TEMPLATE
    (Optional)

    All APIs have reference docs, but some APIs or groups of APIs have an additional high level,
    conceptual page (called a "how-to" page). This section can be used for that content.

    For example, there are several navigation events each with their own reference doc, but then
    there's also a concept doc on navigation
    (https://learn.microsoft.com/microsoft-edge/webview2/concepts/navigation-events).

    Sometimes it's difficult to decide if text belongs on a how-to page or an API page.
    Because our API reference documentation is automatically turned into reference docs you can
    lean towards including text in the API documentation below instead of in this conceptual
    section.
-->
We propose introducing a SensitivityLabelChanged event to the CoreWebView2 object, enabling applications to monitor changes in sensitivity labels within hosted content. This functionality is restricted to domains explicitly included in an allow list configured by the application. The allow list can be set at the profile level, thereby enabling the Page Interaction Restriction Manager for content within specified domains. By default, the allow list is empty, preventing hosted content from transmitting sensitivity label information.
The core features of this proposal are as follows:
•	Configure the allowlist filter for Page Interaction Restriction Manager at the profile level.
•	After setup, the manager is available on allowlisted pages. Content can send sensitivity labels to the platform via the API.
•	When a label changes, an event notifies the platform of all labels on that page.
•	Sensitivity labels are cleared when navigating away from the current WebView.

# Examples
<!-- TEMPLATE
    Use this section to explain the features of the API, showing
    example code with each description in both C# (for our WinRT API or .NET API) and
    in C++ for our COM API. Use snippets of the sample code you wrote for the sample apps.
    The sample code for C++ and C# should demonstrate the same thing.
    If you are introducing a JavaScript API or otherwise the sample relies on HTML or JS
    include that and consider including it in its own HTML or JS sample code.

    As an example of this section, see the Examples section for the Custom Downloads
    APIs (https://github.com/MicrosoftEdge/WebView2Feedback/blob/master/specs/CustomDownload.md). 

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

    If the sample code requires JS or HTML include that as well

    ```html
    <script>
        chrome.webview.postMessage(...);
    </script>
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


    If the sample code requires JS or HTML include that as well

    ```html
    <script>
        chrome.webview.postMessage(...);
    </script>
    ```

-->

# API Details
<!-- TEMPLATE
    The exact API, in IDL format for our COM API and
    in MIDL3 format (https://learn.microsoft.com/uwp/midl-3/)
    when possible.

    Include every new or modified type but use // ... to remove any methods,
    properties, or events that are unchanged.

    For the MIDL3 parts, after running build-apiwriter, open the generated
    `Microsoft.Web.WebView2.Core.idl` and find the new or modified portions
    generated from your modifications to the COM IDL.

    (GitHub's markdown syntax formatter does not (yet) know about MIDL3, so
    use ```c# instead even when writing MIDL3.)

    Example:
    
```
[uuid(B625A89E-368F-43F5-BCBA-39AA6234CCF8), object, pointer_default(unique)]
interface ICoreWebView2Settings4 : ICoreWebView2Settings3 {
  /// The IsPinchZoomEnabled property enables or disables the ability of 
  /// the end user to use a pinching motion on touch input enabled devices
  /// to scale the web content in the WebView2. It defaults to TRUE.
  /// When set to FALSE, the end user cannot pinch zoom.
  /// This API only affects the Page Scale zoom and has no effect on the
  /// existing browser zoom properties (IsZoomControlEnabled and ZoomFactor)
  /// or other end user mechanisms for zooming.
  ///
  /// \snippet SettingsComponent.cpp TogglePinchZooomEnabled
  [propget] HRESULT IsPinchZoomEnabled([out, retval] BOOL* enabled);
  /// Set the IsPinchZoomEnabled property
  [propput] HRESULT IsPinchZoomEnabled([in] BOOL enabled);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Settings
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Settings5")]
        {
            Boolean IsPinchZoomEnabled { get; set; };
        }
    }
}
```

If you are introducing a WebView2 JavaScript API include the TypeScript
definition of that API and reference documentation for it as well.
You can use https://www.typescriptlang.org/play to verify your TypeScript

```ts
interface WebView extends EventTarget {
    postMessage(message: any) : void;
    hostObjects: HostObjectsAsyncRoot;
    // ...
}

interface HostObjectsAsyncRoot {
    cleanupSome() : void;
    options: HostObjectsOptions;
}

interface HostObjectsOptions {
    forceLocalProperties: string[];
    log: (...data: any[]) => void;
    shouldSerializeDates: boolean;
    defaultSyncProxy: boolean;
    forceAsyncMethodMatches: RegExp[];
    ignoreMemberNotFoundError: boolean;
}
```

-->


# Appendix
<!-- TEMPLATE
  Anything else that you want to write down about implementation notes and for posterity,
  but that isn't necessary to understand the purpose and usage of the API.
  
  This or the Background section are a good place to describe alternative designs
  and why they were rejected, any relevant implementation details, or links to other
  resources.
-->
