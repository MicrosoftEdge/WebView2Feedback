# Background
Currently WebView2 supports adding host objects to script from client application
and then later those objects can be accessed from main JavaScript frame using
`window.chrome.webview.hostObjects.{name}`.
Documentation can be found [here](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#addhostobjecttoscript).

We were asked to support this feature in iframes including
cross-domain ones. In this document we describe the extension of API to support
host objects in iframes. We'd appreciate your feedback.


# Description
FrameCreated event is triggered when iframe is created and before starting any
navigation and content loading. FrameDeleted is called when iframe is deleted
or its hosting process has died. By providing event handler for frame created event,
user can obtain the iframe and add host objects to it specifying the list of origins
using `AddHostObjectToScriptWithOrigins` method.
When iframe will try to access the host object its origin will be checked agaist
the provided list. The iframe object will have a properties with the name from
the iframe html tag declaring it and unique id.

The host object will be removed during iframe deletion automatically.


# Examples
## FrameCreated and AddHostObjectToScriptWithOrigins

## .NET, WinRT
```c#
void SubscribeToFrameCreated()
{
    webView.CoreWebView2.FrameCreated += delegate (object sender, CoreWebView2FrameEventArgs args)
    {
        try
        {
            List<string> origins = new List<string>(new string[] { "https://appassets.example" });
            args.Frame.AddHostObjectToScriptWithOrigins("bridge", new BridgeAddRemoteObject(), origins);
        }
        catch (NotSupportedException exception)
        {
            MessageBox.Show("Frame.AddHostObjectToScriptWithOrigins failed: " + exception.Message);
        }
    };
}
```

## Win32 C++
```cpp
void SampleClass::SampleMethod()
{
    // Register a handler for the FrameCreated event.
    // This handler can be used to add host objects to the created iframe.
    CHECK_FAILURE(m_webView->add_FrameCreated(
        Callback<ICoreWebView2FrameEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2FrameEventArgs* args) -> HRESULT
    {
        wil::com_ptr<ICoreWebView2Frame> webviewFrame;
        CHECK_FAILURE(args->get_Frame(&webviewFrame));

        // Wrap host object
        VARIANT remoteObjectAsVariant = {};
        m_hostObject.query_to<IDispatch>(&remoteObjectAsVariant.pdispVal);
        remoteObjectAsVariant.vt = VT_DISPATCH;

        // Create list of origins which will be checked.
        // iframe will have access to host object only if its origin belongs
        // to this list.
        LONG i = 0;
        SAFEARRAY* list = SafeArrayCreateVector(VT_BSTR, 0, 1);
        BSTR origin = SysAllocString(L"https://appassets.example");
        SafeArrayPutElement(list, &i, origin);

        VARIANT originList = {};
        originList.parray = list;
        originList.vt = VT_ARRAY;

        // Add host object to a script for iframe access
        CHECK_FAILURE(
            webviewFrame->AddHostObjectToScriptWithOrigins(
                L"sample", &remoteObjectAsVariant, &originList));

        remoteObjectAsVariant.pdispVal->Release();
        SysFreeString(origin);
        SafeArrayDestroy(list);

        return S_OK;
    }).Get(), &m_frameCreatedToken));
}
```


# Remarks
List of origins in AddHostObjectToScript will be treated as following:
 - empty list - no host object will be added for the iframe;
 - list with origins - during access to host object from iframe the origin will be
 checked that it belongs to this list;
 - list with "*" element - host object will be available for iframe for all origins.
 We suggest not to use this feature without understanding security implications of
 giving access to host object from from iframes with unknown origins.


# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## IDL
```c#
/// WebView2Frame provides direct access to the iframes information and use.
[uuid(18ae830b-8c83-459f-8a8c-95a1022af774), object, pointer_default(unique)]
interface ICoreWebView2Frame : IUnknown {
  /// The name of the iframe from the iframe html tag declaring it.
  [propget] HRESULT Name([ out, retval ] LPWSTR * name);
  /// Unique frame identifier.
  [propget] HRESULT Id([ out, retval ] INT32* frameId);
  /// Add the provided host object to script running in the WebView2 with the
  /// specified name for the list of the specified origins. The host object
  /// will be accessible for this iframe only if the iframe's origin during access
  /// matches one of the origins which are passed.
  /// \snippet ScenarioAddHostObject.cpp AddHostObjectToScriptWithOrigins
  /// For more information about host objects navigate to [AddHostObjectToScript]
  HRESULT AddHostObjectToScriptWithOrigins(
      [in] LPCWSTR name,
      [in] VARIANT *object,
      [in] VARIANT *origins);
}

[uuid(ae64d3bc-01ba-4769-a470-a1888de6d30b), object, pointer_default(unique)]
interface ICoreWebView2 : IUnknown {
  /// Called when a new iframe is created. Use add_FrameDeleted to listen for
  /// when this iframe goes away.
  HRESULT add_FrameCreated(
      [in] ICoreWebView2FrameEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_FrameCreated.
  HRESULT remove_FrameCreated([in] EventRegistrationToken token);

  /// Called when iframe is deleted or its hosting process has died.
  HRESULT add_FrameDeleted(
      [in] ICoreWebView2FrameEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_FrameDeleted.
  HRESULT remove_FrameDeleted([in] EventRegistrationToken token);
}

[uuid(6c2d169c-7912-4332-a288-0aee1626759f), object, pointer_default(unique)]
interface ICoreWebView2FrameEventHandler: IUnknown {
  /// Provides the result for the iframe events
  HRESULT Invoke([in] ICoreWebView2 * sender,
                 [in] ICoreWebView2FrameEventArgs *
                     args);
}

// Event args for the iframe events.
[uuid(5fc1cd71-cd9a-4e8f-ab5f-2f134f941a3d), object, pointer_default(unique)]
interface ICoreWebView2FrameEventArgs : IUnknown {
  /// The frame which was impacted by iframe event
  [propget] HRESULT Frame([ out, retval ] ICoreWebView2Frame **frame);
}
```
