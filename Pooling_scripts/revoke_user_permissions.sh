#!/bin/bash

# Define vars
declare -a arrPermissions=("Configure" "Read" "Discover" "Build" "Workspace" "Cancel")
JENKINS_URL="-eiffel004.lmera.ericsson.se:8443/jenkins/"
LIST=($SIGNUM)
echo $LIST
IFS=',' read -ra SIGNUMS <<< "$LIST"

for i in "${SIGNUMS[@]}"; do
    echo $i
done

########### Functions ###########
#get all permission for all signums
function getAllListPermission(){
    for sig in ${LIST[@]};
    do
        printf $(getStringPermission $sig)
    done
}
#get permission for signum
function getStringPermission(){
    for i in "${arrPermissions[@]}"
    do
       printf "<permission>hudson.model.Item.$i:$sig</permission>\r"
    done
}

#refresh configuration job
function printJob(){
    echo https://${JENKINS}-eiffel004.lmera.ericsson.se:8443/jenkins/job/$1
}

function manipulatePermissions(){
j=$1

for sig in ${SIGNUMS[@]};
    do
    configFile=$(java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} get-job $j | grep -v 'Skipping HTTP')
    if  [[ $configFile == *":$sig</permission>"* ]]
    then
        echo "signum $sig already exist"
        echo "$configFile" | sed "/:$sig<\/permission>/d" | xmllint --format - | java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} update-job $j;  
        echo "Revoked right permission for signum:$sig"
    else
        continue
    fi
    done
printJob $j

}


# main code
IFS=$'\n'
for j in $(java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} list-jobs All | grep "${JOB_NAME}\$");
do
    echo "Processing job $j";

    manipulatePermissions $j;

done