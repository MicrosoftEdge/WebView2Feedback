# Background

There currently is no method using WebView2 APIs to customize the default context menu experience. Currently, the only option using WebView2 APIs is to show or disable the default context menu. We have been requested by WebView2 app developers to allow for customization of the context menu experience. This has produced two different customization paths for context menus. The first option is to allow the app developers to create their own context menu UI using data passed from the WebView and the second is to allow app developers to add and remove items from the default context menus.

# Description
We propose two new events for WebView2, `CoreWebView2ContextMenuRequested` that will allow developers to listen to context menus being requested by the end user in the WebView2 and `CoreWebView2CustomItemSelected` that will notify the developer that one of their inserted context menu items was selected. When a context menu is requested in WebView2, the app developer will receive:

1. The list of default ContextMenuItem objects (contains name, Descriptor, kind, Shortcut Desc and other properties)
2. The coordinates where the context menu was requested. For instance where the end user right clicked.
3. A selection object that will include the kind of context selected, and the appropriate context menu parameter data.

and have the choice to: 

1. Add or remove entries to the default context menu provided by the WebView
2. Use their own UI to display their custom context menu (can either handle the selection on their own or return the selected option to the WebView)

If one of the entries inserted by the end developer is selected, the CustomMenuItemSelected event will be raised on the context menu item object that was selected.

# Examples

## Win32 C++ Add or Remove Entries From WebView Menu

