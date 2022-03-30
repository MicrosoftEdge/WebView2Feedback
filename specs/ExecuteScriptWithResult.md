# Background
Our end developers have pointed out gaps in the existing [CoreWebView2.ExecuteScript](https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.1150.38#executescript) method, and it is necessary
to provide a new method to let our end developers get more information in a more convenient manner.
The new ExecuteScriptWithResult method will provide exception information if the executed script
failed, and provides a new method to try to get the script execution result as a string rather than as JSON
in order to make it more convenient to interact with string results.

In this document we describe the updated API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` to provide an `ExecuteScriptWithResult` 
method. The method acts like ExecuteScript, but returns a CoreWebView2ExecuteScriptResult object that can be used to
get the script execution result as a JSON string or as a string value if execution succeeds, and can be used to get the exception when
execution failed.

# Examples
The following code snippets demonstrate how the ExecuteScriptWithResult can be used:
## Win32 C++
``` cpp
// Tools function to generate the script code
// Using std::wstringstream to generate script code,
// it will generate the code like
// 'let str_0 = "This is a string"; let n_0= str_0.replace(/a/i, "microsoft"); n_0;'
std::wstring GenerateScriptCode(LPCWSTR str, LPCWSTR reg, LPCWSTR item)
{
    if (str == nullptr || reg == nullptr || item == nullptr)
    {
        return L"";
    }

    // This variable is used to ensure that the
    // variables in the script are unique.
    static int idx = 0;

    static std::wstringstream sw;
    sw.clear();

    sw << L"let str_" << idx << L" = \"" << str << L"\"; let n_" << idx << L"= str_" << idx
       << L".replace(" << reg << L", \"" << item << L"\"); n_" << idx << L";";
    ++idx;
    return sw.str();
}

// This is a demo that uses regular expressions in 
// JavaScript to complete string replacement, it will handle
// the case of successful execution and execution exception
void MatchRegWithScript(wil::com_ptr<ICoreWebView2> webView
    , LPCWSTR str
    , LPCWSTR reg
    , LPCWSTR item)
{
    wil::com_ptr<ICoreWebView2_10> webview2 = webView.try_query<ICoreWebView2_10>();
    if (!webview2)
    {
        // ExecuteScriptWithResult is not supported by this WebView.
        return;
    }

    auto scriptCode = GenerateScriptCode(str, reg, item);
    webview2->ExecuteScriptWithResult(
        scriptCode.c_str(),
        Callback<ICoreWebView2ExecuteScriptWithResultCompletedHandler>(
            [](
                HRESULT errorCode, ICoreWebView2ExecuteScriptResult* result) -> HRESULT
            {
                // There is usually no failure here, if the assertion fails,
                // the runtime environment has an exception and needs to fail fast.
                CHECK_FAILURE(errorCode);

                wil::unique_cotaskmem_string stringData;

                BOOL isSuccess;
                result->get_Succeeded(&isSuccess);
                // Here is the successful execution.
                // We will use a MessageBox to print the replaced result.
                if (isSuccess)
                {
                    // We try to use `TryGetResultAsString` to get the string result here.
                    // We can check the `isString` to get if the result is string type.
                    // Since the JavaScript platform's `string.replace` returns a string,
                    // the call here will succeed.
                    // If the script is replaced by `string.search`, the function will
                    // return an int and the call will fail here.
                    BOOL isString;
                    if (result->TryGetResultAsString(&stringData, &isString) != S_OK || !isString)
                    {
                        MessageBox(
                            nullptr, L"Get string failed", L"ExecuteScript Result", MB_OK);
                    }
                    else
                    {
                        MessageBox(nullptr, stringData.get(), L"ExecuteScript Result",
                            MB_OK);
                    }
                }
                // Here is the case of execution exception. 
                // We will use MessageBox to print exception-related information
                else
                {
                    wil::com_ptr<ICoreWebView2ExecuteScriptException> exception;
                    
                    result->get_Exception(&exception);

                    // The ExceptionName property could be the empty string if script throws a non-Error object, 
                    // such as `throw 1`.
                    wil::unique_cotaskmem_string exceptionName;
                    exception->get_Name(&exceptionName);

                    // The ExceptionMessage property could be the empty string if script throws a non-Error object, 
                    // such as `throw 1`.
                    wil::unique_cotaskmem_string exceptionMessage;
                    exception->get_Message(&exceptionMessage)

                    // Get the location of the exception, note that the coordinates
                    // here are 0 as the starting position.
                    uint32_t lineNumber = 0;
                    uint32_t columnNumber = 0;
                    exception->get_LineNumber(&lineNumber);
                    exception->get_ColumnNumber(&columnNumber);

                    auto exceptionInfo = 
                            L"The script execution failed." + 
                            L"\nName: " + exceptionName.get() +
                            L"\nMessage: " + exceptionMessage.get() +
                            L"\nLineNumber: " + std::to_wstring(lineNumber) +
                            L", ColumnNumber:" + std::to_wstring(columnNumber);
                    MessageBox(
                        nullptr, exceptionInfo.c_str(),
                        L"ExecuteScript Result", MB_OK);
                }
                
                return S_OK;
            })
            .Get());
}

```
## .NET and WinRT
```c#
class ExecuteScriptWithResultDemo 
{
    int idx = 0;

    private String GenerateScriptCode(String str, String reg, String item) 
    {
        String ret = $"let str_{idx} = \"{str}\"; let n_{idx} = str_{idx}.replace({reg}, \"{item}\"); n_{idx};";
        ++idx;
        return ret;
    }


    // This is a demo that uses regular expressions in 
    // JavaScript to complete string replacement, it will handle
    // the case of successful execution and execution exception
    public void MatchRegWithScript(String str, String reg, String item) 
    {
        String script = GenerateScriptCode(str, reg, item);
        CoreWebView2ExecuteScriptResult result = await ExecuteScriptWithResultAsync(script);
        
        bool isSuccess = result.Succeeded;
        // Here is the successful execution.
        if (isSuccess) {            
            // Try to get the string result, it will return 0
            // if the result type isn't string type.
            String stringResult;
            if (result.TryGetResultAsString(stringResult) != 0)
            {
                Debug.WriteLine($"replaced string: {stringResult}");
            }
            else 
            {
                Debug.WriteLine($"Non-string message received");
            }
        }
        // Here is the case of execution exception.
        else
        {
            var exception = result.Exception;
            String exceptionInfo = "The script execution failed." + 
                "\nName:" + exception.Name +
                "\nMessage: " + exception.Message +
                "\nLineNumber:" + exception.LineNumber + 
                ", ColumnNumber:" + exception.ColumnNumber;
            Debug.WriteLine($"{exceptionInfo}");
        }
    }
}
```

# API Details
The spec file for `ExecuteScript` is [WebView2Feedback/specs/ExecuteScript.md](https://github.com/MicrosoftEdge/WebView2Feedback/blob/ca99cf43fde3f536a4d3981d53b8345edb0c9a62/specs/ExecuteScript.md).
## Win32 C++
```c++
/// This interface represents a JavaScript exception.
/// If the CoreWebView2.ExecuteScriptWithResult result has Succeeded as false,
/// you can use the result's Exception property to get the script exception.
[uuid(82F22B72-1B22-403E-A0B9-A8816C9C8E45), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptException : IUnknown {

  /// The line number of the source where the exception occurred.
  /// In the JSON it is `exceptionDetail.lineNumber`.
  /// Note that this position starts at 0.
  [propget] HRESULT LineNumber([out, retval] UINT32* value);
  
  /// The column number of the source where the exception occurred.
  /// In the JSON it is `exceptionDetail.columnNumber`.
  /// Note that this position starts at 0.
  [propget] HRESULT ColumnNumber([out, retval] UINT32* value);

  /// The Name is the exception's class name.
  /// In the JSON it is `exceptionDetail.exception.className`.
  /// This is the empty string if the exception doesn't have a class name.
  /// This can happen if the script throws a non-Error object such as `throw "abc";`
  [propget] HRESULT Name([out, retval] LPWSTR* value);

  /// The Message is the exception's message and potentially stack.
  /// In the JSON it is exceptionDetail.exception.description.
  /// This is the empty string if the exception doesn't have a description.
  /// This can happen if the script throws a non-Error object such as throw "abc";.
  [propget] HRESULT Message([out, retval] LPWSTR* value);

  /// This will return all details of the exception as a JSON string.
  /// In the case that script has thrown a non-Error object such as `throw "abc";`
  /// or any other non-Error object, you can get object specific properties.
  [propget] HRESULT ToJson([out, retval] LPWSTR* value);
}

/// This is the result for ExecuteScriptWithResult.
[uuid(D2C59C5C-AD36-4CF4-87CF-2F5359F6D4CB), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptResult : IUnknown {

  /// This property is true if ExecuteScriptWithResult successfully executed script with
  /// no unhandled exceptions and the result is available in the ResultAsJson property
  /// or via the TryGetResultAsString method.
  /// If it is false then the script execution had an unhandled exception which you
  /// can get via the Exception property.
  [propget] HRESULT Succeeded([out, retval] BOOL* value); 

  /// A function that has no explicit return value returns undefined. If the
  /// script that was run throws an unhandled exception, then the result is
  /// also "null". This method is applied asynchronously. If the method is
  /// run before `ContentLoading`, the script will not be executed
  /// and the string "null" will be returned.
  
  /// The return value description is as follows
  /// 1. S_OK: Execution succeeds.
  /// 2. E_POINTER: When the `jsonResult` is nullptr.
  [propget] HRESULT ResultAsJson([out, retval] LPWSTR* jsonResult);

  /// If Succeeded is true and the result of script execution is a string, this method provides the value of the string result,
  /// and we will get the `FALSE` var value when the js result is not string type.
  /// The return value description is as follows
  /// 1. S_OK: Execution succeeds.
  /// 2. E_POINTER: When the `stringResult` or `value` is nullptr.
  HRESULT TryGetResultAsString([out] LPWSTR* stringResult, [out, retval] BOOL* value);

  /// If Succeeded is false, you can use this property to get the unhandled exception thrown by script execution
  /// Note that due to the compatibility of the WinRT/.NET interface,
  /// S_OK will be returned even if the acquisition fails.
  /// We can determine whether the acquisition is successful by judging whether the `exception` is nullptr.
  [propget] HRESULT Exception(
      [out, retval] ICoreWebView2ExecuteScriptException** exception);
}

/// This is the callback for ExecuteScriptWithResult
[uuid(CECDD25B-E6E8-4A4E-B890-BBF95932564F), object, pointer_default(unique)]
interface ICoreWebView2ExecuteScriptWithResultCompletedHandler : IUnknown {

  /// Provides the result of ExecuteScriptWithResult
  HRESULT Invoke(
      [in] HRESULT errorCode, 
      [in] ICoreWebView2ExecuteScriptResult* result);
}

/// This is the interface for getting string and exception with ExecuteScriptWithResult
[uuid(67E0B57B-1AC7-4395-9793-5E4EF9C4B7D9), object, pointer_default(unique)]
interface ICoreWebView2_10 : ICoreWebView2_9 {
  
  /// Run JavaScript code from the JavaScript parameter in the current
  /// top-level document rendered in the WebView.
  /// The result of the execution is returned asynchronously in the CoreWebView2ExecuteScriptResult object
  /// which has methods and properties to obtain the successful result of script execution as well as any
  /// unhandled JavaScript exceptions.
  /// If this method is
  /// run after the NavigationStarting event during a navigation, the script
  /// runs in the new document when loading it, around the time
  /// ContentLoading is run. This operation executes the script even if
  /// ICoreWebView2Settings::IsScriptEnabled is set to FALSE.
  HRESULT ExecuteScriptWithResult(
      [in] LPCWSTR javaScript,
      [in] ICoreWebView2ExecuteScriptWithResultCompletedHandler* handler);
}
```

## .NET and WinRT
The documentation for the old interface [CoreWebView2.ExecuteScriptAsync(String) Method](https://docs.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.core.corewebview2.executescriptasync?view=webview2-dotnet-1.0.1150.38#microsoft-web-webview2-core-corewebview2-executescriptasync(system-string)) is here.
```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2;
    runtimeclass CoreWebView2ExecuteScriptResult;
    runtimeclass CoreWebView2ExecuteScriptException;

    runtimeclass CoreWebView2
    {
        [interface_name("Microsoft.Web.WebView2.Core.ICoreWebView2_10")]
        {
            Windows.Foundation.IAsyncOperation<CoreWebView2ExecuteScriptResult> ExecuteScriptWithResultAsync(String javaScript);
        }
    }

    runtimeclass CoreWebView2ExecuteScriptResult
    {
        Boolean Succeeded { get; };

        // The return value of this interface is the same as `ExecuteScript`.
        // You can refer to the demo and documentation of `ExecuteScript`.
        String ResultAsJson { get; };

        CoreWebView2ExecuteScriptException Exception { get; };

        Int32 TryGetResultAsString(out String stringResult);
    }

    runtimeclass CoreWebView2ExecuteScriptException
    {
        UInt32 LineNumber { get; };

        UInt32 ColumnNumber { get; };

        String Name { get; };

        String Message { get; };

        String ToJson { get; };
    }
}
```
