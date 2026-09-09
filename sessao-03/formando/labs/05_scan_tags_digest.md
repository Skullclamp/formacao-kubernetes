# Lab 05 — Scan, Tags e Digest

**Duração prevista:** 20 minutos

## Objetivo

Executar análise de vulnerabilidades e distinguir referência versionada de identidade imutável.

## 1. Scan informativo

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Não compare o resultado com uma contagem fixa: a base de vulnerabilidades evolui.

## 2. Exemplo de quality gate

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0

echo "EXIT_CODE=$?"
```

Um exit code deve ser interpretado segundo a política definida. A severidade isolada não substitui análise de contexto, explorabilidade e mitigação.

## 3. Tag

```text
symfony-demo:1.1.0
```

A tag é uma referência que pode ser movida por quem controla o registry.

## 4. Digest

Depois de um pull/push:

```bash
docker image inspect "$IMAGE_REPO:1.1.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

O digest identifica o conteúdo de forma imutável.

## 5. Enquadramento

SBOM, assinatura e provenance fazem parte da segurança de supply chain, mas nesta sessão são apenas enquadrados conceptualmente.
