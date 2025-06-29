# Hyper-V VM Imaging Workflow

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Vagrant](https://img.shields.io/badge/Vagrant-2.3%2B-blue.svg)](https://www.vagrantup.com/)
[![Packer](https://img.shields.io/badge/Packer-1.9%2B-blue.svg)](https://www.packer.io/)
[![Windows Server](https://img.shields.io/badge/Windows%20Server-2025-blue.svg)](https://www.microsoft.com/en-us/windows-server)

A streamlined and pretty cool workflow for creating Windows Server 2025 VMs. It creates a "golden image" that is referenced to create other VMs.

## 🚀 Quick Start

1. **Prerequisites Setup**

   ```powershell
   # Run as Administrator
   .\scripts\Initialize-HyperVEnvironment.ps1
   ```

2. **Build Golden Image**

   ```powershell
   .\scripts\Build-WeeklyGoldenImage.ps1
   ```

3. **Deploy Servers**

   ```powershell
   cd vagrant\barebones
   vagrant up
   ```

## ✍ Script Options

### Build-WeeklyGoldenImage.ps1 Parameters

| Parameter            | Description                                                   | Example                                 |
| -------------------- | ------------------------------------------------------------- | --------------------------------------- |
| `-BoxName`           | Name of the Vagrant box (default: windows-server-2025-golden) | `-BoxName "windows-server-2025-golden"` |
| `-IsoPath`           | Path to Windows Server 2025 ISO                               | `-IsoPath "D:\ISOs\WinServer_2025.iso"` |
| `-Force`             | Force rebuild even if image is recent                         | `-Force`                                |
| `-ScheduleWeekly`    | Create scheduled task for weekly builds                       | `-ScheduleWeekly`                       |
| `-CheckOnly`         | Just check if rebuild is needed                               | `-CheckOnly`                            |
| `-DaysBeforeRebuild` | Days before rebuild needed (default: 7)                       | `-DaysBeforeRebuild 14`                 |

### Usage Examples

```powershell
# Check if rebuild is needed
.\scripts\Build-WeeklyGoldenImage.ps1 -CheckOnly

# Force rebuild regardless of age
.\scripts\Build-WeeklyGoldenImage.ps1 -Force

# Build with custom settings
.\scripts\Build-WeeklyGoldenImage.ps1 -BoxName "windows-server-2025-golden" -DaysBeforeRebuild 14

# Remove and recreate scheduled task
.\scripts\Build-WeeklyGoldenImage.ps1 -ScheduleWeekly
```

## ⚙️ Workflow

This guide explains how to use the weekly golden image build process for Windows Server 2025.

## Overview

The golden image workflow allows you to:

1. Build a fresh Windows Server 2025 image weekly with latest updates
2. Package it as a Vagrant box named `windows-server-2025-golden`
3. Use this golden image as the base for all your Vagrant environments

## Getting Started (Complete Setup)

Follow these steps to set up the golden image workflow from scratch:

### Prerequisites

1. **Hyper-V** installed and enabled
2. **HashiCorp Packer** installed (`choco install packer` or download from HashiCorp)
3. **HashiCorp Vagrant** installed (`choco install vagrant` or download from HashiCorp)
4. **Windows Server ISO** downloaded and accessible
5. **Administrative Privileges** user running script needs to be a Hyper-V Administrator
6. **Windows SDK 10** installed

### Step 1: Clone and Setup

```powershell
# Clone the repository
git clone <repository-url> vagrant-hyperv-setup
cd vagrant-hyperv-setup

# Initialize Hyper-V environment (creates Vagrant Virtual Switch if needed)
.\scripts\Initialize-HyperVEnvironment.ps1
```

### Step 2: Prepare ISO

```powershell
# Option A: Place ISO in default location
# Copy your Windows Server 2025 ISO to: F:\Install\Microsoft\Windows Server\WinServer_2025.iso

# Option B: Note your ISO path for custom location
# Example: D:\ISOs\WinServer_2025.iso
```

### Step 3: Build Your First Golden Image

```powershell
# Build with default ISO location
.\scripts\Build-WeeklyGoldenImage.ps1

# OR build with custom ISO path
.\scripts\Build-WeeklyGoldenImage.ps1 -IsoPath "D:\ISOs\WinServer_2025.iso"

# This will take 30-60 minutes and will:
# 1. Run Packer to build the base Windows Server 2025 VM
# 2. Install essential packages and configure WinRM
# 3. Package the result as a Vagrant box named "windows-server-2025-golden"
# 4. Add the box to your local Vagrant installation
```

### Step 4: Deploy Your First VM

Choose from the available VM environments:

#### Available VM Types

| Environment           | Purpose                 | Features                                         | Use Case                         |
| --------------------- | ----------------------- | ------------------------------------------------ | -------------------------------- |
| **barebones**         | Minimal Windows Server  | Basic OS + Windows Updates                       | Testing, minimal deployments     |
| **fileserver**        | File & Storage Server   | File Services, DFS, FSRM, **Data Deduplication** | File sharing, storage management |
| **dev-box**           | Development Environment | Dev tools, VS Code, Git                          | Software development             |
| **domain-controller** | Active Directory        | AD DS, DNS, Group Policy                         | Domain services, authentication  |
| **iis-server**        | Web Server              | IIS, ASP.NET, management tools                   | Web hosting, applications        |

#### Deploy Commands

```powershell
# Deploy a basic Windows Server (minimal configuration)
cd vagrant\barebones
vagrant up --provider=hyperv

# Deploy a file server with deduplication on second drive
cd ..\fileserver
vagrant up --provider=hyperv

# Deploy a development box with tools
cd ..\dev-box
vagrant up --provider=hyperv

# Deploy a domain controller
cd ..\domain-controller
vagrant up --provider=hyperv

# Deploy an IIS web server
cd ..\iis-server
vagrant up --provider=hyperv
```

### Step 5: Connect to Your VM

```powershell
# Connect via RDP
vagrant rdp

# Or check VM status
vagrant status

# Default credentials:
# Username: vagrant
# Password: vagrant
```

### Step 6: Set Up Weekly Automation (Optional)

```powershell
# Create scheduled task for weekly golden image rebuilds
.\scripts\Build-WeeklyGoldenImage.ps1 -ScheduleWeekly
```

### Step 7: Validate Your Setup

```powershell
# Verify Packer is installed
packer version

# Verify Vagrant is installed
vagrant version

# Check if golden image was created
vagrant box list | findstr "windows-server-2025-golden"

# Verify Hyper-V virtual switch
Get-VMSwitch | Where-Object { $_.Name -like "*VLAN*" }

# Test VM deployment (optional)
.\scripts\Build-WeeklyGoldenImage.ps1 -CheckOnly
```

## How It Works

1. **Packer Build**: Uses `packer\windows-server-2025.pkr.hcl` to build a fresh Windows Server 2025 VM with:

   - Latest Windows updates
   - Essential packages
   - Vagrant user configured
   - WinRM enabled

2. **Box Creation**: Packages the Packer output as a Vagrant box using `scripts\New-VagrantBox.ps1`

3. **Vagrant Integration**: All Vagrantfiles use `config.vm.box = "windows-server-2025-golden"`

## Maintenance

### Weekly Process

The automated process will:

- Check if the current golden image is older than 7 days
- Build a new image with latest updates if needed
- Package and register it with Vagrant
- Replace the previous golden image

### Manual Maintenance

```powershell
# List current Vagrant boxes
vagrant box list

# Remove old boxes (if needed)
vagrant box remove windows-server-2025-golden --provider hyperv

# Check scheduled task status
Get-ScheduledTask -TaskName "Build-WeeklyGoldenImage"

# View task history
Get-ScheduledTask -TaskName "Build-WeeklyGoldenImage" | Get-ScheduledTaskInfo
```

### Updating Running VMs

When a new golden image is built, existing VMs continue using the old image. To update them:

```powershell
# Example: Update fileserver VM
cd vagrant\fileserver
vagrant destroy -f
vagrant up --provider=hyperv

# Or update all environments
$environments = @("barebones", "fileserver", "dev-box", "domain-controller", "iis-server")
foreach ($env in $environments) {
    cd vagrant\$env
    vagrant destroy -f
    vagrant up --provider=hyperv
    cd ..\..
}
```

## Troubleshooting

### Build Logs

Build logs are displayed in the console. For scheduled builds, check:

- Event Viewer > Windows Logs > Application
- Task Scheduler > Task Scheduler Library > "Build-WeeklyGoldenImage"

## Integration with Development Workflow

1. **Weekly**: Automated golden image build (Sunday 2 AM)
2. **Daily**: Use existing VMs for development
3. **As Needed**: Recreate VMs when fresh golden image is needed
4. **Testing**: Deploy clean VMs for testing using latest golden image

This workflow ensures all your VMs start from a consistent, up-to-date baseline while minimizing build time and storage requirements.
