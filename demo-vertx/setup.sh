#!/bin/bash
# JBoss, Home of Professional Open Source
# Copyright 2016, Red Hat, Inc. and/or its affiliates, and individual
# contributors by the @authors tag. See the copyright.txt in the 
# distribution for a full listing of individual contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,  
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#Opening Openshift console
open https://$OPENSHIFT_IP:8443
echo "Log as developer/developer"

#Login and prepare the project
oc login --insecure-skip-tls-verify=true -u developer -p developer $OPENSHIFT_IP:8443
oc new-project deploy-master || oc project deploy-master

#Create a pipeline
echo "Creating a pipeline"
oc create -f pipeline.yml


#Build the project locally
mvn package

#Create the application GREEN
oc new-build --binary --name=demo
oc start-build demo --from-dir=. --follow
oc new-app demo -e OPENSHIFT_KUBE_PING_NAMESPACE=$(oc project -q) -e OPENSHIFT_KUBE_PING_LABELS="demo=deploy-master" -l demo=deploy-master
oc set probe dc/demo --readiness --get-url=http://:8080/api/health

#Create the application BLUE
oc new-build --binary --name=demo-blue
oc start-build demo-blue --from-dir=. --follow
oc new-app demo-blue -e OPENSHIFT_KUBE_PING_NAMESPACE=$(oc project -q)  -e OPENSHIFT_KUBE_PING_LABELS="demo=deploy-master" -l demo=deploy-master

#Expose the route GREEN
oc expose svc demo --hostname=demo.$OPENSHIFT_IP.nip.io 

#Enable readiness probe GREEN
oc set probe dc/demo --readiness --get-url=http://:8080/api/health
#Enable readiness probe GREEN
oc set probe dc/demo-blue --readiness --get-url=http://:8080/api/health

#Scale GREEN application
oc scale dc/demo --replicas=3

#Setup Jenkins credentials
oc login -u system:admin
oc new-project deploy-master-dev
oc policy add-role-to-user admin developer -n deploy-master-dev
oc new-project deploy-master-qa
oc policy add-role-to-user admin developer -n deploy-master-qa
echo "Giving Jenkins SA a cluster-admin permission"
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:deploy-master:jenkins -n deploy-master
oc login -u developer -p developer

#Return to PROD project
oc project deploy-master

#Start the pipeline
oc start-build deploy-master-pipeline

#Setup for infinispan
oc policy add-role-to-user view system:serviceaccount:deploy-master:default -n deploy-master

