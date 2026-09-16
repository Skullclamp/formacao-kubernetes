# Validação Operacional End-to-End — Laboratório Integrado Sessões 7 e 8

> Documento de ensaio do formador. Executar **antes da formação**, no cluster real que será usado em aula.
>
> Este documento não substitui `lab-integrado.md`: serve para provar que a sequência completa é executável, cabe no tempo disponível e produz os sintomas previstos.

## 1. Critério de fecho

O laboratório só deve ser considerado operacionalmente fechado quando forem confirmados, no cluster real:

- todos os checkpoints CP0–CP9;
- os sintomas previstos nos quatro incidentes;
- a recuperação declarativa após cada incidente;
- os tempos reais de execução;
- o consumo de recursos da monitorização;
- a versão concreta e validada de `kube-prometheus-stack`;
- a imagem `ghcr.io/skullclamp/symfony-demo:1.0.0`;
- a imagem `postgres:16`;
- o funcionamento real de `local-path`;
- a limpeza final sem deixar workloads de laboratório ativos.

Regra:

```text
EXPECTATIVA
    ↓
EXECUÇÃO REAL
    ↓
EVIDÊNCIA
    ↓
PASS / FAIL
    ↓
CONTINGÊNCIA, se necessário
```

Os tempos apresentados abaixo são **orçamento de ensaio**, não tempos garantidos. Registar sempre o tempo efetivamente observado.

---

# 2. Registo global do ensaio

| Elemento | Registo |
|---|---|
| Data | |
| Kubernetes version | |
| Helm version | |
| Control Plane | |
| Worker 1 | |
| Worker 2 | |
| vCPU/RAM por Node | |
| StorageClass | |
| CNI | |
| Versão `kube-prometheus-stack` | |
| Imagem Symfony validada | |
| Imagem PostgreSQL validada | |
| Resultado global | PASS / FAIL |

---

# CP0 — Pré-validação

**Orçamento:** 5–10 min  
**Risco:** baixo  
**Gate:** obrigatório

## Executar

```bash
cd ~/formacao-kubernetes/sessao-07-08
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./00-precheck/precheck.sh
```

Confirmar também:

```bash
kubectl version
helm version --short
kubectl get nodes -o wide
kubectl get storageclass
kubectl get pods -A | grep -i calico
ls -lh packages/kube-prometheus-stack-*.tgz
```

## PASS

- API acessível;
- exatamente o contexto pretendido;
- pelo menos 2 Workers `Ready` e schedulable;
- `local-path` presente;
- Calico operacional;
- Helm disponível;
- Kustomize integrado disponível;
- existe um único pacote local `kube-prometheus-stack-*.tgz` selecionado para a sessão.

## FAIL / contingência

| Sintoma | Ação |
|---|---|
| API inacessível | Corrigir kubeconfig/contexto antes de continuar. |
| Worker `NotReady` | Não iniciar o laboratório. Diagnosticar o Node. |
| Worker cordoned | `kubectl uncordon <NODE>` apenas se essa for a intenção operacional. |
| `local-path` ausente | Corrigir provisioner/StorageClass; não alterar o laboratório para storage efémero. |
| chart local ausente | Executar `monitoring/prepare-chart.sh <VERSAO_TESTADA>` antes da aula. |
| mais de um chart local | Selecionar e documentar uma única versão validada. |

**Tempo real CP0:** ______ min  
**Resultado:** PASS / FAIL

---

# CP1 — Baseline Kustomize

**Orçamento:** 8–12 min  
**Risco:** médio; valida imagens, storage e scheduling

## Renderizar

```bash
kubectl kustomize app/overlays/normal/ > /tmp/s78-rendered.yaml
kubectl apply --dry-run=client -f /tmp/s78-rendered.yaml >/dev/null
```

## Aplicar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

## Evidência

