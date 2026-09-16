# Incidente 3 — Worker `NotReady`

## Situação

Um Worker deixa de comunicar normalmente com o cluster. Kubernetes tenta manter o estado desejado, mas as regras de scheduling podem limitar a recuperação imediata.

> A ação disruptiva é executada pelo formador.

## Objetivo

Observar:

```text
Worker indisponível
      ↓
Node NotReady / Unknown
      ↓
controladores detetam divergência
      ↓
Scheduler procura Node elegível
      ↓
workload converge quando possível
```

E distinguir:

```text
resiliência do workload ≠ HA do Control Plane ≠ backup
```

## Health gate

```bash
kubectl get nodes -o wide
kubectl get pod postgres-0 -n s7-lab -o wide
kubectl get pods -n s7-lab -l app=symfony-demo -o wide
```

Escolher o Worker que contém uma réplica Symfony mas não `postgres-0`.

## Provocar a falha

No Worker escolhido:

```bash
sudo systemctl stop kubelet
```

## Observar

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s7-lab -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

Se existir um Pod `Pending`:

```bash
kubectl describe pod <POD_PENDING> -n s7-lab
```

Perguntas orientadoras:

- Quando deixa o Node de estar `Ready`?
- O controlador tenta criar outra réplica?
- Existe um Node elegível?
- A anti-affinity permite colocar as duas réplicas no mesmo Worker?
- Que Event comprova a conclusão?

## Recuperar

No Worker:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

No terminal administrativo:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=300s
kubectl get pods -n s7-lab -o wide
```

Não avançar enquanto o Worker e a aplicação não tiverem regressado ao estado esperado.
