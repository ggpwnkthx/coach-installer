# Install Dell OpenManage Server Administrator
install_dell_omsa()
{
  echo 'deb http://linux.dell.com/repo/community/ubuntu trusty openmanage' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list
  gpg --keyserver pool.sks-keyservers.net --recv-key 1285491434D8786F ; gpg -a --export 1285491434D8786F | sudo apt-key add -
  # add openjdk-7-jdk repository to meet dependencies
  sudo add-apt-repository ppa:openjdk-r/ppa
  sudo apt-get update
  sudo apt-get -y install srvadmin-all
  sudo apt-get -y install srvadmin-omcommon srvadmin-storage srvadmin-base srvadmin-storageservices srvadmin-deng srvadmin-omacs srvadmin-omilcore srvadmin-storelib srvadmin-ominst srvadmin-smcommon srvadmin-storelib-sysfs srvadmin-isvc srvadmin-rnasoap srvadmin-xmlsup srvadmin-realssd srvadmin-nvme srvadmin-storageservices-snmp srvadmin-storageservices-cli srvadmin-storage-snmp srvadmin-deng-snmp srvadmin-isvc-snmp srvadmin-idrac-snmp srvadmin-storage-cli srvadmin-omacore
  sudo service dsm_om_connsvc start
  sudo update-rc.d dsm_om_connsvc defaults
  sudo service dataeng start
}

if [ "$1" == "-y"]
then
  install_dell_omsa
else
  is_dell=$(service dataeng status | grep "No such file or directory")
  if [ ! -z "$is_dell" ]
  then
    echo ''
    echo 'Vendor has been identified as Dell.'
    read -n1 -p "Would you like to install the Dell Open Manage Server Adminstrator? [y,n]" doit
    case $doit in
      y|Y) echo '' && install_dell_omsa && echo '' ;;
      n|N) echo '' && echo 'Dell OMSA will not be installed.' ;;
      *) ask_dell_omsa ;;
    esac
  else
    echo "Dell OMSA already installed."
  fi
fi
