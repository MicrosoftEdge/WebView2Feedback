Application-Bound Encryption
============================

# Background

By default, WebView2 protects sensitive data stored in a user data folder, such as cookies, using
Windows Data Protection API (DPAPI) bound to the current Windows user account. While user DPAPI
protects data against other Windows user accounts on the same machine, any process running under
the same Windows user account shares those user DPAPI credentials.

Packaged desktop host applications that handle sensitive authenticated sessions need stronger local
isolation so that another application or process running as the same Windows user cannot decrypt
cookies stored in the host application's user data folder.

Application-Bound Encryption (ABE) lets you bind encryption of sensitive user data folder cookies
to your host application's Windows package identity (Package Family Name and Application User Model
ID) using the WebView2 `ElevationService`. When enabled on an eligible packaged host application,
you supply a 32-byte cryptographically random encryption key when enrolling a fresh user data
folder. WebView2 seals that key to your application's package identity via the WebView2
`ElevationService` and stores only the wrapped key blob in the user data folder. On subsequent
launches, only your packaged host application can unwrap the persisted key through the
`ElevationService`.

# Conceptual pages (How To)

You can configure host-owned Application-Bound Encryption (ABE) on `CoreWebView2EnvironmentOptions`
before creating a `CoreWebView2Environment` for a user data folder.

## Prerequisites

To use Application-Bound Encryption, your host application and runtime environment must meet all of
the following requirements:

- Your host application must have Windows package identity (such as an MSIX package or a sparse
  package registered with a Package Family Name and Application User Model ID).
- Your host application must run as a medium-integrity, non-elevated desktop process outside of an
  AppContainer.
- Your application must use the installed Evergreen WebView2 Runtime, which installs and registers
  the WebView2 `ElevationService` (`MicrosoftEdgeWebViewElevationService`). Fixed Version WebView2
  Runtime distributions do not register this system service.

## Scope and lifetime

`IsAppBoundEncryptionEnabled` and the key configured via `SetAppBoundEncryptionKey` are immutable
creation options on `CoreWebView2EnvironmentOptions`. WebView2 reads these options synchronously
when you create the `CoreWebView2Environment` for a user data folder. Modifying the
`CoreWebView2EnvironmentOptions` instance after calling `CreateCoreWebView2EnvironmentWithOptions`
or `CoreWebView2Environment.CreateAsync` has no effect on an already-created
`CoreWebView2Environment`.

All `CoreWebView2Controller` and `CoreWebView2` instances created from the same
`CoreWebView2Environment` share the user data folder's application-bound encryption state. When
multiple processes share a user data folder, all cooperating processes must belong to the same
Windows package identity and use matching `IsAppBoundEncryptionEnabled` settings.

## First launch vs. subsequent launches

