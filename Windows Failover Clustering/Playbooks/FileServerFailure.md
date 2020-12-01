# Playbook: Recovering after a file server failure

## What does this playbook do?

This playbook walks through the steps required to reconnect the iScsi storage and bring storage replica and other cluster resources back online, after a file server failure.
This playbook caters for file server failures at a single site and across both sites in a stretch cluster.

## Symptoms

- iScsi storage is not accessible from the cluster nodes at either one or both sites.
- Attempting to reconnect to the iScsi target fails with the error: `The target name is not found or is marked as hidden from login`

If both file servers have failed:

- Cluster resources (VMs, etc) are in a failed state.
- Storage replica is in a failed state.

## Resolution

1: On each of the failed file server nodes, confirm the iSci target service is running and start the service if not

```powershell
# Status should be 'Running'
Get-Service WinTarget

# If the service is not running
Start-Service WinTarget
```

2: If the service fails to start, consult the Windows event logs to identify the problem.
The iscsi Target Service logs can be found under "Application and Services Logs/Microsoft/Windows/iScsiTarget-Service"

Once you have found the error, take the necessary steps to correct the error and start the service before continuing.
Note: In our case, the error was:

> The Microsoft iSCSI Target Server service could not bind to network address 10.0.1.30, port 3260. The operation failed with error code 10049. Ensure that no other application is using this port.

Ensuring no other processes were bound to the same port and starting the WinTarget service fixed the issue. If you have a similar issue, the following command will list the PID of any process listening on the required port:

```powershell
netstat -aon | select-string -Pattern 3260
```

3: Ensure the initiator service is running on the client servers

```powershell
# Status should be 'Running'
Get-Service MSiSCSI

# If the service is not running
Start-Service MSiSCSI
```

4: Check the iScsi storage is back online

```powershell
# IsConnected should return 'True'
Get-IscsiTarget
```

Note: If `Get-IscsiTarget` no longer returns a value, restart the initiator service and check again.

```powershell
Restart-Service MSiSCSI
Get-IscsiTarget
```

As well as being reconnected to the iScsi target, you should also check all of the disks are visible:

```powershell
# This should return all of the iScsi disks
Get-Disk
```

5: Bring the Cluster Shared Volumes (CSV) back online

```powershell
# Get the name of the CSVs
Get-ClusterSharedVolume

# Start the CSVs
Start-ClusterResource [csvName]
Start-ClusterResource [csvLogName]
```

6: Bring Storage Replica back online

This involves checking the source and destination are configured correctly. The source replication group needs to be set to whichever site owns the CSVs.

```powershell
# Get the owner of the CSVs
Get-ClusterSharedVolume

# Get the current partnership, SourceRGName should be the name of the RG at the site that owns the CSVs.
Get-SRPartnership

# Fix the partnership, if required
Set-SRPartnership -NewSourceComputerName [csvOwnerNode] -SourceRGName [soureRgName] -DestinationComputerName [destNode] -DestinationRGName [destRgName]

# csvOwnerNode is the name of the node that currently owns the CSV.
# sourceRgName is the name of the replication group at whichever site csvOwnerNode is in.
# destNode is any other cluster node at the other site.
# destRgName is the name of the replication group at the other site.

# Check the storage replica roles are back online
Get-ClusterResource
```

7: Bring other cluster resources back online

```powershell
# Identify any roles that are still offline
Get-ClusterGroup | where State -eq "Offline"

# Bring them online
Start-ClusterGroup [name]
```

## Background

After finishing the initial cluster build, I attempted to perform a test failover by turning off (not shutting down) the site A cluster nodes and the site A file server.
The failover was successful; all cluster roles migrated over to site B after the default resilliency period. Whilst the site A nodes were down, I decided to increase the number of CPUs on each of the cluster nodes and then power the nodes back on. I did this one node at a time, but mistakenly started the cluster nodes before the file server, meaning the storage was not available. These are the steps I took to bring the cluster back online.
