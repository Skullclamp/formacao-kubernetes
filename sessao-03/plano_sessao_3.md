# A) Plano de Formação — Sessão 3
## Docker II — Build, Imagens, Otimização, Segurança, Registry e Deployment Single-host

## 1. Identificação da sessão

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 3 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **N.º estimado de formandos** | Até 5 |
| **Metodologia** | Expositiva e ativa, com forte componente prática |
| **Natureza da sessão** | Construção, otimização, segurança e promoção de imagens para um cenário Docker Compose single-host |
| **Cenário transversal** | Symfony Demo v3.1.0, Symfony 8.1, PHP 8.4 + Apache, PostgreSQL 16 |
| **Progressão pedagógica** | Código → Dockerfile → imagem otimizada → scan → tag/digest → registry → deployment → update → falha → rollback |

A Sessão 3 é deliberadamente orientada para **CONSTRUIR, PREPARAR E PROMOVER**. Kubernetes surge apenas como referência conceptual futura; a implementação prática desta sessão é Docker Compose single-host.

---

## 2. Objetivos específicos

No final da sessão, os formandos deverão ser capazes de:

1. Construir uma imagem de aplicação através de Dockerfile.
2. Compreender o contexto de build e a função de `.dockerignore`.
3. Organizar instruções para melhorar reutilização de layers e cache.
4. Utilizar multi-stage builds.
5. Separar dependências de build do runtime final.
6. Utilizar `ARG`, `ENV`, `CMD`, `ENTRYPOINT` e labels de forma adequada ao contexto.
7. Avaliar a origem e adequação da imagem base, evitando componentes desnecessários.
8. Compreender riscos de secrets em Dockerfile, build args, variáveis e CLI.
9. Aplicar princípios de hardening da imagem e do runtime.
10. Configurar e interpretar Docker `HEALTHCHECK`.
11. Distinguir saúde básica da aplicação de readiness da dependência de dados.
12. Aplicar limites de CPU e memória, restart policy e logging no Compose de produção.
13. Executar scan de vulnerabilidades com Trivy.
14. Distinguir tags versionadas de digests imutáveis.
15. Publicar e consumir imagens no GHCR.
16. Aplicar o princípio **build once, promote the same artifact**.
17. Executar um deployment single-host com PostgreSQL persistente.
18. Executar update entre versões sem recriar os dados.
19. Detetar uma versão operacionalmente defeituosa através do healthcheck.
20. Executar rollback para uma versão conhecida como boa.
21. Confirmar a preservação dos dados durante update, falha e rollback.

---

## 2.1. Revisão à luz das recomendações técnicas

A recomendação de não deixar **multi-stage builds** fora de uma formação intermédia é totalmente incorporada nesta sessão. No desenho atual, multi-stage não é apenas uma microdemonstração: integra o percurso prático da imagem Symfony.

A revisão reforça ainda:

```text
origem da imagem base
        ↓
conteúdo mínimo necessário
        ↓
scan e interpretação
        ↓
tag + digest
        ↓
promoção do mesmo artefacto
```

Isto introduz uma primeira noção de **segurança da supply chain**, sem transformar a sessão numa formação DevSecOps.

Assinatura de imagens, SBOM e provenance aprofundados permanecem fora do âmbito prático, podendo ser apenas enquadrados conceptualmente.

---

## 3. Cenário de referência

### Aplicação

Será utilizada a **Symfony Demo v3.1.0**, com:

- Symfony 8.1;
- PHP 8.4;
- Apache;
- PostgreSQL 16;
- Composer;
- endpoints pedagógicos `/info`, `/health` e `/ready`.

### Fluxo da sessão

```text
Código Symfony
      ↓
Dockerfile
      ↓
Build
      ↓
Imagem 1.0.0
      ↓
Scan + validação
      ↓
GHCR
      ↓
Compose produção
      ↓
PostgreSQL + volume
      ↓
Update 1.1.0
      ↓
Candidata 1.2.0-rc1
      ↓
unhealthy
      ↓
Rollback 1.1.0
```

### Endpoints pedagógicos

