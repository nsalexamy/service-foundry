#!/bin/bash

echo "=========================="
echo "Applying Terraform configuration"
echo "=========================="

CWD=$(pwd)
TERRAFORM_DIR=$CWD/terraform


wait_for_alb_active() {
  # use aws cli to wait for alb to be active
  local alb_name="$1"
  local timeout_seconds="${2:-600}"     # default: 600 seconds
  local interval_seconds="${3:-5}"      # default: 5 seconds
  local max_retries=$((timeout_seconds / interval_seconds))
  echo "Waiting for ALB $alb_name to become active..."
  for ((i=1; i<=max_retries; i++)); do
    alb_state=$(aws elbv2 describe-load-balancers --names "$alb_name" --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null || true)
    if [[ "$alb_state" == "active" ]]; then
      echo "ALB $alb_name is active."
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "Timed out waiting for ALB $alb_name to become active." >&2
  return 1
}

wait_for_lb_hostname() {
  local namespace="$1"
  local release_name="$2"
  local timeout_seconds="${3:-600}"     # default: 600 seconds
  local interval_seconds="${4:-5}"      # default: 5 seconds
  local max_retries=$((timeout_seconds / interval_seconds))

  echo "Waiting for Service ${namespace}/${release_name} to get a LoadBalancer hostname..."

  for ((i=1; i<=max_retries; i++)); do
    LB_HOSTNAME=$(kubectl get svc "$release_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    if [[ -n "$LB_HOSTNAME" ]]; then
      echo "Service has LB hostname: $LB_HOSTNAME"
      return 0
    fi
    sleep "$interval_seconds"
  done

  echo "Timed out waiting for LoadBalancer hostname on service ${namespace}/${release_name}" >&2
  return 1
}

#K8S_NAMESPACE="traefik"
#HELM_RELEASE_NAME="traefik"
#
#if ! wait_for_lb_hostname "$K8S_NAMESPACE" "$HELM_RELEASE_NAME"; then
#  echo "Exiting due to timeout"
#  exit 1
#fi

ALB_NAME="traefik-alb"

if ! wait_for_alb_active "$ALB_NAME"; then
  echo "Exiting due to timeout"
  exit 1
fi

cd $TERRAFORM_DIR


DNS_NAME=${DNS_NAME:-"servicefoundry.org"}

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DNS_NAME | yq '.HostedZones[0].Id' | awk -F'/' '{print $NF}')

# check if HOSTED_ZONE_ID is 'null'
if [ "$HOSTED_ZONE_ID" == "null" ] || [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Hosted Zone ID for $DNS_NAME not found."
  echo "Please create a hosted zone for $DNS_NAME in Route 53 before applying this Terraform configuration."

  exit 1
else
  echo "Found Hosted Zone ID: $HOSTED_ZONE_ID for $DNS_NAME"
  echo "Using existing hosted zone."

  terraform init

  # check if the DNS record exists
  RECORD_SETS=$(aws route53 list-resource-record-sets \
                  --hosted-zone-id $HOSTED_ZONE_ID \
                  --output yaml \
                  --query "ResourceRecordSets[?Name == '${DNS_NAME}.' && Type == 'A']")

  if [ "$RECORD_SETS" == "[]" ]; then
    echo "DNS record for $DNS_NAME not found in hosted zone $HOSTED_ZONE_ID. It will be created."
  else
    echo "DNS record for $DNS_NAME found in hosted zone $HOSTED_ZONE_ID. Importing into Terraform state."

    DNS_ALIAS="${HOSTED_ZONE_ID}_${DNS_NAME}_A"

    echo "terraform import aws_route53_record.a_alias $DNS_ALIAS"
    terraform import module.alias_for_traefik.aws_route53_record.a_alias $DNS_ALIAS
  fi

  terraform apply --auto-approve
fi

cd $CWD