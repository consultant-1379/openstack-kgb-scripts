#!/bin/bash
set +x
CURL=/usr/bin/curl
ECHO=/bin/echo
AWK=/usr/bin/awk
py=/usr/bin/python3

DIT_URL="https://atvdit.athtem.eei.ericsson.se"
CIPORTAL_URL="https://ci-portal.seli.wh.rnd.internal.ericsson.com"
EDP_AUTODEPLOY_IMAGE="armdocker.seli.gic.ericsson.se/proj-edp-autodeploy-dvms-dev"
OS_DEPLOYER_IMAGE="armdocker.seli.gic.ericsson.se/proj_nwci/enmdeployer"
EDP_CONTAINER_NAME="edp_auto_deploy"
DEPLOYER_REGEX='^[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}$'
echo "HOSTNAME=${HOSTNAME}"
project_id=""
PROJECT_NAME=""
ffe_excluded_params=""
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"
ffe_flag="false"

# EDP version support
EDP_ENM_UG_VERSION="1.1.1"
NEW_SIENM_II_VERSION="1.0.67"


# EDP Profiles
EDP_ENM_UG_PROFILES="core_openstack_software_preparation,vnflcm_upgrade,venm_pre_upgrade_phase2,venm_enm_software_upgrade"
EDP_SIENM_UG_PROFILES="core_openstack_software_preparation,venm_pre_upgrade_phase1,vnflcm_upgrade,venm_pre_upgrade_phase2,venm_enm_software_upgrade,venm_post_upgrade,venm_post_upgrade_cleanup"


function get_project_info_from_dit() {
    echo "[INFO] retrieving the deployments project name from DIT"
    project_id=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/deployments/?q=name=${deploymentId}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)[0]\nprint(str(result["project_id"]))')
    PROJECT_NAME=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/projects/${project_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["name"]))')
    echo "[INFO] deployment project name: ${PROJECT_NAME}"
}

function get_edp_version() {
    echo "[INFO] retrieving the EDP Auto Deploy version from the ENM product set: ${productSet}"
    edpVersion=$($py -c "from urllib.request import urlopen; from json import load; edp_version_info = [package for package in load(urlopen('${CIPORTAL_URL}/getProductSetVersionContents/?productSet=enm&version=${productSet}'))[0]['contents'] if 'ERICautodeploy_CXP9038326' in package['artifactName']]; print(edp_version_info[0]['version']) if edp_version_info else 0")
    echo "[INFO] ENM product set EDP Auto Deploy version: ${edpVersion}"

}

function download_deployer_version() {
	echo "Downloading deployer version ${deployerVersion}"
	deployerUpdateCommand="docker pull armdocker.rnd.ericsson.se/proj_nwci/enmdeployer:${deployerVersion}"
	echo ${deployerUpdateCommand}
	eval ${deployerUpdateCommand}
}

function retrieve_private_key() {
    echo "[INFO] Retrieving LAF IP and private key from DIT"
    get_laf_ip
    private_key=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/deployments?q=name=${deploymentId}&fields=enm/private_key" | egrep -o "private_key.*?" | cut -d '"' -f3)
    echo -e $private_key > private_key.pem
    chmod 600 $WORKSPACE/private_key.pem
    if [[ "${ffe_flag}" == 'true' ]]; then
        ssh-keygen -f "/home/lciadm100/.ssh/known_hosts" -R "$laf_ip"
        echo "[INFO] Copying private key to /var/tmp/private_key.pem"
        cp $WORKSPACE/private_key.pem /var/tmp/private_key.pem
    fi

    echo "Transferring pem file to LAF instance (/var/tmp)"
	scp -o StrictHostKeyChecking=no -i $WORKSPACE/private_key.pem $WORKSPACE/private_key.pem cloud-user@$laf_ip:/var/tmp
	echo "Pem file transfer successful."
    ssh -i $WORKSPACE/private_key.pem cloud-user@$laf_ip 'scp -o StrictHostKeyChecking=no -i /var/tmp/private_key.pem /var/tmp/private_key.pem cloud-user@emp:/var/tmp'
	#rm -- "private_key.pem"
}

