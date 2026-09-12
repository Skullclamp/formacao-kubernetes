# Manual do Formando — Docker — Build, Imagens, Otimização, Segurança, Registry e Deployment Single-host

---

# Índice

1. [Do código à imagem](#1-do-código-à-imagem)
2. [Dockerfile: estrutura e instruções fundamentais](#2-dockerfile-estrutura-e-instruções-fundamentais)
3. [Build context e `.dockerignore`](#3-build-context-e-dockerignore)
4. [Imagem base e cadeia de confiança](#4-imagem-base-e-cadeia-de-confiança)
5. [Layers e cache](#5-layers-e-cache)
6. [Multi-stage builds](#6-multi-stage-builds)
7. [`ARG`, `ENV`, `CMD` e `ENTRYPOINT`](#7-arg-env-cmd-e-entrypoint)
8. [Labels OCI e metadata da imagem](#8-labels-oci-e-metadata-da-imagem)
9. [BuildKit e Buildx](#9-buildkit-e-buildx)
10. [Configuração e secrets](#10-configuração-e-secrets)
11. [Hardening da imagem e do runtime](#11-hardening-da-imagem-e-do-runtime)
12. [`HEALTHCHECK`, `/health` e `/ready`](#12-healthcheck-health-e-ready)
13. [Limites de recursos, restart policy e logging](#13-limites-de-recursos-restart-policy-e-logging)
14. [Inspeção da imagem e histórico](#14-inspeção-da-imagem-e-histórico)
15. [Análise de vulnerabilidades com Trivy](#15-análise-de-vulnerabilidades-com-trivy)
16. [Tags, SemVer e identidade](#16-tags-semver-e-identidade)
17. [Digest e identidade imutável](#17-digest-e-identidade-imutável)
18. [Registry e GitHub Container Registry](#18-registry-e-github-container-registry)
19. [Build once, promote the same artifact](#19-build-once-promote-the-same-artifact)
20. [Compose base e configuração de produção](#20-compose-base-e-configuração-de-produção)
21. [Deployment single-host](#21-deployment-single-host)
22. [Update de versão](#22-update-de-versão)
23. [Falha controlada e diagnóstico](#23-falha-controlada-e-diagnóstico)
24. [Rollback](#24-rollback)
25. [Persistência e backup lógico](#25-persistência-e-backup-lógico)
26. [Caso prático integrado — Symfony Demo](#26-caso-prático-integrado--symfony-demo)
27. [Troubleshooting de build, imagem e deployment](#27-troubleshooting-de-build-imagem-e-deployment)
28. [Guia rápido](#28-guia-rápido)
29. [Glossário](#29-glossário)
30. [Recursos e leituras complementares](#30-recursos-e-leituras-complementares)

---

# 1. Do código à imagem

Quando somos responsáveis por uma aplicação, o problema deixa de ser apenas executar uma imagem existente. Precisamos de transformar código-fonte num artefacto executável, reproduzível e identificável.

```text
Código-fonte
     │
     ▼
Build context
     │
     ▼
Dockerfile
     │
     ▼
Builder
     │
     ▼
Layers
     │
     ▼
Imagem
     │
     ├── tag
     └── digest
```

A imagem deve ser encarada como um **artefacto de distribuição**. Contém um filesystem organizado em layers, configuração de runtime e metadata.

Uma boa imagem deve ser:

- reproduzível;
- construída a partir de uma base conhecida;
- suficientemente pequena para a função que desempenha;
- sem ferramentas de build desnecessárias em runtime;
- configurável sem ser reconstruída para cada ambiente;
- identificável por versão e digest;
- passível de análise de vulnerabilidades;
- publicável num registry.

## 1.1. Caso técnico de referência

O caso utilizado é uma Symfony Demo com:

```text
Symfony 8.1
PHP 8.4
Apache
Composer
PostgreSQL 16
```

A aplicação expõe:

```text
/info
/health
/ready
```

```text
/info
└── identifica versão e ambiente

/health
└── verifica saúde básica da aplicação

/ready
└── verifica se a aplicação está pronta,
    incluindo a dependência da base de dados
```

O percurso é:

```text
Código
  ↓
Dockerfile
  ↓
Imagem 1.0.0
  ↓
Scan
  ↓
Registry
  ↓
Deployment
  ↓
Update 1.1.0
  ↓
Candidata 1.2.0-rc1
  ↓
Falha operacional
  ↓
Rollback 1.1.0
```

---

# 2. Dockerfile: estrutura e instruções fundamentais

Um Dockerfile descreve como construir uma imagem.

Exemplo mínimo:

```dockerfile
FROM php:8.4-apache-bookworm

WORKDIR /var/www/html

COPY app/ ./

EXPOSE 80

CMD ["apache2-foreground"]
```

## 2.1. `FROM`

```dockerfile
FROM php:8.4-apache-bookworm
```

Define a imagem base. A imagem resultante começa com o filesystem e metadata fornecidos pela base e acrescenta as alterações descritas pelas instruções seguintes.

## 2.2. `WORKDIR`

```dockerfile
WORKDIR /var/www/html
```

Define a diretoria de trabalho para instruções subsequentes.

## 2.3. `COPY`

```dockerfile
COPY app/ ./
```

Copia ficheiros do **build context** para a imagem.

## 2.4. `RUN`

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

Executa comandos durante o build. O resultado passa a integrar a imagem.

## 2.5. `EXPOSE`

```dockerfile
EXPOSE 80
```

Documenta a porta esperada no container. Não publica a porta no host.

## 2.6. `CMD`

```dockerfile
CMD ["apache2-foreground"]
```

Define o comando por omissão executado quando o container arranca, salvo override.

A forma exec/JSON:

```dockerfile
CMD ["executavel", "arg1", "arg2"]
```

evita a introdução automática de uma shell e tende a produzir comportamento de sinais mais previsível.

---

# 3. Build context e `.dockerignore`

Considere:

```bash
docker build \
  -f formando/docker/Dockerfile \
  -t symfony-demo:1.0.0 \
  .
```

O ponto final define o **build context**.

## 3.1. O que é o build context?

É o conjunto de ficheiros disponibilizado ao builder.

```text
Diretoria escolhida
        │
        ▼
Build context
        │
        ├── COPY
        ├── ADD
        └── .dockerignore
```

O Dockerfile pode estar em:

```text
formando/docker/Dockerfile
```

e o contexto continuar a ser:

```text
.
```

São conceitos diferentes.

## 3.2. Porque o contexto importa?

Um contexto excessivo pode:

- aumentar I/O;
- aumentar o tempo de build;
- invalidar cache;
- expor ficheiros sem necessidade;
- incluir conteúdo sensível;
- tornar o build menos previsível.

## 3.3. `.dockerignore`

Exemplo:

```text
.git/
app/.git/
app/vendor/
app/var/cache/
app/var/log/
app/.env.local
app/.env.*.local
backups/
*.sql
*.zip
```

Benefícios:

```text
menos ficheiros
    ├── contexto menor
    ├── menos risco
    ├── melhor cache
    └── build mais previsível
```

Se o contexto é `.` deve confirmar qual o `.dockerignore` efetivamente aplicado a esse contexto.

---

# 4. Imagem base e cadeia de confiança

A primeira linha condiciona grande parte do conteúdo final:

```dockerfile
FROM php:8.4-apache-bookworm
```

A aplicação herda:

- sistema operativo base;
- bibliotecas;
- PHP;
- Apache;
- configuração;
- vulnerabilidades eventualmente presentes;
- ciclo de manutenção do produtor.

Prefira imagens oficiais ou de origem conhecida, mantidas, documentadas e adequadas ao runtime necessário.

## 4.1. Tag da base

```text
php:8.4-apache-bookworm
```

é uma referência legível, mas a tag é mutável.

Em cenários que exigem reprodutibilidade rigorosa pode ser necessário fixar também um digest:

```dockerfile
FROM php:8.4-apache-bookworm@sha256:...
```

Fixar digest aumenta a precisão, mas também exige um processo explícito de atualização.

## 4.2. Imagem pequena não significa automaticamente imagem melhor

Uma base mínima pode reduzir transferência e superfície de ataque, mas também pode complicar:

- compatibilidade;
- bibliotecas nativas;
- certificados;
- debug;
- ferramentas necessárias em runtime.

A decisão deve ser funcional.

---

# 5. Layers e cache

Uma imagem é composta por layers.

```text
Layer base
   ↓
Layer instalar dependências
   ↓
Layer copiar ficheiros
   ↓
Layer configurar aplicação
```

Durante builds seguintes, o builder tenta reutilizar resultados anteriores.

## 5.1. Ordem das instruções

No caso Symfony:

```dockerfile
COPY app/composer.json app/composer.lock app/symfony.lock ./

RUN composer install ...

COPY app/ ./
```

A instalação pesada de dependências fica separada da cópia do código.

Se apenas o código mudar e os ficheiros de dependências permanecerem iguais, a layer de `composer install` pode ser reutilizada.

Uma regra útil:

```text
conteúdo que muda menos
        ↓
mais cedo no Dockerfile

conteúdo que muda mais
        ↓
mais tarde no Dockerfile
```

## 5.2. Invalidação

```text
Layer A → cache válida
Layer B → mudou
Layer C → depende de B
Layer D → depende de C
```

Resultado:

```text
A reutilizada
B reconstruída
C reconstruída
D reconstruída
```

## 5.3. Observar

```bash
docker history symfony-demo:1.0.0
```

E durante o build procurar etapas marcadas como:

```text
CACHED
```

---

# 6. Multi-stage builds

Um multi-stage build utiliza vários `FROM`.

```dockerfile
FROM imagem-com-ferramentas AS build

RUN compilar
RUN instalar dependências

FROM imagem-runtime AS runtime

COPY --from=build /artefacto /aplicacao
CMD ["executar"]
```

O stage de build pode conter:

- compiladores;
- headers;
- Git;
- Composer;
- bibliotecas de desenvolvimento.

O runtime final deve transportar apenas o necessário.

```text
Build stage
├── ferramentas
├── Composer
├── dependências
└── aplicação preparada
       │
       │ COPY --from=build
       ▼
Runtime stage
├── runtime
├── bibliotecas necessárias
└── aplicação
```

No Dockerfile de referência:

```dockerfile
FROM php:8.4-apache-bookworm AS build
```

e depois:

```dockerfile
FROM php:8.4-apache-bookworm AS runtime
```

A aplicação preparada é copiada:

```dockerfile
COPY --from=build /var/www/html /var/www/html
```

As extensões PHP compiladas também são transferidas:

```dockerfile
COPY --from=build /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
```

Multi-stage melhora não apenas o tamanho, mas também a separação de responsabilidades e a redução de ferramentas desnecessárias em runtime.

---

# 7. `ARG`, `ENV`, `CMD` e `ENTRYPOINT`

## 7.1. `ARG`

```dockerfile
ARG APP_VERSION=dev
```

Existe no contexto de build.

```bash
docker build \
  --build-arg APP_VERSION=1.0.0 \
  .
```

Uso típico:

- metadata;
- opções de compilação;
- comportamento de build.

Não deve ser usado como secret manager.

## 7.2. `ENV`

```dockerfile
ENV APP_ENV=prod \
    APP_DEBUG=0
```

Persiste na configuração final da imagem e é disponibilizado ao container, salvo override.

## 7.3. Passar `ARG` para `ENV`

```dockerfile
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
```

Fluxo:

```text
--build-arg APP_VERSION=1.0.0
              ↓
ARG APP_VERSION
              ↓
ENV APP_VERSION=${APP_VERSION}
              ↓
imagem contém APP_VERSION=1.0.0
```

## 7.4. `CMD`

Define comando ou argumentos por omissão.

```dockerfile
CMD ["apache2-foreground"]
```

## 7.5. `ENTRYPOINT`

Define a entrada principal quando utilizada.

```dockerfile
ENTRYPOINT ["python", "app.py"]
```

Pode ser combinado com `CMD`.

Regra mental:

```text
ARG
└── build

ENV
└── imagem/runtime

ENTRYPOINT
└── executável principal

CMD
└── comando/argumentos por omissão
```

---

# 8. Labels OCI e metadata da imagem

O Dockerfile de referência usa labels:

```dockerfile
LABEL org.opencontainers.image.title="Symfony Demo - Formação Kubernetes" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/symfony/demo" \
      org.opencontainers.image.revision="${SOURCE_REF}"
```

Estas labels permitem responder a questões como:

```text
Que aplicação é?
Que versão representa?
Qual a origem?
Que revisão foi usada?
```

Consultar:

```bash
docker image inspect symfony-demo:1.0.0
```

Uma label concreta:

```bash
docker image inspect \
  symfony-demo:1.0.0 \
  --format '{{ index .Config.Labels "org.opencontainers.image.version" }}'
```

A metadata comunica significado humano; o digest identifica o conteúdo.

---

# 9. BuildKit e Buildx

Docker utiliza BuildKit como tecnologia moderna de build. `docker buildx` disponibiliza capacidades avançadas sobre BuildKit.

```bash
docker buildx version
```

Entre outras capacidades:

- cache avançada;
- builds concorrentes;
- secret mounts;
- SSH mounts;
- outputs diferentes;
- multi-platform builds.

Build de referência:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

Para observar mais detalhe:

```bash
docker build \
  --progress=plain \
  -f formando/docker/Dockerfile \
  -t symfony-demo:1.0.0 \
  .
```

Para diagnóstico sem cache:

```bash
docker build \
  --no-cache \
  -f formando/docker/Dockerfile \
  -t symfony-demo:teste \
  .
```

`--no-cache` é uma ferramenta de diagnóstico, não uma solução estrutural para um Dockerfile mal organizado.

---

# 10. Configuração e secrets

Configuração e segredos não são a mesma coisa.

## 10.1. `ARG` não é secret manager

Evite usar build args para credenciais permanentes.

## 10.2. `ENV` não é secret manager

Evite:

```dockerfile
ENV DB_PASSWORD=password-real
```

O valor fica na configuração da imagem e pode ser observado com `docker image inspect`.

## 10.3. `.env` não é secret manager

Um `.env` é útil para parametrização, mas continua a ser texto.

Não deve ser publicado em Git com credenciais reais.

## 10.4. BuildKit secret mount

Exemplo conceptual:

```dockerfile
RUN --mount=type=secret,id=composer_auth,target=/root/.composer/auth.json \
    composer install
```

Build:

```bash
docker build \
  --secret id=composer_auth,src="$HOME/.composer/auth.json" \
  .
```

O segredo fica disponível durante a instrução sem ser deliberadamente copiado para a layer final.

## 10.5. Compose secrets

```yaml
services:
  app:
    secrets:
      - app_secret

secrets:
  app_secret:
    file: ./secrets/app_secret.txt
```

No container:

```text
/run/secrets/app_secret
```

## 10.6. Docker socket

```text
/var/run/docker.sock
```

é altamente privilegiado. Montá-lo num container pode conceder controlo muito elevado sobre o Docker host.

---

# 11. Hardening da imagem e do runtime

Hardening significa reduzir risco mantendo o funcionamento necessário.

Princípios:

- base de origem conhecida;
- componentes mínimos;
- ferramentas de build fora do runtime;
- privilégios mínimos;
- diretórios graváveis apenas onde necessário;
- não usar `--privileged` como solução genérica;
- não embutir credenciais.

Em Debian/Ubuntu:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

No caso Symfony:

```dockerfile
RUN mkdir -p var/cache var/log \
    && chown -R www-data:www-data var
```

A ideia é atribuir permissões adequadas apenas aos diretórios necessários.

Evite soluções como:

```text
chmod -R 777
```

Também não trate:

```dockerfile
USER www-data
```

como receita universal em imagens Apache. O processo principal, a porta e as permissões da imagem base têm de ser analisados no contexto concreto.

# 12. `HEALTHCHECK`, `/health` e `/ready`

Um processo pode estar em execução e a aplicação não estar saudável.

```text
processo Running
      ≠
aplicação saudável
```

E uma aplicação saudável pode ainda não estar pronta para servir pedidos que dependem de sistemas externos:

```text
aplicação saudável
      ≠
aplicação ready
```

## 12.1. `/health`

No caso de referência:

```text
/health
```

testa a saúde básica da aplicação.

## 12.2. `/ready`

```text
/ready
```

inclui a disponibilidade da dependência PostgreSQL.

```text
Apache/PHP responde
       ├── /health → OK
       └── /ready
              ↓
          PostgreSQL?
```

## 12.3. Docker `HEALTHCHECK`

No Dockerfile:

```dockerfile
ARG HEALTH_PATH=/health

ENV HEALTH_PATH=${HEALTH_PATH}

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
    CMD curl -fsS "http://localhost${HEALTH_PATH}" >/dev/null || exit 1
```

Docker pode apresentar:

```text
Up 2 minutes (healthy)
```

ou:

```text
Up 2 minutes (unhealthy)
```

Consultar:

```bash
docker ps
```

ou:

```bash
docker inspect CONTAINER
```

Significado das opções:

```text
--interval=10s
└── intervalo entre testes

--timeout=3s
└── tempo máximo de cada teste

--start-period=20s
└── período inicial de tolerância

--retries=5
└── falhas consecutivas antes de marcar unhealthy
```

Docker `HEALTHCHECK` e probes Kubernetes são mecanismos diferentes. Um `HEALTHCHECK` da imagem não é convertido automaticamente em `livenessProbe`, `readinessProbe` ou `startupProbe`.

---

# 13. Limites de recursos, restart policy e logging

Uma imagem pronta para execução não resolve, por si só, todas as preocupações operacionais.

## 13.1. Limite de memória

Em Compose:

```yaml
mem_limit: 512m
```

Impõe um limite de memória ao container.

## 13.2. Limite de CPU

```yaml
cpus: 1.0
```

Define uma quota equivalente, de forma simplificada, a um CPU lógico de capacidade.

Não significa fixar obrigatoriamente o processo a um core específico.

## 13.3. Restart policy

```yaml
restart: unless-stopped
```

Docker tenta reiniciar o container após falhas ou restart do Engine, exceto quando o operador o tiver parado explicitamente de acordo com a política.

Políticas comuns:

```text
no
always
on-failure
unless-stopped
```

## 13.4. Logging driver

```yaml
logging:
  driver: local
```

O driver `local` é gerido pelo Docker Engine e é adequado para retenção/rotação local controlada.

## 13.5. Confirmar configuração efetiva

```bash
docker inspect CONTAINER
```

Procurar:

- `HostConfig.Memory`;
- `HostConfig.NanoCpus`;
- `HostConfig.RestartPolicy`;
- `HostConfig.LogConfig`.

---

# 14. Inspeção da imagem e histórico

Antes de publicar ou promover uma imagem, deve ser possível observá-la.

## 14.1. Listar

```bash
docker image ls
```

## 14.2. Inspecionar

```bash
docker image inspect symfony-demo:1.0.0
```

Permite ver:

- IDs;
- tags;
- digests, quando existentes;
- environment;
- command;
- labels;
- exposed ports;
- healthcheck;
- arquitetura;
- sistema operativo.

## 14.3. Histórico

```bash
docker history symfony-demo:1.0.0
```

Ajuda a compreender a sequência de layers e o peso relativo de cada uma.

## 14.4. Tamanho

```bash
docker image ls symfony-demo:1.0.0
```

Tamanho é uma métrica útil, mas não deve ser a única. Uma imagem pequena pode continuar a conter vulnerabilidades críticas ou configuração inadequada.

---

# 15. Análise de vulnerabilidades com Trivy

Uma imagem pode conter vulnerabilidades conhecidas em:

- pacotes do sistema operativo;
- bibliotecas;
- runtimes;
- dependências da aplicação.

O scan torna esse risco visível.

## 15.1. HIGH e CRITICAL

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.0.0
```

## 15.2. Interpretar resultados

Não basta contar findings.

É necessário considerar:

- severidade;
- pacote afetado;
- versão;
- fix disponível;
- componente efetivamente utilizado;
- impacto da atualização;
- contexto de exploração.

## 15.3. `--ignore-unfixed`

Ignora findings sem correção publicada.

Isto reduz ruído, mas não significa que a vulnerabilidade deixou de existir.

## 15.4. Quality gate

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.0.0
```

O exit code permite transformar uma política de segurança numa decisão automática de pipeline.

Os números de findings mudam com o tempo. O importante é aprender o processo:

```text
scan
  ↓
interpretar
  ↓
decidir
  ↓
corrigir / mitigar / aceitar / bloquear
```

---

# 16. Tags, SemVer e identidade

Uma tag é uma referência conveniente.

Exemplos:

```text
1.0.0
1.1.0
1.2.0-rc1
```

No modelo Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Exemplo:

```text
2.4.7
│ │ │
│ │ └── PATCH
│ └──── MINOR
└────── MAJOR
```

Uma versão candidata:

```text
1.2.0-rc1
```

é uma pré-release.

## 16.1. Tag não é conteúdo

Uma tag pode ser alterada por alguém com permissões adequadas no registry.

Logo:

```text
tag
=
referência legível e mutável
```

`latest` continua a ser apenas uma tag. Não é um mecanismo de controlo de versão.

---

# 17. Digest e identidade imutável

Um digest tem forma típica:

```text
sha256:2f4c...
```

## 17.1. Tag vs. digest

```text
Tag
1.1.0
└── referência mutável e legível

Digest
sha256:...
└── identidade do conteúdo
```

## 17.2. RepoDigests

Depois de uma imagem ter sido publicada ou obtida de um registry:

```bash
docker image inspect \
  ghcr.io/skullclamp/symfony-demo:1.0.0 \
  --format '{{json .RepoDigests}}'
```

Resultado conceptual:

```text
ghcr.io/skullclamp/symfony-demo@sha256:...
```

## 17.3. Pull por digest

```bash
docker pull \
  ghcr.io/skullclamp/symfony-demo@sha256:...
```

Isto pede uma identidade de conteúdo concreta.

Tag e digest complementam-se:

```text
tag
└── significado humano

digest
└── identidade técnica
```

---

# 18. Registry e GitHub Container Registry

Um registry armazena e distribui imagens.

O registry de referência é:

```text
ghcr.io
```

e o repository de referência:

```text
ghcr.io/skullclamp/symfony-demo
```

## 18.1. Pull

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

## 18.2. Login para push

Evite escrever tokens diretamente no histórico.

```bash
echo "$GHCR_TOKEN" | \
  docker login ghcr.io \
  -u "$GHCR_USER" \
  --password-stdin
```

## 18.3. Tag para outro namespace

```bash
docker tag \
  symfony-demo:1.0.0 \
  ghcr.io/SEU_UTILIZADOR/symfony-demo:1.0.0
```

## 18.4. Push

```bash
docker push \
  ghcr.io/SEU_UTILIZADOR/symfony-demo:1.0.0
```

## 18.5. Logout

```bash
docker logout ghcr.io
```

Push exige autenticação e permissões adequadas no namespace.

---

# 19. Build once, promote the same artifact

Um princípio importante de entrega é:

```text
build once
promote the same artifact
```

## 19.1. Anti-padrão

```text
DEV
└── build #1

TEST
└── build #2

PROD
└── build #3
```

Mesmo com a mesma tag, cada build pode produzir conteúdo diferente devido a alterações em dependências, imagem base, repositórios ou contexto.

## 19.2. Modelo preferível

```text
Código
  ↓
Build
  ↓
Artefacto A
digest sha256:XYZ
  ↓
Validação + scan
  ↓
Promoção
  ├── DEV
  ├── TEST
  └── PROD
```

A identidade permanece:

```text
sha256:XYZ
```

Promover significa transportar a mesma identidade de conteúdo entre etapas, não reconstruir.

---

# 20. Compose base e configuração de produção

O caso de referência separa:

```text
compose.yaml
```

de:

```text
compose.prod.yaml
```

## 20.1. Base

Trecho do ficheiro base:

```yaml
services:
  app:
    image: ${IMAGE_REPO:-ghcr.io/skullclamp/symfony-demo}:${APP_VERSION:-1.0.0}
    ports:
      - "${APP_PORT:-8080}:80"
    environment:
      APP_ENV: ${APP_ENV:-prod}
      APP_SECRET: ${APP_SECRET:-lab-only-session3-change-me}
      DATABASE_URL: ${DATABASE_URL:-postgresql://symfony:lab-symfony@db:5432/symfony?serverVersion=16&charset=utf8}
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data
```

> **Nota:** o `healthcheck` do service `db`, já apresentado anteriormente no percurso de Docker Compose, mantém-se sem alterações. Neste excerto foi omitido apenas para concentrar a leitura nos elementos relevantes para a configuração base e para o override de produção.

## 20.2. Override de produção

```yaml
services:
  app:
    image: ${IMAGE_REPO}:${APP_VERSION}
    environment:
      APP_ENV: prod
    restart: unless-stopped
    mem_limit: 512m
    cpus: 1.0
    logging:
      driver: local

  db:
    restart: unless-stopped
    mem_limit: 512m
    cpus: 1.0
    logging:
      driver: local
```

## 20.3. Combinar ficheiros

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

O segundo ficheiro funciona como override.

A saída de `config` permite confirmar a configuração resultante antes da execução.

---

# 21. Deployment single-host

A arquitetura é:

```text
Host Docker
    ├── app
    │    └── Symfony + Apache
    └── db
         └── PostgreSQL
              ↓
           db-data
```

## 21.1. Preparar environment

```bash
cp \
  formando/compose/.env.prod.example \
  formando/compose/.env.prod
```

## 21.2. Validar

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

## 21.3. Pull

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull
```

## 21.4. Iniciar

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

## 21.5. Validar

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Depois:

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```

---

# 22. Update de versão

Comece por identificar a versão atual:

```bash
curl -fsS http://localhost:8080/info
```

Alterar:

```dotenv
APP_VERSION=1.1.0
```

Obter artefacto:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull app
```

Aplicar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Confirmar:

```bash
curl -fsS http://localhost:8080/info
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
```

O update da aplicação não deve remover o volume de PostgreSQL.

```text
app 1.0.0
   ↓
db-data
   ↑
app 1.1.0
```

---

# 23. Falha controlada e diagnóstico

A candidata:

```text
1.2.0-rc1
```

é construída com:

```text
HEALTH_PATH=/healthz
```

em vez de:

```text
/health
```

A aplicação continua a disponibilizar:

```text
/health
/ready
/info
```

mas o Docker HEALTHCHECK procura `/healthz`.

Resultado esperado:

```text
GET /health
→ OK

GET /ready
→ OK

GET /info
→ 1.2.0-rc1

Docker HEALTHCHECK
→ unhealthy
```

Diagnóstico:

```bash
docker compose ps
```

```bash
docker inspect CONTAINER \
  --format '{{json .State.Health}}'
```

E:

```bash
docker image inspect \
  ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

Procurar:

```text
HEALTH_PATH=/healthz
```

O objetivo é chegar à causa antes de reverter.

---

# 24. Rollback

Rollback significa regressar a uma versão conhecida como boa.

```text
1.2.0-rc1
    ↓ falha
1.1.0
```

Alterar:

```dotenv
APP_VERSION=1.1.0
```

Aplicar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Validar:

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```

Esperado:

```text
/info
→ 1.1.0
```

Rollback não deve significar “reconstruir uma nova 1.1.0”. Deve consumir o artefacto anteriormente conhecido e validado.

---

# 25. Persistência e backup lógico

O PostgreSQL utiliza um named volume. Isto protege os dados contra a substituição normal do container.

Mas:

```text
volume
≠
backup
```

## 25.1. Backup lógico

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec -T db \
  pg_dump -U symfony symfony \
  > backup.sql
```

O redirecionamento `> backup.sql` é realizado pela shell do host, pelo que o ficheiro fica no host.

Um backup só é útil se puder ser restaurado.

Perguntas essenciais:

```text
O ficheiro existe?
Tem tamanho plausível?
Está protegido?
Existe uma cópia independente?
O restore foi testado?
Qual o RPO e RTO aceitáveis?
```

# 26. Caso prático integrado — Symfony Demo

Este caso junta as peças num percurso único: construir, analisar, publicar, executar, atualizar, detetar uma versão defeituosa e reverter.

## 26.1. Construir `1.0.0`

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

Durante o build, observar:

- transferência do build context;
- execução das layers;
- instalação das dependências;
- reutilização de cache;
- stage `build`;
- stage `runtime`;
- criação da imagem final.

Confirmar:

```bash
docker image ls symfony-demo
```

Inspecionar:

```bash
docker image inspect symfony-demo:1.0.0
```

Consultar histórico:

```bash
docker history symfony-demo:1.0.0
```

## 26.2. Confirmar metadata

Versão OCI:

```bash
docker image inspect \
  symfony-demo:1.0.0 \
  --format '{{ index .Config.Labels "org.opencontainers.image.version" }}'
```

Revisão:

```bash
docker image inspect \
  symfony-demo:1.0.0 \
  --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
```

Environment da imagem:

```bash
docker image inspect \
  symfony-demo:1.0.0 \
  --format '{{json .Config.Env}}'
```

Healthcheck:

```bash
docker image inspect \
  symfony-demo:1.0.0 \
  --format '{{json .Config.Healthcheck}}'
```

## 26.3. Construir `1.1.0` e observar cache

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Na saída do builder devem surgir etapas reutilizadas como:

```text
CACHED
```

A mudança da versão não deve obrigar a repetir indiscriminadamente operações pesadas se o Dockerfile estiver corretamente ordenado.

## 26.4. Construir a candidata `1.2.0-rc1`

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.2.0-rc1 \
  --build-arg SOURCE_REF=v3.1.0 \
  --build-arg HEALTH_PATH=/healthz \
  -t symfony-demo:1.2.0-rc1 \
  .
```

Esta candidata contém deliberadamente:

```text
HEALTH_PATH=/healthz
```

O objetivo é simular uma falha operacional de configuração do healthcheck sem destruir a própria aplicação.

## 26.5. Comparar as três imagens

```bash
docker image ls symfony-demo
```

Exemplo conceptual:

```text
symfony-demo   1.0.0
symfony-demo   1.1.0
symfony-demo   1.2.0-rc1
```

Comparar labels:

```bash
for v in 1.0.0 1.1.0 1.2.0-rc1; do
  echo "=== $v ==="
  docker image inspect \
    "symfony-demo:$v" \
    --format '{{ index .Config.Labels "org.opencontainers.image.version" }}'
done
```

## 26.6. Scan

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.0.0
```

Quality gate conceptual:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.0.0
```

Se existirem findings que correspondam ao filtro, o comando pode terminar com exit code `1`.

## 26.7. Preparar publicação

Autenticar:

```bash
echo "$GHCR_TOKEN" | \
  docker login ghcr.io \
  -u "$GHCR_USER" \
  --password-stdin
```

Criar referência para o namespace autorizado:

```bash
docker tag \
  symfony-demo:1.0.0 \
  ghcr.io/SEU_UTILIZADOR/symfony-demo:1.0.0
```

Publicar:

```bash
docker push \
  ghcr.io/SEU_UTILIZADOR/symfony-demo:1.0.0
```

Repetir, quando pretendido, para:

```text
1.1.0
1.2.0-rc1
```

## 26.8. Obter digest após publicação

```bash
docker image inspect \
  ghcr.io/SEU_UTILIZADOR/symfony-demo:1.0.0 \
  --format '{{json .RepoDigests}}'
```

Registar o digest permite relacionar:

```text
versão lógica
1.0.0
   │
   ▼
identidade real
sha256:...
```

## 26.9. Preparar configuração de deployment

Criar:

```bash
cp \
  formando/compose/.env.prod.example \
  formando/compose/.env.prod
```

Editar para indicar o repository utilizado:

```dotenv
IMAGE_REPO=ghcr.io/SEU_UTILIZADOR/symfony-demo
APP_VERSION=1.0.0
```

A configuração deve ainda conter os valores necessários para:

- `APP_PORT`;
- `APP_SECRET`;
- PostgreSQL;
- `DATABASE_URL`.

Evite credenciais reais ou reutilizadas noutros sistemas.

## 26.10. Validar a configuração final

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

Confirmar na saída:

```text
image
ports
environment
restart
mem_limit
cpus
logging
volume
healthcheck PostgreSQL
```

## 26.11. Deployment `1.0.0`

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull
```

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

Consultar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Validar endpoints:

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```

## 26.12. Confirmar saúde do container

Identificar o container da aplicação:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Depois:

```bash
docker inspect CONTAINER_APP \
  --format '{{json .State.Health}}'
```

Estado esperado, após o período de arranque:

```text
healthy
```

## 26.13. Confirmar limites de recursos

```bash
docker inspect CONTAINER_APP \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}} Log={{.HostConfig.LogConfig.Type}}'
```

Isto permite validar a configuração que efetivamente chegou ao runtime.

## 26.14. Criar um dado persistente

Criar uma tabela:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec db \
  psql -U symfony -d symfony \
  -c "CREATE TABLE IF NOT EXISTS lab_marker (id integer PRIMARY KEY, valor text);"
```

Inserir:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec db \
  psql -U symfony -d symfony \
  -c "INSERT INTO lab_marker (id, valor) VALUES (1, 'persistencia-ok') ON CONFLICT (id) DO UPDATE SET valor = EXCLUDED.valor;"
```

Consultar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

## 26.15. Fazer backup antes do update

```bash
mkdir -p backups
```

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec -T db \
  pg_dump -U symfony symfony \
  > backups/symfony-before-update.sql
```

Confirmar:

```bash
ls -lh backups/symfony-before-update.sql
```

## 26.16. Update para `1.1.0`

Alterar:

```dotenv
APP_VERSION=1.1.0
```

Obter:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull app
```

Aplicar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Confirmar:

```bash
curl -fsS http://localhost:8080/info
```

Resultado esperado:

```text
1.1.0
```

Validar saúde:

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
```

Confirmar persistência:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

## 26.17. Aplicar `1.2.0-rc1`

Alterar:

```dotenv
APP_VERSION=1.2.0-rc1
```

Obter e aplicar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull app
```

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Observar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Após as tentativas definidas no healthcheck, a aplicação deverá aparecer como:

```text
unhealthy
```

## 26.18. Confirmar que a aplicação continua a responder

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```

Esperado:

```text
/health → OK
/ready  → OK
/info   → 1.2.0-rc1
```

Isto demonstra que a causa é a configuração do Docker HEALTHCHECK, não necessariamente a indisponibilidade da aplicação.

## 26.19. Inspecionar causa

```bash
docker inspect CONTAINER_APP \
  --format '{{json .State.Health}}'
```

E:

```bash
docker inspect CONTAINER_APP \
  --format '{{json .Config.Env}}'
```

Procurar:

```text
HEALTH_PATH=/healthz
```

## 26.20. Rollback para `1.1.0`

Repor:

```dotenv
APP_VERSION=1.1.0
```

Aplicar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Validar:

```bash
curl -fsS http://localhost:8080/info
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
```

Confirmar:

```text
/info       → 1.1.0
/health     → OK
/ready      → OK
healthcheck → healthy
```

E voltar a consultar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

O dado deve permanecer.

## 26.21. O que este caso demonstra

```text
Código
  ↓
Dockerfile
  ↓
Imagem
  ↓
Scan
  ↓
Tag
  ↓
Registry
  ↓
Digest
  ↓
Deployment
  ↓
Healthcheck
  ↓
Update
  ↓
Falha
  ↓
Diagnóstico
  ↓
Rollback
```

E, em paralelo:

```text
container da aplicação muda
        │
        ▼
PostgreSQL mantém volume
        │
        ▼
dados preservados
        │
        └── backup lógico independente
```

---

# 27. Troubleshooting de build, imagem e deployment

Um método estruturado reduz tentativas aleatórias:

```text
1. Identificar fase
   ↓
2. Recolher evidência
   ↓
3. Formular hipótese
   ↓
4. Alterar uma variável
   ↓
5. Repetir
   ↓
6. Validar
```

## 27.1. `COPY` não encontra ficheiro

Questões:

```text
O ficheiro está dentro do build context?
O caminho é relativo ao contexto certo?
O .dockerignore excluiu-o?
```

Confirmar:

```bash
pwd
find . -maxdepth 3 -type f | sort
```

## 27.2. Build não reutiliza cache

Verificar:

- ordem das instruções;
- ficheiros copiados antes das operações pesadas;
- alteração de `composer.lock`;
- alteração da base;
- build args;
- uso de `--no-cache`.

Um cache miss é sintoma; a causa está nas entradas da layer.

## 27.3. Imagem ficou demasiado grande

```bash
docker image ls
docker history IMAGE
```

Perguntar:

```text
Ferramentas de build ficaram no runtime?
apt lists foram removidas?
Existem ficheiros temporários?
O contexto contém artefactos desnecessários?
Há duplicação de dependências?
```

## 27.4. Segredo ficou na imagem

Consultar:

```bash
docker history IMAGE
docker image inspect IMAGE
```

Se um segredo foi gravado numa layer, apagá-lo numa layer posterior não garante a sua remoção das layers anteriores.

A solução correta é reconstruir a imagem a partir de uma definição segura e considerar a rotação do segredo comprometido.

## 27.5. `unhealthy`

```bash
docker inspect CONTAINER \
  --format '{{json .State.Health}}'
```

Confirmar manualmente o comando do healthcheck.

Ver environment:

```bash
docker inspect CONTAINER \
  --format '{{json .Config.Env}}'
```

## 27.6. Push é recusado

Sintomas:

```text
denied
unauthorized
permission denied
```

Verificar:

- login;
- utilizador;
- token;
- scopes/permissões;
- namespace;
- nome completo da imagem.

## 27.7. `docker pull` não traz a versão esperada

Confirmar a referência:

```bash
docker pull REGISTRY/NAMESPACE/IMAGE:TAG
docker image inspect REGISTRY/NAMESPACE/IMAGE:TAG
```

Para controlo rigoroso, comparar também `RepoDigests`.

## 27.8. Update não muda `/info`

Verificar, por ordem:

```bash
docker compose ... config
docker compose ... pull app
docker image ls
docker compose ... ps
docker inspect CONTAINER_APP
curl http://localhost:8080/info
```

Possíveis causas:

- `.env` incorreto;
- versão não alterada;
- imagem não publicada;
- pull falhou;
- container antigo não foi recriado;
- endpoint usa metadata diferente do esperado.

## 27.9. Dados desapareceram

Verificar:

```bash
docker volume ls
docker inspect CONTAINER_DB
```

Perguntar:

```text
Foi usado down -v?
O projeto Compose mudou de nome?
O volume tem o mesmo nome?
O mount target é /var/lib/postgresql/data?
Foi criada outra base de dados?
```

## 27.10. Aplicação não arranca porque PostgreSQL não está pronto

```bash
docker compose ... ps
docker compose ... logs db
```

Confirmar estado do healthcheck de PostgreSQL:

```bash
docker inspect CONTAINER_DB \
  --format '{{json .State.Health}}'
```

A condição `service_healthy` só pode funcionar corretamente se o healthcheck da dependência representar uma condição útil.

## 27.11. Trivy devolve exit code `1`

Isso pode ser o comportamento configurado:

```bash
--exit-code 1
```

Não significa necessariamente falha da ferramenta. Pode significar que o quality gate detetou findings que correspondem à política.

---

# 28. Guia rápido

## Build

```bash
docker build -t IMAGE:TAG .
docker build -f CAMINHO_DOCKERFILE -t IMAGE:TAG .
docker build --build-arg CHAVE=VALOR -t IMAGE:TAG .
docker build --progress=plain -t IMAGE:TAG .
docker build --no-cache -t IMAGE:TAG .
```

## Build de referência

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

## Imagens

```bash
docker image ls
docker image inspect IMAGE:TAG
docker history IMAGE:TAG
```

## Labels

```bash
docker image inspect \
  IMAGE:TAG \
  --format '{{json .Config.Labels}}'
```

## Tag

```bash
docker tag \
  IMAGE_LOCAL:TAG \
  REGISTRY/NAMESPACE/IMAGE:TAG
```

## Registry

```bash
docker login REGISTRY
docker push REGISTRY/NAMESPACE/IMAGE:TAG
docker pull REGISTRY/NAMESPACE/IMAGE:TAG
docker logout REGISTRY
```

## Digest

```bash
docker image inspect \
  REGISTRY/NAMESPACE/IMAGE:TAG \
  --format '{{json .RepoDigests}}'
```

## Trivy

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  IMAGE:TAG
```

## Compose com override

```bash
docker compose \
  --env-file .env.prod \
  -f compose.yaml \
  -f compose.prod.yaml \
  config
```

```bash
docker compose \
  --env-file .env.prod \
  -f compose.yaml \
  -f compose.prod.yaml \
  pull
```

```bash
docker compose \
  --env-file .env.prod \
  -f compose.yaml \
  -f compose.prod.yaml \
  up -d
```

## Estado e logs

```bash
docker compose ps
docker compose logs
docker compose logs app
docker compose logs db
```

## Health

```bash
docker inspect CONTAINER \
  --format '{{json .State.Health}}'
```

## Backup PostgreSQL

```bash
docker compose exec -T db \
  pg_dump -U symfony symfony \
  > backup.sql
```

---

# 29. Glossário

| Termo | Definição |
|---|---|
| **Artefacto** | Resultado produzido por um processo de build e destinado a distribuição ou execução. |
| **Build** | Processo que transforma Dockerfile e contexto numa imagem. |
| **Build context** | Conjunto de ficheiros disponibilizado ao builder. |
| **BuildKit** | Backend moderno de build utilizado pelo ecossistema Docker. |
| **Buildx** | Interface avançada para builds com BuildKit. |
| **Cache** | Reutilização de resultados anteriores quando as entradas relevantes não mudaram. |
| **Digest** | Identificador criptográfico do conteúdo representado por uma imagem ou manifest. |
| **Dockerfile** | Ficheiro com instruções para construção de uma imagem. |
| **Healthcheck** | Teste periódico que determina um estado de saúde segundo uma condição configurada. |
| **Layer** | Camada imutável que compõe uma imagem. |
| **Multi-stage build** | Dockerfile com vários `FROM`, permitindo separar build de runtime. |
| **OCI label** | Metadata que utiliza convenções da Open Container Initiative. |
| **Pre-release** | Versão anterior a uma release final, como `1.2.0-rc1`. |
| **Registry** | Serviço de armazenamento e distribuição de imagens. |
| **Repository** | Coleção lógica de imagens e tags dentro de um registry. |
| **RepoDigest** | Referência repository@digest associada a conteúdo publicado num registry. |
| **Rollback** | Regresso a uma versão anteriormente conhecida como boa. |
| **Runtime image** | Imagem final que contém os componentes necessários para executar a aplicação. |
| **Scan** | Análise de uma imagem à procura de vulnerabilidades ou outros problemas conhecidos. |
| **Secret mount** | Mecanismo BuildKit que disponibiliza temporariamente um segredo durante o build. |
| **SemVer** | Convenção `MAJOR.MINOR.PATCH`, com suporte a pré-releases. |
| **Tag** | Referência legível e mutável associada a uma imagem. |
| **Vulnerability gate** | Regra que transforma findings de segurança em decisão automática de sucesso ou falha. |

---

# 30. Recursos e leituras complementares

## Livros de referência

### Docker Deep Dive

Nigel Poulton, edição de maio de 2025.

Temas relevantes:

- imagens e layers;
- Dockerfiles;
- build;
- BuildKit;
- registries;
- networking;
- volumes;
- segurança.

### The Ultimate Docker Container Book

Dr. Gabriel N. Schenker, Fourth Edition, 2026.

Temas relevantes:

- criação e gestão de imagens;
- Dockerfiles;
- multi-stage builds;
- supply chain;
- volumes;
- Compose;
- segurança;
- troubleshooting.

## Documentação oficial

Dockerfile reference:

```text
https://docs.docker.com/reference/dockerfile/
```

Docker Build:

```text
https://docs.docker.com/build/
```

BuildKit:

```text
https://docs.docker.com/build/buildkit/
```

Build secrets:

```text
https://docs.docker.com/build/building/secrets/
```

Build cache:

```text
https://docs.docker.com/build/cache/
```

Image CLI:

```text
https://docs.docker.com/reference/cli/docker/image/
```

Docker Compose:

```text
https://docs.docker.com/compose/
```

Compose file reference:

```text
https://docs.docker.com/reference/compose-file/
```

GitHub Container Registry:

```text
https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry
```

Trivy:

```text
https://trivy.dev/
```

Open Container Initiative:

```text
https://opencontainers.org/
```

> Para opções dependentes de versão, comportamento de flags, formatos Compose, BuildKit e ferramentas de scan, a documentação oficial deve ser considerada a referência operacional primária.
