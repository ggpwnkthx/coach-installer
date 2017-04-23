# COACH

Maybe I have a unique situation, but I wrote a script to help me deploy my new servers into my cluster.

I call it "COACH - Cluster Of Arbitrary, Cheap, Hardware", and this is what it does so far:

* If run on a Dell system, install Dell OMSA
* If Mellanox devices detected, install MLNX OFED (4.0) [will update firmware from source code and flash latest PXE ROM if ConnectX2]
* Reconfigures opemsm service and sets the service up to start on boot
* If any infiniband detected, sets static IP addresses for each ib# device based on hostname (192.168.0.0/24).
* Adds preset hostname resolutions to /etc/hosts
* If MegaRAID device detected, install MegaCLI and grab the VERY useful "megaclisas-status" script
* Clear foreign status of all disks on all MegaRAID controllers
* Automatically create single disk spans in RAID0 for every unconfigured disk on all MegaRAID controllers
* Keep track of HDDs and SSDs in individual RAID0 spans [credit: https://github.com/omame/megaclisas-status]
* Install ceph-deploy
* Install ceph monitor role
* Set up OSDs on local disks
* Set up SSD Journals for OSDs if SSD's exist
* Set up multiple Journals on a single SSD is freespace allows
* Properly remove local OSDs from the cluster
* Add, remove, and update pools
* Add, remove, resize, map and mount, unmount and unmap RBDs
* Benchmark the ceph cluster

There is also a feature to connect to remote machines. It will self replicate on the remote machine and run itself. Technically, it can use itself as it's own proxy!

Roadmap:

* Get away from static IPs. Add in a DHCP and DNS server
* Add menu system for DHCP and DNS managment.
* Rewrite some of the older functions so that the script can have a proper API
* Add a web based GUI
* Integrate SquidViz for ceph into that web GUI https://github.com/TheSov/squidviz
* Add PXE booting and provisioning

Current caveats:

* Only tested on Ubuntu 16.04 (mini). Might work on Debian, but will not work on RedHat distros. It relies heavily on apt-get right now.
