resource "kubectl_manifest" "argocd_app_dev" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: aks-demo-dev
      namespace: argocd
      labels:
        environment: dev
    spec:
      project: default
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: main
        path: k8s/overlays/dev
      destination:
        server: https://kubernetes.default.svc
        namespace: aks-demo-dev
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
        - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_app_staging" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: aks-demo-staging
      namespace: argocd
      labels:
        environment: staging
    spec:
      project: default
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: main
        path: k8s/overlays/staging
      destination:
        server: https://kubernetes.default.svc
        namespace: aks-demo-staging
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
        - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_app_prod" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: aks-demo-prod
      namespace: argocd
      labels:
        environment: prod
    spec:
      project: default
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: main
        path: k8s/overlays/prod
      destination:
        server: https://kubernetes.default.svc
        namespace: aks-demo-prod
      syncPolicy:
        syncOptions:
        - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}
