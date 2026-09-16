# Validação Operacional End-to-End — Laboratório Integrado Sessões 7 e 8

> Documento de ensaio do formador. Executar **antes da formação**, no cluster real que será usado em aula.
>
> A lógica deste laboratório foi validada anteriormente no mesmo cenário técnico com a diretoria `sessao-07/` e o namespace `s7-lab`. Depois da reorganização para `sessao-07-08/` e `s78-lab`, este ensaio deve ser repetido para validar a variante renomeada.

## 1. Critério de fecho

O laboratório só fica operacionalmente fechado quando forem confirmados:

- precheck sem erros críticos;
- baseline saudável;
- os quatro incidentes com os sintomas previstos;
- recuperação e validação pós-correção;
- observação segura do Control Plane e `etcd`;
- adoção Helm com `--take-ownership` sem apagar Deployment/Service;
- upgrade defeituoso com `ImagePullBackOff` e rollback;
- Kustomize usado para render/diff após adoção Helm, sem reaplicar os objetos Symfony;
- `PrometheusRule` alterado e reconciliação comprovada pela API do Prometheus;
- validação global final;
- limpeza do Custom Resource e dos recursos da aplicação.

Regra:

```text
EXPECTATIVA → EXECUÇÃO REAL → EVIDÊNCIA → PASS/FAIL → CONTINGÊNCIA
```

---

# CP0 — Precheck

```bash
cd ~/formacao-kubernetes/sessao-07-08
bash 00-precheck/precheck.sh
```

Não ativar `set -euo pipefail` manualmente no shell interativo.

## PASS

- API acessível;
- pelo menos 2 Workers `Ready`;
- `local-path` presente;
- Calico operacional;
- Kustomize disponível;
- Helm suporta `--take-ownership`;
- Prometheus Operator/monitorização disponíveis.

---

# CP1 — Baseline

```bash
kubectl kustomize app/overlays/normal/ > /tmp/s78-normal.yaml
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get endpointslices -n s78-lab
```

## PASS

```text
postgres-0       1/1 Running
PVC              Bound
Symfony          Deployment 2/2
réplicas Web     Workers diferentes
Service          2 backends prontos
```

---

# CP2A — Readiness

```bash
kubectl apply -k app/overlays/incident-probe/
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo -o yaml
```

Aprofundar o Pod não pronto com `describe` e `logs`.

## PASS

- novo Pod `Running` mas `Ready=False`;
- readiness `/ready-inexistente` devolve HTTP `404`;
- o Pod pode permanecer no EndpointSlice com `ready:false`/`serving:false`;
- pelo menos uma réplica saudável permanece `ready:true`;
- eventual `FailedScheduling` transitório não é confundido com a causa raiz.

Recuperar e exigir Deployment `2/2` e dois endpoints `ready:true`.

---

# CP2B — Service sem backends

```bash
kubectl apply -k app/overlays/incident-service/
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get pods -n s78-lab -l app=symfony-demo-inexistente
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo -o yaml
```

## PASS

- Pods permanecem saudáveis;
- selector incorreto não encontra Pods;
- EndpointSlice fica sem endpoints utilizáveis (`endpoints: null`).

Recuperar com overlay `normal` e validar selector/endpoints.

---

# CP3 — Worker `NotReady`

Escolher o Worker que contém Symfony mas não PostgreSQL. Parar **apenas** o kubelet:

```bash
sudo systemctl stop kubelet
```

Observar:

```bash
kubectl get nodes -w
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo -o yaml
```

## PASS

- Worker passa a `NotReady`;
- PostgreSQL permanece saudável no outro Worker;
- workload perde redundância mas conserva um backend elegível;
- pode surgir substituição `Pending` por anti-affinity/taints;
- endpoint do Worker afetado pode ficar `ready:false`;
- compreende-se `estado desejado ≠ convergência imediata`.

