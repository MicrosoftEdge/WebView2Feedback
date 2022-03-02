# Background
Since the current ExecuteStrip interface is a little shabby, it is necessary
to provide a new interface to let the user get more infomation, and easier to use.
The new interface will provide the exception infomation if the script execute
failed, and provide a new method to try to get the string to resolve the problem
that the old interface is not friendly to the string return type.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` to provide an `ExecuteScriptWithResult` 
method. The method will return a struct to manage the execute result, which can
get the raw result and string if execute success, and can get exception when
execute failed.

# Examples
The following code snippets demonstrate how the ExecuteScriptWithResult can be used:
## Win32 C++
``` cpp
void ScriptComponent::ExecuteScriptWithResult(LPCWSTR script)
{
    wil::com_ptr<ICoreWebView2_10> webview2 =
        m_webView.try_query<ICoreWebView2_10>();

    // The main interface for excute script, the first param is the string
    // which user want to execute, the second param is the callback to process
    // the result, here use a lamada to the param.
    webview2->ExecuteScriptWithResult(
        script,
        // The callback function has two param, the first one is the status of call.
        // it will always be the S_OK for now, and the second is the result struct.
        Callback<ICoreWebView2ExecuteScriptWithResultCompletedHandler>(
            [this](
                HRESULT errorCode
                ICoreWebView2ExecuteScriptResult* result) -> HRESULT
            {
                if (errorCode != S_OK || result == nullptr) 
                {
                    MessageBox(nullptr, L"Call interface failed!", L"ExecuteScript Result", MB_OK);
                    return S_OK;
                }
                else 
                {
                    wil::com_ptr<ICoreWebView2ExecuteScriptException> exception;
                    BOOL is_success;

                    // User should always invoke the get_IsSuccess firstly to get the execution status.
                    if (result->get_IsSuccess(&is_success) != S_OK)
                    {
                        MessageBox(nullptr, L"Get execute status failed!", L"ExecuteScript Result", MB_OK);
                        return S_OK;
                    }
                    
                    // If execute success, then we can get the raw json data, and try to get the string.
                    if (is_success) 
                    {
                        wil::unique_cotaskmem_string rawJsonData;
                        // Get the raw json.
                        if (result->get_ResultAsJson(&rawJsonData) == S_OK) 
                        {
                            MessageBox(
                                nullptr, rawJsonData.get(), L"ExecuteScript Result", MB_OK); 
                        }
                        else 
                        {
                            MessageBox(
                                nullptr, L"Get raw json data failed", L"ExecuteScript Result", MB_OK);
                        }
                        
                        // Get the string, and if the result is not the string type, 
                        // it will return the E_INVALIDARG.
                        wil::unique_cotaskmem_string stringData;
                        if (result->TryGetResultAsString(&stringData) == S_OK) {
                            MessageBox(
                                nullptr, stringData.get(), L"ExecuteScript Result", MB_OK); 
                        }
                        else 
                        {
                            MessageBox(
                                nullptr, L"Get string failed", L"ExecuteScript Result", MB_OK);
                        }
                    }
                    else // If execute failed, then we can get the exception struct to get the reason of failed.
                    {
                        if (result->get_Exception(&exception) == S_OK)
                        {
                            // Get the exception name, this could return the empty string, such as `throw 1`.
                            wil::unique_cotaskmem_string exceptionName;
                            if (exception && exception->get_Name(&exceptionName) == S_OK) 
                            {
                                MessageBox(
                                    nullptr, exceptionName.get(), L"ExecuteScript Result", MB_OK);
                            }
                            
                            // Get the exception message, this could return the empty string, such as `throw 1`.
                            wil::unique_cotaskmem_string exceptionMessage;
                            if (exception && exception->get_Message(&exceptionMessage) == S_OK)
                            {
                                MessageBox(
                                    nullptr, exceptionMessage.get(), L"ExecuteScript Result", MB_OK);
                            }

                            // Get the exception detail, it's a json struct data with all exception infomation
                            // , we can parse it and get the detail what we need.
                            wil::unique_cotaskmem_string exceptionDetail;
                            if (exception && exception->get_Detail(&exceptionDetail) == S_OK)
                            {
                                MessageBox(
                                    nullptr, exceptionDetail.get(), L"ExecuteScript Result", MB_OK);
                            }
                        }
                        else
                        {
                            MessageBox(
                                nullptr, L"Get exception failed", L"ExecuteScript Result", MB_OK); 
                        }
                    }

                }
            }
        )
    )
}

