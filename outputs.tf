output "cluster_name" {
  description = "Nome do cluster EKS criado"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endereço do API server do cluster Kubernetes"
  value       = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  description = "Comando para gerar o kubeconfig local (requer aws-cli configurado)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block da VPC (usado pelo infra-db para liberar acesso ao RDS)"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas onde os nós EKS rodam (usado pelo infra-db para o RDS subnet group)"
  value       = module.vpc.private_subnets
}

output "node_security_group_id" {
  description = "Security group compartilhado dos nós EKS (usado pelo infra-db para liberar acesso ao RDS)"
  value       = module.eks.node_security_group_id
}

output "alb_hostname" {
  description = "Hostname do Application Load Balancer provisionado pelo Ingress"
  value       = data.kubernetes_ingress_v1.oficina_mecanica.status[0].load_balancer[0].ingress[0].hostname
}

output "api_gateway_url" {
  description = "URL pública do API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
