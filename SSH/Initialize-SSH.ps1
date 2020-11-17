[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ComputerName,
    [Parameter(Mandatory)]
    [pscredential]$Credential,
    [Parameter(Mandatory=$false)]
    [string]$Username="Administrator",
    [switch]$UseAdminAuthorizedKeys
)

if($UseAdminAuthorizedKeys) {
    $authKeysPath = "C:\ProgramData\ssh\administrators_authorized_keys"
}
else {
    $authKeysPath = "C:\Users\$($Username)\.ssh\authorized_keys"
}

Write-Information "authorized_keys path: $authKeysPath"

# We should be able to use -ComputerName instead of -VMName, but this results in an access denied error when installing OpenSSH.
$session = New-PSSession -VMName $ComputerName -Credential $Credential -ErrorAction Stop

$scriptBlock = {
    param([Parameter(Mandatory)][string]$authKeysPath)

    $ErrorActionPreference = "Stop"

    $openSshServer = "OpenSSH.Server~~~~0.0.1.0" 
    if((Get-WindowsCapability -Online -Name $openSshServer).State -ne "Installed") {
        Write-Information "Installing $openSshServer"
        Add-WindowsCapability -Online -Name $openSshServer | Out-Null
    }
    
    Write-Information "Configuring ssh-agent service"
    Set-Service -Name ssh-agent -StartupType Automatic
    Write-Information "Starting ssh-agent service"
    Start-Service ssh-agent

    Write-Information "Configuring sshd service"
    Set-Service -Name sshd -StartupType Automatic
    Write-Information "Starting sshd service"
    Start-Service sshd

    $sshDir = Split-Path -Path $authKeysPath -Parent
    if(!(Test-Path $sshDir)) {
        Write-Information "Creating $sshDir"
        New-Item -ItemType Directory -Path $sshDir | Out-Null
    }
}

Invoke-Command -ScriptBlock $scriptBlock -Session $session -ArgumentList $authKeysPath -ErrorAction Stop

Write-Information "Copying public key to server"
Copy-Item "$($ENV:USERPROFILE)\.ssh\id_rsa.pub" -Destination $authKeysPath -ToSession $session

$scriptBlock = {
    param([Parameter(Mandatory)][string]$authKeysPath, [Parameter(Mandatory)][string]$username)

    $ErrorActionPreference = "Stop"

    Write-Information "Disabling NTFS permission inheritance on authorized_keys file"
    $acl = Get-Acl -Path $authKeysPath
    $acl.SetOwner([System.Security.Principal.NTAccount] $username)
    $acl.SetAccessRuleProtection($true,$false) # arg1 protects from inheritence, arg2 clears existing inherited perms.

    Write-Information "Giving $username full access to authorized_keys file"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($username,'FullControl','Allow')
    $acl.AddAccessRule($rule)

    Write-Information "Giving SYSTEM full access to authorized_keys file"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule('SYSTEM','FullControl','Allow')
    $acl.AddAccessRule($rule)

    Set-Acl $authKeysPath $acl
}

Invoke-Command -ScriptBlock $scriptBlock -Session $session -ArgumentList $authKeysPath, $Username