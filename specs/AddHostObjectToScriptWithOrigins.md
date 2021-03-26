# Background
Currently WebView2 supports adding host objects to script from client application
and then later those objects can be accessed from the JavaScript of the top level frame
using `window.chrome.webview.hostObjects.{name}`.
Documentation can be found [here](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.705.50#addhostobjecttoscript).

We were asked to support this feature in iframes including
child frames that don't match the origin of the parent. In this document we describe API
additions to support host objects in iframes. We'd appreciate your feedback.


# Description
The FrameCreated event is raised when an iframe is created and before starting any
navigation and content loading. The FrameDeleted event is raised when an iframe is deleted
or the document containing that iframe is destroyed.
By providing event handler for frame created event,
user can obtain the iframe and add host objects to it specifying the list of origins
using `AddHostObjectToScriptWithOrigins` method.
When script in the iframe tries to access a host object the origin of the iframe will be
checked against the provided list. The Frame object has a Name property with the value of the
name attribute from the iframe html tag declaring it. The NameChanged event is raised when
corresponding iframe changes its window.name property.

The host object will be removed during iframe deletion automatically.


# Examples
## Frame created event, frame name changed event, adding and removing host object

## .NET, WinRT
```c#
void SubscribeToFrameCreated()
{
    webView.CoreWebView2.FrameCreated += delegate (object sender, CoreWebView2FrameCreatedEventArgs args)
    {
        if (args.Frame.Name.Equals("iframe_name"))
        {
            String[] origins = new String[] { "https://appassets.example" };
            args.Frame.AddHostObjectToScriptWithOrigins("bridge", new BridgeAddRemoteObject(), origins);
        }
        args.Frame.NameChanged += delegate (object nameChangedSender, object nameChangedArgs)
        {
            CoreWebView2Frame frame = (CoreWebView2Frame)nameChangedSender;
            if (!frame.Name.Equals("iframe_name"))
            {
                frame.RemoveHostObjectFromScript("bridge");
            }
        };
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
        Callback<ICoreWebView2FrameCreatedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
    {
        wil::com_ptr<ICoreWebView2Frame> webviewFrame;
        CHECK_FAILURE(args->get_Frame(&webviewFrame));

        // Subscribe to frame name changed event and remove host object when name is changed
        webviewFrame->add_NameChanged(
        Callback<ICoreWebView2FrameNameChangedEventHandler>(
            [this](ICoreWebView2Frame* sender,
                IUnknown* args) -> HRESULT {
            LPWSTR newName;
            CHECK_FAILURE(sender->get_Name(&newName));
            if (std::wcscmp(newName, L"iframe_name") != 0)
            {
                sender->RemoveHostObjectFromScript(L"sample");
            }
            return S_OK;
        }).Get(), NULL);

        LPWSTR name;
        CHECK_FAILURE(webviewFrame->get_Name(&name));
        if (std::wcscmp(name, L"iframe_name") == 0)
        {
            // Wrap host object
            VARIANT remoteObjectAsVariant = {};
            m_hostObject.query_to<IDispatch>(&remoteObjectAsVariant.pdispVal);
            remoteObjectAsVariant.vt = VT_DISPATCH;

            // Create list of origins which will be checked.
            // iframe will have access to host object only if its origin belongs
            // to this list.
            LPCWSTR origin = L"https://appassets.example/";
            // Add host object to a script for iframe access
            CHECK_FAILURE(
                webviewFrame->AddHostObjectToScriptWithOrigins(
                    L"sample", &remoteObjectAsVariant, 1, &origin));

            remoteObjectAsVariant.pdispVal->Release();
        }

        return S_OK;
    }).Get(), &m_frameCreatedToken));
}
```

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## IDL
```c#
/// WebView2Frame provides direct access to the iframes information and use.
[uuid(18ae830b-8c83-459f-8a8c-95a1022af774), object, pointer_default(unique)]
interface ICoreWebView2Frame : IUnknown {
  /// The name of the iframe from the iframe html tag declaring it.
  /// Calling this method fails if it is called after the iframe is deleted.
  [propget] HRESULT Name([ out, retval ] LPWSTR * name);
  /// Raised when the iframe changes its window.name property
  HRESULT add_NameChanged(
      [in] ICoreWebView2FrameNameChangedEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_NameChanged.
  HRESULT remove_NameChanged([in] EventRegistrationToken token);

  /// Add the provided host object to script running in the iframe with the
  /// specified name for the list of the specified origins. The host object
  /// will be accessible for this iframe only if the iframe's origin during
  /// access matches one of the origins which are passed. The provided origins
  /// will be normalized before comparing to the origin of the document.
  /// So the scheme name is made lower case, the host will be punycode decoded
  /// as appropriate, default port values will be removed, and so on.
  /// This means the origin's host may be punycode encoded or not and will match
  /// regardless.
  /// If the iframe is declared with no src attribute its origin is considered
  /// the same as the origin of the parent document.
  /// List of origins will be treated as following:
  /// 1. empty list - call will fail and no host object will be added for the
  /// iframe;
  /// 2. list with origins - during access to host object from iframe the
  /// origin will be checked that it belongs to this list;
  /// 3. list with "*" element - host object will be available for iframe for
  /// all origins. We suggest not to use this feature without understanding
  /// security implications of giving access to host object from from iframes
  /// with unknown origins.
  /// Calling this method fails if it is called after the iframe is deleted.
  /// \snippet ScenarioAddHostObject.cpp AddHostObjectToScriptWithOrigins
  /// For more information about host objects navigate to [AddHostObjectToScript]
  HRESULT AddHostObjectToScriptWithOrigins(
      [in] LPCWSTR name,
      [in] VARIANT *object,
      [in] UINT32 originsCount,
      [in, size_is(originsCount)] LPCWSTR* origins);
  /// Remove the host object specified by the name so that it is no longer
  /// accessible from JavaScript code in the iframe. While new access
  /// attempts are denied, if the object is already obtained by JavaScript code
  /// in the iframe, the JavaScript code continues to have access to that
  /// object. Calling this method for a name that is already removed or was never
  /// added fails. If the iframe is deleted this method will return fail also.
  HRESULT RemoveHostObjectFromScript([in] LPCWSTR name);

  /// The FrameDeleted event is raised when the iframe corresponding to this CoreWebView2Frame
  /// object is removed or the document containing that iframe is destroyed
  HRESULT add_FrameDeleted(
      [in] ICoreWebView2FrameDeletedEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_FrameDeleted.
  HRESULT remove_FrameDeleted([in] EventRegistrationToken token);
}

[uuid(ae64d3bc-01ba-4769-a470-a1888de6d30b), object, pointer_default(unique)]
interface ICoreWebView2 : IUnknown {
  /// Raised when a new iframe is created. Use the CoreWebView2Frame.add_FrameDeleted
  /// to listen for when this iframe goes away.
  HRESULT add_FrameCreated(
      [in] ICoreWebView2FrameCreatedEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_FrameCreated.
  HRESULT remove_FrameCreated([in] EventRegistrationToken token);
}

[uuid(6c2d169c-7912-4332-a288-0aee1626759f), object, pointer_default(unique)]
interface ICoreWebView2FrameCreatedEventHandler: IUnknown {
  /// Provides the result for the iframe created event
  HRESULT Invoke([in] ICoreWebView2 * sender,
                 [in] ICoreWebView2FrameCreatedEventArgs *
                     args);
}

// Event args for the iframe created events.
[uuid(5fc1cd71-cd9a-4e8f-ab5f-2f134f941a3d), object, pointer_default(unique)]
interface ICoreWebView2FrameCreatedEventArgs : IUnknown {
  /// The frame which was created.
  [propget] HRESULT Frame([ out, retval ] ICoreWebView2Frame **frame);
}

[uuid(8a1860c1-528f-4286-823c-23b0439340d2), object, pointer_default(unique)]
interface ICoreWebView2FrameDeletedEventHandler: IUnknown {
  /// Provides the result for the iframe deleted event.
  /// No event args exist and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Frame * sender, [in] IUnknown * args);
}

[uuid(cfd00c6a-8889-47de-84b2-3016d44dbaf4), object, pointer_default(unique)]
interface ICoreWebView2FrameNameChangedEventHandler : IUnknown {
  /// Provides the result for the iframe name changed event.
  /// No event args exist and the `args` parameter is set to `null`.
  HRESULT Invoke([in] ICoreWebView2Frame * sender, [in] IUnknown * args);
}
```
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    /// CoreWebView2Frame provides direct access to the iframes information and use.
     runtimeclass CoreWebView2Frame
    {
        /// The name of the iframe from the iframe html tag declaring it.
        /// Calling this method fails if it is called after the iframe is deleted.
        String Name { get; };

        /// Raised when the iframe changes its window.name property
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, Object> NameChanged;
        /// The FrameDeleted event is raised when the iframe corresponding to this CoreWebView2Frame
        /// object is removed or the document containing that iframe is destroyed
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, Object> FrameDeleted;

        /// Add the provided host object to script running in the iframe with the
        /// specified name for the list of the specified origins. The host object
        /// will be accessible for this iframe only if the iframe's origin during
        /// access matches one of the origins which are passed. The provided origins
        /// will be normalized before comparing to the origin of the document.
        /// So the scheme name is made lower case, the host will be punycode decoded
        /// as appropriate, default port values will be removed, and so on.
        /// This means the origin's host may be punycode encoded or not and will match
        /// regardless.
        /// If the iframe is declared with no src attribute its origin is considered
        /// the same as the origin of the parent document.
        /// List of origins will be treated as following:
        /// 1. empty list - call will fail and no host object will be added for the
        /// iframe;
        /// 2. list with origins - during access to host object from iframe the
        /// origin will be checked that it belongs to this list;
        /// 3. list with "*" element - host object will be available for iframe for
        /// all origins. We suggest not to use this feature without understanding
        /// security implications of giving access to host object from from iframes
        /// with unknown origins.
        /// Calling this method fails if it is called after the iframe is deleted.
        /// \snippet ScenarioAddHostObject.cpp AddHostObjectToScriptWithOrigins
        /// For more information about host objects navigate to [AddHostObjectToScript]
        void AddHostObjectToScriptWithOrigins(String name, Object rawObject, String[] origins);
        /// Remove the host object specified by the name so that it is no longer
        /// accessible from JavaScript code in the iframe. While new access
        /// attempts are denied, if the object is already obtained by JavaScript code
        /// in the iframe, the JavaScript code continues to have access to that
        /// object. Calling this method for a name that is already removed or was never
        /// added fails. If the iframe is deleted this method will return fail also.
        void RemoveHostObjectFromScript(String name);
    }

     runtimeclass CoreWebView2
    {
        //..
        /// Raised when a new iframe is created. Use the CoreWebView2Frame.FrameDeleted event to
        /// listen for when this iframe goes away.
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2FrameCreatedEventArgs> FrameCreated;
    }
     runtimeclass CoreWebView2FrameCreatedEventArgs
    {
        /// The frame which was created.
        CoreWebView2Frame Frame { get; };
    }
}
```
