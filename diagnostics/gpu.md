# Graphics and GPU info
GPU logs include details on the user's GPU and any potential graphics or rendering issues. If your WV2 has been created successfully but the content is not there, it might be due to a hosting and/or GPU driver issue.

There's a few pieces of information that can help us investigate these issues:
## DirectX Details
On the device that is hitting the issue:
1. Run `dxdiag` from a console window
1. Once the dialog displays and is done capturing info (there is a small progress bar) hit the "Save All Information" button to save the info to a `dxdiag.txt` file
1. Share the `dxdiag.txt` file

## GPU Logs
1. Navigate your WV2 to `edge://gpu`
1. Wait for the page to load content under the "Log Messages" header towards the bottom.
1. Hit "Copy Report to Clipboard" at the top
1. Paste it into a text file, and share it.