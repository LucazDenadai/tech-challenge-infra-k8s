# Runbooks dos alertas da Fase 4

Um runbook por alerta de `prometheus/alertas.yml` (CARD-42b, ADR-022). Cada regra aponta para a seção com o mesmo nome.

Onde olhar, na demonstração local (`kind/subir.sh`):

| Ferramenta | Endereço | Para quê |
|---|---|---|
| Grafana, dashboard **Saga da OS** | http://localhost:13000 | Estado agregado, etapa mais antiga, DLQ, logs de uma Saga |
| Grafana, dashboard **Serviços** | http://localhost:13000 | Disponibilidade, erros, latência, outbox, filas, pagamento e execução |
| Prometheus | http://localhost:19090/alerts | Alertas disparados e a expressão de cada um |
| Jaeger | http://localhost:16690 | Traces; busca por tag `correlation_id=<id da Saga>` |
| RabbitMQ | http://localhost:15680 | Mensagens nas filas e nas DLQs (`*.dlq`) |

O **correlationId** é o id da Saga (ADR-017). Ele aparece nos logs dos três serviços e na tag `correlation_id` dos spans de mensagem. No Grafana, cole-o na variável `correlationId` do dashboard da Saga. No Explore do Loki, use `{namespace="oficina-mecanica"} | correlation_id="<id>"`.

