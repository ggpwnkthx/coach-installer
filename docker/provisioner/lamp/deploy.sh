#!/bin/bash
services=(provisioner_lamp)
for s in ${services[@]}
do
  if [ ! -z "$(sudo docker ps -a | grep $s)" ]
  then
    sudo docker rm -f $s
  fi
done
if [ ! -d /mnt/ceph/fs/containers/provisioner/www ]
then
  sudo mkdir /mnt/ceph/fs/containers/provisioner/www
fi

echo "#!/bin/bash" | sudo tee /etc/ceph/provisioner-lamp.sh
echo "case \$1 in" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "  start)" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    docker run -d \\" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "      --name provisioner_lamp --net=host \\" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "      -v /mnt/ceph/fs/containers/provisioner/www:/www \\" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "      janes/alpine-lamp" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "  stop)" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    docker stop provisioner_lamp" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    docker rm -f provisioner_lamp" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "  status)" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    docker ps -a | grep provisioner_lamp" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "    ;;" | sudo tee --append /etc/ceph/provisioner-lamp.sh
echo "esac" | sudo tee --append /etc/ceph/provisioner-lamp.sh
