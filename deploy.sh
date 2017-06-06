#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/download_and_run -O download_and_run
chmod +x download_and_run

if [ -z "$(command -v wget)" ]
then
  sudo apt-get -y install wget
fi

# Vendor specific system adminstration software
ask_system_admin()
{
  system_vendor=$(sudo dmidecode | grep "Vendor: " | sed 's/^.*: //')
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
  echo "$(whoami) ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$(whoami)
  sudo chmod 0440 /etc/sudoers.d/$(whoami)
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
menu_auto_installer()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Auto Installers || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[V]	System Vendor Specific Software"
  echo "[D]	Storage Drivers"
  echo "[N]	Network Drivers"
  echo "[P]	SysPrep (Required)"
  echo ""
  echo "[A]	All of the Above"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_main ;;
    v|V) echo '' && ask_system_admin && menu_main;;
    d|D) echo '' && ask_drives && menu_main ;;
    n|N) echo '' && ask_networking && menu_main;;
    p|P) echo '' && sys_prep && menu_main ;;
    a|A) echo '' && auto_install && menu_main ;;
    *) menu_auto_installer ;;
  esac
}
menu_network()
{
  ./download_and_run "hardware/networking/manager.sh"
  menu_main
}
menu_provisioning()
{
  ./download_and_run "docker/provisioner/pxe/deploy.sh"
}
coach_bootstrap()
{
  auto_install
  ./download_and_run "bootstrap/network.sh"
  ./download_and_run "bootstrap/ceph.sh"
  ./download_and_run "bootstrap/provisioner.sh"
  menu_main
}

connect_to()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Remote Operations Manager"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "Connecting to $1"
  scp_user=$(cat ~/.ssh/config | grep -A 2 $1 | grep User | awk '{print $2}')
  scp_found=1
  if [ -z "$scp_user" ]
  then
    read -p "Username: " scp_user
    scp_found=0
  fi
  if [ -f ~/.ssh/id_rsa ]
  then
    echo ''
    echo "SSH keys are already created."
  else
    echo "Creating SSH keys..."
    echo -e "\n\n\n" | ssh-keygen
  fi
  if [ -z "$(ssh-keygen -F $1)" ]
  then
    echo "Copying new public key from $1..."
    ssh-copy-id $scp_user@$1
    if [ $scp_found == 0 ]
    then
      echo "Host $1" >> ~/.ssh/config
      echo "	Hostname $1" >> ~/.ssh/config
      echo "	User $scp_user" >> ~/.ssh/config
    fi
  fi
  script_name=$(basename $0)
  script_path=$(realpath $0)
  echo ''
  echo "Copying preflight installer..."
  scp $script_path $scp_user@$1:/home/$scp_user/$script_name
  echo ''
  echo "Running preflight installer..."
  ssh -t $scp_user@$1 ./$script_name
}
ask_connect_to()
{
  read -p "Hostname: " connect_to_host
  connect_to $connect_to_host
}
# Main Menu
menu_main()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Main Menu || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  if [ -f /etc/sudoers.d/$(whoami) ]
  then
    echo "[B]	Bootstrap (Setup as Seed Node)"
    echo ""
  fi
  echo "[A]	Auto-Installers"
  echo "[N]	Network Manager"
  if [ ! -z "$(command -v ceph)" ]
  then
    echo "[C]	Ceph Manager"
    echo "[P] Refresh Provisiong Images"
  fi
  echo ""
  echo "[R]	Connect to Remote System"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	EXIT"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && exit ;;
    a|A) echo '' && menu_auto_installer ;;
    n|N) echo '' && menu_network ;;
    c|C) echo '' && menu_ceph ;;
    p|P) echo '' && menu_provisioning ;;
    b|B) echo '' && coach_bootstrap ;;
    r|R) echo '' && ask_connect_to ;;
    *) menu_main ;;
  esac
}
# Installer
if [ -z $1 ]
then
  menu_main
else
  connect_to $1
fi