```text
/health → verifica saúde básica da aplicação
/ready  → verifica disponibilidade da aplicação para servir pedidos, incluindo DB
/info   → apresenta versão e ambiente
```

Nota importante:

> O Docker `HEALTHCHECK` desta sessão não é herdado automaticamente pelo Kubernetes como liveness/readiness probe. As probes Kubernetes são configuradas explicitamente nos manifests Kubernetes.

---

## 4. Conteúdos

### 4.1. Dockerfile e contexto de build

- `FROM`.
- `WORKDIR`.
- `COPY`.
- `RUN`.
- `ARG`.
- `ENV`.
- `EXPOSE`.
- `CMD` e `ENTRYPOINT`.
- Contexto de build.
- `.dockerignore` aplicado ao contexto efetivo.

### 4.2. Dependências, layers, cache e multi-stage

- Composer no build.
- Separação entre ficheiros de dependências e código da aplicação.
- Cache de `composer install`.
- Ordem das instruções e invalidation da cache.
- Build stage e runtime stage.
- Redução de dependências desnecessárias no runtime.
- Metadata da versão colocada depois das layers pesadas quando não deve invalidar cache.

### 4.3. Hardening e secrets

- Origem, manutenção e adequação da imagem base.
- Imagens de base e superfície de ataque.
- Redução de componentes desnecessários no runtime.
- Privilégios mínimos.
- Cuidados com `USER` em imagens Apache oficiais.
- Permissões de diretórios graváveis.
- Secrets em `ARG`/`ENV`: risco de exposição.
- BuildKit secret mount como alternativa de build quando necessário.
- `.env` como conveniência de runtime, não como secret manager.
- Compose secrets montados como ficheiros em `/run/secrets/<nome>`.
- Docker socket como recurso altamente privilegiado.

### 4.4. Controlos operacionais

- Docker `HEALTHCHECK`.
- `/health` vs `/ready`.
- Restart policy.
- `mem_limit`.
- `cpus`.
- Logging driver `local`.
- Validação operacional com `docker inspect`.

### 4.5. Scan, tags e identidade

- Noção introdutória de supply chain da imagem.
- Trivy.
- HIGH e CRITICAL.
- Scan informativo.
- Quality gate através de exit code.
- SemVer: `1.0.0`, `1.1.0`, `1.2.0-rc1`.
- Tag como referência mutável.
- Digest como identidade imutável do conteúdo.

### 4.6. Registry e promoção

- GHCR.
- Pull público das imagens de referência.
- Push autenticado para namespaces com permissão.
- `docker tag` e `docker push`.
- `RepoDigests`.
- Build once, promote the same artifact.
- Não reconstruir a aplicação para cada ambiente.

### 4.7. Deployment single-host

- Compose base + override de produção.
- PostgreSQL 16 sem publicação desnecessária da porta da DB no host.
- Named volume para dados.
- `depends_on` com `service_healthy` para PostgreSQL.
- Limites de CPU/memória e restart policies.
- Inicialização de schema apenas no laboratório quando a DB está vazia.
- Update de versão.
- Falha controlada por healthcheck incorreto.
- Rollback.
- Persistência e backup lógico.

---

## 5. Distribuição temporal

| Tempo | Conteúdo / atividade | Tipo predominante |
|---:|---|---|
| 10 min | Enquadramento e ligação à Sessão 2 | Síntese |
| 30 min | Dockerfile, contexto de build e `.dockerignore` | Conceito + prática |
| 30 min | Layers, cache e multi-stage | Conceito + demonstração |
| 25 min | Hardening e secrets | Conceito + análise |
| 20 min | Controlos operacionais: CPU/memória, restart, HEALTHCHECK e logging | Conceito + demonstração |
| 15 min | **Intervalo** | — |
| 20 min | Scan, tags e identidade da imagem | Prática guiada |
| 25 min | Registry e promoção | Demonstração + prática |
| 50 min | Laboratório integrado: deploy, update, falha e rollback | Prática |
| 15 min | Síntese, discussão e checklist | Consolidação |
| **240 min** | **Total** | |

