# CLAUDE.md — ruleset

## Rule 1 — Check tech-challenge-docs Before Implementing
Before starting any implementation task, check the [tech-challenge-docs](https://github.com/LucazDenadai/tech-challenge-docs) repository (ADRs, RFCs, cards) to confirm the work matches what's already been decided there.
If what's about to be built isn't documented there yet (no card, ADR, or RFC covers it), stop and create the missing card/ADR/RFC first — don't implement undocumented work.
Flag any mismatch between the request and what's documented instead of silently picking one.

Relevant docs for this repository: [ADR-009](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-009-migracao-aws-e-separacao-repositorios.md), [ADR-010](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/adr/ADR-010-sizing-e-regiao-aws.md), [RFC-001](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/rfcs/RFC-001-escolha-da-nuvem.md), [CARD-27](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/cards/05-fase3-aws/CARD-27-cicd-multi-repo.md), [CARD-28](https://github.com/LucazDenadai/tech-challenge-docs/blob/main/cards/05-fase3-aws/CARD-28-infra-aws-terraform.md).
