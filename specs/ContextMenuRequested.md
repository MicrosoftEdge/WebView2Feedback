# Background

There currently is no method using WebView2 APIs to customize the default context menu experience. Currently, the only option using WebView2 APIs is to show or disable the default context menu. We have been requested by WebView2 app developers to allow for customization of the context menu experience. This has produced two different customization paths for context menus. The first option is to allow the app developers to create their own context menu UI using data passed from the WebView and the second is to allow app developers to add and remove items from the default context menus.

# Description
We propose two new events for WebView2, `CoreWebView2ContextMenuRequested` that will allow developers to listen to context menus being requested by the end user in the WebView2 and `CoreWebView2CustomItemSelected` that will notify the developer that one of their inserted context menu items was selected. `CoreWebView2ContextMenuRequested` will only be raised if the page allows the context menu to appear. If the WebView2 `AreDefaultContextMenusEnabled` setting is set to `False`, this event will not be raised. When a context menu is requested in WebView2, the app developer will receive:

1. An ordered list of ContextMenuItem objects (contains name, label, kind, Shortcut Desc and other properties) to be shown in the context menu.
2. The coordinates where the context menu was requested in relation to the upper left corner of the webview bounds.
3. A selection object that will include the kind of context selected, and the appropriate context menu parameter data.

and have the option of performing the following, in any combination:

1. Add or remove entries to the default context menu provided by the WebView
2. Use their own UI to display their custom context menu (can either handle the user-selected menu item on their own or return the menu item to the WebView)

If one of the entries inserted by the end developer is selected, the CustomMenuItemSelected event will be raised on the context menu item object that was selected in these cases:

1. App adds custom menu items but defers the context menu UI to the WebView platform.
2. App adds custom menu items, shows custom UI, and sets the SelectedCommandId property to the ID of the custom menu item.

# Examples

## Win32 C++ Add or Remove Entries From WebView Menu

The developer can add or remove entries to the default WebView context menu. For this case, the developer specifies Handled to be false and is able to add or remove items from the collection of context menu items.

 ```cpp
    m_webView2_4 = m_webView.try_query<ICoreWebView2_4>();
    webview2_4->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                CHECK_FAILURE(args->get_MenuItems(&items));
                wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
                CHECK_FAILURE(args->get_ContextMenuTarget(&target));
                COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND context_kind;
                CHECK_FAILURE(target->get_Kind(&context_kind));
                UINT32 itemsCount;
                CHECK_FAILURE(items->get_Count(&itemsCount));
                // Removing the 'Save image as' context menu item for image context selections.
                if (context_kind == COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_IMAGE)
                {
                    wil::com_ptr<ICoreWebView2ContextMenuItem> current;
                    for(UINT32 i = 0; i < itemsCount; i++) 
                    {
                        CHECK_FAILURE(items->GetValueAtIndex(i, &current));
                        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR desc;
                        CHECK_FAILURE(current->get_Descriptor(&desc));
                        if (desc == COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS)
                        {
                            CHECK_FAILURE(items->RemoveValueAtIndex(i));
                            break;
                        }
                    }
                }
                // Adding a custom context menu item for the page that will display the page's URI.
                else if (context_kind == COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_PAGE)
                {
                    wil::com_ptr<ICoreWebView2Environment5> webviewEnvironment;
                    CHECK_FAILURE(m_appWindow->GetWebViewEnvironment()->QueryInterface(
                        IID_PPV_ARGS(&webviewEnvironment)));
                    wil::com_ptr<ICoreWebView2ContextMenuItem> newMenuItem;
                    CHECK_FAILURE(webviewEnvironment->CreateContextMenuItem(L"Display page Uri", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND, &newMenuItem));
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
                        nullptr);
                    CHECK_FAILURE(items->InsertValueAtIndex(itemsCount, newMenuItem.get()));
                }
                return S_OK;
            })
            .Get(),
        &m_contextMenuRequestedToken);
```

## Win32 C++ Use Data to Display Custom Context Menu

