# Cluster EKS + node group — módulo oficial (ADR-010)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_desired_size
      max_size       = var.node_desired_size
      desired_size   = var.node_desired_size
    }
  }

  # Necessário para o AWS Load Balancer Controller assumir uma IAM role via IRSA
  enable_irsa = true

  # Registra automaticamente como admin do cluster (RBAC do EKS, via EKS Access Entry)
  # quem quer que execute o terraform apply que cria o cluster — hoje é a role
  # tech-challenge-github-actions (ADR-011), rodando via pipeline OIDC. Sem isso,
  # kubectl/terraform apply seriam barrados dentro do cluster mesmo já autenticados
  # na AWS via IAM, porque IAM e RBAC do Kubernetes são mecanismos separados.
  enable_cluster_creator_admin_permissions = true
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

resource "kubernetes_namespace" "oficina_mecanica" {
  metadata {
    name = "oficina-mecanica"
    labels = {
      app = "oficina-mecanica"
    }
  }
}

resource "kubernetes_namespace" "observabilidade" {
  metadata {
    name = "observabilidade"
    labels = {
      app = "observabilidade"
    }
  }
}
