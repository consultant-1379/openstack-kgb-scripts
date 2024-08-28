#!/bin/bash
#
# Usage: monitor_resources <project name>
if [ -z "$1" ]; then
    echo "Please specify a Project Name EG 'MyProject_C4A19'"
    exit 1
elif [ -z "$2" ]; then
    echo "Please specify an Image Name"
    exit 1
fi
project_name=$1
image_name=$2
#Authenticate with deployment
#Get rc
./create_rc $project_name
#Source rc
source $project_name-openrc.sh
#Clean up rc file
rm $project_name-openrc.sh
#Count images used for queuing
openstack image list | grep -i $image_name | wc -l
