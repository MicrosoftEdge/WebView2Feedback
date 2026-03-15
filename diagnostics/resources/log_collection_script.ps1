param(
    [Parameter(Mandatory=$false)]
    [string]$ZipPath = "$PSScriptRoot",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = "$env:TEMP",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseCPUProfile = $true,

    [Parameter(Mandatory=$false)]
    [string]$ExeName = "",

    [Parameter(Mandatory=$false)]
    [string]$UserDataDir = ""
)

# Load Windows Forms assembly for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Variables to hold file paths for zipping
$OutPath = ""
$script:RegistryFilePath = ""
$script:DirectoryFilePath = ""
$script:FinalZipPath = ""

$webviewWPRCPUProfile = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Comments="" Company="Microsoft Corporation" Copyright="Microsoft Corporation">
    <Profiles>
        <SystemProvider Id="SystemProvider_Light">
            <Keywords>
                <!-- CPU -->
                <Keyword Value="ProcessThread"/>
                <Keyword Value="Loader"/>
                <Keyword Value="Power"/>
                <Keyword Value="CSwitch"/>
                <Keyword Value="ReadyThread"/>
                <Keyword Value="SampledProfile"/>
                <Keyword Value="DPC"/>
                <Keyword Value="Interrupt"/>
                <Keyword Value="IdleStates"/>

                <!-- Disk -->
                <Keyword Value="DiskIO"/>
                <Keyword Value="FileIO"/>
                <Keyword Value="HardFaults"/>

                <!-- Memory -->
                <Keyword Value="MemoryInfo"/>
                <Keyword Value="MemoryInfoWS"/>
            </Keywords>
            <Stacks>
                <Stack Value="CSwitch"/>
                <Stack Value="ReadyThread"/>
                <Stack Value="SampledProfile"/>
            </Stacks>
        </SystemProvider>

        <!-- Crash reporting events -->
        <EventProvider Id="EventProvider-Microsoft-Windows-WindowsErrorReporting" Name="cc79cf77-70d9-4082-9b52-23f3a3e92fe4"/>
        <EventProvider Id="EventProvider-Microsoft.Windows.FaultReportingTracingGuid" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>
        <EventProvider Id="Edge_Crashpad" Name="94061CA0-FB42-5B87-F7F1-254B0A86F9FD"/>

        <!-- Process, thread, and image load events -->
        <EventProvider Id="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" Name="22fb2cd6-0e7b-422b-a0c7-2fad1fd0e716" NonPagedMemory="true" Stack="true" Level="0" EventKey="true">
            <Keywords>
                <Keyword Value="0x190" />
            </Keywords>
        </EventProvider>

        <!-- WV2 events. Edge providers are included to support tracing when using pre-release runtimes. -->
        <EventProvider Id="Edge" Name="3A5F2396-5C8F-4F1F-9B67-6CCA6C990E61" Level="5">
            <Keywords>
                <Keyword Value="0x10000000202F"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Canary" Name="C56B8664-45C5-4E65-B3C7-A8D6BD3F2E67" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Dev" Name="D30B5C9F-B58F-4DC9-AFAF-134405D72107" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Beta" Name="BD089BAA-4E52-4794-A887-9E96868570D2" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_WebView" Name="E16EC3D2-BB0F-4E8F-BDB8-DE0BEA82DC3D" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Provider_V8js" Name="57277741-3638-4A4B-BDBA-0AC6E45DA56C" Level="5" Stack="true"></EventProvider>

        <Profile Id="Edge.WebView2.General.Verbose.File" Name="Edge.WebView2.General" LoggingMode="File" DetailLevel="Verbose" Description="Edge.WebView2.General" Default="true">
            <Collectors Operation="Add">
                <SystemCollectorId Value="SystemCollector_WPRSystemCollectorInFile">
                    <BufferSize Value="1024"/>
                    <Buffers Value="100"/>
                    <SystemProviderId Value="SystemProvider_Light" />
                </SystemCollectorId>
                <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
                    <BufferSize Value="1024" />
                    <Buffers Value="3" PercentageOfTotalMemory="true"/>
                    <EventProviders Operation="Add">
                        <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
                        <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
                        <EventProviderId Value="Edge_Crashpad"/>
                        <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" />
                        <EventProviderId Value="Edge" />
                        <EventProviderId Value="Edge_Canary" />
                        <EventProviderId Value="Edge_Dev" />
                        <EventProviderId Value="Edge_Beta" />
                        <EventProviderId Value="Edge_WebView" />
                        <EventProviderId Value="Provider_V8js"></EventProviderId>
                    </EventProviders>
                </EventCollectorId>
            </Collectors>
        </Profile>
    </Profiles>
