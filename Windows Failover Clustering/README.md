# Building Windows Stretch Clusters

## Topology

Site A:
SACLUSTERVS01, SACLUSTERVS02, SAFILEVS01

Site B:
SBCLUSTERVS01, SBCLUSTERVS02, SBFILEVS01

Site C:
Quorum (File share on our DC)

SxCLUSTERVSxx are our Hyper-V servers, SxFILEVSxx provide block storage via iScsi for our Cluster Storage Volumes.
SxCLUSTERVSxx should have multiple physical (or virtual) NICs.

SxFILEVSxx should have a multiple disks for LUNs.

## Virtual Machine Configuration

These steps are required if you are following this guide as part of a virtual lab and your cluster nodes are virtual manchines.

1: Create the extra vNICs

```powershell
Get-VM -Name S[A/B]* | Add-VMNetworkAdapter -SwitchName "192.168.3.0-NATSwitch" -DeviceNaming -Name "vNIC01" 
Get-VM -Name S[A/B]* | Add-VMNetworkAdapter -SwitchName "192.168.3.0-NATSwitch" -DeviceNaming -Name "vNIC02"

# Only target S[A/B]CLUSTER* VMs from now on as the file server only needs two NICs.
Get-VM -Name S[A/B]CLUSTER* | Add-VMNetworkAdapter -SwitchName "192.168.3.0-NATSwitch" -DeviceNaming -Name "vNIC03"
Get-VM -Name S[A/B]CLUSTER* | Add-VMNetworkAdapter -SwitchName "192.168.3.0-NATSwitch" -DeviceNaming -Name "vNIC04"

# Enable teaming, device name and MAC address spoofing (required for nested virtualisation)
Get-VMNetworkAdapter -VMName S[A/B]CLUSTER* | Set-VMNetworkAdapter -AllowTeaming On -MacAddressSpoofing On -DeviceNaming On
```

2: Enable nested virtualisation (VM needs to be shutdown)

```powershell
Set-VMProcessor -VMName S[A/B]CLUSTER* -ExposeVirtualizationExtensions $true
```

3: Create and attach an extra VHDX file to the file server VMs for iScsi storage.

4: Initalise the VMs (configure management nic, set computer name, join to domain, etc) via the `Initialize-Server.ps1` script.

5: Bring the LUN storage VHDX online, then initialize and format within the guest OS.

## Failover Cluster Node Configuration

1: Install Hyper-V and Failover-Clustering

```powershell
Install-WindowsFeature Hyper-V, Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools -Restart
```

2: Create Embedded Team

```powershell
New-VMSwitch -Name "Management" -AllowManagementOS $true -EnableEmbeddedTeaming $true -NetAdapterName (Get-NetAdapter | Select-Object -ExpandProperty Name | Sort-Object)
```

**Note:** `(Get-NetAdapter | Select-Object -ExpandProperty Name | Sort-Object)` Adds all adapters to the team. The order is important as the new virtual adapter takes the ip config from the first adapter in the list.

3: Create and configure Storage and Cluster virtual adapters

```powershell
Add-VMNetworkAdapter -Name Storage -ManagementOS -SwitchName Management
New-NetIPAddress -IPAddress [ip] -InterfaceIndex [index] -PrefixLength [prefixLength]

Add-VMNetworkAdapter -Name Cluster -ManagementOS -SwitchName Management
New-NetIPAddress -IPAddress [ip] -InterfaceIndex [index] -PrefixLength [prefixLength]
```

You should now be able to ping all other nodes in the cluster on their management, cluster and storage ip addresses.

Troubleshooting Tips:

- Ensure all host network adapters have teaming enabled. Note: These are the hosts physical (or virtual) adapters, not the adapters created in this step.
- Ensure all host network adapters are connected to the same switch.
- Ensure you haven't duplicated any IPs.

Finally, I also like to disable ipv6 across all nodes, just to keep things simple (optional):

```powershell
Get-NetAdapter | Set-NetAdapterBinding -ComponentID ms_tcpip6 -Enabled $false
```

4: Connect to iScsi target (after file server configuration)

```powershell
Set-Service msiscsi -StartupType Automatic
Start-Service msiscsi

New-IscsiTargetPortal -TargetPortalAddress 10.0.1.101
Get-IscsiTargetPortal | Update-IscsiTargetPortal

Connect-IscsiTarget -NodeAddress "[targetIqn]" -IsPersistent $true -InitiatorPortalAddress [storageIpAddress] -TargetPortalAddress [fileServerStorageIpAddress]
```

## File Server Configuration

1: Install File-Server and iScsi features

```powershell
Install-WindowsFeature FS-FileServer,FS-iSCSITarget-Server -IncludeAllSubfeature -IncludeManagementTools -Restart
```

2: Expose iScsi portal on storage ip address

```powershell
Set-IscsiTargetServerSetting -IP [managementIp] -Enable $false
Set-IscsiTargetServerSetting -IP [storageIp] -Enable $true

New-iSCSIServerTarget -TargetName "[targetName]" -InitiatorIds @("IPAddress:[clustervsxxStorageIp]", ...)

# Get the TargetIqn. This is needed to connect to the target from the initiators.
Get-IscsiServerTarget | select TargetIqn
```

3: Create iScsi virtual disks and target mapping (LUNs):

```powershell
New-IscsiVirtualDisk -Path [vhdxPath] -Description "[description]" -Size [size]GB
Add-IscsiVirtualDiskTargetMapping -TargetName "[targetName]" -Path [vhdxPath]
```

## Creating the cluster

1: Validate the cluster node configuration (run from any single cluster node)

```powershell
Test-Cluster -Node SACLUSTERVS01,SACLUSTERVS02,SBCLUSTERVS01,SBCLUSTERVS02
```

Note: The command will output warnings / errors for any test failures. See the full report for details.
If there aren't any warnings or errors, all tests passed.

2: Create the cluster

```powershell
New-Cluster -Name [clusterName] -Node SACLUSTERVS01,SACLUSTERVS02,SBCLUSTERVS01,SBCLUSTERVS02 -StaticAddress [staticClusterIp]
```

Note: The cluster needs it's own IP, which is provided by the `staticClusterIp` parameter.

## Configure cluster quorum

Our stretch cluster has two nodes at each site, a network partition between the sites would result in a split brain where both sites think they can form a cluster.
To prevent this we can add a witness (providing a third quorum vote), which either site must have visibility of in order to form a quorum. For this lab, we will use a file share witness on our domain controller.

1: Create the SMB file share:

```powershell
New-SmbShare -Name "CLUSTER01QUORUM" -FullAccess "lab1\SACLUSTERVS01$","lab1\SACLUSTERVS02$","lab1\SBCLUSTERVS01$","lab1\SBCLUSTERVS02$" -Path [path]
```

2: Configure the cluster to use node and file share witness:

```powershell
Set-ClusterQuorum -NodeAndFileShareMajority [fileShare]
```
