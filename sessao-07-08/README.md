# Laboratório Integrado — Sessões 7 e 8

## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

Este laboratório integra numa única sessão prática os conteúdos das Sessões 7 e 8 da formação **Mini MBA em Orquestração de Containers com Kubernetes**.

A progressão pedagógica é:

```text
OBSERVAR
   ↓
DIAGNOSTICAR
   ↓
RECUPERAR
   ↓
GERIR CONFIGURAÇÃO
   ↓
GERIR RELEASES
   ↓
ROLLBACK
   ↓
ESTENDER A API
   ↓
RECONCILIAR
   ↓
VALIDAR
```

O laboratório combina:

- Alta Disponibilidade, monitorização e troubleshooting;
- diagnóstico estruturado de incidentes;
- recuperação de workloads;
- distinção entre HA, persistência, backup e recuperação;
- Kustomize;
- Helm;
- releases, upgrades e rollbacks;
- CRDs;
- Custom Resources;
- Controllers;
- Operators;
- extensão da Kubernetes API.

---

## 1. Identificação

| Elemento | Definição |
|---|---|
| Formação | Mini MBA em Orquestração de Containers com Kubernetes |
| Laboratório | Integrado — Sessões 7 e 8 |
| Duração | 4 horas / 240 minutos |
| Nível | Intermédio |
| N.º estimado de formandos | Até 5 |
| Ambiente | Kubernetes on-premises em VMs Ubuntu |
| Topologia base | 1 Control Plane + 2 Worker Nodes |
| Runtime | `containerd` |
| CNI | Calico |
| Aplicação | Symfony Demo + PostgreSQL 16 |
| Ferramentas | `kubectl`, Helm e Kustomize |
| Componente avançado previsto | Prometheus Operator |
| Metodologia | Cenário → sintoma → evidência → hipótese → teste → correção → validação |

---

## 2. Cenário

Os formandos assumem a administração de um cluster onde está em execução uma aplicação Web.

```text
                   Utilizador
                       │
                       ▼
                 Service / Ingress
                       │
                       ▼
                 Symfony Demo
                  Deployment
                  Pod      Pod
                       │
                       ▼
                  PostgreSQL
                       │
                       ▼
                      PVC

                Kubernetes Cluster

          Control Plane
               │
       ┌───────┴────────┐
       ▼                ▼
   Worker 01         Worker 02
```

Durante uma janela de manutenção será necessário:

```text
validar cluster
      ↓
gerir configuração com Kustomize
      ↓
instalar monitoring/operator com Helm
      ↓
provocar falhas
      ↓
diagnosticar
      ↓
recuperar
      ↓
executar upgrade
      ↓
detetar release defeituosa
      ↓
rollback
      ↓
trabalhar CRD / Custom Resource
      ↓
observar reconciliação
```

### Questão orientadora

> Conseguimos detetar uma degradação, encontrar a causa raiz, recuperar o serviço e gerir a evolução do cluster através de mecanismos declarativos e controladores Kubernetes?

---

## 3. Objetivos práticos

No final do laboratório, o formando deverá conseguir:

1. Validar o estado inicial de um cluster.
2. Aplicar um método estruturado de troubleshooting.
3. Utilizar `get`, `describe`, `logs` e `events` como fontes de evidência.
4. Distinguir sintoma de causa raiz.
5. Diagnosticar uma probe incorreta.
6. Diagnosticar um problema de Service/selector.
7. Analisar o impacto de um Worker `NotReady`.
8. Observar mecanismos de recuperação de workloads.
9. Explicar porque **HA ≠ backup**.
10. Identificar o papel do `etcd`.
11. Utilizar Kustomize para gerir variantes de configuração.
12. Instalar e consultar uma release Helm.
13. Executar `upgrade`, consultar histórico e realizar `rollback`.
14. Identificar CRDs adicionadas ao cluster.
15. Distinguir CRD de Custom Resource.
16. Identificar o Controller/Operator responsável pela reconciliação.
17. Modificar um Custom Resource e observar a reconciliação.
18. Validar tecnicamente a recuperação final do ambiente.

---

## 4. Distribuição temporal

| Tempo | Atividade |
|---:|---|
| 15 min | Bloco 1 — Baseline e recolha de evidência |
| 25 min | Bloco 2 — Gestão declarativa com Kustomize |
| 35 min | Bloco 3 — Helm + Prometheus Operator + CRDs |
| 30 min | Incidente 1 — Readiness probe incorreta |
| 15 min | **Intervalo** |
| 25 min | Incidente 2 — Service / selector incorreto |
| 35 min | Incidente 3 — Node `NotReady`, recuperação e HA |
| 35 min | Incidente 4 — Upgrade Helm defeituoso e rollback |
| 25 min | Custom Resource, reconciliação, síntese e limpeza |
| **240 min** | **Total** |

---

## 5. Estrutura prevista dos recursos

Os ficheiros operacionais serão desenvolvidos posteriormente mantendo esta organização:

