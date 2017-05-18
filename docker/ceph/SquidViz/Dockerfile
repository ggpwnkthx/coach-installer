FROM janes/alpine-lamp
MAINTAINER Isaac Jessup "ibjessup@gmail.com"

RUN wget https://github.com/TheSov/squidviz/archive/master.zip -O SquidViz.zip
RUN unzip SquidViz.zip -d /www

ENTRYPOINT ["/start.sh"]
