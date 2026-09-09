# Sessão 3 — Docker II

## Build, Imagens, Segurança, Registry e Deployment Single-host

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

Nesta sessão evoluímos da operação de containers para a construção e preparação de imagens destinadas a ambientes de execução controlados.

```text
Código
  ↓
Dockerfile
  ↓
Build
  ↓
Layers / Cache
  ↓
Multi-stage
  ↓
Hardening
  ↓
Healthcheck
  ↓
Scan
  ↓
Tag / Digest
  ↓
Registry
  ↓
Deployment
  ↓
Update
  ↓
Falha
  ↓
Rollback
```

## 1. Começar numa VM nova

Os recursos da sessão estão no GitHub. Antes de executar qualquer laboratório, o formando deve ter uma cópia local do repositório.

### Primeira utilização

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

### Se o repositório já existir

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Confirme que está na raiz da Sessão 3:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

Todos os comandos dos Labs 01–07 assumem como diretoria de trabalho:

```text
formacao-kubernetes/sessao-03
```

## 2. Preparar o código da aplicação

O laboratório utiliza:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16;
- Docker Compose.

O código da aplicação não é armazenado permanentemente na pasta da sessão. Depois do clone, execute:

```bash
./comum/prepare-source.sh
```

O script descarrega a versão de referência e aplica os endpoints pedagógicos `/info`, `/health` e `/ready`.

Confirme:

```bash
test -f app/composer.json && echo 'OK: aplicação preparada'
```

## 3. Pré-requisitos

```bash
docker version
docker compose version
git --version
curl --version
```

Para o Lab 05:

```bash
trivy --version
```

## 4. Regra pedagógica dos scripts

Os scripts existem para demonstrar automação e para suportar o cenário operacional final. **Não substituem a aprendizagem manual.**

A progressão da sessão é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Nos Labs 01–06, os comandos principais são executados manualmente antes de usar qualquer script equivalente. No Lab 07, os scripts são utilizados deliberadamente porque o objetivo já é integrar deploy, validação, update, falha e rollback.

Sempre que um script for introduzido:

1. identifique os passos que já executou manualmente;
2. abra o script;
3. localize esses passos no código;
4. só depois execute o script.

## Documentação da sessão

- [Plano da Sessão 3](plano_sessao_3.md)
- [Manual do formando](manual_formando.md)
- [Guia do formando](formando/guia_formando.md)
- [Cheat sheet](cheat_sheet.md)
- [Checklist final](checklist.md)
- [Referências](referencias.md)

## Laboratórios

1. [Dockerfile e build](formando/labs/01_dockerfile_build.md)
2. [Layers, cache e multi-stage](formando/labs/02_layers_cache_multistage.md)
3. [Hardening e secrets](formando/labs/03_hardening_secrets.md)
4. [Healthcheck e operação](formando/labs/04_healthcheck_operacao.md)
5. [Scan, tags e digest](formando/labs/05_scan_tags_digest.md)
6. [Registry e promoção](formando/labs/06_registry_promocao.md)
7. [Deploy, update, falha e rollback](formando/labs/07_deploy_update_rollback.md)

## Imagens públicas da formação

As imagens de referência podem ser obtidas sem autenticação:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

| Versão | Utilização |
|---|---|
| `1.0.0` | Deployment inicial |
| `1.1.0` | Atualização válida |
| `1.2.0-rc1` | Falha controlada de healthcheck |

## Push para um registry pessoal

Para publicar num namespace próprio é necessária autenticação e permissão de escrita. O Lab 06 ensina primeiro `docker tag` e `docker push` manualmente; só depois apresenta `push.sh` como automatização.

Nunca colocar tokens no repositório.

## Saúde e prontidão

```text
/health → saúde básica da aplicação
/ready  → disponibilidade da aplicação, incluindo a base de dados
/info   → versão e ambiente
```

> O Docker `HEALTHCHECK` da imagem não é convertido automaticamente numa probe Kubernetes.

## Persistência

PostgreSQL utiliza um named volume. A substituição do container ou da imagem não deve implicar a perda dos dados persistentes.

```text
Persistência ≠ Backup
```

## Conceito principal

```text
BUILD ONCE
    ↓
Imagem / Digest
    ↓
DEV → TEST → PROD
```

O mesmo artefacto deve ser promovido entre ambientes.

## Importante

```text
Docker Compose single-host
           ≠
     Alta Disponibilidade
           ≠
        Kubernetes
```

Esta sessão prepara a aplicação e os artefactos. A orquestração distribuída será trabalhada posteriormente em Kubernetes.
