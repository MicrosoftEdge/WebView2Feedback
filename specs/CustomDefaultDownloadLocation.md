Custom Default Download Location
===

# Background
This API allows you to set a custom default download location per profile. The
user can still change the path through the Save As dialog.

In this document we describe the updated API. We'd appreciate your feedback.

# Examples
```cpp
HRESULT AppWindow::OnCreateCoreWebView2ControllerCompleted(
    HRESULT result, ICoreWebView2Controller* controller)
{
    if (result == S_OK)
    {
        if (!m_webviewOption.downloadPath.empty())
        {
            Microsoft::WRL::ComPtr<ICoreWebView2Profile2> profile2;
            CHECK_FAILURE(m_profile->QueryInterface(IID_PPV_ARGS(
                &profile2)));
            CHECK_FAILURE(profile2->put_DefaultDownloadFolderPath(
                m_webviewOption.downloadPath.c_str()));
        }
    }
}
```
```c#
void SetDefaultDownloadPathCmdExecuted(object target,
    ExecutedRoutedEventArgs e)
{
    var dialog = new TextInputDialog(
        title: "Set Default Download Folder Path",
        description: "Enter the new default download folder path.",
        defaultInput: WebViewProfile.DefaultDownloadFolderPath);
    if (dialog.ShowDialog() == true)
    {
        WebViewProfile.DefaultDownloadFolderPath = dialog.Input.Text;
    }
}
```
# API Details
```c#
/// This is a continuation of the `ICoreWebView2Profile` interface.
[uuid(DAF8B1F9-276D-410C-B481-58CBADF85C9C), object, pointer_default(unique)]
interface ICoreWebView2Profile2 : ICoreWebView2Profile {
  /// Gets the `DefaultDownloadFolderPath` property. The default value is the
  /// system default download folder path for the user.
  [propget] HRESULT DefaultDownloadFolderPath([out, retval] LPWSTR* value);

  /// Sets the `DefaultDownloadFolderPath` property. The value should be
  /// an absolute path to a folder that the user and application can write to.
  /// Returns `E_INVALIDARG` if the value is invalid, and the default download
  /// folder path is not changed. Otherwise the path is changed immediately. If
  /// the directory does not yet exist, it is created at the time of the next
  /// download. If the host application does not have permission to create the
  /// directory, then the user is prompted to provide a new path through the
  /// Save As dialog. This value is persisted in the user data folder across
  /// sessions and can be changed by the user through the Save As dialog.
  [propput] HRESULT DefaultDownloadFolderPath([in] LPCWSTR value);
}
```
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Profile
    {
        // The following properties already exist.
        // String ProfileName { get; };
        // Boolean IsInPrivateModeEnabled { get; };
        // String ProfilePath { get; };

        // The following method already exists.
        // Windows.Foundation.IAsyncOperation<Boolean> ClearBrowsingDataAsync(
        //     UInt64 dataKinds, Double startTime, Double endTime);

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2Profile2")]
        {
            String DefaultDownloadFolderPath { get; set; };
        }
    }
}
```