```bash
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

## PASS

```text
postgres-0         Running / Ready
PVC                Bound
Symfony Pod A      Running / Ready / Worker A
Symfony Pod B      Running / Ready / Worker B
Service            2 endpoints ready
```

## FAIL / contingência

| Sintoma | Diagnóstico imediato |
|---|---|
| `ImagePullBackOff` Symfony | `kubectl describe pod`; validar existência/acesso a `ghcr.io/skullclamp/symfony-demo:1.0.0`. |
| `ImagePullBackOff` PostgreSQL | Validar acesso a `postgres:16`. |
| PVC `Pending` | `kubectl describe pvc`; validar `local-path` e provisioner. |
| Symfony `Pending` | `kubectl describe pod`; verificar CPU/RAM e anti-affinity. |
| Symfony `Running` mas `NotReady` na baseline | Validar `/ready`, `DATABASE_URL` e PostgreSQL. Não avançar para incidentes. |

**Tempo real CP1:** ______ min  
**Resultado:** PASS / FAIL

---

# CP2 — Helm + Prometheus Operator + CRDs

**Orçamento:** 12–20 min  
**Risco:** alto; é o bloco com maior dependência de recursos do cluster

## Confirmar pacote

```bash
CHART=$(ls packages/kube-prometheus-stack-*.tgz)
helm show chart "$CHART"
```

Registar a versão efetiva: ____________________

## Instalar

```bash
helm install monitoring "$CHART" \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 5m
```

## Evidência

```bash
helm list -n monitoring
helm status monitoring -n monitoring
kubectl get pods -n monitoring -o wide
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -n monitoring
kubectl get statefulset -n monitoring
kubectl get deploy -n monitoring
kubectl get events -n monitoring --sort-by=.lastTimestamp
```

Aplicar a regra:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

## PASS

- release Helm em estado operacional;
- Operator em `Running`;
- Prometheus CR existente;
- StatefulSet/Pod Prometheus criado pelo Operator;
- `kube-state-metrics` em execução;
- CRDs `monitoring.coreos.com` presentes;
- `PrometheusRule/s78-lab-rules` aceite pela API.

## Verificação de capacidade

```bash
kubectl top nodes 2>/dev/null || true
kubectl top pods -n monitoring 2>/dev/null || true
```

Se Metrics Server não existir, registar apenas requests/limits e utilização observável no hypervisor.

## FAIL / contingência

| Sintoma | Ação |
|---|---|
| `helm install` timeout | Não aumentar o timeout cegamente. Ver Pods/Events e identificar a causa. |
| Pods `Pending` | Verificar CPU/RAM livres e scheduling. |
| `ImagePullBackOff` | Pré-carregar/garantir acesso às imagens antes da formação. |
| CRDs ausentes | Não continuar para CP9; validar instalação do chart e versão. |
| PrometheusRule existe mas não há `kube-state-metrics` | Corrigir `values-lab.yaml`/versão do chart antes da formação. |

> Se este bloco exceder consistentemente 20 minutos ou consumir recursos excessivos, rever os componentes do chart que não são necessários ao objetivo pedagógico antes de congelar a versão.

**Tempo real CP2:** ______ min  
**Resultado:** PASS / FAIL

---

# CP3 — Incidente 1: readiness incorreta

**Orçamento:** 12–15 min

## Health gate

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Confirmar 2/2 réplicas Ready antes da falha.

## Provocar

```bash
kubectl apply -k app/overlays/incident-probe/
```

Observar rollout:

```bash
kubectl get pods -n s78-lab -w
```

Noutro terminal:

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get endpointslices -n s78-lab -o yaml
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Identificar o Pod novo:

```bash
kubectl get pods -n s78-lab --sort-by=.metadata.creationTimestamp -o wide
```

Depois:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl logs <NOVO_POD> -n s78-lab
```

## PASS

```text
Pod antigo   Running / Ready
Pod novo     Running / NotReady
Service      mantém pelo menos 1 endpoint ready
Rollout      não conclui enquanto a probe estiver errada
```

A evidência deve apontar para `/ready-inexistente` e falha da readiness probe.

## Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

## Contingência

Se o novo Pod ficar `Pending`, o problema é de scheduling/recursos e **não** o incidente pretendido. Voltar à baseline e resolver antes de continuar.

**Tempo real CP3:** ______ min  
**Resultado:** PASS / FAIL

---

# CP4 — Incidente 2: selector do Service

**Orçamento:** 8–10 min

## Provocar

```bash
kubectl apply -k app/overlays/incident-service/
```

## Evidência

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab -o yaml
```

## PASS

- Pods permanecem `Running` e `Ready`;
- Service existe;
- selector não corresponde às labels dos Pods;
- Service deixa de ter backends utilizáveis.

## Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab -o yaml
```

## Contingência

Se os Pods também deixarem de estar Ready, existe uma falha residual de CP3. Repor primeiro a baseline e repetir CP4 isoladamente.

