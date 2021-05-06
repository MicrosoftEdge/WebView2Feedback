# Background
The WebView2 team has been asked for an API to allow end developers to set the autofill preferences.  We are exposing two of the autofill preferences that will allow enabling and disabling general autofill and password autosave.  General autofill includes things like email addresses, shipping addresses, phone numbers, and names.  Password autosave includes things like usernames and passwords for login.  Password information is not included in general autofill. 

In this document we describe the updated API. We'd appreciate your feedback.


# Description

The components of autofill/autosave are as follows:
* Auto-populate - Populate the corresponding form fields automatically on page load.
* Suggest - When the user clicks on the form field, drop down suggestions of previously saved forms will be displayed.
* Populate - When clicking on one of the suggestions, the form data will populate the respective fields.
* Save/Update prompt - After submitting password information, if IsPasswordAutosaveEnabled is true, a prompt will popup that allows the user to give permission to save or update their password information.

The general autofill setting and password autosave setting behave independently.  Their behavior differs as well. 

The default behavior for the general autofill setting is enabled.  
The default behavior for the password autosave setting is disabled.

| Behavior | IsPasswordAutosaveEnabled = false | IsGeneralAutofillEnabled = false | IsPasswordAutoSaveEnabled = true | IsGeneralAutofillEnabled = true |
|-|-|-|-|-|
| Populate on accepted suggestion | Yes | No | Yes | Yes |
| Suggest | Yes | No | Yes | Yes |
| Auto-populate | Yes | No | Yes | No |
| Save/Update prompt | No | N/A | Yes | N/A |
| Input saved | No | No | Yes | Yes |

The information that is autofilled, auto-populated, or suggested when the IsPasswordAutosaveEnabled is false is previously saved information when the IsPasswordAutosaveEnabled property has been set to true.

# Examples

## Win32 C++
```cpp
void SettingsComponent::TogglePasswordAutofill() {
    wil::com_ptr<ICoreWebView2Settings> settings;
    CHECK_FAILURE(webView->get_Settings(&settings));
    wil::com_ptr<ICoreWebView2Settings4> settings4 = settings.try_query<ICoreWebView2Settings4>();
    if (settings4) 
    {
        bool enabled;
        CHECK_FAILURE(settings4->get_IsPasswordAutofillEnabled(&enabled));
        CHECK_FAILURE(settings4->put_IsPasswordAutofillEnabled(!enabled));
    }
}

void SettingsComponent::ToggleGeneralAutofill() {
    wil::com_ptr<ICoreWebView2Settings> settings;
    CHECK_FAILURE(webView->get_Settings(&settings));
    wil::com_ptr<ICoreWebView2Settings4> settings4 = settings.try_query<ICoreWebView2Settings4>();
    if (settings4) 
    {
        bool enabled;
        CHECK_FAILURE(settings4->get_IsGeneralAutofillEnabled(&enabled));
        CHECK_FAILURE(settings4->put_IsGeneralAutofillEnabled(!enabled));
    } 
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

/// A continuation of the ICoreWebView2Settings interface.
[uuid(cb56846c-4168-4d53-b04f-03b6d6796ff2), object, pointer_default(unique)]
interface ICoreWebView2Settings4 : ICoreWebView2Settings3 {
  /// IsPasswordAutosaveEnabled controls whether autosave for password
  /// information is enabled. The IsPasswordAutosaveEnabled property behaves 
  /// independently of the IsGeneralAutofillEnabled property. When IsPasswordAutosaveEnabled is
  /// false, no new password data is saved and no Save/Update Password prompts are displayed. 
  /// However, if there was password data already saved before disabling this setting, 
  /// then that password information is auto-populated, suggestions are shown and clicking on 
  /// one will populate the fields.
  /// When IsPasswordAutosaveEnabled is true, password information is auto-populated, 
  /// suggestions are shown and clicking on one will populate the fields, new data 
  /// is saved, and a Save/Update Password prompt is displayed. 
  /// The default value is `FALSE`.
  [propget] HRESULT IsPasswordAutosaveEnabled([out, retval] BOOL* value);
  /// Set the IsPasswordAutosaveEnabled property.
  [propput] HRESULT IsPasswordAutosaveEnabled([in] BOOL value);

  /// IsGeneralAutofillEnabled controls whether autofill for information 
  /// like names, street and email addresses, phone numbers, and arbitrary input 
  /// is enabled. This excludes password and credit card information. When 
  /// IsGeneralAutofillEnabled is false, no suggestions appear, and no new information 
  /// is saved. When IsGeneralAutofillEnabled is true, information is saved, suggestions 
  /// appear and clicking on one will populate the form fields.
  /// The default value is `TRUE`.
  [propget] HRESULT IsGeneralAutofillEnabled([out, retval] BOOL* value);
  /// Set the IsGeneralAutofillEnabled property.
  [propput] HRESULT IsGeneralAutofillEnabled([in] BOOL value);
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