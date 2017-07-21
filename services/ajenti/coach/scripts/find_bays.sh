#!/bin/bash
# Display drive bay for disks connected to SAS expander backplane
for name in /sys/block/* ; do
    dev=$(echo $name | awk -F/ '{print $4}')
    npath=$(readlink -f $name)
    while [ $npath != "/" ] ; do
        npath=$(dirname $npath)
        ep=$(basename $npath)
        if [ -e $npath/sas_device/$ep/bay_identifier ] ; then
            bay=$(cat $npath/sas_device/$ep/bay_identifier)
            encl=$(cat $npath/sas_device/$ep/enclosure_identifier)
            echo \"/dev/$dev\": $bay
            break
        fi
    done
done
