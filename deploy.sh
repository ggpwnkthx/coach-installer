#!/bin/bash

if [ -z "$(command -v wget)" ]
then
  apt-get -y install wget
fi

#wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/download_and_run -O download_and_run
chmod +x download_and_run

# Vendor specific system adminstration software
ask_system_admin()
{
  system_vendor=$(dmidecode | grep "Vendor: " | sed 's/^.*: //')
  case $system_vendor in
    "Dell Inc.") ./download_and_run "sofware/dell/omsa.sh" -y ;;
  esac
}
# Storage specific software and drivers
ask_drives()
{
  megacli=$(lspci | grep MegaRAID)
  if [ ! -z "$megacli" ]
  then
    ./download_and_run "hardware/storage/megacli.sh"
  fi
}
# Install networking
ask_networking()
{
  mellanox=$(lspci | grep Mellanox)
  if [ ! -z "$mellanox" ]
  then
    ./download_and_run "hardware/networking/infiniband.sh"
  fi
}
# System Preparation
sys_prep()
{
  echo "$(whoami) ALL = (root) NOPASSWD:ALL" | tee /etc/sudoers.d/$(whoami)
  chmod 0440 /etc/sudoers.d/$(whoami)
}
auto_install()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Installing System Administrative Software"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  ask_system_admin
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Installing Storage Drivers"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  ask_drives
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Installing Network Drivers"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  ask_networking
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Installing Prerequisets"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  sys_prep
}

auto_install
./download_and_run "bootstrap/ajenti.sh"
