# Folha de Evidências — Sessões 7 e 8
## Continuidade, Troubleshooting e Operação Avançada

Esta folha acompanha o laboratório orientado pelo formador. O objetivo é registar apenas a evidência necessária para justificar cada conclusão.

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

> Um comando terminar sem erro não prova que o sistema está saudável.

---

## CP0 — Baseline

| Verificação | Evidência observada | OK? |
|---|---|:---:|
| 2 Workers `Ready` | | |
| `local-path` disponível | | |
| Calico operacional | | |
| Kustomize disponível | | |
| Helm suporta `--take-ownership` | | |
| Prometheus Operator disponível | | |
| PostgreSQL `Running/Ready` | | |
| PVC `Bound` | | |
| Symfony 2/2 `Ready` | | |
| Réplicas Symfony em Workers diferentes | | |
| Service com backends | | |

---

## CP2A — `Running ≠ Ready`

| Etapa | Evidência essencial |
|---|---|
| Sintoma | |
| Estado do Pod novo | |
| Readiness probe observada | |
| HTTP/erro observado | |
| Event/`describe` relevante | |
| EndpointSlice — endpoint saudável | |
| EndpointSlice — endpoint não pronto (`ready=false`) | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção | |
| Validação final — Deployment 2/2 | |
| Validação final — 2 endpoints `ready=true` | |

**Conclusão:**

```text
Running ≠ Ready
Presença no EndpointSlice ≠ endpoint Ready
```

---

## CP2B — Service sem backends

| Etapa | Evidência essencial |
|---|---|
| Pods `Running/Ready` | |
| Selector do Service | |
| Labels dos Pods | |
| Resultado do teste com selector | |
| EndpointSlice durante a falha | |
| Hipótese | |
| Causa raiz | |
| Correção | |
| Selector após correção | |
| EndpointSlice após correção | |

**Conclusão:**

```text
Service existente ≠ Service com backends
```

---

## CP3 — Worker `NotReady`

| Momento | Evidência / tempo observado |
|---|---|
| Worker escolhido | |
| PostgreSQL permanece no outro Worker | |
| Distribuição inicial dos Pods Symfony | |
| Paragem apenas do `kubelet` | |
| Node deixa de estar `Ready` | |
| Event `NodeNotReady` / eviction | |
| Aplicação perde redundância | |
| Backend que permanece `ready=true` | |
| Nova réplica criada | |
| Razão de eventual `Pending` | |
| `kubelet` reiniciado | |
| Node regressa a `Ready` | |
| Deployment regressa a 2/2 | |
| Dois endpoints regressam a `ready=true` | |

**Conclusões:**

```text
estado desejado ≠ convergência imediata
resiliência do workload ≠ HA do Control Plane
```

---

## CP4 — Control Plane / `etcd`

| Componente | Evidência observada | Função |
|---|---|---|
| `kube-apiserver` | | |
| `kube-controller-manager` | | |
| `kube-scheduler` | | |
| `etcd` | | |
| `/readyz?verbose` | | |

Completar:

```text
1 único Control Plane saudável
→ __________________________________________

vários Control Planes + etcd redundante
→ __________________________________________

snapshot de etcd
→ __________________________________________
```

**Conclusão:**

```text
Control Plane saudável ≠ Control Plane altamente disponível
HA ≠ Backup ≠ Recovery
```

---

## CP6 — Helm: adoção, upgrade e rollback

| Verificação | Evidência |
|---|---|
| Release inicial | |
| Ownership Deployment | |
| Ownership Service | |
| Revisão conhecida como boa | |
| Estado após upgrade defeituoso | |
| Estado da release após falha | |
| Estado do Pod novo | |
| Imagem declarada no Deployment | |
| Event/erro principal | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Histórico após rollback | |
| Nova revision criada pelo rollback | |
| Estado final da aplicação | |
| Imagem final | |
| Endpoints finais | |

Completar:

```text
Chart ≠ __________ ≠ Revision
```

---

## CP7 — Kustomize

| Elemento | O que representa? |
|---|---|
| `app/base/` | |
| `overlays/normal/` | |
| `overlays/incident-probe/` | |
| `overlays/incident-service/` | |
| Ownership atual de Deployment/Service Symfony | |

Completar:

```text
base comum + __________________ = variante declarativa
```

Responder:

```text
Depois da adoção por Helm, devemos voltar a aplicar Kustomize
sobre Deployment/Service Symfony? __________________________
```

---

## CP8 — CRD / Custom Resource / reconciliação

| Evidência | Registo |
|---|---|
| CRD observada | |
| Namespace do Custom Resource | |
| Namespace observado pela expressão PromQL | |
| Custom Resource criada | |
| `generation` inicial | |
| `summary` inicial | |
| `generation` após alteração | |
| `summary` alterada no CR | |
| Controller/Operator identificado | |
| `summary` alterada observada na API do Prometheus | |
| Estado da regra no Prometheus | |
| `generation` após reposição | |
| `summary` original reposta no Prometheus | |

Completar:

```text
CRD             → __________________________
Custom Resource → __________________________
Controller      → __________________________
Reconciliação   → __________________________
```

---

## CP9 — Desafio final

Registar apenas a sequência proposta pela turma:

```text
1. __________________________________________
2. __________________________________________
3. __________________________________________
4. __________________________________________
5. __________________________________________
6. __________________________________________
```

### Validação global final

| Verificação | Evidência | OK? |
|---|---|:---:|
| Todos os Nodes `Ready` | | |
| PostgreSQL `1/1 Running` | | |
| Symfony Deployment `2/2` | | |
| 2 Pods Symfony `1/1 Running` | | |
| Symfony distribuído pelos 2 Workers | | |
| Imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` | | |
| Helm `STATUS: deployed` | | |
| Histórico mantém revisão falhada e rollback | | |
| 2 endpoints `ready=true` / `serving=true` | | |
| Deployment e Service geridos por Helm | | |
| `PrometheusRule` reposto para a `summary` original | | |

### Checklist pedagógico

- [ ] recolhemos evidência antes de alterar;
- [ ] distinguimos sintoma de causa raiz;
- [ ] validámos depois da correção;
- [ ] distinguimos `Running` de `Ready`;
- [ ] sabemos interpretar `ready` num EndpointSlice;
- [ ] compreendemos que estado desejado não implica convergência imediata;
- [ ] sabemos quando um rollback é apropriado;
- [ ] compreendemos que rollback cria uma nova revision;
- [ ] distinguimos resiliência, HA, backup e recovery;
- [ ] distinguimos CRD de Custom Resource;
- [ ] compreendemos a relação CR + Controller/Operator → reconciliação.
