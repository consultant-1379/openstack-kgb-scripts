#!/bin/bash
set +x
CURL=/usr/bin/curl
ECHO=/bin/echo
AWK=/usr/bin/awk
DEPLOYER_REGEX='^[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}$'
echo "HOSTNAME=${HOSTNAME}"
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"

function retrieve_ddp_information_from_dit () {
    echo "Retrieving DDP info and private key from DIT"
    ddpdocument=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/deployments/?q=name=${deploymentId}&fields=documents" | egrep -o "ddp.*?"| awk -F"\"" '{print $5}')
    if [ -z ${ddpdocument} ]
        then
            echo "There is no DDP document in DIT for deployment: $deploymentId"
        else
            ddpname=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/${ddpdocument}?fields=name" | egrep -o "name.*?" | cut -d '"' -f3| cut -c 5-)
            ddphostname=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/${ddpdocument}?fields=content/hostname" | egrep -o "hostname.*?" | cut -d '"' -f3)
            croninterval=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/${ddpdocument}?fields=content/cron" | egrep -o "cron.*?" | cut -d '"' -f3)
            echo "DDP document https://atvdit.athtem.eei.ericsson.se/api/documents/$ddpdocument"
            echo "DDP site name $ddpname, DDP server name $ddphostname, cron interval $croninterval"
            echo "Retrieving esmon details"
            esmon_ip=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents?q=name=${deploymentId}&fields=content/parameters/esmon_external_ip_list" | egrep -o "esmon_external_ip_list.*?" | cut -d '"' -f3)
            if [ -z ${esmon_ip} ]
                then
                    echo "ESMON is not deployed"
                else
                    echo "ESMON IP $esmon_ip"
                    echo "Updating /var/ericsson/ddc_data/config/ddc_upload"
                    crontext="$croninterval * * * * root /opt/ericsson/ERICddc/bin/ddcDataUpload -d $ddphostname -s $ddpname"
                    ssh -o StrictHostKeyChecking=no -i ./private_key.pem cloud-user@$esmon_ip "echo $crontext | sudo tee /var/ericsson/ddc_data/config/ddc_upload"
                    echo "Updating/var/ericsson/ddc_data/config/ddp.txt"
                    ssh -o StrictHostKeyChecking=no -i ./private_key.pem cloud-user@$esmon_ip "echo lmi_$ddpname | sudo tee /var/ericsson/ddc_data/config/ddp.txt"
            fi
    fi
}

function retrieve_private_key() {
    echo "Retrieving private key from DIT"
    private_key=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/deployments/?q=name=${deploymentId}&fields=enm/private_key" | egrep -o "private_key.*?" | cut -d '"' -f3)
    echo -e $private_key > private_key.pem
    chmod 600 private_key.pem
}
function remove_private_key() {
    echo "Removing private key from VM"
    rm -- "private_key.pem"
}

retrieve_private_key
retrieve_ddp_information_from_dit
remove_private_key
