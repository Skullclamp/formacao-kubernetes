# Folha de Evidências — Laboratório Integrado Sessões 7 e 8

## Como utilizar esta folha

Esta folha acompanha um **laboratório orientado pelo formador**. Não é uma ficha de avaliação autónoma nem um guião para o formando resolver sozinho.

Em cada checkpoint:

```text
formador explica o conceito
        ↓
turma executa os comandos
        ↓
formador orienta a leitura do output
        ↓
turma regista a evidência essencial
        ↓
formador valida antes de avançar
```

O objetivo é criar hábitos de observação e validação sem transformar o laboratório numa coleção de respostas escritas.

> **Regra de evidência:** um comando terminar sem erro não prova que o sistema está saudável. O estado observado tem de confirmar o objetivo do passo.

---

# CP0 — Pré-validação mínima do ambiente

## O que o formador pretende confirmar

Que as ferramentas e o cluster estão prontos para iniciar o laboratório.

| Verificação acompanhada | Evidência observada | OK? |
|---|---|:---:|
| `git`, `kubectl` e Helm disponíveis | | |
| API Kubernetes acessível | | |
| 2 Workers `Ready` e schedulable | | |
| `local-path` disponível | | |
| Calico identificado | | |
| Kustomize integrado disponível | | |
| Helm suporta `--take-ownership` | | |

> As máquinas Ubuntu dos formandos são criadas de raiz. Não é necessário registar ou comparar `machine-id`, UUIDs ou identificadores equivalentes.

**Gate acompanhado:** o formador confirma os pré-requisitos antes de avançar.

---

# CP1 — Obter os materiais e criar a baseline

## Conceitos acompanhados

```text
Git → obter os materiais
Kustomize → compor manifests
apply → declarar estado desejado
rollout status → observar convergência
```

| Verificação acompanhada | Evidência observada | OK? |
|---|---|:---:|
| Repositório descarregado | | |
| Diretoria `sessao-07-08/` disponível | | |
| Chart `kube-prometheus-stack-91.4.1.tgz` disponível | | |
| `precheck.sh` concluído | | |
| PostgreSQL `Running` e `Ready` | | |
| PVC `Bound` | | |
| 2 Pods Symfony `Running` e `Ready` | | |
| Réplicas em Workers diferentes | | |
| Service com 2 endpoints prontos | | |

### Síntese oral guiada

O formando deve conseguir explicar:

```text
manifesto aplicado ≠ aplicação validada
```

---

# CP2 — Helm, Operator, CRDs e PrometheusRule

## Conceitos acompanhados

```text
Helm Chart → pacote
Values     → configuração
Release    → instalação concreta
CRD        → novo tipo de recurso
CR         → instância desse tipo
Operator   → observa e reconcilia
```

| Verificação acompanhada | Evidência observada | OK? |
|---|---|:---:|
| Release `monitoring` instalada | | |
| Pods de monitorização operacionais | | |
| CRDs `monitoring.coreos.com` presentes | | |
| Prometheus Custom Resource existe | | |
| StatefulSet/Pods gerados identificados | | |
| `PrometheusRule` aceite pela API | | |

### Relação a completar em conjunto

```text
CRD
 ↓
____________________
 ↓
Operator / Controller
 ↓
____________________
```

---

# CP3 — Incidente 1: `Running` mas não `Ready`

## Método acompanhado

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

| Etapa | Evidência essencial observada |
|---|---|
| Sintoma inicial | |
| Estado da réplica antiga | |
| Estado da nova réplica | |
| Condição do endpoint da nova réplica | |
| Event/`describe` relevante | |
| Hipótese formulada em conjunto | |
| Teste efetuado | |
| Causa raiz identificada | |
| Correção declarativa aplicada | |
| Estado após recuperação | |

### Conceito a consolidar

```text
Running ≠ Ready
```

O formando deve conseguir explicar oralmente como a readiness protege o tráfego e influencia o rollout.

---

# CP4 — Incidente 2: Service sem endpoints

