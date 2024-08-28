set +x
echo ${JOB_NAME}

#!/bin/bash

# Define vars
declare -a arrPermissions=("Read" "Discover" "Build" "Workspace" "Cancel")
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
    for sig in ${SIGNUMS[@]};
    do
    	#echo "getAllListPermission"
        #echo $sig
        printf $(getStringPermission $sig)
    done
}
#get permission for signum
function getStringPermission(){
    #echo "getStringPermission"
    #echo $sig
    sig=${1,,}
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

configFile=$(java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} get-job $j | grep -v 'Skipping HTTP')

if  [[ $configFile == *"hudson.security.AuthorizationMatrixProperty"* ]];then
    #found enable security options

    if  [[ $configFile == *"<hudson.security.AuthorizationMatrixProperty/>"* ]];then
        #echo "Enable project-based security without users"
        STR_TEMP="<hudson.security.AuthorizationMatrixProperty>\r"$(getAllListPermission)"</hudson.security.AuthorizationMatrixProperty>"
		
        STR_TEMP=$(echo "$STR_TEMP" | sed 's/\//\\\/\\/g')

        echo "$configFile" | sed "s/<hudson.security.AuthorizationMatrixProperty\/>/$STR_TEMP/g" | xmllint --format - | java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} update-job $j;

        printJob $j
    else
        for sig in ${SIGNUMS[@]};
        do
            if  [[ $configFile == *":$sig</permission>"* ]]
            then
                echo "signum $sig already exist"
            else
                STR_PERMIS=$(getStringPermission $sig)
				echo ${STR_PERMIS}
                TT="</hudson.security.AuthorizationMatrixProperty>"
                TT=$(echo "$TT" | sed 's/\//\\\/\\/g')
                STR_PERMIS=$(echo "$STR_PERMIS" | sed 's/\//\\\/\\/g')

                echo "Added right permission for signum:$sig"
				echo $j
                echo "$configFile" | sed "s/$TT/$STR_PERMIS$TT/g" | xmllint --format - | java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} update-job $j;

                configFile=$(java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} get-job $j | grep -v 'Skipping ')

            fi
        done
        printJob $j
    fi

else
    #echo "Enable project-based security is disable"
    STR_TEMP="<hudson.security.AuthorizationMatrixProperty>"$(getAllListPermission)"</hudson.security.AuthorizationMatrixProperty>"

    STR_TEMP=$(echo "$STR_TEMP" | sed 's/\//\\\/\\/g')

    echo "$configFile" | sed "s/<properties>/<properties>$STR_TEMP/g" | xmllint --format - | java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} update-job $j;

    printJob $j
fi

}


# main code
IFS=$'\n'
for j in $(java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://${JENKINS}${JENKINS_URL} list-jobs All | grep "${JOB_NAME}\$");
do
    echo "Processing job $j";

    manipulatePermissions $j;

done
