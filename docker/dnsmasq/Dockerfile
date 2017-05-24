FROM ubuntu:16.04
RUN apt-get update
RUN apt-get -y install dnsmasq ceph-common
ENTRYPOINT ["dnsmasq", "-d"]
