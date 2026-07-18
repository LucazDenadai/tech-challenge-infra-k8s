variable "cluster_name" {
  description = "Nome do cluster Kind"
  type        = string
  default     = "oficina-mecanica"
}

variable "kubernetes_version" {
  description = "Versão da imagem do nó Kind"
  type        = string
  default     = "v1.31.0"
}
