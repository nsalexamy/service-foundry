#!/bin/bash

echo "Creating EKS cluster"

USE_LONGHORN=${USE_LONGHORN:-true}
USE_SSD_STORAGE=${USE_SSD_STORAGE:-true}
USE_SSH_ACCESS=${USE_SSH_ACCESS:-true}
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-"~/.ssh/id_rsa.pub"}   # default to ~/.ssh/id_rsa.pub


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

# check EKS_NODE_GROUP_NAME is set
if [ -z "$EKS_NODE_GROUP_NAME" ]; then
    echo "EKS_NODE_GROUP_NAME is not set. Using default value"
    EKS_NODE_GROUP_NAME="${EKS_CLUSTER_NAME}-ng-0"
#    exit 1
fi

# check EKS_NODE_TYPE is set
# Deprecated, use EKS_INSTANCE_TYPES instead

# if [ -z "$EKS_NODE_TYPE" ]; then
#     echo "EKS_NODE_TYPE is not set. Using default value"
#     EKS_NODE_TYPE="t3a.xlarge"
#     #EKS_NODE_TYPE="r6a.xlarge"
#     #EKS_NODE_TYPE="r6i.xlarge"
#     #EKS_NODE_TYPE="r6g.xlarge" # ARM64
# fi

if [ -z "$NODE_VOLUME_TYPE" ]; then
    echo "NODE_VOLUME_TYPE is not set. Using default value"
    NODE_VOLUME_TYPE="gp3"
    #EKS_NODE_TYPE="r6a.xlarge"
    #EKS_NODE_TYPE="r6i.xlarge"
    #EKS_NODE_TYPE="r6g.xlarge" # ARM64
fi

# check EKS_INSTANCE_TYPES is set
# Use comma separated list of instance types
if [ -z "$EKS_INSTANCE_TYPES" ]; then
    echo "EKS_INSTANCE_TYPES is not set. Using default value"

    if [ "$USE_SSD_STORAGE" = "true" ]; then
        EKS_INSTANCE_TYPES="m5ad.xlarge,m5d.xlarge,m5d.large"
    else
        EKS_INSTANCE_TYPES="m5a.xlarge,m5.xlarge,m5.large"
    fi

    #2025-08-15 09:24:30 [ℹ]  skipping ca-central-1b from selection because it doesn't support the following instance type(s): m6a.xlarges
    #2025-08-15 09:24:30 [ℹ]  skipping ca-central-1a from selection because it doesn't support the following instance type(s): m6a.xlarges
    #2025-08-15 09:24:30 [ℹ]  skipping ca-central-1d from selection because it doesn't support the following instance type(s): r5a.xlarge,r6a.xlarge,t3a.xlarge,m6a.xlarges
    # EKS_INSTANCE_TYPES="r5a.xlarge,r6a.xlarge,t3a.xlarge,m5a.xlarge,m6a.xlarge"
    #EKS_INSTANCE_TYPES="r6a.xlarge"
    #EKS_INSTANCE_TYPES="r6i.xlarge"            
fi
# check EKS_VERSION is set
if [ -z "$EKS_VERSION" ]; then
    echo "EKS_VERSION is not set. Using default value"
    EKS_VERSION="1.34"
fi

# check EKS_NODE_MIN is set
if [ -z "$EKS_NODE_MIN" ]; then
    echo "EKS_NODE_MIN is not set. Using default value"

    # when using Longhorn, min node must be at least 3
    if [ "$USE_LONGHORN" = "true" ]; then
        EKS_NODE_MIN=3
    else
        EKS_NODE_MIN=2
    fi
fi

# check EKS_NODE_MAX is set
if [ -z "$EKS_NODE_MAX" ]; then
    echo "EKS_NODE_MAX is not set. Using default value"
    EKS_NODE_MAX=4
fi