Comandos de apoio usam `kubectl -n oficina-mecanica`. As rotas de Admin ficam no Swagger do OS (http://localhost:8090/os/swagger).

---

## SagaEmAcaoManual

**O que significa:** uma ou mais Sagas pararam em `ManualActionRequired`. O sistema não decide sozinho, e a OS fica parada até o Admin agir (ADR-020).

**Causas comuns, pelo rótulo `causa` do painel "Ações manuais por causa":**

| Causa | Situação |
|---|---|
| `PrazoEsgotado` | Um participante não respondeu ao comando nem aos reenvios (CARD-40b) |
| `PagamentoDivergente` | O pagamento foi aprovado com valor ou moeda diferentes do orçamento aprovado |
| `EstornoFalhou` | O estorno de um pagamento aprovado falhou |

**O que fazer:**

1. No dashboard da Saga, veja quantas Sagas estão em ação manual. Nos logs, filtre por `nivel="Error"` e procure `Saga parada em ação manual`: a linha tem a causa, o motivo e o `OsId`.
2. Consulte a Saga pela API do OS (`GET /os/ordens-servico/{osId}/saga`, perfil Admin ou Atendente) para ver estado, causa, motivo e transições.
3. Resolva como Admin em `POST /os/ordens-servico/{osId}/saga/resolucao`, com a ação e o motivo (ficam no histórico):
   - **Retomar**, se a causa já foi resolvida (por exemplo, o participante voltou): a Saga reenvia os comandos da etapa.
   - **Cancelar**, se o fluxo não deve continuar: a Saga compensa o que foi feito (libera a reserva, estorna o pagamento). Pagamento divergente só aceita Cancelar.
5. Confirme que `os_sagas_por_estado{estado="ManualActionRequired"}` voltou a 0.

---

## PagamentoPendente

**O que significa:** há Saga em `AwaitingPayment` ou `ReconcilingPayment` há mais de 30 minutos. O Pix vence em 30 minutos (ADR-019), então o webhook ou a reconciliação do Billing já deveriam ter trazido aprovação, recusa ou expiração. Em `ReconcilingPayment`, o Billing ainda não sabe o resultado (`PaymentOutcomeUnknown`) e continua consultando o provedor.

**O que fazer:**

1. No dashboard **Serviços**, veja "Notificações do webhook" e "Chamadas ao Mercado Pago". Se não houver notificações, o webhook pode não estar chegando (túnel da Cloudflare desligado, CARD-39b).
2. Nos logs do Billing (`{servico="billing"}`), procure a reconciliação do pagamento pelo `correlationId`.
3. Se o provedor responde erro, `billing_mercadopago_chamadas_total{resultado!="sucesso"}` sobe. Confira as credenciais e o status do Mercado Pago.
4. Na demonstração com o provedor simulado, aprove ou recuse pelo simulador do Billing (`POST /billing/simulador/pagamentos/{referencia}/status`).
5. Depois de `MaxTentativasReconciliacao` falhas técnicas seguidas (10 por padrão), o pagamento para em ação manual **no Billing**: `billing_pagamentos_reconciliacao_manual_total` sobe e a Saga continua esperando. Confira o pagamento no painel do Mercado Pago antes de qualquer ação na Saga.

---

## SagaParada

**O que significa:** uma Saga está há mais de 10 minutos em um estado que espera resposta de outro serviço (por exemplo, `ReservingInventory` ou `StartingExecution`). O prazo é de 5 minutos por tentativa, com até 3 reenvios (CARD-40b); sem resposta, a Saga vai para ação manual aos 20 minutos. Passar de 10 minutos quer dizer que o participante não respondeu nem ao primeiro reenvio.

**O que fazer:**

1. O rótulo `estado` diz quem deveria responder:

   | Estado | Participante |
   |---|---|
   | `RequestingQuote` | Billing (orçamento) |
   | `ReservingInventory`, `ReleasingReservation`, `StartingExecution`, `CancellingExecution` | Operações |
   | `CreatingPayment`, `Compensating` (estorno) | Billing |

2. No dashboard **Serviços**, confira se o participante está no ar e se a fila de entrada dele está acumulando ("Mensagens prontas nas filas").
3. Veja a outbox do OS: `outbox_publicacoes_total{servico="os",resultado="falha"}` subindo indica RabbitMQ fora do ar. Os comandos ficam na outbox e saem quando o broker volta.
4. Se o participante caiu, `kubectl -n oficina-mecanica rollout restart deployment/<servico>`. Os comandos reenviados têm a mesma `idempotencyKey`, então repetir não duplica efeito.
5. Esgotados os reenvios, a Saga vai para ação manual (**SagaEmAcaoManual**).

---

## DlqCrescendo

**O que significa:** um serviço recebeu mensagem que não consegue processar e a mandou para a DLQ (`<fila>.dlq`): fora do contrato, sem Saga correspondente ou de outra Saga.

**O que fazer:**

1. O rótulo `queue` (`<servico>.<canal>.dlq`) diz quem rejeitou e de qual canal veio.
2. No RabbitMQ, abra essa fila e veja os cabeçalhos da mensagem: `x-motivo` traz o motivo da rejeição, e `x-correlation-id` traz a Saga.
3. Nos logs do serviço, procure `Mensagem enviada para a DLQ`.
4. Contrato divergente: compare o payload com `contratos/asyncapi-saga-os.yaml` (o CI de cada serviço compara a cópia com a spec do `tech-challenge-docs`). Corrija o produtor; não reprocesse a mensagem errada.
5. Saga inexistente: a mensagem é de um ambiente ou teste antigo; pode ser descartada.
6. O alerta continua ativo enquanto houver mensagem na DLQ: depois de analisar, mova ou descarte a mensagem pelo painel do RabbitMQ.

---

## DeployIndisponivel

**O que significa:** um Deployment do namespace `oficina-mecanica` tem réplicas indisponíveis há 5 minutos. Em geral, é uma imagem que não sobe ou uma readiness que não fica pronta.

**O que fazer:**

1. `kubectl -n oficina-mecanica get pods` e `kubectl -n oficina-mecanica describe deployment/<nome>`: veja eventos de `ImagePullBackOff`, `CrashLoopBackOff` ou probe falhando.
2. `kubectl -n oficina-mecanica logs deployment/<nome>`: falha de migration, de conexão com o banco ou com o RabbitMQ aparece aqui.
3. O readiness (`/<servico>/ready`) depende do banco e do consumidor da Saga. Se o RabbitMQ estiver fora, todos os serviços ficam não prontos.
4. Para voltar à versão anterior: `kubectl -n oficina-mecanica rollout undo deployment/<nome>`.
5. No CI, o job `deploy-kind` falha nesse mesmo caso e publica pods, eventos e logs no resumo do job.

---

## ServicoForaDoAr

**O que significa:** o Prometheus não consegue ler o `/metrics` de um serviço há 2 minutos, ou o Deployment dele não tem nenhuma réplica disponível.

**O que fazer:**

1. Siga os passos de **DeployIndisponivel**.
2. Se o pod está pronto mas o scrape falha, confira as anotações `prometheus.io/*` em `k8s/deployment.yaml` do serviço e a página Targets do Prometheus (http://localhost:19090/targets).
3. A Saga não perde mensagens com um serviço fora: as mensagens esperam na fila do RabbitMQ, e os comandos do OS esperam na outbox.
