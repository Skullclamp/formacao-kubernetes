# Release candidata, diagnóstico e rollback

## Falha pedagógica

A release candidata altera **numa única revisão**:

```text
imagem 1.2.0-rc1
        +
readiness /ready-errado
```

A readiness deliberadamente inválida torna a falha determinística em Kubernetes. O Docker `HEALTHCHECK` da imagem não é automaticamente convertido numa probe Kubernetes.

## Aplicar

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml

kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=30s || true
```

## Diagnosticar

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get rs
kubectl -n "$NS" get pods -l app=symfony-demo -o wide
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -25
```

Identificar explicitamente o Pod `1.2.0-rc1`; não usar simplesmente o primeiro item da lista durante o RollingUpdate.

## Confirmar que a versão estável continua disponível

```bash
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/health
echo
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/ready
echo
```

## Rollback

```bash
kubectl -n "$NS" rollout history deployment/symfony-demo
kubectl -n "$NS" rollout undo deployment/symfony-demo
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

Confirmar imagem `1.1.0`, readiness `/ready`, Pods 2/2 e endpoints funcionais.

> `rollout undo` pode apresentar um warning quando o Deployment foi anteriormente gerido por `kubectl apply`, porque a annotation `last-applied-configuration` não é atualizada pelo rollback. Para o exercício mantém-se `rollout undo`; num fluxo declarativo/GitOps deve igualmente repor-se a configuração desejada na fonte e no pipeline/apply.

> O rollback restaura uma configuração anterior **criando uma nova revisão**. O número da revisão não regressa para trás.
