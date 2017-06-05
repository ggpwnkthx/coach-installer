#!/bin/bash

# Build out MegaRAID devices
preflight_megaraid()
{
  # Clear foreign states
  sudo MegaCli -CfgForeign -Clear -aALL
}
build_megaraid()
{
  preflight_megaraid
  sudo megaclisas-status | grep Unconfigured | grep "HDD\|SSD" | while read -r line ;
  do
    adapter=$(echo $line | awk '{print $1}' | grep -o '[0-9]\+')
    device=$(echo $line | awk 'NR>1{print $1}' RS=[ FS=] | sed -e 's/N\/A//g')
    sudo MegaCli -CfgLdAdd -r0[$device] -a$adapter
  done
}
use_megaraid=0
ask_megaraid_ceph()
{
  no_it_mode=$(sudo megaclisas-status | grep "PERC H700\|NonJBODCard")
  if [ ! -z "$no_it_mode" ]
  then
    use_megaraid=1
  fi

  if [ $use_megaraid = 1 ]
  then
    if [ "$(megaclisas-status | grep -c Unconfigured)" -ge 1 ]
    then
      echo ''
      echo "Ceph works best with individual disk, but your controller does not support this."
      read -n1 -p "Do you want to prepare your unconfigured disks into individual RAID0 devices? [y,n]" doit
      case $doit in
        y|Y) echo '' && build_megaraid ;;
        n|N) echo '' && echo 'Disk were not prepared.' ;;
        *) ask_megaraid ;;
      esac
    else
      echo "MegaRAID is enabled, but there are no disks to configure."
    fi
  fi
}
ignore_dev=()
dev="$(lsblk -p -l -o kname | grep -v 'KNAME' | grep -v [0-9])"
dev_available=()
dev_spin=()
dev_ssd=()
preflight_ceph_osd()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Device Scanner || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "Scanning for storage devices..."

  ignore_dev=()
  dev="$(lsblk -p -l -o kname | grep -v 'KNAME' | grep -v [0-9])"
  dev_available=()
  dev_spin=()
  dev_ssd=()

  spin_count=0
  ssd_count=0
  if [ ! -z $(command -v megaclisas-status) ]
  then
    echo "MegaRAID controller found. "
    echo "Cleaning and preparing disks..."
    build_megaraid

    echo "Scanning for any RAID spans with more than 1 device. These will be ignored."
    raid_ignore=($(sudo megaclisas-status | grep Online | grep HDD | awk '{print $1}' | grep p1))
    raid_ignore=(${raid_ignore[@]} $(sudo megaclisas-status | grep Online | grep SSD | awk '{print $1}' | grep p1))
    raid_ignore=("${raid_ignore[@]}" "$(megaclisas-status | grep Online | grep SSD | awk '{print $1}' | grep p1)")
    ignore_count=0
    echo ""
    echo "Ignoring the following MegaRAID devices:"
    for line in "${raid_ignore}"
    do
      raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p1)/\1/')
      dev_id=$(sudo megaclisas-status | grep $raid_id | grep "/dev" | awk '{print $16}')
      ignore_dev=("${ignore_dev[@]}" "$dev_id")
      dev=$(echo "$dev" | grep -v "$dev_id")
      echo "  $raid_id		$dev_id"
    done
    echo ""
    echo "Scanning for MegaRAID hard disks..."
    found_spin=$(sudo megaclisas-status | grep Online | grep HDD)
    if [ ! -z "$found_spin" ]
    then
      raid_spin=($(echo "${found_spin[@]}" | awk '{print $1}' | grep p0))
      for line in "${raid_spin[@]}"
      do
        raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p0)/\1/')
        dev_id=$(sudo megaclisas-status | grep -w $raid_id | grep "/dev" | awk '{print $16}')
        should_ignore=$((for e in "${ignore_dev[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0)
        if [ "$should_ignore" -lt 1 ]
        then
          dev_spin=("${dev_spin[@]}" "$dev_id")
          dev_available=("${dev_available[@]}" "$dev_id")
          dev=$(echo "$dev" | grep -v "$dev_id")
          echo "  $raid_id		$dev_id"
          spin_count=$[$spin_count + 1]
        fi
      done
    fi
    echo ""
    echo "Scanning for MegaRAID solid state disks..."
    found_ssd=$(sudo megaclisas-status | grep Online | grep SSD)
    if [ ! -z "$found_ssd" ]
    then
      raid_ssd=($(echo "${found_ssd[@]}" | awk '{print $1}' | grep p0))
      for line in "${raid_ssd[@]}"
      do
        raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p0)/\1/')
        dev_id=$(sudo megaclisas-status | grep -w $raid_id | grep "/dev" | awk '{print $16}')
        should_ignore=$((for e in "${ignore_dev[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0)
        if [ "$should_ignore" -lt 1 ]
        then
          dev_ssd=("${dev_ssd[@]}" "$dev_id")
          dev_available=("${dev_available[@]}" "$dev_id")
          dev=$(echo "$dev" | grep -v "$dev_id")
          echo "  $raid_id		$dev_id"
          ssd_count=$[$ssd_count + 1]
        fi
      done
    fi
    echo ""
  fi
  if [ ! -z "$dev" ]
  then
    while read line
    do
      id=$(echo "$line" | awk '{split($0,a,"/"); print a[3]}')
      if [ -z "$(sudo cat /proc/mdstat | grep $id)" ]
      then
        if [ -z  $(lsblk -p -l -o kname | grep -e $line"[0-9]") ]
        then
          if [ $(lsblk -p -l -o kname,rota | grep -e $line | awk '{print $2}') -gt 0 ]
          then
            dev_spin=("${dev_spin[@]}" "$line")
            spin_count=$[$spin_count + 1]
          else
            dev_ssd=("${dev_ssd[@]}" "$line")
            ssd_count=$[$ssd_count + 1]
          fi
        else
          if [ $(lsblk -p -l -o kname,rota | grep -e $line | grep -v -e $line"[0-9]" | awk '{print $2}') -gt 0 ]
          then
            dev_spin=("${dev_spin[@]}" "$line")
            spin_count=$[$spin_count + 1]
          else
            dev_ssd=("${dev_ssd[@]}" "$line")
            ssd_count=$[$ssd_count + 1]
          fi
        fi
        dev_available=("${dev_available[@]}" "$line")
      fi
    done <<EOT
$(echo "$dev")
EOT
  fi
}
diff(){
  awk 'BEGIN{RS=ORS=" "}
       {NR==FNR?a[$0]++:a[$0]--}
  END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}

printout_ceph_osd()
{
  RED='\033[1;31m'
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
  counter=0
  add_selections=()
  remove_selections=()
  fix_selections=()
  for dev_id in ${dev_available[@]}
  do
    counter=$[$counter +1]
    if [ $((for e in "${dev_available[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
    then
      if [ ${#dev_spin[@]} -gt 0 ]
      then
        if [ $((for e in "${dev_spin[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph data')" ]
          then
            osd_id=$(mount | grep $dev_id | grep ceph | awk '{print $3}' | grep -Eo '[0-9]{1,4}')
            if [ -z "$osd_id" ]
            then
              in_use=$(sudo sgdisk $dev_id -p | sed -n -e '/Number/,$p' | grep -v Number | grep -v ceph)
              if [ -z "$in_use" ]
              then
                if [ "$1" = "no-select" ]
                then
                  printf  "$dev_id	HDD	${BLUE}ORPHANED${NC}\n"
                else
                  printf  "${BLUE}[$counter]${NC}	$dev_id	HDD	${BLUE}ORPHANED${NC}\n"
                fi
                add_selections=("${add_selections[@]}" "$counter")
              else
                if [ "$1" = "no-select" ]
                then
                  printf "$dev_id	HDD	${YELLOW}IN USE${NC}\n"
                else
                  printf "${YELLOW}[$counter]${NC}	$dev_id	HDD	${YELLOW}IN USE${NC}\n"
                fi
                add_selections=("${add_selections[@]}" "$counter")
              fi
            else
              if [ "$1" = "no-select" ]
              then
                printf  "${RED}[$counter]${NC}	$dev_id	HDD	${RED}(osd.$osd_id)${NC}\n"
              else
                printf  "${RED}[$counter]${NC}	$dev_id	HDD	${RED}(osd.$osd_id)${NC}\n"
              fi
              remove_selections=("${remove_selections[@]}" "$counter")
            fi
          else
            if [ -z $(lsblk -p -l -o kname | grep -e $dev_id"[0-9]") ]
            then
              if [ "$1" = "no-select" ]
              then
                printf "$dev_id	HDD\n"
              else
                printf "${GREEN}[$counter]${NC}	$dev_id	HDD\n"
              fi
              add_selections=("${add_selections[@]}" "$counter")
            fi
          fi
        fi
      fi
      if [ ${#dev_ssd[@]} -gt 0 ]
      then
        if [ $((for e in "${dev_ssd[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph data')" ]
          then
            osd_id=$(mount | grep $dev_id | grep ceph | awk '{print $3}' | grep -Eo '[0-9]{1,4}')
            if [ -z "$osd_id" ]
            then
              in_use=$(sudo sgdisk $dev_id -p | sed -n -e '/Number/,$p' | grep -v Number | grep -v ceph)
              if [ -z "$in_use" ]
              then
                if [ "$1" = "no-select" ]
                then
                  printf  "$dev_id	SSD	${BLUE}ORPHANED${NC}\n"
                else
                  printf  "${BLUE}[$counter]${NC}	$dev_id	SSD	${BLUE}ORPHANED${NC}\n"
                then
                add_selections=("${add_selections[@]}" "$counter")
              else
                if [ "$1" = "no-select" ]
                then
                  printf "$dev_id	SSD	${YELLOW}IN USE${NC}\n"
                else
                  printf "${YELLOW}[$counter]${NC}	$dev_id	SSD	${YELLOW}IN USE${NC}\n"
                fi
                add_selections=("${add_selections[@]}" "$counter")
              fi
            else
              if [ "$1" = "no-select" ]
              then
                printf  "$dev_id	SSD	${RED}(osd.$osd_id)${NC}\n"
              else
                printf  "${RED}[$counter]${NC}	$dev_id	SSD	${RED}(osd.$osd_id)${NC}\n"
              fi
              remove_selections=("${remove_selections[@]}" "$counter")
            fi
          else
            if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph journal')" ]
            then
              parts=($(lsblk -p -l -o kname | grep -e $dev_id"[0-9]"))
              echo "	$dev_id	SSD	(${#parts[@]} Journals)"
            else
              if [ -z $(lsblk -p -l -o kname | grep -e $dev_id"[0-9]") ]
              then
                if [ "$1" = "no-select" ]
                then
                  printf  "$dev_id	SSD\n"
                else
                  printf  "${GREEN}[$counter]${NC}	$dev_id	SSD\n"
                fi
                add_selections=("${add_selections[@]}" "$counter")
              fi
            fi
          fi
        fi
      fi
    fi
  done
}

menu_ceph_osd()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Available Devices || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "	PATH		TYPE	ACTIVITY"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printout_ceph_osd
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
}

install_ceph_osd()
{
  menu_ceph_osd
  if [ $counter -gt 0 ]
  then
    read -p "Which device would you like to use for an OSD? " to_be_osd
    if [ "$to_be_osd" != "0" ]
    then
      if [ $((for e in "${add_selections[@]}"; do [[ "$e" == "$to_be_osd" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
      then
        if [ $((for e in "${dev_spin[@]}"; do [[ "$e" == "${dev_available[to_be_osd-1]}" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ${#dev_ssd[@]} -gt 0 ]
          then
            counter=0
            journal_selections=()
            echo ''
            echo "Ceph journaling can be used for the following SSDs (may take a moment to load):"
            for i in ${dev_ssd[@]}
            do
              counter=$[$counter +1]
              parts=($(lsblk -p -l -o kname | grep -e $i"[0-9]"))
              if [ "${#parts[@]}" -gt 0 ]
              then
                if [ ! -z "$(sudo sgdisk $i -p | grep 'ceph journal')" ]
                then
                  journal_free_space=$(sudo parted $i unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}' | sed 's/MB//g')
                  if [ $journal_free_space -gt $osd_journal_size ]
                  then
                    echo "[$counter]	$i	(Space Available)"
                    journal_selections=("${journal_selections[@]}" "$counter")
                  else
                    echo "	$i	(Full)"
                  fi
                fi
              else
                echo "[$counter]	$i	(Empty)"
                journal_selections=("${journal_selections[@]}" "$counter")
              fi
            done
            read -p "Which device would you like to use for the ceph journal? " to_be_journal
            if [ $((for e in "${journal_selections[@]}"; do [[ "$e" == "$to_be_journal" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
            then
              create_ceph_osd ${dev_available[to_be_osd-1]} ${dev_ssd[to_be_journal-1]}
            else
              echo "Your selection was not in the list of available devices."
              install_ceph_osd
            fi
          fi
          create_ceph_osd ${dev_available[to_be_osd-1]}
        else
          echo "You chose an SSD."
        fi
        install_ceph_osd
      else
        echo "Your selection was not in the list of available devices."
        install_ceph_osd
      fi
    else
      menu_ceph_osd
    fi
  else
    echo "No devices available."
    read -n 1 -s -p "Press any key to return to the previous menu..."
    menu_ceph
  fi
}
ask_ceph_osd_add()
{
  if [ ${#dev_ssd[@]} -gt 0 ]
  then
    ask_ceph_journal_size
  fi
  install_ceph_osd
  menu_ceph
}
delete_ceph_osd()
{
  if [ ! -z $1 ]
  then
    sudo systemctl stop ceph-osd@$1
    sudo umount /var/lib/ceph/osd/ceph-$1
    ssh -t $ceph_admin "cd ~/ceph && ceph osd out $1 && ceph osd crush remove osd.$1 && ceph auth del osd.$1 && ceph osd rm $1"
    sudo sgdisk -z $2
  else
    echo "You need to provide a valid OSD #"
  fi
  remove_ceph_osd
}
remove_ceph_osd()
{
  menu_ceph_osd
  if [ $counter -gt 0 ]
  then
    read -p "Which OSD would you like to remove from the cluster? " to_be_osd
    if [ "$to_be_osd" != "0" ]
    then
      if [ $((for e in "${remove_selections[@]}"; do [[ "$e" == "$to_be_osd" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
      then
        menu="$(menu_ceph_osd)"
        osd_id=$(echo "$menu" | grep '\['$to_be_osd'\]' | awk '{print $4}' | grep -Eo '[0-9]{1,4}' )
        read -p "Are you absolutely sure you want to delete this OSD? [y,n]" doit
        case $doit in
          y|Y) echo '' && delete_ceph_osd $osd_id ${dev_available[to_be_osd-1]};;
          n|N) remove_ceph_osd ;;
          *) remove_ceph_osd ;;
        esac
      else
        echo "Your selection was not in the list of available devices."
        remove_ceph_osd
      fi
    fi
  else
    echo "No devices available."
  fi
}
ask_ceph_osd_remove()
{
  remove_ceph_osd
  menu_ceph
}
scanned=0
menu_ceph_osd()
{
  if [ $scanned -eq 0 ]
  then
    preflight_ceph_osd
    scanned=1
  fi
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Ceph OSD - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printout_ceph_osd
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[A]	Add OSD"
  echo "[R]	Remove OSD"
  echo "[S]	Rescan Devices"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_ceph ;;
    a|A) echo '' && ask_ceph_osd_add ;;
    r|R) echo '' && ask_ceph_osd_remove ;;
    s|S) echo '' && preflight_ceph_osd && menu_ceph_osd ;;
    *) menu_ceph_osd ;;
  esac
}

menu_ceph_osd
