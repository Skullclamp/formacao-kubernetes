# Incidente 3 — Degradação após falha de um Worker

## Situação entregue ao formando

Durante o funcionamento normal da aplicação ocorre uma falha num dos Worker Nodes. A equipa deve observar o impacto, recolher evidência e acompanhar a recuperação.

> Se a turma utilizar um cluster partilhado, a ação disruptiva é executada exclusivamente pelo formador.

Neste incidente, a falha do Worker faz parte do cenário e não é necessário descobrir **que Node falhou**. O trabalho de diagnóstico consiste em perceber **como Kubernetes reage**, que capacidade permanece disponível e por que razão o cluster pode não conseguir repor imediatamente todas as réplicas.

---

## Objetivo

Observar e explicar a cadeia:

```text
Worker deixa de comunicar
        ↓
estado do Node degrada-se
        ↓
endpoints associados deixam de ser elegíveis
        ↓
controladores tentam reconciliar o estado desejado
        ↓
regras de scheduling/capacidade podem limitar a recuperação
```

E distinguir corretamente:

```text
resiliência do workload
        ≠
Alta Disponibilidade do Control Plane
        ≠
backup / recuperação de dados
```

---

## Conceitos a compreender antes do incidente

### Worker Node

Um Worker Node é uma máquina onde o Kubernetes executa workloads. Entre os componentes mais relevantes está o `kubelet`.

### kubelet

O `kubelet` é o agente do Node. Entre outras funções:

```text
comunica o estado do Node à API
acompanha os Pods atribuídos ao Node
gere o ciclo de vida local dos containers
executa probes
```

Se o Control Plane deixar de receber atualizações do Node, o estado do Node pode deixar de ser considerado saudável.

### Condição `Ready` do Node

A condição `Ready` indica se Kubernetes considera o Node disponível para executar workloads normalmente.

Durante uma perda de comunicação podem surgir estados como:

```text
Ready=True
Ready=False
Ready=Unknown
```

A transição não é necessariamente instantânea.

### Taints e tolerations

Kubernetes pode aplicar taints automáticos a Nodes problemáticos, por exemplo associados a estados `not-ready` ou `unreachable`.

Um taint influencia onde os Pods podem permanecer ou ser agendados. As `tolerations` definem se, e em que condições, um Pod tolera esse taint.

### Eviction

Uma réplica num Node indisponível não é necessariamente removida imediatamente. Existem temporizações e mecanismos de eviction que podem atrasar a substituição.

### Pod Anti-Affinity

Neste laboratório, as duas réplicas Symfony têm anti-affinity obrigatória por hostname. Isso significa que duas réplicas da aplicação não devem executar no mesmo Worker.

Consequência:

```text
2 Workers saudáveis
→ 2 réplicas distribuídas

1 Worker saudável
→ pode existir capacidade física
  mas a regra de placement pode impedir 2 réplicas no mesmo Worker
```

---

# 1. Registar a baseline antes da falha

Antes de o formador provocar a falha:

```bash
kubectl get nodes -o wide
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Como interpretar os comandos e flags

```text
kubectl get nodes -o wide
→ mostra estado, função, versão e IP dos Nodes

kubectl get pod postgres-0 -o wide
→ identifica o Worker onde está a base de dados

-l app=symfony-demo
→ filtra apenas os Pods da aplicação Web

-o wide
→ mostra o Node e o IP de cada Pod
```

### O que observar

Registar explicitamente:

```text
Node do PostgreSQL
Node da réplica Symfony A
Node da réplica Symfony B
IPs dos endpoints
estado Ready dos 3 Nodes
```

A baseline é indispensável para comparar o estado antes e depois da falha.

---

# 2. Observar a transição do Node

Quando o formador indicar o início do incidente:

```bash
kubectl get nodes -w
```

### Como interpretar

```text
-w
→ mantém a consulta aberta e mostra alterações ao objeto à medida que chegam da API
```

Registar o instante aproximado do início da falha e o instante em que o estado do Node muda.

Não assumir um tempo fixo: observar o valor real no cluster.

---

# 3. Observar o impacto nos Pods e no Service

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
kubectl get events -A --sort-by=.lastTimestamp
```

### O que observar

Nos Pods:

```text
STATUS
READY
NODE
AGE
```

No EndpointSlice:

```yaml
conditions:
  ready:
  serving:
  terminating:
```