function get_laf_ip() {
vnflcm_sed_id=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/deployments/?q=name=${deploymentId}&fields=documents" | egrep -o "vnflcm.*?"| awk -F"\"" '{print $5}')
if [[ ${vnflcm_sed_id} == "vnflcm" || ${vnflcm_sed_id} == "other" ]]
    then
        vnflcm_sed_id=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/deployments/?q=name=${deploymentId}&fields=documents" | egrep -o "document_id.*?" | cut -d '"' -f3)
fi
laf_services_count=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["content"]["parameters"]["services_vm_count"]))')
laf_db_count=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["content"]["parameters"]["db_vm_count"]))')

if [ ${laf_services_count} == "1" ] && [ ${laf_db_count} == "1" ]
    then
        external_ipv4_for_services_vm=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["content"]["parameters"]["external_ipv4_for_services_vm"]))')
        if [[ ${external_ipv4_for_services_vm} == *","* ]]
            then
                laf_ip=${external_ipv4_for_services_vm%,*}
            else
                laf_ip=${external_ipv4_for_services_vm}
        fi
    else
        vnflcm_sed=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}")
        if [[ ${vnflcm_sed} == *"external_ipv4_vip_for_services"* ]]
            then
            laf_ip=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["content"]["parameters"]["external_ipv4_vip_for_services"]))')
            else
            laf_ip=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/documents/${vnflcm_sed_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["content"]["parameters"]["external_ipv4_for_services_vm"]))')
        fi
fi
}

function check_if_project_is_ffe() {
    get_project_info_from_dit
    echo "[INFO] Checking if project is FFE: ${PROJECT_NAME}"
    network_name=$(curl --header 'Accept: application/json' --user ${dit_username}:${dit_password} -X GET -ks "${DIT_URL}/api/projects/${project_id}" | $py -c $'import sys, json\nresult=json.load(sys.stdin)\nprint(str(result["network"]["name"]))')
    if [[ "$network_name" == "${deploymentId}_northbound" ]]; then
      echo "[INFO] Adding excluded parameters"
      ffe_excluded_params="--exclude-server ${deploymentId}_gateway,${deploymentId}_netsim,${deploymentId}_seleniumhub,${deploymentId}_tafex,${deploymentId}_wlvm --exclude-volume ${deploymentId}_gateway_docker_volume,${deploymentId}_gateway_root_volume,${deploymentId}_tafex_home_volume,${deploymentId}_tafex_root_volume,${deploymentId}_seleniumhub_root_volume,${deploymentId}_netsim_root_volume,${deploymentId}_wlvm_root_volume --exclude-network ${deploymentId}_northbound"
      ffe_flag="true"
    fi
}

function is_edp_supported_version() {
    edpSupportedVersion=$1
    echo "[INFO] compare ENM product set EDP version: ${edpVersion} against EDP supported feature version: ${edpSupportedVersion}" >&2
    isEdpSupportedVersion=$($py -c "from packaging import version; print(version.parse(\"${edpVersion}\") >= version.parse(\"${edpSupportedVersion}\"))")
    echo ${isEdpSupportedVersion}
}

function stop_running_containers() {
    echo "[INFO] stop any running containers"
    imageList=$(docker ps --all --format "{{.Image}}")
    for imageName in $imageList
    do
      if [[ "${imageName}" == *"proj-edp-autodeploy-dvms-dev"* ||  "${imageName}" == *"enmdeployer"* ]]; then
        docker stop $(docker ps --all --quiet --filter "ancestor=${imageName}")
      fi
    done
    stoppedContainers=$(docker ps --all --quiet --filter "status=exited")
    if [ "${stoppedContainers}" ]; then
      echo "[INFO] remove containers with status: exited"
      docker rm --force "${stoppedContainers}"
    fi
}

