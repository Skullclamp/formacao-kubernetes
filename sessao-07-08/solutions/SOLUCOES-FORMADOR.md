# SOLUÇÕES DO FORMADOR — Laboratório Integrado Sessões 7 e 8

> Material de apoio ao formador. Não entregar como guião inicial aos formandos.
>
> **Nota de acesso:** este ficheiro está num repositório GitHub público. A designação «soluções do formador» é pedagógica e não constitui controlo de acesso técnico.

## 1. Preparação e baseline

Executar a partir de `sessao-07-08/`.

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./00-precheck/precheck.sh
```

Aplicar a baseline:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab -o wide
kubectl get svc,endpointslices -n s78-lab
```

Resultado esperado:

- `postgres-0` em `Running` e `Ready`;
- duas réplicas de `symfony-demo` em `Running` e `Ready`;
- réplicas Symfony em Workers diferentes devido à Pod Anti-Affinity obrigatória;
- Service `symfony-demo` com dois endpoints prontos.

A estratégia do Deployment usa `maxSurge: 0` e `maxUnavailable: 1`. Com apenas dois Workers e anti-affinity obrigatória, isto evita um deadlock de rollout: uma réplica antiga é libertada antes de criar a nova.

## 2. Monitorização, CRDs e Operator

Antes da sessão, preparar uma versão do chart `kube-prometheus-stack` efetivamente validada no cluster:

```bash
./monitoring/prepare-chart.sh <VERSAO_VALIDADA>
```

Na sessão:

```bash
helm install monitoring \
  ./packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 5m
```

Validar a release e as extensões da API:

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -A
```

Identificar concretamente a cadeia de reconciliação:

```bash
kubectl get prometheus -n monitoring
kubectl get statefulset -n monitoring
kubectl get pods -n monitoring
```

Relação a reforçar:

```text
CRD
 ↓
define um novo tipo
 ↓
Prometheus Custom Resource
 ↓
Prometheus Operator / Controller
 ↓
StatefulSet + Pods reconciliados
```

Criar logo nesta fase a regra pedagógica, para poder observá-la durante os incidentes:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

O `PrometheusRule` usa a label `release: monitoring`, selecionada explicitamente em `monitoring/values-lab.yaml`.

## 3. Incidente 1 — rollout bloqueado por readiness probe

### Preparar a falha

```bash
kubectl apply -k app/overlays/incident-probe/
```

### Sintoma esperado

Com `maxSurge: 0` e `maxUnavailable: 1`, o Deployment substitui uma réplica de cada vez. A nova réplica pode aparecer:

```text
Running
READY 0/1
```

A réplica antiga que não foi substituída permanece `Ready`, pelo que o Service deverá continuar a dispor de pelo menos um endpoint utilizável.

### Evidência principal

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

A readiness probe aponta para:

```text
/ready-inexistente
```

A evidência esperada é uma falha HTTP da readiness probe. O processo continua em execução, mas Kubernetes não considera o novo Pod pronto para receber tráfego.

### Recuperação

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

Mensagens-chave:

```text
Running ≠ Ready
Readiness protege o tráfego e o rollout
```

## 4. Incidente 2 — Service sem endpoints

### Preparar a falha

```bash
kubectl apply -k app/overlays/incident-service/
```

### Evidência

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab
```

O Service fica com:

```yaml
selector:
  app: symfony-demo-inexistente
```

Os Pods mantêm:

```yaml
app: symfony-demo
```

### Causa raiz

Incompatibilidade entre o selector do Service e as labels dos Pods.

### Recuperação

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab
```

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

## 5. Incidente 3 — Worker NotReady

### Escolher o Worker da falha

Evitar falhar o Worker onde corre PostgreSQL para manter o incidente focado na resiliência do workload Web.

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

Selecionar o outro Worker, onde corre uma das réplicas Symfony mas não `postgres-0`.

### Provocar a falha

No Worker escolhido:

```bash
sudo systemctl stop kubelet
```

### Observar

```bash
kubectl get nodes -w
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -A --sort-by=.lastTimestamp
```

A transição para `NotReady` e eventual evicção não são instantâneas. Os tempos concretos dependem da configuração do cluster.

Como existe anti-affinity obrigatória, Kubernetes não pode manter as duas réplicas Symfony no único Worker restante. É possível observar:

```text
1 réplica funcional no Worker saudável
+
1 réplica indisponível/Pending enquanto o outro Worker não regressar
```

Isto é intencional e permite discutir a tensão entre disponibilidade e regras de placement.

### Recuperar

No Worker:

```bash
sudo systemctl start kubelet
```

No terminal administrativo:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
```

