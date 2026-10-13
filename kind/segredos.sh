#!/usr/bin/env sh
# Cria os Secrets do namespace oficina-mecanica com valores gerados a cada subida (ADR-021): nenhum segredo
# fica versionado. Idempotente: valores já existentes são mantidos, para não quebrar serviços em execução.
#
#   ./kind/segredos.sh os billing operacoes
#
# plataforma-segredos: usuário/senha do RabbitMQ e a chave JWT, compartilhada pelos três serviços.
# <servico>-segredos: senha do banco do serviço (e, no OS, senha dos usuários do seed e chave da API interna).
set -eu
NS=oficina-mecanica

aleatorio() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "${1:-32}"; }

existe() { kubectl -n "$NS" get secret "$1" >/dev/null 2>&1; }

if ! existe plataforma-segredos; then
    kubectl -n "$NS" create secret generic plataforma-segredos \
        --from-literal=rabbitmq-usuario=saga \
        --from-literal=rabbitmq-senha="$(aleatorio 24)" \
        --from-literal=jwt-key="$(aleatorio 48)"
fi

for servico in "$@"; do
    existe "$servico-segredos" && continue
    case "$servico" in
        os)
            # Senha dos usuários do seed (admin, atendente, mecânico): precisa de maiúscula, minúscula, número e símbolo.
            kubectl -n "$NS" create secret generic os-segredos \
                --from-literal=db-senha="$(aleatorio 24)" \
                --from-literal=seed-senha="Demo@$(aleatorio 10)1a" \
                --from-literal=interno-api-key="$(aleatorio 32)" ;;
        billing|operacoes)
            kubectl -n "$NS" create secret generic "$servico-segredos" --from-literal=db-senha="$(aleatorio 24)" ;;
        *)
            echo "Serviço desconhecido: $servico" >&2; exit 1 ;;
    esac
done
