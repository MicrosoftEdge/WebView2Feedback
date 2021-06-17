# Background

There currently is no method using WebView2 APIs to customize the default context menu experience. Currently, the only option using WebView2 APIs is to show or disable the default context menu. We have been requested by WebView2 app developers to allow for customization of the context menu experience. This has produced two different customization paths for context menus. The first option is to allow the app developers to create their own context menu UI using data passed from the browser and the second is to allow app developers to add and remove items from the default context menus.

# Description
We propose two new events for WebView2, `CoreWebView2ContextMenuRequested` that will allow developers to listen to context menus being requested by the end user in the WebView2 and `CoreWebView2CustomItemSelected` that will notify the developer that one of their inserted context menu items was selected. When a context menu is requested in WebView2, the app developer will receive:

1. The list of default ContextMenuItem objects (contains name, Descriptor, kind/type, Shorcut Desc and other properties)
2. The coordinates where the context menu was requested. For instance where the end user right clicked.
3. A selection object that will include the type of context selected, and the appropriate context menu parameter data.

and have the choice to: 

1. Add or remove entries to the default context menu provided by the browser
2. Use their own UI to display their custom context menu (can either handle the selection on their own or return the selected option to the browser)

If one of the entries added by the end developer is selected, the CustomMenuItemSelected event will be raised and will include in the event args: 

1. The developer-provided ID for the context menu selected
2. The selection object with the appropriate data for the end developer to use to carry out custom commands

# Examples

## Win32 C++ Add or Remove Entries From Browser Menu

The developer can add or remove entries to the default browser context menu. For this case, the developer specifies Handled to be false and is able to add or remove items to the collection of context menu items.

 ```cpp
    webview2->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                args->get_MenuItems(&items);
                wil::com_ptr<ICoreWebView2ContextMenuParams> params;
                args->get_ContextMenuParams(&params);
                COREWEBVIEW2_CONTEXT_TYPE context;
                params->get_Context(&context);
                args->put_Handled(false);
                UINT32 itemsCount;
                CHECK_FAILURE(items->get_Count(&menuCollectionCount));

                // Removing item
                if (context == COREWEBVIEW2_CONTEXT_TYPE_IMAGE)
                {
                    UINT32 removeIndex = -1;
                    wil::com_ptr<ICoreWebView2ContextMenuItem> current;
                    for(UINT32 i = 0; i < menuCollectionCount; i++) {
                        CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR desc;
                        CHECK_FAILURE(current->get_Descriptor(&desc));
                        if(desc == COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS){
                            removeIndex = i;
                        }
                    }
                    if(removeIndex > -1){
                        CHECK_FAILURE(items->RemoveValueAtIndex(removeIndex));
                    }
                }
                /// Adding item
                else if (context == COREWEBVIEW2_CONTEXT_TYPE_LINK)
                {
                    wil::com_ptr<ICoreWebView2Environment> webviewEnvironment;
                    m_appWindow->GetWebViewEnvironment()->QueryInterface(
                        IID_PPV_ARGS(&webviewEnvironment));
                    wil::com_ptr<ICoreWebView2ContextMenuItem> newMenuItem;
                    CHECK_FAILURE(webviewEnvironment->CreateContextMenuItem(
                        1, L"Display Link", L"Shorcut", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL, false, &newMenuItem));
                        1, L"Display Link", L"Shorcut", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL, false, &newMenuItem);    
                    CHECK_FAILURE(items->AddValueAtIndex(menuCollectionCount, newMenuItem.get()));
                }
                return S_OK;
            })
            .Get(),
        &m_contextMenuRequestedToken);
    
    /// If newly inputted item (with CreateContextMenuItem) was selected
    webview2->add_CustomItemSelected(
        Callback<ICoreWebView2CustomItemSelectedEventHandler>(
              [this](
                ICoreWebView2* sender,
                ICoreWebView2CustomItemSelectedEventArgs* args)
            {
                UINT32 customId;
                args->get_SelectedId(&customId);
                wil::com_ptr<ICoreWebView2ContextMenuParams> params;
                args->get_ContextMenuParams(&params);
                switch(customId)
                {
                    case 1:
                        wil::unique_cotaskmem_string linkUrl;
                        params->get_LinkUrl(&linkUrl);
                        MessageBox(
                            nullptr,
                            linkUrl,
                            L"Display Link", MB_OK);
                    break;
                };
                return S_OK;
            })
            .Get(),
        &m_customItemSelectedToken);
```

