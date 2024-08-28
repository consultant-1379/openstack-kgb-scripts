#!/bin/bash

#booking_jobs=("Testing_Master_Booking_Job1" "Testing_Master_Booking_Job2" "Testing_Master_Booking_Job3" "Testing_Master_Booking_Job4")
booking_jobs=("StackCentric_C6A04_Booking")
flag=true

while( $flag == "true" )
do
    for job in "${booking_jobs[@]}"
    do
        echo $job
        job_booked=$(curl -s "https://fem139-eiffel004.lmera.ericsson.se:8443/jenkins/job/$job/lastBuild/api/json" | egrep -o "building.*?" | cut -d ',' -f1 | cut -d ':' -f2)
        echo "job=${job}" >> build.properties
    
        if [ $job_booked == "false" ]
        then
            echo "job is not currently booked"
            java -jar /proj/ciexadm200/tools/jcli/jenkins-cli.jar -noCertificateCheck -s https://fem139-eiffel004.lmera.ericsson.se:8443/jenkins/ build $job -p users=$users -p team_name=$team_name -p length_of_booking=$length_of_booking 
            flag=false
            chosen_install_job_name=${job%_*}
            echo "chosen_install_job_name=$chosen_install_job_name" >> build.properties
            exit 0
        else
        	echo "job is booked, checking other deployments"
            continue
    	fi
    done
    echo "Sleeing 10 seconds and will check booking deployments again"
    sleep 10s
done