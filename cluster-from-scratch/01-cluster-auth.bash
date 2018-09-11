#!/bin/bash

source ./common.bash

#
# Cluster CA creation scripts, using OpenSSL
#
# At the end of this script, you will have a Cluster Certificate Authority 
# to create certificates for the rest of the components
#
#       - ca.crt (CA Certificate)
#       - ca.key (CA private key)
#

echo "Creating Cluster Authority"

# Create folder for storing keys, we will use /etc/kubernetes/pki (based on examples like Kubeadm)

mkdir -p "$KUBERNETES_CERT_DIR"

# Create CA key
openssl genrsa -out "$KUBERNETES_CA_KEY_PATH" 2048

# Create CA certificate
openssl req -x509 -new -nodes -key "$KUBERNETES_CA_KEY_PATH" -days 10000 -out "$KUBERNETES_CA_CERT_PATH" -subj "/CN=Kubernetes/O=Kubernetes"  

echo "End of Cluster Auth step"

