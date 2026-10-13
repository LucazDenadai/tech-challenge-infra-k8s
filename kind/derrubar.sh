#!/usr/bin/env sh
# Apaga o cluster da demonstração. Bancos e filas somem junto (ADR-021).
set -eu
kind delete cluster --name oficina
