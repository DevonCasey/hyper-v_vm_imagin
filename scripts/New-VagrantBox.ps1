# Build and package a Vagrant box from Packer output
# Run this after successfully building with Packer

param(
    [Parameter(Mandatory = $true)]
    [string]$BoxName,
    
    [string]$PackerOutputDirectory = "..\packer\output-hyperv-iso",
    [string]$VagrantBoxDirectory = "..\boxes"
)

# Use BoxName as VM name (clean it for file naming)
$VirtualMachineName = $BoxName -replace '[<>:"/\\|?*]', '_'

Write-Host "Building Vagrant box: $BoxName" -ForegroundColor Green
Write-Host "Using '$VirtualMachineName' as VM name" -ForegroundColor Yellow

# Check if Packer output exists
$VhdxPath = Join-Path $PackerOutputDirectory "Virtual Hard Disks\*.vhdx"
$VhdxFile = Get-ChildItem $VhdxPath -ErrorAction SilentlyContinue | Select-Object -First 1

if (!$VhdxFile) {
    Write-Error "No VHDX file found in $PackerOutputDirectory. Please run Packer build first."
    exit 1
}

Write-Host "Found VHDX: $($VhdxFile.FullName)" -ForegroundColor Yellow

# Create boxes directory
if (!(Test-Path $VagrantBoxDirectory)) {
    New-Item -ItemType Directory -Path $VagrantBoxDirectory -Force
}

# Create temporary directory for box packaging
$TemporaryDirectory = Join-Path $env:TEMP "vagrant-box-$BoxName"
if (Test-Path $TemporaryDirectory) {
    Remove-Item $TemporaryDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $TemporaryDirectory -Force

try {
    # Copy VHDX to temp directory with custom naming
    $BoxVhdx = Join-Path $TemporaryDirectory "${VirtualMachineName}_os.vhdx"
    Copy-Item $VhdxFile.FullName $BoxVhdx
    Write-Host "Copied VHDX to temporary location as: ${VirtualMachineName}_os.vhdx" -ForegroundColor Green
    
    # Create Vagrantfile for Windows box
    $BoxVagrantfile = @"
Vagrant.configure("2") do |config|
  config.vm.guest = :windows
  config.vm.communicator = "winrm"
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"
  config.winrm.transport = :plaintext
  config.winrm.basic_auth_only = true
  
  config.vm.provider "hyperv" do |hv|
    hv.enable_virtualization_extensions = false
    hv.linked_clone = false  # Full copy instead of linked clone
    hv.enable_secure_boot = false
  end
end
"@
    
    Set-Content -Path (Join-Path $TemporaryDirectory "Vagrantfile") -Value $BoxVagrantfile
    Write-Host "Created box Vagrantfile" -ForegroundColor Green
    
    # Create metadata.json
    $Metadata = @{
        provider  = "hyperv"
        format    = "vhdx"
        vm_name   = $VirtualMachineName
        vhdx_file = "${VirtualMachineName}_os.vhdx"
    } | ConvertTo-Json
    
    Set-Content -Path (Join-Path $TemporaryDirectory "metadata.json") -Value $Metadata
    Write-Host "Created metadata.json" -ForegroundColor Green
    
    # Package the box
    $BoxFile = Join-Path $VagrantBoxDirectory "$BoxName.box"
    Set-Location $TemporaryDirectory
    
    # Use tar to create the box file (assuming tar is available on Windows 10+)
    if (Get-Command tar -ErrorAction SilentlyContinue) {
        tar -czf $BoxFile *
        Write-Host "Box packaged successfully: $BoxFile" -ForegroundColor Green
    }
    else {
        # Fallback: use PowerShell compression
        Compress-Archive -Path "$TemporaryDirectory\*" -DestinationPath "$BoxFile.zip"
        Rename-Item "$BoxFile.zip" $BoxFile
        Write-Host "Box packaged successfully (using ZIP): $BoxFile" -ForegroundColor Green
    }
    
    # Add box to Vagrant
    Write-Host "Adding box to Vagrant..." -ForegroundColor Yellow
    vagrant box add $BoxName $BoxFile --force
    
    Write-Host "`nBox '$BoxName' has been successfully created and added to Vagrant!" -ForegroundColor Green
    Write-Host "You can now use it in Vagrantfiles with: config.vm.box = '$BoxName'" -ForegroundColor Cyan
    Write-Host "VHDX file in box: ${VirtualMachineName}_os.vhdx" -ForegroundColor Cyan
    
}
finally {
    # Clean up temporary directory
    Set-Location $PSScriptRoot
    if (Test-Path $TemporaryDirectory) {
        Remove-Item $TemporaryDirectory -Recurse -Force
    }
}
