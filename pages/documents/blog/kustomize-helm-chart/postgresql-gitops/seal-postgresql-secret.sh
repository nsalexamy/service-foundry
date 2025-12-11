#!/bin/bash

POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
DBUSER_PASSWORD=${DBUSER_PASSWORD:-postgres}
REPLICATION_PASSWORD=${REPLICATION_PASSWORD:-replication}
NAMESPACE=${NAMESPACE:-dev}

SECRET_YAML_FILE="postgresql-credentials-${NAMESPACE}.yaml"
SEALED_SECRET_YAML_FILE="postgresql-credentials-${NAMESPACE}-sealed.yaml"
K8S_PUBLIC_CERT_FILE="pub-cert.pem"

kubectl create secret generic postgresql-credentials \
    --from-literal=postgres-password=$POSTGRES_PASSWORD \
    --from-literal=password=$DBUSER_PASSWORD \
    --from-literal=replication-password=$REPLICATION_PASSWORD \
    --namespace=$NAMESPACE --dry-run=client -o yaml > $SECRET_YAML_FILE


kubeseal --fetch-cert \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=kube-system \
    > $K8S_PUBLIC_CERT_FILE

kubeseal --cert $K8S_PUBLIC_CERT_FILE --format yaml < $SECRET_YAML_FILE > $SEALED_SECRET_YAML_FILE

echo "Clean up temp files"
rm $SECRET_YAML_FILE
rm $K8S_PUBLIC_CERT_FILE

echo "Sealed secret created at $SEALED_SECRET_YAML_FILE"
