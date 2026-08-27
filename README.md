# tech-challenge-infra-k8s

Terraform que provisiona o cluster Kubernetes usado pelo [Tech-challenge](https://github.com/LucazDenadai/tech-challenge) (Atendimento + Estoque).

Documentação arquitetural completa (ADRs, RFCs, diagramas) em [tech-challenge-docs](https://github.com/LucazDenadai/tech-challenge-docs).

Diagramas relevantes para este repositório:

| Diagrama | Conteúdo |
|---|---|
| [Componentes](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/diagramas/diagrama-componentes.md) | VPC, EKS, API Gateway e como este repositório se conecta ao RDS e à Lambda |
| [Sequência — Autenticação via CPF](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/diagramas/diagrama-sequencia-autenticacao.md) | Fluxo completo — o API Gateway provisionado aqui faz apenas proxy, sem authorizer ([ADR-013](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-013-autenticacao-authorize-aspnet-nao-api-gateway.md)) |

## Estado atual

Provisiona um cluster **Amazon EKS** real (migração do Kind local do ADR-005, conforme [ADR-009](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-009-migracao-aws-e-separacao-repositorios.md), [ADR-010](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-010-sizing-e-regiao-aws.md) e [ADR-011](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-011-bootstrap-aws-backend-remoto-oidc.md)). Ver critérios de aceite em [CARD-27](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/cards/05-fase3-aws/CARD-27-cicd-multi-repo.md) e [CARD-28](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/cards/05-fase3-aws/CARD-28-infra-aws-terraform.md).

## O que é criado

| Recurso | Tipo | Descrição |
|---|---|---|
| VPC | `terraform-aws-modules/vpc` | Subnets públicas (ALB) e privadas (nós EKS) |
| Cluster EKS | `terraform-aws-modules/eks` | Control plane + node group (2× `t3.small`, ADR-010) |
| Namespace `oficina-mecanica` | K8s Namespace | Onde os serviços de aplicação rodam |
| Namespace `observabilidade` | K8s Namespace | Jaeger, Prometheus, Grafana |
| AWS Load Balancer Controller | Helm chart | Traduz `Ingress` em Application Load Balancer real |
| EBS CSI Driver | `aws_eks_addon` + IRSA | Provisiona volumes EBS para PVCs (ex: RabbitMQ) |
| Ingress `oficina-mecanica-ingress` | `kubernetes_ingress_v1` | Roteia `/atendimento` e `/estoque` para os services |
| API Gateway (HTTP API) | `aws_apigatewayv2_*` | Proxy genérico (`ANY /{proxy+}`) para o hostname do ALB — sem authorizer, ver [ADR-013](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-013-autenticacao-authorize-aspnet-nao-api-gateway.md) |
| Datadog Agent | Helm chart (`datadog.tf`) | Observabilidade corporativa — [ADR-012](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-012-observabilidade-corporativa-datadog.md), dashboards/monitors como código |

A integração entre o API Gateway e a Lambda de autenticação (`tech-challenge-lambda`, CARD-29) é feita diretamente no repositório da Lambda (`aws_apigatewayv2_route`/`aws_apigatewayv2_integration` apontando para este API Gateway via `terraform_remote_state`) — este repositório provisiona apenas o proxy genérico.

**Custo desligado por padrão:** por controle de orçamento (ver ADR-009, seção de mitigação de custo), este ambiente é destruído fora de janelas de demonstração/avaliação. Se `terraform plan` mostrar `0 resources`, é porque o ambiente está desligado no momento — normal, não é um erro.

## Pré-requisitos

- Conta AWS com bootstrap já feito (bucket S3 + DynamoDB de state, OIDC/IAM — ver [ADR-011](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-011-bootstrap-aws-backend-remoto-oidc.md))
- Service-linked roles `AWSServiceRoleForAmazonEKS` e `AWSServiceRoleForElasticLoadBalancing` já existentes na conta (criadas uma única vez via `aws iam create-service-linked-role` — necessário porque a role de CI/CD por si só não pode criá-las na primeira vez que o EKS/ALB é usado na conta, mesmo com `iam:CreateServiceLinkedRole` na policy)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure`)
- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (para inspecionar o cluster após o apply)

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars

export TF_VAR_datadog_api_key="..."   # Datadog → Organization Settings → API Keys
export TF_VAR_datadog_app_key="..."   # Datadog → Organization Settings → Application Keys

terraform init
terraform plan
terraform apply
```

No pipeline, `TF_VAR_datadog_api_key`/`TF_VAR_datadog_app_key` vêm dos GitHub Secrets `DATADOG_API_KEY`/`DATADOG_APP_KEY` (ver `.github/workflows/terraform.yml`).

Após o apply, gere o kubeconfig local:

```bash
aws eks update-kubeconfig --region us-east-1 --name oficina-mecanica
```

Aplique os manifestos de aplicação (mantidos no repositório [Tech-challenge](https://github.com/LucazDenadai/Tech-challenge)):

```bash
kubectl apply -f ../Tech-challenge/k8s/ -n oficina-mecanica
```

**Lembrete de custo (ADR-010/ADR-011):** este ambiente é provisionado sob demanda, não 24/7. Rode `terraform destroy` ao final de cada sessão de trabalho.

```bash
terraform destroy
```

## Outputs

| Output | Descrição |
|---|---|
| `cluster_name` | Nome do cluster EKS criado |
| `cluster_endpoint` | Endereço do API server |
| `update_kubeconfig_command` | Comando pronto para gerar o kubeconfig local |
| `vpc_id` | ID da VPC criada |
| `vpc_cidr` | CIDR block da VPC — consumido por `tech-challenge-infra-db` para liberar acesso ao RDS |
| `private_subnet_ids` | IDs das subnets privadas onde os nós EKS rodam — consumido por `tech-challenge-infra-db` para o RDS subnet group |
| `node_security_group_id` | Security group dos nós EKS — consumido por `tech-challenge-infra-db` para liberar acesso ao RDS |
| `alb_hostname` | Hostname do ALB provisionado pelo Ingress |
| `api_gateway_url` | URL pública do API Gateway |

Os três primeiros marcados acima (`vpc_cidr`, `private_subnet_ids`, `node_security_group_id`) e `vpc_id` são lidos por outros repositórios via `terraform_remote_state` — não altere seus nomes sem atualizar quem os consome (`tech-challenge-infra-db/main.tf`, `tech-challenge-lambda/infra/main.tf`).

## O que NÃO commitar

| Arquivo/Pasta | Motivo |
|---|---|
| `terraform.tfvars` | Pode conter valores específicos de ambiente |
| `terraform.tfstate` / `.backup` | Não se aplica — state fica remoto no S3 (ver `versions.tf`) |
| `.terraform/` | Cache de providers |

Todos já estão no `.gitignore`.