# check EKS_NODE_DESIRED is set
if [ -z "$EKS_NODE_DESIRED" ]; then
    echo "EKS_NODE_DESIRED is not set. Using default value"
    # when using Longhorn, desired node must be at least 3
    if [ "$USE_LONGHORN" = "true" ]; then
        EKS_NODE_DESIRED=3
    else
        EKS_NODE_DESIRED=2
    fi
fi

# check EKS_USE_SPOT is set
#if [ -z "$EKS_USE_SPOT" ]; then
#    echo "EKS_USE_SPOT is not set. Using default value"
#    EKS_USE_SPOT=false
#fi

# check EKS_USE_SPOT is set, default value is true
if [ -z "$EKS_USE_SPOT" ]; then
    echo "EKS_USE_SPOT is not set. Using default value"
    EKS_USE_SPOT="false"
fi

if [ -z "$EKS_USE_SPOT" ]; then
    echo "EKS_USE_SPOT is not set. Using default value"
    EKS_USE_SPOT="false"
fi

EKS_SPOT_FLAG=""
if [ "$EKS_USE_SPOT" = "true" ]; then
  EKS_SPOT_FLAG="--spot"
fi

SSH_FLAG=""
if [ "$USE_SSH_ACCESS" = "true" ]; then
    SSH_FLAG="--ssh-access --ssh-public-key $SSH_PUBLIC_KEY"
fi

EKS_NODE_VOLUME_SIZE=${EKS_NODE_VOLUME_SIZE:-100}
NODE_AMI_FAMILY=${NODE_AMI_FAMILY:-"AmazonLinux2023"}
EKS_WITH_OIDC_FLAG=${EKS_WITH_OIDC_FLAG:-"--with-oidc"}


# display the values
echo "AWS_REGION: $AWS_REGION"
echo "EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
echo "EKS_VERSION: $EKS_VERSION"
echo "EKS_NODE_GROUP_NAME: $EKS_NODE_GROUP_NAME"
#echo "EKS_NODE_TYPE: $EKS_NODE_TYPE"
echo "EKS_INSTANCE_TYPES: $EKS_INSTANCE_TYPES"
echo "NODE_VOLUME_TYPE: $NODE_VOLUME_TYPE"
echo "EKS_NODE_MIN: $EKS_NODE_MIN"
echo "EKS_NODE_MAX: $EKS_NODE_MAX"
echo "EKS_NODE_DESIRED: $EKS_NODE_DESIRED"
echo "EKS_NODE_VOLUME_SIZE: $EKS_NODE_VOLUME_SIZE"
echo "EKS_SPOT_FLAG: $EKS_SPOT_FLAG"
echo "NODE_AMI_FAMILY: $NODE_AMI_FAMILY"
echo "EKS_WITH_OIDC_FLAG: $EKS_WITH_OIDC_FLAG"
echo "SSH_FLAG: $SSH_FLAG"


# check EKS_NODE_DESIRED is less than or equal to EKS_NODE_MAX
if [ $EKS_NODE_DESIRED -gt $EKS_NODE_MAX ]; then
    echo "EKS_NODE_DESIRED ($EKS_NODE_DESIRED) is greater than EKS_NODE_MAX ($EKS_NODE_MAX)"
    exit 1
fi

# check EKS_NODE_MIN is less than or equal to EKS_NODE_MAX
if [ $EKS_NODE_MIN -gt $EKS_NODE_MAX ]; then
    echo "EKS_NODE_MIN ($EKS_NODE_MIN) is greater than EKS_NODE_MAX ($EKS_NODE_MAX)"
    exit 1
fi

# check EKS_NODE_DESIRED is greater than or equal to EKS_NODE_MIN
if [ $EKS_NODE_DESIRED -lt $EKS_NODE_MIN ]; then
    echo "EKS_NODE_DESIRED ($EKS_NODE_DESIRED) is less than EKS_NODE_MIN ($EKS_NODE_MIN)"
    exit 1
fi

# FROM HERE
# eksctl create cluster --name $EKS_CLUSTER_NAME \
#   --region $AWS_REGION \
#   --version $EKS_VERSION \
#   --with-oidc \
#   --managed $EKS_SPOT_FLAG
#   --without-nodegroup