function remove_docker_images() {
    imageName=$1
    imageIdList=$(docker images --quiet --filter "reference=${imageName}")
    echo "[INFO] list ${imageName} image ids : ${images}"
    imageCounter=0
    imageRetention=1
    for imageId in ${imageIdList}
    do
      if [ "${imageCounter}" -ge "${imageRetention}" ]; then
        echo "[INFO] removing image: $(docker image inspect ${imageId} --format='{{.RepoTags}}')"
        docker image rm --force ${imageId} || true
      fi
      imageCounter=$((imageCounter+1))
    done
}

function remove_docker_volumes () {
    echo "[INFO] list pre-existing docker volumes"
    dockerVolumeList=$(docker volume ls -q)
    echo "${dockerVolumeList}"
    if [[ ${dockerVolumeList}  == *"media-volume"* ]]; then
        echo "[INFO] delete docker volume named: media-volume"
        docker volume rm --force media-volume
    fi
    if [[ ${dockerVolumeList}  == *"config-volume"* ]]; then
        echo "[INFO] delete docker volume named: config-volume"
        docker volume rm --force config-volume
    fi
    if [[ ${dockerVolumeList}  == *"logs-volume"* ]]; then
        echo "[INFO] delete docker volume named: logs-volume"
        docker volume rm --force logs-volume
    fi
    echo "[INFO] list volumes post delete:"
    echo $(docker volume ls -q)
}

function create_docker_volumes() {
    for volume in media-volume config-volume logs-volume; do
        echo "[INFO] create docker volume named: ${volume}"
        docker volume create ${volume}
        if [[ $? -ne 0 ]]; then
            "[ERROR] docker volume: ${volume} failed to create. Please troubleshoot."
            exit 1
        fi
    done
}

function run_deployer_command() {
    command=$1
    docker_volumes=$2
    runCommand="docker run ${docker_volumes} --rm ${OS_DEPLOYER_IMAGE}:${deployerVersion} ${command} --debug"
    echo "${runCommand}"
    eval ${runCommand} || exit 1

}

function retrieve_utility_content_for_edp() {
    remove_docker_volumes
    create_docker_volumes
    echo "[INFO] run openstack auto deployer ci edp venm command"
    docker_volumes="-v media-volume:/artifacts/ -v config-volume:/config/"
    command="ci edp venm --deployment-name ${deploymentId} --product-set ${productDrop}::${productSet} ${deployPackagePopulated}"
    run_deployer_command "${command}" "${docker_volumes}"

}

function get_edp_logs () {
    echo "[INFO] copy logs from docker volumes to /edp_logs/"
    sudo cp -R /docker/volumes/config-volume/_data/ ./edp_logs
    sudo cp -R /docker/volumes/logs-volume/_data/ ./edp_logs
    echo "[INFO] change /edp_logs/ owner and user group: ${USER}:${USER}"
    sudo chown ${USER}:${USER} -R ./edp_logs/
    echo "[INFO] list contents of /edp_logs/:"
    echo $(ls ./edp_logs)
}

