
Title
===
UserDataFolder API 

# Background
You may have a need to cleanup or possibly add to the data being
stored in the WebView2 user data directory.  This directory can be either 
configured by you during creation of the webview2 control or calculated
at runtime by the control if it wasn't set during creation.

The current WebView2 code is designed to use a the directory that the hosting 
application is running in as the default location.  This has resulted in issues 
if running from a folder for which the WebView2 process doesn't have write access 
such as a Program Files folder.  Work is in progress to change that default and 
will be forthcoming in later changes.

With the current guidance it is possible for you to have built
logic into your application with an assumption where the User Data is 
located.  WebView2 changing that default can then result in a code error or 
possible crash.

This api will provide you a way to get the directory that is 
currently being used by the WebView for storage of the user data.

Using this returned directory is safer for the long run so that if WebView2 
changes the underlying path default logic the application will be able to adapt 
automatically.

# Description

Returns the user data folder that all CoreWebView2's created from this 
environment are using.
This could be either the value passed in by you when creating the 
environment object or the calculated one for default handling.  It will
always be an absolute path.


# Examples

```cpp
HRESULT UserDataFolder()
{
    // get the current user data folder from the webview environment object
        wil::unique_cotaskmem_string userDataFolder;
        m_webViewEnvironment->get_UserDataFolder(&userDataFolder);

    // using the folder
    WriteAppLog(userDataFolder.get(), "Logging information");
}```

```c#

    /// Webview creation and setup of completion handler are out of scope of sample
    void WebView_CoreWebView2InitializationCompleted(object sender, CoreWebView2InitializationCompletedEventArgs e)
    {
        if (e.IsSuccess)
        {
            // Get the current user data folder
            String userDataFolder = webView.CoreWebView2.Environment->UserDataFolder();

            // using the folder
            WriteAppLog(userDataFolder, "Logging information");
        }
    }

```

# API Details
```c# (but really MIDL3)
/// This interface is an extension of the ICoreWebView2Environment. An object
/// implementing the ICoreWebView2Environment6 interface will also
/// implement ICoreWebView2Environment.
[
  uuid(083CB0D7-E464-4108-807E-80AE4EAA3B28), object,
  pointer_default(unique)
] interface ICoreWebView2Environment6 : ICoreWebView2Environment5  {
  /// Returns the user data folder that all CoreWebView2's created from this 
  /// environment are using.
  /// This could be either the value passed in by the developer when creating the 
  /// environment object or the calculated one for default handling.  And will
  /// always be an absolute path.
  ///
  /// \snippet AppWindow.cpp GetUserDataFolder

  [propget] HRESULT UserDataFolder([ out, retval ] LPWSTR * value);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Environment6")]
        {
            // ICoreWebView2ExperimentalEnvironment5 members
            String UserDataFolder { get; };
        }
    }
}
```