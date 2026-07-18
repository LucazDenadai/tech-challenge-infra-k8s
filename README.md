# tech-challenge-infra-k8s

Terraform que provisiona o cluster Kubernetes usado pelo [Tech-challenge](https://github.com/LucazDenadai/Tech-challenge) (Atendimento + Estoque).

Documentação arquitetural completa (ADRs, RFCs, diagramas) em [tech-challenge-docs](https://github.com/LucazDenadai/tech-challenge-docs).

## Estado atual

Provisiona um cluster **Kind** local (Kubernetes in Docker) — herdado do ADR-005 da Fase 2. A migração para **Amazon EKS** (requisito da Fase 3, ver [ADR-009](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-009-migracao-aws-e-separacao-repositorios.md)) está prevista no [CARD-28](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/cards/05-fase3-aws/CARD-28-infra-aws-terraform.md).

## O que é criado

| Recurso | Tipo | Descrição |
|---|---|---|
| Cluster Kind | Kubernetes | Cluster K8s local rodando dentro do Docker |
| Namespace `oficina-mecanica` | K8s Namespace | Onde os serviços de aplicação rodam |
| Namespace `observabilidade` | K8s Namespace | Reservado para Jaeger, Prometheus, Grafana |

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) rodando
- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/install)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) instalado

## Como usar

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Após o apply, aplique os manifestos da aplicação (mantidos no repositório [Tech-challenge](https://github.com/LucazDenadai/Tech-challenge)):

```bash
kubectl apply -f ../Tech-challenge/k8s/ -n oficina-mecanica
```

Para destruir:

```bash
terraform destroy
```

## Outputs

| Output | Descrição |
|---|---|
| `cluster_name` | Nome do cluster criado |
| `cluster_endpoint` | Endereço do API server |
| `kubeconfig` | Kubeconfig para conectar ao cluster (sensitive) |

## O que NÃO commitar

| Arquivo/Pasta | Motivo |
|---|---|
| `terraform.tfvars` | Pode conter valores específicos de ambiente |
| `terraform.tfstate` / `.backup` | Estado da infra, pode conter dados sensíveis |
| `.terraform/` | Cache de providers |

Todos já estão no `.gitignore`.
