
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

The main differences are that:
1. WebView2 inherits from [HwndHost]([url](https://learn.microsoft.com/en-us/dotnet/api/system.windows.interop.hwndhost?view=windowsdesktop-8.0)),
whereas WebView2CompositionControl inherits from Control and [IKeyboardInputSite]([url](https://learn.microsoft.com/en-us/dotnet/api/system.windows.interop.ikeyboardinputsink?view=windowsdesktop-8.0)), which makes some of the protected overriden methods differ. In particular, WebView2 overrides HwndHost.BuildWindowCore, HwndHost.DestroyWindowCore, and HwndHost.TabIntoCore. WebView2CompositionControl overrides the IKeyboardInputSite properties/methods.
2. WebView2 uses windowed HWND hosting and the CoreWebView2Controller, whereas WebView2CompositionControl uses visual hosting and the CoreWebView2CompositionController. As such the WebView2CompositionControl needs to handle and forward appropriate input to the composition controller, instead of input going directly to the WebView2 HWNDs. To do this it overrides an extra set of input events, such as OnMouseDown/Up/Move/Wheel/DoubleClick, and OnTouchDown/Up/Move.

Full public/protected API:
```cs
/// <summary>
/// Visual hosting version of the WebView2 control.
/// </summary>
/// <remarks>
/// This control is effectively a wrapper around the [WebView2 COM
/// API](https://aka.ms/webview2). You can directly access the underlying
/// ICoreWebView2 interface and all of its functionality by accessing the
/// <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> property. Some of the most common COM
/// functionality is also accessible directly through wrapper
/// methods/properties/events on the control.
///
/// Upon creation, the control's <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> property will be
/// <c>null</c>. This is because creating the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> is an
/// expensive operation which involves things like launching Edge browser
/// processes. There are two ways to cause the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> to
/// be created:
/// <list type="bullet">
/// <item><description>
/// Call the <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.EnsureCoreWebView2Async(Microsoft.Web.WebView2.Core.CoreWebView2Environment,Microsoft.Web.WebView2.Core.CoreWebView2ControllerOptions)" /> method.  This is
/// referred to as explicit initialization.
/// </description></item>
/// <item><description>
/// Set the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.Source" /> property (which could be done from
/// markup, for example).  This is referred to as implicit initialization.
/// Either option will start initialization in the background and return
/// back to the caller without waiting for it to finish.
/// To specify options regarding the initialization process, either pass
/// your own <see cref="T:Microsoft.Web.WebView2.Core.CoreWebView2Environment" /> to <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.EnsureCoreWebView2Async(Microsoft.Web.WebView2.Core.CoreWebView2Environment,Microsoft.Web.WebView2.Core.CoreWebView2ControllerOptions)" /> or set the control's <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CreationProperties" /> property prior to initialization.
/// </description></item>
/// </list>
///
/// When initialization has finished (regardless of how it was triggered or
/// whether it succeeded) then the following things will occur, in this
/// order:
/// <list type="number">
/// <item><description>
/// The control's <see cref="E:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2InitializationCompleted" /> event
/// will be invoked. If you need to perform one time setup operations on
/// the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> prior to its use then you should
/// do so in a handler for that event.
/// </description></item>
/// <item><description>
/// If initialization was successful and a Uri has been set to the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.Source" /> property then the control will start navigating to it in
/// the background (i.e. these steps will continue without waiting for the
/// navigation to finish).
/// </description></item>
/// <item><description>
/// The Task returned from <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.EnsureCoreWebView2Async(Microsoft.Web.WebView2.Core.CoreWebView2Environment,Microsoft.Web.WebView2.Core.CoreWebView2ControllerOptions)" /> will
/// complete.
/// </description></item>
/// </list>
///
/// For more details about any of the methods/properties/events involved in
/// the initialization process, see its specific documentation.
///
/// Because the control's <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> is a very heavyweight
/// object (potentially responsible for multiple running processes and
/// megabytes of disk space) the control implements <see cref="T:System.IDisposable" /> to provide an explicit means to free it.
/// Calling <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.Dispose" /> will release the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" />
/// and its underlying resources (except any that are also being used by other
/// WebViews), and reset <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> to <c>null</c>. After <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.Dispose" /> has been called the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> cannot be
/// re-initialized, and any attempt to use functionality which requires it
/// will throw an <see cref="T:System.ObjectDisposedException" />.
///
/// Accelerator key presses (e.g. Ctrl+P) that occur within the control will
/// fire standard key press events such as OnKeyDown. You can suppress the
/// control's default implementation of an accelerator key press (e.g.
/// printing, in the case of Ctrl+P) by setting the Handled property of its
/// EventArgs to true. Also note that the underlying browser process is
/// blocked while these handlers execute, so:
/// <list type="number">
/// <item>
/// <description>You should avoid doing a lot of work in these handlers.</description>
/// </item>
/// <item><description>
/// Some of the WebView2 and CoreWebView2 APIs may throw errors if
/// invoked within these handlers due to being unable to communicate with
/// the browser process.
/// </description></item>
/// </list>
/// If you need to do a lot of work and/or invoke WebView2 APIs in response to
/// accelerator keys then consider kicking off a background task or queuing
/// the work for later execution on the UI thread.
///
/// This control extends <see cref="T:System.Windows.Controls.Control" /> in order to host the image
/// displaying WebView's content using template. This has some
/// implications regarding the control's input and output behavior as well as
/// the functionality it "inherits" from <see cref="T:System.Windows.UIElement" /> and <see cref="T:System.Windows.FrameworkElement" />.
///
/// The content of <see cref="T:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl" /> is rendered by an <see cref="T:System.Windows.Controls.Image" />.
/// By default, <see cref="P:System.Windows.FrameworkElement.UseLayoutRounding" /> of WebView2CompositionControl
/// is set to true. This can prevent the <see cref="T:System.Windows.Controls.Image" /> from becoming blurry at certain dimensions,
/// but it disables anti-aliasing. Set it to false if you want to keep the anti-aliasing.
/// </remarks>
/// <seealso cref="T:System.Windows.Controls.Control" />
[ToolboxItem(true)]
[TemplatePart(Name = "PART_image", Type = typeof(System.Windows.Controls.Image))]
public class WebView2CompositionControl : Control, IWebView2, IDisposable, IWebView2Private, IKeyboardInputSink
{
	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CreationProperties" /> property.
	/// </summary>
	/// <seealso cref="T:System.Windows.DependencyProperty" />
	public static readonly DependencyProperty CreationPropertiesProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.Source" /> property.
	/// </summary>
	public static readonly DependencyProperty SourceProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CanGoBack" /> property.
	/// </summary>
	public static readonly DependencyProperty CanGoBackProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CanGoForward" /> property.
	/// </summary>
	public static readonly DependencyProperty CanGoForwardProperty;

	private bool _webviewHasFocus;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.ZoomFactor" /> property.
	/// </summary>
	public static readonly DependencyProperty ZoomFactorProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.DefaultBackgroundColor" /> property.
	/// </summary>
	public static readonly DependencyProperty DefaultBackgroundColorProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="F:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.AllowExternalDropProperty" /> property.
	/// </summary>
	public static readonly DependencyProperty AllowExternalDropProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.DesignModeForegroundColor" /> property.
	/// </summary>
	public static readonly DependencyProperty DesignModeForegroundColorProperty;

	/// <summary>
	/// The WPF <see cref="T:System.Windows.DependencyProperty" /> which backs the <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.FpsDivider" /> property.
	/// </summary>
	public static readonly DependencyProperty FpsDividerProperty;

	/// <inheritdoc />
	[Category("Common")]
	public CoreWebView2CreationProperties CreationProperties
	{
		get
		set
	}

	/// <inheritdoc />
	[Browsable(false)]
	public CoreWebView2 CoreWebView2 => m_webview2Base.CoreWebView2;

	/// <inheritdoc />
	[Category("Common")]
	public Uri Source
	{
		get
		set
	}

	/// <inheritdoc />
	[Browsable(false)]
	public bool CanGoBack => (bool)GetValue(CanGoBackProperty);

	/// <inheritdoc />
	[Browsable(false)]
	public bool CanGoForward => (bool)GetValue(CanGoForwardProperty);

	/// <summary>
	/// WebView2Composition Control only needs IKeyboardInputSink:TabInto to get the direction of tab traversal.
	/// KeyboardInputSite is not implemented by WebView2Composition.
	/// </summary>
	public IKeyboardInputSite KeyboardInputSite
	{
		get
		set
	}

	/// <inheritdoc />
	[Category("Common")]
	public double ZoomFactor
	{
		get
		set
	}

	/// <inheritdoc />
	[Category("Common")]
	public System.Drawing.Color DefaultBackgroundColor
	{
		get
		set
	}

	/// <inheritdoc />
	[Category("Common")]
	public bool AllowExternalDrop
	{
		get
		set
	}

	/// <inheritdoc />
	[Category("Common")]
	public System.Drawing.Color DesignModeForegroundColor
	{
		get
		set
	}

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new System.Windows.Media.Brush OpacityMask => base.OpacityMask;

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new double Opacity => base.Opacity;

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new Effect Effect => base.Effect;

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new ContextMenu ContextMenu => base.ContextMenu;

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new Style FocusVisualStyle => base.FocusVisualStyle;

	[Browsable(false)]
	[EditorBrowsable(EditorBrowsableState.Never)]
	public new InputScope InputScope => base.InputScope;

	/// <inheritdoc />
	public event EventHandler<CoreWebView2InitializationCompletedEventArgs> CoreWebView2InitializationCompleted

	/// <inheritdoc />
	public event EventHandler<CoreWebView2SourceChangedEventArgs> SourceChanged

	/// <inheritdoc />
	public event EventHandler<CoreWebView2NavigationStartingEventArgs> NavigationStarting

	/// <inheritdoc />
	public event EventHandler<CoreWebView2NavigationCompletedEventArgs> NavigationCompleted

	/// <inheritdoc />
	public event EventHandler<EventArgs> ZoomFactorChanged

	/// <inheritdoc />
	public event EventHandler<CoreWebView2ContentLoadingEventArgs> ContentLoading

	/// <inheritdoc />
	public event EventHandler<CoreWebView2WebMessageReceivedEventArgs> WebMessageReceived

	/// <summary>
	/// <see cref="M:System.Windows.FrameworkElement.OnApplyTemplate" /> interface.
	/// </summary>
	public override void OnApplyTemplate()

	/// <summary>
	/// Creates a new instance of a WebView2Composition control.
	/// Note that the control's <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> will be null until initialized.
	/// See the <see cref="T:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl" /> class documentation for an initialization overview.
	/// </summary>
	public WebView2CompositionControl()

	/// <summary>
	/// Send the pointer event to the WebView2 Control.
	/// </summary>
	/// <seealso cref="M:Microsoft.Web.WebView2.Core.CoreWebView2CompositionController.SendPointerInput(Microsoft.Web.WebView2.Core.CoreWebView2PointerEventKind,Microsoft.Web.WebView2.Core.CoreWebView2PointerInfo)" />
	public void SendPointerInput(CoreWebView2PointerEventKind eventKind, CoreWebView2PointerInfo pointerInfo)

	/// <summary>
	/// This is an event handler for WPF control's OnTouchDown event.
	/// We use CoreWebView2CompositionController.SendPointerInput to send the touch input to our browser.
	/// </summary>
	protected override void OnTouchDown(TouchEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnTouchMove event.
	/// We use CoreWebView2CompositionController.SendPointerInput to send the touch input to our browser.
	/// </summary>
	protected override void OnTouchMove(TouchEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnTouchUp event.
	/// We use CoreWebView2CompositionController.SendPointerInput to send the touch input to our browser.
	/// </summary>
	protected override void OnTouchUp(TouchEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnMouseMove event.
	/// We use CoreWebView2CompositionController.SendMouseInput to send the mouse input to our browser.
	/// </summary>
	protected override void OnMouseMove(MouseEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnMouseDown event.
	/// We use CoreWebView2CompositionController.SendMouseInput to send the mouse input to our browser.
	/// </summary>
	protected override void OnMouseDown(MouseButtonEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnMouseUp event.
	/// We use CoreWebView2CompositionController.SendMouseInput to send the mouse input to our browser.
	/// </summary>
	protected override void OnMouseUp(MouseButtonEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnMouseWheel event.
	/// We use CoreWebView2CompositionController.SendMouseInput to send the input to our browser.
	/// </summary>
	protected override void OnMouseWheel(MouseWheelEventArgs e)

	/// <summary>
	/// This is an event handler for WPF control's OnMouseDoubleClick event.
	/// We use CoreWebView2CompositionController.SendMouseInput to send the input to our browser.
	/// </summary>
	protected override void OnMouseDoubleClick(MouseButtonEventArgs e)

	/// <summary>
	/// Override for painting to draw
	/// </summary>
	/// <param name="dc">The tools to handle the drawing via <see cref="T:System.Windows.Media.DrawingContext" />.</param>
	protected override void OnRender(DrawingContext dc)

	/// <inheritdoc />
	public Task EnsureCoreWebView2Async(CoreWebView2Environment environment = null, CoreWebView2ControllerOptions controllerOptions = null)

	/// <inheritdoc />
	public Task EnsureCoreWebView2Async(CoreWebView2Environment environment)

	/// <summary>
	/// Implementation of the <see cref="T:System.IDisposable" /> pattern.
	/// This will release all of our underlying COM resources.
	/// </summary>
	public void Dispose()

	/// <summary>
	/// Implementation of the ISupportInitialize pattern.
	/// Prevents the control from implicitly initializing its <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CoreWebView2" /> until <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.EndInit" /> is called.
	/// Does *not* prevent explicit initialization of the CoreWebView2 (i.e. <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.EnsureCoreWebView2Async(Microsoft.Web.WebView2.Core.CoreWebView2Environment,Microsoft.Web.WebView2.Core.CoreWebView2ControllerOptions)" />).
	/// Mainly intended for use by interactive UI designers.
	/// </summary>
	/// <remarks>
	/// Note that the "Initialize" in ISupportInitialize and the "Init" in BeginInit/EndInit mean
	/// something different and more general than this control's specific concept of initializing
	/// its CoreWebView2 (explicitly or implicitly).  This ISupportInitialize pattern is a general
	/// way to set batches of properties on the control to their initial values without triggering
	/// any dependent side effects until all of the values are set (i.e. until EndInit is called).
	/// In the case of this control, a specific side effect to be avoided is triggering implicit
	/// initialization of the CoreWebView2 when setting the Source property.
	/// For example, normally if you set <see cref="P:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.CreationProperties" /> after you've already set Source,
	/// the data set to CreationProperties is ignored because implicit initialization has already started.
	/// However, if you set the two properties (in the same order) in between calls to BeginInit and
	/// EndInit then the implicit initialization of the CoreWebView2 is delayed until EndInit, so the data
	/// set to CreationProperties is still used even though it was set after Source.
	/// </remarks>
	public override void BeginInit()

	/// <summary>
	/// Implementation of the ISupportInitialize pattern.
	/// Invokes any functionality that has been delayed since the corresponding call to <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.BeginInit" />.
	/// Mainly intended for use by interactive UI designers.
	/// </summary>
	/// <remarks>
	/// See the documentation of <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.BeginInit" /> for more information.
	/// </remarks>
	public override void EndInit()

	/// <summary>
	/// We override the  <see cref="M:System.Windows.UIElement.OnGotFocus(System.Windows.RoutedEventArgs)" /> to prevent the focus event from propagating.
	/// We expect the event raised from <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2Base.CoreWebView2Controller_GotFocus(System.Object,System.Object)" />
	/// </summary>
	protected override void OnGotFocus(RoutedEventArgs e)

	/// <summary>
	/// We override the  <see cref="M:System.Windows.UIElement.OnLostFocus(System.Windows.RoutedEventArgs)" /> to prevent the focus event from propagating.
	/// We expect the event raised from <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2Base.CoreWebView2Controller_LostFocus(System.Object,System.Object)" />
	/// </summary>
	protected override void OnLostFocus(RoutedEventArgs e)

	/// <summary>
	/// IKeyboardInputSink:HasFocusWithin interface.
	/// Whether WebView has focus.
	/// </summary>
	public bool HasFocusWithin()

	/// <summary>
	/// IKeyboardInputSink:OnMnemonic interface.
	/// Not implemented by WebView2.
	/// </summary>
	public bool OnMnemonic(ref MSG msg, ModifierKeys modifiers)

	/// <summary>
	/// IKeyboardInputSink:RegisterKeyboardInputSink interface.
	/// Not implemented by WebView2.
	/// </summary>
	public IKeyboardInputSite RegisterKeyboardInputSink(IKeyboardInputSink sink)

	/// <summary>
	/// IKeyboardInputSink:TabInto interface.
	/// </summary>
	public bool TabInto(TraversalRequest request)

	/// <summary>
	/// IKeyboardInputSink:TranslateAccelerator interface.
	/// Not implemented by WebView2.
	/// </summary>
	public bool TranslateAccelerator(ref MSG msg, ModifierKeys modifiers)

	/// <summary>
	/// IKeyboardInputSink:TranslateChar interface.
	/// Not implemented by WebView2.
	/// </summary>
	public bool TranslateChar(ref MSG msg, ModifierKeys modifiers)

	/// <summary>
	/// This is overridden from <see cref="T:System.Windows.UIElement" /> and called to allow us to handle key press input.
	/// WPF should never actually call this in response to keyboard events because the focus is on the controller's HWND.
	/// When Controller's HWND has focus, WPF does not know the Controller's HWND belongs to this control, and the key event will not be fired for this control and WPF main window.
	/// This override should only be called when we're explicitly forwarding accelerator key input from the CoreWebView2 to WPF (in CoreWebView2Controller_AcceleratorKeyPressed).
	/// Even then, this KeyDownEvent is only triggered because our PreviewKeyDownEvent implementation explicitly triggers it, matching WPF's usual system.
	/// So the process is:
	/// <list type="number">
	/// <item><description>CoreWebView2Controller_AcceleratorKeyPressed</description></item>
	/// <item><description>PreviewKeyDownEvent</description></item>
	/// <item><description>KeyDownEvent</description></item>
	/// <item><description>OnKeyDown</description></item>
	/// </list>
	/// .
	/// </summary>
	protected override void OnKeyDown(KeyEventArgs e)

	/// <summary>
	/// See <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.OnKeyDown(System.Windows.Input.KeyEventArgs)" />.
	/// </summary>
	protected override void OnKeyUp(KeyEventArgs e)

	/// <summary>
	/// This is the "Preview" (i.e. tunneling) version of <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.OnKeyDown(System.Windows.Input.KeyEventArgs)" />, so it actually happens first.
	/// Like OnKeyDown, this will only ever be called if we're explicitly forwarding key presses from the CoreWebView2.
	/// In order to mimic WPF's standard input handling, when we receive this we turn around and fire off the standard bubbling KeyDownEvent.
	/// That way others in the WPF tree see the same standard pair of input events that WPF itself would have triggered if it were handling the key press.
	/// </summary>
	/// <seealso cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.OnKeyDown(System.Windows.Input.KeyEventArgs)" />
	protected override void OnPreviewKeyDown(KeyEventArgs e)

	/// <summary>
	/// See <see cref="M:Microsoft.Web.WebView2.Wpf.WebView2CompositionControl.OnPreviewKeyDown(System.Windows.Input.KeyEventArgs)" />.
	/// </summary>
	protected override void OnPreviewKeyUp(KeyEventArgs e)

	/// <inheritdoc />
	public void GoBack()

	/// <inheritdoc />
	public void GoForward()

	/// <inheritdoc />
	public void Reload()

	/// <inheritdoc />
	public void Stop()

	/// <inheritdoc />
	public void NavigateToString(string htmlContent)

	/// <inheritdoc />
	public async Task<string> ExecuteScriptAsync(string javaScript)
}
```

# Appendix
At a high level, the WebView2CompositionControl instantiates a CoreWebView2 in much the same way as
the regular WebView2 control, but connects to it and controls it using the CoreWebView2CompositionController
instead of the CoreWebView2Controller. The composition controller is given a WinComp visual to draw into,
and this visual is used to create a GraphicsCaptureSession. When frames from this capture session are
captured they are they rendered into a WPF Image element that's part of the control.

