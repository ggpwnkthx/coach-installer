#/bin/bash
sudo apt-get -y install docker.io
sudo docker run -d --restart=always -p 8080:8080 rancher/server
