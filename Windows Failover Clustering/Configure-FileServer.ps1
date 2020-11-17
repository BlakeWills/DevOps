[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ComputerName,
    [Parameter(Mandatory)]
    [pscredential]$Credential,
    [Parameter(Mandatory)]
    [string]$StorageIpAddress,
    [Parameter(Mandatory)]
    [string]$StorageIpAddressPrefixLength,
    [Parameter(Mandatory)]
    [string]$SwitchName
)

$session = New-PSSession -ComputerName $ComputerName -Credential $Credential

$getStorageIpScriptBlock = {param([string]$ipAddress) return Get-NetIPAddress -IPAddress $ipAddress -ErrorAction SilentlyContinue }
if($null -eq (Invoke-Command -Session $session -ArgumentList $StorageIpAddress -ScriptBlock $getStorageIpScriptBlock)) {
    Write-Information "$($ComputerName): Adding network adapter for storage"
    Add-VMNetworkAdapter -VMName $ComputerName -SwitchName $SwitchName | Out-Null

    Write-Information "$($ComputerName): Configuring storage network adapter"
    $configureNicScript = {
        param($StorageIpAddress, $StorageIpAddressPrefixLength)
        $interfaceIndex = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.SuffixOrigin -eq "Link" }).InterfaceIndex
        New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $StorageIpAddress -PrefixLength $StorageIpAddressPrefixLength | Out-Null
    }
    Invoke-Command -Session $session -ScriptBlock $configureNicScript -ArgumentList $StorageIpAddress, $StorageIpAddressPrefixLength
}
else {
    Write-Information "$($ComputerName): Storage network adapter already configured."
}

$restartRequired = $false
foreach($feature in @("FS-FileServer", "FS-iSCSITarget-Server")) {
    $restartRequired = Invoke-Command -Session $session -ArgumentList $feature -ScriptBlock {
        param($feature)
        if(!(Get-WindowsFeature -Name $feature).Installed) {
            Write-Information "$($ENV:COMPUTERNAME): Installing $feature"
            Install-WindowsFeature -Name $feature -IncludeAllSubFeature -IncludeManagementTools -Restart:$false | Out-Null
            return $true
        }
        else {
            Write-Information "$($ENV:COMPUTERNAME): $feature already installed."
            return $false
        }
    }
}

if($restartRequired) {
    Write-Information "$($ComputerName): Restarting and waiting 60 seconds."
    Restart-VM -Name $ComputerName -Confirm:$false -Force
    Start-Sleep -Seconds 60
}

Write-Information "$($ComputerName): Configuring and starting msiscsi service."
Invoke-Command -Session $session -ScriptBlock {
    Set-Service -Name MSiSCSI -StartupType Automatic
    Start-Service -Name MSiSCSI
}