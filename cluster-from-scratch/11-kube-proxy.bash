#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-proxy
#
# At the end of this script you will have running Kube Controller Manager
#

echo "Creating kube-proxy certificates"

#
# Create kube-proxy certificate
#
export KUBE_PROXY_CSR_PATH=/tmp/kube-proxy.csr

## Private key
openssl genrsa -out "$KUBE_PROXY_KEY_PATH" 2048

## Certificate sign request
openssl req -new -key "$KUBE_PROXY_KEY_PATH" -out "$KUBE_PROXY_CSR_PATH" -subj "/CN=system:kube-proxy/O=system:node-proxier"

## Copy the request to the server (NOT THE PROPER WAY)
scp $KUBE_PROXY_CSR_PATH ubuntu@$CONTROLLER_PUBLIC_IP:/tmp/

# Execute this part on the controller node

export KUBE_PROXY_CSR_IN_PATH=/tmp/kube-proxy.csr
export KUBE_PROXY_CSR_CONF_IN_PATH=/tmp/kube-proxy_cert_config.conf
export KUBE_PROXY_CERT_OUT_PATH=/tmp/kube-proxy.crt

## Certificate
openssl x509 -req -in "$KUBE_PROXY_CSR_IN_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$KUBE_PROXY_CERT_OUT_PATH" -days 500 

#
# This part is to be executed again in the worker node
#
export KUBE_PROXY_CERT_OUT_PATH=/tmp/kube-proxy.crt

# Download the generated certificate (NOT THE PROPER WAY)
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBE_PROXY_CERT_OUT_PATH "$KUBE_PROXY_CERT_PATH"
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBERNETES_CA_CERT_PATH "$KUBERNETES_CA_CERT_PATH"

#
# Create kubeconfig for kube-proxy
#
kubectl config set-cluster k8s-training --certificate-authority=$KUBERNETES_CA_CERT_PATH --embed-certs=true --server=https://${CONTROLLER_PRIVATE_IP}:6443 --kubeconfig=${KUBE_PROXY_KUBECONFIG_PATH}
kubectl config set-credentials system:kube-proxy --client-certificate=$KUBE_PROXY_CERT_PATH --client-key=$KUBE_PROXY_KEY_PATH --embed-certs=true --kubeconfig=${KUBE_PROXY_KUBECONFIG_PATH}
kubectl config set-context default --cluster=k8s-training --user=system:kube-proxy --kubeconfig=${KUBE_PROXY_KUBECONFIG_PATH}
kubectl config use-context default --kubeconfig=${KUBE_PROXY_KUBECONFIG_PATH}

#
# Install kube-proxy
#

echo "Installing kube-proxy"

## Download
wget -q "$KUBE_PROXY_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kube-proxy"

## Create systemd service
cat << EOF | sudo tee "$KUBE_PROXY_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kube-proxy

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kube-proxy \\
  --kubeconfig=${KUBE_PROXY_KUBECONFIG_PATH} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy.service
systemctl restart kube-proxy.service

# Cleanup
rm /tmp/kube-proxy* -rf

