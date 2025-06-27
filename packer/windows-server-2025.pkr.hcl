packer {
  required_plugins {
    hyperv = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/hyperv"
    }
  }
}

variable "VirtualMachineName" {
  type    = string
  default = "windows-server-2025"
}

variable "IsoPath" {
  type    = string
  default = "F:\\Install\\Microsoft\\Windows Server\\WinServer_2025.iso"
}

variable "OutputDirectory" {
  type    = string
  default = "output-hyperv-iso"
}

variable "WinRMUsername" {
  type    = string
  default = "vagrant"
}

variable "WinRMPassword" {
  type    = string
  default = "vagrant"
}

source "hyperv-iso" "windows-server-2025" {
  vm_name          = var.VirtualMachineName
  iso_url          = var.IsoPath
  iso_checksum     = "none"  # Skip checksum for local ISO
  output_directory = var.OutputDirectory
  
  # VM Configuration - golden image resources
  cpus         = 4
  memory       = 4096   # 4 GiB
  disk_size    = 64512  # 63 GB
  generation   = 2
  
  # Hyper-V specific settings
  switch_name               = "Default Switch"
  enable_secure_boot        = true
  enable_virtualization_extensions = false
  guest_additions_mode      = "disable"
  
  # CD files for unattended installation
  cd_files = [
    "autounattend.xml",
    "scripts/Enable-WindowsRemoteManagement.ps1",
    "scripts/Set-VagrantUser.ps1"
  ]
  
  # Boot and installation settings
  boot_wait = "5s"
  
  # Communication settings
  communicator   = "winrm"
  winrm_username = var.WinRMUsername
  winrm_password = var.WinRMPassword
  winrm_timeout  = "30m"
  winrm_port     = 5985
  winrm_host     = "127.0.0.1"
  
  # Shutdown command
  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout = "15m"
}

build {
  name = "windows-server-2025"
  sources = ["source.hyperv-iso.windows-server-2025"]
  
  # Wait for Windows to be ready
  provisioner "powershell" {
    inline = [
      "Write-Host 'Waiting for Windows to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }
  
  # Essential Windows Updates only
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing critical Windows Updates...'",
      "try {",
      "  Install-Module PSWindowsUpdate -Force -Scope AllUsers",
      "  Import-Module PSWindowsUpdate",
      "  Get-WindowsUpdate -Category 'Critical Updates' -AcceptAll -Install -AutoReboot:$false",
      "} catch {",
      "  Write-Warning 'Windows Updates failed, continuing...'",
      "}"
    ]
  }
  
  # Configure Vagrant user
  provisioner "powershell" {
    script = "scripts/Set-VagrantUser.ps1"
  }
  
  # Configure WinRM for Vagrant
  provisioner "powershell" {
    script = "scripts/Enable-WindowsRemoteManagement.ps1"
  }
  
  # Minimal cleanup
  provisioner "powershell" {
    inline = [
      "Write-Host 'Performing minimal cleanup...'",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Write-Host 'Minimal Windows Server 2025 golden image build complete!'"
    ]
  }
}
