# Sessão 3 — Docker II

## Build, Imagens, Segurança, Registry e Deployment Single-host

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

Nesta sessão evoluímos da operação de containers para a construção e preparação de imagens destinadas a ambientes de execução controlados.

```text
Ubuntu Server limpo
  ↓
Docker Engine + containerd + Buildx + Compose
  ↓
Git + recursos da formação
  ↓
Dockerfile
  ↓
Build
  ↓
Layers / Cache / Multi-stage
  ↓
Hardening / Secrets
  ↓
HEALTHCHECK / Recursos / Logging
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
Diagnóstico
  ↓
Rollback
```

# 1. Ponto de partida — Ubuntu Server limpo

A VM do formando parte apenas de uma instalação limpa de **Ubuntu Server**.

O laboratório integrado inclui, passo a passo:

- instalação das ferramentas base;
- instalação do Docker pelo repositório oficial;
- explicação de Docker CLI, Docker Engine, `containerd`, `runc`, Buildx e Compose;
- validação com `hello-world`;
- configuração do grupo `docker` com a respetiva nota de segurança;
- instalação do Trivy;
- clonagem do repositório da formação;
- preparação do source Symfony;
- build, segurança, scan, registry, deployment, update, falha e rollback.

# 2. Laboratório único da sessão

Os sete laboratórios anteriores foram substituídos por um único percurso integrado:

[**Laboratório Integrado — da VM Ubuntu Server limpa ao deployment e rollback**](formando/labs/laboratorio_integrado_sessao_3.md)

O laboratório segue sempre o mesmo modelo pedagógico:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

A regra da sessão mantém-se:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Os scripts existentes em `formando/scripts/` permanecem como exemplos de automação. Só são utilizados depois de os passos manuais correspondentes terem sido compreendidos.

# 3. Aplicação utilizada

O cenário utiliza:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16;
- Docker Compose.

A preparação do código é realizada por:

```bash
./comum/prepare-source.sh
```

O script aplica os endpoints pedagógicos:

```text
/info
/health
/ready
```

# 4. Imagens públicas da formação

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

| Versão | Utilização |
|---|---|
| `1.0.0` | deployment inicial |
| `1.1.0` | atualização válida |
| `1.2.0-rc1` | falha controlada de HEALTHCHECK |

# 5. Documentação da sessão

- [Plano da Sessão 3](plano_sessao_3.md)
- [Manual do formando](manual_formando.md)
- [Guia do formando](formando/guia_formando.md)
- [Laboratório integrado](formando/labs/laboratorio_integrado_sessao_3.md)
- [Cheat sheet](cheat_sheet.md)
- [Checklist final](checklist.md)
- [Referências](referencias.md)

# 6. Conceitos-chave

## Registry

Um **container registry** armazena e distribui imagens de containers. Na formação utilizamos o GitHub Container Registry, `ghcr.io`.

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
│       │          │            │
registry namespace  repositório   tag
```

## Saúde e prontidão

```text
/health → saúde básica da aplicação
/ready  → aplicação pronta, incluindo dependência da DB
/info   → versão e ambiente
```

> Docker `HEALTHCHECK` não é convertido automaticamente numa probe Kubernetes.

## Persistência

```text
Persistência ≠ Backup
```

## Promoção

```text
BUILD ONCE
    ↓
Imagem / Digest
    ↓
DEV → TEST → PROD
```

## Limite do cenário

```text
Docker Compose single-host
           ≠
     Alta Disponibilidade
           ≠
        Kubernetes
```
