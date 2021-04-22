# Background
The WebView2 team has been asked for an API to allow end developers to set the autofill preferences.  We are exposing two of the autofill preferences that will allow enabling and disabling general and password autofill.  General autofill includes things like email addresses, shipping addresses, phone numbers, and names.  Password autofill includes things like usernames and passwords for login.  Password information is not included in the general autofill. 

In this document we describe the updated API. We'd appreciate your feedback.


# Description

Autofill has three components
* Auto-populate - Populate the corresponding form fields automatically on page load.
* Suggest - When the user clicks on the form field, drop down suggestions of previously saved forms will be displayed.
* Populate - When clicking on one of the suggestions, the form data will populate the respective fields.
The general autofill setting and password autofill setting behave independently.  Their behavior differs as well.  
When the password autofill setting is disabled, no new password data is saved and no Save/Update Password prompts are displayed.  However, if there was password data already saved before disabling this setting, then that password information is auto-populated, suggestions are shown and clicking on one will populate the fields.  When the password autofill setting is enabled, password information is auto-populated, suggestions are shown and clicking on one will populate the fields, new data is saved, and a Save/Update Password prompt is displayed. The password autofill setting default behavior is enabled. 
When the general autofill setting is disabled, no suggestions appear, and no new information is saved. When the general autofill setting is enabled, information is saved, suggestions appear and clicking on one will populate the form fields. 


# Examples

## Win32 C++
```cpp
void SettingsComponent::TogglePasswordAutofill() {
    wil::com_ptr<ICoreWebView2Settings2_2> settings;
    webView->get_Settings(&settings);
    bool enabled;
    settings->get_IsPasswordAutofillEnabled(&enabled);
    settings->put_IsPasswordAutofillEnabled(!enabled);
}

void SettingsComponent::ToggleGeneralAutofill() {
    wil::com_ptr<ICoreWebView2Settings2_2> settings;
    webView->get_Settings(&settings);
    bool enabled;
    settings->get_IsGeneralAutofillEnabled(&enabled);
    settings->put_IsGeneralAutofillEnabled(!enabled);
}
```

## .NET, WinRT
```c#

// This demonstrates a scenario in which a button triggers TogglePasswordAutofill or 
// ToggleGeneralAutofill. 

private void TogglePasswordAutofill(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs e)
{
    var settings = webView2Control.CoreWebView2.Settings;
    settings.IsPasswordAutofillEnabled = !settings.IsPasswordAutofillEnabled;
}

private void ToggleGeneralAutofill(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs e)
{
    var settings = webView2Control.CoreWebView2.Settings;
    settings.IsGeneralAutofillEnabled = !settings.IsGeneralAutofillEnabled;
}

```


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details
```IDL
interface ICoreWebView2Settings4

[uuid(f051013e-4bb3-46b2-b6e4-6ee3fe4f43c2), object, pointer_default(unique)]
interface ICoreWebView2Settings4 : ICoreWebView2Settings3 {
  /// IsPasswordAutofillEnabled controls whether autofill for password
  /// information is enabled. The IsPasswordAutofillEnabled property behaves 
  /// independently of the IsGeneralAutofillEnabled property. When 
  /// IsPasswordAutofillEnabled is false, password information is auto-populated,
  /// suggestions are shown and clicking on one will populate the fields, 
  /// but no new data is saved and no Save/Update Password prompts are displayed. 
  /// When IsPasswordAutofillEnabled is true, password information is auto-populated, 
  /// suggestions are shown and clicking on one will populate the fields, new data 
  /// is saved, and a Save/Update Password prompt is displayed. 
  /// The default value is `FALSE`.
  [propget] HRESULT IsPasswordAutofillEnabled([out, retval] BOOL* isPasswordAutofillEnabled);
  // Set the IsPasswordAutofillEnabled property.
  [propput] HRESULT IsPasswordAutofillEnabled([in] BOOL isPasswordAutofillEnabled);

  /// IsGeneralAutofillEnabled controls whether autofill for information 
  /// like names, street and email addresses, phone numbers, and aribtrary input 
  /// is enabled. This excludes password information. When IsGeneralAutofillEnabled 
  /// is false, no suggestions appear, and no new information is saved.
  /// When IsGeneralAutofillEnabled is true, information is saved, suggestions appear
  /// and clicking on one will populate the form fields.
  /// The default value is `TRUE`.
  [propget] HRESULT IsGeneralAutofillEnabled([out, retval] BOOL* isGeneralAutofillEnabled);
  /// Set the IsGeneralAutofillEnabled property.
  [propput] HRESULT IsGeneralAutofillEnabled([in] BOOL isGeneralAutofillEnabled);
}
```
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
        public bool IsPasswordAutofillEnabled { get; set; };
        public bool IsGeneralAutofillEnabled {get; set; };
    }
}

```