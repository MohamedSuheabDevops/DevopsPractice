# ---------- IAM: let ExternalDNS edit ONE hosted zone ----------
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "route53" {
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.zone_id}"]   # least privilege: this zone only
  }
  statement {
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy" "external_dns" {
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.route53.json
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn
}

# ---------- ExternalDNS itself ----------
resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"

  values = [yamlencode({
    provider       = { name = "aws" }
    serviceAccount = { create = true, name = "external-dns" }
    sources        = ["ingress", "service"]      # watch Ingresses and Services
    domainFilters  = [var.domain_name]           # NEVER leave this empty
    txtOwnerId     = var.cluster_name            # marks records this cluster owns (via TXT records)
    policy         = var.dns_policy
    interval       = "1m"
    env            = [{ name = "AWS_DEFAULT_REGION", value = var.region }]
    extraArgs      = ["--aws-zone-type=public"]
  })]

  depends_on = [aws_eks_pod_identity_association.external_dns]
}
