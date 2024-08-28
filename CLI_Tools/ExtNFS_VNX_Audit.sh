#!/bin/bash

if [ -z "$1" ]; then
echo "Please enter VNX IP"
exit 1
fi

VNXIP=$1
MODELNUMBER=$(naviseccli -User admin -Password password -Scope global -Address $VNXIP getagent | grep Model | awk '{print $2}' | grep -o [0-9]*)
NAME=$(nslookup $VNXIP | grep -o vnx.* | awk -F. '{print $1}' | sed s'/sp[a|b]//g')
FREEDISKS=$(naviseccli -User admin -Password password -Scope global -Address $VNXIP getdisk | grep "does not belong to a RAIDGroup" | wc -l)
HOWMANYEIGHTS=$(( $FREEDISKS / 8 ))


echo "===================================================================================="
echo "================================= GENERAL INFO ====================================="
echo "===================================================================================="
echo "Name : "$NAME
echo "Model number : "$MODELNUMBER
echo "Total Disks : "$(naviseccli -User admin -Password password -Scope global -Address $VNXIP getdisk | grep ^"Serial Number" | wc -l)
echo "Free Disks : "$FREEDISKS
echo "Free Space (assuming a RAID level of 1 + 0) : "$(( ($HOWMANYEIGHTS * 8) * 536 )) GB

IFS=$'\n'
STORAGEPOOLLIST=$(naviseccli -User admin -Password password -Scope global -Address $VNXIP storagepool -list | grep "Pool Name" | sed 's/Pool Name://'g | awk '{$1=$1}1')
if [[ ! $STORAGEPOOLLIST ]]
then
	echo "No Storage Pools Found"
	exit 0
else
	echo "===================================================================================="
	echo "============================== STORAGE POOL INFO ==================================="
	echo "===================================================================================="
	for storagepool in $STORAGEPOOLLIST
	do
		echo "Pool Name : "$storagepool
		echo "Number of LUNs : "$(naviseccli -User admin -Password password -Scope global -Address $VNXIP storagepool -list -name $storagepool | grep LUNs | awk -F, '{print NF}')
		echo "Number of disks : "$(naviseccli -User admin -Password password -Scope global -Address $VNXIP storagepool -list -name $storagepool | grep Bus | wc -l)
		naviseccli -User admin -Password password -Scope global -Address $VNXIP storagepool -list -name $storagepool | grep -i available | grep -i gbs
		LUNNUMS=$(naviseccli -User admin -Password password -Scope global -Address $VNXIP storagepool -list -name $storagepool | grep LUNs | grep -o [0-9].*)
		IFS=', ' read -r -a LUNSLIST <<< "$LUNNUMS"
		echo "------------------------------------"
		echo "------------- LUN INFO -------------"
		echo "------------------------------------"
		for lun in ${LUNSLIST[@]}
		do
			naviseccli -User admin -Password password -Scope global -Address $VNXIP lun -list -l $lun | grep ^Name
			naviseccli -User admin -Password password -Scope global -Address $VNXIP lun -list -l $lun | grep -i capacity | grep -vi blocks
			naviseccli -User admin -Password password -Scope global -Address $VNXIP lun -list -l $lun | grep -i thin
			echo "------------------------------------"
		done
		echo "===================================================================================="
	done
fi
