# Checklist — Sessão 3

## Preparação da VM

- [ ] Clonei o repositório ou executei `git pull`.
- [ ] Entrei em `formacao-kubernetes/sessao-03`.
- [ ] Confirmei que `formando/docker/Dockerfile` existe.
- [ ] Executei `./comum/prepare-source.sh`.
- [ ] Confirmei que `app/composer.json` existe.
- [ ] Confirmei `docker version` e `docker compose version`.
- [ ] Confirmei `trivy --version` antes do Lab 05.

## Build

- [ ] Analisei `Dockerfile.inicial` antes de construir.
- [ ] Construí manualmente a imagem inicial com `docker build`.
- [ ] Consigo explicar o contexto `.` no final de `docker build`.
- [ ] Consultei `docker history`.
- [ ] Analisei o Dockerfile multi-stage.
- [ ] Construí manualmente `1.0.0` com `--build-arg`.
- [ ] Construí manualmente `1.1.0` e observei a cache.
- [ ] Consigo explicar por que `composer.json` e `composer.lock` entram antes do restante código.
- [ ] Só depois consultei/executei `build.sh` como automação.

## Segurança

- [ ] Avaliei a origem e adequação da imagem base.
- [ ] Construí o exemplo `Dockerfile.bad` com um valor fictício.
- [ ] Observei por que `ARG`/`ENV` não são mecanismos seguros para secrets persistentes.
- [ ] Executei um exemplo com BuildKit secret mount.
- [ ] Executei o exemplo de Compose secret.
- [ ] Compreendi que `.env` não é um secret manager.

## Saúde e operação

- [ ] Executei `docker compose ... config` manualmente com base + override.
- [ ] Iniciei a stack com o comando Compose completo antes de usar o wrapper.
- [ ] Validei `/health`.
- [ ] Validei `/ready`.
- [ ] Consultei o Docker `HEALTHCHECK`.
- [ ] Compreendi que health e readiness podem divergir.
- [ ] Consultei limites de CPU/memória e restart policy.
- [ ] Só depois utilizei `compose-prod.sh` como wrapper.

## Scan e identidade

- [ ] Analisei a imagem com Trivy.
- [ ] Interpretei o exit code do quality gate didático.
- [ ] Criei `symfony-demo:stable` com `docker tag`.
- [ ] Confirmei que `1.1.0` e `stable` podem apontar para o mesmo image ID local.
- [ ] Consigo explicar a diferença entre tag e digest.

## Registry

- [ ] Fiz pull de uma imagem pública do GHCR.
- [ ] Quando aplicável, executei `docker tag` manualmente para o meu namespace.
- [ ] Quando aplicável, executei `docker push` manualmente.
- [ ] Observei um RepoDigest.
- [ ] Só depois consultei/executei `push.sh` como automação.
- [ ] Compreendi `build once / promote the same artifact`.

## Deployment integrado

- [ ] Abri `deploy-prod.sh` e identifiquei o algoritmo antes de o executar.
- [ ] Abri `validate.sh` e identifiquei as validações realizadas.
- [ ] Fiz deploy de `1.0.0`.
- [ ] Criei um marcador persistente na base de dados.
- [ ] Abri `backup-postgres.sh` e identifiquei o `pg_dump`.
- [ ] Efetuei backup lógico.
- [ ] Atualizei para `1.1.0`.
- [ ] Confirmei a preservação do marcador.
- [ ] Testei `1.2.0-rc1`.
- [ ] Detetei o estado `unhealthy` e o exit code de falha.
- [ ] Comparei manualmente `/health` com `/healthz` antes do rollback.
- [ ] Abri `rollback.sh` antes de o executar.
- [ ] Fiz rollback para `1.1.0`.
- [ ] Confirmei novamente os dados.

## Conceitos finais

- [ ] Consigo explicar por que razão primeiro fazemos manualmente e só depois automatizamos.
- [ ] Consigo explicar por que razão uma tag é diferente de um digest.
- [ ] Consigo explicar por que razão persistência não substitui backup.
- [ ] Consigo explicar por que Docker Compose single-host não é HA.
- [ ] Sei que Docker `HEALTHCHECK` não se transforma automaticamente numa probe Kubernetes.
