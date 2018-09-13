# Session-04
## Logging

These manifests have been adapted from upstream Kubernetes at
https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/fluentd-elasticsearch
tweaked for:

* all: deploy to `logging` namespace
* elasticsearch: adjust `limits.cpu` down, to better fix single VM
  [Bitnami Kubernetes Sandbox](https://bitnami.com/stack/kubernetes-sandbox)
* fluentd-elasticsearch: remove `spec.nodeSelector`

Diffs from upstream have been saved to
`./kubernetes_cluster_addons_fluentd-elasticsearch.diff`.
