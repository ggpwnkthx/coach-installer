if [ ! -z $1 ]
then
  user=$1
  if [ ! -z $2 ]
  then
    password=$2
  else
    echo "No password specified."
    exit
  fi
else
  echo "No username or password specified."
  exit
fi
if [ ! -d /mnt/ceph/fs/containers/ftp/config ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/ftp/config
fi
if [ ! -f /mnt/ceph/fs/containers/ftp/config/sftp-users.conf ]
then
  echo "$user:$password:1001" | sudo tee /mnt/ceph/fs/containers/ftp/config/sftp-users.conf
  if [ ! -d /mnt/ceph/fs/containers/ftp/data/$user ]
  then
    sudo mkdir -p /mnt/ceph/fs/containers/ftp/data/$user
  fi
else
  if [ -z "$(cat /mnt/ceph/fs/containers/ftp/config/sftp-users.conf | grep $user)" ]
  then
    uids=($(cat /mnt/ceph/fs/containers/ftp/config/sftp-users.conf | awk '{split($0,a,":"); print a[3]}'))
    if [ -z $uids ]
    then
      uids=1000
    fi
    IFS=$'\n'
    hi=$(echo "${uids[*]}" | sort -nr | head -n1)
    uid=$[$hi+1]
    echo "$user:$password:$uid" | sudo tee --append /mnt/ceph/fs/containers/ftp/config/sftp-users.conf
    if [ ! -d /mnt/ceph/fs/containers/ftp/data/$user ]
    then
      sudo mkdir -p /mnt/ceph/fs/containers/ftp/data/$user
    fi
  else
    uid=$(cat /mnt/ceph/fs/containers/ftp/config/sftp-users.conf | grep $user | awk '{split($0,a,":"); print a[3]}')
    sudo sed -i "/^$user/d" /mnt/ceph/fs/containers/sftp/config/users.conf
    echo "$user:$password:$uid" | sudo tee --append /mnt/ceph/fs/containers/ftp/config/sftp-users.conf
    if [ ! -d /mnt/ceph/fs/containers/ftp/data/$user ]
    then
      sudo mkdir -p /mnt/ceph/fs/containers/ftp/data/$user
    fi
  fi
fi
sudo chmod 777 /mnt/ceph/fs/containers/ftp/data/$user
if [ ! -z "$(sudo docker ps | grep ftpd_server)" ]
then
  sudo docker kill ftpd_server
fi
if [ ! -z "$(sudo docker ps -a | grep ftpd_server)" ]
then
  sudo docker rm ftpd_server
fi
sudo docker run -d --name ftpd_server \
  -v /mnt/ceph/fs/containers/ftp/config/sftp-users.conf:/etc/sftp-users.conf:ro \
  -v /mnt/ceph/fs/containers/ftp/data:/home \
  -p 21:21 \
  -p 30000-300039:30000-300039 \
  -e "PUBLICHOST=localhost" \
  stilliard/pure-ftpd:hardened
