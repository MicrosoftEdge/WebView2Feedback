# Background

There currently is no method using WebView2 APIs to customize the default context menu experience. Currently, the only option using WebView2 APIs is to show or disable the default context menu. We have been requested by WebView2 app developers to allow for customization of the context menu experience. This has produced two different customization paths for context menus. The first option is to allow the app developers to create their own context menu UI using data passed from the WebView and the second is to allow app developers to add and remove items from the default context menus.

# Description
We propose two new events for WebView2, `CoreWebView2ContextMenuRequested` that will allow developers to listen to context menus being requested by the end user in the WebView2 and `CoreWebView2CustomItemSelected` that will notify the developer that one of their inserted context menu items was selected. When a context menu is requested in WebView2, the app developer will receive:

1. The list of default ContextMenuItem objects (contains name, Descriptor, kind/type, Shorcut Desc and other properties)
2. The coordinates where the context menu was requested. For instance where the end user right clicked.
3. A selection object that will include the type of context selected, and the appropriate context menu parameter data.

and have the choice to: 

1. Add or remove entries to the default context menu provided by the WebView
2. Use their own UI to display their custom context menu (can either handle the selection on their own or return the selected option to the WebView)

If one of the entries added by the end developer is selected, the CustomMenuItemSelected event will be raised and will include in the event args: 

1. The developer-provided ID for the context menu selected
2. The selection object with the appropriate data for the end developer to use to carry out custom commands

# Examples

## Win32 C++ Add or Remove Entries From WebView Menu

The developer can add or remove entries to the default WebView context menu. For this case, the developer specifies Handled to be false and is able to add or remove items to the collection of context menu items.

 ```cpp
    webview2->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                args->get_MenuItems(&items);
                wil::com_ptr<ICoreWebView2ContextMenuInfo> info;
                args->get_ContextMenuInfo(&info);
                COREWEBVIEW2_CONTEXT_TYPE context;
                info->get_Context(&context);
                args->put_Handled(false);
                UINT32 itemsCount;
                CHECK_FAILURE(items->get_Count(&itemsCount));
                // Removing item
                if (context == COREWEBVIEW2_CONTEXT_TYPE_IMAGE)
                {
                    UINT32 removeIndex = itemsCount;
                    wil::com_ptr<ICoreWebView2ContextMenuItem> current;
                    for(UINT32 i = 0; i < itemsCount; i++) 
                    {
                        CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR desc;
                        CHECK_FAILURE(current->get_Descriptor(&desc));
                        if (desc == COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS)
                        {
                            removeIndex = i;
                        }
                    }
                    if (removeIndex < itemsCount)
                    {
                        CHECK_FAILURE(items->RemoveValueAtIndex(removeIndex));
                    }
                }
                // Adding item
                else if (context == COREWEBVIEW2_CONTEXT_TYPE_LINK)
                {
                    wil::com_ptr<ICoreWebView2Environment> webviewEnvironment;
                    CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                        IID_PPV_ARGS(&webviewEnvironment)));
                    wil::com_ptr<ICoreWebView2ContextMenuItem> newMenuItem;
                    CHECK_FAILURE(webviewEnvironment->CreateContextMenuItem(L"Display Link", L"Shorcut", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL, true, false, &newMenuItem));
                    newMenuItem->add_CustomItemSelected(Callback<ICoreWebView2CustomItemSelectedEventHandler>(
                        [this, info](
                            ICoreWebView2* sender,
                            IUnknown* args)
                            {
                                wil::unique_cotaskmem_string linkUrl;
                                info->get_LinkUrl(&linkUrl);
                                m_appWindow->RunAsync([this, linkUrl]()
                                {
                                MessageBox(
                                    m_appWindow->GetMainWindow(), linkUrl,
                                    L"Display Link", MB_OK);
                                });
                                return S_OK;
                            })
                            .Get(),
                    &m_customItemSelectedToken);
                    CHECK_FAILURE(items->AddValueAtIndex(itemsCount, newMenuItem.get()));
                }
                return S_OK;
            })
            .Get(),
        &m_contextMenuRequestedToken);
```

## Win32 C++ Use Data to Display Custom Context Menu

