#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: API Server
#
# At the end of this script you will have running API Server
#

echo "Creating kube-apiserver certificates"

#
# Create kube-apiserver server certificate
#
export KUBE_APISERVER_CSR_PATH=/tmp/kube-apiserver_server.csr

## Private key
openssl genrsa -out "$KUBE_APISERVER_KEY_PATH" 2048

export KUBE_APISERVER_CERT_CONFIG=/tmp/kube-apiserver_cert_config.conf

cat <<EOF | tee ${KUBE_APISERVER_CERT_CONFIG}
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS = ${HOSTNAME}
IP = ${CONTROLLER_PRIVATE_IP}
IP.1 = 127.0.0.1
IP.2 = ${CONTROLLER_PUBLIC_IP}
IP.3 = ${KUBE_APISERVER_SERVICE_IP}
EOF

## Certificate sign request
openssl req -new -key "$KUBE_APISERVER_KEY_PATH" -out "$KUBE_APISERVER_CSR_PATH" -subj "/CN=kubernetes/O=Kubernetes" -config ${KUBE_APISERVER_CERT_CONFIG}
## Certificate
openssl x509 -req -in "$KUBE_APISERVER_CSR_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$KUBE_APISERVER_CERT_PATH"  -extensions v3_req -days 500 -extfile ${KUBE_APISERVER_CERT_CONFIG}

#
# Install kube-apiserver
#

echo "Installing kube-apiserver"

## Download
wget -q "$KUBE_APISERVER_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kube-apiserver"

## Create systemd service
cat << EOF | sudo tee "$KUBE_APISERVER_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kube-apiserver

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kube-apiserver \\
  --tls-cert-file=${KUBE_APISERVER_CERT_PATH} \\
  --tls-private-key-file=${KUBE_APISERVER_KEY_PATH} \\
  --client-ca-file=${KUBERNETES_CA_CERT_PATH} \\
  --etcd-cafile=${KUBERNETES_CA_CERT_PATH} \\
  --etcd-certfile=${ETCD_CLIENT_CERT_PATH} \\
  --etcd-keyfile=${ETCD_CLIENT_KEY_PATH} \\
  --etcd-servers=https://${CONTROLLER_PRIVATE_IP}:2379 \\
  --service-cluster-ip-range=${SERVICE_CLUSTERIP_NET} \\
  --authorization-mode=RBAC \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl restart kube-apiserver.service

# Cleanup
rm /tmp/kube-apiserver* -rf

echo "End of kube-apiserver step"