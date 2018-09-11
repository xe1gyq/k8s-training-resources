#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-scheduler
#
# At the end of this script you will have running Kube Controller Manager
#

echo "Creating kube-scheduler certificates"

#
# Create kube-scheduler certificate
#
export KUBE_SCHEDULER_CSR_PATH=/tmp/kube-scheduler_server.csr

## Private key
openssl genrsa -out "$KUBE_SCHEDULER_KEY_PATH" 2048

## Certificate sign request
openssl req -new -key "$KUBE_SCHEDULER_KEY_PATH" -out "$KUBE_SCHEDULER_CSR_PATH" -subj "/CN=system:kube-scheduler/O=system:kube-scheduler"


## Certificate
openssl x509 -req -in "$KUBE_SCHEDULER_CSR_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$KUBE_SCHEDULER_CERT_PATH" -days 500 

#
# Create kubeconfig for kube-scheduler
#
kubectl config set-cluster k8s-training --certificate-authority=$KUBERNETES_CA_CERT_PATH --embed-certs=true --server=https://${CONTROLLER_PRIVATE_IP}:6443 --kubeconfig=${KUBE_SCHEDULER_KUBECONFIG_PATH}
kubectl config set-credentials system:kube-scheduler --client-certificate=$KUBE_SCHEDULER_CERT_PATH --client-key=$KUBE_SCHEDULER_KEY_PATH --embed-certs=true --kubeconfig=${KUBE_SCHEDULER_KUBECONFIG_PATH}
kubectl config set-context default --cluster=k8s-training --user=system:kube-scheduler --kubeconfig=${KUBE_SCHEDULER_KUBECONFIG_PATH}
kubectl config use-context default --kubeconfig=${KUBE_SCHEDULER_KUBECONFIG_PATH}

#
# Install kube-scheduler
#

echo "Installing kube-scheduler"

## Download
wget -q "$KUBE_SCHEDULER_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kube-scheduler"

## Create systemd service
cat << EOF | sudo tee "$KUBE_SCHEDULER_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kube-scheduler

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kube-scheduler \\
  --kubeconfig=${KUBE_SCHEDULER_KUBECONFIG_PATH} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable kube-scheduler.service
systemctl restart kube-scheduler.service

# Cleanup
rm /tmp/kube-scheduler* -rf

