# COACH
## How To
### Prerequisites
If you're not familiar with Github, or git in general, you need to make sure you have a git client installed on your target machine.
```bash
sudo apt-get install git wget sshd
```
Once you have a git client installed use the following commands to pull all the necessary files over and start the installation.
```bash
git clone https://github.com/ggpwnkthx/coach.git
cd coach
chmod +x deploy.sh
sudo ./deploy.sh
```
### Web Interface
To log into the web interface, go to:
```
http://[ip-address]:8000
```
To log in, use a local username and password.

If you have not bootstrapped the device yet, the navigation bar will only show the "BOOTSTRAP" item under the "CLUSTER" section. 

To start the bootstrap process, you must eleveate your permission level. To do that, click on the blue circle at the top right of the page. Then select "Elevate". Then click on the "BOOTSTRAP" navigation menu item.
## Bootstap
### Fabric
To start the bootstrap process, you must first select a network interface that you want to use for your storage fabric. Due to how ceph (the storage clustering service) monitors work, these settings cannot be changed in the future. Once a static IP address has been defined for a monitor, if it ever changes the monitor will be degraded.

After selecting a network interface for the storage fabric, a dialog will appear. Enter in a fully qualified domain name for the device. Minimum requirements are {hostname}.{domainname}.{tld}

Examples:
```
storage01.example.local
```
```
seed001.mycluster.com
```
You are also required to define a Classless Inter-Domain Routing (CIDR). This should be an isolated subnet. Keeping it on it's own pysical network without any internet access is even better for security.

Examples:
```
192.168.0.0/24
```
```
172.16.0.0/16
```
```
172.16.10.0/24
```
For the fabric bootstrap process, the first usable IP address in the provided CIDR will be used as the selected network interface's IP address.
### Initial Storage Devices
The bottom of this page will list the devices available to be used as Object Storage Devices (OSDs). Click the + to add a device to the storrage cluster. If you have any SSDs, they can be used as Journals for slower HDDs to speed up data writes.

Only devices with no partitions on them can be used as OSDs. For safety, any devices with partitions are not included in the Available Devices lists because the process of crearting an OSD will wipe/zap the device and you will loose all data that was on that device.

If you accidentally added an OSD, you can press the correspnding - in the Active OSDs list to remove the OSD from the cluster. This will NOT restore any lost data.

When you are finished adding OSDs to the cluster, click "CREATE CLLUSTERED FILE SYSTEM" at the bottom right of the interface.
### Clustered File System
No interaction is need here.

It's going to take some time to get the services installed and set up. Just hang tight for about 5 min.

### Network Services
No interaction is need here, either.

This too will take some time to get Docker installed and DNSMasq bootstrapped and configured for the storage fabric. By default, DNSMasq will use the domain name you used in the beginning.

For example, if you used...
```
store01.us-ga.mycluster.info
```
...DNSMasq will set the local domain name to...
```
us-ga.mycluster.info
```
...so that any local DNS lookup will automatically have the domain name appended to it.

### Finished
That's it for the bootstrap process.

## About
I call it "COACH - Cluster Of Arbitrary, Cheap, Hardware", and this is what it does so far:

### Auto-Installer
* If run on a Dell system, install Dell OMSA
* If Mellanox devices detected, install MLNX OFED (4.0) [will update firmware from source code and flash latest PXE ROM if ConnectX2]
* Reconfigures opemsm service and sets the service up to start on boot
* If any infiniband detected, sets static IP addresses for each ib# device based on hostname (192.168.0.0/24).
* Adds preset hostname resolutions to /etc/hosts
* If MegaRAID device detected, install MegaCLI and grab the VERY useful "megaclisas-status" script
* Clear foreign status of all disks on all MegaRAID controllers
* Automatically create single disk spans in RAID0 for every unconfigured disk on all MegaRAID controllers
* Keep track of HDDs and SSDs in individual RAID0 spans [credit: https://github.com/omame/megaclisas-status]

### Bootstrap
* Runs the Auto-Installer
* Sets up a static IPs on seed nodes, and dynamic IPs on client nodes.
* Initializes a ceph cluster.
* Creates a cephFS instance.
* Sets up DHCP for the given CIDR on seed nodes.
* Sets up DNS for the DHCP clients on seed nodes.

### Networking
* Manage interface (mode, ip, netmask, gateway, state)
* Add, edit, and remove child-interfaces

### Ceph
* Install ceph-deploy
* Install ceph monitor role
* Set up OSDs on local disks
* Set up SSD Journals for OSDs if SSD's exist
* Set up multiple Journals on a single SSD is freespace allows
* Properly remove local OSDs from the cluster
* Add, remove, and update pools
* Add, remove, resize, map and mount, unmount and unmap RBDs
* Add, remove, and mount ceph filesystem (persistant)
* Benchmark the ceph cluster

### Docker
* Installs Docker.io to easily manage the COACH modules

### PXE Provisioning
* Uses a DNSMASQ container created in the Bootstrapping to point PXE clients to a web server.
* Uses a LAMP container to host the (i)PXE data.
* Downloads the official Ubuntu 16.04 Cloud Image generic-vzlinuz kernel.
* Downloads the official Ubuntu 16.04 Cloud Image generic-initrd, decompresses it, adds the current machine's modules to it, and recompiles it.
* Downloads the official Ubuntu 16.04 Cloud Image squashfs filesystem, unsquashes it, adds the ceph client to it as well as some custom services to make sure that the cluster's cephFS gets mounted properly.

## Roadmap
* Add menu system for the DHCP and DNS managment.
* Rewrite some of the older functions so that the script can have a proper API
* Add a web based GUI
* Integrate SquidViz for ceph into that web GUI https://github.com/TheSov/squidviz
* Add PXE booting and provisioning

## Known Issues
* Only tested on Ubuntu 16.04 (mini). Might work on Debian, but will not work on RedHat distros. It relies heavily on apt-get right now.
