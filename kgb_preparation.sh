#!/bin/bash

WGET='/usr/bin/wget'
MKDIR='/bin/mkdir'
RM='/bin/rm'
RPM2CPIO='/usr/bin/rpm2cpio'
CPIO='/bin/cpio'
CD='cd'
SOURCE='source'
DEV_NULL='> /dev/null 2>&1'
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"

TEMP_DIR='/var/tmp'
WORK_SPACE="${TEMP_DIR}/$$"
CLOUD_TEMPLATE_RPM='ERICenmcloudtemplates_CXP9033639.rpm'
THE_LATEST_CLOUD_TEMPLATES_RPM_DOWNLOAD_URL='https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/service/local/artifact/maven/redirect?r=releases&g=com.ericsson.oss.itpf.deployment&a=ERICenmcloudtemplates_CXP9033639&p=rpm&v=RELEASE'
OPENSTACK_CREDS_FILE="${TEMP_DIR}/os_creds.sh"
OPENSTACK_TENANT_NAME=${1}
OPENSTACK_PROJECT_NAME=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/?q=name=${OPENSTACK_TENANT_NAME}&fields=content(parameters(cloudManagerTenantName))" | awk -F '":' '{print $4}' | sed "s/\"//g" | sed "s/}//g" | sed "s/]//g")
OPENSTACK_USERNAME=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/?q=name=${OPENSTACK_TENANT_NAME}&fields=content(parameters(cloudManagerUserName))" | awk -F '":' '{print $4}' | sed "s/\"//g" | sed "s/}//g" | sed "s/]//g")
OPENSTACK_PASSWORD=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/?q=name=${OPENSTACK_TENANT_NAME}&fields=content(parameters(cloudManagerUserPassword))" | awk -F '":' '{print $4}' | sed "s/\"//g" | sed "s/}//g" | sed "s/]//g")
OPENSTACK_AUTH_URL=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "https://atvdit.athtem.eei.ericsson.se/api/documents/?q=name=${OPENSTACK_TENANT_NAME}&fields=content(parameters(cloudManagerRestInterfaceBaseURL))" | awk -F '":' '{print $4}' | sed "s/\"//g" | sed "s/}//g" | sed "s/]//g")
OPENSTACK_STACK_CREATE_COMMAND='openstack stack create'
LOCATION_OF_SED="http://atvts3267.athtem.eei.ericsson.se/seds/SED_${OPENSTACK_TENANT_NAME}.yaml"
CLOUD_TEMPLATES_LOCATION="${WORK_SPACE}/opt/ericsson/ERICenmcloudtemplates_CXP9033639"
SECURITY_GROUP_STACK_YAML="${CLOUD_TEMPLATES_LOCATION}/infrastructure_resources/network_security_group_stack.yaml"
SECURITY_GROUP_STACK_NAME="security_group_stack_bs_${OPENSTACK_PROJECT_NAME}"
INTERNAL_DUAL_NETWORK_STACK_YAML="${CLOUD_TEMPLATES_LOCATION}/infrastructure_resources/network_internal_dual_stack.yaml"
INTERNAL_DUAL_NETWORK_STACK_NAME="internal_network_stack_bs_${OPENSTACK_PROJECT_NAME}"

function create_a_temp_work_space {
	${MKDIR} ${WORK_SPACE}
}

function download_the_latest_cloud_template_rpm {
	echo 'Downloading the latest cloud template rpm from nexus'
	${WGET} -q ${THE_LATEST_CLOUD_TEMPLATES_RPM_DOWNLOAD_URL} -O ${WORK_SPACE}/${CLOUD_TEMPLATE_RPM}
}

function extract_the_content_of_the_latest_cloud_template_rpm {
	echo 'Extracting the content of the latest cloud template rpm'
	${CD} ${WORK_SPACE}
	${RPM2CPIO} ${WORK_SPACE}/${CLOUD_TEMPLATE_RPM} | ${CPIO} -idmv ${DEV_NULL}
	${CD} -
}

function create_an_openstack_credentials_source_file {
	echo 'Creating an openstack credentials source file'
	echo "export OS_PROJECT_NAME=\""${OPENSTACK_PROJECT_NAME}\""" > ${OPENSTACK_CREDS_FILE}
	echo "export OS_USERNAME=\""${OPENSTACK_USERNAME}\""" >> ${OPENSTACK_CREDS_FILE}
	echo "export OS_PASSWORD=\""${OPENSTACK_PASSWORD}\""" >> ${OPENSTACK_CREDS_FILE}
	echo "export OS_AUTH_URL=\""${OPENSTACK_AUTH_URL}\""" >> ${OPENSTACK_CREDS_FILE}
	${SOURCE} ${OPENSTACK_CREDS_FILE}
}

function create_security_stack {
	echo 'Creating a security stack'
	echo "${OPENSTACK_STACK_CREATE_COMMAND} -e ${LOCATION_OF_SED} -t ${SECURITY_GROUP_STACK_YAML} ${SECURITY_GROUP_STACK_NAME}" 
	${OPENSTACK_STACK_CREATE_COMMAND} -e ${LOCATION_OF_SED} -t ${SECURITY_GROUP_STACK_YAML} ${SECURITY_GROUP_STACK_NAME}
}

function create_internal_network_stack {
	echo 'Creating an internal network stack'
	echo "${OPENSTACK_STACK_CREATE_COMMAND} -e ${LOCATION_OF_SED} -t ${INTERNAL_DUAL_NETWORK_STACK_YAML} ${INTERNAL_DUAL_NETWORK_STACK_NAME}"
	${OPENSTACK_STACK_CREATE_COMMAND} -e ${LOCATION_OF_SED} -t ${INTERNAL_DUAL_NETWORK_STACK_YAML} ${INTERNAL_DUAL_NETWORK_STACK_NAME}
}

function delete_temp_work_space {
	echo 'Deleting temp work space'
	${RM} -rf ${TEMP_DIR}/$$
}


create_a_temp_work_space
download_the_latest_cloud_template_rpm
extract_the_content_of_the_latest_cloud_template_rpm
create_an_openstack_credentials_source_file
#create_security_stack
#create_internal_network_stack
delete_temp_work_space

