#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-proxy
#
# At the end of this script you will have running Kube Controller Manager
#

helm install stable/nginx-ingress --name nginx-ingress --set rbac.create=true --namespace kube-system --set controller.hostNetwork=true --set controller.kind=DaemonSet