</WindowsPerformanceRecorder>
"@

$webviewWPRProfile = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Comments="" Company="Microsoft Corporation" Copyright="Microsoft Corporation">
    <Profiles>
        <SystemProvider Id="SystemProvider_Light">
            <Keywords>
                <!-- CPU -->
                <Keyword Value="ProcessThread"/>
                <Keyword Value="Loader"/>
                <Keyword Value="Power"/>
                <Keyword Value="CSwitch"/>
                <Keyword Value="ReadyThread"/>
                <Keyword Value="DPC"/>
                <Keyword Value="Interrupt"/>
                <Keyword Value="IdleStates"/>

                <!-- Disk -->
                <Keyword Value="DiskIO"/>
                <Keyword Value="FileIO"/>
                <Keyword Value="HardFaults"/>

                <!-- Memory -->
                <Keyword Value="MemoryInfo"/>
                <Keyword Value="MemoryInfoWS"/>
            </Keywords>
            <Stacks>
                <Stack Value="CSwitch"/>
                <Stack Value="ReadyThread"/>
            </Stacks>
        </SystemProvider>

        <!-- Crash reporting events -->
        <EventProvider Id="EventProvider-Microsoft-Windows-WindowsErrorReporting" Name="cc79cf77-70d9-4082-9b52-23f3a3e92fe4"/>
        <EventProvider Id="EventProvider-Microsoft.Windows.FaultReportingTracingGuid" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>
        <EventProvider Id="Edge_Crashpad" Name="94061CA0-FB42-5B87-F7F1-254B0A86F9FD"/>

        <!-- Process, thread, and image load events -->
        <EventProvider Id="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" Name="22fb2cd6-0e7b-422b-a0c7-2fad1fd0e716" NonPagedMemory="true" Stack="true" Level="0" EventKey="true">
            <Keywords>
                <Keyword Value="0x190" />
            </Keywords>
        </EventProvider>

        <!-- WV2 events. Edge providers are included to support tracing when using pre-release runtimes. -->
        <EventProvider Id="Edge" Name="3A5F2396-5C8F-4F1F-9B67-6CCA6C990E61" Level="5">
            <Keywords>
                <Keyword Value="0x10000000202F"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Canary" Name="C56B8664-45C5-4E65-B3C7-A8D6BD3F2E67" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Dev" Name="D30B5C9F-B58F-4DC9-AFAF-134405D72107" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Beta" Name="BD089BAA-4E52-4794-A887-9E96868570D2" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_WebView" Name="E16EC3D2-BB0F-4E8F-BDB8-DE0BEA82DC3D" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Provider_V8js" Name="57277741-3638-4A4B-BDBA-0AC6E45DA56C" Level="5" Stack="true"></EventProvider>

        <Profile Id="Edge.WebView2.General.Verbose.File" Name="Edge.WebView2.General" LoggingMode="File" DetailLevel="Verbose" Description="Edge.WebView2.General" Default="true">
            <Collectors Operation="Add">
                <SystemCollectorId Value="SystemCollector_WPRSystemCollectorInFile">
                    <BufferSize Value="1024"/>
                    <Buffers Value="100"/>
                    <SystemProviderId Value="SystemProvider_Light" />
                </SystemCollectorId>
                <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
                    <BufferSize Value="1024" />
                    <Buffers Value="3" PercentageOfTotalMemory="true"/>
                    <EventProviders Operation="Add">
                        <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
                        <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
                        <EventProviderId Value="Edge_Crashpad"/>
                        <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" />
                        <EventProviderId Value="Edge" />
                        <EventProviderId Value="Edge_Canary" />
                        <EventProviderId Value="Edge_Dev" />
                        <EventProviderId Value="Edge_Beta" />
                        <EventProviderId Value="Edge_WebView" />
                        <EventProviderId Value="Provider_V8js"></EventProviderId>
                    </EventProviders>
                </EventCollectorId>
            </Collectors>
        </Profile>
    </Profiles>
