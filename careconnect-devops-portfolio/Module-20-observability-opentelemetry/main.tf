# ---------- cert-manager (the ADOT operator needs it for its webhooks) ----------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"

  set {
    name  = "crds.enabled"     # older chart versions used installCRDs=true
    value = "true"
  }
}

# ---------- ADOT operator as an EKS add-on ----------
resource "aws_eks_addon" "adot" {
  cluster_name = var.cluster_name
  addon_name   = "adot"
  depends_on   = [helm_release.cert_manager]
}

# ---------- Amazon Managed Prometheus (metrics storage) ----------
resource "aws_prometheus_workspace" "this" {
  alias = "${var.cluster_name}-metrics"
}

# ---------- IAM for the collector (Pod Identity) ----------
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "collector" {
  name               = "${var.cluster_name}-adot-collector"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "collector" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess",            # traces -> X-Ray
    "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess", # metrics -> AMP
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",       # logs/metrics -> CloudWatch
  ])
  role       = aws_iam_role.collector.name
  policy_arn = each.value
}

resource "aws_eks_pod_identity_association" "collector" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "adot-collector"       # the operator names the SA <collector-name>-collector
  role_arn        = aws_iam_role.collector.arn
}

# ---------- Optional: container stdout logs -> CloudWatch Logs ----------
resource "aws_iam_role" "cw_agent" {
  count              = var.enable_container_logs ? 1 : 0
  name               = "${var.cluster_name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  count      = var.enable_container_logs ? 1 : 0
  role       = aws_iam_role.cw_agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch" {
  count        = var.enable_container_logs ? 1 : 0
  cluster_name = var.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  pod_identity_association {
    role_arn        = aws_iam_role.cw_agent[0].arn
    service_account = "cloudwatch-agent"
  }
}

# ---------- Optional: Amazon Managed Grafana ----------
resource "aws_grafana_workspace" "this" {
  count                    = var.create_grafana ? 1 : 0
  name                     = "${var.cluster_name}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]        # requires IAM Identity Center
  permission_type          = "SERVICE_MANAGED"
  data_sources             = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
}
