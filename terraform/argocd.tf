resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "10.4.0"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_kubernetes_cluster_node_pool.app
  ]
}
