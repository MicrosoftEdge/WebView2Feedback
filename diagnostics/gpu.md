# Graphics and GPU info
Issues where the WebView2 isn't displaying anything are most often caused by a launch failure, such as un-writeable user data folder, mismatched DPI awareness, or missing files (runtime or binaries). However, if the WebView2 has launched correctly (you can check return values and task manager) but the content is not there, then it might be due to a hosting and/or GPU driver issue.
1. Get the output of `edge://gpu` (wait for the page to load the 'log messages' section at the bottom).
1. Get DirectX diagnostic info
    1. Run `dxdiag` from a console window
    1. Once the dialog displays and is done capturing info (small progress bar) hit the **Save All Information** button to save the info to a dxdiag.txt file
    1. Share the `dxdiag.txt` file
  