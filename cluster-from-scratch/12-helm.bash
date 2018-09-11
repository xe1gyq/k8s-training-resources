#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-proxy
#
# At the end of this script you will have running Kube Controller Manager
#

echo "Creating Helm service account"

export TILLER_SA_YAML_PATH=/tmp/tiller-sa.yaml

cat << EOF | tee $TILLER_SA_YAML_PATH
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller-sa
  namespace: kube-system
EOF

kubectl apply -f $TILLER_SA_YAML_PATH

export TILLER_CLUSTERROLEBINDING_PATH=/tmp/tiller-clusterrolebinding.yaml

cat << EOF | tee $TILLER_CLUSTERROLEBINDING_PATH
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-rolebinding
subjects:
- kind: ServiceAccount
  name: tiller-sa # Name is case sensitive
  apiGroup: ""
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f $TILLER_CLUSTERROLEBINDING_PATH

helm init --upgrade --service-account tiller-sa