# API Gateway HTTP API — rota proxy para o ALB do EKS (via Ingress).
# A rota de autenticação (Lambda, CARD-29) é adicionada quando a Lambda existir;
# por enquanto o API Gateway só encaminha para o ALB.
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.cluster_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "alb_proxy" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${data.kubernetes_ingress_v1.oficina_mecanica.status[0].load_balancer[0].ingress[0].hostname}/{proxy}"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "alb_proxy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb_proxy.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}
