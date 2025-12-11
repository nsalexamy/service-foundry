# ArgoCD Configuration for Airflow Kustomize with Helm

This document explains how to configure ArgoCD to deploy the Airflow Kustomize application with Helm chart inflation enabled.

## Overview

ArgoCD supports Kustomize with Helm chart inflation, but you **must** explicitly enable it. There are two approaches:

1. **Per-Application Configuration** (Recommended): Configure `--enable-helm` for specific applications
2. **Global Configuration**: Enable `--enable-helm` for all Kustomize applications in ArgoCD

## Option 1: Per-Application Configuration (Recommended)

Configure the `--enable-helm` flag directly in the ArgoCD Application manifest.

### ArgoCD Application Manifest

Create an ArgoCD Application for the dev environment:

**File**: `argocd/airflow-dev-application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: airflow-dev
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/nsalexamy/service-foundry.git  # Update with your repo
    targetRevision: main  # or your branch name
    path: documents/blog/kustomize-helm-chart/airflow-gitops/dev
    
    kustomize:
      # Enable Helm chart inflation
      buildOptions: "--enable-helm"
  
  destination:
    server: https://kubernetes.default.svc
    namespace: airflow-dev
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Apply the Application

```bash
kubectl apply -f argocd/airflow-dev-application.yaml
```

### Key Configuration Points

- **`kustomize.buildOptions`**: Set to `"--enable-helm"` to enable Helm chart inflation
- **`syncPolicy.syncOptions`**: `CreateNamespace=true` ensures the namespace is created (though we also have it in our resources)
- **`syncPolicy.automated`**: Enables automatic sync when Git changes are detected

## Option 2: Global Configuration

Enable `--enable-helm` for **all** Kustomize applications by updating the `argocd-cm` ConfigMap.

### Update argocd-cm ConfigMap

```bash
kubectl edit configmap argocd-cm -n argocd
```

Add the following to the `data` section:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: "--enable-helm"
```

Or patch it directly:

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'
```

**Note**: This enables Helm inflation for **all** Kustomize applications in your ArgoCD instance.

## Verification

### Check Application Status

```bash
# List applications
kubectl get applications -n argocd

# Get detailed status
kubectl get application airflow-dev -n argocd -o yaml

# Check sync status
argocd app get airflow-dev
```

### View Sync Details in ArgoCD UI

1. Open ArgoCD UI
2. Navigate to the `airflow-dev` application
3. Check the "Sync Status" and "Health Status"
4. View the resources tree to see all deployed components

### Manual Sync

If automatic sync is not enabled, sync manually:

```bash
argocd app sync airflow-dev
```

## Troubleshooting

### Error: "must specify --enable-helm"

**Symptom**: ArgoCD Application shows sync error with message about `--enable-helm`

**Solution**: Ensure `buildOptions: "--enable-helm"` is set in the Application spec, or the global config is updated.

### Application Not Syncing

**Check**:
```bash
# View application details
argocd app get airflow-dev

# View recent events
kubectl describe application airflow-dev -n argocd
```

### Helm Chart Not Being Downloaded

**Check ArgoCD repo-server logs**:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Multiple Environments

To deploy to multiple environments (dev, staging, prod):

### Create Applications for Each Environment

**airflow-staging-application.yaml**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: airflow-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nsalexamy/service-foundry.git
    targetRevision: main
    path: documents/blog/kustomize-helm-chart/airflow-gitops/staging
    kustomize:
      buildOptions: "--enable-helm"
  destination:
    server: https://kubernetes.default.svc
    namespace: airflow-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Using ApplicationSet

For managing multiple environments with a single resource:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: airflow-environments
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        namespace: airflow-dev
      - env: staging
        namespace: airflow-staging
      - env: prod
        namespace: airflow-prod
  
  template:
    metadata:
      name: 'airflow-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/nsalexamy/service-foundry.git
        targetRevision: main
        path: 'documents/blog/kustomize-helm-chart/airflow-gitops/{{env}}'
        kustomize:
          buildOptions: "--enable-helm"
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Best Practices

1. **Use Per-Application Configuration**: More explicit and easier to troubleshoot
2. **Enable Automated Sync**: Let ArgoCD automatically sync changes from Git
3. **Enable Prune**: Remove resources that are no longer defined in Git
4. **Enable SelfHeal**: Revert manual changes to match Git state
5. **Use ApplicationSets**: For managing multiple similar environments
6. **Pin Helm Chart Versions**: Avoid unexpected updates (already done: `version: 1.18.0`)

## Security Considerations

The `--enable-helm` flag allows Kustomize to download and inflate Helm charts from remote repositories. Ensure:

1. **Trust the Helm repositories** you're using
2. **Pin chart versions** to avoid unexpected changes
3. **Review values files** for sensitive configurations
4. **Use private repos** with appropriate credentials if needed
5. **Scan Helm charts** for vulnerabilities before deployment

## References

- [ArgoCD Kustomize Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Kustomize Helm Chart Inflation](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)
