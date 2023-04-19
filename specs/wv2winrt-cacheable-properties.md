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
        // cacheable to improve runtime performance.
        [cacheable]
        String Model { get; };
        
        // ...
    }
```

# API Details

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    /// You can use the `cacheable` attribute on a runtimeclass property
    /// or runtimeclass method to indicate that the property value or
    /// method return value can be cached.
    ///
    /// You can apply it to an instance property if the property
    /// value doesn't change for the lifetime of its object instance.
    /// You can apply it to a static property if the property value
    /// doesn't change for the lifetime of the process.
    /// You can apply it to an instance method if when the method is called
    /// with the same parameters it always returns the same value for the
    /// lifetime of its object instance.
    /// You can apply it to a static method if when the method is called
    /// with the same parameters it always returns the same value for the
    /// lifetime of the process.
    ///
    /// When an object is projected into JavaScript via 
    /// `CoreWebView2.AddHostObjectToScript`, WebView2 will cache property values
    /// marked with this attribute. This can potentially improve performance by
    /// reducing the number of cross-process calls to obtain the latest value.
    [attributeusage(target_property, target_method)]
    [attributename("cacheable")]
    attribute CacheableAttribute
    {
    }
}
```

# Appendix

Names considered for the attribute:
 * **Cacheable**: A familiar term also used by python that more closely matches this feature.
 * **ReadOnly**: Similar to C#'s readonly keyword which indicates a value won't change (once
 initialized). But does not convey that the implementer cannot change the value.
 * **Immutable**: Similar to readonly
 * **Const**: Does a better job indicating that the value does not change even by the
 implementer.
 * **Memoizable**: A broader term than cacheable that also applies to methods but more specific
 than cacheable in that it better defines the kind of caching.

For the sample code, the only code you have to write is applying the attribute to the
property. The only effect this has is to potentially improve performance so there's no other
code to demonstrate anything. Accordingly, not sure what else to do in the sample code other
than the MIDL3.
