#!/usr/bin/env sh
# Sobe a demonstração da Fase 4 no Kind (ADR-021): cluster, plataforma compartilhada e os três serviços,
# construídos a partir dos repositórios lado a lado:
#
#   <pasta>/tech-challenge-infra-k8s, <pasta>/tech-challenge-os, <pasta>/tech-challenge-billing, <pasta>/tech-challenge-operacoes
#
#   ./kind/subir.sh                         cria (ou reaproveita) o cluster e implanta tudo
#   SEM_OBSERVABILIDADE=1 ./kind/subir.sh   sem Prometheus, Grafana e Loki (menos memória)
#   ./kind/derrubar.sh                      apaga o cluster
#
# Requisitos: Docker, kind e kubectl.
set -eu

cd "$(dirname "$0")"
CLUSTER=oficina
NS=oficina-mecanica
RAIZ=../..

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    kind create cluster --config cluster.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

echo "== Plataforma compartilhada"
kubectl apply -k plataforma
./segredos.sh os billing operacoes
kubectl -n "$NS" rollout status deployment/rabbitmq --timeout=180s

if [ "${SEM_OBSERVABILIDADE:-0}" != 1 ]; then
    echo "== Observabilidade (Prometheus, Grafana, Loki)"
    kubectl apply -k observabilidade
    ./segredos.sh observabilidade
fi

for servico in os billing operacoes; do
    repo="$RAIZ/tech-challenge-$servico"
    echo "== $servico"
    docker build -q -t "tech-challenge-$servico:local" "$repo" >/dev/null
    kind load docker-image "tech-challenge-$servico:local" --name "$CLUSTER" >/dev/null
    kubectl apply -k "$repo/k8s"
    # Imagem local com a mesma tag: força um rollout novo para pegar o build mais recente.
    kubectl -n "$NS" rollout restart "deployment/$servico" >/dev/null
done

for servico in os billing operacoes; do
    kubectl -n "$NS" rollout status "deployment/$servico" --timeout=300s
done

observabilidade=""
if [ "${SEM_OBSERVABILIDADE:-0}" != 1 ]; then
    for componente in prometheus grafana loki kube-state-metrics; do
        kubectl -n observabilidade rollout status "deployment/$componente" --timeout=180s
    done
    grafana=$(kubectl -n observabilidade get secret observabilidade-segredos -o jsonpath='{.data.grafana-senha}' | base64 -d)
    observabilidade="
  Grafana    http://localhost:13000  (leitura sem login; admin / $grafana)
  Prometheus http://localhost:19090
  Runbooks   kind/observabilidade/runbooks.md"
fi

senha=$(kubectl -n "$NS" get secret os-segredos -o jsonpath='{.data.seed-senha}' | base64 -d)
cat <<EOF

Demonstração no ar:
  OS         http://localhost:8090/os/swagger
  Billing    http://localhost:8091/billing/swagger
  Operações  http://localhost:8092/operacoes/swagger
  RabbitMQ   http://localhost:15680
  Jaeger     http://localhost:16690$observabilidade

Usuários do seed (admin@, atendente@, mecanico@oficina.example), senha: $senha
EOF