**Tempo real CP4:** ______ min  
**Resultado:** PASS / FAIL

---

# CP5 — Incidente 3: Worker `NotReady`

**Orçamento:** 15–25 min  
**Risco:** alto; depende dos timers reais do cluster

## Health gate

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab
```

Selecionar o Worker com uma réplica Symfony **sem** `postgres-0`.

Registar:

```text
Worker alvo: ____________________
Pod Symfony nesse Worker: ____________________
```

## Provocar — apenas pelo formador

No Worker alvo:

```bash
sudo systemctl stop kubelet
```

No terminal administrativo:

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab -o yaml
kubectl get events -A --sort-by=.lastTimestamp
```

## PASS

- Node transita para `NotReady`;
- a transição **não é assumida como instantânea**;
- pelo menos uma réplica Symfony no Worker saudável permanece utilizável;
- a topologia não é apresentada como HA do Control Plane;
- é observado e explicado o efeito da anti-affinity obrigatória com apenas um Worker saudável.

Registar:

```text
Tempo até NotReady: ______
Tempo até alteração relevante de Pods/endpoints: ______
```

## Recuperar

No Worker:

```bash
sudo systemctl start kubelet
```

Depois:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

## Contingência temporal

Não gastar a sessão à espera de timers de evicção. Se o objetivo pedagógico já estiver demonstrado (`NotReady`, impacto no endpoint e diferença entre resiliência/HA), recuperar o kubelet e continuar. Os tempos reais devem ser documentados neste ensaio para o formador saber quanto esperar em aula.

**Tempo real CP5:** ______ min  
**Resultado:** PASS / FAIL

---

# CP6 — Control Plane e `etcd`

**Orçamento:** 5–8 min  
**Risco:** baixo; exclusivamente observacional

## Executar

```bash
kubectl get nodes
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -o wide | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
```

## PASS

Identificar objetivamente:

```text
1 Control Plane
kube-apiserver
kube-controller-manager
kube-scheduler
etcd
```

Explicação validada:

```text
redundância de Control Plane / etcd → disponibilidade
snapshot de etcd                    → recuperação do estado
```

Não executar falha destrutiva ou restore de `etcd`.

**Tempo real CP6:** ______ min  
**Resultado:** PASS / FAIL

---

# CP7 — Transição Kustomize → Helm

**Orçamento:** 6–10 min

## Confirmar baseline antes da transição

```bash
kubectl get deployment,svc,pods -n s78-lab
kubectl get statefulset,pvc -n s78-lab
```

## Remover apenas ownership Kustomize da aplicação Web

```bash
kubectl delete deployment symfony-demo -n s78-lab
kubectl delete service symfony-demo -n s78-lab
```

Confirmar que PostgreSQL permanece:

```bash
kubectl get statefulset,pod,pvc,secret,svc -n s78-lab
```

## Instalar Helm

```bash
helm install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --wait \
  --timeout 3m
```

## PASS

- release `symfony-lab` criada;
- revisão 1 operacional;
- 2 réplicas Ready em Workers diferentes;
- Service com endpoints;
- PostgreSQL/PVC mantidos.

## Nota operacional

Existe uma pequena janela de indisponibilidade entre a remoção dos objetos Kustomize e a criação da release Helm. Neste laboratório é uma transição pedagógica controlada de ownership, não uma estratégia de migração zero-downtime.

**Tempo real CP7:** ______ min  
**Resultado:** PASS / FAIL

---

# CP8 — Release defeituosa + rollback

**Orçamento:** 12–15 min

## Health gate

```bash
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Não avançar sem baseline saudável.

## Provocar

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado um retorno não-zero/timeout.

## Evidência

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab -o yaml
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl describe pod <NOVO_POD> -n s78-lab
```

## PASS

```text
1 réplica anterior continua disponível
novo Pod → ErrImagePull / ImagePullBackOff
histórico Helm contém revisão candidata falhada
```

## Rollback

Identificar a revisão boa no histórico e só depois executar:

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait --timeout 3m
```

Validar:

```bash
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

## Contingência

Se a falha observada for `Pending` em vez de `ImagePullBackOff`, investigar scheduling/recursos: o incidente pretendido não foi reproduzido.

**Tempo real CP8:** ______ min  
**Resultado:** PASS / FAIL

