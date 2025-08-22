# Memory Dump from Task Manager
In some cases, a user might need to manually gather a memory dump, normally for unresponsive processes. To do so:

1. Open Task Manager (Ctrl+Shift+Esc).
2. Click "Details" on the left menu.
3. Sort by the "Name" column.
4. Search for "msedgewebview2.exe" in the search box.
5. To find the right msedgewebview2.exe, you can use a combination of:
    1. The "Package name" column, which will represent the application using WebView2. (you might need to right-click the column headers, choose "select columns" and check the box for "Package name")
    2. The "Description" column, which will describe which of WebView2's processes it is. (you might need to make Task Manager very wide to see this one, you can drag to re-arrange the columns if needed)
    
    For example, if you're asked to get a crash dump of "Outlook's Manager process", you'll want the process that has "Outlook" as its Package name, and "WebView2 Manager" for its Description.
6. Right-click the process on the list and choose "Create memory dump file"
7. Once that completes, click "Open file location"
8. Copy the msedgewebview2.DMP file to a location where you can share it.