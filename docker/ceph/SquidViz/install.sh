#!/bin/bash
wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/docker/ceph/SquidViz/Dockerfile
sudo docker build -t "coach/squidviz" .
if [ ! -z "$(sudo docker ps | grep squidviz)" ]
then
  sudo docker kill squidviz
fi
if [ ! -z "$(sudo docker ps -a | grep squidviz)" ]
then
  sudo docker rm squidviz
fi
sudo docker run -d --name squidviz -p 80:80 coach/squidviz
