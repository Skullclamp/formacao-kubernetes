# Folha de Evidências — Sessão 7
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
| 2 Workers `Ready` e schedulable | | |
| `local-path` disponível | | |
| Calico operacional | | |
| Kustomize disponível | | |
| Helm suporta `--take-ownership` | | |
| Prometheus Operator disponível | | |
| PostgreSQL `Running/Ready` | | |
| PVC `Bound` | | |
| Symfony 2/2 `Ready` | | |
| Service com backends | | |

---

## CP2A — `Running ≠ Ready`

| Etapa | Evidência essencial |
|---|---|
| Sintoma | |
| Estado do Pod novo | |
| Probe observada | |
| Event/`describe` relevante | |
| Estado do EndpointSlice | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção | |
| Validação final | |

**Conclusão:**

```text
Running ≠ Ready
```

---

## CP2B — Service sem backends

| Etapa | Evidência essencial |
|---|---|
| Pods `Running/Ready` | |
| Selector do Service | |
| Labels dos Pods | |
| EndpointSlice durante a falha | |
| Hipótese | |
| Teste com selector | |
| Causa raiz | |
| Correção | |
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
| Distribuição inicial dos Pods | |
| Paragem do `kubelet` | |
| Node deixa de estar `Ready` | |
| Event/taint relevante | |
| Nova réplica criada | |
| Eventual razão de `Pending` | |
| `kubelet` reiniciado | |
| Node regressa a `Ready` | |
| Aplicação regressa ao estado esperado | |

**Conclusão:**

```text
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

Completar:

```text
vários Control Planes + etcd redundante
→ __________________________________________

snapshot de etcd
→ __________________________________________
```

---

## CP6 — Helm: upgrade e rollback

| Verificação | Evidência |
|---|---|
| Release inicial | |
| Revisão conhecida como boa | |
| Estado após upgrade defeituoso | |
| Estado do Pod novo | |
| Event principal | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Histórico após rollback | |
| Estado final da aplicação | |

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

Completar:

```text
base comum + __________________ = variante declarativa
```

---

## CP8 — CRD / Custom Resource / reconciliação

| Evidência | Registo |
|---|---|
| CRD observada | |
| Custom Resource criada | |
| `generation` inicial | |
| `generation` após alteração | |
| Controller/Operator identificado | |
| Alteração observada no Prometheus | |

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

### Validação final

- [ ] recolhemos evidência antes de alterar;
- [ ] distinguimos sintoma de causa raiz;
- [ ] validámos depois da correção;
- [ ] sabemos quando um rollback é apropriado;
- [ ] distinguimos resiliência, HA, backup e recovery;
- [ ] compreendemos a relação CRD → CR → Controller → reconciliação.
