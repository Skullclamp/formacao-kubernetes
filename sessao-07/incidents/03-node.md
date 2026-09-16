# Incidente 3 — Degradação após falha de um Worker

## Como utilizar este incidente

Este incidente é executado em **modo acompanhado**. A ação disruptiva é controlada pelo formador e a turma acompanha, em tempo real, a evolução do Node, dos Pods, dos EndpointSlices e dos Events.

O objetivo não é deixar os formandos sozinhos a interpretar uma falha de infraestrutura. O formador conduz a observação e usa o incidente para explicar temporizações, eviction, taints, anti-affinity e limites reais de resiliência.

> Num cluster partilhado, apenas o formador executa a paragem e o arranque do `kubelet`.

---

## Situação

Um dos Worker Nodes deixa de comunicar normalmente com o cluster. A aplicação perde parte da sua capacidade e Kubernetes tenta reconciliar o estado desejado.

## Objetivo pedagógico

Observar a cadeia:

```text
Worker deixa de comunicar
        ↓
Node deixa de ser considerado saudável
        ↓
endpoints desse Node deixam de ser elegíveis
        ↓
controladores tentam repor as réplicas
        ↓
regras de scheduling podem limitar a recuperação
```

E distinguir:

```text
resiliência do workload
        ≠
HA do Control Plane
        ≠
backup / recuperação de dados
```

---

# 1. Conceitos antes da falha

## Worker Node

É um Node onde são executados workloads. Neste laboratório, os Pods Symfony e PostgreSQL executam nos Workers.

## kubelet

O `kubelet` é o agente do Node. Entre outras funções:

```text
comunica estado do Node à API
acompanha os Pods atribuídos ao Node
gere o ciclo de vida local dos containers
executa probes
```

## Condição `Ready`

A condição `Ready` indica se o Node é considerado saudável para executar workloads normalmente.

Durante uma perda de comunicação podem surgir estados como:

```text
Ready=True
Ready=False
Ready=Unknown
```

A mudança não é instantânea.

## Taints e tolerations

Kubernetes pode aplicar taints automáticos a Nodes `NotReady` ou `Unreachable`.

As tolerations dos Pods definem durante quanto tempo determinadas condições podem ser toleradas antes de o Pod ser marcado para eviction.

## Eviction

Uma réplica num Node indisponível não desaparece imediatamente da API. Existe um intervalo até Kubernetes considerar que deve ser substituída.

## Anti-affinity

As duas réplicas Symfony usam anti-affinity obrigatória por hostname.

```text
2 Workers saudáveis
→ 1 réplica em cada Worker

1 Worker saudável
→ pode existir capacidade livre
  mas a regra pode impedir colocar as 2 réplicas no mesmo Worker
```

---

# 2. Health gate antes da falha — executar em conjunto

```bash
kubectl get nodes -o wide
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Flags importantes

```text
-o wide
→ mostra IP e Node, permitindo saber onde cada Pod está colocado

-l app=symfony-demo
→ mostra apenas os Pods da aplicação Web
```

O formador identifica o Worker que contém uma réplica Symfony mas **não** o PostgreSQL. Esse será o Worker usado no incidente.

### Checkpoint acompanhado

Antes da falha, a turma deve conseguir responder:

```text
Onde corre o PostgreSQL?
Onde corre cada réplica Symfony?
Quantos endpoints prontos existem?
Qual Worker pode ser afetado sem interromper deliberadamente a base de dados?
```

---

# 3. Provocar a falha — ação exclusiva do formador

No Worker selecionado:

```bash
sudo systemctl stop kubelet
```

## Como interpretar

```text
systemctl stop kubelet
→ pára o agente Kubernetes nesse Node

sudo
→ executa a operação com privilégios administrativos
```

Isto não desliga a máquina. Simula uma perda do agente que mantém a comunicação operacional com o Control Plane.

---

# 4. Observar a evolução em tempo real

Num terminal:

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
kubectl get events -A --sort-by=.lastTimestamp
```

## Comandos e flags

```text
-w
→ mantém a consulta aberta e mostra alterações à medida que chegam da API

-A
→ inclui Events de todos os Namespaces

--sort-by=.lastTimestamp
→ ordena os Events por tempo
```

## Observação guiada pelo formador

A turma regista, por ordem:

```text
1. momento da paragem do kubelet
2. momento em que o Node deixa de estar Ready
3. estado do Pod no Node afetado
4. alteração das condições do endpoint
5. aparecimento de taints/Events
6. eventual eviction
7. criação de uma nova réplica
8. possível estado Pending da nova réplica
```

Não assumir tempos fixos: registar os valores efetivamente observados.

---

# 5. Explicar por que uma nova réplica pode ficar `Pending`

Se Kubernetes criar uma nova réplica e esta não for agendada, executar em conjunto:

```bash
kubectl get pods -n s78-lab -o wide
kubectl describe pod <POD_PENDING> -n s78-lab
```

O formador orienta a leitura dos Events de scheduling.

Perguntas guiadas:

```text
O Worker saudável já tem uma réplica Symfony?
A anti-affinity permite uma segunda réplica nesse Worker?
O Worker afetado tem taints?
O Control Plane é elegível para este workload?
```

O objetivo é perceber que:

```text
controlador quer 2 réplicas
        ↓
scheduler precisa de encontrar um Node elegível
        ↓
se não existir Node elegível
        ↓
Pod permanece Pending
```

---

# 6. Recuperar o Worker — ação do formador

No Worker:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

Depois, no terminal administrativo:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo \
  -n s78-lab \
  --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Interpretação

```text
systemctl start kubelet
→ inicia novamente o agente do Node

systemctl is-active kubelet
→ confirma se o serviço está ativo

rollout status
→ acompanha a convergência do Deployment para o estado desejado
```

---

# 7. Validação final acompanhada

O incidente termina quando existir evidência de:

```text
3 Nodes Ready
Symfony 2/2 Ready
PostgreSQL Ready
2 endpoints Symfony ready=true
```

## Registo na folha de evidências

| Campo | Registo |
|---|---|
| Worker afetado | |
| Tempo até mudança de estado | |
| Evidência no EndpointSlice | |
| Taint/Event relevante | |
| Momento aproximado da eviction | |
| Estado da réplica de substituição | |
| Razão de eventual Pending | |
| Evidência após recuperação | |

## Síntese a consolidar

```text
Kubernetes reconcilia estado desejado
mas necessita de recursos elegíveis para recuperar capacidade

1 réplica sobrevivente
→ resiliência do workload

não prova
→ HA do Control Plane

não substitui
→ backup ou recuperação de dados
```
