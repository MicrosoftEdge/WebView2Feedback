# Background
When opening a PDF file in Edge, there will be a toolbar at the top. The toolbar provides functionality like print, save and adding annotations.
This PDF viewer is also available in WebView2. And we provide this new API to enable end developers to customize the PDF toolbar.


# Description
We add a new `HiddenPdfToolbarItems` property in `CoreWebView2Settings`. This API allows end developers to hide buttons on the PDF toolbar. 
Currently, this API can hide the _save button_, _save as button_, and _print button_.
By default, `HiddenPdfToolbarItems` is equal to `None` which means no button will be hidden.

# Examples
## C++

```cpp
wil::com_ptr<ICoreWebView2> webView;
void SettingsComponent::ToggleHidePdfToolbarButtons()
{
    // Get webView's current settings
    wil::com_ptr<ICoreWebView2Settings> coreWebView2Settings;
    CHECK_FAILURE(webView->get_Settings(&coreWebView2Settings));
    
    COREWEBVIEW2_PDF_TOOLBAR_ITEMS hiddenPdfToolbarItems;
    CHECK_FAILURE(coreWebView2Settings->get_HiddenPdfToolbarItems(&hiddenPdfToolbarItems));
    
    if (hiddenPdfToolbarItems == COREWEBVIEW2_PDF_TOOLBAR_ITEMS::COREWEBVIEW2_PDF_TOOLBAR_ITEMS_NONE)
    {
        CHECK_FAILURE(coreWebView2Settings->put_HiddenPdfToolbarItems(
            COREWEBVIEW2_PDF_TOOLBAR_ITEMS::COREWEBVIEW2_PDF_TOOLBAR_ITEMS_PRINT |
            COREWEBVIEW2_PDF_TOOLBAR_ITEMS::COREWEBVIEW2_PDF_TOOLBAR_ITEMS_SAVE));
    }
    else
    {
        CHECK_FAILURE(coreWebView2Settings->put_HiddenPdfToolbarItems(
            COREWEBVIEW2_PDF_TOOLBAR_ITEMS::COREWEBVIEW2_PDF_TOOLBAR_ITEMS_NONE));
    }
}
```

## C#
```c#
private WebView2 _webView;
void ToggleHidePdfToolbarButtons(object target, ExecutedRoutedEventArgs e)
{
    var coreWebView2Settings = _webView.CoreWebView2.Settings;
    if(coreWebView2Settings.HiddenPdfToolbarItems.HasFlag(CoreWebView2PdfToolbarItems.Save | CoreWebView2PdfToolbarItems.Print))
    {
        WebViewSettings.HiddenPdfToolbarItems = CoreWebView2PdfToolbarItems.None;
    }
    else
    {
        WebViewSettings.HiddenPdfToolbarItems = CoreWebView2PdfToolbarItems.Save;
    }
}
```

# API Notes
See [API Details](#api-details) section below for API reference.

# API Details
## Win32 C++
```c#
/// Specifies the PDF toolbar item types used for the `ICoreWebView2StagingSettings::put_HiddenPdfToolbarItems` method.
[v1_enum]
typedef enum COREWEBVIEW2_PDF_TOOLBAR_ITEMS {

  /// No item

  COREWEBVIEW2_PDF_TOOLBAR_ITEMS_NONE  = 0x0,

  /// The save button

  COREWEBVIEW2_PDF_TOOLBAR_ITEMS_SAVE  = 0x0001,

  /// The print button

  COREWEBVIEW2_PDF_TOOLBAR_ITEMS_PRINT  = 0x0002,

  /// The save as button

  COREWEBVIEW2_PDF_TOOLBAR_ITEMS_SAVE_AS  = 0x0004,


} COREWEBVIEW2_PDF_TOOLBAR_ITEMS;
cpp_quote("DEFINE_ENUM_FLAG_OPERATORS(COREWEBVIEW2_PDF_TOOLBAR_ITEMS);")

[uuid(183e7052-1d03-43a0-ab99-98e043b66b39), object, pointer_default(unique)]
interface ICoreWebView2Settings6 : ICoreWebView2Settings5 {
  /// `HiddenPdfToolbarItems` is used to customize the PDF toolbar items. By default, it is COREWEBVIEW2_PDF_TOOLBAR_ITEMS_NONE and so it displays all of the items.
  /// Changes to this property apply to all CoreWebView2s in the same environment and using the same profile.
  /// Changes to this setting apply only after the next navigation.
  /// \snippet SettingsComponent.cpp ToggleHidePdfToolbarItems

  [propget] HRESULT HiddenPdfToolbarItems([out, retval] COREWEBVIEW2_PDF_TOOLBAR_ITEMS* hidden_pdf_toolbar_items);

  [propput] HRESULT HiddenPdfToolbarItems([in] COREWEBVIEW2_PDF_TOOLBAR_ITEMS hidden_pdf_toolbar_items);
}

```


## .NET and WinRT

```c#
namespace Microsoft.Web.WebView2.Core
{
    //
    // Summary:
    //     Specifies the PDF toolbar item types used for the <see cref="CoreWebView2Settings.HiddenPdfToolbarItems"/>
    [Flags]
    public enum CoreWebView2PdfToolbarItems
    {
        //
        // Summary:
        //     No item. By default the `CoreWebView2Settings.HiddenPdfToolbarItems` equal to this value.
        None = 0,
        
        //
        // Summary:
        //     The save button on PDF toolbar.
        Save = 1,
        
        //
        // Summary:
        //     The print button on PDF toolbar.
        Print = 2,
        
        //
        // Summary:
        //     The save as button on PDF toolbar.
        SaveAs = 4
    }
}

namespace Microsoft.Web.WebView2.Core
{
    public partial class CoreWebView2Settings
    {
       //
       // Summary:
       //     Used to customize the PDF toolbar items. 
       // 
       // Remarks:
       //     By default, it equal to `CoreWebView2PdfToolbarItems.None` which means displays all of the items.
       public CoreWebView2PdfToolbarItems HiddenPdfToolbarItems { get; set; }
    }
}
```
