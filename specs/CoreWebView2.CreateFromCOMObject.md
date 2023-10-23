CoreWebView2.CreateFromComObject
===

# Background
The new [Unity WebView2](https://learn.microsoft.com/en-us/windows/mixed-reality/develop/
advanced-concepts/webview2-unity-plugin) control creates and uses C++ COM to create and manage the
ICoreWebView2* objects. However, Unity developers are often interacting with the Unity WebView2
control using C#/.NET. The Unity WebView2 control doesn't expose the CoreWebView2 directly to devs
using the Unity WebView2 control, so when devs want to call an API on CoreWebView2, they
have to rely on that API being exposed on the Unity WebView2 control, which then internally calls 
into CoreWebView2. This is in contrast to our other controls (like WPF WebView2 and Winforms
WebView2 controls) which directly give access to their [CoreWebView2 object]
(https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.winforms.webview2.
corewebview2?view=webview2-dotnet-1.0.2088.41), allowing devs to call any API that exists or gets
added to the CoreWebView2/ICoreWebView2_*. The Unity WebView2 control can't do this today,
as they are unable to create a CoreWebView2 object that wraps an already existing COM object.
To help implement this for Unity, we are adding a new static factory function on CoreWebView2 .NET
class that will allow it to wrap an existing ICoreWebView2 COM object, instead of creating a new
one underlying ICoreWebView2.

# Examples
## CoreWebView2.CreateFromComObject
```c#
public class MyWebView2Control
{
  ... // Regular control code

  CoreWebView2 _myCoreWebView2 = null;

  [DllImport(DLL_NAME, CallingConvention = CallingConvention.StdCall)]
  public static extern ComNativePointer GetNativePointer(WebViewInstancePtr instanceId);

  // This is the CoreWebView2 property which allows developers to access CoreWebView2 APIs directly.
  public CoreWebView2 CoreWebView2
  {
    get
    {
      if (!_myCoreWebView2)
      {
        IntPtr comPtr = WebViewNative.GetNativePointer(InstanceId);

        _myCoreWebView2 = CoreWebView2.CreateFromComObject(comPtr);
      }
      return _myCoreWebView2;
    }
  }

}
```


# API Details
```c#
namespace Microsoft.Web.WebView2.Core
{
  public class CoreWebView2
  {
    /// <summary>
    /// Creates a CoreWebView2 object that wraps an existing COM ICoreWebView2 object.
    /// This allows interacting with the WebView2 control using .NET,
    /// even if the control was originally created using COM.
    /// </summary>
    /// <param name="value">Pointer to a COM object that implements the ICoreWebView2 COM interface.</param>
    /// <returns>Returns a .NET CoreWebView2 object that wraps the COM object.</returns>
    /// <exception cref="ArgumentNullException">Thrown when the provided COM pointer is null.</exception>
    /// <exception cref="InvalidComObjectException">Thrown when the value is not an ICoreWebView2 COM object and cannot be wrapped.</exception>
    public static CoreWebView2 CreateFromComObject(IntPtr value);
  }
}
```

# Appendix
We have a couple of other options to accomplish this, including moving the "CreateFromComOBject" function to the
CoreWebView2Controller class instead. CoreWebView2Controller could then be used to get the CoreWebView2 through
it's CoreWebView2 property which already exists. Or we could expose a new constructor on CoreWebView2/CoreWebView2Controller,
instead of a factory method.

We decided on using the CoreWebView2 due to it being the class most likely to be exposed and used
in .NET, and which is the same across different C# frameworks.
We decided on a factory method to not give the impression that a new constructor is the default 
one (we don't currently have any public constructors), and to make the intent and usage of
the method more obvious.
