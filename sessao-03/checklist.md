# Checklist — Sessão 3

## Laboratório Integrado

Utilize esta checklist em conjunto com:

[Laboratório Integrado da Sessão 3](formando/labs/laboratorio_integrado_sessao_3.md)

## Preparação da VM

- [ ] Parti de uma VM Ubuntu Server limpa.
- [ ] Atualizei o catálogo e os pacotes do sistema.
- [ ] Instalei `ca-certificates`, `curl` e `git`.
- [ ] Adicionei a chave e o repositório oficial Docker.
- [ ] Instalei Docker Engine, Docker CLI, `containerd`, Buildx e Compose.
- [ ] Executei `docker run --rm hello-world` com sucesso.
- [ ] Consigo explicar a relação Docker CLI → Engine → containerd → runc.
- [ ] Adicionei o utilizador ao grupo `docker` e compreendi a implicação de segurança.
- [ ] Instalei e validei Trivy.

## Recursos da formação

- [ ] Clonei o repositório ou executei `git pull`.
- [ ] Entrei em `formacao-kubernetes/sessao-03`.
- [ ] Executei `./comum/prepare-source.sh`.
- [ ] Confirmei que `app/composer.json` existe.

## Build

- [ ] Consigo explicar imagem versus container.
- [ ] Analisei `Dockerfile.inicial`.
- [ ] Construí manualmente a imagem inicial.
- [ ] Consigo explicar `-f`, `-t` e o contexto `.` em `docker build`.
- [ ] Consultei `docker history`.
- [ ] Construí manualmente `1.0.0` com `--build-arg`.
- [ ] Construí `1.1.0` e observei reutilização da cache.
- [ ] Consigo explicar a finalidade do multi-stage build.
- [ ] Só depois analisei `build.sh` como automação.

## Segurança

- [ ] Consigo explicar o conceito de hardening.
- [ ] Demonstrei por que `ARG`/`ENV` não são secret managers.
- [ ] Executei o exemplo com BuildKit secret.
- [ ] Executei o exemplo de Compose secret.
- [ ] Consigo explicar `/run/secrets/<nome>`.
- [ ] Compreendi que `.env` não é um secret manager.

## Saúde e operação

- [ ] Consultei o Docker `HEALTHCHECK` da imagem.
- [ ] Consigo distinguir `/health`, `/ready` e `/info`.
- [ ] Validei o Compose com base + override + `.env.prod`.
- [ ] Consigo explicar `--env-file` e os vários `-f`.
- [ ] Identifiquei limites de CPU/memória, restart policy e logging.
- [ ] Só depois utilizei o wrapper `compose-prod.sh`.

## Scan

- [ ] Executei Trivy sobre a imagem.
- [ ] Consigo explicar `--scanners`, `--severity` e `--ignore-unfixed`.
- [ ] Compreendi o significado de `--exit-code 1` num quality gate didático.
- [ ] Sei que a contagem de vulnerabilidades varia ao longo do tempo.

## Tag, digest e registry

- [ ] Consigo explicar o que é um container registry.
- [ ] Consigo decompor `ghcr.io/skullclamp/symfony-demo:1.0.0`.
- [ ] Criei uma segunda tag local com `docker tag`.
- [ ] Confirmei que duas tags podem apontar para o mesmo conteúdo.
- [ ] Consigo distinguir tag de digest.
- [ ] Fiz `docker pull` de uma imagem pública.
- [ ] Quando aplicável, fiz `docker push` para o meu namespace.
- [ ] Observei um RepoDigest.
- [ ] Compreendi `build once / promote the same artifact`.

## Deployment single-host

- [ ] Validei a configuração Compose efetiva.
- [ ] Iniciei os serviços manualmente antes de usar scripts de deployment.
- [ ] Validei `/health`, `/ready` e `/info`.
- [ ] Consultei o estado Docker `healthy/unhealthy`.
- [ ] Consigo explicar porque Compose single-host não é Alta Disponibilidade.

## Persistência e backup

- [ ] Criei `lab_marker` na base de dados.
- [ ] Insertei dados de controlo.
- [ ] Executei um `pg_dump` manual.
- [ ] Confirmei que `backup.sql` tem conteúdo.
- [ ] Consigo explicar persistência versus backup.

## Update, falha e rollback

- [ ] Abri `deploy-prod.sh` e identifiquei as suas fases.
- [ ] Fiz deploy de `1.0.0`.
- [ ] Atualizei para `1.1.0`.
- [ ] Confirmei que os dados permaneceram.
- [ ] Executei `1.2.0-rc1` e registei o exit code.
- [ ] Consultei `docker inspect` e logs antes de corrigir.
- [ ] Comparei `/health` com `/healthz`.
- [ ] Consegui explicar a causa do estado `unhealthy`.
- [ ] Só depois executei rollback para `1.1.0`.
- [ ] Validei novamente aplicação e dados.

## Conceitos finais

- [ ] Fazer manualmente → observar → explicar → automatizar.
- [ ] Imagem ≠ Container.
- [ ] `.env` ≠ Secret Manager.
- [ ] Docker `HEALTHCHECK` ≠ Kubernetes Probe.
- [ ] Tag ≠ Digest.
- [ ] Persistência ≠ Backup.
- [ ] Build Once → Promote the Same Artifact.
- [ ] Compose Single-host ≠ Alta Disponibilidade ≠ Kubernetes.
