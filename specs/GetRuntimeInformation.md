# Background
As you know, one single WV2 runtime instance can be shared by multiple host apps, e.g., office apps (excel, word, ppt) might share a single WV2 runtime. So, a given host app does not have a whole picture of what's happening in the runtime process, such as what profiles are active there and what webviews are under each profile.

We want to have a new API to help developers get such information.

In this document we describe the API. We'd appreciate your feedback.

# Description
We propose extending `CoreWebView2` to provide an `GetRuntimeInformation` method. The method returns a information object that can be used to
form an information view.

# Examples
The following code snippets demonstrate how the GetRuntimeInformation can be used:
## Win32 C++
```cpp
```

## .NET and WinRT
```c#
```

# API Details
The spec file for `GetRuntimeInformation`.
## Win32 C++
```c++
```

## .NET and WinRT
```c#
```