The developer can use the data provided in the Event arguments to display a custom context menu with entries of their choice. For this case, the developer specifies Handled to be true and requests a deferral. Deferral of this event should be completed when the user selects a context menu item (either the app developer will handle the case, or can return the selected option to the WebView) or when the end user dismisses the context menu by clicking outside of the context menu for example.

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

                    UINT32 itemsCount;
                    CHECK_FAILURE(items->get_Count(&itemsCount));

                    HMENU hPopupMenu = CreatePopupMenu();
                    wil::com_ptr<ICoreWebView2ContextMenuItem> current;

                    for (UINT32 i = 0; i < itemsCount; i++) 
                    {
                        CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                        wil::unique_cotaskmem_string name;
                        CHECK_FAILURE(current->get_Name(&name));
                        UINT32 command_id;
                        CHECK_FAILURE(current->get_CommandId(&command_id));
                        InsertMenu(hPopupMenu, 0, MF_BYPOSITION | MF_STRING, command_id, name);
                    }
                    HWND hWnd;
                    m_appWindow->GetWebViewController()->get_ParentWindow(&hWnd);
                    SetForegroundWindow(hWnd);
                    wil::com_ptr<ICoreWebView2ContextMenuInfo> parameters;
                    args->get_ContextMenuInfo(&parameters);
                    POINT locationInControlCoordinates;
                    POINT locationInScreenCoordinates;
                    CHECK_FAILURE(parameters->get_Location(&locationInControlCoordinates));
                    // get_Location returns coordinates in relation to upper left Bounds of the WebView2.Controller. Will need to convert to Screen coordinates to display the popup menu in the correct location.
                    ConvertToScreenCoordinates(locationInControlCoordinates, &locationInScreenCoordinates);
                    UINT32 selectedCommand = TrackPopupMenu(hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD, locationInScreenCoordinates.x, locationInScreenCoordinates.y, 0, hWnd, NULL);
                    CHECK_FAILURE(args->put_SelectedCommand(selectedCommand));
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
## .Net/ WinRT Add or Remove Entries From WebView Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        IList<CoreWebView2ContextMenuItem> menuList = args.MenuItems;
        CoreWebView2ContextType context = args.ContextMenuInfo.context;
        args.Handled = false;
        if (context == CoreWebView2ContextType.Image)
        {
            // removes the last item in the collection
            menuList.RemoveAt(menuList.Count - 1);
        }
        else if (context == CoreWebView2ContextType.Link)
        {
            // add new item to end of collection
            CoreWebView2ContextMenuItem newItem = webView.CoreWebView2.Environment.CreateContextMenuItem(
                "Display Link", "Shorcut", null, CoreWebView2ContextMenuItemKind.Normal,1, 0);
                newItem.CustomItemSelected += delegate (object send, Object ex)
                {
                    string linkUrl = args.ContextMenuInfo.LinkUrl;
                    MessageBox.Show(linkUrl, "Display Link", MessageBoxButton.YesNo);
                }
            menuList.Insert(menuList.Count, newItem);
        }
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
                CoreWebView2ContextType context = args.ContextMenuInfo.context;
                args.Handled = true;
                ContextMenu cm = this.FindResource("ContextMenu") as ContextMenu;
                cm.Items.Clear();
                for (int i = 0; i < menuList.Count; i ++)
                {
                    CoreWebView2ContextMenuItem current = menuList[i];
                    MenuItem newItem = new MenuItem();
                    newItem.Header = current.Name;
                    newItem.Click += (s, ex) => args.SelectedCommand = current.CommandId;
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
    interface ICoreWebView2ContextMenuInfo;
    interface ICoreWebView2ContextMenuRequestedEventArgs;
    interface ICoreWebView2ContextMenuRequestedEventHandler;
    interface ICoreWebView2CustomItemSelectedEventHandler;

    /// Defines the Context Menu Items.
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR
    {
        /// Context menu item for Custom action (Developer inserted context menu item).
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUSTOM,

        /// Context menu item for an Extension-inserted item.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EXTENSION,

        /// Context menu items for Spellcheck action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SPELLCHECK_SUGGESTION,

        /// Context menu item for "Back" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_BACK,

        /// Context menu item for "Forward" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_FORWARD,

        /// Context menu item for "Reload" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_RELOAD,
        
        /// Context menu item for "Save as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_AS,

        /// Context menu item for "Print" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PRINT,

        /// Context menu item for "Creating a QR code" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CREATE_QR_CODE,

        /// Context menu item for "Inspect" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_INSPECT,

        /// Context menu item for "Emoji menu" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EMOJI,

        /// Context menu item for "Redo" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_REDO,

        /// Context menu item for "Undo" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_UNDO,

        /// Context menu item for "Cut" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUT,

        /// Context menu item for "Copy" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY,

        /// Context menu item for "Paste" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE,

        /// Context menu item for "Paste as plain text" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE_AS_PLAIN_TEXT,

        /// Context menu item for "Select all" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SELECT_ALL,

        /// Context menu item for "Open link in new window" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OPEN_LINK_NEW_WINDOW,

        /// Context menu item for "Save link as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_LINK_AS,

        /// Context menu item for "Copy link" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_LINK,

        /// Context menu item for "Save image as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS,

        /// Context menu item for "Copy image" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE,

        /// Context menu item for "Copy image link" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE_LINK,

        /// Context menu item for "Save media as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_MEDIA_AS,

        /// Context menu item for other commands not corresponding with any of the enums above.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OTHER,
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR;
    
    /// Indicates the type of selected context.
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_TYPE
    {
        /// Indicates that the context menu was created for the page.
        COREWEBVIEW2_CONTEXT_TYPE_PAGE,

        /// Indicates that the context menu was created for a frame.
        COREWEBVIEW2_CONTEXT_TYPE_FRAME,

        /// Indicates that the context menu was created for a selection.
        COREWEBVIEW2_CONTEXT_TYPE_SELECTION,

        /// Indicates that the context menu was created for a link.
        COREWEBVIEW2_CONTEXT_TYPE_LINK,

        /// Indicates that the context menu was created for an editable component.
        COREWEBVIEW2_CONTEXT_TYPE_EDITABLE,
        
        /// Indicates that the context menu was created for audio.
        COREWEBVIEW2_CONTEXT_TYPE_AUDIO,

        /// Indicates that the context menu was created for an image.
        COREWEBVIEW2_CONTEXT_TYPE_IMAGE,
        
        /// Indicates that the context menu was created for a video.
        COREWEBVIEW2_CONTEXT_TYPE_VIDEO,
    } COREWEBVIEW2_CONTEXT_TYPE;

    /// Indicates the menu item type.
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND
    {
        /// A normal menu item kind, can be enabled or not.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL,

        /// A checkbox. Can be checked or enabled.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECKBOX,

        /// A radio button type, can be checked or enabled.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_RADIO,

        /// A separator type, used to visually differentiate sections of context menu items.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR,

        /// A submenu type, will contain a list of its children menu items.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU,
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND;

    /// Represents a context menu item of a context menu displayed by WebView.
    [uuid(7aed49e3-a93f-497a-811c-749c6b6b6c65), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItem : IUnknown
    {
        /// Get the label displayed for the ContextMenuItem, will already have been translated by the WebView.
        [propget] HRESULT Label([out, retval] LPWSTR* value);

        /// Get the name for the ContextMenuItem, will be an unlocalized string to allow for 
        /// distinguishing between the extension and 'other' items since multiple items can
        /// have those descriptors.
        [propget] HRESULT Name([out, retval] LPWSTR* value);

        /// Get the descriptor for the ContextMenuItem.
        [propget] HRESULT Descriptor([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR* value);

        /// Get the Command ID for the context menu item, this ID is unique and will be used by the app to return which specific item was selected.
        [propget] HRESULT CommandId([out, retval] UINT32* value);

        /// Get the shortcut for the ContextMenuItem.
        [propget] HRESULT Shortcut([out, retval] LPWSTR* value);

        /// Get the Icon for the ContextMenuItem in PNG format in the form of an IStream.
        [propget] HRESULT Icon([out, retval] IStream** value);

        /// Returns the menu item kind.
        [propget] HRESULT Kind([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND* value);

        /// Returns if the menu item is enabled.
        [propget] HRESULT IsEnabled([out, retval] BOOL* value);

        /// Returns if the menu item is checked, used for checkbox or radio types.
        [propget] HRESULT IsChecked([out, retval] BOOL* value);

        /// Returns the list of Children menu items if the kind is submenu.
        [propget] HRESULT Children([out, retval] ICoreWebView2ContextMenuItemCollection** value);
        
        /// Add an event handler for the CustomItemSelected event.
        /// CustomItemSelected event is raised when the user selects a custom context menu item that
        /// was inserted by the developer and is not part of the default WebView context menu.
        HRESULT add_CustomItemSelected(
            [in] ICoreWebView2CustomItemSelectedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with add_CustomItemSelected.
        HRESULT remove_CustomItemSelected(
            [in] EventRegistrationToken token);
    }

    /// Collection of ContextMenuItem objects.
    [uuid(f562a2f5-c415-45cf-b909-d4b7c1e276d3), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItemCollection : IUnknown
    {
        /// The number of ContextMenuItems contained in the ICoreWebView2ContextMenuItemCollection.
        [propget] HRESULT Count([out, retval] UINT32* value);

        /// Gets the ContextMenuItem at the given index.
        HRESULT GetValueAtIndex([in] UINT32 index,
            [out, retval] ICoreWebView2ContextMenuItem** value);

        /// Removes ContextMenuItem at the specified index.
        HRESULT RemoveValueAtIndex([in] UINT32 index);

        /// Will insert the new ContextMenuItem at the index specified.
        HRESULT AddValueAtIndex([in] UINT32 index, [in] ICoreWebView2ContextMenuItem* value);
    }

    [uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
    interface ICoreWebView2_4 : ICoreWebView2_3
    {
        /// Add an event handler for the `ContextMenuRequested` event.
        /// ContextMenuRequested event is raised when a context menu is requested by the user
        /// and the WebView hasn't disabled context menu usage.
        /// The host can create their own context menu with the information provided in the event
        /// or can add items to or remove items from WebView context menu.
        /// If the host doesn't handle the event, Webview will display the default context menu.
        HRESULT add_ContextMenuRequested(
            [in] ICoreWebView2ContextMenuRequestedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with add_ContextMenuRequested.
        HRESULT remove_ContextMenuRequested(
            [in] EventRegistrationToken token);
    }

    /// A continuation of the ICoreWebView2Environment interface.
    [uuid(04d4fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2Environment : IUnknown
    {
        /// Create a ContextMenuItem object used for developers to insert new items into the WebView context menu.
        /// The IsChecked property will only be used if the menu item type is radio or checkbox.
        HRESULT CreateContextMenuItem(
            [in] LPCWSTR label,
            [in] LPCWSTR shorctut,
            [in] IStream* iconStream,
            [in] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind,
            [in] BOOL isEnabled,
            [in] BOOL isChecked,
            [out, retval] ICoreWebView2ContextMenuItem ** item);
    }

    [uuid(04d3fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventHandler : IUnknown
    {
        /// Called to provide the event args when a context menu is invoked on WebView2 element.
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2ContextMenuRequestedEventArgs* args);
    }

    [uuid(49e1d0bc-fe9e-4481-b7c2-32324aa21998), object, pointer_default(unique)]
    interface ICoreWebView2CustomItemSelectedEventHandler : IUnknown
    {
        /// Called to provide the event args when the end user selects on an dev-inserted context menu item.
        HRESULT Invoke(
            [in] ICoreWebView2ContextMenuItem* sender, [in] IUnknown* args);
    }

    /// Event args for the ContextMenuRequested event. Will contain the selection information and a collection of all of the default context menu items that the default WebView2 menu would show and allows the app to draw its own context menu or add/remove from the default context menu.
    [uuid(a1d309ee-c03f-11eb-8529-0242ac130003), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventArgs : IUnknown
    {
        /// The list of ContextMenuItem objects. The end developer may modify the contents of this collection.
        [propget] HRESULT MenuItems([out, retval] ICoreWebView2ContextMenuItemCollection ** value);

        /// Information about the requested context menu.
        [propget] HRESULT ContextMenuInfo([out, retval] ICoreWebView2ContextMenuInfo ** value);

        /// Sets the selected command for the WebView to execute. If user clicks away from context menu, this value will remain 0, meaning no selection occured.
        [propput] HRESULT SelectedCommand([in] UINT32 value);

        /// Returns the selected command. This value defaults to 0, which means there was no selection and the context menu was canceled.
        [propget] HRESULT SelectedCommand([out, retval] UINT32* value);

        /// Sets whether the `ContextMenuRequested` event is handled by host.  If this
        /// is `FALSE`, the WebView will draw its own context menu UI.  If set to `TRUE` 
        /// the Webview will not open its own context menu and will wait on the app to 
        /// return the item the user selected.
        /// The default value is `FALSE`.
        [propput] HRESULT Handled([in] BOOL value);

        /// Gets whether the `ContextMenuRequested` event is handled by host.
        [propget] HRESULT Handled([out, retval] BOOL* value);

        /// Returns an `ICoreWebView2Deferral` object. Use this operation to
        /// complete the event when a user selects a context menu item from custom menu
        /// or clicks outside from context menu.
        HRESULT GetDeferral([out, retval] ICoreWebView2Deferral ** deferral);
    }

    /// Context Menu Parameters including the location of the request, the context selected and the appropriate data associated with the context menu request.
    [uuid(b8611d99-eed6-4f3f-902c-a198502ad472), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuInfo : IUnknown
    {
        /// The coordinates where the context menu is requested occured in relation to the upper left corner of the webview bounds.
        [propget] HRESULT Location([out, retval] POINT* value);

        /// The type of context that the user selected.
        [propget] HRESULT Context([out, retval] COREWEBVIEW2_CONTEXT_TYPE* value);

        /// The url of the page.
        [propget] HRESULT PageUrl([out, retval] LPWSTR * value);

        /// The url of the frame (if context menu invoked on a frame, null otherwise).
        [propget] HRESULT FrameUrl([out, retval] LPWSTR * value);

        /// The source url of element (if context menu invoked on media element, null otherwise).
        [propget] HRESULT SourceUrl([out, retval] LPWSTR * value);

        /// The url of the link (if context menu invoked on a link, null otherwise).
        [propget] HRESULT LinkUrl([out, retval] LPWSTR * value);

        /// The text of the link (if context menu invoked on a link, null otherwise).
        [propget] HRESULT LinkText([out, retval] LPWSTR * value);

        /// The selected text (if context menu was invoked on a selection, null otherwise).
        [propget] HRESULT SelectionText([out, retval] LPWSTR * value);
    }
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2ContextMenuItem;
    runtimeclass CoreWebView2ContextMenuInfo;
    runtimeclass CoreWebView2ContextMenuRequestedEventArgs;
    
    enum CoreWebView2ContextMenuItemDescriptor
    {
        Custom = 0,
        Extension = 1,
        SpellcheckSuggestion = 2,
        Back = 3,
        Forward = 4,
        Reload = 5,
        SaveAs = 6,
        Print = 7,
        CreateQrCode = 8,
        Inspect = 9,
        Emoji = 10,
        Redo = 11,
        Undo = 12,
        Cut = 13,
        Copy = 14,
        Paste = 15,
        PasteAsPlainText = 16,
        SelectAll = 17,
        OpenLinkNewWindow = 24,
        SaveLinkAs = 25,
        CopyLink = 26,
        SaveImageAs = 27,
        CopyImage = 28,
        CopyImageLink = 29,
        SaveMediaAs = 30,
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
        CoreWebView2ContextMenuInfo ContextMenuInfo { get; }
        IVector<CoreWebView2ContextMenuItem> MenuItems { get; }
        CoreWebView2ContextMenuItem SelectedCommand { get; set; }
        Windows.Foundation.Deferral GetDeferral();
    };
    
    runtimeclass CoreWebView2ContextMenuInfo
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
        String Label { get; }
        String Name { get; }
        String Shortcut { get; }
        Int32 CommandId { get; }
        CoreWebView2ContextMenuItemDescriptor Descriptor { get; }
        Stream Icon { get; }
        CoreWebView2ContextMenuItemKind Kind { get; }
        Boolean IsEnabled { get; }
        Boolean IsChecked { get; }
        IVector<CoreWebView2ContextMenuItem> Children { get; }

        event Windows.Foundation.TypedEventHandler<CoreWebView2ContextMenuItem, Object> CustomItemSelected;
    };

    runtimeclass CoreWebView2Environment
    {
        public CoreWebView2ContextMenuItem CreateContextMenuItem(
            String Label,
            String Shortcut,
            Stream Icon,
            CoreWebView2ContextMenuItemKind Kind,
            Boolean IsEnabled,
            Boolean IsChecked);
    };

    runtimeclass CoreWebView2
    {
        ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ContextMenuRequestedEventArgs> ContextMenuRequested;
    };
}
```

# Appendix
