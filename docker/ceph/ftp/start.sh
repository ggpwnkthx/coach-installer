if [ ! -z $1 ]
then
  user=$1
#  if [ ! -z $2 ]
#  then
#    password=$2
#  else
#    echo "No password specified."
#    exit
#  fi
else
#  echo "No username or password specified."
  echo "No username specified."
  exit
fi
if [ ! -d /mnt/ceph/fs/containers/ftp/config ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/ftp/config
  sudo chmod +rw /mnt/ceph/fs/containers/ftp/config
fi
if [ ! -d /mnt/ceph/fs/containers/ftp/data ]
then
  sudo mkdir -p /mnt/ceph/fs/containers/ftp/data
  sudo chmod +rw /mnt/ceph/fs/containers/ftp/data
fi
if [ ! -z "$(sudo docker ps | grep ftpd_server)" ]
then
  sudo docker kill ftpd_server
fi
if [ ! -z "$(sudo docker ps -a | grep ftpd_server)" ]
then
  sudo docker rm ftpd_server
fi
sudo docker run -d --name ftpd_server \
  -v /mnt/ceph/fs/containers/ftp/config:/etc/pure-ftpd/passwd \
  -v /mnt/ceph/fs/containers/ftp/data:/home \
  -p 21:21 \
  -p 30000-30039:30000-30039 \
  -e "PUBLICHOST=localhost" \
  stilliard/pure-ftpd:hardened
sudo docker exec -it ftpd_server pure-pw useradd $user -f /etc/pure-ftpd/passwd/pureftpd.passwd -m -u ftpuser -d /home/$user
