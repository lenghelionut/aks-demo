resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  # Reduce resource footprint for demo
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "24h"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "grafana.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    azurerm_kubernetes_cluster_node_pool.app,
    helm_release.nginx_ingress
  ]
}

resource "kubectl_manifest" "grafana_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: grafana-ingress
      namespace: monitoring
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - grafana.aksdemo.lenghel.dev
        secretName: grafana-aksdemo-lenghel-dev-tls
      rules:
      - host: grafana.aksdemo.lenghel.dev
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-grafana
                port:
                  number: 80
  YAML

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.nginx_ingress,
    helm_release.cert_manager
  ]
}
