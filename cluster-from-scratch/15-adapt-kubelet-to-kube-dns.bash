#!/bin/bash

source ./common.bash

#
# Kubernetes Control Plane: kube-dns
#
# At the end of this script you will have running Kube Controller Manager
#

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
  --v=2 \\
  --allow-privileged=true \\
  --cluster-dns=$KUBE_DNS_SERVICE_IP \\
  --cluster-domain=$CLUSTER_DOMAIN
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service
