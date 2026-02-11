#!/bin/bash

cat <<EOF > node-config-template.yaml
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: application/node.eks.aws

apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${EKS_CLUSTER_NAME}
    apiServerEndpoint: ${EKS_API_SERVER_ENDPOINT}
    certificateAuthority: ${EKS_CERTIFICATE_AUTHORITY}
    cidr: ${EKS_CLUSTER_CIDR}

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -euxo pipefail

dnf install -y iscsi-initiator-utils

# Make sure the iSCSI daemon is enabled and running
systemctl enable --now iscsid || true

# (Optional) helpful debug info in logs
iscsiadm --version || true
systemctl status iscsid --no-pager || true
EOF