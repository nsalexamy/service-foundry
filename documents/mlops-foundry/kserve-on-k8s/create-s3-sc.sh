#!/bin/bash

echo "Creating S3 Storage Class for EKS cluster"

# check AWS_REGION is set
if [ -z "$AWS_REGION" ]; then
    echo "AWS_REGION is not set"
    exit 1
fi

# check EKS_CLUSTER_NAME is set
if [ -z "$EKS_CLUSTER_NAME" ]; then
    echo "EKS_CLUSTER_NAME is not set"
    exit 1
fi

usage() {
  echo ''
  echo ''
  echo "Usage: ${0} [-h] [-b s3-bucket-name]"
  echo ''
  echo 'options'
  echo '  -b : S3 bucket name'
  echo '  -h : Display this help message'

  exit 1
}

while getopts "bpchm:r:t:" OPTION
do
  case ${OPTION} in
    b) S3_BUCKET_NAME="${OPTARG}" ;;
    h) usage ;;
    ?) usage ;;
  esac
done

# check EKS_CLUSTER_NAME is set
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "S3_BUCKET_NAME is not set"
    usage
fi

# check if S3 bucket already exists
if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
    echo "S3 bucket $S3_BUCKET_NAME already exists"
else
    # create S3 bucket
    echo "$S3_BUCKET_NAME does not exist. Creating..."
    aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
    echo "S3 bucket $S3_BUCKET_NAME created"
fi

S3_CSI_POLICY_FILE="s3-csi-policy.json"

# Create s3-csi-policy.json file
cat <<EOF > ./$S3_CSI_POLICY_FILE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
    }
  ]
}

EOF

S3_CSI_DRIVER_POLICY_NAME="S3_CSI_Driver_Policy_${EKS_CLUSTER_NAME}_${AWS_REGION}_${S3_BUCKET_NAME}"
S3_CSI_DRIVER_ROLE_NAME="AmazonEKS_S3_CSI_Driver_Role_${EKS_CLUSTER_NAME}_${AWS_REGION}_${S3_BUCKET_NAME}"

echo "S3_CSI_DRIVER_POLICY_NAME: $S3_CSI_DRIVER_POLICY_NAME"
echo "S3_CSI_DRIVER_ROLE_NAME: $S3_CSI_DRIVER_ROLE_NAME"

# check s3-csi-policy is created
if [ -z "$(aws iam list-policies --region $AWS_REGION --query "Policies[?PolicyName=='${S3_CSI_DRIVER_POLICY_NAME}'].PolicyName" --output text)" ]; then
    echo "${S3_CSI_DRIVER_POLICY_NAME} policy is not created yet"
    # create s3-csi-policy
    aws iam create-policy --policy-name ${S3_CSI_DRIVER_POLICY_NAME} --policy-document file://$S3_CSI_POLICY_FILE
else
    echo "${S3_CSI_DRIVER_POLICY_NAME} policy is already created"
fi         

POLICY_ARN=$(aws iam list-policies --region $AWS_REGION --query "Policies[?PolicyName=='${S3_CSI_DRIVER_POLICY_NAME}'].Arn" --output text)  
echo "Policy ARN: $POLICY_ARN"

# Create IAM role with trust relationship for the S3 CSI Driver

# eksctl create iamserviceaccount \
#     --name s3-csi-controller-sa \
#     --namespace kube-system \
#     --cluster $EKS_CLUSTER_NAME \
#     --role-name $S3_CSI_DRIVER_ROLE_NAME \
#     --attach-policy-arn arn:aws:iam::aws:policy/service-role/$S3_CSI_DRIVER_POLICY_NAME  \
#     --approve \
#     --override-existing-serviceaccounts

eksctl create iamserviceaccount \
    --name s3-csi-controller-sa \
    --namespace kube-system \
    --cluster $EKS_CLUSTER_NAME \
    --role-name $S3_CSI_DRIVER_ROLE_NAME \
    --attach-policy-arn $POLICY_ARN  \
    --approve \
    --override-existing-serviceaccounts

# get the role ARN
ROLE_ARN=$(aws iam get-role --role-name $S3_CSI_DRIVER_ROLE_NAME --query "Role.Arn" --output text)
echo "Role ARN: $ROLE_ARN

# get node groups
NODE_GROUPS=$(eksctl get nodegroup --region $AWS_REGION --cluster $EKS_CLUSTER_NAME -o json | jq -r '.[].Name')

# put the role ARN in the node groups
for NODE_GROUP in $NODE_GROUPS; do

    # get node group role name
    NODE_GROUP_ROLE_NAME=$(aws eks describe-nodegroup --region $AWS_REGION --cluster-name $EKS_CLUSTER_NAME --nodegroup-name $NODE_GROUP --query "nodegroup.nodeRole" --output text | awk -F'/' '{print $2}')
    #echo "Node Group Role Name: $NODE_GROUP_ROLE_NAME"
    echo "Putting role ARN in node group $NODE_GROUP"
    aws iam put-role-policy --role-name $NODE_GROUP_ROLE_NAME --policy-name ${S3_CSI_DRIVER_POLICY_NAME} --policy-document file://$S3_CSI_POLICY_FILE
done
# Install the S3 CSI Driver using Helm
# check helm repo aws-mountpoint-s3-csi-driver is added
if [ -z "$(helm repo list 2> /dev/null | grep aws-mountpoint-s3-csi-driver)" ]; then
    echo "Adding helm repo aws-mountpoint-s3-csi-driver"
    helm repo add aws-mountpoint-s3-csi-driver https://awslabs.github.io/mountpoint-s3-csi-driver
    helm repo update aws-mountpoint-s3-csi-driver
else
    echo "helm repo aws-mountpoint-s3-csi-driver is already added"
    helm repo update aws-mountpoint-s3-csi-driver
fi

# Install or upgrade the S3 CSI Driver
helm upgrade --install aws-mountpoint-s3-csi-driver \
   --namespace kube-system \
   --set node.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::account:role/$S3_CSI_DRIVER_ROLE_NAME" \
   aws-mountpoint-s3-csi-driver/aws-mountpoint-s3-csi-driver




STORAGE_CLASS_NAME="s3-sc"

echo "Creating ${STORAGE_CLASS_NAME}.yaml file"

cat <<EOF > ./${STORAGE_CLASS_NAME}.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS_NAME}
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: s3.csi.aws.com
parameters:
  # some parameters, e.g. bucketName if required
  bucketName: ${S3_BUCKET_NAME}
volumeBindingMode: Immediate

EOF

echo "Applying ${STORAGE_CLASS_NAME}.yaml"
kubectl apply -f ./${STORAGE_CLASS_NAME}.yaml

