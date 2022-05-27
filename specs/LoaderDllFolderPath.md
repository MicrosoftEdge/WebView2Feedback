# Background
The WebView2 loader code is what knows where to find and start or connect to already running WebView2 runtimes. This can either be statically linked for C based projects, or is also available as a standalone DLL. For .NET projects they must use the DLL since the loader code is native and we don't have a way to merge the native code into a managed module. Before this change the .NET WebView2 API module would look for the WebView2Loader.dll in the its same folder. But some .NET projects have requirements about where they can place DLLs and so this property is introduced to allow end developers to place the WebView2Loader.dll in any folder and specify the path of 'WebView2Loader.dll' explicitly.
So we add an API to enable them to specify the path, so that they can use 'WebView2Loader.dll' from any path.

# Description
We add new static `SetLoaderDllFolderPath` function in `CoreWebView2Environment` class.
The function allow the end developers to specify the folder's path containing `WebView2Loader.dll`.

# Examples
## C#
``` c#
// Use default path
Task<CoreWebView2Environment> CreateEnvironmentAsync()
{
    // To use default path, just do not call SetLoaderDllFolderPath function or give a empty string:CoreWebView2Environment.SetLoaderDllFolderPath("") will use the default path;
    // The default search path logic is the same as loadlibrary
    return CoreWebView2Environment.CreateAsync();
}

// Specify a absolute path
Task<CoreWebView2Environment> CreateEnvironmentAsync()
{
    // Specify a absolute path 'D:\\folder', and there should be a 'WebView2Loader.dll' file in the folder.
    CoreWebView2Environment.SetLoaderDllFolderPath("D:\\folder");
    return CoreWebView2Environment.CreateAsync();
}

// Specify a relative path
Task<CoreWebView2Environment> CreateEnvironmentAsync()
{
    // Specify a relative path 'sub/sub'. The absolute folder path is '%Microsoft.Web.WebView2.Core.dll%\sub\sub', and there should be a 'WebView2Loader.dll' file in the folder.
    CoreWebView2Environment.SetLoaderDllFolderPath("sub\\sub");
    return CoreWebView2Environment.CreateAsync();
}
```

# Remarks
This function allows you to set the path of the folder containing the `WebView2Loader.dll`. This should be the path of a folder containing `WebView2Loader.dll` and not a path to the `WebView2Loader.dll` file itself.
Note that the WebView2 SDK contains multiple `WebView2Loader.dll` files for different CPU architectures. When specifying folder path, you must specify one containing a `WebView2Loader.dll` module with a CPU architecture matching the current process CPU architecture.
This function is used to load the `WebView2Loader.dll` module during calls to any other static methods on `CoreWebView2Environment`. So, the path should be specified before any other API is called in `CoreWebView2Environment` class. Once `WebView2Loader.dll` is successfully loaded this function will throw an InvalidOperationException exception.
The path can be relative or absolute. Relative paths are relative to the path of the `Microsoft.Web.WebView2.Core.dll` module.
If the `WebView2Loader.dll` file does not exist in that path or LoadLibrary cannot load the file, or LoadLibrary fails for any other reason, an exception corresponding to the LoadLibrary failure is thrown when any other API is called in `CoreWebView2Environment` class. For instance, if the file cannot be found a `DllNotFoundException` exception will be thrown.

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    /// <summary>
    /// Set the path of the folder containing the `WebView2Loader.dll`.
    /// </summary>
    /// <param name="folderPath">The path of the folder containing the `WebView2Loader.dll`.</param>
    /// <exception cref="InvalidOperationException">
    /// Thrown when `WebView2Loader.dll` has been successfully loaded.
    /// </exception>
    /// <remarks>
    /// This function allows you to set the path of the folder containing the `WebView2Loader.dll`. This should be the path of a folder containing `WebView2Loader.dll` and not a path to the `WebView2Loader.dll` file itself.
    /// Note that the WebView2 SDK contains multiple `WebView2Loader.dll` files for different CPU architectures. When specifying folder path, you must specify one containing a `WebView2Loader.dll` module with a CPU architecture matching the current process CPU architecture.
    /// This function is used to load the `WebView2Loader.dll` module during calls to any other static methods on `CoreWebView2Environment`. So, the path should be specified before any other API is called in `CoreWebView2Environment` class. Once `WebView2Loader.dll` is successfully loaded this function will throw an InvalidOperationException exception.
    /// The path can be relative or absolute. Relative paths are relative to the path of the `Microsoft.Web.WebView2.Core.dll` module.
    /// If the `WebView2Loader.dll` file does not exist in that path or LoadLibrary cannot load the file, or LoadLibrary fails for any other reason, an exception corresponding to the LoadLibrary failure is thrown when any other API is called in `CoreWebView2Environment` class. For instance, if the file cannot be found a `DllNotFoundException` exception will be thrown.
    /// </remarks>
    public static void SetLoaderDllFolderPath(string folderPath);
}
```
