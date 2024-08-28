#!/bin/bash
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"

if [[ ${jobType}  == 'teardown' ]]; then
    echo "Nothing to do as teardown"
    exit 0
fi
project_id=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/deployments/?q=name=${deploymentId}&fields=project_id" | egrep -o "project_id.*?" | cut -d '"' -f3)
project_name=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/projects?q=_id=${project_id}&fields=name" | egrep -o "name.*?" | cut -d '"' -f3)

CLI_Tools/create_rc "$project_name"
. "$project_name-openrc.sh"

rm "$project_name-openrc.sh"

security_group=$(openstack security group list| grep $project_name | grep enm_external | awk '{print $2}')
rules=$(openstack security group rule list | grep $security_group | awk '{print $8}' | grep -E "111|2049" | wc -l)
if [ ${rules} -eq 0 ]; then
    echo "Creating security group rules for ENIQ (111 and 2049)"
    for port in 2049 111; do
        for prot in udp tcp; do
            for ether_type in IPv4 IPv6; do
                for direction in egress ingress; do
                    if [ "$ether_type" == "IPv4" ]; then
                        openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port $port --protocol $prot --ethertype $ether_type --$direction --description ENIQ $security_group
                    else
                        openstack security group rule create --remote-ip ::/0 --dst-port $port --protocol $prot --ethertype $ether_type --$direction --description ENIQ $security_group
                    fi
                done
            done
        done
    done
else
    echo "Security Rules exist for 111 or 2049"
    openstack security group rule list | grep -E "Remote Security Group|$security_group" | grep -E " 111| 2049|Remote Security Group"
fi
