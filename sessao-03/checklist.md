# Checklist — Sessão 3

## Preparação

- [ ] Executei `./comum/prepare-source.sh`.
- [ ] Confirmei `docker version` e `docker compose version`.
- [ ] Confirmei `trivy --version` antes do Lab 05.

## Build

- [ ] Construí a imagem inicial.
- [ ] Construí a imagem multi-stage.
- [ ] Compreendi a função de `.dockerignore`.
- [ ] Observei a reutilização da cache entre `1.0.0` e `1.1.0`.
- [ ] Identifiquei o papel de `ARG`, `ENV`, `CMD` e `ENTRYPOINT`.

## Segurança

- [ ] Avaliei a origem e adequação da imagem base.
- [ ] Identifiquei riscos de secrets em Dockerfile, `ARG`, `ENV` e CLI.
- [ ] Compreendi o uso de BuildKit secrets no build.
- [ ] Compreendi que `.env` não é um secret manager.
- [ ] Analisei a imagem com Trivy.

## Saúde e operação

- [ ] Validei `/health`.
- [ ] Validei `/ready`.
- [ ] Consultei o Docker `HEALTHCHECK`.
- [ ] Compreendi que health e readiness podem divergir.
- [ ] Consultei limites de CPU/memória e restart policy.

## Registry

- [ ] Trabalhei com tags explícitas.
- [ ] Observei um digest.
- [ ] Fiz pull de uma imagem pública do GHCR.
- [ ] Compreendi `build once / promote the same artifact`.

## Deployment

- [ ] Fiz deploy de `1.0.0`.
- [ ] Criei um marcador persistente na base de dados.
- [ ] Efetuei backup lógico.
- [ ] Atualizei para `1.1.0`.
- [ ] Confirmei a preservação do marcador.
- [ ] Testei `1.2.0-rc1`.
- [ ] Detetei o estado `unhealthy` e o exit code de falha.
- [ ] Fiz rollback para `1.1.0`.
- [ ] Confirmei novamente os dados.

## Conceitos finais

- [ ] Consigo explicar por que razão uma tag é diferente de um digest.
- [ ] Consigo explicar por que razão persistência não substitui backup.
- [ ] Consigo explicar por que Docker Compose single-host não é HA.
- [ ] Sei que Docker `HEALTHCHECK` não se transforma automaticamente numa probe Kubernetes.