The developer can add or remove entries to the default WebView context menu. For this case, the developer specifies Handled to be false and is able to add or remove items from the collection of context menu items.

 ```cpp
    webview2->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                CHECK_FAILURE(args->get_MenuItems(&items));
                wil::com_ptr<ICoreWebView2ContextMenuInfo> info;
                CHECK_FAILURE(args->get_ContextMenuInfo(&info));
                COREWEBVIEW2_CONTEXT_KIND context;
                CHECK_FAILURE(info->get_ContextKind(&context));
                CHECK_FAILURE(args->put_Handled(false));
                UINT32 itemsCount;
                CHECK_FAILURE(items->get_Count(&itemsCount));
                // Removing the 'Save image as' context menu item for image context selections.
                if (context == COREWEBVIEW2_CONTEXT_KIND_IMAGE)
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
                // Adding a custom context menu item for the page that will display the page's URI.
                else if (context == COREWEBVIEW2_CONTEXT_KIND_PAGE)
                {
                    wil::com_ptr<ICoreWebView2Environment> webviewEnvironment;
                    CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                        IID_PPV_ARGS(&webviewEnvironment)));
                    wil::com_ptr<ICoreWebView2ContextMenuItem> newMenuItem;
                    CHECK_FAILURE(webviewEnvironment->CreateContextMenuItem(L"Display page Uri", L"Shortcut", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL, true, false, &newMenuItem));
                    newMenuItem->add_CustomItemSelected(Callback<ICoreWebView2CustomItemSelectedEventHandler>(
                        [this, info](
                            ICoreWebView2* sender,
                            IUnknown* args)
                            {
                                wil::unique_cotaskmem_string pageUri;
                                CHECK_FAILURE(info->get_PageUri(&pageUri));
                                std::wstring pageString = pageUri.get();
                                m_appWindow->RunAsync([this, pageString]()
                                {
                                    MessageBox(
                                        m_appWindow->GetMainWindow(), pageString.c_str(),
                                        L"Display Page Uri", MB_OK);
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
                    CHECK_FAILURE(args->put_Handled(true));
                    HMENU hPopupMenu = CreatePopupMenu();
                    AddMenuItems(hPopupMenu, items);
                    HWND hWnd;
                    m_controller->get_ParentWindow(&hWnd);
                    SetForegroundWindow(hWnd);
                    wil::com_ptr<ICoreWebView2ContextMenuInfo> parameters;
                    CHECK_FAILURE(args->get_ContextMenuInfo(&parameters));
                    POINT locationInControlCoordinates;
                    POINT locationInScreenCoordinates;
                    CHECK_FAILURE(parameters->get_Location(&locationInControlCoordinates));
                    // get_Location returns coordinates in relation to upper left Bounds of the WebView2.Controller. Will need to convert to Screen coordinates to display the popup menu in the correct location.
                    ConvertToScreenCoordinates(locationInControlCoordinates, locationInScreenCoordinates);
                    UINT32 selectedCommandId = TrackPopupMenu(hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD, locationInScreenCoordinates.x, locationInScreenCoordinates.y, 0, hWnd, NULL);
                    CHECK_FAILURE(args->put_SelectedCommandId(selectedCommandId));
                };
                wil::com_ptr<ICoreWebView2Deferral> deferral;
                CHECK_FAILURE(args->GetDeferral(&deferral));
                m_sampleWindow->RunAsync([deferral, showMenu]() {
                    showMenu();
                    CHECK_FAILURE(deferral->Complete());
                });
                return S_OK;
            }).Get(),
        &m_contextMenuRequestedToken);

    void ContextMenu::AddMenuItems(
        HMENU hPopupMenu, wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items)
        {
            wil::com_ptr<ICoreWebView2ContextMenuItem> current;
            UINT32 itemsCount;

            CHECK_FAILURE(items->get_Count(&itemsCount));
            for (UINT32 i = 0; i < itemsCount; i++)
            {
                CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind;
                CHECK_FAILURE(current->get_Kind(&kind));
                wil::unique_cotaskmem_string label;
                CHECK_FAILURE(current->get_Label(&label));
                std::wstring labelString = label.get();
                BOOL isEnabled;
                CHECK_FAILURE(current->get_IsEnabled(&isEnabled));
                BOOL isChecked;
                CHECK_FAILURE(current->get_IsChecked(&isChecked));
                INT32 commandId;
                CHECK_FAILURE(current->get_CommandId(&commandId));
                if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR)
                {
                    AppendMenu(hPopupMenu, MF_SEPARATOR, 0, nullptr);
                }
                else if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU)
                {
                    HMENU newMenu = CreateMenu();
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> submenuItems;
                    CHECK_FAILURE(current->get_Children(&submenuItems));
                    AddMenuItems(newMenu, submenuItems);
                    AppendMenu(hPopupMenu, MF_POPUP, (UINT_PTR)newMenu, labelString.c_str());
                }
                else if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL)
                {
                    if (isEnabled)
                    {
                        AppendMenu(hPopupMenu, MF_BYPOSITION | MF_STRING, commandId, labelString.c_str());
                    }
                    else
                    {
                        AppendMenu(hPopupMenu, MF_GRAYED | MF_STRING, commandId, labelString.c_str());
                    }
                }
                else if (
                    kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECKBOX ||
                    kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_RADIO)
                {
                    if (isEnabled)
                    {
                        if (isChecked)
                        {
                            AppendMenu(hPopupMenu, MF_CHECKED | MF_STRING, commandId, labelString.c_str());
                        }
                        else
                        {
                            AppendMenu(hPopupMenu, MF_BYPOSITION | MF_STRING, commandId, labelString.c_str());
                        }
                    }
                    else
                    {
                        if (isChecked)
                        {
                            AppendMenu(
                                hPopupMenu, MF_CHECKED | MF_GRAYED | MF_STRING, commandId, labelString.c_str());
                        }
                        else
                        {
                            AppendMenu(hPopupMenu, MF_GRAYED | MF_STRING, commandId, labelString.c_str());
                        }
                    }
                }
            }
        }
```
## .Net/ WinRT Add or Remove Entries From WebView Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        IList<CoreWebView2ContextMenuItem> menuList = args.MenuItems;
        CoreWebView2ContextKind context = args.ContextMenuInfo.ContextKind;
        args.Handled = false;
        if (context == CoreWebView2ContextKind.Image)
        {
            // removes the last item in the collection
            menuList.RemoveAt(menuList.Count - 1);
        }
        else if (context == CoreWebView2ContextKind.Page)
        {
            // add new item to end of collection
            CoreWebView2ContextMenuItem newItem = webView.CoreWebView2.Environment.CreateContextMenuItem(
                "Display Page Uri", "Shortcut", null, CoreWebView2ContextMenuItemKind.Normal,1, 0);
                newItem.CustomItemSelected += delegate (object send, Object ex)
                {
                    string pageUri = args.ContextMenuInfo.PageUri;
                    System.Threading.SynchronizationContext.Current.Post((_) =>
                    {
                        MessageBox.Show(pageUri, "Page Uri", MessageBoxButton.YesNo);
                    }, null);
                }
            menuList.Insert(menuList.Count, newItem);
        }
    };
