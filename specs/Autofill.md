# Background
The WebView2 team has been asked for an API to allow end developers to set the autofill preferences.  We are exposing two of the autofill preferences that will allow toggling between enable and disable autofill for addresses and passwords.  Addresses includes things like email addresses, shipping addresses, phone numbers, and names.  Passwords includes things like username and passwords for login. 

In this document we describe the updated API. We'd appreciate your feedback.


# Description

Autofilling has three components
* Auto-stuffing - filling the corresponding form fields automatically on page load.
* Suggesting - When the user clicks on the form field, drop down suggestions of previously saved forms will be displayed.  
* Populating - When clicking on one of the suggestions, the form data will populate the respective fields. 


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

void SettingsComponent::ToggleAddressAutofill() {
    wil::com_ptr<ICoreWebView2Settings2_2> settings;
    webView->get_Settings(&settings);
    bool enabled;
    settings->get_IsAddressAutofillEnabled(&enabled)
    settings->put_IsAddressAutofillEnabled(!enabled);
}
```

## .NET, WinRT
```c#
webView2Control.NavigationStarting += TogglePasswordAutofill;

private void TogglePasswordAutofill(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs e)
{
    var settings = webView2Control.CoreWebView2.Settings;
    settings.IsPasswordAutofillEnabled = !settings.IsPasswordAutofillEnabled;
}

webView2Control.NavigationStarting += ToggleAddressAutofill;

private void ToggleAddressAutofill(CoreWebView2 sender, CoreWebView2NavigationStartingEventArgs e)
{
    var settings = webView2Control.CoreWebView2.Settings;
    settings.IsAddressAutofillEnabled = !settings.IsAddressAutofillEnabled;
}

```


# Remarks
The behaviour of the two types of autofill preferences behaves differently when toggling between enable and disable.  
If address autofill is enabled:
* Address data will be saved
* Upon clicking on the form field, suggestions will appear
* Clicking on one of the suggestions will populate the corresponding fields
If address autofill is disabled
* No new address data will be saved
* Upon clicking on the form field, suggestions will not appear
If password autofill is enabled
* Password data will be autostuffed
* Upon clicking on the form field, suggestions will appear
* Clicking on one of the suggestions will populate the corresponding fields
* Upon submitting the password data, a save password prompt will be displayed that will give the user the option to save or update the password data. If the user selects `Yes`, the new password data will be saved or updated depending on if they have previously entered password data while password autofill is enabled.  
If password autofill is disabled
* The password data will be autostuffed
* Upon clicking on the form field, suggestions will appear
* Clicking on one of the suggestions will populate the corresponding fields. 
* Upon submitting the password data, no save password prompt will be displayed and no password information is saved or updated. 


# API Notes
See [API Details](#api-details) section below for API reference.


# API Details
```IDL
interface ICoreWebView2Settings2_2

[uuid(f051013e-4bb3-46b2-b6e4-6ee3fe4f43c2), object, pointer_default(unique)]
interface ICoreWebView2Settings2_2 : ICoreWebView2Settings2 {
  /// IsPasswordAutofillEnabled controls whether autofill for passwords is enabled.
  /// The default value is `FALSE`.
  [propget] HRESULT IsPasswordAutofillEnabled([out, retval] BOOL* isPasswordAutofillEnabled);
  // Set the IsPasswordAutofillEnabled property.
  [propput] HRESULT IsPasswordAutofillEnabled([in] BOOL isPasswordAutofillEnabled);

  /// IsAddressAutofillEnabled controls whether autofill for addresses is enabled.
  /// The default value is `TRUE`.
  [propget] HRESULT IsAddressAutofillEnabled([out, retval] BOOL* isAddressAutofillEnabled);
  /// Set the IsAddressAutofillEnabled property.
  [propput] HRESULT IsAddressAutofillEnabled([in] BOOL isAddressAutofillEnabled);
}
```
## .NET and WinRT
```c#
namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
        public bool IsPasswordAutofillEnabled { get; set; };
        public bool IsAddressAutofillEnabled {get; set; };
    }
}

```