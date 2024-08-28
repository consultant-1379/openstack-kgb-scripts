#!/bin/bash
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"

function retrieve_private_key () {
	echo "Retrieving EMP IP and private key from DIT"
	emp_ip=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents?q=name=${deploymentId}&fields=content/parameters/emp_external_ip_list" | egrep -o "emp_external_ip_list.*?" | cut -d '"' -f3)
	private_key=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/deployments/?q=name=${deploymentId}&fields=enm/private_key" | egrep -o "private_key.*?" | cut -d '"' -f3)
    echo -e $private_key > private_key.pem
	chmod 600 private_key.pem
    echo "Transferring pem file to EMP instance $emp_ip (/var/tmp/)"
    scp -i ./private_key.pem ./private_key.pem cloud-user@$emp_ip:/var/tmp/
    rm -- "private_key.pem"
}

retrieve_private_key