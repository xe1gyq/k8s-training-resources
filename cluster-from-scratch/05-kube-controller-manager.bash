#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-controller-manager
#
# At the end of this script you will have running Kube Controller Manager
#

echo "Creating kube-controller-manager certificates"

#
# Create kube-controller-manager certificate
#
export KUBE_CONTROLLER_MANAGER_CSR_PATH=/tmp/kube-controller-manager_server.csr

## Private key
openssl genrsa -out "$KUBE_CONTROLLER_MANAGER_KEY_PATH" 2048

## Certificate sign request
openssl req -new -key "$KUBE_CONTROLLER_MANAGER_KEY_PATH" -out "$KUBE_CONTROLLER_MANAGER_CSR_PATH" -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager"
## Certificate
openssl x509 -req -in "$KUBE_CONTROLLER_MANAGER_CSR_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$KUBE_CONTROLLER_MANAGER_CERT_PATH" -days 500 

#
# Create certificate for service account generation
#
export SERVICE_ACCOUNT_GEN_CSR_PATH=/tmp/service-account-gen.csr

## Private key
openssl genrsa -out "$SERVICE_ACCOUNT_GEN_KEY_PATH" 2048

## Certificate sign request
openssl req -new -key "$SERVICE_ACCOUNT_GEN_KEY_PATH" -out "$SERVICE_ACCOUNT_GEN_CSR_PATH" -subj "/CN=service-accounts/O=Kubernetes"
## Certificate
openssl x509 -req -in "$SERVICE_ACCOUNT_GEN_CSR_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$SERVICE_ACCOUNT_GEN_CERT_PATH" -days 500 


#
# Install kubectl for creating the required kubeconfig
#
wget -q "$KUBECTL_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kubectl"

#
# Create kubeconfig for kube-controller-manager
#
kubectl config set-cluster k8s-training --certificate-authority=$KUBERNETES_CA_CERT_PATH --embed-certs=true --server=https://${CONTROLLER_PRIVATE_IP}:6443 --kubeconfig=${KUBE_CONTROLLER_MANAGER_KUBECONFIG_PATH}
kubectl config set-credentials system:kube-controller-manager --client-certificate=$KUBE_CONTROLLER_MANAGER_CERT_PATH --client-key=$KUBE_CONTROLLER_MANAGER_KEY_PATH --embed-certs=true --kubeconfig=${KUBE_CONTROLLER_MANAGER_KUBECONFIG_PATH}
kubectl config set-context default --cluster=k8s-training --user=system:kube-controller-manager --kubeconfig=${KUBE_CONTROLLER_MANAGER_KUBECONFIG_PATH}
kubectl config use-context default --kubeconfig=${KUBE_CONTROLLER_MANAGER_KUBECONFIG_PATH}

#
# Install kube-controller-manager
#

echo "Installing kube-controller-manager"

## Download
wget -q "$KUBE_CONTROLLER_MANAGER_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kube-controller-manager"

## Create systemd service
cat << EOF | sudo tee "$KUBE_CONTROLLER_MANAGER_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kube-controller-manager

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kube-controller-manager \\
  --cluster-name=kubernetes \\
  --kubeconfig=${KUBE_CONTROLLER_MANAGER_KUBECONFIG_PATH} \\
  --use-service-account-credentials=true \\
  --service-account-private-key-file=${SERVICE_ACCOUNT_GEN_KEY_PATH} \\
  --root-ca-file=${KUBERNETES_CA_CERT_PATH} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable kube-controller-manager.service
systemctl restart kube-controller-manager.service

# Cleanup
rm /tmp/kube-controller-manager* -rf