---

## 6. Estratégia pedagógica

Cada bloco deverá seguir, sempre que aplicável:

```text
conceito
   ↓
exemplo
   ↓
construir
   ↓
observar
   ↓
medir
   ↓
alterar
   ↓
validar
```

Ao longo da sessão, reforçar permanentemente:

```text
O que entrou na imagem?
        ↓
Que layer mudou?
        ↓
Que artefacto foi produzido?
        ↓
Como identifico exatamente esse artefacto?
        ↓
Como valido que está operacional?
        ↓
Como recupero se a nova versão falhar?
```

---

## 7. Bloco 1 — Enquadramento

**Duração:** 10 minutos

### Recuperar a Sessão 2

```text
Sessão 2
OPERAR
→ imagens existentes
→ containers
→ rede
→ volumes
→ Compose
```

### Questão orientadora

> Como transformamos agora o código da aplicação numa imagem reproduzível, otimizada, identificável e promovível entre ambientes?

---

## 8. Bloco 2 — Dockerfile e build

**Duração:** 30 minutos

### Progressão

```text
código
  ↓
contexto de build
  ↓
Dockerfile
  ↓
layers
  ↓
imagem
```

### Tópicos práticos

- comparar Dockerfile inicial e final;
- observar o contexto enviado ao daemon/buildkit;
- confirmar o `.dockerignore` da raiz;
- construir `symfony-demo:1.0.0`;
- validar `/health`, `/info` e aplicação Web.

---

## 9. Bloco 3 — Layers, cache e multi-stage

**Duração:** 30 minutos

### Questão orientadora

> Se apenas mudarmos `APP_VERSION`, porque haveríamos de repetir instalações pesadas que não mudaram?

### Demonstração

Construir versões `1.0.0` e `1.1.0` e observar a reutilização de cache.

### Mensagem-chave

> A ordem das instruções do Dockerfile influencia diretamente o custo de rebuild.

---

## 10. Bloco 4 — Hardening e secrets

**Duração:** 25 minutos

### Comparações a trabalhar

```text
ARG/ENV com segredo
        ≠
secret mount durante build
```

```text
.env
  = conveniência de configuração
  ≠ secret manager
```

```text
Docker socket
  = controlo privilegiado do Docker
```

### Nota sobre non-root

Evitar apresentar `USER www-data` como receita universal numa imagem `php:8.4-apache-bookworm`; o comportamento do Apache e as permissões necessárias devem ser analisados no contexto da imagem base.

---

## 11. Bloco 5 — Controlos operacionais

**Duração:** 20 minutos

### Relação

```text
processo a correr
      ≠
aplicação saudável
      ≠
aplicação pronta para dependências externas
```

### Demonstração

- `/health` responde sem depender de PostgreSQL;
- `/ready` verifica a base de dados;
- Docker `HEALTHCHECK` utiliza `/health`;
- Compose aguarda PostgreSQL healthy antes da aplicação quando configurado para isso.

### Controlos adicionais

```text
mem_limit: 512m
cpus: 1.0
restart: unless-stopped
logging.driver: local
```

---

## 12. Intervalo

**Duração:** 15 minutos

---

## 13. Bloco 6 — Scan, tags e digest

**Duração:** 20 minutos

### Scan informativo

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.0.0
```

### Quality gate conceptual

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.0.0
```

Os números de findings não devem ser memorizados nem fixados no material, porque mudam com as bases de vulnerabilidades.

### Identidade

```text
1.0.0
  = tag
  = referência conveniente
  = mutável

sha256:...
  = digest
  = identidade do conteúdo
  = imutável
```

---

## 14. Bloco 7 — Registry e promoção

**Duração:** 25 minutos

### Registry de referência

```text
ghcr.io/skullclamp/symfony-demo
```

As imagens de referência podem ser consumidas por pull público. Push para um namespace próprio exige autenticação e permissões adequadas.

### Fluxo

```text
build 1x
   ↓
imagem + digest
   ↓
registry
   ├── DEV
   ├── TEST
   └── PROD
```

