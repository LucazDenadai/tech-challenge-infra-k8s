resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = "kindest/node:${var.kubernetes_version}"
  wait_for_ready = true

  # kind_config é o mesmo YAML que você escreveria num arquivo kind-config.yaml
  # extra_port_mappings expõe portas do container para o host — necessário
  # para acessar os serviços via NodePort fora do cluster
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
      }

      extra_port_mappings {
        container_port = 30081
        host_port      = 30081
      }

      extra_port_mappings {
        container_port = 30090
        host_port      = 30090
      }

      extra_port_mappings {
        container_port = 30086
        host_port      = 30086
      }

      extra_port_mappings {
        container_port = 30317
        host_port      = 30317
      }

      extra_port_mappings {
        container_port = 30300
        host_port      = 30300
      }
    }
  }
}

# O provider kubernetes lê o kubeconfig diretamente como string.
# kind_cluster.this.kubeconfig já contém tudo que o kubectl precisaria —
# endpoint, certificados e credenciais — no formato padrão YAML.
provider "kubernetes" {
  config_path = kind_cluster.this.kubeconfig_path
}

resource "kubernetes_namespace" "oficina_mecanica" {
  depends_on = [kind_cluster.this]

  metadata {
    name = "oficina-mecanica"
    labels = {
      app = "oficina-mecanica"
    }
  }
}

resource "kubernetes_namespace" "observabilidade" {
  depends_on = [kind_cluster.this]

  metadata {
    name = "observabilidade"
    labels = {
      app = "observabilidade"
    }
  }
}
