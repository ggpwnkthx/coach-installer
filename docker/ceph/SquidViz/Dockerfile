FROM nickistre/ubuntu-lamp
MAINTAINER Isaac Jessup "ibjessup@gmail.com"

RUN apt-get update && apt-get -y install ceph-common
RUN wget https://github.com/TheSov/squidviz/archive/master.zip -O SquidViz.zip
RUN unzip SquidViz.zip -d /var
RUN rm -r /var/www
RUN mv /var/squidviz-master /var/www

ENTRYPOINT ["/start.sh"]
