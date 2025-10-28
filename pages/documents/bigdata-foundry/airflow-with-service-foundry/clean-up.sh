#!/bin/bash

echo "=========================="
echo "Cleaning up Airflow with Service Foundry"
echo "=========================="

AIRFLOW_NAMESPACE="airflow"

helm -n $AIRFLOW_NAMESPACE uninstall airflow



kubectl -n $AIRFLOW_NAMESPACE delete secret airflow-broker-url airflow-fernet-key

kubectl -n $AIRFLOW_NAMESPACE delete pvc data-airflow-postgresql-0 logs-airflow-triggerer-0
