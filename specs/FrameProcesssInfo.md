Frame Process Info API
===

# Background
Management of performance and overhead are some of the top concerns with 
applications building more complex experiences using WebView2. We're seeing
applications use multiple WebView2s, iframes, fencedframes, or other 
embedding techniques for different aspects of their user's experience, and
needing to prioritize or deprioritize the less important experiences depending
on what the user is doing. This is similar to how the browser needs to 
understand the impact of each tab in order to ensure that the background tabs 
don't cause a major impact on the user's experience in the foreground tab.

We provide the `GetProcessInfos` API for host applications to understand which
processes are part of their WebView2s. That API provides enough information for
a host application to understand the overall performance impact (memory, CPU 
usage, etc.) of WebView2 on their application or the user's device, but it 
doesn't provide the granularity needed for the host application to know which 
part of WebView2 is consuming those resources.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
* We propose extending `CoreWebView2Environment` to include the 
`GetProcessExtendedInfos` API. This asynchronous call returns a 
snapshot collection of `ProcessExtendedInfo`s corresponding to 
all currently running processes associated with this 
`ICoreWebView2Environment` except for crashpad process. This 
provide the same list of `ProcessInfo`s as what's provided in 
`GetProcessInfos`. Plus, this also provide the list of associated 
`FrameInfo`s actively running (showing UI elements) in the 
renderer process.

* We propose to add the new interface `CoreWebView2ProcessExtendedInfo` 
which has `AssociatedFrameInfo` and `ProcessInfo` properties. We use 
the `AssociatedFrameInfo` API to provide a list of `FrameInfo`s actively 
running (showing UI elements) in the asscociated renderer process. 
We use `ProcessInfo` to provide corresponding process information. 

* We propose extending `CoreWebView2` and `CoreWebView2Frame` to include 
the `FrameId` property. This property represents the unique identifier of
the frame running in this `CoreWebView2` or `CoreWebView2Frame`.

* We propose extending `CoreWebView2FrameInfo` to include `FrameId`, 
`FrameKind` and `ParentFrameInfo` properties. `FrameId` is the same 
kind of ID as with `FrameID` in `CoreWebView2` and `CoreWebView2Frame`. 
`ParentFrameInfo` supports to retrieve a frame's direct parent. This 
also can be used to build the frame tree represented by `FrameInfo`s.

