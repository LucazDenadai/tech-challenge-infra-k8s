variable "aws_region" {
  description = "Região AWS (decidida no ADR-010)"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "oficina-mecanica"
}

variable "kubernetes_version" {
  description = "Versão do control plane EKS"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Tipo de instância dos nós do EKS (sizing definido no ADR-010)"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Número de nós do node group (sizing definido no ADR-010)"
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}
