[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [pscredential]$LocalCredential,
    [Parameter(Mandatory)]
    [pscredential]$DomainCredential
)

$InformationPreference = "Continue"

$scriptBlock = {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ipAddress,
        [Parameter(Mandatory)]
        [byte]$ipPrefix,
        [Parameter(Mandatory)]
        [string]$defaultGateway,
        [Parameter(Mandatory)]
        [string]$dnsServers,
        [Parameter(Mandatory)]
        [string]$machineName,
        [Parameter(Mandatory)]
        [string]$ouPath,
        [Parameter(Mandatory)]
        [pscredential]$DomainCredential,
        [Parameter(Mandatory)]
        [string]$domain
    )

    $ErrorActionPreference = "Stop"

    if($machineName.Length -gt 15) {
        throw "Machine Name cannot be greater than 15 characters. ($machineName)"
    }

    Write-Information "Getting Net Adapter Name"
    $interfaceAlias = (Get-NetAdapter | Where-Object { $_.Name -like "Ethernet*" }).Name
    Write-Information "Net Adapter Name: $interfaceAlias"
    
    Write-Information 'Disabling IPV6'
    Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction Stop

    Write-Information 'Removing existing IP'
    Get-NetIPAddress -InterfaceAlias $interfaceAlias | Remove-NetIPAddress -Confirm:$false -ErrorAction Stop

    Write-Information 'Removing default net route (gateway)'
    Remove-NetRoute -InterfaceAlias $interfaceAlias -Confirm:$false -ErrorAction Stop

    Write-Information 'Setting IP address and default gateway'
    New-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $ipAddress -AddressFamily IPv4 -PrefixLength $ipPrefix -DefaultGateway $defaultGateway -Confirm:$false -ErrorAction Stop

    Write-Information 'Setting DNS Servers'
    Set-DnsClientServerAddress -InterfaceAlias $interfaceAlias -ServerAddresses $dnsServers -ErrorAction Stop

    Write-Information 'Disabling Firewall'
    & 'netsh' advfirewall set allprofiles state off

    Write-Information 'Setting Power Mode: High Performance'
    powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

    Write-Information 'Renaming Computer'
    Rename-Computer -NewName $machineName -Confirm:$false -ErrorAction Stop

    # Add-Computer doesn't seem to work straight away.
    Start-Sleep -Seconds 10

    Write-Information "Adding computer to $domain and restarting. ($ouPath)"
    Add-Computer -DomainName $domain -Credential $DomainCredential -Options JoinWithNewName,AccountCreate -OUPath $ouPath -Restart -Confirm:$false -ErrorAction Stop
}

$ipPrefix = 24
$defaultGateway = "192.168.3.2"
$ouPath = "OU=Servers,DC=lab1,DC=local"
$domain = "lab1.local"
$dnsServers = @("192.168.3.10", "8.8.8.8")

$vms = @(
    'SBCLUSTERVS01|192.168.3.161',
    'SBCLUSTERVS02|192.168.3.162',
    'SBFILEVS01|192.168.3.163'
)

foreach($vm in $vms) {
    $parts = $vm.Split('|');
    $machineName = $parts[0];
    $ipAddress = $parts[1];

    Invoke-Command -VMName $machineName -Credential $LocalCredential -ScriptBlock $scriptBlock -ErrorAction Stop -ArgumentList `
        $ipAddress, `
        $ipPrefix, `
        $defaultGateway, `
        $dnsServers, `
        $machineName, `
        $ouPath, `
        $DomainCredential, `
        $domain
}