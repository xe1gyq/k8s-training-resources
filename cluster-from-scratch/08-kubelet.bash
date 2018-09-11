#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kubelet
#
# At the end of this script you will have running Kube Controller Manager
#

#
# This part must be executed in the worker nodes
#

echo "Creating kubelet certificates"

mkdir -p "$KUBERNETES_CERT_DIR"

#
# Create kubelet certificate
#
export KUBELET_CSR_PATH=/tmp/kubelet.csr

## Private key
openssl genrsa -out "$KUBELET_KEY_PATH" 2048

export KUBELET_CERT_CONFIG=/tmp/kubelet_cert_config.conf
export THIS_WORKER_IP=$(ifconfig eth0 | awk '/inet addr/ {print $2}' | cut -d: -f2)

cat <<EOF | tee ${KUBELET_CERT_CONFIG}
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS = ${HOSTNAME}
IP = ${THIS_WORKER_IP}
IP.1 = 127.0.0.1
EOF


## Certificate sign request
openssl req -new -key "$KUBELET_KEY_PATH" -out "$KUBELET_CSR_PATH" -subj "/CN=system:node:${HOSTNAME}/O=system:nodes" -config ${KUBELET_CERT_CONFIG}

## Copy the request to the server (NOT THE PROPER WAY)
scp $KUBELET_CSR_PATH ubuntu@$CONTROLLER_PUBLIC_IP:/tmp/
scp $KUBELET_CERT_CONFIG ubuntu@$CONTROLLER_PUBLIC_IP:/tmp/

# Execute this part on the controller node

export KUBELET_CSR_IN_PATH=/tmp/kubelet.csr
export KUBELET_CSR_CONF_IN_PATH=/tmp/kubelet_cert_config.conf
export KUBELET_CERT_OUT_PATH=/tmp/kubelet.crt

## Certificate
openssl x509 -req -in "$KUBELET_CSR_IN_PATH" -CA "$KUBERNETES_CA_CERT_PATH" -CAkey "$KUBERNETES_CA_KEY_PATH" -CAcreateserial -out "$KUBELET_CERT_OUT_PATH" -days 500 -extensions v3_req -extfile ${KUBELET_CSR_CONF_IN_PATH}  

#
# This part is to be executed again in the worker node
#
export KUBELET_CERT_OUT_PATH=/tmp/kubelet.crt

# Download the generated certificate (NOT THE PROPER WAY)
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBELET_CERT_OUT_PATH "$KUBELET_CERT_PATH"
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBERNETES_CA_CERT_PATH "$KUBERNETES_CA_CERT_PATH"

#
# Install kubectl for creating the required kubeconfig
#
wget -q "$KUBECTL_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kubectl"

#
# Create kubeconfig for kubelet
#
kubectl config set-cluster k8s-training --certificate-authority=$KUBERNETES_CA_CERT_PATH --embed-certs=true --server=https://${CONTROLLER_PRIVATE_IP}:6443 --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config set-credentials system:node:${HOSTNAME} --client-certificate=$KUBELET_CERT_PATH --client-key=$KUBELET_KEY_PATH --embed-certs=true --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config set-context default --cluster=k8s-training --user=system:node:${HOSTNAME} --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config use-context default --kubeconfig=${KUBELET_KUBECONFIG_PATH}

#
# Install dependencies
#

## docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y socat conntrack ipset docker-ce
sudo systemctl enable docker.service
sudo systemctl start docker.service

## cni
mkdir -p /opt/cni/bin
mkdir -p /etc/cni/net.d
wget -q $CNI_TARBALL_URL -P /tmp
tar xf "/tmp/$CNI_TARBALL_NAME" -C /opt/cni/bin/

#
# Install kubelet
#

echo "Installing kubelet"

## Download
wget -q "$KUBELET_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kubelet"

## Create systemd service
cat << EOF | sudo tee "$KUBELET_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kubelet

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kubelet \\
  --kubeconfig=${KUBELET_KUBECONFIG_PATH} \\
  --container-runtime=docker \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/cni/bin \\
  --client-ca-file=${KUBERNETES_CA_CERT_PATH} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service

# Cleanup
rm /tmp/kubelet* -rf