### Mensagem-chave

> Promover significa mover a mesma identidade de conteúdo entre etapas; não reconstruir uma aplicação diferente em cada ambiente.

---

## 15. Laboratório integrado — Deployment, update, falha e rollback

**Duração:** 50 minutos

### Objetivo

Executar um ciclo realista de promoção e recuperação num host Docker single-host.

### Fase 1 — Deployment `1.0.0`

1. Preparar `.env.prod` a partir do exemplo.
2. Validar `docker compose config`.
3. Validar a porta antes do deployment.
4. Puxar imagens.
5. Iniciar PostgreSQL.
6. Inicializar o schema do laboratório se a base estiver vazia.
7. Iniciar a aplicação.
8. Validar `/health`, `/ready`, `/info` e Docker HEALTHCHECK.

### Fase 2 — Persistência e backup

1. Criar um registo identificável em `lab_marker`.
2. Confirmar o dado.
3. Executar `pg_dump` através do script de backup.
4. Reforçar: **volume persistente ≠ backup**.

### Fase 3 — Update `1.1.0`

1. Aplicar a versão `1.1.0`.
2. Confirmar `/info` com `1.1.0`.
3. Confirmar healthcheck `healthy`.
4. Confirmar que `lab_marker` permanece.

### Fase 4 — Falha controlada `1.2.0-rc1`

A imagem candidata utiliza deliberadamente um `HEALTH_PATH` incorreto (`/healthz`).

Resultado esperado:

```text
/health             → OK
/ready              → OK
/info               → 1.2.0-rc1
Docker HEALTHCHECK  → unhealthy
deploy-prod.sh      → exit 1
```

### Fase 5 — Rollback

```text
1.2.0-rc1
   ↓ falha
rollback
   ↓
1.1.0
```

Confirmar:

- `/health` OK;
- `/ready` OK;
- `/info` = `1.1.0`;
- Docker HEALTHCHECK = `healthy`;
- `lab_marker` preservado.

---

## 16. Síntese e avaliação formativa

**Duração:** 15 minutos

### Checklist de competências

- [ ] Consigo explicar o contexto de build.
- [ ] Sei porque existe um `.dockerignore` na raiz do contexto.
- [ ] Consigo explicar layers e cache.
- [ ] Sei justificar um multi-stage build.
- [ ] Distingo `ARG` de `ENV` e não uso ambos como secret manager.
- [ ] Consigo interpretar Docker `HEALTHCHECK`.
- [ ] Distingo `/health` de `/ready`.
- [ ] Consigo executar e interpretar um scan Trivy.
- [ ] Distingo tag de digest.
- [ ] Compreendo build once / promote same artifact.
- [ ] Consigo executar update e rollback.
- [ ] Consigo provar que os dados persistiram durante o ciclo.

---

## 17. Delimitação de âmbito

### Incluído

- Dockerfile e build.
- Cache e multi-stage.
- Hardening essencial.
- Secrets no contexto Docker/Compose.
- `HEALTHCHECK`.
- Resource limits e restart policy.
- Logging local.
- Trivy.
- Tags e digest.
- GHCR.
- Compose single-host de produção contextualizada.
- Update e rollback.
- Backup lógico curto.

### Fora do âmbito desta sessão

- Kubernetes em profundidade.
- Liveness/readiness probes Kubernetes em configuração prática.
- Alta Disponibilidade.
- Swarm.
- Logging centralizado.
- Secret managers empresariais.
- Rootless Docker em profundidade.
- TLS automatizado.
- Assinatura/verificação de imagens em profundidade.
- SBOM/provenance em profundidade.
- Restore avançado de PostgreSQL.

---

## 18. Continuidade para a Sessão 4

A Sessão 3 termina com uma imagem preparada, versionada, publicada e validada num cenário single-host.

A Sessão 4 passa para a questão:

> Como instalamos e administramos o cluster Kubernetes que irá orquestrar estes workloads?

```text
Sessão 3
imagem pronta + registry + operação controlada
            ↓
Sessão 4
instalação e administração de Kubernetes
```
