Programmatic Save As API


# Background

The context menu has the "Save as" item to manually save the html page, image, pdf, or other content through a save as dialog. We provide more flexiable ways to do the save as programmatically in WebView2. You can bring up the default save as dialog easily. And you will be able to block default dialog, save the content silently, by providing the path and save as type programmatically or even build your own save as UI.

In this document we describe the API. We'd appreciate your feedback.

# Description

We propose the `SaveContentAs` method WebView2, which allows you to trigger the save as programmatically. By using this method alone, the system default will popup.

Additionally, we propose the `SaveAsRequestedEvent`. You can register this event to block the default dialog and use the `SaveAsRequestedEventArgs` instead, to set your perferred save as path, save as type, and depulicate file replacement rule. In your clinet app, you can design your own UI to input these parameters. For html page, we support 3 save as types: HTML_ONLY, SINGLE_FILE and COMPLETE. For non-html page, the type is been set as DEFAULT, which will save the content as it is. This API also provides default values for all parameters, if you don't want to input anything.

# Examples
## Win32 C++
# API Details
## Win32 C++
Sync with the code and design doc soon