## Relação acompanhada

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
```

| Etapa | Evidência essencial observada |
|---|---|
| Pods `Running/Ready` | |
| Selector observado no Service | |
| Labels observadas nos Pods | |
| EndpointSlice durante a falha | |
| Hipótese formulada em conjunto | |
| Teste com selector | |
| Causa raiz identificada | |
| Correção aplicada | |
| EndpointSlice após correção | |

### Conceito a consolidar

```text
Service existente ≠ Service com backends
```

---

# CP5 — Incidente 3: Worker `NotReady`

Este checkpoint é acompanhado em tempo real. A ação disruptiva é executada pelo formador.

| Momento observado | Evidência / tempo aproximado |
|---|---|
| Worker escolhido | |
| Distribuição inicial dos Pods | |
| Paragem do `kubelet` | |
| Node deixa de estar `Ready` | |
| Endpoint do Node afetado deixa de estar pronto | |
| Taint/Event relevante | |
| Eviction observada | |
| Nova réplica criada | |
| Estado da nova réplica | |
| Razão de eventual `Pending` | |
| Arranque do `kubelet` | |
| Node recupera `Ready` | |
| Aplicação regressa a 2/2 | |

### Conceitos a consolidar em conjunto

```text
kubelet
Node Ready
Taints / tolerations
Eviction
Anti-affinity
Scheduling
```

E distinguir:

```text
resiliência do workload ≠ HA do Control Plane ≠ backup
```

---

# CP6 — Control Plane, etcd, HA e recuperação

## Identificação acompanhada

| Componente | Onde foi observado? | Função discutida |
|---|---|---|
| `kube-apiserver` | | |
| `kube-controller-manager` | | |
| `kube-scheduler` | | |
| `etcd` | | |

### Completar em conjunto

```text
1 Control Plane
→ _______________________________________________

redundância de etcd
→ _______________________________________________

snapshot de etcd
→ _______________________________________________
```

O objetivo é distinguir disponibilidade, persistência e recuperação sem provocar uma falha destrutiva no único Control Plane.

---

# CP7 — Transição Kustomize → Helm

## Conceitos acompanhados

```text
Kustomize → composição declarativa de YAML
Helm      → templates + values + release + histórico
ownership → quem passa a gerir os objetos
```

| Verificação acompanhada | Evidência observada | OK? |
|---|---|:---:|
| `helm template` renderizado | | |
| `kubectl diff -n s78-lab` analisado | | |
| Alterações funcionais inesperadas ausentes | | |
| `--take-ownership` executado | | |
| Deployment gerido por Helm | | |
| Release `symfony-lab` criada | | |
| Baseline Helm `2/2` | | |
| 2 endpoints prontos | | |

### Health gate

O formador só avança para o upgrade defeituoso depois de a turma confirmar uma baseline Helm comprovadamente saudável.

---

# CP8 — Incidente 4: release defeituosa e rollback

## Método acompanhado

| Etapa | Evidência essencial observada |
|---|---|
| Revisão boa inicial | |
| Revisão candidata | |
| Estado da release após upgrade | |
| Estado da réplica anterior | |
| Estado do novo Pod | |
| Endpoint ainda utilizável | |
| Event/`describe` principal | |
| Hipótese formulada em conjunto | |
| Teste sobre imagem/configuração | |
| Causa raiz identificada | |
| Revisão escolhida para rollback | |
| Nova revisão criada pelo rollback | |
| Estado após rollback | |
| 2 endpoints novamente prontos | |

### Conceitos a consolidar

```text
Chart
Values
Release
Revision
Upgrade
Rollback
Configuration drift
```

O formando deve conseguir explicar oralmente por que não se corrige este incidente com `kubectl edit`.

---

# CP9 — Alterar um Custom Resource e provar reconciliação

## Cadeia acompanhada

```text
Custom Resource alterado
        ↓
generation muda
        ↓
Operator observa
        ↓
Prometheus recebe nova configuração
```

| Verificação acompanhada | Evidência observada | OK? |
|---|---|:---:|
| Campo do `PrometheusRule` alterado | | |
| `generation` antes/depois | | |
| `resourceVersion` antes/depois | | |
| Nova `summary` visível no CR | | |
| Nova `summary` visível em `/api/v1/rules` | | |
| Estado da regra observado | | |
| Regra original reposta | | |

### Prova forte de reconciliação

A alteração não fica apenas armazenada na API Kubernetes: deve tornar-se visível no sistema gerido pelo Operator.

---

# Síntese final acompanhada

No final, o formador revê oralmente com a turma:

```text
Running ≠ Ready
Service existente ≠ Service com backends
resiliência do workload ≠ HA do Control Plane
HA ≠ Backup / Recuperação
Kustomize ≠ Helm
CRD ≠ Custom Resource
Custom Resource + Controller → reconciliação
release defeituosa → diagnóstico → rollback → validação
```

## Regra final

```text
Executar
  não chega.

É necessário:
executar → observar → interpretar → validar
```
