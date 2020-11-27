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

SxFILEVSxx should have additional disks for LUNs. Each file server will host a single LUN and LUN log (used for replication).

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

5: On each file server, bring the LUN storage VHDX online, then initialize and format within the guest OS.

## Failover Cluster Node Configuration

1: Install Hyper-V, Failover-Clustering and Storage-Replica

```powershell
Install-WindowsFeature Hyper-V, Failover-Clustering, Storage-Replica -IncludeAllSubFeature -IncludeManagementTools -Restart
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

4: Attach the iScsi storage:

```powershell
Set-Service msiscsi -StartupType Automatic
Start-Service msiscsi

New-IscsiTargetPortal -TargetPortalAddress [fileServerStorageIpAddress]
Get-IscsiTargetPortal | Update-IscsiTargetPortal

Connect-IscsiTarget -NodeAddress "[targetIqn]" -IsPersistent $true -InitiatorPortalAddress [storageIpAddress] -TargetPortalAddress [fileServerStorageIpAddress]
```

5: On one of the nodes at each site, bring the iScsi disk online, initalise it, then format it as an NTFS volume

```powershell
Set-Disk -Number [diskNumber] -IsOffline $false
Initialize-Disk -Number [diskNumber] -PartitionStyle GPT
Get-Disk -Number [diskNumber] | New-Volume -FileSystem NTFS -FriendlyName "[LUN01]/[LUN01LOG]" -DriveLetter [driveLetter]
```

Note: Drive letters are required to run the storage tests. 

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

## Cluster site awareness

We want to use one of our sites as a disaster recovery site, to do this we need failover cluster to be aware of which nodes are in what sites.

```powershell
# Create sites
New-ClusterFaultDomain -FaultDomainType Site -Name SiteA -Description SiteA -Location "UK-WEST"
New-ClusterFaultDomain -FaultDomainType Site -Name SiteB -Description SiteB -Location "UK-SOUTH"

# Assign nodes to site
Set-ClusterFaultDomain -Name SACLUSTERVS01 -Parent SiteA
Set-ClusterFaultDomain -Name SACLUSTERVS02 -Parent SiteA
Set-ClusterFaultDomain -Name SBCLUSTERVS01 -Parent SiteB
Set-ClusterFaultDomain -Name SBCLUSTERVS02 -Parent SiteB

# Set preferred site
(Get-Cluster).PreferredSite = "SiteA"
```

## Site A Cluster Storage

1: Add the LUN01 and LUN01LOG disk to cluster available storage

```powershell
Get-Disk -Number [lun01DiskNumber] | Add-ClusterDisk
Get-Disk -Number [lun01LogDiskNumber] | Add-ClusterDisk
```

2: Convert LUN01 cluster available storage to a cluster shared volume (CSV)

```powershell
# Add-ClusterSharedVolume uses the name of the cluster disk, so get it:
Get-ClusterResource | where OwnerGroup -eq "Available Storage"

Add-ClusterSharedVolume -Name "[lun01ClusterDiskName]"
```

3: Rename the cluster disks to SALUN01 and SALUN01LOG

```powershell
(Get-ClusterSharedVolume).Name = "SALUN01"
(Get-ClusterResource -Name "[saLun01ClusterDiskName]").Name = "SALUN01LOG"
```

## Site B Cluster Storage

1: Add the SBLUN01 and SBLUN01LOG disk to cluster available storage.

```powershell
Get-Disk -Number [sbLun01DiskNumber] | Add-ClusterDisk
Get-Disk -Number [sbLun01LogDiskNumber] | Add-ClusterDisk
```

Note: take note of the cluster disk name as this is used in the next step:

2: Rename the cluster disks to SBLUN01 and SBLUN01LOG:

```powershell
(Get-ClusterResource -Name "[sbLun01ClusterDiskName]").Name = "SBLUN01"
(Get-ClusterResource -Name "[sbLun01LogClusterDiskName]").Name = "SBLUN01"
```

## Testing the storage topology

Before we can configure replication we need to run some tests against the storage to validate our configuration.
In order to run the tests we need all of the storage online, however, all the storage we have added to the cluster (except SALUN01), is configured as available storage. Since available storage moves as a group, only a single sites storage can be online at any one time. To fix this, we must first create empty cluster roles for each site and then assign the storage. 

1: Create empty cluster roles and assign the storage:

```powershell
Add-ClusterGroup -Name SITEA
Add-ClusterGroup -Name SITEB

Move-ClusterResource -Name SALUN01LOG -Group SITEA
Move-ClusterResource -Name SBLUN01 -Group SITEB
Move-ClusterResource -Name SBLUN01LOG -Group SITEB
```

2: Ensure all of the storage is online and in the correct location

```powershell
# Use Get-ClusterGroup to ensure SITEA is owned by a SiteA node and SITEB is owned by a SiteB node:
Get-ClusterGroup

# If you need to move one of the groups to another node:
Move-ClusterGroup -Name SITE[A/B] -node S[A/B]CLUSTERVS01

# Use Get-ClusterResource to ensure the storage is all online:
Get-ClusterResource | where ResourceType -eq "Physical Disk"

# If you need to start any of the disks:
Start-ClusterResource -Name [resourceName]

# Finally, ensure the SiteA CSV in on the same node as SALUN01LOG
Get-ClusterSharedVolume

# If not, move it:
Move-ClusterSharedVolume -Name SALUN01 -Node SACLUSTERVS01
```

3: Run the storage replication tests

```powershell
Test-SRTopology `
    -SourceComputerName SACLUSTERVS01 `
    -SourceVolumeName C:\ClusterStorage\Volume1 `
    -SourceLogVolumeName W: `
    -DestinationComputerName SBCLUSTERVS01 `
    -DestinationVolumeName X: `
    -DestinationLogVolumeName Y: `
    -DurationInMinutes 1 `
    -IgnorePerfTests `
    -ResultPath C:\
```

Note I: This command cannot be run remotely. It must be run directly on the `SourceComputerName`.
Note II: We add the `-IgnorePerfTests` and `DurationInMinutes` flags as this is just a lab. In production these should not be left off and the tests will run over several hours.
Note III: The volumes must have drive letters assigned.
Note IV: Ensure you run powershell as a domain administrator rather than a local administrator.

Once the test is complete, check the report for errors or warnings.

4: Remove the storage roles to convert the storage back to Available Storage

```powershell
Remove-ClusterGroup -Name SITEA -RemoveResources
Remove-ClusterGroup -Name SITEB -RemoveResources
```
