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
  # quem quer que execute o terraform apply que cria o cluster pela primeira vez. Sem
  # isso, kubectl/terraform apply seriam barrados dentro do cluster mesmo já
  # autenticados na AWS via IAM, porque IAM e RBAC do Kubernetes são mecanismos
  # separados. Só cobre o criador original do cluster — não a role usada em applies
  # subsequentes, por isso o access_entries abaixo também é necessário.
  enable_cluster_creator_admin_permissions = true

  # A role usada pelos pipelines (ADR-011) faz applies subsequentes ao cluster já
  # existente, então não é coberta por enable_cluster_creator_admin_permissions —
  # precisa da própria entry. Tentativa anterior de registrar isso ANTES do primeiro
  # apply causou ResourceInUseException (a mesma identidade tentando se registrar
  # duas vezes, uma via cluster_creator e outra aqui) — corrigido registrando só
  # depois que o cluster já existia e o "criador" (identidade local que rodou o
  # primeiro apply) já não era mais a mesma role do pipeline.
  access_entries = {
    github_actions = {
      principal_arn = "arn:aws:iam::575225901719:role/tech-challenge-github-actions"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
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
