# Weekly Golden Image Build Script for Windows Server 2025
# Run this script weekly to build a fresh golden image with latest updates
# 
# Usage:
#   .\Build-WeeklyGoldenImage.ps1                     # Build with default name
#   .\Build-WeeklyGoldenImage.ps1 -Force              # Force rebuild even if recent
#   .\Build-WeeklyGoldenImage.ps1 -ScheduleWeekly     # Set up weekly scheduled task
#   .\Build-WeeklyGoldenImage.ps1 -CheckOnly          # Just check if rebuild needed

param(
    [string]$BoxName = "windows-server-2025-golden",
    [string]$IsoPath = "F:\Install\Microsoft\Windows Server\WinServer_2025.iso",
    [switch]$Force,
    [switch]$ScheduleWeekly,
    [switch]$CheckOnly,
    [int]$DaysBeforeRebuild = 7
)

$ErrorActionPreference = "Stop"

# Function to check if ISO exists
function Test-IsoAvailable {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        Write-Warning "ISO file not found at: $Path"
        Write-Host "Please ensure Windows Server 2025 ISO is available or specify correct path with -IsoPath parameter" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Function to check if rebuild is needed
function Test-RebuildNeeded {
    param([string]$BoxName, [int]$DaysThreshold)
    
    try {
        $BoxInfo = vagrant box list | Where-Object { $_ -like "*$BoxName*" }
        if (!$BoxInfo) {
            Write-Host "Box '$BoxName' not found - rebuild needed" -ForegroundColor Yellow
            return $true
        }
        
        # Check box creation date (this is approximate since Vagrant doesn't store creation date)
        # We'll check the last modified date of the box file instead
        $BoxPath = "$env:USERPROFILE\.vagrant.d\boxes"
        $BoxDirs = Get-ChildItem $BoxPath -Directory | Where-Object { $_.Name -like "*$BoxName*" }
        
        if ($BoxDirs) {
            $LatestBox = $BoxDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $DaysSinceUpdate = (Get-Date) - $LatestBox.LastWriteTime
            
            if ($DaysSinceUpdate.Days -ge $DaysThreshold) {
                Write-Host "Box is $($DaysSinceUpdate.Days) days old - rebuild needed" -ForegroundColor Yellow
                return $true
            }
            else {
                Write-Host "Box is $($DaysSinceUpdate.Days) days old - still fresh" -ForegroundColor Green
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Warning "Could not determine box age: $($_.Exception.Message)"
        return $true
    }
}

# Function to create scheduled task
function New-WeeklyScheduledTask {
    param([string]$ScriptPath)
    
    $TaskName = "Build-WeeklyGoldenImage"
    $TaskDescription = "Weekly Windows Server 2025 Golden Image Build"
    
    # Remove existing task if it exists
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch { }
    
    # Create new task
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2:00AM
    $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -RestartCount 3
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal
    
    Write-Host "Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
    Write-Host "Will run every Sunday at 2:00 AM" -ForegroundColor Cyan
    Write-Host "You can modify it using Task Scheduler or:" -ForegroundColor Yellow
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Set-ScheduledTask" -ForegroundColor White
}

Write-Host "=== Weekly Golden Image Build Process ===" -ForegroundColor Green
Write-Host "Building fresh Windows Server 2025 golden image..." -ForegroundColor Yellow
Write-Host "Box Name: $BoxName" -ForegroundColor Cyan
Write-Host "ISO Path: $IsoPath" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan

# Handle scheduling request
if ($ScheduleWeekly) {
    Write-Host "`nSetting up weekly scheduled task..." -ForegroundColor Yellow
    New-WeeklyScheduledTask -ScriptPath $PSCommandPath
    exit 0
}

# Check if rebuild is needed
if (!$Force -and !$CheckOnly) {
    if (!(Test-RebuildNeeded -BoxName $BoxName -DaysThreshold $DaysBeforeRebuild)) {
        Write-Host "`nGolden image is still fresh. Use -Force to rebuild anyway." -ForegroundColor Green
        exit 0
    }
}

# Handle check-only request
if ($CheckOnly) {
    $NeedsRebuild = Test-RebuildNeeded -BoxName $BoxName -DaysThreshold $DaysBeforeRebuild
    Write-Host "`nRebuild needed: $NeedsRebuild" -ForegroundColor $(if ($NeedsRebuild) { "Yellow" } else { "Green" })
    exit $(if ($NeedsRebuild) { 1 } else { 0 })
}

# Verify ISO exists
if (!(Test-IsoAvailable -Path $IsoPath)) {
    exit 1
}

# Navigate to packer directory
$PackerPath = Join-Path $PSScriptRoot "..\packer"
$OriginalLocation = Get-Location

try {
    Set-Location $PackerPath
    
    # Clean up previous build artifacts
    Write-Host "`nCleaning up previous build artifacts..." -ForegroundColor Yellow
    if (Test-Path "output-hyperv-iso") {
        Remove-Item "output-hyperv-iso" -Recurse -Force
        Write-Host "Removed previous Packer output" -ForegroundColor Green
    }
    
    # Build the golden image
    Write-Host "`nBuilding Windows Server 2025 golden image with Packer..." -ForegroundColor Yellow
    Write-Host "This process typically takes 30-60 minutes..." -ForegroundColor Yellow
    $PackerStartTime = Get-Date
    
    # Build with custom ISO path if specified
    if ($IsoPath -ne "F:\Install\Microsoft\Windows Server\WinServer_2025.iso") {
        Write-Host "Using custom ISO path: $IsoPath" -ForegroundColor Cyan
        packer build -var "iso_path=$IsoPath" windows-server-2025.pkr.hcl
    }
    else {
        packer build windows-server-2025.pkr.hcl
    }
    
    if ($LASTEXITCODE -eq 0) {
        $PackerDuration = (Get-Date) - $PackerStartTime
        Write-Host "Packer build completed successfully!" -ForegroundColor Green
        Write-Host "Build time: $($PackerDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    }
    else {
        throw "Packer build failed with exit code $LASTEXITCODE"
    }
    
    # Package as Vagrant box
    Write-Host "`nPackaging as Vagrant box..." -ForegroundColor Yellow
    Set-Location (Join-Path $PSScriptRoot "..")
    
    $BoxArgs = @{
        BoxName               = $BoxName
        PackerOutputDirectory = "packer\output-hyperv-iso"
        VagrantBoxDirectory   = "boxes"
    }
    
    # Remove existing box if Force is specified
    if ($Force) {
        Write-Host "Force mode: Removing existing Vagrant box if present..." -ForegroundColor Yellow
        try {
            vagrant box remove $BoxName --provider hyperv --force 2>$null
            Write-Host "Removed existing box: $BoxName" -ForegroundColor Green
        }
        catch {
            Write-Host "No existing box to remove" -ForegroundColor Gray
        }
    }
    
    # Create the new box
    & "scripts\New-VagrantBox.ps1" @BoxArgs
    
    # Final summary
    $TotalDuration = (Get-Date) - $PackerStartTime
    Write-Host "`n=== Golden Image Build Complete ===" -ForegroundColor Green
    Write-Host "Total time: $($TotalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host "Box name: $BoxName" -ForegroundColor Cyan
    Write-Host "Built on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "`nYou can now deploy VMs using:" -ForegroundColor Yellow
    Write-Host "  cd vagrant\barebones && vagrant up --provider=hyperv" -ForegroundColor White
    Write-Host "  cd vagrant\fileserver && vagrant up --provider=hyperv" -ForegroundColor White
    Write-Host "  cd vagrant\dev-box && vagrant up --provider=hyperv" -ForegroundColor White
    Write-Host "  cd vagrant\domain-controller && vagrant up --provider=hyperv" -ForegroundColor White
    Write-Host "  cd vagrant\iis-server && vagrant up --provider=hyperv" -ForegroundColor White
    
    Write-Host "`nNext weekly build will be needed after: $(((Get-Date).AddDays($DaysBeforeRebuild)).ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
    
    # Check if any VMs are currently running that use this box
    Write-Host "`nChecking for running VMs that use this box..." -ForegroundColor Yellow
    $VagrantEnvs = @("barebones", "fileserver", "dev-box", "domain-controller", "iis-server")
    $RunningVMs = @()
    
    foreach ($Env in $VagrantEnvs) {
        $EnvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "vagrant\$Env"
        if (Test-Path $EnvPath) {
            try {
                Push-Location $EnvPath
                $Status = vagrant status 2>$null
                if ($Status -and ($Status -like "*running*")) {
                    $RunningVMs += $Env
                }
            }
            catch { }
            finally { Pop-Location }
        }
    }
    
    if ($RunningVMs.Count -gt 0) {
        Write-Host "`nWARNING: The following VMs are running with the old golden image:" -ForegroundColor Yellow
        $RunningVMs | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        Write-Host "Consider recreating them to use the new golden image:" -ForegroundColor Yellow
        $RunningVMs | ForEach-Object { 
            Write-Host "  cd vagrant\$_ && vagrant destroy -f && vagrant up --provider=hyperv" -ForegroundColor White
        }
    }
    else {
        Write-Host "No running VMs detected - all future VMs will use the new golden image" -ForegroundColor Green
    }
    
}
catch {
    Write-Error "Weekly golden image build failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Set-Location $OriginalLocation
}
