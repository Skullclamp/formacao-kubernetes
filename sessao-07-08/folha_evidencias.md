# Folha de Evidências — Laboratório Integrado Sessões 7 e 8

## Regra de evidência

Neste laboratório, um comando executado sem erro **não é evidência suficiente** de que o sistema está saudável ou de que a correção produziu o efeito esperado.

Em cada checkpoint regista:

```text
resultado esperado
      ↓
evidência observada
      ↓
interpretação
      ↓
decisão de avançar ou diagnosticar
```

---

## CP0 — Pré-validação mínima

| Questão | Evidência / output relevante | Interpretação |
|---|---|---|
| `git`, `kubectl` e Helm disponíveis? | | |
| Contexto Kubernetes correto? | | |
| API acessível? | | |
| 2 Workers `Ready` e schedulable? | | |
| `local-path` disponível? | | |
| Calico identificado? | | |
| Kustomize integrado disponível? | | |
| Helm suporta `--take-ownership`? | | |

> As máquinas Ubuntu dos formandos são criadas de raiz. Não é necessário registar ou comparar UUIDs/UIDs das máquinas neste checkpoint.

**Gate:** não avançar se faltar um pré-requisito crítico.

---

## CP1 — Materiais e baseline da aplicação

| Questão | Evidência / output relevante | Interpretação |
|---|---|---|
| Repositório da formação descarregado? | | |
| Diretoria `sessao-07-08/` contém os manifests e guiões? | | |
| Chart `kube-prometheus-stack-91.4.1.tgz` descarregado? | | |
| `precheck.sh` terminou sem erros críticos? | | |
| PostgreSQL `Running` e `Ready`? | | |
| PVC `Bound`? | | |
| 2 Pods Symfony `Running` e `Ready`? | | |
| Réplicas em Workers diferentes? | | |
| Service com endpoints? | | |
| Events anómalos? | | |

Comandos úteis:

```bash
ls -lh packages/kube-prometheus-stack-91.4.1.tgz
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

---

## CP2 — Operator, CRDs e reconciliação

| Questão | Evidência / output relevante | Interpretação |
|---|---|---|
| Release `monitoring` instalada? | | |
| CRDs `monitoring.coreos.com` presentes? | | |
| Existe um `Prometheus` Custom Resource? | | |
| Que StatefulSet/Pods foram criados? | | |
| `PrometheusRule` foi aceite pela API? | | |

Desenha a relação observada:

```text
CRD → Custom Resource → Operator/Controller → recursos reconciliados
```

---

## CP3 — Incidente 1: readiness

| Campo | Registo |
|---|---|
| Sintoma | |
| Estado da réplica antiga | |
| Estado da nova réplica | |
| Event/describe relevante | |
| Endpoints durante a falha | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção declarativa | |
| Evidência final | |

**Questão de síntese:** por que razão `Running` não implica `Ready`?

Resposta:


---

## CP4 — Incidente 2: Service/selector

| Campo | Registo |
|---|---|
| Estado dos Pods | |
| Selector do Service | |
| Labels dos Pods | |
| EndpointSlices antes da correção | |
| Causa raiz | |
| Correção declarativa | |
| EndpointSlices após correção | |

**Questão de síntese:** um Service existente prova que existem backends utilizáveis?

Resposta:


---

## CP5 — Incidente 3: Worker `NotReady`

| Campo | Registo |
|---|---|
| Worker afetado | |
| Pod Symfony no Worker afetado | |
| Estado inicial do Node | |
| Estado após a falha | |
| Tempo aproximado até mudança observável | |
| Endpoints ainda utilizáveis | |
| Events relevantes | |
| Estado após recuperação | |

Explica:

```text
resiliência do workload ≠ HA do Control Plane ≠ backup/recuperação de dados
```


---

## CP6 — Control Plane e etcd

| Questão | Evidência / output relevante | Interpretação |
|---|---|---|
| Quantos Control Planes existem? | | |
| Onde corre `kube-apiserver`? | | |
| Onde corre `kube-controller-manager`? | | |
| Onde corre `kube-scheduler`? | | |
| Onde corre `etcd`? | | |

Completa:

```text
redundância de etcd → ______________________________
snapshot de etcd    → ______________________________
```

---

## CP7 — Transição Kustomize → Helm e health gate

| Questão | Evidência / output relevante | Interpretação |
|---|---|---|
| `helm template` produz a baseline esperada? | | |
| `kubectl diff -n s78-lab` mostra apenas alterações previstas? | | |
| Deployment/Service foram adotados sem serem apagados? | | |
| `managed-by=Helm`? | | |
| Release conhecida como boa? | | |
| Revisão atual? | | |
| 2 Pods `Ready`? | | |
| Service com 2 endpoints prontos? | | |

**Gate:** não executar o upgrade defeituoso sem baseline Helm saudável.

---

## CP8 — Incidente 4: release defeituosa e rollback

| Campo | Registo |
|---|---|
| Revisão anterior | |
| Revisão candidata | |
| Estado da réplica antiga | |
| Estado do novo Pod | |
| Event/describe relevante | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Nova revisão criada pelo rollback | |
| Estado após rollback | |
| Endpoints após rollback | |

**Questão de síntese:** por que razão o rollback Helm é preferível a editar manualmente o Deployment neste exercício?

Resposta:


---

## CP9 — Alteração de Custom Resource e reconciliação

Regista uma alteração não destrutiva no `PrometheusRule`:

| Campo | Registo |
|---|---|
| Campo alterado | |
| Valor anterior | |
| Novo valor | |
| `generation` antes/depois | |
| `resourceVersion` antes/depois | |
| Nova `summary` visível no CR? | |
| Nova `summary` visível em `/api/v1/rules` do Prometheus? | |
| Estado da regra no Prometheus | |
| Regra original reposta no final? | |
| O que significa reconciliação neste caso? | |

**Prova forte de reconciliação:** a alteração não deve ficar apenas visível no objeto Kubernetes; deve também aparecer na configuração carregada pelo Prometheus.

---

## Autoavaliação final

- [ ] Consigo descarregar e identificar os manifests e materiais necessários ao laboratório.
- [ ] Consigo distinguir sintoma de causa raiz.
- [ ] Consigo recolher evidência com `get`, `describe`, `logs` e Events.
- [ ] Consigo explicar `Running ≠ Ready`.
- [ ] Consigo relacionar Service selectors, labels e EndpointSlices.
- [ ] Consigo explicar o impacto de um Worker `NotReady`.
- [ ] Distingo resiliência de workload de HA do Control Plane.
- [ ] Distingo HA, persistência, backup e recuperação.
- [ ] Consigo utilizar Kustomize para aplicar uma baseline e variantes.
- [ ] Consigo transferir de forma controlada o ownership de objetos para uma release Helm.
- [ ] Consigo consultar uma release Helm e o respetivo histórico.
- [ ] Consigo identificar uma revisão boa e executar rollback.
- [ ] Distingo CRD de Custom Resource.
- [ ] Consigo relacionar Custom Resource, Controller/Operator e reconciliação.
- [ ] Consigo provar reconciliação observando também o sistema gerido.

## Regra final da sessão

```text
Sem evidência não há validação.
Sem causa raiz não há troubleshooting concluído.
Sem validação após a correção não há recuperação demonstrada.
```