Nos Events, procurar mensagens relacionadas com:

```text
Node
scheduling
eviction
taints
criação de réplicas
```

### Pergunta importante

Um Pod que continua temporariamente apresentado como `Running` num Node que deixou de comunicar prova que a aplicação continua realmente acessível nesse Node?

A resposta deve ser baseada no EndpointSlice e no estado do Node, não apenas na coluna `STATUS` do Pod.

---

# 4. Inspecionar o Node afetado

Depois de identificada a degradação:

```bash
kubectl describe node <NODE_AFETADO>
```

Se necessário, observar apenas taints:

```bash
kubectl get node <NODE_AFETADO> \
  -o jsonpath='{.spec.taints}{"\n"}'
```

### Como interpretar

`kubectl describe node` permite observar:

```text
Conditions
Taints
Events
capacidade e allocatable
Pods atribuídos ao Node
```

A secção `Conditions` é particularmente importante para distinguir um Node saudável de um Node cujo estado deixou de ser conhecido.

---

# 5. Observar tolerations da réplica afetada

Identificar um Pod Symfony associado ao Node afetado e executar:

```bash
kubectl get pod <POD_AFETADO> -n s78-lab \
  -o jsonpath='{.spec.tolerations}{"\n"}'
```

### Conceito

As tolerations podem incluir um período temporal antes de um Pod ser removido de um Node `NotReady` ou `Unreachable`.

O objetivo não é decorar um número fixo, mas relacionar:

```text
taint do Node
      +
toleration do Pod
      ↓
tempo até eventual eviction
```

Registar os valores realmente observados.

---

# 6. Analisar uma eventual réplica `Pending`

Se Kubernetes criar uma réplica de substituição e esta ficar `Pending`:

```bash
kubectl get pods -n s78-lab -o wide
kubectl describe pod <POD_PENDING> -n s78-lab
```

### O que procurar

Na secção Events do Pod, observar o motivo real apresentado pelo scheduler.

Relacionar com os conceitos:

```text
Node indisponível
Control Plane não elegível para workload normal
Pod Anti-Affinity obrigatória
```

Uma mensagem `FailedScheduling` é evidência muito mais forte do que assumir genericamente que “não há recursos”.

---

# 7. Acompanhar a recuperação

Depois de o formador repor o Worker:

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

### O que significa

A recuperação só fica demonstrada quando houver novamente evidência de:

```text
Node afetado Ready
Deployment 2/2 Ready
2 réplicas em Workers elegíveis
2 endpoints ready=true
```

---

## Questões de análise

1. Qual foi o primeiro sintoma observável?
2. Quanto tempo decorreu entre o início da falha e a mudança de estado do Node?
3. Que Pods estavam associados ao Node afetado?
4. O estado apresentado pelo Pod permaneceu temporariamente desatualizado?
5. O Service manteve pelo menos um endpoint utilizável?
6. Que taints surgiram no Node?
7. Que tolerations existiam no Pod?
8. Foi criada uma réplica de substituição?
9. Se ficou `Pending`, que razão concreta apresentou o scheduler?
10. Que mecanismo manteve algum nível de serviço?
11. Esta experiência prova HA do Control Plane? Porquê?
12. Esta experiência constitui um backup? Porquê?

---

## Registo do incidente

| Campo | Registo |
|---|---|
| Node afetado | |
| Instante aproximado do início da falha | |
| Estado inicial | |
| Estado após degradação | |
| Tempo até mudança de estado | |
| Réplica Symfony afetada | |
| Estado apresentado pelo Pod | |
| Estado do endpoint correspondente | |
| Taints observados | |
| Tolerations relevantes | |
| Events relevantes | |
| Réplica de substituição criada? | |
| Motivo de `Pending`, se aplicável | |
| Endpoints ainda utilizáveis | |
| Evidência após recuperação | |

---

## CHECKPOINT — Incidente 3 concluído

O incidente só fica concluído quando o formando consegue demonstrar e explicar:

```text
falha de Worker
      ↓
degradação do Node
      ↓
remoção do endpoint não saudável
      ↓
tentativa de reconciliação
      ↓
limite imposto por placement/capacidade
      ↓
recuperação do Worker
      ↓
2/2 réplicas e 2 endpoints
```

E distinguir:

```text
resiliência do workload
        ≠
HA do Control Plane
        ≠
backup / recuperação de dados
```
