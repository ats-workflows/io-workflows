#!/bin/bash
 
echo 'Running Black Duck'
 
wget -O detect.sh https://detect.synopsys.com/detect.sh
 
chmod a+x detect.sh
 
./detect.sh --blackduck.url=${Blackduck_InstanceUrl} --blackduck.api.token=${Blackduck_AuthToken} --detect.project.name=${Blackduck_ProjectName}   --detect.project.version.name=${Blackduck_ProjectVersion}  --detect.force.success=true
