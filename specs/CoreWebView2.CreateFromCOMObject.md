CoreWebView2.CreateFromComICoreWebView2
===

# Background
The new [Unity WebView2](https://learn.microsoft.com/windows/mixed-reality/develop/advanced-concepts/webview2-unity-plugin) 
control creates and uses C++ COM to create and manage the
ICoreWebView2* objects. However, Unity developers are often interacting with the Unity WebView2
control using C#/.NET. The Unity WebView2 control doesn't expose the CoreWebView2 directly to devs
using the Unity WebView2 control, so when devs want to call an API on CoreWebView2, they
have to rely on that API being exposed on the Unity WebView2 control, which then internally calls 
into CoreWebView2. This is in contrast to our other controls (like WPF WebView2 and Winforms
WebView2 controls) which directly give access to their [CoreWebView2 object](https://learn.microsoft.com/dotnet/api/microsoft.web.webview2.winforms.webview2.corewebview2?view=webview2-dotnet-1.0.2088.41),
allowing devs to call any API that exists or gets
added to the CoreWebView2/ICoreWebView2_*. The Unity WebView2 control can't do this today,
as they are unable to create a CoreWebView2 object that wraps an already existing COM object.
To help implement this for Unity, we are adding a new static factory function on CoreWebView2 .NET
class that will allow it to wrap an existing ICoreWebView2 COM object, instead of creating a new
one.

To round out the more general scenario of interoperating between libraries written in different
languages, we add the ability to convert a CoreWebView2 to and from .NET and COM, as well as
to and from WinRT and COM.

# Examples

## COM to .NET

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

        _myCoreWebView2 = CoreWebView2.CreateFromComICoreWebView2(comPtr);
      }
      return _myCoreWebView2;
    }
  }

}
```

## WinRT to COM

```c++
winrt::com_ptr<ICoreWebView2> GetComICoreWebView2FromCoreWebView2(
    winrt::Microsoft::Web::WebView2::Core::CoreWebView2 coreWebView2WinRT)
{
    // Get the COM interop interface from the WinRT CoreWebView2.
    auto interop = coreWebView2WinRT.as<ICoreWebView2Interop2>();

    // Get the COM ICoreWebView2 object from the COM interop interface.
    winrt::com_ptr<ICoreWebView2> coreWebView2Com;
    winrt::check_hresult(interop->GetComICoreWebView2(coreWebView2Com.put()));
	
	return coreWebView2Com;
}
```

## COM to WinRT

```c++
winrt::Microsoft::Web::WebView2::Core::CoreWebView2 CreateCoreWebView2FromComICoreWebView2(
    winrt::com_ptr<ICoreWebView2> coreWebView2Com)
{
    auto factory = winrt::get_activation_factory<
        winrt::Microsoft::Web::WebView2::Core::CoreWebView2>();
	
    // Get the COM interop interface from the WinRT factory.
    auto interop = factory.try_as<ICoreWebView2ActivationFactoryInterop>();

    // Get the WinRT CoreWebView2 object from the COM interop interface as
    // its ABI interface.
    winrt::com_ptr<IUnknown> coreWebView2WinRTAsIUnknown;
    winrt::check_hresult(interop->CreateFromComICoreWebView2(
        coreWebView2Com.get(), coreWebView2WinRTAsIUnknown.put()));

    // Convert from the WinRT CoreWebView2 object API interface to C++/WinRT type
    return coreWebView2WinRTAsIUnknown.as<
        winrt::Microsoft::Web::WebView2::Core::CoreWebView2>();
}
```


# API Details

## .NET API

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
    public static CoreWebView2 CreateFromComICoreWebView2(IntPtr value);

    /// <summary>
    /// Returns the existing COM ICoreWebView2 object underlying this .NET CoreWebView2 object.
    /// This allows interacting with the WebView2 control using COM APIs,
    /// even if the control was originally created using .NET.
    /// </summary>
    /// <returns>Pointer to a COM object that implements the ICoreWebView2 COM interface.</returns>
    public IntPtr GetComICoreWebView2();
  }
}
```

## WinRT COM Interop API

```c# (but really COM IDL)
/// Interop interface for the CoreWebView2 WinRT object to allow WinRT end
/// developers to be able to use COM interfaces as parameters for some methods.
/// This interface is implemented by the Microsoft.Web.WebView2.Core.CoreWebView2
/// runtime class.
[uuid(B151AD7C-CFB0-4ECF-B9B2-AFCA868581A6), object, pointer_default(unique)]
interface ICoreWebView2Interop2 : IUnknown {
  /// Get a COM ICoreWebView2 interface corresponding to this WinRT CoreWebView2
  /// object.
  HRESULT GetComICoreWebView2([out, retval] ICoreWebView2** coreWebView2);
}

/// Interop interface for the CoreWebView2 WinRT activation factory object to allow
/// WinRT end developers to be able to use COM interfaces as parameters for some
/// methods.
/// This interface is implemented by the Microsoft.Web.WebView2.Core.CoreWebView2
/// activation factory runtime class.
[uuid(BABBED43-D40E-40CF-B106-8ED65FAE2E7C), object, pointer_default(unique)]
interface ICoreWebView2ActivationFactoryInterop : IUnknown {
  /// Creates a CoreWebView2 WinRT object that wraps an existing COM ICoreWebView2 object.
  /// This allows interacting with the WebView2 control using WinRT,
  /// even if the control was originally created using COM.
  HRESULT CreateFromComICoreWebView2([in] ICoreWebView2* coreWebView2Com,
                                     [out, retval] IUnknown** coreWebView2WinRt);
}

```

# Appendix
We have a couple of other options to accomplish this, including moving the "CreateFromComICoreWebView2" function to the
CoreWebView2Controller class instead. CoreWebView2Controller could then be used to get the CoreWebView2 through
its CoreWebView2 property which already exists. Or we could expose a new constructor on CoreWebView2/CoreWebView2Controller,
instead of a factory method.

We decided on using the CoreWebView2 due to it being the class most likely to be exposed and used
in .NET, and which is the same across different C# frameworks.
We decided on a factory method to not give the impression that a new constructor is the default 
one (we don't currently have any public constructors), and to make the intent and usage of
the method more obvious.
