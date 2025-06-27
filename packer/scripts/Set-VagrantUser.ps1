# Configure Vagrant user for proper SSH access
Write-Host "Configuring Vagrant user..."

# Ensure vagrant user exists and is in administrators group
$VagrantUser = "vagrant"
$VagrantPassword = "vagrant"

try {
    # Create user if it doesn't exist
    $User = Get-LocalUser -Name $VagrantUser -ErrorAction SilentlyContinue
    if (-not $User) {
        $SecurePassword = ConvertTo-SecureString $VagrantPassword -AsPlainText -Force
        New-LocalUser -Name $VagrantUser -Password $SecurePassword -FullName "Vagrant User" -Description "Vagrant SSH User"
        Write-Host "Created vagrant user"
    }
    
    # Add to administrators group
    Add-LocalGroupMember -Group "Administrators" -Member $VagrantUser -ErrorAction SilentlyContinue
    Write-Host "Added vagrant user to Administrators group"
    
    # Set password to never expire
    Set-LocalUser -Name $VagrantUser -PasswordNeverExpires $true
    Write-Host "Set vagrant user password to never expire"
    
} catch {
    Write-Warning "Error configuring vagrant user: $($_.Exception.Message)"
}

# Configure automatic logon
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $RegistryPath -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $RegistryPath -Name "DefaultUserName" -Value $VagrantUser
Set-ItemProperty -Path $RegistryPath -Name "DefaultPassword" -Value $VagrantPassword

Write-Host "Vagrant user configured successfully!"