## 6. Control Plane, etcd, HA e recuperação

O cluster da formação tem um único Control Plane. Portanto, este laboratório não demonstra HA real do Control Plane.

Recolher evidência dos componentes:

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -o wide | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
```

Pedir aos formandos que identifiquem o Node onde executam os static Pods do Control Plane e o Pod `etcd`.

Consolidar:

```text
1 Control Plane
      ↓
não demonstra HA do Control Plane

redundância de etcd
      ↓
disponibilidade

snapshot de etcd
      ↓
ponto de recuperação
```

Não parar o único Control Plane nem executar restore de `etcd` no cluster principal da formação. Se for demonstrado um snapshot, fazê-lo como demonstração controlada do formador e sem restore no ambiente principal.

## 7. Transição de Kustomize para Helm

Não misturar ownership do mesmo Deployment/Service entre Kustomize e Helm.

Antes de instalar a release Helm, remover apenas os dois recursos Symfony geridos anteriormente por Kustomize. PostgreSQL, Secret, PVC e Namespace permanecem.

```bash
kubectl delete deployment symfony-demo -n s78-lab
kubectl delete service symfony-demo -n s78-lab
```

Instalar a baseline Helm:

```bash
helm install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --wait \
  --timeout 3m
```

Health gate:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Não avançar para o upgrade defeituoso enquanto as duas réplicas não estiverem `Running` e `Ready`.

## 8. Incidente 4 — release candidata defeituosa

### Aplicar a candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

O comando deverá falhar por timeout.

### Evidência

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl describe pod <NOVO_POD> -n s78-lab
```

### Causa raiz

`values-broken.yaml` altera o repositório da imagem para:

```text
registry.invalid/s78/symfony-demo
```

O novo Pod deverá evidenciar `ErrImagePull` e/ou `ImagePullBackOff`. Uma réplica anterior permanece disponível devido à estratégia `maxSurge: 0` / `maxUnavailable: 1`.

### Rollback

Identificar primeiro a revisão boa:

```bash
helm history symfony-lab -n s78-lab
```

Depois:

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait --timeout 3m
```

Não assumir que a revisão boa é sempre `1`.

Validar:

```bash
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

## 9. Alteração de Custom Resource e reconciliação

Consultar a regra:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

Pedir ao formando que altere um campo não destrutivo, por exemplo `annotations.summary` ou `for`, e reaplique:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

Relacionar novamente:

```text
CRD → tipo
CR → estado desejado
Controller/Operator → observa
reconciliação → aproxima estado real do desejado
```

O objetivo não é programar um Operator, mas observar recursos reais introduzidos por uma extensão da API.

## 10. Limpeza

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

As CRDs do `kube-prometheus-stack` podem permanecer após a remoção da release. Não as remover automaticamente sem confirmar que não são utilizadas por outros componentes do cluster.

## 11. Checklist final do formador

- [ ] `precheck.sh` concluído sem erros críticos.
- [ ] Imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` validada no ambiente real.
- [ ] Imagem `postgres:16` disponível.
- [ ] StorageClass `local-path` funcional.
- [ ] Duas réplicas Symfony distribuídas pelos dois Workers.
- [ ] Rollout com `maxSurge: 0` e `maxUnavailable: 1` validado.
- [ ] Chart `kube-prometheus-stack` escolhido, descarregado e testado antes da sessão.
- [ ] `PrometheusRule` selecionado pela instância Prometheus.
- [ ] Cadeia `Prometheus CR → Operator → StatefulSet/Pods` identificada.
- [ ] Incidente de probe validado com uma réplica antiga ainda disponível.
- [ ] Incidente de selector validado.
- [ ] Worker seguro para simular falha identificado.
- [ ] Componentes do Control Plane e `etcd` identificados sem provocar indisponibilidade do Control Plane.
- [ ] Helm install/upgrade/rollback testado.
- [ ] Procedimento de limpeza testado.