# if [ $? -ne 0 ]; then
#     echo "Failed to create EKS cluster $EKS_CLUSTER_NAME"
#     exit 1
# else 
#     echo "EKS cluster $EKS_CLUSTER_NAME created successfully"

#     TIMEOUT_SECONDS=$((10 * 60))
#     INTERVAL_SECONDS=10
#     ELAPSED=0

#     echo "Waiting for EKS cluster '$EKS_CLUSTER_NAME' to become ACTIVE..."

#     while true; do
#         STATUS=$(aws eks describe-cluster \
#             --name "$EKS_CLUSTER_NAME" \
#             --region "$AWS_REGION" \
#             --query "cluster.status" \
#             --output text 2>/dev/null)

#         if [ "$STATUS" = "ACTIVE" ]; then
#             echo "✅ Cluster is ACTIVE!"
#             break
#         fi

#         if [ "$ELAPSED" -ge "$TIMEOUT_SECONDS" ]; then
#             echo "⚠️ Timeout reached. Exiting wait loop."
#             exit 1
#         fi

#         echo "⏳ Current status: $STATUS (waiting...)"
#         sleep "$INTERVAL_SECONDS"
#         ELAPSED=$((ELAPSED + INTERVAL_SECONDS))
#     done
# fi


# eksctl create nodegroup \
#   --cluster $EKS_CLUSTER_NAME \
#   --region $AWS_REGION \
#   --name $EKS_NODE_GROUP_NAME \
#   --instance-types $EKS_INSTANCE_TYPES \
#   --nodes $EKS_NODE_DESIRED \
#   --nodes-min $EKS_NODE_MIN \
#   --nodes-max $EKS_NODE_MAX \
#   --node-volume-size $EKS_NODE_VOLUME_SIZE \
#   --node-ami-family $NODE_AMI_FAMILY \
#   --managed $EKS_SPOT_FLAG

# if [ $? -ne 0 ]; then
#     echo "Failed to create node group $EKS_NODE_GROUP_NAME in cluster $EKS_CLUSTER_NAME"
#     eksctl delete nodegroup --region=$AWS_REGION --cluster=$EKS_CLUSTER_NAME --name=$EKS_NODE_GROUP_NAME
# else 
#     echo "Node group $EKS_NODE_GROUP_NAME created successfully in cluster $EKS_CLUSTER_NAME"
#     echo "Adding label 'agentpool=sfnodes' to node group $EKS_NODE_GROUP_NAME"
#     aws eks update-nodegroup-config --region $AWS_REGION --cluster-name $EKS_CLUSTER_NAME \
#         --nodegroup-name $EKS_NODE_GROUP_NAME --labels "addOrUpdateLabels={agentpool=sfnodes}"
# fi

# END HERE


eksctl create cluster --name $EKS_CLUSTER_NAME \
 --region $AWS_REGION \
 --version $EKS_VERSION \
 --nodegroup-name $EKS_NODE_GROUP_NAME \
 --instance-types $EKS_INSTANCE_TYPES \
 --nodes $EKS_NODE_DESIRED \
 --nodes-min $EKS_NODE_MIN \
 --nodes-max $EKS_NODE_MAX \
 --node-volume-size $EKS_NODE_VOLUME_SIZE \
 --node-ami-family $NODE_AMI_FAMILY \
 --node-volume-type $NODE_VOLUME_TYPE \
 --managed \
 $EKS_SPOT_FLAG $EKS_WITH_OIDC_FLAG $SSH_FLAG

#aws eks update-nodegroup-config --region $AWS_REGION --cluster-name $EKS_CLUSTER_NAME \
#  --nodegroup-name $EKS_NODE_GROUP_NAME --labels "addOrUpdateLabels={agentpool=sfnodes}"

echo "Executing post EKS setup script"
source ./post-eks-setup.sh

