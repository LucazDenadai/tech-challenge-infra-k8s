# Ingress criado pelo Terraform (não como manifesto solto aplicado via kubectl) para que o
# API Gateway consiga referenciar o hostname do ALB gerado, resolvido no mesmo apply.
resource "kubernetes_ingress_v1" "oficina_mecanica" {
  metadata {
    name      = "oficina-mecanica-ingress"
    namespace = kubernetes_namespace.oficina_mecanica.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/atendimento"
          path_type = "Prefix"
          backend {
            service {
              name = "atendimento-svc"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/estoque"
          path_type = "Prefix"
          backend {
            service {
              name = "estoque-svc"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.alb_controller]
}

# O provisionamento do ALB pelo controller é assíncrono — aguarda o hostname aparecer no status
# do Ingress antes do apply seguir para o API Gateway, que depende desse valor.
resource "time_sleep" "wait_for_alb" {
  depends_on      = [kubernetes_ingress_v1.oficina_mecanica]
  create_duration = "60s"
}

data "kubernetes_ingress_v1" "oficina_mecanica" {
  metadata {
    name      = kubernetes_ingress_v1.oficina_mecanica.metadata[0].name
    namespace = kubernetes_ingress_v1.oficina_mecanica.metadata[0].namespace
  }

  depends_on = [time_sleep.wait_for_alb]
}