# Examples
C++
```c++
void AppendFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstringstream& result);
wil::com_ptr<ICoreWebView2FrameInfo> GetAncestorMainFrameDirectChildFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo);
wil::com_ptr<ICoreWebView2FrameInfo> GetAncestorMainFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo);
std::wstring FrameKindToString(COREWEBVIEW2_FRAME_KIND kind);

// Display renderer process info with details which includes the list of 
// associated frame infos for the renderer process. Also shows the process 
// info of other type of process.
void ProcessComponent::ShowProcessExtendedInfo()
{
    auto environment14 =
        m_webViewEnvironment.try_query<ICoreWebView2Environment14>();
    if (environment14)
    {
        //! [GetProcessExtendedInfos]
        CHECK_FAILURE(environment14->GetProcessExtendedInfos(
            Callback<ICoreWebView2GetProcessExtendedInfosCompletedHandler>(
                [this](HRESULT error, ICoreWebView2ProcessExtendedInfoCollection* processCollection)
                    -> HRESULT
                {
                    UINT32 processCount = 0;
                    UINT32 rendererProcessCount = 0;
                    CHECK_FAILURE(processCollection->get_Count(&processCount));
                    std::wstringstream otherProcessInfos;
                    std::wstringstream rendererProcessInfos;
                    for (UINT32 i = 0; i < processCount; i++)
                    {
                        Microsoft::WRL::ComPtr<ICoreWebView2ProcessExtendedInfo> processExtendedInfo;
                        CHECK_FAILURE(processCollection->GetValueAtIndex(i, &processExtendedInfo));
                        Microsoft::WRL::ComPtr<ICoreWebView2ProcessInfo> processInfo;
                        CHECK_FAILURE(processExtendedInfo->get_ProcessInfo(&processInfo));
                        COREWEBVIEW2_PROCESS_KIND kind;
                        CHECK_FAILURE(processInfo->get_Kind(&kind));
                        INT32 processId = 0;
                        CHECK_FAILURE(processInfo->get_ProcessId(&processId));
                        if (kind == COREWEBVIEW2_PROCESS_KIND_RENDERER)
                        {
                            //! [AssociatedFrameInfos]
                            std::wstringstream rendererProcess;
                            wil::com_ptr<ICoreWebView2FrameInfoCollection> frameInfoCollection;
                            CHECK_FAILURE(processExtendedInfo->get_AssociatedFrameInfos(
                                &frameInfoCollection));
                            wil::com_ptr<ICoreWebView2FrameInfoCollectionIterator> iterator;
                            CHECK_FAILURE(frameInfoCollection->GetIterator(&iterator));
                            BOOL hasCurrent = FALSE;
                            UINT32 frameInfoCount = 0;
                            while (SUCCEEDED(iterator->get_HasCurrent(&hasCurrent)) &&
                                   hasCurrent)
                            {
                                wil::com_ptr<ICoreWebView2FrameInfo> frameInfo;
                                CHECK_FAILURE(iterator->GetCurrent(&frameInfo));

                                AppendFrameInfo(frameInfo, rendererProcess);

                                BOOL hasNext = FALSE;
                                CHECK_FAILURE(iterator->MoveNext(&hasNext));
                                frameInfoCount++;
                            }
                            rendererProcessInfos
                                << std::to_wstring(frameInfoCount)
                                << L" frameInfo(s) found in Renderer Process ID:"
                                << std::to_wstring(processId) << L"\n"
                                << rendererProcess.str() << std::endl;
                            rendererProcessCount++;
                            //! [AssociatedFrameInfos]
                        }
                        else
                        {
                            otherProcessInfos << L"Process Id:" << std::to_wstring(processId)
                                              << L" | Process Kind:"
                                              << ProcessKindToString(kind) << std::endl;
                        }
                    }
                    std::wstringstream message;
                    message << std::to_wstring(processCount)
                            << L" process(es) found, from which "
                            << std::to_wstring(rendererProcessCount)
                            << L" renderer process(es) found\n\n"
                            << rendererProcessInfos.str() << L"Remaining Process(es) Infos:\n"
                            << otherProcessInfos.str();

                    m_appWindow->AsyncMessageBox(
                        std::move(message.str()), L"Process Info with Associated Frames");
                    return S_OK;
                })
                .Get()));
        //! [GetProcessExtendedInfos]
    }
}

// Get the ancestor main frameInfo.
// Return itself if it's a main frame.
wil::com_ptr<ICoreWebView2FrameInfo> ProcessComponent::GetAncestorMainFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo)
{
    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo;
    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    while (frameInfo)
    {
        mainFrameInfo = frameInfo;
        CHECK_FAILURE(frameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_ParentFrameInfo(&frameInfo));
    }
    return mainFrameInfo;
}

// Get the frame's corresponding main frame's direct child frameInfo.
// Example:
//         A (main frame/CoreWebView2)
//         | \
// (frame) B  C (frame)
//         |  |
// (frame) D  E (frame)
//            |
//            F (frame)
// C GetAncestorMainFrameDirectChildFrameInfo returns C.
// D GetAncestorMainFrameDirectChildFrameInfo returns B.
// F GetAncestorMainFrameDirectChildFrameInfo returns C.
wil::com_ptr<ICoreWebView2FrameInfo> ProcessComponent::GetAncestorMainFrameDirectChildFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo)
{
    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo;
    wil::com_ptr<ICoreWebView2FrameInfo> childFrameInfo;
    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    while (frameInfo)
    {
        childFrameInfo = mainFrameInfo;
        mainFrameInfo = frameInfo;
        CHECK_FAILURE(frameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_ParentFrameInfo(&frameInfo));
    }
    return childFrameInfo;
}

void ProcessComponent::AppendFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstringstream& result)
{
    UINT32 frameId = 0;
    UINT32 parentFrameId = 0;
    UINT32 mainFrameId = 0;
    UINT32 firstLevelFrameId = 0;
    std::wstring type = L"other child frame";
    wil::unique_cotaskmem_string nameRaw;
    wil::unique_cotaskmem_string sourceRaw;
    COREWEBVIEW2_FRAME_KIND frameKind = COREWEBVIEW2_FRAME_KIND_UNKNOWN;

    CHECK_FAILURE(frameInfo->get_Name(&nameRaw));
    std::wstring name = nameRaw.get()[0] ? nameRaw.get() : L"none";
    CHECK_FAILURE(frameInfo->get_Source(&sourceRaw));
    std::wstring source = sourceRaw.get()[0] ? sourceRaw.get() : L"none";

    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    CHECK_FAILURE(frameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
    frameInfo2->get_FrameId(&frameId);
    frameInfo2->get_FrameKind(&frameKind);

    wil::com_ptr<ICoreWebView2FrameInfo> parentFrameInfo;
    CHECK_FAILURE(frameInfo2->get_ParentFrameInfo(&parentFrameInfo));
    if (parentFrameInfo)
    {
        CHECK_FAILURE(parentFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_FrameId(&parentFrameId));
    }

    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo = GetAncestorMainFrameInfo(frameInfo);
    if (mainFrameInfo == frameInfo)
    {
        type = L"main frame";
    }
    CHECK_FAILURE(mainFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
    CHECK_FAILURE(frameInfo2->get_FrameId(&mainFrameId));

    wil::com_ptr<ICoreWebView2FrameInfo> childFrameInfo =
        GetAncestorMainFrameDirectChildFrameInfo(frameInfo);
    if (childFrameInfo == frameInfo)
    {
        type = L"first level frame";
    }
    if (childFrameInfo)
    {
        CHECK_FAILURE(
            childFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_FrameId(&childFrameId));
    }

    result << L"{frame name:" << name << L" | frame Id:" << frameId << L" | parent frame Id:"
           << ((parentFrameId == 0) ? L"none" : std::to_wstring(parentFrameId))
           << L" | frame type:" << type << L"\n"
           << L" | ancestor main frame Id:" << mainFrameId
           << L" | ancestor main frame's direct child frame Id:"
           << ((childFrameId == 0) ? L"none" : std::to_wstring(childFrameId)) << L"\n"
           << L" | frame kind:" << FrameKindToString(frameKind) << L"\n"
           << L" | frame source:" << source << L"}," << std::endl;
}

// Get a string for the frame kind enum value.
std::wstring ProcessComponent::FrameKindToString(const COREWEBVIEW2_FRAME_KIND kind)
{
    switch (kind)
    {           
#define KIND_ENTRY(kindValue)                                                        
    case kindValue:   
        return L#kindValue;
        KIND_ENTRY(COREWEBVIEW2_FRAME_KIND_MAIN_FRAME);
        KIND_ENTRY(COREWEBVIEW2_FRAME_KIND_IFRAME);
        KIND_ENTRY(COREWEBVIEW2_FRAME_KIND_EMBED);
        KIND_ENTRY(COREWEBVIEW2_FRAME_KIND_OBJECT);
        KIND_ENTRY(COREWEBVIEW2_FRAME_KIND_UNKNOWN);
    }
#undef KIND_ENTRY
    return std::to_wstring(static_cast<uint32_t>(kind));
}
```
C#
```c#
string AppendFrameInfo(CoreWebView2FrameInfo frameInfo) {
    string id = frameInfo.FrameId.ToString();
    string kind = frameInfo.FrameKind.ToString();
    string name = String.IsNullOrEmpty(frameInfo.Name) ? "none" : frameInfo.Name;
    string source = String.IsNullOrEmpty(frameInfo.Source) ? "none" : frameInfo.Source;
    string parentId = frameInfo.ParentFrameInfo == null ? "none" : frameInfo.ParentFrameInfo.FrameId.ToString();
    string type = "other frame";

    CoreWebView2FrameInfo mainFrame = GetAncestorMainFrameInfo(frameInfo);
    string mainFrameId = mainFrame.FrameId.ToString();
    if (frameInfo == mainFrame) {
        type = "main frame";
    }

    CoreWebView2FrameInfo childFrame = GetAncestorMainFrameDirectChildFrameInfo(frameInfo);
    string childFrameId = childFrame == null ? "none" : childFrame.FrameId.ToString();
    if (frameInfo == childFrame) {
        type = "first level frame";
    }

    return $"{{frame Id:{id} " +
            $"| frame Name: {name} " +
            $"| frame Type: {type} " +
            $"| parent frame Id: {parentId} \n" +
            $"| ancestor main frame Id: {mainFrameId} " +
            $"| ancestor first level frame Id: {childFrameId} \n" +
            $"| frame Kind: {kind} " +
            $"| frame Source: \"{source}\"}}\n";
}

CoreWebView2FrameInfo GetAncestorMainFrameInfo(CoreWebView2FrameInfo frameInfo) {
    while (frameInfo.ParentFrameInfo != null) {
        frameInfo = frameInfo.ParentFrameInfo;
    }
    return frameInfo;
}

// Get the frame's corresponding main frame's direct child frameInfo.
// Example:
//         A (main frame/CoreWebView2)
//         | \
// (frame) B  C (frame)
//         |  |
// (frame) D  E (frame)
//            |
//            F (frame)
// C GetAncestorMainFrameDirectChildFrameInfo returns C.
// D GetAncestorMainFrameDirectChildFrameInfo returns B.
// F GetAncestorMainFrameDirectChildFrameInfo returns C.
CoreWebView2FrameInfo GetAncestorMainFrameDirectChildFrameInfo(CoreWebView2FrameInfo frameInfo) {
    if (frameInfo.ParentFrameInfo == null) {
        return null;
    }

    CoreWebView2FrameInfo childFrameInfo = null;
    CoreWebView2FrameInfo mainFrameInfo = null;
    while (frameInfo != null) {
        childFrameInfo = mainFrameInfo;
        mainFrameInfo = frameInfo;
        frameInfo = frameInfo.ParentFrameInfo;
    }
    return childFrameInfo;
}

private async void ProcessFrameInfoCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    try
    {
        // <GetProcessExtendedInfos>
        IReadOnlyList<CoreWebView2ProcessExtendedInfo> processList = await webView.CoreWebView2.Environment.GetProcessExtendedInfosAsync();
        int processCount = processList.Count;
        string rendererProcessInfos = "";
        string otherProcessInfos = "";
        int rendererProcessCount = 0;
        for (int i = 0; i < processCount; ++i)
        {
            CoreWebView2ProcessInfo processInfo = processList[i].ProcessInfo;
            CoreWebView2ProcessKind kind = processInfo.Kind;
            int processId = processInfo.ProcessId;
            if (kind == CoreWebView2ProcessKind.Renderer)
            {
                int frameInfoCount = 0;
                string frameInfos = "";
                // <AssociatedFrameInfos>
                IReadOnlyList<CoreWebView2FrameInfo> frameInfoList = processList[i].AssociatedFrameInfos;
                foreach (CoreWebView2FrameInfo frameInfo in frameInfoList)
                {
                    frameInfoCount++;
                    frameInfos += AppendFrameInfo(frameInfo);
                }
                // </AssociatedFrameInfos>
                string rendererProcessInfo = $"{frameInfoCount} frame info(s) found in renderer process ID: {processId}\n {frameInfos}";
                rendererProcessInfos += $"{rendererProcessInfo} \n";
                rendererProcessCount++;
            }
            else
            {
                otherProcessInfos += $"Process ID: {processId} | Process Kind: {kind}\n";
            }
        }
        // </GetProcessExtendedInfos>
        string message = $"{processCount} process(es) found in total, from which {rendererProcessCount} renderer process(es) found\n\n" +
                            $"{rendererProcessInfos}\nRemaining Process Infos:\n{otherProcessInfos}";
        MessageBox.Show(this, message, "Process Extended Info");
    }
    catch (NotImplementedException exception)
    {
        MessageBox.Show(this, "GetProcessExtendedInfosAsync Failed: " + exception.Message,
                "Process Extended Info");
    }
}
```

