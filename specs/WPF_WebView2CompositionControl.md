
WPF Airspace - WebView2CompositionControl
===

# Background
For a long time, the WebView2 WPF control has had airspace issues, where the WebView2 control will always
be the top-most control in the WPF app. Any WPF element in the same location as the WebView2 control will
end up below the WebView2 control and be "invisible" to the end-user. This issue stems from the fact that
our WPF control uses the WPF HwndHost to host the Win32 WebView2 control, and HwndHost has a long-standing
issue with airspace. This issue has existed for over a decade, and you can read more about in-depth efforts to fix
it in general in WPF here:
https://dwayneneed.github.io/wpf/2013/02/26/mitigating-airspace-issues-in-wpf-applications.html

Solving this issue for WebView2 necessitates moving away from the HwndHost and the windowed hosting model
of WebView2, and instead use visuals to host the WebView2. To avoid compatibility issues and introducing
new regressions in the existing control, we decided to create a new WebView2 WPF control, called the WebView2CompositionControl.

# Examples
In this example we create a WebView2CompositionControl in exactly the same way we would a regular
WebView2 control in WPF. Additionally, we place a pink Label that appears ABOVE the WebView2CompositionControl.
If you were to instead do this with the regular WebView2 control, the Label would be hidden behind it.
```xml
    <DockPanel>

        <DockPanel
            DockPanel.Dock="Top">
            <Button
                x:Name="ButtonGo"
                DockPanel.Dock="Right"
                Click="ButtonGo_Click"
                Content="Go" />
            <TextBox Name="addressBar"/>
        </DockPanel>
        <Grid>
            <wv2:WebView2CompositionControl
                Name="webView"
                Source="https://www.microsoft.com"
                AllowExternalDrop="False"/>
            <Label
                Content="This is a label over the WebView2!"
                Background="LightPink"
                Height="100"
                Width="300"/>
        </Grid>
    </DockPanel>
```
![image](https://github.com/user-attachments/assets/023ad943-dca5-4f5e-a3f4-52258b35a6cd)


# API Details
If you are building a Windows Presentation Foundation (WPF) app and using the WebView2 control, you
may find that your app runs into "airspace" issues, where the WebView2 control will always show up
on top and hide any WPF elements in the same location, even if you try to specify the WPF elements
to be above the WebView2 control (using visual tree order or the z-index property, for example). To
solve this issue you should use the WebView2CompositionControl. 

The WebView2CompositionControl is a drop-in replacement
for the standard WPF WebView2 control - both the WebView2 control and the WebView2CompositionControl
implement the [Microsoft.Web.WebView2.Wpf.IWebView2](https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.wpf.iwebview2?view=webview2-dotnet-1.0.2739.15)
interface, as well as derive from FrameworkElement (`FrameworkElement -> HwndHost -> WebView2`, and
`FrameworkElement -> Control -> WebView2CompositionControl`). So anywhere you use
WebView2, you can instead change to a WebView2CompositionControl without changing your
code.

We chose the name "WebView2CompositionControl" because it matches our naming convention
for visual hosting WebView2, which uses the CoreWebView2CompositionController instead
of the CoreWebView2Controller.

Due to using a GraphicsCaptureSession to create a screen capture of the underlying browser processes,
there may be lower framerates compared to the standard WebView2 control, and DRM videos will be unable to play.

Reference documentation is very similar to the existing WPF control and can be found here:
https://learn.microsoft.com/en-us/dotnet/api/microsoft.web.webview2.wpf.webview2compositioncontrol?view=webview2-dotnet-1.0.2783-prerelease#remarks

# Appendix
At a high level, the WebView2CompositionControl instantiates a CoreWebView2 in much the same way as
the regular WebView2 control, but connects to it and controls it using the CoreWebView2CompositionController
instead of the CoreWebView2Controller. The composition controller is given a WinComp visual to draw into,
and this visual is used to create a GraphicsCaptureSession. When frames from this capture session are
captured they are they rendered into a WPF Image element that's part of the control.

