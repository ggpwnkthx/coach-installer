#!/bin/bash
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
if [ ! -d /mnt/ceph/fs/containers/sftp/config ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/sftp/config
fi
if [ ! -f /mnt/ceph/fs/containers/sftp/config/users.conf ]
then
  echo "$user:$password:1001" | sudo tee /mnt/ceph/fs/containers/sftp/config/users.conf
  if [ ! -d /mnt/ceph/fs/containers/sftp/data/$user ]
  then
    sudo mkdir -p /mnt/ceph/fs/containers/sftp/data/$user
  fi
else
  if [ -z "$(cat /mnt/ceph/fs/containers/sftp/config/users.conf | grep $user)" ]
  then
    uids=($(cat /mnt/ceph/fs/containers/sftp/config/users.conf | awk '{split($0,a,":"); print a[3]}'))
    IFS=$'\n'
    hi=$(echo "${uids[*]}" | sort -nr | head -n1)
    uid=$[$hi+1]
    echo "$user:$password:$uid" | sudo tee --append /mnt/ceph/fs/containers/sftp/config/users.conf
    if [ ! -d /mnt/ceph/fs/containers/sftp/data/$user ]
    then
      sudo mkdir -p /mnt/ceph/fs/containers/sftp/data/$user
    fi
  else
    uid=$(cat /mnt/ceph/fs/containers/sftp/config/users.conf | grep $user | awk '{split($0,a,":"); print a[3]}')
    sudo sed -i '/^$user/d' /mnt/ceph/fs/containers/sftp/config/users.conf
    echo "$user:$password:$uid" | sudo tee --append /mnt/ceph/fs/containers/sftp/config/users.conf
    if [ ! -d /mnt/ceph/fs/containers/sftp/data/$user ]
    then
      sudo mkdir -p /mnt/ceph/fs/containers/sftp/data/$user
    fi
  fi
fi
docker run \
    -v /mnt/ceph/fs/containers/sftp/config/users.conf:/etc/sftp-users.conf:ro \
    -v /mnt/ceph/fs/containers/sftp/data/user:/home/user/ \
    -p 22:22 -d atmoz/sftp