# API Details
## C++
```c++
interface ICoreWebView2_18;
interface ICoreWebView2Frame5;
interface ICoreWebView2FrameInfo2;
interface ICoreWebView2Environment14;
interface ICoreWebView2ProcessExtendedInfo;
interface ICoreWebView2ProcessExtendedInfoCollection;
interface ICoreWebView2GetProcessExtendedInfosCompletedHandler;

// Indicates the frame type used in the `ICoreWebView2FrameInfo2` interface.
[v1_enum]
typedef enum COREWEBVIEW2_FRAME_KIND {
  /// Indicates that the frame is an unknown type frame. We may extend this enum
  /// type to identify more frame kinds in the future.
  COREWEBVIEW2_FRAME_KIND_UNKNOWN,
  /// Indicates that the frame is a primary main frame(webview).
  COREWEBVIEW2_FRAME_KIND_MAIN_FRAME,
  /// Indicates that the frame is an iframe.
  COREWEBVIEW2_FRAME_KIND_IFRAME,
  /// Indicates that the frame is an embed element.
  COREWEBVIEW2_FRAME_KIND_EMBED,
  /// Indicates that the frame is an object element.
  COREWEBVIEW2_FRAME_KIND_OBJECT,
} COREWEBVIEW2_FRAME_KIND;

/// Receives the result of the `GetProcessExtendedInfos` method.
/// The result is written to the collection of `ProcessInfo`s provided
/// in the `GetProcessExtendedInfos` method call.
[uuid(8e7d154c-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2ProcessExtendedInfoCompletedHandler : IUnknown {
  /// Provides the process extended info list for the `GetProcessExtendedInfos`.
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ProcessExtendedInfoCollection* value);
}

/// A list containing processInfo and associated extended information.
[uuid(32efa696-407a-11ee-be56-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2ProcessExtendedInfoCollection : IUnknown {
  /// The number of process contained in the `ICoreWebView2ProcessExtendedInfoCollection`.
  [propget] HRESULT Count([out, retval] UINT* count);

  /// Gets the `ICoreWebView2ProcessExtendedInfo` located in the
  /// `ICoreWebView2ProcessExtendedInfoCollection` at the given index.
  HRESULT GetValueAtIndex([in] UINT32 index,
                          [out, retval] ICoreWebView2ProcessExtendedInfo** processInfo);
}

/// This is the ICoreWebView2ProcessExtendedInfo interface
// MSOWNERS: wangsongjin@microsoft.com
[uuid(b120f7d0-1f6a-11ee-be56-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2ProcessExtendedInfo : IUnknown {
  /// The process info of the current process.
  [propget] HRESULT ProcessInfo(
    [out, retval] ICoreWebView2ProcessInfo** processInfo);

  /// The collection of associated `FrameInfo`s which are actively running
  /// (showing UI elements) in this renderer process. `AssociatedFrameInfos`
  /// will only be populated when this `CoreWebView2ProcessExtendedInfo`
  /// corresponds to a renderer process. Non-renderer processes will always
  /// have an empty `AssociatedFrameInfos`. The `AssociatedFrameInfos` may
  /// also be empty for renderer processes that have no active frames.
  ///
  /// \snippet ProcessComponent.cpp AssociatedFrameInfos
  [propget] HRESULT AssociatedFrameInfos(
    [out, retval] ICoreWebView2FrameInfoCollection** frames);
}

/// A continuation of the ICoreWebView2Environment13 interface.
[uuid(9d4d8624-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2Environment14 : ICoreWebView2Environment13 {
  /// Gets a snapshot collection of `ProcessInfo`s corresponding to all currently
  /// running processes associated with this `CoreWebView2Environment` except 
  /// for crashpad process. This provides the same list of `ProcessInfo`s as 
  /// what's provided in `GetProcessInfos`, but additionally provides a list of 
  /// associated `FrameInfo`s which are actively running (showing UI elements) 
  /// in the renderer process. See `AssociatedFrameInfos` for more information.
  /// 
  /// \snippet ProcessComponent.cpp GetProcessExtendedInfos
  HRESULT GetProcessExtendedInfos([in] ICoreWebView2GetProcessExtendedInfosCompletedHandler* handler);
}

/// A continuation of the ICoreWebView2FrameInfo interface.
[uuid(a7a7e150-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2FrameInfo2 : ICoreWebView2FrameInfo {
  /// This parent frame's `FrameInfo`. `ParentFrameInfo` will only be
  /// populated when obtained via calling 
  /// `CoreWebView2ProcessExtendedInfo.AssociatedFrameInfos`. 
  /// `CoreWebView2FrameInfo` objects obtained via `CoreWebView2.ProcessFailed` will
  /// always have a `null` `ParentFrameInfo`. This property is also `null` for the  
  /// main frame in the WebView2 which has no parent frame.
  /// Note that this `ParentFrameInfo` could be out of date as it's a snapshot.   
  [propget] HRESULT ParentFrameInfo([out, retval] ICoreWebView2FrameInfo** frameInfo);
  /// The unique identifier of the frame associated with the current `FrameInfo`.
  /// It's the same kind of ID as with the `FrameId` in `CoreWebView2` and via 
  /// `CoreWebView2Frame`. `FrameId` will only be populated (non-zero) when obtained
  /// calling `CoreWebView2ProcessExtendedInfo.AssociatedFrameInfos`. 
  /// `CoreWebView2FrameInfo` objects obtained via `CoreWebView2.ProcessFailed` will
  /// always have an invalid frame Id 0.
  /// Note that this `FrameId` could be out of date as it's a snapshot. 
  [propget] HRESULT FrameId([out, retval] UINT32* id);
  /// The frame kind of the frame. `FrameKind` will only be populated when
  /// obtained calling `CoreWebView2ProcessExtendedInfo.AssociatedFrameInfos`.
  /// `CoreWebView2FrameInfo` objects obtained via `CoreWebView2.ProcessFailed`
  /// will always have the default value `COREWEBVIEW2_FRAME_KIND_UNKNOWN`.
  /// Note that this `FrameKind` could be out of date as it's a snapshot.
  [propget] HRESULT FrameKind([out, retval] COREWEBVIEW2_FRAME_KIND* kind);
}

/// A continuation of the ICoreWebView2Frame4 interface.
[uuid(04baa798-a0e9-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2Frame5: ICoreWebView2Frame4 {
  /// The unique identifier of the current frame. It's the same kind of ID as with 
  /// the `FrameId` in `CoreWebView2` and via `CoreWebView2FrameInfo`.
  [propget] HRESULT FrameId([out, retval] UINT32* id);
}

/// A continuation of the ICoreWebView2_17 interface.
[uuid(ad712504-a66d-11ed-afa1-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2_18 : ICoreWebView2_17 {
  /// The unique identifier of the main frame. It's the same kind of ID as with 
  /// the `FrameId` in `CoreWebView2Frame` and via `CoreWebView2FrameInfo`.
  /// Note that `FrameId` may not be valid if `CoreWebView` has not done
  /// any navigation. It's safe to get this value during or after the first
  /// `ContentLoading` event. Otherwise, it could return the invalid frame Id 0.
  [propget] HRESULT FrameId([out, retval] UINT32* id);
}
```

