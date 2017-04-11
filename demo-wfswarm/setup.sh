#!/bin/bash
#Opening Openshift console
open https://$OPENSHIFT_IP:8443
echo "Log as developer/developer"

#Login and prepare the project
oc login --insecure-skip-tls-verify=true -u developer -p developer $OPENSHIFT_IP:8443
oc new-project deploy-master


#Download xPaaS ImageStream
oc create -f https://raw.githubusercontent.com/wildfly-swarm/sti-wildflyswarm/master/1.0/wildflyswarm-sti-all.json
echo "Waiting 5 seconds...."
sleep 5
oc logs -f bc/wildflyswarm-10-centos7-build

#Create the application GREEN
oc new-app --name demo -e SWARM_JVM_ARGS=-Xmx512m wildflyswarm-10-centos7~https://github.com/redhat-developer-demos/the-deploy-master --context-dir=/demo-wfswarm
#Create the application BLUE
oc new-app --name demo-blue -e SWARM_JVM_ARGS=-Xmx512m wildflyswarm-10-centos7~https://github.com/redhat-developer-demos/the-deploy-master --context-dir=/demo-wfswarm

#Expose the route GREEN
oc expose svc demo --hostname=demo.$OPENSHIFT_IP.nip.io 

#Enable incremental builds GREEN
oc patch bc/demo -p '{"spec":{"strategy":{"type":"Source","sourceStrategy":{"incremental":true}}}}'
#Enable incremental builds BLUE
oc patch bc/demo-blue -p '{"spec":{"strategy":{"type":"Source","sourceStrategy":{"incremental":true}}}}'

#Enable readiness probe GREEN
oc set probe dc/demo --readiness --get-url=http://:8080/api/health
#Enable readiness probe BLUE
oc set probe dc/demo-blue --readiness --get-url=http://:8080/api/health

#Scale GREEN application
oc scale dc/demo --replicas=3

echo "Wait until the builds complete... They should take approximately 20 minutes for the first run"
oc logs bc/demo --follow
oc logs bc/demo-blue --follow
