wv2winrt Cacheable Properties
===

# Background

WebView2 supports WinRT projection into JavaScript similar to how the previous edgehtml
WebView support WinRT projection. However unlike the previous WebView, for WebView2 the
WinRT objects live in a different process from the JavaScript that invokes the WinRT.
Because of this cross-process access, performance is something we're working on improving.
To that end, this feature allows you to mark individual runtimeclass properties as
cacheable so that the JavaScript running in the renderer process can cache the result of
the property value the first time and avoid subsequent cross-process calls each time the
property is accessed. Working with partner apps with existing JavaScript that uses WinRT
this was identified as something in particular that could help improve runtime
performance.

# Examples

```c# (but really MIDL3)
    [default_interface]
    runtimeclass Toaster
    {
        // This property changes value throughout the lifetime of the object so is not
        // marked readonly.
        Boolean Available { get; };

        // This property has one value for the lifetime of the object so we mark it
        // readonly to improve wv2winrt performance.
		    [corewebview2readonly]
        String Model { get; };
        
        // ...
    }
```

# API Details

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    /// You can use the CoreWebView2ReadOnly attribute on a runtimeclass property
    /// definition in MIDL3 if the property value doesn't change for the lifetime
    /// of its object. When an object is projected into JavaScript via 
    /// `CoreWebView2.AddHostObjectToScript`, WebView2 will cache property values
    /// marked with this attribute. This can potentially improve performance by
    /// reducing the number of cross-process calls to obtain the latest value of
    /// the property.
    [attributeusage(target_property)]
    [attributename("corewebview2readonly")]
    attribute CoreWebView2ReadOnlyAttribute
    {
    }
}
```

# Appendix

Names considered for the attribute:
 * **Cacheable**: Caching is what WebView2 will do with the property rather than describing
 an aspect of the runtimeclass property.
 * **ReadOnly**: Similar to C#'s readonly keyword which indicates a value won't change (once
 initialized). A more familiar term to end developers than 'immutable'. It does
 convey that the caller can't set it, but does it also convey that the implementer also
 cannot change the value?
 * **Immutable**: Perhaps more explicit than readonly that the implementer also cannot
 change the value, but perhaps less familiar of a term.

For the sample code, the only code you have to write is applying the attribute to the
property. The only effect this has is to potentially improve performance so there's no other
code to demonstrate anything. Accordingly, not sure what else to do in the sample code other
than the MIDL3.
