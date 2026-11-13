# ArgoCD installed with Helm. After this, EVERYTHING else is deployed from Git.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"

  values = [yamlencode({
    configs = { params = { "server.insecure" = true } }   # TLS is handled at the ALB/port-forward in this practice setup
  })]

  depends_on = [helm_release.metrics_server]
}