function run_edp_autodeploy() {
    profiles=$1
    get_project_info_from_dit
    set +e
    echo "[INFO] start EDP auto deploy container in detached mode"
    startEdpContainer="docker run -t -d --name ${EDP_CONTAINER_NAME} --privileged \
                      --entrypoint /bin/bash \
                      -v media-volume:/vol1/ENM/artifacts/ \
                      -v config-volume:/vol1/senm/etc/ \
                      -v logs-volume:/vol1/senm/log/ \
                      --rm ${EDP_AUTODEPLOY_IMAGE}:${edpVersion}"

    echo ${startEdpContainer}
    eval ${startEdpContainer} || exit 1
    echo "[INFO] EDP auto deploy container started successfully."

    echo "[INFO] check if EDP pre-release test packages need to be installed."
    testEdpPackages=$(docker exec -t ${EDP_CONTAINER_NAME} find /vol1/ENM/artifacts/ci_edp_packages/ -type f | tr -d '\r')
    echo "${testEdpPackages}"
    if [[ ${testEdpPackages} == *"ERIC"* ]]; then
        echo "[INFO] the following EDP packages will be installed in the running EDP Auto Deploy container: ${testEdpPackages}"
        for package in ${testEdpPackages}; do
           installEdpPackage=$(docker exec -t ${EDP_CONTAINER_NAME} rpm -Uvh --force ${package})
           echo "${installEdpPackage}"
        done
        echo "[INFO] EDP packages installation is complete."
        echo "[INFO] list installed ERIC* packages"
        packageCheck=$(docker exec -t ${EDP_CONTAINER_NAME} rpm -qa ERIC*)
        echo "${packageCheck}"
    else
        echo "[INFO] No EDP test packages required to be installed."
    fi

    runEdpProfiles="docker exec -t ${EDP_CONTAINER_NAME} /opt/ericsson/edpcore/bin/edp_autodeploy.sh -y -d -e /vol1/senm/etc/sed.json \
                   -m /vol1/senm/etc/lcm_sed.json \
                   -k /vol1/senm/etc/key_pair_${PROJECT_NAME}.pem \
                   -O /vol1/senm/etc/${PROJECT_NAME}_project.rc \
                   -p ${profiles}"

    echo ${runEdpProfiles}
    eval ${runEdpProfiles}
    return_code=$?

    get_edp_logs
    echo "[INFO] delete EDP auto deploy container"
    docker rm --force ${EDP_CONTAINER_NAME}

    if [ $return_code -ne 0 ]; then
        exit -1
    fi
}

stop_running_containers
remove_docker_images "armdocker.*/proj_nwci/enmdeployer"
remove_docker_images "armdocker.*/proj-edp-autodeploy-dvms-dev"

if [ -z "${productSet}" ]
    then
    	echo "[INFO] product set not defined, retrieve product set version with set confidence level for Deploy-vENM-II"
        productSet=$(${CURL} -L "${CIPORTAL_URL}/getLastGoodProductSetVersion/?productSet=ENM&confidenceLevel=Deploy-vENM-II")
        productDrop=$(${ECHO} ${productSet} | ${AWK} -F'.' '{ print $1"."$2 }' )
        echo "productDrop=${productDrop}" >> "${WORKSPACE}"/build.properties
	echo "productSet=${productSet}" >> "${WORKSPACE}"/build.properties
        productSetPopulated="--product-set ${productDrop}::${productSet}"
    else
    	productDrop=$(${ECHO} ${productSet} | ${AWK} -F'.' '{ print $1"."$2 }' )
	echo "productDrop=${productDrop}" >> "${WORKSPACE}"/build.properties
	echo "productSet=${productSet}" >> "${WORKSPACE}"/build.properties
	productSetPopulated="--product-set ${productDrop}::${productSet}"
fi

if [ -z "${deployerVersion}" ]
    then
    	deployerVersion=$(curl -L -s "${CIPORTAL_URL}/api/deployment/deploymentutilities/productSet/ENM/version/${productSet}/" | egrep -o "deployerVersion.*?" | cut -d '"' -f3)
	echo "Deployer Version=${deployerVersion}"
    	download_deployer_version ${deployerVersion}

	elif [[ "${deployerVersion}" =~ ${DEPLOYER_REGEX} ]]
	then
    	echo "This job will use the deployer version ${deployerVersion} that has been passed into the job as a build parameter. This should only be used when the deployer version mapped to a product set is not functioning correctly."
    	download_deployer_version ${deployerVersion}
	else
    	echo "Incorrect deployer Version entered into the job"
    	exit 1
fi

