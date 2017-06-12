# COACH
## How To
### First Use
#### Method 1:
This method will download all scripts at once, and will ignore any updates. This is best for production environments.
```bash
git clone https://github.com/ggpwnkthx/coach.git
cd coach
chmod +x deploy.sh
./deploy.sh
```
#### Method 2:
This method will automatically download the latest version of each script as it is called. This is best for developmental needs.
```bash
git clone https://github.com/ggpwnkthx/coach.git
cd coach
sed -i 's/^#wget/wget/g' deploy.sh
sed -i 's/^#get_latest/get_latest/g' download_and_run
chmod +x deploy.sh
./deploy.sh
```
##### Prerequisites
* git - Need for the initial download.
* wget - Needed to download 3rd party libraries.
* sshd - Needed to communicate with other nodes.
```bash
sudo apt-get install git wget sshd
```

### Consecutive uses:
```bash
./deploy.sh
```

## About
Maybe I have a unique situation, but I wrote a script to help me deploy my new servers into my cluster.

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
