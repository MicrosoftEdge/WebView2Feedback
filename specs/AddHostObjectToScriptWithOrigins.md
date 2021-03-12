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
## FrameCreated/FrameDeleted and AddHostObjectToScriptWithOrigins

## .NET, WinRT
```c#
void SubscribeToFrameCreated()
{
    webView.CoreWebView2.FrameCreated += delegate (object sender, CoreWebView2FrameCreatedEventArgs args)
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
        Callback<ICoreWebView2FrameCreatedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2FrameCreatedEventArgs* args) -> HRESULT
    {
        wil::com_ptr<ICoreWebView2Frame> webviewFrame;
        CHECK_FAILURE(args->get_Frame(&webviewFrame));

        // Subscribe to frame deleted event
        webviewFrame->add_FrameDeleted(
        Callback<ICoreWebView2FrameDeletedEventHandler>(
            [this](ICoreWebView2* sender) -> HRESULT {
            /*Cleanup on frame deletion*/
        }).Get(), &m_frameDeletedToken));

        // Wrap host object
        VARIANT remoteObjectAsVariant = {};
        m_hostObject.query_to<IDispatch>(&remoteObjectAsVariant.pdispVal);
        remoteObjectAsVariant.vt = VT_DISPATCH;

        // Create list of origins which will be checked.
        // iframe will have access to host object only if its origin belongs
        // to this list.
        int originsCount = 1;
        LPCWSTR* originsList =
            reinterpret_cast<LPCWSTR*>(CoTaskMemAlloc(sizeof(LPCWSTR) * originsCount));
        originsList[0] = L"https://appassets.example";
        // Add host object to a script for iframe access
        CHECK_FAILURE(
            webviewFrame->AddHostObjectToScriptWithOrigins(
                L"sample", &remoteObjectAsVariant, originsList, originsCount));

        remoteObjectAsVariant.pdispVal->Release();
        CoTaskMemFree(originsList);

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
  /// Called when the iframe changes its window.name property
  HRESULT add_NameChanged(
      [in] ICoreWebView2FrameNameChangedEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_NameChanged.
  HRESULT remove_NameChanged([in] EventRegistrationToken token);

  /// Add the provided host object to script running in the iframe with the
  /// specified name for the list of the specified origins. The host object
  /// will be accessible for this iframe only if the iframe's origin during
  /// access matches one of the origins which are passed. Non-ASCII origins
  /// can be passed in Unicode or Punycode format. The IDN origins will be
  /// converted to Unicode and normalized before comparison. If the iframe is
  /// declared with no src attribute its origin is considered the same as
  /// the origin of the parent document.
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

  /// Called when an iframe is removed or the document containing that iframe
  /// is destroyed
  HRESULT add_FrameDeleted(
      [in] ICoreWebView2FrameDeletedEventHandler *eventHandler,
      [out] EventRegistrationToken * token);
  /// Remove an event handler previously added with add_FrameDeleted.
  HRESULT remove_FrameDeleted([in] EventRegistrationToken token);
}

[uuid(ae64d3bc-01ba-4769-a470-a1888de6d30b), object, pointer_default(unique)]
interface ICoreWebView2 : IUnknown {
  /// Called when a new iframe is created. Use add_FrameDeleted to listen for
  /// when this iframe goes away.
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
  /// Provides the result for the iframe name changed event
  HRESULT Invoke([in] ICoreWebView2Frame * sender,
                 [in] ICoreWebView2FrameNameChangedEventArgs * args);
}

[uuid(5586b928-ef41-43f7-b63c-8b33a52dd378), object, pointer_default(unique)]
interface ICoreWebView2FrameNameChangedEventArgs : IUnknown {
  /// The new name of the iframe.
  [propget] HRESULT Name([ out, retval ] LPWSTR * name);
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

        /// Called when the iframe changes its window.name property
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, CoreWebView2FrameNameChangedEventArgs> NameChanged;
        /// Called when an iframe is removed or the document containing that iframe
        /// is destroyed
        event Windows.Foundation.TypedEventHandler<CoreWebView2Frame, Object> FrameDeleted;

        /// Add the provided host object to script running in the iframe with the
        /// specified name for the list of the specified origins. The host object
        /// will be accessible for this iframe only if the iframe's origin during
        /// access matches one of the origins which are passed. Non-ASCII origins
        /// can be passed in Unicode or Punycode format. The IDN origins will be
        /// converted to Unicode and normalized before comparison. If the iframe is
        /// declared with no src attribute its origin is considered the same as
        /// the origin of the parent document.
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
        void AddHostObjectToScriptWithOrigins(String name, Object rawObject, String origins);
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
        /// Called when a new iframe is created. Use FrameDeleted event to listen for
        /// when this iframe goes away.
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2FrameCreatedEventArgs> FrameCreated;
    }
     runtimeclass CoreWebView2FrameNameChangedEventArgs
    {
        /// The new name of the iframe.
        String Name { get; };
    }
     runtimeclass CoreWebView2FrameCreatedEventArgs
    {
        /// The frame which was created.
        CoreWebView2Frame Frame { get; };
    }
}
```
