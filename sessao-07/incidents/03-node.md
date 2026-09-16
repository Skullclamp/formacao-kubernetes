# Incidente 3 — Worker `NotReady`

## Situação

Um Worker deixa de comunicar normalmente com o cluster. Kubernetes tenta manter o estado desejado, mas as regras de scheduling podem limitar a recuperação imediata.

> A ação disruptiva é executada pelo formador.

## Objetivo

Observar:

```text
Worker indisponível
      ↓
Node NotReady
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

No Worker escolhido, parar **apenas o kubelet**:

```bash
sudo systemctl stop kubelet
```

> Não parar `containerd`, não desligar a VM e não tocar no Control Plane. Este cenário demonstra perda de heartbeat/gestão do Node, não uma falha física completa.

## Observar

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s7-lab -o wide
kubectl get deployment symfony-demo -n s7-lab
kubectl get events -n s7-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Se existir um Pod `Pending`:

```bash
kubectl describe pod <POD_PENDING> -n s7-lab
```

## Evidência esperada

No cenário validado observou-se:

- o Worker passa a `NotReady`;
- PostgreSQL mantém-se saudável no outro Worker;
- a aplicação perde redundância, mas conserva uma réplica Symfony elegível;
- o Pod do Worker indisponível pode permanecer algum tempo antes de ser marcado para remoção;
- o controlador cria uma réplica de substituição;
- a nova réplica pode ficar `Pending` porque a anti-affinity obrigatória impede colocá-la no Worker que já contém a outra réplica e os restantes Nodes não são elegíveis;
- no EndpointSlice, o endpoint do Worker indisponível pode aparecer com `ready: false`, enquanto o backend saudável permanece `ready: true`.

Isto demonstra:

```text
estado desejado ≠ convergência imediata
```

Perguntas orientadoras:

- Quando deixa o Node de estar `Ready`?
- O controlador tenta criar outra réplica?
- Existe um Node elegível?
- A anti-affinity permite colocar as duas réplicas no mesmo Worker?
- Que Event comprova a conclusão?
- O Service conserva pelo menos um backend `ready=true`?

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
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Não avançar enquanto:

- o Worker não estiver `Ready`;
- o Deployment não estiver `2/2`;
- as duas réplicas Symfony não estiverem `1/1 Running`;
- os dois endpoints não estiverem `ready: true`.
