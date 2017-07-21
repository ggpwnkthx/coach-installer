#!/bin/bash
SYSTEMD_ETC_DIR="/etc/systemd/system"
SYSTEMD_USR_DIR="/usr/lib/systemd/system"

cd $SYSTEMD_USR_DIR
rm -f ceph-*.service
rm -f ceph*.target

for CONF in /etc/ceph/*.conf; do
  CLUSTER=${CONF##/etc/ceph/}
  CLUSTER=${CLUSTER%%.conf}
  cat << EOF > $CLUSTER.target
[Unit]
Description=Ceph target allowing to start/stop all ceph*@.service instances at once
Wants=$CLUSTER-mon.target $CLUSTER-osd.target

[Install]
WantedBy=multi-user.target
EOF

  for TYPE in osd mon; do
    mkdir -p $SYSTEMD_ETC_DIR/$CLUSTER-$TYPE.target.wants
    rm -f $SYSTEMD_ETC_DIR/$CLUSTER-$TYPE.target.wants/*
    
    for DAEMON in $(ceph-conf -c $CONF -l $TYPE --filter-key-value host=`hostname -s`); do
        ID=${DAEMON##$TYPE.}
        case $TYPE in 
            'osd')  cat << EOF > $CLUSTER-$TYPE@$ID.service
[Unit]
Description=Ceph object storage daemon
After=$CLUSTER-mon.target
Wants=$CLUSTER-mon.target
PartOf=$CLUSTER-osd.target

[Service]
EnvironmentFile=-/etc/sysconfig/ceph
ExecStart=/usr/bin/ceph-osd -f --cluster $CLUSTER --id $ID
ExecStartPre=/usr/libexec/ceph/ceph-osd-prestart.sh --cluster $CLUSTER --id $ID
LimitNOFILE=131072
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=$CLUSTER-osd.target
EOF
					echo "Created $CLUSTER-$TYPE@$ID.service"
                    cat << EOF > $CLUSTER-$TYPE@.service
[Unit]
Description=Ceph object storage daemon
After=$CLUSTER-mon.target
Wants=$CLUSTER-mon.target
PartOf=$CLUSTER-osd.target

[Service]
EnvironmentFile=-/etc/sysconfig/ceph
ExecStart=/usr/bin/ceph-osd -f --cluster $CLUSTER --id %i
ExecStartPre=/usr/libexec/ceph/ceph-osd-prestart.sh --cluster $CLUSTER --id %i
LimitNOFILE=131072
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=$CLUSTER-osd.target
EOF
					echo "Created $CLUSTER-$TYPE.service"
                    cat << EOF > $CLUSTER-$TYPE.target
[Unit]
Description=Ceph OSD target allowing to start/stop all CEPH OSDs at once
After=$CLUSTER-mon.target
PartOf=$CLUSTER.target

[Install]
WantedBy=$CLUSTER.target
EOF
					echo "Created $CLUSTER-$TYPE.target"

            ln -s $SYSTEMD_USR_DIR/$CLUSTER-$TYPE@$ID.service -t $SYSTEMD_ETC_DIR/$CLUSTER-$TYPE.target.wants
            ;;

            'mon')  cat << EOF > $CLUSTER-$TYPE@$ID.service
[Unit]
Description=Ceph cluster monitor daemon
After=network-online.target local-fs.target
Wants=network-online.target local-fs.target
PartOf=$CLUSTER-mon.target

[Service]
EnvironmentFile=-/etc/sysconfig/ceph
ExecStart=/usr/bin/ceph-mon -f --cluster $CLUSTER --id $ID
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=$CLUSTER-mon.target
EOF
					echo "Created $CLUSTER-$TYPE@$ID.service"
                    cat << EOF > $CLUSTER-$TYPE@.service
[Unit]
Description=Ceph cluster monitor daemon
After=network-online.target local-fs.target
Wants=network-online.target local-fs.target
PartOf=$CLUSTER-mon.target

[Service]
EnvironmentFile=-/etc/sysconfig/ceph
ExecStart=/usr/bin/ceph-mon -f --cluster $CLUSTER --id %i
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=$CLUSTER-mon.target
EOF
					echo "Created $CLUSTER-$TYPE@.service"
                    cat << EOF > $CLUSTER-$TYPE.target
[Unit]
Description=Ceph MON target allowing to start/stop all Ceph monitors at once
After=network-online.target local-fs.target
PartOf=$CLUSTER.target

[Install]
WantedBy=$CLUSTER.target
EOF
					echo "Created $CLUSTER-$TYPE.target"

            ln -s $SYSTEMD_USR_DIR/$CLUSTER-$TYPE@$ID.service -t $SYSTEMD_ETC_DIR/$CLUSTER-$TYPE.target.wants
            ;; 
        esac
    done
  done
done
