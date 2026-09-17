# Sessão 9 — Baseline reutilizado na Sessão 10

A Sessão 9 deixa preparado o estado M3/M4 que será operado e reforçado na Sessão 10.

## Resultado esperado

```text
ConfigMap + Secret
        ↓
Deployment Symfony (sem resources/probes de M5)
        ↓
Service
        ↓
Ingress (quando utilizado)

PostgreSQL StatefulSet
        ↓
PVC persistente
```

A aplicação deve responder internamente a:

```text
/health → saúde básica
/ready  → prontidão, incluindo ligação à base de dados
/info   → versão e ambiente
```

## Ordem sugerida

```bash
kubectl apply -f baseline/01-configmap.yaml
# criar/adaptar primeiro o Secret real a partir de 02-secret.example.yaml
kubectl apply -f baseline/03-postgresql.yaml
kubectl apply -f baseline/04-symfony-deployment.yaml
kubectl apply -f baseline/05-symfony-service.yaml
kubectl apply -f baseline/06-ingress.example.yaml   # opcional / adaptar host
```

> `02-secret.example.yaml` contém placeholders. Não o aplicar sem substituir os valores. Na formação, o Secret pode ser pré-provisionado pelo formador para evitar exposição de credenciais.

## Nota pedagógica

O Deployment desta pasta não contém resources nem probes. Esses elementos entram propositadamente na Sessão 10 (`01_resources_probes`) para não antecipar M5.
