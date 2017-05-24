FROM ubuntu:16.04
RUN apt-get update
RUN apt-get -y install dnsmasq apache2 php7.0 libapache2-mod-php7.0
ENTRYPOINT ["dnsmasq", "-d"]