The developer can use the data provided in the Event arguments to display a custom context menu with entries of their choice. For this case, the developer specifies Handled to be true and requests a deferral. Deferral of this event should be completed when the user selects a context menu item (either the app developer will handle the case, or can return the selected option to the WebView) or when the end user dismisses the context menu by clicking outside of the context menu for example.

 ```cpp
    m_webView2_4 = m_webView.try_query<ICoreWebView2_4>();
    webview2_4->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                auto showMenu = [this, args = 
                wil::com_ptr<ICoreWebView2ContextMenuRequestedEventArgs>(args)]
                {
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                    CHECK_FAILURE(args->get_MenuItems(&items));
                    CHECK_FAILURE(args->put_Handled(true));
                    HMENU hPopupMenu = CHECK_POINTER(CreatePopupMenu());
                    AddMenuItems(hPopupMenu, items);
                    HWND hWnd;
                    m_controller->get_ParentWindow(&hWnd);
                    POINT locationInControlCoordinates;
                    POINT locationInScreenCoordinates;
                    CHECK_FAILURE(args->get_Location(&locationInControlCoordinates));
                    // get_Location returns coordinates in relation to upper left Bounds of the WebView2.Controller. Will need to convert to Screen coordinates to display the popup menu in the correct location.
                    ConvertToScreenCoordinates(locationInControlCoordinates, locationInScreenCoordinates);
                    UINT32 selectedCommandId = TrackPopupMenu(hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD, locationInScreenCoordinates.x, locationInScreenCoordinates.y, 0, hWnd, NULL);
                    if (selectedCommandId != 0) {
                        CHECK_FAILURE(args->put_SelectedCommandId(selectedCommandId));
                    }
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
                wil::unique_cotaskmem_string shortcut;
                CHECK_FAILURE(current->get_ShortcutKeyDescription(&shortcut));
                std::wstring shortcutString = shortcut.get();
                if (!shortcutString.empty())
                {
                    labelString = labelString + L"\t" + shortcutString;
                }
                BOOL isEnabled;
                CHECK_FAILURE(current->get_IsEnabled(&isEnabled));
                BOOL isChecked;
                CHECK_FAILURE(current->get_IsChecked(&isChecked));
                INT32 commandId;
                CHECK_FAILURE(current->get_CommandId(&commandId));
                if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SEPARATOR)
                {
                    CHECK_BOOL(AppendMenu(hPopupMenu, MF_SEPARATOR, 0, nullptr));
                }
                else if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_SUBMENU)
                {
                    HMENU newMenu = CHECK_POINTER(CreateMenu());
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> submenuItems;
                    CHECK_FAILURE(current->get_Children(&submenuItems));
                    BOOL isEnabled;
                    CHECK_FAILURE(current->get_IsEnabled(&isEnabled));
                    if (isEnabled)
                    {
                        AddMenuItems(newMenu, submenuItems);
                        CHECK_BOOL(AppendMenu(hPopupMenu, MF_POPUP, (UINT_PTR)newMenu, labelString.c_str()));
                    }
                    else
                    {
                        CHECK_BOOL(AppendMenu(hPopupMenu, MF_POPUP | MF_GRAYED, (UINT_PTR)newMenu, labelString.c_str()));
                    }
                }
                else if (
                    kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECK_BOX ||
                    kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_RADIO)
                {
                    if (isEnabled)
                    {
                        if (isChecked)
                        {
                            CHECK_BOOL(AppendMenu(hPopupMenu, MF_CHECKED | MF_STRING, commandId, labelString.c_str()));
                        }
                        else
                        {
                            CHECK_BOOL(AppendMenu(hPopupMenu, MF_BYPOSITION | MF_STRING, commandId, labelString.c_str()));
                        }
                    }
                    else
                    {
                        if (isChecked)
                        {
                            CHECK_BOOL(AppendMenu(
                                hPopupMenu, MF_CHECKED | MF_GRAYED | MF_STRING, commandId, labelString.c_str()));
                        }
                        else
                        {
                            CHECK_BOOL(AppendMenu(hPopupMenu, MF_GRAYED | MF_STRING, commandId, labelString.c_str()));
                        }
                    }
                }
                else if (kind == COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND)
                {
                    if (isEnabled)
                    {
                        CHECK_BOOL(AppendMenu(hPopupMenu, MF_BYPOSITION | MF_STRING, commandId, labelString.c_str()));
                    }
                    else
                    {
                        CHECK_BOOL(AppendMenu(hPopupMenu, MF_GRAYED | MF_STRING, commandId, labelString.c_str()));
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
        CoreWebView2ContextMenuTargetKind context = args.ContextMenuTarget.Kind;
        if (context == CoreWebView2ContextMenuTargetKind.Image)
        {
            for (int index = 0; index < menuList.Count; index++)
            {
                if (menuList[index].Descriptor == CoreWebView2ContextMenuItemDescriptor.SaveImageAs)
                {
                    menuList.RemoveAt(index);
                    break;
                }
            }
        }
        else if (context == CoreWebView2ContextMenuTargetKind.Page)
        {
            // add new item to end of collection
            CoreWebView2ContextMenuItem newItem = webView.CoreWebView2.Environment.CreateContextMenuItem(
                "Display Page Uri", null, CoreWebView2ContextMenuItemKind.Command);
                newItem.CustomItemSelected += delegate (object send, Object ex)
                {
                    string pageUri = args.ContextMenuTarget.PageUri;
                    System.Threading.SynchronizationContext.Current.Post((_) =>
                    {
                        MessageBox.Show(pageUri, "Page Uri", MessageBoxButton.OK);
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
                if (current.Kind == CoreWebView2ContextMenuItemKind.CheckBox
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
    interface ICoreWebView2Environment5;
    interface ICoreWebView2ContextMenuItem;
    interface ICoreWebView2ContextMenuItemCollection;
    interface ICoreWebView2ContextMenuRequestedEventArgs;
    interface ICoreWebView2ContextMenuRequestedEventHandler;
    interface ICoreWebView2ContextMenuTarget;
    interface ICoreWebView2CustomItemSelectedEventHandler;
    
    /// Indicates the kind of context for which the context menu was created
    /// for the `ICoreWebView2ContextMenuTarget::get_Kind` method.
    /// This enum will always represent the active element that caused the context menu request. 
    /// If there is a selection with multiple images, audio and text, for example, the element that 
    /// the end user right clicks on within this selection will be the option represented by this enum.
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND
    {
        /// Indicates that the context menu was created for the page without any additional content.
        COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_PAGE,

        /// Indicates that the context menu was created for an image element.
        COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_IMAGE,

        /// Indicates that the context menu was created for selected text.
        COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_SELECTED_TEXT,
        
        /// Indicates that the context menu was created for an audio element.
        COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_AUDIO,
        
        /// Indicates that the context menu was created for a video element.
        COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_VIDEO,
    } COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND;

    /// Specifies the menu item kind
    /// for the `ICoreWebView2StagingContextMenuItem::get_Kind` method
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND
    {
        /// Specifies a command menu item kind.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_COMMAND,

        /// Specifies a check box menu item kind. `ContextMenuItem` objects of this kind
        /// will need the `IsChecked` property to determine current state of the check box.
        COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECK_BOX,

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
        
        /// Gets the unlocalized name for the `ContextMenuItem`. Use this to distinguish
        /// between context menu item types.
        [propget] HRESULT Name([out, retval] LPWSTR* value);
        
        /// Gets the localized label for the `ContextMenuItem`. Will contain an ampersand for characters to be used
        /// as keyboard accelerator.
        [propget] HRESULT Label([out, retval] LPWSTR* value);

        /// Gets the Command ID for the `ContextMenuItem`. Use this to report the `SelectedCommandId` in `ContextMenuRequested` event.
        [propget] HRESULT CommandId([out, retval] INT32* value);

        /// Gets the localized keyboard shortcut for this ContextMenuItem. It will be the empty
        /// string if there is no keyboard shortcut.
        /// This is text intended to be displayed to the end user to show the keyboard shortcut. 
        /// For example this property is `Ctrl+Shift+I` for the "Inspect" `ContextMenuItem`.
        [propget] HRESULT ShortcutKeyDescription([out, retval] LPWSTR* value);

        /// Gets the Icon for the `ContextMenuItem` in PNG format in the form of an IStream.
        /// Stream will be rewound to the start of the PNG.
        [propget] HRESULT Icon([out, retval] IStream** value);

        /// Gets the `ContextMenuItem` kind.
        [propget] HRESULT Kind([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND* value);

        /// Sets the enabled property of the `ContextMenuItem`. Must only be used in the case of a 
        /// custom context menu item. The default value for this is `TRUE`.
        [propput] HRESULT IsEnabled([in] BOOL value);

        /// Gets the enabled property of the `ContextMenuItem`.
        [propget] HRESULT IsEnabled([out, retval] BOOL* value);

        /// Sets the checked property of the `ContextMenuItem`. Must only be used for custom context 
        /// menu items that are of type Check box or Radio.
        [propput] HRESULT isChecked([in] BOOL value);

        /// Gets the checked property of the `ContextMenuItem`, used if the kind is Check box or Radio.
        [propget] HRESULT IsChecked([out, retval] BOOL* value);

        /// Gets the list of children menu items through a `ContextMenuItemCollection` 
        /// if the kind is Submenu. If the kind is not submenu, will return null.
        [propget] HRESULT Children([out, retval] ICoreWebView2StagingContextMenuItemCollection** value);

        /// Add an event handler for the `CustomItemSelected` event.
        /// `CustomItemSelected` event is raised when the user selects this `ContextMenuItem`.
        /// Will only be raised for end developer created context menu items
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
        HRESULT InsertValueAtIndex([in] UINT32 index, [in] ICoreWebView2ContextMenuItem* value);
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
    interface ICoreWebView2Environment5 : ICoreWebView2Environment4
    {
        /// Create a `ContextMenuItem` object to insert into the WebView context menu.
        /// CoreWebView2 will rewind the stream before decoding. Command Id for new 
        /// custom menu items will be unique for the lifespan of the ContextMenuRequested
        /// event. They will be a unique value between 52600 and 52650.
        /// The returned `ContextMenuItem` object's `IsEnabled` property will default to `TRUE`
        /// and `IsChecked` property will default to `FALSE`.
        HRESULT CreateContextMenuItem(
            [in] LPCWSTR label,
            [in] IStream* iconStream,
            [in] COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND kind,
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

        /// Gets the target information associated with the requested context menu. 
        /// See `ICoreWebView2ContextMenuTarget` for more details.
        [propget] HRESULT ContextMenuTarget([out, retval] ICoreWebView2ContextMenuTarget** value);

        /// Gets the coordinates where the context menu request occured in relation to the upper 
        /// left corner of the webview bounds.
        [propget] HRESULT Location([out, retval] POINT* value);

        /// Sets the selected command for the WebView to execute. The value is
        /// obtained via the `ContextMenuItem` CommandId property.
        /// This value should always be from context menu items for the relevant context menu and 
        /// event arg. Attempting to mix will result in invalid outputs.
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

    /// Represents the information regarding the context menu target.
    /// Includes the context selected and the appropriate data used for the actions of a context menu.
    [uuid(b8611d99-eed6-4f3f-902c-a198502ad472), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuTarget : IUnknown
    {
        /// Gets the kind of context that the user selected.
        [propget] HRESULT Kind([out, retval] COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND* value);

        /// Returns TRUE if the context menu is requested on an editable component.
        [propget] HRESULT IsEditable([out, retval] BOOL* value);

        /// Returns TRUE if the context menu was requested on the main frame and
        /// FALSE if invoked on another frame.
        [propget] HRESULT IsRequestedForMainFrame([out, retval] BOOL* value);
        
        /// Gets the uri of the page.
        [propget] HRESULT PageUri([out, retval] LPWSTR* value);

        /// Gets the uri of the frame. Will match the PageUri if `get_IsRequestedForMainFrame` is TRUE.
        [propget] HRESULT FrameUri([out, retval] LPWSTR* value);

        /// Returns TRUE if the context menu is requested on HTML containing an anchor tag.
        [propget] HRESULT HasLinkUri([out, retval] BOOL* value);

        /// Gets the uri of the link (if `HasLinkUri` is TRUE, null otherwise).
        [propget] HRESULT LinkUri([out, retval] LPWSTR* value);

        /// Returns TRUE if the context menu is requested on text element that contains an anchor tag.
        [propget] HRESULT HasLinkText([out, retval] BOOL* value);

        /// Gets the text of the link (if `HasLinkText` is TRUE, null otherwise).
        [propget] HRESULT LinkText([out, retval] LPWSTR * value);

        /// Returns TRUE if the context menu is requested on HTML containing a source uri.
        [propget] HRESULT HasSourceUri([out, retval] BOOL* value);

        /// Gets the active source uri of element (if `HasSourceUri` is TRUE, null otherwise).
        [propget] HRESULT SourceUri([out, retval] LPWSTR* value);

        /// Returns TRUE if the context menu is requested on a selection.
        [propget] HRESULT HasSelection([out, retval] BOOL* value);

        /// Gets the selected text (if `HasSelection` is TRUE, null otherwise).
        [propget] HRESULT SelectionText([out, retval] LPWSTR* value);
    }
```

