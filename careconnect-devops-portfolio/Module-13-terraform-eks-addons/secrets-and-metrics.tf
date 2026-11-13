# Secrets Store CSI Driver + AWS provider (ASCP). Pairs with 07-secrets/eks-only/ from Tier 1.
resource "helm_release" "secrets_store_csi" {
  name       = "csi-secrets-store"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"

  set {
    name  = "syncSecret.enabled"   # allows secretObjects (sync to a K8s Secret)
    value = "true"
  }
  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

resource "helm_release" "ascp" {
  name       = "secrets-provider-aws"
  namespace  = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  depends_on = [helm_release.secrets_store_csi]
}

# Metrics Server: required for `kubectl top` and the HPA (see 05-hpa)
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
}
