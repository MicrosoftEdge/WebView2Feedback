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
a host application to understand the overall performance impact(memory, CPU 
usage, etc.) of WebView2 on their application or the user's device, but it 
doesn't provide the granularity needed for the host application to know which 
part of WebView2 is consuming those resources.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
* We propose extending `CoreWebView2Environment` to include the 
`GetProcessInfosWithDetails` API. This asynchronous call returns a 
snapshot collection of `ProcessInfo`s corresponding to all currently
running processes associated with this `ICoreWebView2Environment` 
except for crashpad process. This provide the same list of `ProcessInfo`s
as what's provided in `GetProcessInfos`. Plus, this also provide the list
of associated `FrameInfo`s actively running(showing UI elements) in the 
renderer process.

* We propose to add the `AssociatedFrameInfo` API to provide a list of 
`FrameInfo`s actively running(showing UI elements) in the asscociated 
renderer process. 

* We propose extending `CoreWebView2` and `CoreWebView2Frame` to include 
the `FrameId` property. This property represents the unique identifier of
the frame running in this WebView2 or WebView2Frame.

* We propose extending `CoreWebView2FrameInfo` to include `FrameId` and 
`ParentFrameInfo` properties. `FrameId` is the same kind of ID as with 
`FrameID` in `CoreWebView2` and `CoreWebView2Frame`. `ParentFrameInfo` 
supports to retrive a frame's direct parent, ancestor first level frame 
and ancestor main frame. This also can be used to build the architecture 
of the frame tree with represent by `FrameInfo`. 