```c#
namespace Microsoft.Web.WebView2.Core
{
    runtimeclass CoreWebView2Environment;
    runtimeclass CoreWebView2ContextMenuItem;
    runtimeclass CoreWebView2ContextMenuRequestedEventArgs;
    runtimeclass CoreWebView2ContextMenuTarget;

    enum CoreWebView2ContextMenuTargetKind
    {
        Page = 0,
        Image = 1,
        SelectedText = 2,
        Audio = 3,
        Video = 4,
    };

    enum CoreWebView2ContextMenuItemKind
    {
        Command = 0,
        CheckBox = 1,
        Radio = 2,
        Separator = 3,
        Submenu = 4,
    };

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        Boolean Handled { get; set; }
        CoreWebView2ContextMenuTarget ContextMenuTarget { get; }
        IVector<CoreWebView2ContextMenuItem> MenuItems { get; }
        Point Location { get; }
        Int32 SelectedCommandId { get; set; }
        Windows.Foundation.Deferral GetDeferral();
    };
    
    runtimeclass CoreWebView2ContextMenuTarget
    {
        CoreWebView2ContextMenuTargetKind Kind { get; }
        Boolean IsEditable { get; }
        Boolean IsRequestedForMainFrame { get; }
        String PageUri { get; }
        String FrameUri { get; }
        Boolean HasLink { get; }
        String LinkUri { get; }
        String LinkText { get; }
        Boolean HasSourceUri { get; }
        String SourceUri { get; }
        Boolean HasSelection { get; }
        String SelectionText { get; }
    };
    
    runtimeclass CoreWebView2ContextMenuItem
    {
        String Label { get; }
        String Name { get; }
        String ShortcutKeyDescription { get; }
        Int32 CommandId { get; }
        Stream Icon { get; }
        CoreWebView2ContextMenuItemKind Kind { get; }
        Boolean IsEnabled { get; set; }
        Boolean IsChecked { get; set; }
        IVector<CoreWebView2ContextMenuItem> Children { get; }

        event Windows.Foundation.TypedEventHandler<CoreWebView2ContextMenuItem, Object> CustomItemSelected;
    };

    runtimeclass CoreWebView2Environment
    {
        public CoreWebView2ContextMenuItem CreateContextMenuItem(
            String Label,
            Stream Icon,
            CoreWebView2ContextMenuItemKind Kind);
    };

    runtimeclass CoreWebView2
    {
        ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebView2ContextMenuRequestedEventArgs> ContextMenuRequested;
    };
}
```

# Appendix
