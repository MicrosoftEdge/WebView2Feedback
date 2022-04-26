# Background
Some developers may want to specify the path of `WebView2Loader.dll`. So we add a static property in CoreWebView2Environment to enable it.

# Description
We add new `LoaderDllFolderPath` properties in `CoreWebView2Environment`.
The APIs allow end developers to specify the folder's path where the `WebView2Loader.dll` is exited.

# Examples
## C#
```c#
Task<CoreWebView2Environment> CreateEnvironmentAsync()
{
    CoreWebView2Environment.LoaderDllFolderPath = ".";
    return CoreWebView2Environment.CreateAsync();
}
```

# Remarks
The path can be relative or absolute.
If LoaderDllFolderPath is set and the `WebView2Loader.dll` is not exit or an invalid file, a `DllNotFoundException` exception will be throwed.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Environment
    {
        // ...
        public static string LoaderDllFolderPath { get; set; }
    }
}
```
