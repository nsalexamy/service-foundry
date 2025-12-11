# Airflow Installation Guide with Kustomize

This guide explains how to install Apache Airflow in the `airflow-dev` namespace using Kustomize with Helm chart inflation.

## Prerequisites

- `kubectl` configured with access to your Kubernetes cluster
- `kustomize` v5.0.0 or later (you have v5.8.0 ✓)
- Helm repository access to https://airflow.apache.org

> **Note**: If you're using ArgoCD, see [ARGOCD.md](./ARGOCD.md) for ArgoCD-specific configuration.


## Configuration Overview

The setup uses Kustomize overlays with Helm chart inflation:

### Base Configuration (`base/`)
- Contains shared resources like the Git SSH key secret
- No Helm chart definition (moved to overlays for environment-specific configuration)

### Dev Overlay (`dev/`)
- **Namespace**: `airflow-dev`
- **Helm Chart**: Apache Airflow v1.18.0
- **Values File**: `values-dev.yaml` (configured for KubernetesExecutor with GitSync)
- **Secrets**: PostgreSQL credentials and webserver user credentials

## Installation Steps

### 1. Build and Preview Configuration

First, verify the Kustomize build output before applying:

```bash
cd /Users/young/Dev/alexamy/service-foundry/documents/blog/kustomize-helm-chart/airflow-gitops
kustomize build dev --enable-helm
```

**Note**: The `--enable-helm` flag is required for Helm chart inflation.

### 2. Apply to Kubernetes Cluster

Apply the configuration to your cluster:

```bash
kustomize build dev --enable-helm | kubectl apply -f -
```

This will:
- Create the `airflow-dev` namespace
- Install Airflow Helm chart with dev-specific values
- Create necessary secrets for PostgreSQL and webserver authentication
- Configure GitSync to pull DAGs from your Git repository

### 3. Verify Installation

Check the status of resources:

```bash
# Check namespace
kubectl get namespace airflow-dev

# Check all resources in airflow-dev namespace
kubectl get all -n airflow-dev

# Check pod status
kubectl get pods -n airflow-dev

# Check Helm-inflated resources
kubectl get deployment,statefulset,service -n airflow-dev
```

### 4. Access Airflow Webserver

Once pods are running, you can access the Airflow webserver:

```bash
# Port forward to access locally
kubectl port-forward -n airflow-dev svc/airflow-webserver 8080:8080
```

Then open http://localhost:8080 in your browser.

Default credentials are configured in `airflow-webserver-default-user-credentials.yaml`.

## Configuration Details

### Helm Chart Configuration

The Helm chart is configured in `dev/kustomization.yaml`:

```yaml
helmCharts:
  - name: airflow
    repo: https://airflow.apache.org
    version: 1.18.0
    releaseName: airflow
    namespace: airflow-dev
    valuesFile: values-dev.yaml
```

### Key Values in `values-dev.yaml`

- **Executor**: KubernetesExecutor
- **DAG Source**: GitSync from `git@github.com:nsalexamy/airflow-dags-example.git`
- **Database**: PostgreSQL (enabled, using Bitnami chart)
- **Redis**: Disabled (not needed for KubernetesExecutor)

## Updating the Installation

To update after making changes:

```bash
kustomize build dev --enable-helm | kubectl apply -f -
```

## Uninstalling

To remove the Airflow installation:

```bash
kustomize build dev --enable-helm | kubectl delete -f -
```

## Troubleshooting

### Error: "must specify --enable-helm"
**Solution**: Always include the `--enable-helm` flag when building or applying.

### Pods not starting
**Solution**: Check pod logs:
```bash
kubectl logs -n airflow-dev <pod-name>
```

### GitSync not working
**Solution**: Verify the SSH key secret is correctly configured:
```bash
kubectl get secret -n airflow-dev airflow-git-ssh-key-secret
```

## Creating Additional Environments

To create a new environment (e.g., `prod`):

1. Create a new directory: `airflow-gitops/prod/`
2. Copy and modify `dev/kustomization.yaml` and values file
3. Update namespace and environment-specific configurations
4. Apply with: `kustomize build prod --enable-helm | kubectl apply -f -`
