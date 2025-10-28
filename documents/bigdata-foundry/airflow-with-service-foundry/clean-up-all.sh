#!/bin/bash

echo "=========================="
echo "Cleaning up Airflow with Service Foundry"
echo "=========================="

AIRFLOW_NAMESPACE="airflow"

#helm -n $AIRFLOW_NAMESPACE uninstall airflow

argocd-delapp oss-airflow-1.18.0-helm-app

kubectl -n $AIRFLOW_NAMESPACE get secrets | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete secret {}
kubectl -n $AIRFLOW_NAMESPACE get configmaps | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete configmap {}
kubectl -n $AIRFLOW_NAMESPACE get svc | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete svc {}
kubectl -n $AIRFLOW_NAMESPACE get deployments | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete deployment {}
kubectl -n $AIRFLOW_NAMESPACE get statefulsets | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete statefulset {}
kubectl -n $AIRFLOW_NAMESPACE get pvc | awk 'NR>1' | awk '{print $1}' | xargs -I {} kubectl -n $AIRFLOW_NAMESPACE delete pvc {}

kubectl delete namespace $AIRFLOW_NAMESPACE

kubectl create namespace $AIRFLOW_NAMESPACE




#kubectl -n $AIRFLOW_NAMESPACE delete secret airflow-broker-url airflow-fernet-key

#kubectl -n $AIRFLOW_NAMESPACE delete pvc data-airflow-postgresql-0 logs-airflow-triggerer-0