if [ -z "${deployPackage}" ]
    then
        deployPackagePopulated=''
    else
        deployPackagePopulated="--rpm-versions ${deployPackage}"
fi

if [ -z "${deployMedia}" ]
    then
        deployMediaPopulated=''
    else
        deployMediaPopulated="--media-versions ${deployMedia}"
fi

if [ -z "${vioNicType}" ]
    then
        vioNicTypePopulated=''
    else
        vioNicTypePopulated="--vio-nic-type ${vioNicType}"
fi

if [ -z "${imagePostfix}" ]
    then
        imagePostfixPopulated=""
    else
        imagePostfixPopulated="--image-name-postfix ${imagePostfix}"
fi

if [ -z "${snapshotTag}" ]
    then
	snapshotTagPopulated="--snapshot-tag snapshot_${deploymentId}"
    else
	snapshotTagPopulated="--snapshot-tag ${snapshotTag}"
fi

if [ "${enterEDPVersion}" == "No" ]
    then
        get_edp_version
    else
        edpVersion=${edpVersion}
        edpVersion="${edpVersion//,}"
        echo "[INFO] EDP auto deploy version: ${edpVersion} specified by user in job build parameter"
fi

if [[ "${jobType}"  == 'install' ]]
    then
        check_if_project_is_ffe
        run_deployer_command "ci enm stacks delete --deployment-name ${deploymentId} ${ffe_excluded_params}"
        run_deployer_command "ci enm rollout --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${imagePostfixPopulated} ${ffe_excluded_params}"
        retrieve_private_key
    elif [[ "${jobType}"  == 'upgrade' ]]
    then
        check_if_project_is_ffe
        EDP_ENM_UG_SUPPORTED=$(is_edp_supported_version "${EDP_ENM_UG_VERSION}")
        if [ "${EDP_ENM_UG_SUPPORTED}" == True ]; then
            retrieve_utility_content_for_edp
            echo "[INFO] run vENM upgrade using EDP auto deploy"
            if [ "${enterProfiles}" == "No" ]; then
                echo "[INFO] the following default EDP vENM upgrade profiles will be used:"
                profiles="${EDP_ENM_UG_PROFILES}"
                echo ${profiles}
            else
                echo "[INFO] the following user specified EDP profiles in the job build parameters will be used:"
                profiles=${profiles}
                echo ${profiles}
            fi
            run_edp_autodeploy "${profiles}"
        else
            echo "[INFO] run non-EDP vENM upgrade as the EDP version: ${edpVersion} does not have the required support, minimium supporting EDP version is: ${EDP_ENM_UG_VERSION}"
            run_deployer_command "ci enm upgrade --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${imagePostfixPopulated}"
        fi
        retrieve_private_key
    elif [[ "${jobType}"  == 'enm_snapshot' ]]
    then
        run_deployer_command "ci enm snapshot deployment --deployment-name ${deploymentId} ${productSetPopulated} ${snapshotTagPopulated}"
    elif [[ "${jobType}"  == 'enm_rollback' ]]
    then
        run_deployer_command "ci enm rollback deployment --deployment-name ${deploymentId} ${productSetPopulated} ${snapshotTagPopulated}"
    elif [[ "${jobType}"  == 'deploy_dvms' ]]
    then
        run_deployer_command "ci vio dvms deploy --deployment-name ${deploymentId} ${productSetPopulated}"
    elif [[ "${jobType}"  == 'vio platform install' ]]
    then
        profiles="phase1,phase2"
        NEW_SIENM_II_SUPPORTED=$(is_edp_supported_version "${NEW_SIENM_II_VERSION}")
        if [ "${NEW_SIENM_II_SUPPORTED}" == True ]; then
            profiles="sienm_phase1,sienm_phase2"
        fi

        if [ "${enterProfiles}" == "Yes" ]; then
            echo "[INFO] the following user specified EDP profiles in the job build parameters will be used:"
            profiles=${profiles}
        fi
        echo "${profiles}"
        run_deployer_command "ci vio platform install --deployment-name ${deploymentId} ${productSetPopulated} --vio-profile-list ${profiles} ${deployPackagePopulated} ${deployMediaPopulated} ${vioNicTypePopulated}"
    elif [[ "${jobType}"  == 'vio platform post-install' ]]
    then
        run_deployer_command "ci vio platform post install --deployment-name ${deploymentId} ${productSetPopulated}"
    elif [[ "${jobType}"  == 'vio platform upgrade' ]]
    then
        run_deployer_command "ci vio platform upgrade --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${deployMediaPopulated}"
    elif [[ "${jobType}"  == 'vio platform post upgrade' ]]
    then
        run_deployer_command "ci vio platform post upgrade --deployment-name ${deploymentId} ${productSetPopulated}"
    elif [[ "${jobType}"  == 'Full SIENM Install' ]]
    then
        profiles="phase1,phase2"
        NEW_SIENM_II_SUPPORTED=$(is_edp_supported_version "${NEW_SIENM_II_VERSION}")
        if [ "${NEW_SIENM_II_SUPPORTED}" == True ]; then
            profiles="sienm_phase1,sienm_phase2"
        fi

        if [ "${enterProfiles}" == "Yes" ]; then
            echo "[INFO] the following user specified EDP profiles in the job build parameters will be used:"
            profiles=${profiles}
        fi
        echo ${profiles}
        run_deployer_command "ci vio platform install --deployment-name ${deploymentId} ${productSetPopulated} --vio-profile-list ${profiles} ${deployPackagePopulated} ${deployMediaPopulated} ${vioNicTypePopulated}"
        run_deployer_command "ci enm rollout --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${imagePostfixPopulated}"
        run_deployer_command "ci vio platform post install --deployment-name ${deploymentId} ${productSetPopulated}"
    elif [[ ${jobType} == 'Full SIENM Upgrade' ]]
    then
        run_deployer_command "ci vio platform upgrade --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${deployMediaPopulated}"
        if [ "${enterProfiles}" == "Yes" ]; then
            echo "[INFO] the following user specified EDP profiles in the job build parameters will be used:"
            profiles=${profiles}
            echo ${profiles}
        else
            profiles="${EDP_SIENM_UG_PROFILES}"
        fi

        EDP_ENM_UG_SUPPORTED=$(is_edp_supported_version "${EDP_ENM_UG_VERSION}")
        if [ "${EDP_ENM_UG_SUPPORTED}" == True ]; then
            echo "[INFO] run upgrade using EDP auto deploy"
            retrieve_utility_content_for_edp
            run_edp_autodeploy "${profiles}"
        else
            echo "[INFO] run non-EDP vENM upgrade as the EDP version: ${edpVersion} does not have the required support, minimium supporting EDP version is: ${EDP_ENM_UG_VERSION}"
            run_deployer_command "ci enm upgrade --deployment-name ${deploymentId} ${productSetPopulated} ${deployPackagePopulated} ${imagePostfixPopulated}"
        fi
        retrieve_private_key
        run_deployer_command "ci vio platform post upgrade --deployment-name ${deploymentId} ${productSetPopulated}"
    elif [[ ${jobType} == 'EDP autodeploy' ]]
    then
        if [ "${enterProfiles}" == "No" ]; then
            echo "[ERROR] No EDP profiles defined...user must specify the required EDP profiles to be run as a job build parameters."
            exit 1
        else
            profiles=${profiles}
            echo ${profiles}
        fi
        retrieve_utility_content_for_edp
        run_edp_autodeploy "${profiles}"
    elif [[ ${jobType} == 'teardown' ]]
    then
        check_if_project_is_ffe
        run_deployer_command "ci enm stacks delete --deployment-name ${deploymentId} ${ffe_excluded_params}"
    else
        echo "No job type matching: ${jobType} found"
fi
