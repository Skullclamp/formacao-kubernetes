# Sessão 10 — Micropráticas M6

## Cloud-native, Kustomize e Helm

**Duração total:** 30 minutos  
**Posição:** bloco anterior ao laboratório integrado final.

## 1. Cloud-native / 12-factor — 10 min

Identificar no cenário:

| Princípio | Evidência no laboratório |
|---|---|
| configuração externalizada | ConfigMap + Secret |
| backing service | PostgreSQL |
| processo Web replicável | Pods Symfony |
| logs | stdout/stderr via `kubectl logs` |
| build/release/run | imagem separada da configuração e do Deployment |
| exposição | Service / Ingress |

Mensagem-chave: reconhecer decisões cloud-native, não memorizar uma lista.

## 2. Kustomize — 10 min

Estrutura:

```text
m6_kustomize/
├── base/
└── overlays/
    ├── dev/
    └── prod/
```

Renderizar:

```bash
kubectl kustomize m6_kustomize/overlays/dev
kubectl kustomize m6_kustomize/overlays/prod
```

Comparar `APP_ENV`, réplicas e CPU request.

Aplicar DEV:

```bash
kubectl -n "$NS" apply -k m6_kustomize/overlays/dev
kubectl -n "$NS" rollout status deployment/symfony-demo-kustomize-dev --timeout=90s
```

Remover:

```bash
kubectl -n "$NS" delete -k m6_kustomize/overlays/dev
```

## 3. Helm — 10 min

Renderizar:

```bash
helm template symfony-demo-helm m6_helm/symfony-demo
```

Instalar/atualizar:

```bash
helm upgrade --install symfony-demo-helm \
  m6_helm/symfony-demo \
  --namespace "$NS" \
  --set replicaCount=1
```

Consultar:

```bash
helm status symfony-demo-helm --namespace "$NS"
helm history symfony-demo-helm --namespace "$NS"
```

Remover:

```bash
helm uninstall symfony-demo-helm --namespace "$NS"
```

> As micropráticas reutilizam `symfony-demo-config` e `postgres-credentials` do baseline. O objetivo é compreender o fluxo de gestão por ambientes/releases, não aprofundar templating.