---

# CP9 — Custom Resource e reconciliação

**Orçamento:** 7–10 min

## Estado inicial

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
kubectl get prometheus -n monitoring
kubectl get statefulset -n monitoring
kubectl get pods -n monitoring
```

## Alterar

Em `monitoring/prometheus-rule.yaml`, alterar por exemplo:

```yaml
for: 2m
```

em vez do valor inicial `1m`, ou alterar a annotation `summary`.

Aplicar:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

## Observar o Controller/Operator

Identificar primeiro o Pod do Operator, sem assumir um nome fixo entre versões do chart:

```bash
kubectl get pods -n monitoring | grep -i operator
```

Depois consultar os logs do Pod identificado:

```bash
kubectl logs -n monitoring <POD-OPERATOR> --since=5m
```

## PASS

- Custom Resource apresenta o novo estado desejado;
- Operator permanece saudável;
- o formando consegue relacionar `CRD → CR → Controller/Operator → reconciliação`;
- em CP2 já foi demonstrado que um Prometheus CR leva à criação/gestão de StatefulSet e Pods.

> A simples existência do `PrometheusRule` na API prova que o CR foi aceite; a observação do Operator e dos recursos geridos reforça a demonstração de reconciliação.

**Tempo real CP9:** ______ min  
**Resultado:** PASS / FAIL

---

# 3. Limpeza end-to-end

**Orçamento:** 5–10 min

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

Validar:

```bash
kubectl get namespace s78-lab monitoring 2>/dev/null || true
helm list -A
kubectl get pods -A | grep -E 's78|monitoring' || true
```

Não remover automaticamente CRDs partilháveis do Prometheus Operator sem confirmar utilização noutros namespaces.

**Tempo real limpeza:** ______ min

---

# 4. Orçamento temporal do ensaio

| Bloco | Orçamento | Tempo real |
|---|---:|---:|
| CP0 | 5–10 min | |
| CP1 | 8–12 min | |
| CP2 | 12–20 min | |
| CP3 | 12–15 min | |
| CP4 | 8–10 min | |
| CP5 | 15–25 min | |
| CP6 | 5–8 min | |
| CP7 | 6–10 min | |
| CP8 | 12–15 min | |
| CP9 | 7–10 min | |
| Limpeza | 5–10 min | |

O ensaio técnico puro deverá deixar margem suficiente para, em aula, explicação, formulação de hipóteses, discussão dos outputs, preenchimento de evidências e intervalo.

---

# 5. Critérios finais PASS / FAIL

## PASS operacional

- [ ] CP0 sem erros críticos.
- [ ] Baseline Kustomize sobe de forma repetível.
- [ ] Imagem Symfony validada no cluster real.
- [ ] PostgreSQL e PVC operacionais.
- [ ] Operator/Prometheus instalados dentro do orçamento.
- [ ] Versão do chart registada e congelada.
- [ ] Incidente 1 produz `Running/NotReady`, não `Pending`.
- [ ] Incidente 2 remove backends mantendo Pods saudáveis.
- [ ] Incidente 3 produz `NotReady` e recuperação controlável dentro do tempo de aula.
- [ ] CP6 identifica corretamente o único Control Plane e `etcd`.
- [ ] Transição Kustomize → Helm preserva PostgreSQL/PVC.
- [ ] Incidente 4 produz `ErrImagePull/ImagePullBackOff`.
- [ ] Rollback Helm recupera 2 réplicas Ready.
- [ ] PrometheusRule pode ser alterada e reaplicada.
- [ ] Operator/recursos reconciliados podem ser observados.
- [ ] Limpeza concluída.

## FAIL operacional

Qualquer um dos seguintes bloqueia o fecho:

- imagem principal inexistente/inacessível;
- storage não provisiona;
- chart não instala de forma previsível;
- falta de recursos impede os cenários;
- incidentes produzem sintomas diferentes dos documentados;
- Worker não recupera de forma segura;
- rollback não recupera a aplicação;
- sequência excede de forma consistente o tempo disponível.

---

# 6. Decisão final do formador

```text
[ ] PASS — laboratório pronto para formação
[ ] PASS COM AJUSTES — repetir apenas os checkpoints assinalados
[ ] FAIL — não utilizar ainda em formação
```

Observações:

__________________________________________________________________

__________________________________________________________________

__________________________________________________________________
