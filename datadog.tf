# Observabilidade corporativa (ADR-012, CARD-31) — Datadog Agent como DaemonSet no EKS,
# consumindo as métricas/traces já exportados via OTel (ADR-008) através de OTLP.
# Mantido em paralelo à stack Prometheus/Grafana/Loki/Jaeger local, não em substituição.

resource "kubernetes_secret" "datadog_api_key" {
  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.observabilidade.metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.observabilidade.metadata[0].name

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_api_key.metadata[0].name
  }

  set {
    name  = "datadog.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  # Recebe métricas/traces via OTLP da instrumentação OTel já existente na aplicação (ADR-008),
  # sem exigir uma segunda instrumentação.
  set {
    name  = "datadog.otlp.receiver.protocols.grpc.enabled"
    value = "true"
  }

  set {
    name  = "datadog.otlp.receiver.protocols.http.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  depends_on = [kubernetes_secret.datadog_api_key]
}

# ── Dashboard: latência das APIs e healthchecks (ADR-012, CARD-31) ──
resource "datadog_dashboard" "apis" {
  title       = "${var.cluster_name} — APIs (latência e uptime)"
  description = "Latência das APIs Atendimento/Estoque e healthchecks — ADR-012/CARD-31"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "Latência p95 por serviço"
      request {
        q            = "p95:trace.aspnet_core.request.duration{service:atendimento} by {resource_name}"
        display_type = "line"
      }
      request {
        q            = "p95:trace.aspnet_core.request.duration{service:estoque} by {resource_name}"
        display_type = "line"
      }
    }
  }

  widget {
    check_status_definition {
      title    = "Healthcheck — Atendimento e Estoque"
      check    = "http.can_connect"
      grouping = "cluster"
      group_by = ["host"]
      tags     = ["service:atendimento", "service:estoque"]
    }
  }
}

# ── Dashboard: recursos de Kubernetes (CPU, memória) ──
resource "datadog_dashboard" "kubernetes_resources" {
  title       = "${var.cluster_name} — Recursos Kubernetes"
  description = "CPU e memória por pod/deployment — CARD-31"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "CPU por pod (namespace oficina-mecanica)"
      request {
        q            = "avg:kubernetes.cpu.usage.total{kube_namespace:oficina-mecanica} by {pod_name}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Memória por pod (namespace oficina-mecanica)"
      request {
        q            = "avg:kubernetes.memory.usage{kube_namespace:oficina-mecanica} by {pod_name}"
        display_type = "line"
      }
    }
  }
}

# ── Dashboard: negócio — ordens de serviço (CARD-31) ──
resource "datadog_dashboard" "ordens_servico" {
  title       = "${var.cluster_name} — Ordens de Serviço"
  description = "Volume, tempo por status e erros de integração — CARD-31"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "Volume diário de OS abertas"
      request {
        q            = "sum:oficina.os.abertas{*}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Tempo médio por status (Diagnóstico, Execução, Finalização)"
      request {
        q            = "avg:oficina.os.tempo_status{status:em_diagnostico}"
        display_type = "line"
      }
      request {
        q            = "avg:oficina.os.tempo_status{status:em_execucao}"
        display_type = "line"
      }
      request {
        q            = "avg:oficina.os.tempo_status{status:finalizada}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Erros nas integrações (HTTP Atendimento→Estoque, consumo RabbitMQ)"
      request {
        q            = "sum:oficina.integracao.erro{*} by {tipo}.as_count()"
        display_type = "bars"
      }
    }
  }
}

# ── Alerta: falha no processamento de ordens de serviço (dead letter queue) ──
resource "datadog_monitor" "dlq_baixa_estoque" {
  name    = "${var.cluster_name} — mensagens na dead letter queue estoque.baixa_error"
  type    = "metric alert"
  message = <<-EOT
    Mensagens acumulando na dead letter queue `estoque.baixa_error` — baixa de estoque falhando
    após esgotar as tentativas de reprocessamento (ADR-001).
    Ver diagrama de sequência de abertura/finalização de OS em tech-challenge-docs.
    @pagerduty-oficina-mecanica
  EOT

  query = "sum(last_15m):sum:rabbitmq.queue.messages{queue:estoque.baixa_error} > 0"

  monitor_thresholds {
    critical = 0
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["service:estoque", "card:CARD-31"]
}

# ── Alerta: taxa de erro elevada nas APIs ──
resource "datadog_monitor" "taxa_erro_apis" {
  name    = "${var.cluster_name} — taxa de erro elevada (Atendimento/Estoque)"
  type    = "metric alert"
  message = <<-EOT
    Taxa de erro HTTP 5xx acima do threshold nas APIs Atendimento/Estoque.
    @pagerduty-oficina-mecanica
  EOT

  query = "sum(last_10m):sum:trace.aspnet_core.request.errors{service:atendimento OR service:estoque}.as_count() / sum:trace.aspnet_core.request.hits{service:atendimento OR service:estoque}.as_count() > 0.05"

  monitor_thresholds {
    critical = 0.05
    warning  = 0.02
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = ["card:CARD-31"]
}
