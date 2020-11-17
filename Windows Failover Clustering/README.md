# Building Windows Stretch Clusters

## Topology

Site A:
CLUSTERVS01, CLUSTERVS02, FILEVS01

Site B:
SITEBCLUSTERVS01, SITEBCLUSTERVS02, SITEBFILEVS01

Site C:
Quorum

CLUSTERVSxx VMs are our Hyper-V servers, FILEVSxx provide block storage via iScsi for our Cluster Storage Volumes.