```text
sessao-07-08/
│
├── README.md
├── 00-precheck/
│   └── precheck.sh
│
├── app/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   │
│   └── overlays/
│       ├── normal/
│       ├── incident-probe/
│       └── incident-service/
│
├── helm/
│   ├── app-lab/
│   └── values/
│       ├── values-good.yaml
│       └── values-broken.yaml
│
├── monitoring/
│   ├── values-lab.yaml
│   └── prometheus-rule.yaml
│
├── incidents/
│   ├── 01-probe.md
│   ├── 02-service.md
│   ├── 03-node.md
│   └── 04-release.md
│
└── solutions/
    └── SOLUCOES-FORMADOR.md
```

As soluções não deverão ser disponibilizadas inicialmente aos formandos.

---

# 6. Bloco 1 — Estado inicial do cluster

**Tempo:** 15 minutos

Regra operacional:

> Antes de alterar, observar.

### Consultar o ambiente

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
kubectl get deployments -A
kubectl get svc -A
kubectl get pvc -A
kubectl get events -A --sort-by=.lastTimestamp
```

Os formandos deverão registar:

| Questão | Evidência |
|---|---|
| Quantos Nodes estão `Ready`? | |
| Onde corre a aplicação? | |
| Quantas réplicas existem? | |
| Todos os Pods estão `Ready`? | |
| O PVC está `Bound`? | |
| Existem Events anómalos? | |

Mensagem-chave:

```text
"Está a funcionar"
       ≠
"Tenho evidência de que está saudável"
```

---

# 7. Bloco 2 — Gestão declarativa com Kustomize

**Tempo:** 25 minutos

O objetivo é mostrar que variantes de configuração não devem depender de edição manual no cluster.

### Estrutura

```text
app/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
│
└── overlays/
    └── normal/
        └── kustomization.yaml
```

### Visualizar o resultado

```bash
kubectl kustomize app/overlays/normal/
```

### Aplicar

```bash
kubectl apply -k app/overlays/normal/
```

### Validar

```bash
kubectl get all -n s78-lab
kubectl get pods -n s78-lab -o wide
```

Relação conceptual:

```text
Base
  +
Overlay
  ↓
manifest final
  ↓
Kubernetes API
```

Neste ponto é estabelecida a **baseline conhecida como boa**.

---

# 8. Bloco 3 — Helm + Operator + CRDs

**Tempo:** 35 minutos

Para evitar dependência da Internet durante a formação, o formador deverá disponibilizar previamente o chart Helm, imagens e versões validadas para o ambiente.

### Instalação conceptual

```bash
helm install monitoring \
  ./packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml
```

### Consultar a release

```bash
helm list -n monitoring
helm status monitoring -n monitoring
kubectl get pods -n monitoring
```

### Descobrir extensões da API

```bash
kubectl get crd
kubectl get crd | grep monitoring.coreos.com
```

Os formandos deverão identificar recursos como:

```text
Prometheus
ServiceMonitor
PrometheusRule
Alertmanager
```

Relação a consolidar:

```text
CRD
 │
 └── define um novo tipo na API
             │
             ▼
       Custom Resource
             │
             ▼
          Operator
             │
       observa alterações
             │
             ▼
         reconciliação
```

---

# 9. Incidente 1 — A aplicação corre, mas não está Ready

**Tempo:** 30 minutos

O formador aplica o overlay defeituoso:

```bash
kubectl apply -k app/overlays/incident-probe/
```

Sintoma esperado:

```text
Pod Running
mas
READY 0/1
```

O formando recebe apenas o sintoma e deverá aplicar:

```text
Sintoma
 ↓
Evidência
 ↓
Hipótese
 ↓
Teste
 ↓
Causa raiz
 ↓
Correção
 ↓
Validação
```

### Recolher evidência

```bash
kubectl get pods -n s78-lab
kubectl describe pod <POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl logs <POD> -n s78-lab
```

A causa preparada será uma **readiness probe incorreta**.

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab
kubectl get pods -n s78-lab
```

Critério de sucesso:

```text
Running + Ready
```

---

# 10. Incidente 2 — Pods saudáveis, Service sem funcionar

**Tempo:** 25 minutos

Cenário:

```text
Pod → Running
Pod → Ready
Service → existe

MAS

cliente → Service → falha
```

### Diagnóstico

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab
```

A causa preparada será um **selector incompatível com as labels dos Pods**.

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab
```

Relação a validar:

```text
Service
  ↓ selector
labels
  ↓
Pods
```

---

# 11. Incidente 3 — Worker Node `NotReady`

**Tempo:** 35 minutos

Se a turma partilhar um único cluster, esta tarefa deverá ser conduzida pelo formador.

### Antes da falha

```bash
kubectl get pods -n s78-lab -o wide
kubectl get nodes
```

### Falha controlada

No Worker selecionado:

```bash
sudo systemctl stop kubelet
```

### Observar