```
## .NET and WinRT

```c#
void ExecuteScriptWithResultAsync(String script)
{
    var environment = webView2Control.CoreWebView2.Environment;
    CoreWebView2ExecuteScriptResult result = await ExecuteScriptWithResultAsync(script);

    bool isSuccess = result.IsSuccess;
    if (isSuccess) 
    {
        Debug.WriteLine($"execute script success.");

        Debug.WriteLine($"json result received: {result.ResultAsJson}");
        try 
        {
            string stringResult = result.TryGetResultAsString();
            Debug.WriteLine($"get string result success: {stringResult}");
        } 
        catch (ArgumentException) 
        {
            Debug.WriteLine($"Non-string message received");
        }
    } 
    else 
    {
        Debug.WriteLine($"execute script failed.");
        CoreWebView2ExecuteScriptException exception = result.Exception;
        Debug.WriteLine($"exception name: {exception.Name}");
        Debug.WriteLine($"exception message: {exception.Message}");
        Debug.WriteLine($"exception Detail: {exception.Detail}");
    }
}
```

# API Details
## Win32 C++
```c++
/// This is the exception struct when ExecuteScriptWithResult return false, user can
/// use get_Exception to get it.
[uuid(82F22B72-1B22-403E-A0B9-A8816C9C8E45), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptException : IUnknown {

  /// This will return the exception className, it would be got from the 
  /// `result.exceptionDetail.exception.className` in json result, this
  /// could be empty if the exception doesn't have the specified element, 
  /// such as user active throw an exception like `throw "abc"`.
  [propget] HRESULT Name([out, retval] LPWSTR* value);

  /// This will return the exception message, it would be got from the 
  /// `result.exceptionDetail.exception.description` in json result, this
  /// could be empty if the exception doesn't have the specified element, 
  /// such as user active throw an exception like `throw "abc"`.
  [propget] HRESULT Message([out, retval] LPWSTR* value);

  /// This will return the exception detail, it's a json struct with complete information for
  /// exception, if get_Name and get_Exception is not enough, user can use this interface and 
  /// get what they want.
  [propget] HRESULT Detail([out, retval] LPWSTR* detail);
}

/// This is the result for ExecuteScriptWithResult.
[uuid(D2C59C5C-AD36-4CF4-87CF-2F5359F6D4CB), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptResult : IUnknown {

  /// This property is true if ExecuteScriptWithResult successfully executed script with
  /// no unhandled exceptions and the result is available in the ResultAsJson property
  /// or via the TryGetResultAsString method.
  /// If it is false then the script execution had an unhandled exception which you
  /// can get via the Exception property.
  [propget] HRESULT IsSuccess([out, retval] BOOL* value); 

  /// If IsSuccess is true, then this property is the JSON representation of the result of the script execution
  /// and otherwise returns E_INVALIDARG.
  [propget] HRESULT ResultAsJson([out, retval] LPWSTR* jsonResult);

  /// If IsSuccess is true and the result of script execution is a string, this method provides the value of the string result
  /// and otherwise returns E_INVALIDARG.
  HRESULT TryGetResultAsString([out, retval] LPWSTR* stringResult);

  /// If IsSuccess return failed, user can use this interface to get exception to handle, 
  /// otherwise return E_INVALIDARG.
  [propget] HRESULT Exception(
      [out, retval] ICoreWebView2ExecuteScriptException** exception);
}

/// This is the callback for ExecuteScriptWithResult
[uuid(CECDD25B-E6E8-4A4E-B890-BBF95932564F), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptWithResultCompletedHandler : IUnknown {

  /// Provides the event args for the execute result.
  HRESULT Invoke(
      [in] HRESULT errorCode, 
      [in] ICoreWebView2ExecuteScriptResult* result);
}

/// This is the interface for getting string and exception with ExecuteScriptWithResult
[uuid(67E0B57B-1AC7-4395-9793-5E4EF9C4B7D9), object, pointer_default(unique)]
interface ICoreWebView2_10 : ICoreWebView2_9 {
  
  /// New execute javascript for user can get the string result and can get exception
  /// if execution fails.
  HRESULT ExecuteScriptWithResult(
      [in] LPCWSTR javaScript,
      [in] ICoreWebView2ExecuteScriptWithResultCompletedHandler* handler);
}
```

## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2;
    runtimeclass CoreWebView2ExecuteScriptResult;
    runtimeclass CoreWebView2ExecuteScriptException;

    runtimeclass CoreWebView2
    {
        Windows.Foundation.IAsyncOperation<CoreWebView2ExecuteScriptResult>
        ExecuteScriptWithResultAsync(String javaScript);
    }

    runtimeclass CoreWebView2ExecuteScriptResult
    {
        bool IsSuccess { get; };

        String ResultAsJson { get; };

        String TryGetResultAsString();
    }

    runtimeclass CoreWebView2ExecuteScriptException
    {
        String Name { get; };
        
        String Message { get; };

        String Detail { get; };
    }
}
```


