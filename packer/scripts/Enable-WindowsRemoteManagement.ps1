# Enable WinRM for Packer communication
Write-Host "Enabling WinRM for Packer..."

# Configure WinRM
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Configure firewall for WinRM
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

# Start WinRM service
net start winrm
Set-Service -Name winrm -StartupType Automatic

Write-Host "WinRM enabled successfully!"
