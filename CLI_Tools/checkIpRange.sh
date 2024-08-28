#!/bin/bash

start_range=$1
end_range=$2

end_range_lsv="$(echo $end_range | cut -d. -f4)"
start_range_lsv="$(echo $start_range | cut -d. -f4)"

if [[ ${start_range_lsv} -gt ${end_range_lsv} ]]
then
    echo "Range must go from smallest IP to biggest IP"
    exit 0
fi

count="$(($end_range_lsv-$start_range_lsv))"

base_addr="$(echo $start_range | cut -d. -f1-3)"
lsv="$(echo $start_range | cut -d. -f4)"

while [ $count -ge 0 ]
do
    #echo $baseaddr.$lsv
    #openstack server list --all-projects | grep $baseaddr.$lsv
    openstack port list | grep -w $base_addr.$lsv
    lsv=$(( $lsv + 1 ))
    count=$(( $count - 1 ))
done

exit 0
