# Background

There currently is no method using WebView2 APIs to customize the default context menu experience. Currently, the only option using WebView2 API's is to show or disable the default context menu. We have been requested by WebView2 app developers to allow for two different customization paths for context menus. The first option is to pass appropriate data to allow the app developers to create their own context menu UI and the second is to allow app developers to add and remove items from the default context menus.

# Description
We propose a new event for WebView2, CoreWebView2ContextMenuRequested that will allow developers to listen to context menus being requested by the end user in the WebView2. When a context menu is requested in WebView2, the app developer will receive:

1. The list of default ContextMenuItem objects (contains name, Descriptor, kind/type, Shorcut Desc)
2. The coordinates where the context menu was requested. For instance where the end user right clicked.
3. The type of context selected (image, textbox, link, etc)

and have the choice to: 

1. Add or remove entries to the default context menu provided by the browser (not in this PR, added later)
2. Use their own UI to display their custom context menu (can either handle the selection on their own or return the selected option to the browser)

# Examples

## Win32 C++ Add/ Remove Entries From the Browser Menu

## Win32 C++ Use Data to Display Custom Context Menu

The developer can use the data provided in the Event arguments to display a custom context menu with entries of their choice. For this case, the developer specifies Handled to be true and requests a deferral. deferral of this event should be completed when the user selects a context menu item (either the app developer will handle the case, or can return the selected option to the browser) or when they click on the screen (effectively closing the menu).

 ```cpp
    webview2->add_ContextMenuRequested(
        Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [this](
                ICoreWebView2* sender,
                ICoreWebView2ContextMenuRequestedEventArgs* args)
            {
                auto showMenu = [this, args] {
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollection> context_menu_items;
                    CHECK_FAILURE(args->get_ContextMenuItems(&context_menu_items));
                    args->put_Handled(true);
                    wil::com_ptr<ICoreWebView2ContextMenuItemCollectionIterator> iterator;
                    CHECK_FAILURE(context_menu_items->GetIterator(&iterator));
                    HMENU hPopupMenu = CreatePopupMenu();
                    BOOL hasCurrent = FALSE;
                    while (SUCCEEDED(iterator->get_HasCurrent(&hasCurrent)) && hasCurrent)
                    {
                        wil::com_ptr<ICoreWebView2ContextMenuItem> current;
                        CHECK_FAILURE(iterator->GetCurrent(&current));
                        wil::unique_cotaskmem_string name;
                        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR desc;
                        wil::unique_cotaskmem_string shortcut;
                        CHECK_FAILURE(current->get_Name(&name));
                        CHECK_FAILURE(current->get_DESCRIPTOR(&desc));
                        CHECK_FAILURE(current->get_Shortcut(&shortcut));
                        InsertMenu(hPopupMenu, 0, MF_BYPOSITION | MF_STRING, desc, name);
                        BOOL hasNext = FALSE;
                        CHECK_FAILURE(iterator->MoveNext(&hasNext));
                    }
                    HWND hWnd;
                    m_appWindow->GetWebViewController()->get_ParentWindow(&hWnd);
                    SetForegroundWindow(hWnd);
                    POINT p;
                    CHECK_FAILURE(args->get_Location(&p));
                    UINT selectedItem = TrackPopupMenu(hPopupMenu, TPM_TOPALIGN | TPM_LEFTALIGN | TPM_RETURNCMD, p.x, p.y, 0, hWnd, NULL);
                    CHECK_FAILURE(args->put_SelectedItem(selectedItem));
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
## .Net/ WinRT Add/ Remove Entries From Browser Menu

## .Net/ WinRT Use Data to Display Custom Context Menu 

 ```c#
    webView.CoreWebView2.ContextMenuRequested += delegate (object sender, CoreWebView2ContextMenuRequestedEventArgs args)
    {
        CoreWebView2Deferral deferral = args.GetDeferral();
        System.Threading.SynchronizationContext.Current.Post((_) =>
        {
            using (deferral)
            {
                CoreWebView2ContextMenuItemCollection collection = args.MenuItems;
                CoreWebView2SelectionContext context = args.context;
                CoreWebView2ContextMenuItemCollectionIterator iterator = collection.GetIterator();
                args.Handled = true;
                ContextMenu cm = this.FindResource("ContextMenu") as ContextMenu;
                cm.Items.Clear();
                while (iterator.HasCurrent)
                {
                    CoreWebView2ContextMenuItem current = iterator.GetCurrent();
                    MenuItem newItem = new MenuItem();
                    newItem.Header = current.Name;
                    newItem.Click += (s, ex) => args.SelectedItem = current.id;
                    cm.Items.Add(newItem);
                    iterator.MoveNext();
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
    interface ICoreWebView2ContextMenuItem;
    interface ICoreWebView2ContextMenuItemCollection;
    interface ICoreWebView2ContextMenuItemCollectionIterator;
    interface ICoreWebView2ContextMenuRequestedEventArgs;
    interface ICoreWebView2ContextMenuRequestedEventHandler;

    /// Defines the Context Menu Items
    [v1_enum]
    typedef enum COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR {
        /// Custome type, will include Items brought in by browser extensions
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUSTOM,

        /// No Command
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_NONE,

        /// Page Commands
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_BACK,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_FORWARD,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_RELOAD,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_STOP,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_NEW_WINDOW,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PRINT,

        /// Clipboard Commands
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_CUT,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_COPY,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_PASTE_AS_PLAIN_TEXT,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SELECT_ALL,

        /// Saving
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_LINK_AS,
        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_SAVE_IMAGE_AS,

        COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_INSPECT, 

        ... /// list is not complete
        
    } COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR;
    
    /// Indicates the context selected (where the user right clicked)
    [v1_enum]
    typedef enum COREWEBVIEW2_SELECTION_CONTEXT {

        /// Indicates that a user right clicked on an image.

        COREWEBVIEW2_SELECTION_CONTEXT_IMAGE,

        /// Indicates that a user right clicked on a link.

        COREWEBVIEW2_SELECTION_CONTEXT_LINK,

        /// Indicates that a user right clicked on a textbox.

        COREWEBVIEW2_SELECTION_CONTEXT_TEXTBOX,

        /// Indicates that a user right clicked on selected text.

        COREWEBVIEW2_SELECTION_CONTEXT_TEXT,

        /// Indicates that a user right clicked on an area on the page.

        COREWEBVIEW2_SELECTION_CONTEXT_PAGE,

        /// Indicates that a user right clicked on a video

        COREWEBVIEW2_SELECTION_CONTEXT_VIDEO,
        
        /// Indicates that a user right clicked on a pdf

        COREWEBVIEW2_SELECTION_CONTEXT_PDF,

        /// list is not complete

    } COREWEBVIEW2_SELECTION_CONTEXT;

    /// Context Menu Items displayed by the Edge browser, holds the properties of a context menu item
    [uuid(7aed49e3-a93f-497a-811c-749c6b6b6c65), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItem : IUnknown {
        /// Get the Name displayed for the Context Menu Item
        [propget] HRESULT Name([out, retval] LPWSTR* value);

        /// Get the ID for the Context Menu Item
        [propget] HRESULT ID([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR* value);

        /// Get the Shortcut for the Context Menu Item
        [propget] HRESULT Shortcut([out, retval] LPWSTR* value);

    }

    /// Collection of ContextMenuItem objects 
    [uuid(f562a2f5-c415-45cf-b909-d4b7c1e276d3), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItemCollection : IUnknown {
        /// Gets the iterator over the collection of context menu items from the start
        HRESULT GetIterator([out, retval] ICoreWebView2ContextMenuItemCollectionIterator ** iterator);

        /// Returns whether the specific Context Menu ID is contained in the collection
        HRESULT Contains([in] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR menuItem, [out, retval] BOOL * iterator);

        /// Returns the iterator starting at the menu item specified
        HRESULT Get([in] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR menuItem, [out, retval]  ICoreWebView2ContextMenuItemCollectionIterator** iterator);

        /// Deletes the menu item specified
        HRESULT Delete(COREWEBVIEW2_CONTEXT_MENU_ITEM_ID menuItem);

        /// Adds a context menu item to the front of the list
        HRESULT InsertBefore(ICoreWebView2ContextMenu* menuItem, UINT index);

        /// Adds a context menu item to the end of the list
        HRESULT Append(ICoreWebView2ContextMenu* newMenuItem);

    }

    /// Iterator for a collection of ContextMenuItem objects 
    [uuid(b9cc0ce5-4d10-4b9c-af06-802b199abc42), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuItemCollectionIterator : IUnknown {
        /// TRUE when the iterator has not run out of ContextMenuItem objects
        /// Will be FALSE if collection is empty or if iterator has gone past collection
        [propget] HRESULT HasCurrent([out, retval] BOOL * value);

        /// Gets the current ICoreWebView2ContextMenuItem of the iterator
        HRESULT GetCurrent([out, retval] ICoreWebView2ContextMenuItem ** contextItem);

        /// Moves the iterator to the next ContextMenuItem
        HRESULT MoveNext([out, retval] BOOL * hasNext);

        /// Deletes the current context menu item and moves to the next item
        HRESULT DeleteAndMoveNext(BOOL * hasNext);

        /// Inserts the new context menu item before the current one.
        HRESULT InsertBefore(ICoreWebView2ContextMenuItem* menuItem);
    }

    [uuid(76eceacb-0462-4d94-ac83-423a6793775e), object, pointer_default(unique)]
    interface ICoreWebView2_4 : ICoreWebView2_3
    {
        /// Add an event handler for the ContextMenuRequested event.
        /// ContextMenuRequested event is raied when the user right clicks in the webview
        ///
        /// The host can use their own UI to create their own context menu using
        /// the data provided in the API or can add to / remove from the default
        /// context menu. If the host doesn't handle the event, Webview will
        /// display the original context menu.
        ///
        HRESULT add_ContextMenuRequested(
            [in] ICoreWebView2ContextMenuRequestedEventHandler* eventHandler,
            [out] EventRegistrationToken* token);

        /// Remove an event handler previously added with add_ContextMenuRequested.
        HRESULT remove_ContextMenuRequested(
            [in] EventRegistrationToken token);
    }

    /// A continuation of the ICoreWebView2Environment3 interface.
    [uuid(04d4fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2Environment4 : ICoreWebView2Environment3 {
        /// Create a ContextMenuItem object used for developers to insert new items 
        /// into the default browser context menu, Descriptor will be CUSTOM
        HRESULT CreateContextMenuItem(
            [in] LPCWSTR Name,
            [in] LPCWSTR Shorctut,
            [out, retval] ICoreWebView2ContextMenuItem ** item);
    }

    [uuid(04d3fe1d-ab87-42fb-a898-da241d35b63c), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventHandler : IUnknown {
        // Called to provide the event args when a user right clicks on WebView2 element
        HRESULT Invoke(
            [in] ICoreWebView2* sender,
            [in] ICoreWebView2ContextMenuRequestedEventArgs* args);
    }

    /// Event args for the ContextMenuRequested event. Will contain the
    /// context selected by the user, the location of the right click, a collection of all of the default
    /// context menu items that the default WebView2 menu would show and allows the app to draw its own context menu or add/ remove from the default context menu.
    [uuid(a1d309ee-c03f-11eb-8529-0242ac130003), object, pointer_default(unique)]
    interface ICoreWebView2ContextMenuRequestedEventArgs : IUnknown {
        /// The list of default ContextMenuItem objects
        [propget] HRESULT MenuItems([out, retval] ICoreWebView2ContextMenuItemCollection ** value);

        /// The coordinates where the right click occured
        [propget] HRESULT Location([out, retval] POINT* value);

        /// The context that the user selected
        [propget] HRESULT Context([out, retval] COREWEBVIEW2_SELECTION_CONTEXT* value);

        /// Returns the selected Context Menu Item, default item is COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_NONE
        [propget] HRESULT SelectedItem([out, retval] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR* value);

        /// Sets the Selected Menu Item to respond to the server, default item is COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR_NONE
        [propput] HRESULT SelectedItem([in] COREWEBVIEW2_CONTEXT_MENU_ITEM_DESCRIPTOR value);

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
```

```c#
namespace Microsoft.Web.WebView2.Core
{

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs;
    runtimeclass CoreWebView2ContextMenuItem;
    runtimeclass CoreWebView2ContextMenuItemCollection;
    runtimeclass CoreWebView2ContextMenuItemCollectionIterator;

    enum CoreWebView2ContextMenuItemDescriptor {
        /// Custome type, will include Items brought in by browser extensions
        Custom = 0,

        /// No Command
        None = 1,

        /// Page Commands
        Back = 2,
        Forward = 3,
        Reload = 4,
        Stop = 5,
        NewWindow = 6,
        Print = 7,

        /// Clipboard Commands
        Cut = 8,
        Copy = 9,
        Paste = 10,
        PasteAsPlainText = 11,
        SelectAll = 12,

        /// Saving
        SaveLinkAs = 13,
        SaveImageAs = 14,
        
        Inspect = 15,
        ... /// list is not complete
    };

    enum CoreWebView2SelectionContext
    {
        Image = 0,
        Link = 1,
        Textbox = 2,
        Text = 3,
        Page = 4,
        Video = 5,
        PDF = 6,
        ... /// list is not complete
    };

    runtimeclass CoreWebView2ContextMenuRequestedEventArgs
    {
        Boolean Handled { get; set; }
        CoreWebView2SelectionContext Context { get; };
        CoreWebView2ContextMenuItemCollection MenuItems { get; };
        CoreWebView2ContextMenuItem SelectedItem { get; set; }
        Point Location { get; };
        Windows.Foundation.Deferral GetDeferral();
    };
    
    runtimeclass CoreWebView2ContextMenuItem
    {
        String Name { get; }
        String Shortcut { get; }
        CoreWebView2ContextMenuItemDescriptor Descriptor { get; }
    };

    runtimeclass CoreWebView2ContextMenuItemCollection
    {
        CoreWebView2ContextMenuItemCollectionIterator GetIterator();
        Boolean Contains(CoreWebView2ContextMenuItemDescriptor menuItem);
        CoreWebView2ContextMenuItemCollectionIterator Get(CoreWebView2ContextMenuItemDescriptor menuItem);
        void Delete(CoreWebView2ContextMenuItemDescriptor menuItem);
        void InsertBefore(CoreWebView2ContextMenuItemDescriptor newMenuItem, Int32 index);
        void Append(CoreWebView2ContextMenuItemDescriptor newMenuItem);
    };
    
    runtimeclass CoreWebView2ContextMenuItemCollectionIterator
    {
        Boolean HasCurrent{ get; }
        CoreWebView2ContextMenuItem GetCurrent();
        Boolean MoveNext();
        Boolean DeleteAndMoveNext();
        void InsertBefore(CoreWebView2ContextMenuItem newMenuItem);
    };

    runtimeclass CoreWebView2
    {
        ...
        event Windows.Foundation.TypedEventHandler<CoreWebView2, CoreWebViewContextMenuRequestedEventEventArgs> ContextMenuRequestedEvent;
    }
}
```

# Appendix