- **First launch on a fresh (unenrolled) user data folder:** Generate a 32-byte cryptographically
  random key using a platform CSPRNG (such as `BCryptGenRandom` in C++ or
  `RandomNumberGenerator.Fill` in C#) and pass it to `SetAppBoundEncryptionKey`. Calling
  `SetAppBoundEncryptionKey` with a valid 32-byte key automatically sets
  `IsAppBoundEncryptionEnabled` to `TRUE`. During initialization, WebView2 binds the 32-byte key to
  your host application's package identity via the WebView2 `ElevationService`, persists the
  wrapped key in the user data folder, and zeroes the in-memory plaintext key cached for the
  handshake.
- **Subsequent launches on an already-enrolled user data folder:** Set
  `IsAppBoundEncryptionEnabled` to `TRUE` (either directly or by calling
  `SetAppBoundEncryptionKey`). When the user data folder already contains a persisted
  application-bound key, WebView2 automatically unwraps and uses the persisted key bound to your
  package identity and ignores any new candidate key passed via `SetAppBoundEncryptionKey` so
  existing encrypted cookies remain readable.
- **Mismatch or unauthorized package access:** If a different application package attempts to open
  an already-enrolled user data folder, the WebView2 `ElevationService` denies key unwrapping
  because the caller's package identity does not match the enrolled owner, preventing decryption of
  application-bound cookies.

# Examples

## Enrolling a fresh user data folder and reopening an enrolled user data folder

The following examples show how to configure `CoreWebView2EnvironmentOptions` both on first launch
(when enrolling a fresh user data folder with a 32-byte cryptographically random key) and on
subsequent launches (when reopening an already-enrolled user data folder).

```c#
using System;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.Web.WebView2.Core;

public class AppBoundEncryptionSample
{
    public static async Task<CoreWebView2Environment> CreateEnvironmentAsync(
        string userDataFolder,
        bool isFirstLaunchEnrollment)
    {
        var options = new CoreWebView2EnvironmentOptions();

        if (isFirstLaunchEnrollment)
        {
            // On first launch with a fresh user data folder, supply a 32-byte
            // cryptographically random key. This also sets
            // IsAppBoundEncryptionEnabled to true.
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
            // On subsequent launches of an already-enrolled user data folder,
            // enable application-bound encryption to unwrap the persisted key.
            options.IsAppBoundEncryptionEnabled = true;
        }

        CoreWebView2Environment environment =
            await CoreWebView2Environment.CreateAsync(
                browserExecutableFolder: null,
                userDataFolder: userDataFolder,
                options: options);

        return environment;
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

/// Creates a WebView2 environment configured for host-owned application-bound
/// encryption using `userDataFolder`, `isFirstLaunchEnrollment`, and
/// `completedHandler`.
HRESULT CreateAppBoundWebViewEnvironment(
    PCWSTR userDataFolder,
    bool isFirstLaunchEnrollment,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler* completedHandler)
{
    auto options = Make<CoreWebView2EnvironmentOptions>();
    if (!options)
    {
        return E_OUTOFMEMORY;
    }

    wil::com_ptr_nothrow<ICoreWebView2EnvironmentOptions11> options11;
    HRESULT hr = options.As(&options11);
    if (FAILED(hr))
    {
        return hr;
    }

    if (isFirstLaunchEnrollment)
    {
        // Generate a 32-byte cryptographically random key for a fresh
        // user data folder. SetAppBoundEncryptionKey also sets
        // IsAppBoundEncryptionEnabled to TRUE.
        BYTE encryptionKey[32] = {};
        NTSTATUS status = BCryptGenRandom(
            nullptr,
            encryptionKey,
            sizeof(encryptionKey),
            BCRYPT_USE_SYSTEM_PREFERRED_RNG);
        if (!BCRYPT_SUCCESS(status))
        {
            return HRESULT_FROM_NT(status);
        }

        hr = options11->SetAppBoundEncryptionKey(
            sizeof(encryptionKey), encryptionKey);
        ::SecureZeroMemory(encryptionKey, sizeof(encryptionKey));
        if (FAILED(hr))
        {
            return hr;
        }
    }
    else
    {
        // On subsequent launches of an already-enrolled user data folder,
        // enable application-bound encryption so WebView2 unwraps the key
        // persisted in the user data folder.
        hr = options11->put_IsAppBoundEncryptionEnabled(TRUE);
        if (FAILED(hr))
        {
            return hr;
        }
    }

    return CreateCoreWebView2EnvironmentWithOptions(
        nullptr, userDataFolder, options.Get(), completedHandler);
}
```

# API Details

```
/// Additional options used to create WebView2 Environment to configure
/// host-owned application-bound encryption.
[uuid(5df2ef84-51a6-5727-a502-6c7a4e406694), object, pointer_default(unique)]
interface ICoreWebView2EnvironmentOptions11 : IUnknown {
  /// Indicates whether host-owned application-bound encryption (ABE) is
  /// enabled for the WebView2 environment.
  ///
  /// The default value is `FALSE`. This option is applied when creating the
  /// `CoreWebView2Environment` for a user data folder and requires the host
  /// application to have Windows package identity (MSIX or sparse package) and
  /// the WebView2 `ElevationService` installed.
  /// Returns `E_POINTER` if `value` is `nullptr`.
  [propget] HRESULT IsAppBoundEncryptionEnabled([out, retval] BOOL* value);
  /// Sets the `IsAppBoundEncryptionEnabled` property.
  ///
  /// Set this property to `TRUE` when reopening an already-enrolled user data
  /// folder so WebView2 unwraps and uses the persisted application-bound key.
  [propput] HRESULT IsAppBoundEncryptionEnabled([in] BOOL value);
  /// Sets the 32-byte cryptographically random application-bound encryption
  /// (ABE) key to enroll for a fresh user data folder.
  ///
  /// `keySize` must be `32` when `key` is non-null, or `0` when `key` is
  /// `nullptr` to clear any in-memory key before environment creation and reset
  /// `IsAppBoundEncryptionEnabled` to `FALSE`. Passing `nullptr` for `key` with
  /// a non-zero `keySize` fails with `E_POINTER` and leaves the existing state
  /// unchanged. Any other `keySize` fails with `E_INVALIDARG` and leaves the
  /// existing state unchanged.
  ///
  /// Calling `SetAppBoundEncryptionKey` with a valid 32-byte key copies the key
  /// into this options instance and sets `IsAppBoundEncryptionEnabled` to
  /// `TRUE`. On a fresh user data folder, WebView2 binds this 32-byte key to
  /// the host application's package identity and persists the wrapped key in
  /// the user data folder. On an already-enrolled user data folder, WebView2
  /// uses the persisted application-bound key and ignores any new candidate key
  /// passed to this method.
  HRESULT SetAppBoundEncryptionKey(
      [in] UINT32 keySize,
      [in, size_is(keySize)] const BYTE* key
  );
  /// Retrieves the 32-byte cryptographically random application-bound
  /// encryption (ABE) key currently stored in this options instance into the
  /// caller-supplied buffer.
  ///
  /// `key` must point to a writable 32-byte buffer (`E_POINTER` if `nullptr`),
  /// and `keySize` must be `32` (`E_INVALIDARG` otherwise). Fails with
  /// `E_INVALIDARG` if no key is currently set on this options instance.
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
            Boolean IsAppBoundEncryptionEnabled { get; set; };
            void SetAppBoundEncryptionKey(UInt8[] key);
            UInt8[] GetAppBoundEncryptionKey();
        }
    }
}
```
