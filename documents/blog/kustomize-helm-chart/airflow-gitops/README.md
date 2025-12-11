# Airflow GitOps with Kustomize and Helm

This directory contains Kustomize configurations for deploying Apache Airflow using Helm chart inflation.

## Quick Start

### With kubectl and Kustomize

```bash
cd airflow-gitops
kustomize build dev --enable-helm | kubectl apply -f -
```

See [INSTALLATION.md](./INSTALLATION.md) for detailed instructions.

### With ArgoCD

```bash
kubectl apply -f argocd/airflow-dev-application.yaml
```

See [ARGOCD.md](./ARGOCD.md) for detailed ArgoCD configuration.

## Directory Structure

```
airflow-gitops/
├── base/                           # Base Kustomize resources
│   ├── kustomization.yaml         # Base configuration (no helmCharts)
│   └── airflow-git-ssh-key-secret.yaml
├── dev/                           # Dev environment overlay
│   ├── kustomization.yaml         # Dev config with helmCharts
│   ├── namespace.yaml             # airflow-dev namespace
│   ├── values-dev.yaml            # Helm values for dev
│   ├── airflow-postgresql-credentials-secret.yaml
│   └── airflow-webserver-default-user-credentials.yaml
├── argocd/                        # ArgoCD Application manifests
│   ├── airflow-dev-application.yaml
│   └── airflow-applicationset.yaml
├── INSTALLATION.md                # Manual installation guide
├── ARGOCD.md                      # ArgoCD configuration guide
└── README.md                      # This file
```

## Key Features

- **Kustomize Overlays**: Separate base and environment-specific configurations
- **Helm Chart Inflation**: Uses Kustomize's built-in Helm chart inflation
- **GitOps Ready**: Designed for ArgoCD deployment
- **Environment-Specific**: Easy to add staging, prod, etc.

## Environment Configuration

### Dev Environment

- **Namespace**: `airflow-dev`
- **Executor**: KubernetesExecutor
- **Database**: PostgreSQL (included via Helm chart)
- **DAG Source**: Git sync from `git@github.com:nsalexamy/airflow-dags-example.git`

## Important Notes

### The `--enable-helm` Flag

When using `kustomize build` with Helm chart inflation, you **must** include the `--enable-helm` flag:

```bash
kustomize build dev --enable-helm
```

### ArgoCD Configuration

For ArgoCD deployments, you must configure the Application with:

```yaml
spec:
  source:
    kustomize:
      buildOptions: "--enable-helm"
```

See [ARGOCD.md](./ARGOCD.md) for complete examples.

## Adding New Environments

To create a new environment (e.g., `staging`):

1. Copy the `dev/` directory: `cp -r dev staging`
2. Update `staging/kustomization.yaml`:
   - Change `namespace: airflow-staging`
   - Update `valuesFile: values-staging.yaml`
3. Create `staging/values-staging.yaml` with environment-specific values
4. Update secrets for the new environment
5. Build and test: `kustomize build staging --enable-helm`

## Documentation

- **[INSTALLATION.md](./INSTALLATION.md)**: Complete installation guide for kubectl/kustomize
- **[ARGOCD.md](./ARGOCD.md)**: ArgoCD configuration and deployment guide

## Troubleshooting

See the Troubleshooting sections in:
- [INSTALLATION.md](./INSTALLATION.md#troubleshooting)
- [ARGOCD.md](./ARGOCD.md#troubleshooting)

## Resources

- [Apache Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kustomize Helm Chart Inflation](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)
- [ArgoCD Kustomize Support](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
