#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-dns
#
# At the end of this script you will have running Kube Controller Manager
#
export KUBE_DNS_WORKING_FOLDER=/tmp/kube-dns
mkdir -p $KUBE_DNS_WORKING_FOLDER

# Download source files

wget "https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/Makefile" -P $KUBE_DNS_WORKING_FOLDER

wget "https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/kube-dns.yaml.base" -P $KUBE_DNS_WORKING_FOLDER

wget "https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/coredns.yaml.base" -P $KUBE_DNS_WORKING_FOLDER

wget "https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/transforms2salt.sed" -P $KUBE_DNS_WORKING_FOLDER
wget "https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/transforms2sed.sed" -P $KUBE_DNS_WORKING_FOLDER

# Install required software

sudo apt install make

# Set the required environment variables

export DNS_SERVER_IP=$KUBE_DNS_SERVICE_IP
export DNS_DOMAIN=$CLUSTER_DOMAIN
export SERVICE_CLUSTER_IP_RANGE=$SERVIRE_CLUSTERIP_NET

# Generate the yaml

cd $KUBE_DNS_WORKING_FOLDER
make
envsubst < kube-dns.yaml.sed  > kube-dns.yaml

# Deploy the yaml

kubectl apply -f kube-dns.yaml