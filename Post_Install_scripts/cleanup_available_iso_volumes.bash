#!/bin/bash
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"

project_id=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/deployments/?q=name=${deploymentId}&fields=project_id" | egrep -o "project_id.*?" | cut -d '"' -f3)
project_name=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/projects?q=_id=${project_id}&fields=name" | egrep -o "name.*?" | cut -d '"' -f3)

CLI_Tools/create_rc "$project_name"
. "$project_name-openrc.sh"

rm "$project_name-openrc.sh"

for vol in $(openstack volume list | grep -E "vol-|iso"| grep available | awk '{print $2}')
do
    vol_name=$(openstack volume show "$vol" | grep "name  "| awk '{print $4}')
    date_t=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$date_t" "Deleting volume" "$vol" "$vol_name"
    openstack volume delete "$vol"
done