Recuperar:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=300s
```

Exigir Worker `Ready`, Deployment `2/2` e dois endpoints `ready:true`.

---

# CP4 — Control Plane / etcd

Apenas observação:

```bash
kubectl get pods -n kube-system -o wide \
  | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
kubectl get --raw='/readyz?verbose'
```

## PASS

- componentes identificados no único Control Plane;
- `/readyz` saudável;
- fica claro que `Control Plane saudável ≠ Control Plane altamente disponível`;
- nenhum componente do Control Plane é parado;
- nenhum restore destrutivo de `etcd` é executado.

---

# CP6 — Adoção Helm, upgrade e rollback

Renderizar e comparar:

```bash
helm template symfony-lab ./helm/app-lab \
  -n s78-lab -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml
kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

Adotar os objetos existentes **sem os apagar**:

```bash
helm upgrade --install symfony-lab ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait --timeout 180s
```

Validar ownership, Deployment `2/2`, Pods e imagem.

Introduzir a candidata defeituosa:

```bash
helm upgrade symfony-lab ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait --timeout 90s
```

## PASS da falha

- nova revisão `failed`;
- Deployment `1/2`;
- novo Pod em `ErrImagePull`/`ImagePullBackOff`;
- imagem declarada `registry.invalid/s78/symfony-demo:1.0.0`;
- uma réplica anterior permanece disponível.

Rollback para a revisão conhecida como boa:

```bash
helm history symfony-lab -n s78-lab
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab --wait --timeout 180s
```

## PASS da recuperação

- rollback cria uma nova revision;
- release `deployed`;
- Deployment `2/2`;
- imagem `ghcr.io/skullclamp/symfony-demo:1.0.0`;
- dois endpoints `ready:true`.

---

# CP7 — Kustomize após adoção Helm

Apenas renderizar/comparar:

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml

diff -u /tmp/normal.yaml /tmp/probe.yaml || true
diff -u /tmp/normal.yaml /tmp/service.yaml || true
```

**Não executar `kubectl apply -k` sobre Deployment/Service Symfony depois da adoção Helm.** Confirmar ownership por labels/anotações Helm.

---

# CP8 — Custom Resource e reconciliação

Criar a regra:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Alterar apenas `summary` com `kubectl patch` e confirmar incremento de `generation`.

Abrir **um único** port-forward:

```bash
kubectl port-forward -n monitoring \
  svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Noutro terminal, consultar `/api/v1/rules` e filtrar o grupo `s78-lab.rules` e a regra `SymfonyDeploymentUnavailable`.

## PASS

- `generation` aumenta após alteração do CR;
- a nova `summary` aparece na API do Prometheus;
- `state=inactive` é aceite quando o Deployment está saudável;
- reaplicar `monitoring/prometheus-rule.yaml` repõe a `summary` original;
- a API do Prometheus volta a apresentar a `summary` original.

---

# CP9 — Validação global final

```bash
kubectl get nodes
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{" terminating="}{.conditions.terminating}{"\n"}{end}'
```

## PASS global

```text
Nodes       todos Ready
PostgreSQL  1/1 Running
Deployment  2/2
Symfony     2 Pods 1/1 Running, distribuídos pelos Workers
Imagem      ghcr.io/skullclamp/symfony-demo:1.0.0
Helm        deployed
Endpoints   2 × ready=true, serving=true, terminating=false
```

---

# Limpeza

```bash
kubectl delete prometheusrule s78-lab-rules \
  -n monitoring --ignore-not-found
helm uninstall symfony-lab -n s78-lab || true
kubectl delete namespace s78-lab --ignore-not-found
```

Não remover automaticamente CRDs do Prometheus Operator.

## Decisão final

```text
[ ] PASS — variante sessao-07-08 / s78-lab pronta para formação
[ ] PASS COM AJUSTES — repetir checkpoints assinalados
[ ] FAIL — não utilizar ainda em formação
```
