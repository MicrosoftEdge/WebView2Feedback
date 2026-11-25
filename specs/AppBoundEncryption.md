Application-Bound Encryption
============================

# Background

By default, WebView2 encrypts sensitive data stored in a user data folder, such as cookies, using
credentials scoped to the current Windows user account. Any process running under that same Windows
user account can access those user-scoped credentials.

Application-Bound Encryption (ABE) lets a packaged desktop application bind encryption of sensitive
user data folder data to its Windows package identity so that other applications running under the
same Windows user account cannot decrypt it.

# Conceptual pages (How To)

Configure Application-Bound Encryption on `CoreWebView2EnvironmentOptions` before creating a
`CoreWebView2Environment`. Application-Bound Encryption requires Windows package identity (such as
an MSIX or sparse package) and the Evergreen WebView2 Runtime; otherwise WebView2 falls back to
default user-scoped encryption.

- **First launch (fresh user data folder):** Pass a 32-byte cryptographically random key to
  `SetAppBoundEncryptionKey`, which also sets `IsAppBoundEncryptionEnabled` to `TRUE`. If
  `IsAppBoundEncryptionEnabled` is `TRUE` on a fresh user data folder without a 32-byte key,
  WebView2 falls back to default user-scoped encryption.
- **Subsequent launches (enrolled user data folder):** Set `IsAppBoundEncryptionEnabled` to `TRUE`
  to use the existing key for the user data folder. Any new key passed to
  `SetAppBoundEncryptionKey` is ignored. If a different application opens an enrolled user data
  folder, data encrypted by the original package cannot be decrypted, and new data falls back to
  default user-scoped encryption.

These options are read when creating the `CoreWebView2Environment`. Modifying
`CoreWebView2EnvironmentOptions` afterward has no effect, and all `CoreWebView2` instances in the
environment share the setting.

# Examples

```c#
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.Web.WebView2.Core;

public class AppBoundEncryptionSample
{
    public static async Task<CoreWebView2Environment> CreateEnvironmentAsync(
        string userDataFolder,
        bool isFirstLaunch)
    {
        var options = new CoreWebView2EnvironmentOptions();

        if (isFirstLaunch)
        {
            byte[] encryptionKey = new byte[32];
            RandomNumberGenerator.Fill(encryptionKey);
            try
            {
                options.SetAppBoundEncryptionKey(encryptionKey);
            }
            finally
            {
                CryptographicOperations.ZeroMemory(encryptionKey);
            }
        }
        else
        {
            options.IsAppBoundEncryptionEnabled = true;
        }

        return await CoreWebView2Environment.CreateAsync(
            browserExecutableFolder: null,
            userDataFolder: userDataFolder,
            options: options);
    }
}
```

```cpp
#include <windows.h>
#include <bcrypt.h>
#include <wrl.h>
#include <wil/com.h>
#include "WebView2.h"
#include "WebView2EnvironmentOptions.h"

using namespace Microsoft::WRL;

void AppWindow::InitializeAppBoundWebView(bool isFirstLaunch)
{
    auto options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    wil::com_ptr<ICoreWebView2EnvironmentOptions11> options11;
    CHECK_FAILURE(options.As(&options11));

    if (isFirstLaunch)
    {
        BYTE encryptionKey[32] = {};
        NTSTATUS status = BCryptGenRandom(
            nullptr,
            encryptionKey,
            sizeof(encryptionKey),
            BCRYPT_USE_SYSTEM_PREFERRED_RNG);
        CHECK_FAILURE(HRESULT_FROM_NT(status));

        HRESULT hr = options11->SetAppBoundEncryptionKey(
            sizeof(encryptionKey), encryptionKey);
        ::SecureZeroMemory(encryptionKey, sizeof(encryptionKey));
        CHECK_FAILURE(hr);
    }
    else
    {
        CHECK_FAILURE(options11->put_IsAppBoundEncryptionEnabled(TRUE));
    }

    CHECK_FAILURE(CreateCoreWebView2EnvironmentWithOptions(
        nullptr,
        m_userDataFolder.c_str(),
        options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            this, &AppWindow::OnCreateEnvironmentCompleted)
            .Get()));
}
```

# API Details

```
/// Additional options used to create a WebView2 Environment to configure
/// application-bound encryption.
[uuid(5df2ef84-51a6-5727-a502-6c7a4e406694), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions11 : IUnknown {
  /// Indicates whether application-bound encryption is enabled for the
  /// WebView2 environment.
  ///
  /// The default value is `FALSE`. Requires Windows package identity and the
  /// Evergreen WebView2 Runtime; otherwise WebView2 falls back to default
  /// user-scoped encryption. Returns `E_POINTER` if `value` is `nullptr`.
  [propget] HRESULT IsAppBoundEncryptionEnabled([out, retval] BOOL* value);
  /// Sets the `IsAppBoundEncryptionEnabled` property.
  [propput] HRESULT IsAppBoundEncryptionEnabled([in] BOOL value);
  /// Sets the 32-byte cryptographically random application-bound encryption
  /// key for a fresh user data folder, and sets `IsAppBoundEncryptionEnabled`
  /// to `TRUE`.
  ///
  /// `keySize` must be `32` when `key` is non-null, or `0` when `key` is
  /// `nullptr` to clear any in-memory key and reset
  /// `IsAppBoundEncryptionEnabled` to `FALSE`. Passing `nullptr` for `key`
  /// with a non-zero `keySize` fails with `E_POINTER`, and any other `keySize`
  /// fails with `E_INVALIDARG`, leaving the existing state unchanged. On an
  /// already-enrolled user data folder, any new key passed to this method is
  /// ignored.
  HRESULT SetAppBoundEncryptionKey(
      [in] UINT32 keySize,
      [in, size_is(keySize)] const BYTE* key
  );
  /// Copies the 32-byte application-bound encryption key currently set on this
  /// options instance into `key`.
  ///
  /// `key` must point to a writable 32-byte buffer (`E_POINTER` if `nullptr`),
  /// and `keySize` must be `32` (`E_INVALIDARG` otherwise). Fails with
  /// `E_INVALIDARG` if no key is currently set.
  HRESULT GetAppBoundEncryptionKey(
      [in] UINT32 keySize,
      [out, size_is(keySize)] BYTE* key
  );
}
```

```c# (but really MIDL3)
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2EnvironmentOptions
    {
        // ...

        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2EnvironmentOptions11")]
        {
            // ICoreWebView2EnvironmentOptions11 members
            Boolean IsAppBoundEncryptionEnabled { get; set; };

            // Sets the 32-byte key (or null/empty array to clear the key and
            // reset IsAppBoundEncryptionEnabled to false). Throws
            // ArgumentException for any other length.
            void SetAppBoundEncryptionKey(UInt8[] key);

            // Returns the 32-byte key currently set on this options instance,
            // or throws ArgumentException if no key is set.
            UInt8[] GetAppBoundEncryptionKey();
        }
    }
}
```
