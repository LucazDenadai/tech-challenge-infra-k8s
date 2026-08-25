# tech-challenge-infra-k8s

Terraform que provisiona o cluster Kubernetes usado pelo [Tech-challenge](https://github.com/LucazDenadai/Tech-challenge) (Atendimento + Estoque).

Documentação arquitetural completa (ADRs, RFCs, diagramas) em [tech-challenge-docs](https://github.com/LucazDenadai/tech-challenge-docs).

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
| Ingress `oficina-mecanica-ingress` | `kubernetes_ingress_v1` | Roteia `/atendimento` e `/estoque` para os services |
| API Gateway (HTTP API) | `aws_apigatewayv2_*` | Rota proxy pública apontando para o hostname do ALB |

A rota de autenticação via Lambda (CARD-29) ainda não existe — será adicionada ao API Gateway quando a Lambda for provisionada em `tech-challenge-lambda`.

## Pré-requisitos

- Conta AWS com bootstrap já feito (bucket S3 + DynamoDB de state, OIDC/IAM — ver [ADR-011](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-011-bootstrap-aws-backend-remoto-oidc.md))
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure`)
- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (para inspecionar o cluster após o apply)

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

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
| `alb_hostname` | Hostname do ALB provisionado pelo Ingress |
| `api_gateway_url` | URL pública do API Gateway |

## O que NÃO commitar

| Arquivo/Pasta | Motivo |
|---|---|
| `terraform.tfvars` | Pode conter valores específicos de ambiente |
| `terraform.tfstate` / `.backup` | Não se aplica — state fica remoto no S3 (ver `versions.tf`) |
| `.terraform/` | Cache de providers |

Todos já estão no `.gitignore`.