## Win32 C++ Use Data to Display Custom Context Menu

The developer can use the data provided in the Event arguments to display a custom context menu with entries of their choice. For this case, the developer specifies Handled to be true and requests a deferral. Deferral of this event should be completed when the user selects a context menu item (either the app developer will handle the case, or can return the selected option to the browser) or when they click on the screen (effectively closing the menu).

 ```cpp
    webview2->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                auto showMenu = [this, args]
                {
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                    CHECK_FAILURE(args->get_MenuItems(&items));
                    args->put_Handled(true);

                    UINT32 menuCollectionCount;
                    CHECK_FAILURE(certificateCollection->get_Count(&menuCollectionCount));

                    HMENU hPopupMenu = CreatePopupMenu();
                    wil::com_ptr<ICoreWebView2ContextMenuItem> current;

                    for(UINT32 i = 0; i < menuCollectionCount; i++) {
                        CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                        wil::unique_cotaskmem_string name;
                        wil::unique_cotaskmem_string shortcut;
                        CHECK_FAILURE(current->get_Name(&name));
                        CHECK_FAILURE(current->get_Shortcut(&shortcut));
                        InsertMenu(hPopupMenu, 0, MF_BYPOSITION | MF_STRING, i, name + "-" + shortcut);
                    }
                    HWND hWnd;
                    m_appWindow->GetWebViewController()->get_ParentWindow(&hWnd);
                    SetForegroundWindow(hWnd);
                    wil::com_ptr<ICoreWebView2ContextMenuParams> params;
                    args->get_ContextMenuParams(&params);
                    POINT p;
                    POINT final_p;
                    CHECK_FAILURE(params->get_Location(&p));
                    /// get_Location returns coordinates in relation to upper left Bounds of the WebView2.Controller. Will need to convert to Screen coordinates to display the popup menu in the correct location.
                    ConvertToScreenCoordinates(p, &final_p);
                    UINT32 selectedIndex = TrackPopupMenu(hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD, final_p.x, final_p.y, 0, hWnd, NULL);
                    wil::com_ptr<ICoreWebView2ContextMenuItem> selectedItem;
                    items->GetValueAtIndex(selectedIndex, &selectedItem);
                    CHECK_FAILURE(args->put_SelectedItem(selectedItem.get()));
                }
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));
                m_sampleWindow->RunAsync([deferral, showMenu]() {
                    showMenu();
                    CHECK_FAILURE(deferral->Complete());
                });
                return S_OK;
            }).Get(),
        &m_contextMenuRequestedToken);
```
## .Net/ WinRT Add or Remove Entries From Browser Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        IList<CoreWebView2ContextMenuItem> menuList = args.MenuItems;
        CoreWebView2ContextType context = args.ContextMenuParams.context;
        args.Handled = false;
        if (context == CoreWebView2ContextType.Image)
        {
            /// removes the last item in the collection
            menuList.RemoveAt(menuList.Count - 1);
        }
        else if (context == CoreWebView2ContextType.Link)
        {
            /// add new item to end of colelction
            CoreWebView2ContextMenuItem newItem = webView.CoreWebView2.Environment.CreateContextMenuItem(
                1, "Display Link", "Shorcut", null, CoreWebView2ContextMenuItemKind.Normal, 0);
            menuList.Insert(menuList.Count, newItem);
        }
    };
    // CustomItemSelected event notified when a dev-inserted context menu item is selected
    webView.CoreWebView2.CustomItemSelected += delegate (object sender, CoreWebView2CustomItemSelectedEventArgs args)
    {
        UInt32 customId = args.SelectedId;
        CoreWebView2ContextMenuParams parameters = args.ContextMenuParams;
        switch (customId)
        {
            case 1:
                string linkUrl = parameters.LinkUrl;
                MessageBox.Show(linkUrl, "Display Link", MessageBoxButton.YesNo);
            break;
        };
    };
