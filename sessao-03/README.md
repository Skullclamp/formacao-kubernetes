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

## Aplicação utilizada

O laboratório utiliza:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16;
- Docker Compose.

O código da aplicação não é armazenado neste diretório. É preparado através de:

```bash
./comum/prepare-source.sh
```

O script descarrega a versão de referência e aplica os endpoints pedagógicos `/info`, `/health` e `/ready`.

## Preparação

A partir da raiz do repositório:

```bash
cd sessao-03
./comum/prepare-source.sh
```

Confirmar:

```bash
docker version
docker compose version
```

Para o Lab 05:

```bash
trivy --version
```

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

Para publicar num namespace próprio é necessária autenticação e permissão de escrita:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
./formando/scripts/push.sh 1.0.0
```

Nunca colocar tokens no repositório.

## Deployment single-host

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
./formando/scripts/compose-prod.sh config
./formando/scripts/deploy-prod.sh 1.0.0
./formando/scripts/deploy-prod.sh 1.1.0
./formando/scripts/rollback.sh 1.1.0
```

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

## Scan de vulnerabilidades

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Os resultados variam com a base de vulnerabilidades disponível; não devem ser comparados através de contagens fixas.

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