C#
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core 
{
  enum CoreWebView2FrameKind
  {
    Unknown = 0,
    MainFrame = 1,
    Iframe = 2,
    Embed = 3,
    Object = 4,
  };

  runtimeclass CoreWebView2FrameInfo
  {
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2FrameInfo2")]
    {
        // ICoreWebView2FrameInfo2 members
        CoreWebView2FrameInfo ParentFrameInfo { get; };
        UInt32 FrameId { get; };
        CoreWebView2FrameKind FrameKind { get; };
    }
  }

  runtimeclass CoreWebView2Environment
  {
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment14")]
    {
        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ProcessExtendedInfo>> GetProcessExtendedInfosAsync();
    }
  }

  runtimeclass CoreWebView2ProcessExtendedInfo
  {
        // ICoreWebView2ProcessExtendedInfo members
        CoreWebView2ProcessInfo ProcessInfo { get; };
        IVectorView<CoreWebView2FrameInfo> AssociatedFrameInfos { get; };
  }

  runtimeclass CoreWebView2
  {
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_18")]
    {
        // ICoreWebView2_18 members
        UInt32 FrameId { get; };
    }
  }

  runtimeclass CoreWebView2Frame
  {
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Frame2")]
    {
        // ICoreWebView2Frame2 members
        UInt32 FrameId { get; };
    }
  }
}
```