``` 

## .Net/ WinRT Use Data to Display Custom Context Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        CoreWebView2Deferral deferral = args.GetDeferral();
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            using (deferral)
            {
                IList<CoreWebView2ContextMenuItem> menuList = args.MenuItems;
                CoreWebView2ContextType context = args.ContextMenuParams.context;
                args.Handled = true;
                ContextMenu cm = this.FindResource("ContextMenu") as ContextMenu;
                cm.Items.Clear();
                for(int i = 0; i < menuList.Count; i ++){
                    CoreWebView2ContextMenuItem current = menuList[i];
                    MenuItem newItem = new MenuItem();
                    newItem.Header = current.Name;
                    newItem.Click += (s, ex) => args.SelectedItem = current;
                    cm.Items.Add(newItem);
                }
                cm.IsOpen = true;
            }
        }, null);
    };
```
# Remarks

# API Notes

# API Details
 ```cpp
    interface ICoreWebView2_4;
    interface ICoreWebView2Environment;
    interface ICoreWebView2ContextMenuItem;
    interface ICoreWebView2ContextMenuItemCollection;
    interface ICoreWebView2ContextMenuParams;
    interface ICoreWebView2ContextMenuRequestedEventArgs;
    interface ICoreWebView2ContextMenuRequestedEventHandler;
    interface ICoreWebView2CustomItemSelectedEventArgs;
    interface ICoreWebView2CustomItemSelectedEventHandler;

    /// Defines the Context Menu Items
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR
    {
        /// Custome type, any of the new context menu items created by the app developer
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUSTOM,

        /// Extenstion command, any of the context menu items created by a browser extension
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EXTENSION,

        /// Context menu items that provide spelling suggestions
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_MISSPELLED,

        /// Context menu item for going back to previous page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_BACK,

        /// Context menu item for going to the next page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_FORWARD,

        /// Context menu item for reloading the current page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_RELOAD,
        
        /// Context menu item for saving the page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_AS,

        /// Context menu item for printing 
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PRINT,

        /// Context menu item for creating a QR code for the page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_QR,

        /// Context menu item for inspecting the page
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_INSPECT,

        /// Context menu item for an emoji
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EMOJI,

        /// Context menu item for redo
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_REDO,

        /// Context menu item for undo
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_UNDO,

        /// Context menu item for cut
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUT,

        /// Context menu item for copy
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY,

        /// Context menu item for paste
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE,

        /// Context menu item for pasting as plain text
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE_AS_PLAIN_TEXT,

        /// Context menu item for select all
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SELECT_ALL,

        /// Context menu item for spellcheck menu (submenu type)
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SPELLCHECK_MENU,

        /// Context menu item for spellcheck when entering text
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SPELLCHECK_WHILE_TYPING,

        /// Context menu item for writing direction menu (submenu type)
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_WRITING_DIRECTION_MENU,

        /// Context menu item for writing direction default
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_WRITING_DIRECTION_DEFAULT,

        /// Context menu item for writing direction left to right
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_WRITING_DIRECTION_LTR,

        /// Context menu item for writing direction right to left
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_WRITING_DIRECTION_RTL,

        /// Context menu item for openning link in new window
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OPEN_LINK_NEW_WINDOW,

        /// Context menu item for saving the link
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_LINK_AS,

        /// Context menu item for copying the link
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_LINK,

        /// Context menu item for saving an image
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS,

        /// Context menu item for copying an image
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE,

        /// Context menu item for copying the link to an image
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE_LINK,

        /// Context menu item for saving audio and video items
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_MEDIA_AS,

        /// Other command, any of the context menu items not falling in any of the enums above
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OTHER,
        
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR;
    
    /// Indicates the context selection type
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_TYPE
    {
        /// Indicates that the context menu was invoked on the page.
        COREWEBVIEW2_CONTEXT_TYPE_PAGE,

        /// Indicates that the context menu was invoked on a frame.
        COREWEBVIEW2_CONTEXT_TYPE_FRAME,

        /// Indicates that the context menu was invoked on a selection.
        COREWEBVIEW2_CONTEXT_TYPE_SELECTION,

        /// Indicates that the context menu was invoked on a link.
        COREWEBVIEW2_CONTEXT_TYPE_LINK,

        /// Indicates that the context menu was invoked on an editable component
        COREWEBVIEW2_CONTEXT_TYPE_EDITABLE,
        
        /// Indicates that the context menu was invoked on audio.
        COREWEBVIEW2_CONTEXT_TYPE_AUDIO,

        /// Indicates that the context menu was invoked on an image.
        COREWEBVIEW2_CONTEXT_TYPE_IMAGE,
        
        /// Indicates that the context menu was invoked on a video
        COREWEBVIEW2_CONTEXT_TYPE_VIDEO,

    } COREWEBVIEW2_CONTEXT_TYPE;

    /// Indicates the menu item type
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND
    {
        /// A normal menu item kind, can be enabled or not.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL,

        /// A checkbox. Can be checked or enabled
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECKBOX,

        /// A radio button type, can be checked or enabled
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_RADIO,

        /// A separator type, used to visually differentiate sections of context menu items. Can not be disabled or checked but can be deleted from the list.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR,

        /// A submenu type, will contain a list of its children
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU,

    } COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND;

    /// Context Menu Items displayed by the Edge browser, holds the properties of a context menu item
    [uuid(7aed49e3-a93f-497a-811c-749c6b6b6c65), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItem : IUnknown
    {
        /// Get the name displayed for the Context Menu Item, will already have been translated by the browser
        [propget] HRESULT Name([out, retval] LPWSTR* value);

        /// Get the descriptor for the Context Menu Item
        [propget] HRESULT Descriptor([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR* value);

        /// Get the shortcut for the Context Menu Item, the functionality will already exist in the browser code
        [propget] HRESULT Shortcut([out, retval] LPWSTR* value);

        /// Get the Icon for the ContextMenuItem in the form of IStream
        [propget] HRESULT Icon([out, retval] IStream** value);

        /// Returns the menu item kind
        [propget] HRESULT Kind([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND* value);

        /// Returns if the menu item is visible
        [propget] HRESULT IsVisible([out, retval] BOOL* value);

        /// Returns if the menu item is enabled
        [propget] HRESULT IsEnabled([out, retval] BOOL* value);

        /// Returns if the menu item is checked, used for checkbox or radio types
        [propget] HRESULT IsChecked([out, retval] BOOL* value);

        /// Returns the list of Children menu items if the kind is submenu
        [propget] HRESULT Children([out, retval] ICoreWebView2ContextMenuItemCollection** value);

    }

    /// Collection of ContextMenuItem objects 
    [uuid(f562a2f5-c415-45cf-b909-d4b7c1e276d3), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItemCollection : IUnknown
    {
        /// The number of context menu items contained in the ICoreWebView2ContextMenuItemCollection
        [propget] HRESULT Count([out, retval] UINT32* value);

        /// Gets the context menu item at the given index.
        HRESULT GetValueAtIndex([in] UINT32 index,
            [out, retval] ICoreWebView2ContextMenuItem** value);

        /// Removes ContextMenuItem at the specified index
        HRESULT RemoveValueAtIndex([in] UINT32 index);

        /// Will insert the new ContextMenuItem at the index specified
        HRESULT AddValueAtIndex([in] UINT32 index, [in] ICoreWebView2ContextMenuItem* value);
    }

    [uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
    interface ICoreWebView2_4 : ICoreWebView2_3
    {
        /// Add an event handler for the ContextMenuRequested event.
        /// ContextMenuRequested event is raised when a context menu is requested by the user
        /// and the browser hasn't disabled context menu usage.
        /// The host can use their own UI to create their own context menu using
        /// the data provided in the API or can add to / remove from the default
        /// context menu. If the host doesn't handle the event, Webview will
        /// display the original context menu.

        HRESULT add_ContextMenuRequested(
            [in] ICoreWebView2ContextMenuRequestedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with add_ContextMenuRequested.
        HRESULT remove_ContextMenuRequested(
            [in] EventRegistrationToken token);

        /// Add an event handler for the CustomItemSelected event.
        /// CustomItemSelected event is raied when the user selects a context menu item that
        /// was inserted by the developer and is not part of the default browser context menu.
        /// The developer will include the logic for the appropriate data in this event handler.

        HRESULT add_CustomItemSelected(
            [in] ICoreWebView2CustomItemSelectedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with add_CustomItemSelected.
        HRESULT remove_CustomItemSelected(
            [in] EventRegistrationToken token);
        
    }

    /// A continuation of the ICoreWebView2Environment interface.
    [uuid(04d4fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2Environment : IUnknown
    {
        /// Create a ContextMenuItem object used for developers to insert new items into the default browser context menu.
        /// The Enabled and visible properties will default to true and the IsChecked property will only be used if the 
        /// menu item type is radio or checkbox.
        HRESULT CreateContextMenuItem(
            [in] UINT32 customItemID,
            [in] LPCWSTR displayName,
            [in] LPCWSTR shorctut,
            [in] IStream* iconStream,
            [in] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind,
            [in] BOOL isChecked,
            [out, retval] ICoreWebView2ContextMenuItem ** item);
    }

    [uuid(04d3fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventHandler : IUnknown
    {
        /// Called to provide the event args when a context menu is invoked on WebView2 element
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2ContextMenuRequestedEventArgs* args);
    }

    [uuid(49e1d0bc-fe9e-4481-b7c2-32324aa21998), object, pointer_default(unique)]
    interface ICoreWebView2CustomItemSelectedEventHandler : IUnknown
    {
        /// Called to provide the event args when the end user selects on an dev-inserted context menu item
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2CustomItemSelectedEventArgs* args);
    }

    /// Event args for the ContextMenuRequested event. Will contain the selection information and a collection of all of the default context menu items that the default WebView2 menu would show and allows the app to draw its own context menu or add/ remove from the default context menu.
    [uuid(a1d309ee-c03f-11eb-8529-0242ac130003), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventArgs : IUnknown
    {
        /// The list of ContextMenuItem objects. The end developer may modify the contents of this collection.
        [propget] HRESULT MenuItems([out, retval] ICoreWebView2ContextMenuItemCollection ** value);

        /// Contains the data regarding the selection
        [propget] HRESULT ContextMenuParameters([out, retval] ICoreWebView2ContextMenuParameters ** value);

        /// Returns the selected Context Menu Item
        [propget] HRESULT SelectedItem([out, retval] ICoreWebView2ContextMenuItem ** value);

        /// Sets the Selected Menu Item for the browser to execute the command
        [propput] HRESULT SelectedItem([in] ICoreWebView2ContextMenuItem * value);

        /// Whether the App will draw context menu. False by default, meaning WebView should display default context menu
        /// If set to true, app developer will handle displaying the Context Menu using the data provided.
        [propput] HRESULT Handled([out, retval] BOOL* value);

        /// Sets the Handled property
        [propget] HRESULT Handled([in] BOOL value);

        /// Returns an `ICoreWebView2Deferral` object. Use this operation to
        /// complete the event when a user selects a context menu item from custom menu
        /// or clicks outside from context menu
        HRESULT GetDeferral([out, retval] ICoreWebView2Deferral ** deferral);
    }

    /// Event args for the CustomItemSelected event. Will contain the
    /// context selected by the user, the location of the context menu request and the data of the selection
    [uuid(8d606e57-f8d4-412f-8d69-c2205eabd9ee), object, pointer_default(unique)]
    interface ICoreWebView2CustomItemSelectedEventArgs : IUnknown
    {
        /// Get the ID used when creating the new context menu item
        [propget] HRESULT SelectedId([out, retval] UINT32 * value);

        /// Get the data regarding the selection
        [propget] HRESULT ContextMenuParams([out, retval] ICoreWebView2ContextMenuParams ** value);
    }

    /// Context Menu Parameters including the location of the request, the context selected and the appropriate data associated with the context menu request
    [uuid(b8611d99-eed6-4f3f-902c-a198502ad472), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuParams : IUnknown
    {
        /// The coordinates where the context menu is requested occured in relation to the upper left corner of the webview bounds
        [propget] HRESULT Location([out, retval] POINT* value);

        /// The context that the user selected
        [propget] HRESULT Context([out, retval] COREWEBVIEW2_CONTEXT_TYPE* value);

        /// The url of hte page
        [propget] HRESULT PageUrl([out, retval] LPWSTR * value);

        /// The url of the frame (if context menu invoked on a frame, otherwise null)
        [propget] HRESULT FrameUrl([out, retval] LPWSTR * value);

        /// The source url of element, if context menu invoked on media element
        [propget] HRESULT SourceUrl([out, retval] LPWSTR * value);

        /// The url of the link (if context menu invoked on a link, otherwise null)
        [propget] HRESULT LinkUrl([out, retval] LPWSTR * value);

        /// The text of the link (if context menu invoked on a link, otherwise null)
        [propget] HRESULT LinkText([out, retval] LPWSTR * value);

        /// The selection text if context menu was invoked on a selection
        [propget] HRESULT SelectionText([out, retval] LPWSTR * value);
    }
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2ContextMenuItem;
    runtimeclass CoreWebView2ContextMenuParams;
    runtimeclass CoreWebView2ContextMenuRequestedEventArgs;
    runtimeclass CoreWebView2CustomItemSelectedEventArgs;
    
    enum CoreWebView2ContextMenuItemDescriptor
    {
        Custom = 0,
        Extension = 1,
        Misspelled = 2,
        Back = 3,
        Forward = 4,
        Reload = 5,
        SaveAs = 6,
        Print = 7,
        QR = 8,
        Inspect = 9,
        Emoji = 10,
        Redo = 11,
        Undo = 12,
        Cut = 13,
        Copy = 14,
        Paste = 15,
        PasteAsPlainText = 16,
        SelectAll = 17,
        SpellcheckMenu = 18,
        SpellcheckWhileTyping = 19,
        WritingDirectionMenu = 20,
        WritingDirectionDefault = 21,
        WritingDirectionLtr = 22,
        WritingDirectionRtl = 23,
        OpenLinkNewWindow = 24,
        SaveLinkAs = 25,
        CopyLink = 26,
        SaveImageAs = 27,
        CopyImage = 28,
        CopyImageLink = 29,
        SaveAs = 30,
        Other = 31,
    };

    enum CoreWebView2ContextType
    {
        Page = 0,
        Frame = 1,
        Selection = 2,
        Link = 3,
        Editable = 4,
        Audio = 5,
        Image = 6,
        Video = 7,
    };

    enum CoreWebView2ContextMenuItemKind
    {
        Normal = 0,
        Checkbox = 1,
        Radio = 2,
        Separator = 3,
        Submenu = 4,
    };

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        Boolean Handled { get; set; }
        CoreWebView2ContextMenuParams ContextMenuParams { get; }
        IVector<CoreWebView2ContextMenuItem> MenuItems { get; }
        CoreWebView2ContextMenuItem SelectedItem { get; set; }
        Windows.Foundation.Deferral GetDeferral();
    };

    runtimeclass CoreWebView2CustomItemSelectedEventArgs
    {
        Int32 SelectedId { get; }
        CoreWebView2ContextMenuParams ContextMenuParams { get; }
    };

    runtimeclass CoreWebView2ContextMenuParams
    {
        Point Location { get; }
        CoreWebView2ContextType Context { get; }
        String PageUrl { get; }
        String FrameUrl { get; }
        String SourceUrl { get; }
        String LinkUrl { get; }
        String LinkText { get; }
        String SelectionText { get; }
    };
    
    runtimeclass CoreWebView2ContextMenuItem
    {
        String Name { get; }
        String Shortcut { get; }
        CoreWebView2ContextMenuItemDescriptor Descriptor { get; }
        Stream Icon { get; }
        CoreWebView2ContextMenuItemKind Kind { get; }
        Boolean IsEnabled { get; }
        Boolean IsVisible { get; }
        Boolean IsChecked { get; }
        IVector<CoreWebView2ContextMenuItem> Children { get; }
    };

    runtimeclass CoreWebView2Environment
    {
        public CoreWebView2ContextMenuItem CreateContextMenuItem(
            Int32 CustomItemID,
            String DisplayName,
            String Shortcut,
            Stream Icon,
            CoreWebView2ContextMenuItemKind Kind,
            Boolean IsChecked);
    };

    runtimeclass CoreWebView2
    {
        ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ContextMenuRequestedEventArgs> ContextMenuRequested;
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2CustomItemSelectedEventArgs> CustomItemSelected;
    };
}
```

# Appendix
