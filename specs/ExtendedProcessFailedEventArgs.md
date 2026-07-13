
Code integrity failure source module path
===

# Background
[Windows Code Integrity](https://learn.microsoft.com/en-us/mem/intune/user-help/you-need-to-enable-code-integrity) is a feature that verifies the
integrity of the code that runs on the system. It helps protect it from malware,
tampering, and unauthorized changes. Code integrity checks the digital
signatures of the files that are loaded into memory, and prevents any
file that does not have a valid signature from running in WebView2 process.
We are extending ProcessFailedEventArgs with FailureSourceModulePath property
which caused webview2 process to exit with code STATUS_INVALID_IMAGE_HASH.

# Examples

    ```c#
        /// This is an event handler for our CoreWebView2's ProcessFailedEvent
        private void CoreWebView2_ProcessFailed(object sender, CoreWebView2ProcessFailedEventArgs e)
        {
            if (e.ExitCode == -1073740760 /*STATUS_INVALID_IMAGE_HASH*/)
            {
                // If the process crashed because of STATUS_INVALID_IMAGE_HASH,
                // then we want to log to our app's telemetry the name of the
                // DLL that caused the issue.
                SendTelemetry(e.FailureSourceModulePath);
            }
        }
    ```

    ```cpp
    CHECK_FAILURE(m_webView->add_ProcessFailed(
        Callback<ICoreWebView2ProcessFailedEventHandler>(
            [this](ICoreWebView2* sender, ICoreWebView2ProcessFailedEventArgs* argsRaw)
                -> HRESULT {
                wil::com_ptr<ICoreWebView2ProcessFailedEventArgs> args = argsRaw;
                int exit_code;
                CHECK_FAILURE(args->get_ExitCode(&exit_code));

                if (exit_code == -1073740760 /*STATUS_INVALID_IMAGE_HASH*/) {
                    wil::unique_cotaskmem_string modulePath;
                    CHECK_FAILURE(args->get_FailureSourceModulePath(&modulePath));

                    // If the process crashed because of STATUS_INVALID_IMAGE_HASH,
                    // then we want to log to our app's telemetry the name of the
                    // DLL that caused the issue.
                    SendTelemetry(modulePath);
                }

                return S_OK;
            }
    ```


# API Details

```
[uuid(a9fc1af8-f934-4f0f-a788-7be0808c329b), object, pointer_default(unique)]
interface ICoreWebView2ProcessFailedEventArgs : IUnknown {
    /// This property is the full path of the module that caused the
    /// crash in cases of Windows Code Integrity failures.
    /// [Windows Code Integrity](https://learn.microsoft.com/en-us/mem/intune/user-help/you-need-to-enable-code-integrity)
    /// is a feature that verifies the integrity and
    /// authenticity of dynamic-link libraries (DLLs)
    /// on Windows systems. It ensures that only trusted
    /// code can run on the system and prevents unauthorized or
    /// malicious modifications.
    /// When ProcessFailed occurred due to a failed Code Integrity check,
    /// this property returns the full path of the file that was prevented from
    /// loading on the system.
    /// The webview2 process which tried to load the DLL will fail with
    /// exit code STATUS_INVALID_IMAGE_HASH(-1073740760).
    /// A file can fail integrity check for various
    /// reasons, such as:
    /// - It has an invalid or missing signature that does
    /// not match the publisher or signer of the file.
    /// - It has been tampered with or corrupted by malware or other software.
    /// - It has been blocklisted by an administrator or a security policy.
    /// This property always will be the empty string if failure is not caused by
    /// STATUS_INVALID_IMAGE_HASH.
    [propget] HRESULT FailureSourceModulePath([out, retval] LPWSTR* modulePath);
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core 
{
    runtimeclass CoreWebView2ProcessFailedEventArgs
    {
        // ICoreWebView2ProcessFailedEventArgs members continuation
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2ProcessFailedEventArgs3")]
        {
            // ICoreWebView2ProcessFailedEventArgs3 members
            String FailureSourceModulePath { get; };
        }

    }
}
```