# ============================================================
# Karpenter infrastructure + controller
# Pre-req: Tier 2 cluster with the Pod Identity Agent add-on (02-eks-addons) and its managed node group
# (Karpenter cannot start on nodes it creates itself, so the node group keeps running the controller).
# ============================================================

# ---------- 1. Discovery tags: how Karpenter finds subnets and the node security group ----------
data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = [var.private_subnet_name_pattern]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.this.vpc_config[0].vpc_id]
  }
}

resource "aws_ec2_tag" "subnet_discovery" {
  for_each    = toset(data.aws_subnets.private.ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "sg_discovery" {
  resource_id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# ---------- 2. IAM (controller + node role), SQS interruption queue, EventBridge rules, access entry ----------
# The community module wraps ~200 lines of IAM. Read its README to see exactly what it creates.
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.37"

  cluster_name = var.cluster_name

  enable_v1_permissions           = true    # policies for Karpenter v1.x
  enable_pod_identity             = true
  create_pod_identity_association = true    # ServiceAccount "karpenter" in kube-system -> controller role
  namespace                       = "kube-system"

  # role name for the nodes Karpenter creates. Must match EC2NodeClass.spec.role
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

# ---------- 3. The controller itself ----------
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  wait       = true

  values = [yamlencode({
    replicas = 1                                   # practice cluster. Production: 2 (default)
    settings = {
      clusterName       = var.cluster_name
      interruptionQueue = module.karpenter.queue_name   # THIS enables spot interruption handling
    }
    serviceAccount = { name = "karpenter" }
    nodeSelector   = { role = "general" }          # run on the managed node group (label set in Tier 2)
    controller = {
      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
  })]

  depends_on = [module.karpenter, aws_ec2_tag.subnet_discovery, aws_ec2_tag.sg_discovery]
}