</WindowsPerformanceRecorder>
"@

# Function to start WPR tracing
function StartWPR {
    param(
        [string]$OutputDirectory,
        [string]$OutPath,
        [bool]$UseCPUProfile
    )

    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Error "This script requires administrator privileges to start/stop WPR tracing."
        Write-Host "Please right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
        exit 1
    }
    
    # Select the appropriate profile based on parameter
    if ($UseCPUProfile) {
        $selectedProfile = $webviewWPRCPUProfile
        $profileType = "CPU"
        Write-Host "Using CPU profile for performance analysis" -ForegroundColor Cyan
    } else {
        $selectedProfile = $webviewWPRProfile
        $profileType = "General"
        Write-Host "Using general profile for comprehensive logging" -ForegroundColor Cyan
    }

    # Create the temporary WPRP file
    $tempWprpPath = "$OutputDirectory\webview2-$profileType.wprp"
    Write-Host "Creating WPR profile at: $tempWprpPath" -ForegroundColor Green

    try {
        $selectedProfile | Out-File -FilePath $tempWprpPath -Encoding utf8
        Write-Host "Profile file created successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create profile file: $($_.Exception.Message)"
        exit 1
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutPath = "$OutputDirectory\webview2-trace_$timestamp.etl"
    Write-Host "Saving webview2 trace to : $OutPath" -ForegroundColor Yellow

    # Start WPR tracing
    Write-Host "Starting WPR tracing..." -ForegroundColor Green
    try {
        $result = wpr -start $tempWprpPath -filemode 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "WPR tracing started successfully!" -ForegroundColor Green
            Write-Host "Trace will be saved to: $OutPath" -ForegroundColor Cyan
            
            # Show the GUI window for stopping
            Show-StopWPRWindow -TracePath $OutPath
        }
        else {
            Write-Error "WPR failed with exit code: $LASTEXITCODE"
            Write-Host "WPR output: $result" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Error "Failed to start WPR: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create zip archive with all collected files
function Create-DiagnosticZip {
    param(
        [string]$RegistryFilePath,
        [string]$DirectoryFilePath,
        [string]$TraceFilePath,
        [string]$ZipPath,
        [string]$CrashpadFolderPath = ""
    )
    
    try {
        # Generate timestamp for unique zip filename
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $zipFileName = "WebView2_Diagnostics_$timestamp.zip"
        $fullZipPath = Join-Path $ZipPath $zipFileName
        
        Write-Host "Creating diagnostic zip archive..." -ForegroundColor Green
        Write-Host "Zip location: $fullZipPath" -ForegroundColor Cyan
        
        # Ensure the zip destination directory exists
        if (-not (Test-Path $ZipPath)) {
            New-Item -Path $ZipPath -ItemType Directory -Force | Out-Null
            Write-Host "Created destination directory: $ZipPath" -ForegroundColor Yellow
        }
        
        # Remove existing zip file if it exists
        if (Test-Path $fullZipPath) {
            Remove-Item $fullZipPath -Force
        }
        
        # Create the zip archive
        $zip = [System.IO.Compression.ZipFile]::Open($fullZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        
        # Add files to zip if they exist
        $filesToZip = @(
            @{ Path = $RegistryFilePath; Name = "EdgeUpdate_Registry.txt" }
            @{ Path = $DirectoryFilePath; Name = "EdgeWebView_Directory.txt" }
            @{ Path = $TraceFilePath; Name = "WebView2_Trace.etl" }
            @{ Path = "C:\ProgramData\Microsoft\EdgeUpdate\Log\MicrosoftEdgeUpdate.log"; Name = "MicrosoftEdgeUpdate.log" }
            @{ Path = [System.Environment]::ExpandEnvironmentVariables("%localappdata%\Temp\MicrosoftEdgeUpdate.log"); Name = "MicrosoftEdgeUpdate_LocalAppData.log" }
            @{ Path = [System.Environment]::ExpandEnvironmentVariables("%temp%\msedge_installer.log"); Name = "msedge_installer_Temp.log" }
            @{ Path = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\Temp\msedge_installer.log"); Name = "msedge_installer_SystemTemp.log" }
            @{ Path = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\SystemTemp\msedge_installer.log"); Name = "msedge_installer_SystemTemp2.log" }
        )
        
        $addedFiles = @()  # Track successfully added files for cleanup
        
        foreach ($file in $filesToZip) {
            if ($file.Path -and (Test-Path $file.Path)) {
                try {
                    $entry = $zip.CreateEntry($file.Name)
                    $entryStream = $entry.Open()
                    
                    # Use FileShare.ReadWrite to handle files locked by other processes
                    $fileStream = [System.IO.File]::Open($file.Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $fileStream.CopyTo($entryStream)
                    $fileStream.Close()
                    $entryStream.Close()
                    
                    # Calculate file size for display
                    $fileSize = (Get-Item $file.Path).Length / 1MB
                    Write-Host "  Added to zip: $($file.Name) ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Cyan
                    
                    # Track files for cleanup (only temp files we created)
                    if ($file.Path -eq $RegistryFilePath -or $file.Path -eq $DirectoryFilePath -or $file.Path -eq $TraceFilePath) {
                        $addedFiles += $file.Path
                    }
                }
                catch {
                    Write-Host "  Failed to add $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "  Continuing with other files..." -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "  Skipped (not found): $($file.Name)" -ForegroundColor Red
            }
        }
        
        # Add Crashpad folder if it exists
        if ($CrashpadFolderPath -and (Test-Path $CrashpadFolderPath)) {
            try {
                Write-Host "Adding Crashpad folder contents..." -ForegroundColor Cyan
                $crashpadFiles = Get-ChildItem -Path $CrashpadFolderPath -Recurse -File -ErrorAction SilentlyContinue
                
                # Trim trailing backslash to ensure correct substring calculation
                $crashpadBasePath = $CrashpadFolderPath.TrimEnd('\')
                
                foreach ($crashpadFile in $crashpadFiles) {
                    try {
                        # Get relative path within Crashpad folder
                        $relativePath = $crashpadFile.FullName.Substring($crashpadBasePath.Length + 1)
                        $zipEntryName = "Crashpad/$relativePath".Replace("\", "/")
                        
                        $entry = $zip.CreateEntry($zipEntryName)
                        $entryStream = $entry.Open()
                        
                        $fileStream = [System.IO.File]::Open($crashpadFile.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        $fileStream.CopyTo($entryStream)
                        $fileStream.Close()
                        $entryStream.Close()
                        
                        $fileSize = $crashpadFile.Length / 1KB
                        Write-Host "  Added to zip: Crashpad/$relativePath ($([math]::Round($fileSize, 2)) KB)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "  Failed to add $($crashpadFile.Name): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            catch {
                Write-Host "  Failed to add Crashpad folder: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $zip.Dispose()
        
        # Calculate final zip size
        $zipSize = (Get-Item $fullZipPath).Length / 1MB
        Write-Host "Diagnostic zip created successfully!" -ForegroundColor Green
        Write-Host "Final zip size: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Cyan
        Write-Host "Zip location: $fullZipPath" -ForegroundColor Green
        
        # Clean up temporary files after successful zip creation
        foreach ($filePath in $addedFiles) {
            if (Test-Path $filePath) {
                try {
                    Remove-Item $filePath -Force
                }
                catch {
                    Write-Host "Warning: Could not clean up temporary file: $filePath" -ForegroundColor Yellow
                }
            }            
        }
        
        # Also clean up any temporary .wprp files in the OutputDirectory
        try {
            $wprpFiles = Get-ChildItem -Path (Split-Path $RegistryFilePath -Parent) -Filter "webview2-*.wprp" -ErrorAction SilentlyContinue
            foreach ($wprpFile in $wprpFiles) {
                Remove-Item $wprpFile.FullName -Force
            }
        }
        catch {
            Write-Host "Warning: Could not clean up .wprp files" -ForegroundColor Yellow
        }
        
        
        return $fullZipPath
    }
    catch {
        Write-Host "Failed to create diagnostic zip: $($_.Exception.Message)" -ForegroundColor Red
        if ($zip) {
            $zip.Dispose()
        }
        return $null
    }
}

# Function to stop WPR and display results
function Stop-WPRTrace {
    param([string]$TracePath)
    
    try {
        $queryResult = wpr -status 2>&1
        if ($LASTEXITCODE -ne 0 -or $queryResult -match "not recording") {
            Write-Host "WPR is not currently running. No action needed." -ForegroundColor Green
            return
        }
        
        Write-Host "Stopping WPR tracing and saving to: $TracePath" -ForegroundColor Green
        $result = wpr -stop "$TracePath" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $fileSize = (Get-Item $TracePath -ErrorAction SilentlyContinue).Length / 1MB
            Write-Host "WPR tracing stopped successfully!" -ForegroundColor Green
            Write-Host "Trace file saved to: $TracePath" -ForegroundColor Green
            Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
            
            # Create diagnostic zip with all collected files
            Write-Host ""
            Write-Host "Creating diagnostic package..." -ForegroundColor Cyan
            $zipResult = Create-DiagnosticZip -RegistryFilePath $script:RegistryFilePath -DirectoryFilePath $script:DirectoryFilePath -TraceFilePath $TracePath -ZipPath $script:FinalZipPath -CrashpadFolderPath $script:CrashpadFolderPath
            
            if ($zipResult) {
                Write-Host "All diagnostic files have been packaged and saved to: $zipResult" -ForegroundColor Green
            }
            else {
                Write-Host "Warning: Failed to create diagnostic zip package" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "WPR stop failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "WPR output: $result" -ForegroundColor Red
        }
    }
    catch {
       Write-Host "Failed to check or stop WPR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to create and show the stop WPR window
function Show-StopWPRWindow {
    param([string]$TracePath)
    
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "WebView2 WPR Trace Collection"
    $form.Size = New-Object System.Drawing.Size(400, 200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $false
    
    # Create label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "WPR tracing is currently running.`n`nReproduce the issue you want to capture,`nthen click 'Stop WPR Trace' to save the log."
    $label.Size = New-Object System.Drawing.Size(360, 80)
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.TextAlign = "MiddleCenter"
    
    # Create stop button
    $stopButton = New-Object System.Windows.Forms.Button
    $stopButton.Text = "Stop WPR Trace"
    $stopButton.Size = New-Object System.Drawing.Size(120, 30)
    $stopButton.Location = New-Object System.Drawing.Point(140, 110)
    $stopButton.BackColor = [System.Drawing.Color]::LightCoral
    
    # Add click event for stop button
    $stopButton.Add_Click({
        # Close the window immediately
        $form.Close()
        
        # Stop WPR trace
        Stop-WPRTrace -TracePath $TracePath
    })
    
    # Add form closing event to stop WPR when X button is clicked
    $form.Add_FormClosing({
        param($sender, $e)
        
        # Stop WPR trace
        Stop-WPRTrace -TracePath $TracePath
    })
    
    # Add controls to form
    $form.Controls.Add($label)
    $form.Controls.Add($stopButton)
    
    # Show form
    $form.ShowDialog() | Out-Null
    $form.Dispose()
}

# Function to export EdgeWebView directory information
function Export-EdgeWebViewDirectory {
    param(
        [string]$OutputDirectory = "$env:TEMP"
    )
    
    try {
        # Generate timestamp for unique filename
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $outputFileName = "EdgeWebView_Directory_$timestamp.txt"
        $outputFilePath = Join-Path $OutputDirectory $outputFileName
        
        Write-Host "Exporting EdgeWebView directory information..." -ForegroundColor Green
        
        # Initialize output content
        $output = @()
        $output += "EdgeWebView Directory Information"
        $output += "Generated on: $(Get-Date)"
        $output += "=" * 50
        $output += ""
        
        # Directory paths to check
        $directoryPaths = @(
            "C:\Program Files (x86)\Microsoft\EdgeWebView",
            "C:\Program Files (x86)\Microsoft\EdgeCore"
        )
        
        foreach ($dirPath in $directoryPaths) {
            $output += "Directory Path: $dirPath"
            $output += "-" * 40
            
            try {
                # Check if the directory exists
                if (Test-Path $dirPath) {
                    Write-Host "Found directory: $dirPath" -ForegroundColor Cyan
                    
                    try {
                        # Get directory listing recursively (equivalent to dir /s)
                        $items = Get-ChildItem -Path $dirPath -Recurse -ErrorAction SilentlyContinue
                        
                        if ($items) {
                            foreach ($item in $items) {
                                if ($item.PSIsContainer) {
                                    # Directory
                                    $output += "  DIR  $($item.FullName)"
                                } else {
                                    # File with size and date
                                    $size = $item.Length
                                    $date = $item.LastWriteTime.ToString("MM/dd/yyyy  hh:mm tt")
                                    $output += "  $date  $size  $($item.FullName)"
                                }
                            }
                        } else {
                            $output += "  Directory is empty or no accessible items found"
                        }
                    }
                    catch {
                        Write-Host "Error reading directory contents: $($_.Exception.Message)" -ForegroundColor Red
                        $output += "  Error reading directory: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "Directory not found: $dirPath" -ForegroundColor Yellow
                    $output += "  Directory not found"
                }
            }
            catch {
                Write-Host "Error accessing $dirPath : $($_.Exception.Message)" -ForegroundColor Red
                $output += "  Error: $($_.Exception.Message)"
            }
            
            $output += ""
        }
        
        # Write output to file
        $output | Out-File -FilePath $outputFilePath -Encoding UTF8
        
        Write-Host "EdgeWebView directory information exported successfully!" -ForegroundColor Green
        Write-Host "Output file: $outputFilePath" -ForegroundColor Yellow
        
        return $outputFilePath
    }
    catch {
        Write-Host "Failed to export EdgeWebView directory information: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to export EdgeUpdate registry information
function Export-EdgeUpdateRegistry {
    param(
        [string]$OutputDirectory = "$env:TEMP"
    )
    
    try {
        # Generate timestamp for unique filename
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $outputFileName = "EdgeUpdate_Registry_$timestamp.txt"
        $outputFilePath = Join-Path $OutputDirectory $outputFileName
        
        Write-Host "Exporting EdgeUpdate registry information..." -ForegroundColor Green
        
        # Initialize output content
        $output = @()
        $output += "EdgeUpdate Registry Information"
        $output += "Generated on: $(Get-Date)"
        $output += "=" * 50
        $output += ""
        
        # Registry paths to check
        $registryPaths = @(
            "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\ClientState",
            "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\ClientState"
        )
        
        foreach ($regPath in $registryPaths) {
            $output += "Registry Path: $regPath"
            $output += "-" * 40
            
            try {
                # Check if the registry key exists
                if (Test-Path $regPath) {
                    Write-Host "Found registry path: $regPath" -ForegroundColor Cyan
                    
                    # Get all subkeys
                    $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                    
                    if ($subKeys) {
                        foreach ($subKey in $subKeys) {
                            $output += "  Subkey: $($subKey.Name)"
                            
                            # Get all properties of the subkey
                            try {
                                $properties = Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue
                                if ($properties) {
                                    foreach ($property in $properties.PSObject.Properties) {
                                        # Skip PowerShell internal properties
                                        if ($property.Name -notmatch "^PS") {
                                            $output += "    $($property.Name): $($property.Value)"
                                        }
                                    }
                                }
                            }
                            catch {
                                $output += "    Error reading properties: $($_.Exception.Message)"
                            }
                            $output += ""
                        }
                    } else {
                        $output += "  No subkeys found"
                    }
                    
                    # Also try to get direct properties of the main key
                    try {
                        $mainProperties = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                        if ($mainProperties) {
                            $output += "  Direct properties:"
                            foreach ($property in $mainProperties.PSObject.Properties) {
                                if ($property.Name -notmatch "^PS") {
                                    $output += "    $($property.Name): $($property.Value)"
                                }
                            }
                        }
                    }
                    catch {
                        $output += "  Error reading main key properties: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "Registry path not found: $regPath" -ForegroundColor Yellow
                    $output += "  Registry key not found"
                }
            }
            catch {
                Write-Host "Error accessing $regPath : $($_.Exception.Message)" -ForegroundColor Red
                $output += "  Error: $($_.Exception.Message)"
            }
            
            $output += ""
        }
        
        # Write output to file
        $output | Out-File -FilePath $outputFilePath -Encoding UTF8
        
        Write-Host "Registry information exported successfully!" -ForegroundColor Green
        Write-Host "Output file: $outputFilePath" -ForegroundColor Yellow
        
        return $outputFilePath
    }
    catch {
        Write-Host "Failed to export registry information: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get user data folders from WebView2 processes
function Get-WebView2UserDataFolder {
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExeName,
        
        [Parameter(Mandatory=$false)]
        [string]$UserDataDir = ""
    )
    
    try {
        # Look for Crashpad folder
        $crashpadFolder = ""
        $folderToCheck = ""
        $foundUserDataFolder = ""
        
        if (-not [string]::IsNullOrWhiteSpace($UserDataDir)) {
            # Validate UserDataDir to prevent path traversal
            if ($UserDataDir -match '\.\.') {
                Write-Host "Error: UserDataDir contains path traversal sequences (..). This is not allowed for security reasons." -ForegroundColor Red
                return @{ UserDataFolders = @(); CrashpadFolder = "" }
            }
            
            # Check if path is absolute (Windows path or UNC path)
            if (-not ([System.IO.Path]::IsPathRooted($UserDataDir))) {
                Write-Host "Error: UserDataDir must be an absolute path. Relative paths are not allowed." -ForegroundColor Red
                return @{ UserDataFolders = @(); CrashpadFolder = "" }
            }
            
            Write-Host "Using provided UserDataDir: $UserDataDir" -ForegroundColor Cyan
            $folderToCheck = $UserDataDir
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ExeName)) {
            Write-Host "Searching for msedgewebview2.exe processes with exe name: $ExeName" -ForegroundColor Green
            
            # Get all msedgewebview2.exe processes with their command lines
            $processes = Get-CimInstance Win32_Process -Filter "Name = 'msedgewebview2.exe'" -ErrorAction SilentlyContinue
            
            if (-not $processes) {
                Write-Host "No msedgewebview2.exe processes found" -ForegroundColor Yellow
                return @{ UserDataFolders = @(); CrashpadFolder = "" }
            }
            
            foreach ($process in $processes) {
                $commandLine = $process.CommandLine
                
                if ($commandLine) {
                    # Check if command line contains required parameters
                    if ($commandLine -match '--embedded-browser-webview=1' -and 
                        $commandLine -match "--webview-exe-name=$([regex]::Escape($ExeName))") {
                        
                        Write-Host "  Process ID $($process.ProcessId) matches criteria" -ForegroundColor Cyan
                        
                        # Extract --user-data-dir value
                        # Pattern handles: --user-data-dir="path" or --user-data-dir=path
                        if ($commandLine -match '--user-data-dir=(?:"([^"]+)"|([^\s]+))') {
                            $folderToCheck = if ($matches[1]) { $matches[1] } else { $matches[2] }
                            $foundUserDataFolder = $folderToCheck
                            Write-Host "Found user data folder: $folderToCheck" -ForegroundColor Green
                            break
                        }
                    }
                }
            }
            
            if (-not $folderToCheck) {
                Write-Host "No matching processes found with the specified criteria" -ForegroundColor Yellow
            }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($folderToCheck)) {
            $crashpadFolder = Join-Path $folderToCheck "Crashpad"
            
            if (Test-Path $crashpadFolder) {
                Write-Host "Checking Crashpad folder: $crashpadFolder" -ForegroundColor Cyan
                Write-Host "Found Crashpad folder: $crashpadFolder" -ForegroundColor Green
            }
            else {
                Write-Host "Crashpad folder not found: $crashpadFolder" -ForegroundColor Yellow
                $crashpadFolder = ""
            }
        }
        else {
            Write-Host "No user data folder available to check for Crashpad" -ForegroundColor Yellow
        }
        
        return @{ UserDataFolders = @($foundUserDataFolder); CrashpadFolder = $crashpadFolder }
    }
    catch {
        Write-Host "Error getting WebView2 user data folders: $($_.Exception.Message)" -ForegroundColor Red
        return @{ UserDataFolders = @(); CrashpadFolder = "" }
    }
}

# Collect installer logs.
$registryResult = Export-EdgeUpdateRegistry -OutputDirectory $OutputDirectory
Write-Host ""
$directoryResult = Export-EdgeWebViewDirectory -OutputDirectory $OutputDirectory
Write-Host ""

if (-not $registryResult -or -not $directoryResult) {
    exit 1
}

# Set global variables for zip creation
$script:RegistryFilePath = $registryResult
$script:DirectoryFilePath = $directoryResult
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:FinalZipPath = Join-Path $ZipPath "WebView2_Logs_$timestamp"

Write-Host "Registry file: $registryResult" -ForegroundColor Yellow
Write-Host "Directory file: $directoryResult" -ForegroundColor Yellow
Write-Host "Zip destination: $ZipPath" -ForegroundColor Yellow
Write-Host ""

$result = @{ UserDataFolders = @(); CrashpadFolder = "" }
if (-not [string]::IsNullOrWhiteSpace($ExeName) -or -not [string]::IsNullOrWhiteSpace($UserDataDir)) {
    $result = Get-WebView2UserDataFolder -ExeName $ExeName -UserDataDir $UserDataDir
    Write-Host "User data folders found: $($result.UserDataFolders.Count)" -ForegroundColor Yellow
    foreach ($folder in $result.UserDataFolders) {
        Write-Host "  $folder" -ForegroundColor Yellow
    }
    Write-Host ""
}
else {
    Write-Host "ExeName and UserDataDir not provided, skipping user data folder detection" -ForegroundColor Yellow
    Write-Host ""
}

# Set Crashpad folder path
$script:CrashpadFolderPath = $result.CrashpadFolder
Write-Host ""

# Start WPR tracing automatically
StartWPR -OutputDirectory $OutputDirectory -OutPath $OutPath -UseCPUProfile $UseCPUProfile