# Examples
C++
```c++
void AppendAncestorFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstring& result);
void AppendFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstring& result);
wil::com_ptr<ICoreWebView2FrameInfo> GetAncestorFirstLevelFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo);
wil::com_ptr<ICoreWebView2FrameInfo> GetAncestorMainFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo);

// Display renderer process info with details which includes the list of 
// associated frame infos for the renderer process. Also shows the process 
// info of other type of process.
void ProcessComponent::ShowRendererProcessFrameInfo()
{
    auto environment14 =
        m_webViewEnvironment.try_query<ICoreWebView2Environment14>();
    if (environment14)
    {
        //! [GetProcessInfosWithDetails]
        CHECK_FAILURE(environment14->GetProcessInfosWithDetails(
            Callback<ICoreWebView2GetProcessInfosWithDetailsCompletedHandler>(
                [this](HRESULT error, ICoreWebView2ProcessInfoCollection* processCollection)
                    -> HRESULT
                {
                    UINT32 processCount = 0;
                    UINT32 rendererProcessCount = 0;
                    CHECK_FAILURE(processCollection->get_Count(&processCount));
                    std::wstring result;
                    std::wstring otherProcessResult;
                    for (UINT32 i = 0; i < processCount; i++)
                    {
                        Microsoft::WRL::ComPtr<ICoreWebView2ProcessInfo> processInfo;
                        CHECK_FAILURE(processCollection->GetValueAtIndex(i, &processInfo));
                        COREWEBVIEW2_PROCESS_KIND kind;
                        CHECK_FAILURE(processInfo->get_Kind(&kind));
                        INT32 processId = 0;
                        CHECK_FAILURE(processInfo->get_ProcessId(&processId));
                        if (kind == COREWEBVIEW2_PROCESS_KIND_RENDERER)
                        {
                            //! [AssociatedFrameInfos]
                            std::wstring rendererProcessResult;
                            wil::com_ptr<ICoreWebView2ProcessInfo2> processInfo2;
                            CHECK_FAILURE(
                                processInfo->QueryInterface(IID_PPV_ARGS(&processInfo2)));
                            wil::com_ptr<ICoreWebView2FrameInfoCollection> frameInfoCollection;
                            CHECK_FAILURE(processInfo2->get_AssociatedFrameInfos(
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

                                AppendFrameInfo(frameInfo, rendererProcessResult);
                                AppendAncestorFrameInfo(frameInfo, rendererProcessResult);

                                BOOL hasNext = FALSE;
                                CHECK_FAILURE(iterator->MoveNext(&hasNext));
                                frameInfoCount++;
                            }
                            rendererProcessResult.insert(0, std::to_wstring(frameInfoCount) +
                                                L" frameInfo(s) found in Renderer Process ID:" +
                                                std::to_wstring(processId) + L"\n");
                            result.append(rendererProcessResult + L"\n");
                            rendererProcessCount++;
                            //! [AssociatedFrameInfos]
                        }
                        else
                        {
                            otherProcessResult.append(L"Process Id:" + std::to_wstring(processId) +
                                            L" | Process Kind:" + ProcessKindToString(kind) + L"\n");
                        }
                    }
                    result.insert(0, std::to_wstring(processCount) +
                               L" process(es) found, from which " +
                               std::to_wstring(rendererProcessCount) + 
                               L" renderer process(es) found\n\n");
                    otherProcessResult.insert(0, L"\nRemaining " +
                                           std::to_wstring(processCount - rendererProcessCount) +
                                           L" Process(es) Infos:\n");
                    result.append(otherProcessResult);
                    MessageBox(nullptr, result.c_str(), L"Process Info with Associated Frames", MB_OK);
                    return S_OK;
                })
                .Get()));
        //! [GetProcessInfosWithDetails]
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

// Get the ancestor first level frameInfo.
// Return itself if it's a first level frame.
wil::com_ptr<ICoreWebView2FrameInfo> ProcessComponent::GetAncestorFirstLevelFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo)
{
    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo;
    wil::com_ptr<ICoreWebView2FrameInfo> firstLevelFrameInfo;
    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    while (frameInfo)
    {
        firstLevelFrameInfo = mainFrameInfo;
        mainFrameInfo = frameInfo;
        CHECK_FAILURE(frameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_ParentFrameInfo(&frameInfo));
    }
    return firstLevelFrameInfo;
}

// Append the frameInfo's properties.
void ProcessComponent::AppendFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstring& result)
{
    if (!frameInfo)
    {
        return;
    }

    wil::unique_cotaskmem_string nameRaw;
    CHECK_FAILURE(frameInfo->get_Name(&nameRaw));
    result.append(L"{frame name:");
    result.append(nameRaw.get());

    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    CHECK_FAILURE(frameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
    UINT32 frameId = 0;
    frameInfo2->get_FrameId(&frameId);
    result.append(L" | frame Id:" + std::to_wstring(frameId));

    // Check if a frame is a main frame.
    BOOL isMainFrameOrFirstLevelframeInfo = false;
    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo = 
        GetAncestorMainFrameInfo(frameInfo);
    wil::com_ptr<ICoreWebView2FrameInfo> firstLevelFrameInfo =
        GetAncestorFirstLevelFrameInfo(frameInfo);
    if (mainFrameInfo == frameInfo)
    {
        result.append(L" | frame kind: main frame");
        isMainFrameOrFirstLevelframeInfo = true;
    }
    // Check if a frame is a first level frame.
    if (firstLevelFrameInfo == frameInfo)
    {
        result.append(L" | frame kind: first level frame");
        isMainFrameOrFirstLevelframeInfo = true;
    }
    if (!isMainFrameOrFirstLevelframeInfo)
    {
        result.append(L" | frame kind: other child frame");
    }
    // Append the frame's direct parent frame's ID if it exists.
    wil::com_ptr<ICoreWebView2FrameInfo> parentFrameInfo;
    CHECK_FAILURE(frameInfo2->get_ParentFrameInfo(&parentFrameInfo));
    if (parentFrameInfo)
    {
        CHECK_FAILURE(parentFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_FrameId(&frameId));
        result.append(L" \n | parent frame Id:" + std::to_wstring(frameId));
    }

    wil::unique_cotaskmem_string sourceRaw;
    CHECK_FAILURE(frameInfo->get_Source(&sourceRaw));
    result.append(L"\n | frame source:\n\"");
    result.append(sourceRaw.get());
    result.append(L"\"");
}

// Append the frameInfo's ancestor main frame(webview)'s ID and 
// ancestor first level frame's ID if it exists.
void ProcessComponent::AppendAncestorFrameInfo(
    wil::com_ptr<ICoreWebView2FrameInfo> frameInfo, std::wstring& result)
{
    if (frameInfo)
    {
        return;
    }

    wil::com_ptr<ICoreWebView2FrameInfo> mainFrameInfo = GetAncestorMainFrameInfo(frameInfo);
    wil::com_ptr<ICoreWebView2FrameInfo> firstLevelFrameInfo =
        GetAncestorFirstLevelFrameInfo(frameInfo);
    wil::com_ptr<ICoreWebView2FrameInfo2> frameInfo2;
    UINT32 frameId = 0;
    if (firstLevelFrameInfo)
    {
        CHECK_FAILURE(firstLevelFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_FrameId(&frameId));
        result.append(L"\n | ancestor first level frame Id:" + std::to_wstring(frameId));
    }
    if (mainFrameInfo)
    {
        CHECK_FAILURE(mainFrameInfo->QueryInterface(IID_PPV_ARGS(&frameInfo2)));
        CHECK_FAILURE(frameInfo2->get_FrameId(&frameId));
        result.append(L"\n | ancestor main frame Id:" + std::to_wstring(frameId));
    }
    result.append(L"},\n");
}
```
C#
```c#
string AppendFrameInfo(CoreWebView2FrameInfo frameInfo, string kind, string mainFrameId, string firstLevelFrameId) {
    string id = frameInfo.FrameId.ToString();
    string name = String.IsNullOrEmpty(frameInfo.Name) ? "none" : frameInfo.Name;
    string source = String.IsNullOrEmpty(frameInfo.Source) ? "none" : frameInfo.Source;
    string parentId = frameInfo.ParentFrameInfo == null ? "none" : frameInfo.ParentFrameInfo.FrameId.ToString();

    return $"{{frame Id:{id} " +
            $"| frame Name: {name} " +
            $"| frame Kind: {kind} " +
            $"| parent frame Id: {parentId} " +
            $"| ancestor main frame Id: {mainFrameId} " +
            $"| ancestor first level frame Id: {firstLevelFrameId} " +
            $"| frame Source: \"{source}\"}}\n";
}

// Display renderer process info with details which includes the list of 
// associated frame infos for the renderer process. Also shows the process 
// info of other type of process.
private async void ProcessFrameInfoCmdExecuted(object target, ExecutedRoutedEventArgs e)
{
    try
    {
        // <GetProcessInfosWithDetailsAsync>
        IReadOnlyList<CoreWebView2ProcessInfo> processList = await webView.CoreWebView2.Environment.GetProcessInfosWithDetailsAsync();
        int processListCount = processList.Count;
        string rendererProcessInfosStr = $"{processListCount} process(es) found in total\n\n";
        string otherProcessInfosStr = $"\nRemaining Process Infos:\n";
        int rendererProcessCount = 0;
        for (int i = 0; i < processListCount; ++i)
        {
            CoreWebView2ProcessKind kind = processList[i].Kind;
            int processId = processList[i].ProcessId;
            if (kind == CoreWebView2ProcessKind.Renderer)
            {
                int frameInfoCount = 0;
                string frameInfosStr = "";
                // <AssociatedFrameInfos>
                IReadOnlyList<CoreWebView2FrameInfo> frameInfoList = processList[i].AssociatedFrameInfos;
                foreach (CoreWebView2FrameInfo frameInfo in frameInfoList)
                {
                    string ancestorMainFrameId = "none";
                    string ancestorFirstLevelFrameId = "none";
                    CoreWebView2FrameInfo parentFrameInfo = frameInfo.ParentFrameInfo;
                    frameInfoCount++;
                    // If the frame has no parent, then it's a main frame.
                    if (parentFrameInfo == null)
                    {
                        ancestorMainFrameId = frameInfo.FrameId.ToString();
                        frameInfosStr += AppendFrameInfo(frameInfo, "main frame", ancestorMainFrameId, ancestorFirstLevelFrameId);
                        continue;
                    }

                    CoreWebView2FrameInfo mainFrameInfo = parentFrameInfo;
                    CoreWebView2FrameInfo firstLevelFrameInfo = frameInfo;
                    // If the frame's parent has no parent frame, then it's a first level frame.
                    if (mainFrameInfo.ParentFrameInfo == null) {
                        ancestorMainFrameId = mainFrameInfo.FrameId.ToString();
                        ancestorFirstLevelFrameId = firstLevelFrameInfo.FrameId.ToString();
                        frameInfosStr += AppendFrameInfo(frameInfo, "first level frame", ancestorMainFrameId, ancestorFirstLevelFrameId);
                        continue;
                    }
                    // For other child frames, we traverse the parent frame until find the ancestor main frame.
                    while (mainFrameInfo.ParentFrameInfo != null) {
                        firstLevelFrameInfo = mainFrameInfo;
                        mainFrameInfo = mainFrameInfo.ParentFrameInfo;
                    }

                    ancestorMainFrameId = mainFrameInfo.FrameId.ToString();
                    ancestorFirstLevelFrameId = firstLevelFrameInfo.FrameId.ToString();
                    frameInfosStr += AppendFrameInfo(frameInfo, "other frame", ancestorMainFrameId, ancestorFirstLevelFrameId);
                }
                // </AssociatedFrameInfos>
                string rendererProcessInfoStr = $"{frameInfoCount} frame info(s) found in renderer process ID: {processId}\n {frameInfosStr}";
                rendererProcessInfosStr += $"{rendererProcessInfoStr} \n";
                rendererProcessCount++;
            }
            else
            {
                otherProcessInfosStr += $"Process ID: {processId} | Process Kind: {kind}\n";
            }
        }
        // </GetProcessInfosWithDetailsAsync>
        string message = $"{rendererProcessCount} renderer process(es) found, {rendererProcessInfosStr + otherProcessInfosStr}";
        MessageBox.Show(this, message, "Process Info with Associated Frames");
    }
    catch (NotImplementedException exception)
    {
        MessageBox.Show(this, "GetProcessInfosWithDetailsAsync Failed: " + exception.Message,
            "Process Info with Associated Frames");
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
interface ICoreWebView2ProcessInfo2;
interface ICoreWebView2GetProcessInfosWithDetailsCompletedHandler;

/// Receives the result of the `GetProcessInfosWithDetails` method.
/// The result is written to the collection of `ProcessInfo`s provided
/// in the `GetProcessInfosWithDetails` method call.
[uuid(8e7d154c-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2GetProcessInfosWithDetailsCompletedHandler : IUnknown {
  HRESULT Invoke([in] HRESULT errorCode, [in] ICoreWebView2ProcessInfoCollection* value);
}

/// A continuation of the ICoreWebView2ProcessInfo interface.
[uuid(982ae768-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2ProcessInfo2 : ICoreWebView2ProcessInfo {
  /// The collection of associated `FrameInfo`s which are actively running
  /// (showing UI elements) in this renderer process. `AssociatedFrameInfos`
  /// will only be populated when obtained via calling 
  /// `CoreWebView2.GetProcessInfosWithDetails` and when this 
  /// `CoreWebView2ProcessInfo` corresponds to a renderer process.
  /// `CoreWebView2ProcessInfo` objects obtained via `CoreWebView2.GetProcessInfos`
  /// or for non-renderer processes will always have an empty `AssociatedFrameInfos`. 
  /// The `AssociatedFrameInfos` may also be be empty for renderer processes that 
  /// have no active frames.
  ///
  /// \snippet ProcessComponent.cpp AssociatedFrameInfos
  [propget] HRESULT AssociatedFrameInfos(
    [out, retval] ICoreWebView2FrameInfoCollection** frames);
}

/// A continuation of the ICoreWebView2Environment13 interface.
[uuid(9d4d8624-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2Environment14 : ICoreWebView2Environment13 {
  /// Gets a snapshot collection of `ProcessInfo`s corresponding to all currently
  /// running processes associated with this `ICoreWebView2Environment` except 
  /// for crashpad process. This provide the same list of `ProcessInfo`s as 
  /// what's provided in `GetProcessInfos`. Plus, this provide a list of associated
  /// `FrameInfo`s which are actively running (showing UI elements) in the renderer
  /// process. Check `AssociatedFrameInfos` for acquiring this detail infos.
  /// 
  /// \snippet ProcessComponent.cpp GetProcessInfosWithDetails
  HRESULT GetProcessInfosWithDetails([in] ICoreWebView2GetProcessInfosWithDetailsCompletedHandler* handler);
}

/// A continuation of the ICoreWebView2FrameInfo interface.
[uuid(a7a7e150-e2ca-11ed-b5ea-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2FrameInfo2 : ICoreWebView2FrameInfo {
  /// The parent `FrameInfo`. `ParentFrameInfo` will only be populated when obtained
  /// via calling `CoreWebView2ProcessInfo.AssociatedFrameInfos`. 
  /// `CoreWebView2FrameInfo` objects obtained via `CoreWebView2.ProcessFailed` will
  /// always have a `null` `ParentFrameInfo`. This property is also `null` for the  
  /// top most document in the WebView2 which has no parent frame.
  /// Note that this `ParentFrameInfo` could be out of date as it's a snapshot.   
  [propget] HRESULT ParentFrameInfo([out, retval] ICoreWebView2FrameInfo** frameInfo);
  /// The unique identifier of the frame associated with the current `FrameInfo`.
  /// It's the same kind of ID as with the `FrameId` in `ICoreWebView2` and via 
  /// `ICoreWebView2Frame`. `FrameId` will only be populated when obtained
  /// calling `CoreWebView2ProcessInfo.AssociatedFrameInfos`. 
  /// `CoreWebView2FrameInfo` objects obtained via `CoreWebView2.ProcessFailed` will
  /// always have an invalid frame Id 0.
  /// Note that this `FrameId` could be out of date as it's a snapshot. 
  [propget] HRESULT FrameId([out, retval] UINT32* id);
}

/// A continuation of the ICoreWebView2Frame4 interface.
[uuid(04baa798-a0e9-11ed-a8fc-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2Frame5: ICoreWebView2Frame4 {
  /// The unique identifier of the current frame.
  [propget] HRESULT FrameId([out, retval] UINT32* id);
}

/// A continuation of the ICoreWebView2_17 interface.
[uuid(ad712504-a66d-11ed-afa1-0242ac120002), object, pointer_default(unique)]
interface ICoreWebView2_18 : ICoreWebView2_17 {
  /// The unique identifier of the current frame.
  /// Note that `FrameId` is not valid if `ICoreWebView` has not done 
  /// any navigation. It returns an invalid frame Id 0.  
  [propget] HRESULT FrameId([out, retval] UINT32* id);
}
```

C#
```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core 
{
  runtimeclass CoreWebView2ProcessInfo
  {
      [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ProcessInfo2")]
      {
          IVectorView<CoreWebView2FrameInfo> AssociatedFrameInfos { get; };
      }
  }

  runtimeclass CoreWebView2FrameInfo
  {
      [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2FrameInfo2")]
      {
          CoreWebView2FrameInfo ParentFrameInfo { get; };
      }
  }

  runtimeclass CoreWebView2Environment
  {
    [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment14")]
    {
        Windows.Foundation.IAsyncOperation<IVectorView<CoreWebView2ProcessInfo>> GetProcessInfosWithDetailsAsync();
    }
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
