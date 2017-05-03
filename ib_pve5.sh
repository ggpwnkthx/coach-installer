cd /tmp
wget http://download.proxmox.com/debian/dists/stretch/pvetest/binary-amd64/pve-headers-4.10.1-2-pve_4.10.1-2_amd64.deb
dpkg -i pve-headers-4.10.1-2-pve_4.10.1-2_amd64.deb
apt-get update
apt-get -y install python-libxml2 make dkms
wget http://content.mellanox.com/ofed/MLNX_OFED-4.0-2.0.2.0/MLNX_OFED_LINUX-4.0-2.0.2.0-ubuntu17.04-x86_64.iso
mkdir iso
mount -o loop MLNX_OFED_LINUX-*.iso iso
cd iso
cd DEBS
dpkg -i ofed-scripts* mlnx-ofed-kernel-utils* mlnx-ofed-kernel-dkms* iser-dkms* srp-dkms* libibverbs1* ibverbs-utils* libibverbs-dev* libibverbs1-dbg* libmlx4-1* libmlx4-dev* libmlx4-1-dbg* libmlx5-1* libmlx5-dev* libmlx5-1-dbg* libibumad* libibumad-static* libibumad-devel* ibacm* ibacm-dev* librdmacm1* librdmacm-utils* librdmacm-dev* libibmad*  ibdump* libibmad-static* libibmad-devel* libopensm* opensm* opensm-doc* libopensm-devel* infiniband-diags* infiniband-diags-compat* mft* kernel-mft-dkms* srptools* mlnx-ethtool*\
service openibd start
