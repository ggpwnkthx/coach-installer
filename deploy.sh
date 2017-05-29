#!/bin/bash

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
  echo "[B]	Bootstrap (Setup as Seed Node)"
  echo ""
  echo "[A]	Auto-Installers"
  echo "[N]	Network Manager"
  if [ ! -z "$(command -v ceph)" ]
  then
    echo "[C]	Ceph Manager"
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