``` 

## .Net/ WinRT Use Data to Display Custom Context Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        IList<CoreWebView2ContextMenuItem> menuList = args.MenuItems;
        CoreWebView2Deferral deferral = args.GetDeferral();
        args.Handled = true;
        ContextMenu cm = new ContextMenu();
        cm.Closed += (s, ex) => deferral.Complete();
        PopulateContextMenu(args, menuList, cm);
        cm.IsOpen = true;
    };
    void PopulateContextMenu(CoreWebView2ContextMenuRequestedEventArgs args, 
    IList<CoreWebView2ContextMenuItem> menuList, ItemsControl cm)
    {
        for (int i = 0; i < menuList.Count; i++)
        {
            CoreWebView2ContextMenuItem current = menuList[i];
            if (current.Kind == CoreWebView2ContextMenuItemKind.Separator)
            {
                Separator sep = new Separator();
                cm.Items.Add(sep);
                continue;
            }
            MenuItem newItem = new MenuItem();
            // The accessibility key is the key after the & in the label
            // Replace with '_' so it is underlined in the label
            newItem.Header = current.Label.Replace('&', '_');
            newItem.InputGestureText = current.ShortcutKeyDescription;
            newItem.IsEnabled = current.IsEnabled;
            if (current.Kind == CoreWebView2ContextMenuItemKind.Submenu)
            {
                PopulateContextMenu(args, current.Children, newItem);
            }
            else
            {
                if (current.Kind == CoreWebView2ContextMenuItemKind.Checkbox
                || current.Kind == CoreWebView2ContextMenuItemKind.Radio)
                {
                    newItem.IsCheckable = true;
                    newItem.IsChecked = current.IsChecked;
                }

                newItem.Click += (s, ex) =>
                {
                    args.SelectedCommandId = current.CommandId;
                };
            }
            cm.Items.Add(newItem);
        }
    }
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

    /// Defines the context menu items' descriptors
    /// for the `ICoreWebView2StagingContextMenuItem::get_Descriptor` method
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR
    {
        /// Context menu item descriptor for items added by host (Custom context menu item).
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUSTOM,

        /// Context menu item descriptor for items added by extensions.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EXTENSION,

        /// Context menu item descriptor for spellcheck suggestions.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SPELLCHECK_SUGGESTION,

        /// Context menu item descriptor for "Back" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_BACK,

        /// Context menu item descriptor for "Forward" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_FORWARD,

        /// Context menu item descriptor for "Reload" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_RELOAD,
        
        /// Context menu item descriptor for "Save as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_AS,

        /// Context menu item descriptor for "Print" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PRINT,

        /// Context menu item descriptor for "Create a QR code" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CREATE_QR_CODE,

        /// Context menu item descriptor for "Inspect" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_INSPECT,

        /// Context menu item descriptor for "Emoji menu" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_EMOJI,

        /// Context menu item descriptor for "Redo" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_REDO,

        /// Context menu item descriptor for "Undo" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_UNDO,

        /// Context menu item descriptor for "Cut" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUT,

        /// Context menu item descriptor for "Copy" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY,

        /// Context menu item descriptor for "Paste" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE,

        /// Context menu item descriptor for "Paste as plain text" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE_AS_PLAIN_TEXT,

        /// Context menu item descriptor for "Select all" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SELECT_ALL,

        /// Context menu item descriptor for "Open link in new window" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OPEN_LINK_NEW_WINDOW,

        /// Context menu item descriptor for "Save link as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_LINK_AS,

        /// Context menu item descriptor for "Copy link" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_LINK,

        /// Context menu item descriptor for "Save image as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS,

        /// Context menu item descriptor for "Copy image" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE,

        /// Context menu item descriptor for "Copy image link" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY_IMAGE_LINK,

        /// Context menu item descriptor for "Save media as" action.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_MEDIA_AS,

        /// Context menu item descriptor for other commands not corresponding with any of the enums above.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_OTHER,
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR;
    
    /// Indicates the kind of context for which the context menu was created
    /// for the `ICoreWebView2ContextMenuInfo::get_ContextKind` method
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_KIND
    {
        /// Indicates that the context menu was created for the page without any additional content.
        COREWEBVIEW2_CONTEXT_KIND_PAGE,

        /// Indicates that the context menu was created for an image element.
        COREWEBVIEW2_CONTEXT_KIND_IMAGE,

        /// Indicates that the context menu was created for selected text.
        COREWEBVIEW2_CONTEXT_KIND_SELECTED_TEXT,
        
        /// Indicates that the context menu was created for an audio element.
        COREWEBVIEW2_CONTEXT_KIND_AUDIO,
        
        /// Indicates that the context menu was created for a video element.
        COREWEBVIEW2_CONTEXT_KIND_VIDEO,
    } COREWEBVIEW2_CONTEXT_KIND;

    /// Specifies the menu item kind
    /// for the `ICoreWebView2StagingContextMenuItem::get_Kind` method
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND
    {
        /// Specifies a normal menu item kind.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_NORMAL,

        /// Specifies a checkbox menu item kind. `ContextMenuItem` objects of this kind
        /// will need the `IsChecked` property to determine current state of the checkbox.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECKBOX,

        /// Specifies a radio button menu item kind. `ContextMenuItem` objects of this kind
        /// will need the `IsChecked` property to determine current state of the radio button.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_RADIO,

        /// Specifies a separator menu item kind. `ContextMenuItem` objects of this kind
        /// are used to signal a visual separator with no functionality.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR,

        /// Specifies a submenu menu item kind. `ContextMenuItem` objects of this kind will contain
        /// a `ContextMenuItemCollection` of its children `ContextMenuItem` objects.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU,
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND;

    /// Represents a context menu item of a context menu displayed by WebView.
    [uuid(7aed49e3-a93f-497a-811c-749c6b6b6c65), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItem : IUnknown
    {
        /// Gets the localized label for the `ContextMenuItem`.
        [propget] HRESULT Label([out, retval] LPWSTR* value);

        /// Gets the unlocalized name for the `ContextMenuItem`. Use this to distinguish items with 
        /// same Descriptor such as Extension items and items with Other as descriptor.
        [propget] HRESULT Name([out, retval] LPWSTR* value);

        /// Gets the descriptor for the `ContextMenuItem`.
        [propget] HRESULT Descriptor([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR* value);

        /// Gets the Command ID for the `ContextMenuItem`. Use this to report the `SelectedCommandId` in `ContextMenuRequested` event.
        [propget] HRESULT CommandId([out, retval] INT32* value);

        /// Gets the keyboard shortcut for this ContextMenuItem. It will be the empty
        /// string if there is no keyboard shortcut.
        /// This is text intended to be displayed to the end user to show the keyboard shortcut. 
        /// For example this property is `Ctrl+Shift+I` for the "Inspect" `ContextMenuItem`.
        [propget] HRESULT ShortcutKeyDescription([out, retval] LPWSTR* value);

        /// Gets the Icon for the `ContextMenuItem` in PNG format in the form of an IStream.
        [propget] HRESULT Icon([out, retval] IStream** value);

        /// Gets the `ContextMenuItem` kind.
        [propget] HRESULT Kind([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND* value);

        /// Gets the enabled property of the `ContextMenuItem`.
        [propget] HRESULT IsEnabled([out, retval] BOOL* value);

        /// Gets the checked property of the `ContextMenuItem`, used if the kind is Checkbox or Radio.
        [propget] HRESULT IsChecked([out, retval] BOOL* value);

        /// Gets the list of children menu items through a `ContextMenuItemCollection` 
        /// if the kind is Submenu. If the kind is not submenu, will return null.
        [propget] HRESULT Children([out, retval] ICoreWebView2StagingContextMenuItemCollection** value);

        /// Add an event handler for the `CustomItemSelected` event.
        /// `CustomItemSelected` event is raised when the user selects this `ContextMenuItem`.
        HRESULT add_CustomItemSelected(
            [in] ICoreWebView2StagingCustomItemSelectedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with `add_CustomItemSelected`.
        HRESULT remove_CustomItemSelected(
            [in] EventRegistrationToken token);
    }

    /// Represents a collection of `ContextMenuItem` objects. Used to get, remove and add
    /// `ContextMenuItem` objects at the specified index.
    [uuid(f562a2f5-c415-45cf-b909-d4b7c1e276d3), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItemCollection : IUnknown
    {
        /// Gets the number of `ContextMenuItem` objects contained in the `ContextMenuItemCollection`.
        [propget] HRESULT Count([out, retval] UINT32* value);

        /// Gets the `ContextMenuItem` at the specified index.
        HRESULT GetValueAtIndex([in] UINT32 index,
            [out, retval] ICoreWebView2ContextMenuItem** value);

        /// Removes the `ContextMenuItem` at the specified index.
        HRESULT RemoveValueAtIndex([in] UINT32 index);

        /// Inserts the `ContextMenuItem` at the specified index.
        HRESULT AddValueAtIndex([in] UINT32 index, [in] ICoreWebView2ContextMenuItem* value);
    }

    [uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
    interface ICoreWebView2_4 : ICoreWebView2_3
    {
        /// Add an event handler for the `ContextMenuRequested` event.
        /// `ContextMenuRequested` event is raised when a context menu is requested by the user
        /// and the content inside WebView hasn't disabled context menus.
        /// The host has the option to create their own context menu with the information provided in 
        /// the event or can add items to or remove items from WebView context menu.
        /// If the host doesn't handle the event, WebView will display the default context menu.
        HRESULT add_ContextMenuRequested(
            [in] ICoreWebView2StagingContextMenuRequestedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with `add_ContextMenuRequested`.
        HRESULT remove_ContextMenuRequested(
            [in] EventRegistrationToken token);
    }

    /// A continuation of the ICoreWebView2Environment interface.
    [uuid(04d4fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2Environment : IUnknown
    {
        /// Create a `ContextMenuItem` object to insert into the WebView context menu.
        /// The `IsChecked` property will only be used if the menu item kind is Radio or Checkbox.
        /// For more information regarding paramters, see `ContextMenuItem`.
        HRESULT CreateContextMenuItem(
            [in] LPCWSTR label,
            [in] LPCWSTR shortcutKeyDescription,
            [in] IStream* iconStream,
            [in] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind,
            [in] BOOL isEnabled,
            [in] BOOL isChecked,
            [out, retval] ICoreWebView2ContextMenuItem** item);
    }

    [uuid(04d3fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventHandler : IUnknown
    {
        /// Called to provide the event args when a context menu is requested on a WebView element.
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2ContextMenuRequestedEventArgs* args);
    }

    /// Raised to notify the host that the end user selected a custom `ContextMenuItem`.
    /// `CustomItemSelected` event is raised on the specific `ContextMenuItem` that the end user selected.
    [uuid(49e1d0bc-fe9e-4481-b7c2-32324aa21998), object, pointer_default(unique)]
    interface ICoreWebView2CustomItemSelectedEventHandler : IUnknown
    {
        /// Provides the event args for the corresponding event. No event args exist
        /// and the `args` parameter is set to `null`.
        HRESULT Invoke(
            [in] ICoreWebView2ContextMenuItem* sender, [in] IUnknown* args);
    }

    /// Event args for the `ContextMenuRequested` event. Will contain the selection information 
    /// and a collection of all of the default context menu items that the WebView
    /// would show. Allows the app to draw its own context menu or add/remove 
    /// from the default context menu.
    [uuid(a1d309ee-c03f-11eb-8529-0242ac130003), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventArgs : IUnknown
    {
        /// Gets the collection of `ContextMenuItem` objects. 
        /// See `ICoreWebView2ContextMenuItemCollection` for more details.
        [propget] HRESULT MenuItems([out, retval] ICoreWebView2ContextMenuItemCollection** value);

        /// Gets the information associated with the requested context menu. 
        /// See `ICoreWebView2ContextMenuInfo` for more details.
        [propget] HRESULT ContextMenuInfo([out, retval] ICoreWebView2ContextMenuInfo** value);

        /// Sets the selected command for the WebView to execute. The value is
        /// obtained via the `ContextMenuItem` CommandId property
        /// The default value is -1 which means that no selected occured.
        [propput] HRESULT SelectedCommandId([in] INT32 value);

        /// Gets the selected CommandId.
        [propget] HRESULT SelectedCommandId([out, retval] INT32* value);

        /// Sets whether the `ContextMenuRequested` event is handled by host after
        /// the event handler completes or if there is a deferral then after the deferral is completed.  
        /// If Handled is set to TRUE then WebView2 will not display a context menu and will instead
        /// use the SelectedCommandId property to indicate which, if any, context menu item to invoke.
        /// If after the event handler or deferral completes Handled is set to FALSE then WebView2 
        /// will display a context menu based on the contents of the MenuItems property. 
        /// The default value is FALSE.
        [propput] HRESULT Handled([in] BOOL value);

        /// Gets whether the `ContextMenuRequested` event is handled by host.
        [propget] HRESULT Handled([out, retval] BOOL* value);

        /// Returns an `ICoreWebView2Deferral` object. Use this operation to
        /// complete the event when the custom context menu is closed.
        HRESULT GetDeferral([out, retval] ICoreWebView2Deferral** deferral);
    }

    /// Represents the information regarding the context menu. Includes the location of the request, 
    /// the context selected and the appropriate data used for the actions of a context menu.
    [uuid(b8611d99-eed6-4f3f-902c-a198502ad472), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuInfo : IUnknown
    {
        /// Gets the coordinates where the context menu request occured in relation to the upper left corner of the webview bounds.
        [propget] HRESULT Location([out, retval] POINT* value);

        /// Gets the kind of context that the user selected.
        [propget] HRESULT ContextKind([out, retval] COREWEBVIEW2_CONTEXT_KIND* value);

        /// Returns TRUE if the context menu was requested on the main frame and
        /// FALSE if invoked on another frame.
        [propget] HRESULT IsMainFrame([out, retval] BOOL* value);

        /// Returns TRUE if the context menu is requested on a selection.
        [propget] HRESULT HasSelection([out, retval] BOOL* value);

        /// Returns TRUE if the context menu is requested on an editable component.
        [propget] HRESULT IsEditable([out, retval] BOOL* value);

        /// Returns TRUE if the context menu is requested on a component that contains a link.
        [propget] HRESULT ContainsLink([out, retval] BOOL* value);

        /// Gets the uri of the page.
        [propget] HRESULT PageUri([out, retval] LPWSTR* value);

        /// Gets the uri of the frame. Will match the PageUri if `get_IsMainFrame` is TRUE.
        [propget] HRESULT FrameUri([out, retval] LPWSTR* value);

        /// Gets the source uri of element (if context menu requested on a media element, null otherwise).
        [propget] HRESULT SourceUri([out, retval] LPWSTR* value);

        /// Gets the uri of the link (if context menu requested on a link, null otherwise).
        [propget] HRESULT LinkUri([out, retval] LPWSTR* value);

        /// Gets the text of the link (if context menu requested on a link, null otherwise).
        [propget] HRESULT LinkText([out, retval] LPWSTR * value);

        /// Gets the selected text (available when HasSelection is TRUE, null otherwise).
        [propget] HRESULT SelectionText([out, retval] LPWSTR* value);
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

    enum CoreWebView2ContextKind
    {
        Page = 0,
        Image = 1,
        SelectedText = 2,
        Audio = 3,
        Video = 4,
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
        Int32 SelectedCommandId { get; set; }
        Windows.Foundation.Deferral GetDeferral();
    };
    
    runtimeclass CoreWebView2ContextMenuInfo
    {
        Point Location { get; }
        CoreWebView2ContextKind ContextKind { get; }
        Boolean IsMainFrame { get; }
        Boolean HasSelection { get; }
        Boolean IsEditable { get; }
        Boolean ContainsLink { get; }
        String PageUri { get; }
        String FrameUri { get; }
        String SourceUri { get; }
        String LinkUri { get; }
        String LinkText { get; }
        String SelectionText { get; }
    };
    
    runtimeclass CoreWebView2ContextMenuItem
    {
        String Label { get; }
        String Name { get; }
        String ShortcutKeyDescription { get; }
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
            String ShortcutKeyDescription,
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