```bash
kubectl get nodes
kubectl get pods -n s78-lab -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

Questões de análise:

- O Node passa imediatamente a `NotReady`?
- O que acontece às réplicas?
- O Deployment tenta preservar o estado desejado?
- Existem réplicas noutro Worker?
- O Service continua com endpoints utilizáveis?

### Recuperar

```bash
sudo systemctl start kubelet
kubectl get nodes
kubectl get pods -n s78-lab -o wide
```

### Discussão obrigatória

```text
2 Pods em 2 Workers
       ↓
resiliência de workload

        ≠

Control Plane HA
```

E:

```text
Alta Disponibilidade
        ≠
Backup
        ≠
Recuperação
```

---

# 12. `etcd` — estado, disponibilidade e recuperação

Os formandos deverão identificar onde reside o estado do cluster:

```bash
kubectl get pods -n kube-system | grep etcd
```

Relação conceptual:

```text
Kubernetes API
      ↓
    etcd
      ↓
estado persistente
do cluster
```

O snapshot poderá ser demonstrado pelo formador no Control Plane.

> Não executar um restore de `etcd` no cluster principal durante este laboratório.

Mensagem-chave:

```text
redundância de etcd
     → disponibilidade

snapshot de etcd
     → ponto de recuperação
```

---

# 13. Incidente 4 — Helm upgrade defeituoso e rollback

**Tempo:** 35 minutos

### Consultar histórico

```bash
helm history symfony-lab -n s78-lab
```

### Aplicar versão conhecida como boa

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml
```

Validar:

```bash
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab
```

### Aplicar versão defeituosa

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml
```

A falha preparada poderá utilizar uma imagem/tag inexistente.

### Recolher evidência

```bash
kubectl get pods -n s78-lab
kubectl describe pod <POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
helm history symfony-lab -n s78-lab
```

### Rollback

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab
helm history symfony-lab -n s78-lab
```

Fluxo operacional:

```text
release nova
   ↓
falha
   ↓
evidência
   ↓
decisão
   ↓
rollback
   ↓
validação
```

---

# 14. Custom Resource e reconciliação

**Tempo incluído no bloco final:** 25 minutos

### Consultar objetos geridos pelo Prometheus Operator

```bash
kubectl get prometheus -A
kubectl get prometheusrule -A
```

Será fornecido um `PrometheusRule` preparado para o laboratório.

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule -n monitoring
```

Depois será alterado um campo do Custom Resource.

O objetivo é observar:

```text
Utilizador
   ↓
altera Custom Resource
   ↓
Kubernetes API
   ↓
Operator observa
   ↓
Controller executa lógica
   ↓
estado real converge
   ↓
estado pretendido
```

Não é objetivo ensinar a programar um Operator.

---

# 15. Registo obrigatório de troubleshooting

Para cada incidente, o formando deverá preencher:

| Campo | Registo |
|---|---|
| Sintoma inicial | |
| Primeira evidência | |
| Comandos utilizados | |
| Hipótese | |
| Teste efetuado | |
| Causa raiz | |
| Correção | |
| Evidência da recuperação | |

O objetivo é impedir que o laboratório se transforme numa simples sequência de comandos copiados.

---

# 16. Critérios de sucesso

| Critério | Evidência |
|---|---|
| Cluster validado | Nodes e componentes identificados |
| Baseline estabelecida | Aplicação operacional antes dos incidentes |
| Kustomize utilizado | Overlay aplicado |
| Helm utilizado | Release instalada e histórico consultado |
| CRDs identificadas | Recursos `monitoring.coreos.com` reconhecidos |
| Operator identificado | Controller em execução |
| Probe diagnosticada | Causa encontrada em `describe`/Events |
| Service diagnosticado | Selector/endpoints verificados |
| Falha de Node analisada | Impacto observado |
| Workload recuperado | Réplicas novamente disponíveis |
| Release defeituosa identificada | Events/estado demonstrados |
| Rollback executado | Revisão boa recuperada |
| Custom Resource utilizado | Recurso criado/alterado |
| Reconciliação compreendida | Alteração observada |
| HA distinguida de backup | Explicação tecnicamente correta |
| Troubleshooting documentado | Ficha de incidente preenchida |

---

# 17. Incidentes opcionais

Para formandos que concluam antecipadamente:

```text
EXTRA A
Pod → CrashLoopBackOff

EXTRA B
Pod → Pending

EXTRA C
DNS interno deixa de resolver

EXTRA D
NetworkPolicy bloqueia comunicação
```

Nos exercícios extra, o formando recebe apenas o sintoma. Não recebe a solução nem a sequência de comandos.

---

## Resultado pedagógico esperado

O laboratório deverá terminar com o formando a compreender e praticar o seguinte percurso:

```text
OBSERVAR
   ↓
DIAGNOSTICAR
   ↓
RECUPERAR
   ↓
GERIR CONFIGURAÇÃO
   ↓
GERIR RELEASES
   ↓
ROLLBACK
   ↓
ESTENDER A API
   ↓
RECONCILIAR
   ↓
VALIDAR
```

A componente de troubleshooting fornece o problema operacional; Helm, Kustomize, CRDs e Operators fornecem mecanismos estruturados para operar, recuperar e evoluir o cluster.
