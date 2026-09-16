# SOLUÇÕES DO FORMADOR — Laboratório Integrado Sessões 7 e 8

> Material de apoio ao formador. Não entregar como guião inicial aos formandos.
>
> **Nota de acesso:** este ficheiro está num repositório GitHub público. A designação «soluções do formador» é pedagógica e não constitui controlo de acesso técnico.

## 1. Preparação e baseline

Executar a partir de `sessao-07-08/`.

```bash
chmod +x 00-precheck/precheck.sh
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
- as réplicas Symfony distribuídas por Workers diferentes devido a Pod Anti-Affinity;
- Service `symfony-demo` com endpoints.

## 2. Monitorização / Operator

Antes da sessão, preparar um chart `kube-prometheus-stack` validado:

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

Validar:

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -A
```

Aplicar o Custom Resource pedagógico:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

Relação a reforçar:

```text
CRD → novo tipo de recurso
Custom Resource → instância desse tipo
Operator/Controller → observa e reconcilia
```

## 3. Incidente 1 — Readiness probe incorreta

### Preparar a falha

```bash
kubectl apply -k app/overlays/incident-probe/
```

### Sintoma esperado

Os Pods podem aparecer `Running`, mas `READY` deverá indicar `0/1` após a substituição das réplicas.

### Evidência principal

```bash
kubectl get pods -n s78-lab
kubectl describe pod <POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

A readiness probe aponta para:

```text
/ready-inexistente
```

A evidência esperada é uma falha HTTP da readiness probe, normalmente com resposta não bem-sucedida.

### Causa raiz

Configuração incorreta da readiness probe. O processo continua em execução, mas Kubernetes não considera o Pod pronto para receber tráfego.

### Recuperação

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
```

Mensagem-chave:

```text
Running ≠ Ready
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

O EndpointSlice do Service deverá voltar a conter os endereços das réplicas prontas.

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

### Comportamento a explicar

A transição do Node para `NotReady` e a remoção/evicção de Pods não são instantâneas. Os tempos concretos dependem da configuração do cluster.

Como o Deployment utiliza Pod Anti-Affinity obrigatória por `kubernetes.io/hostname`, Kubernetes não pode manter duas réplicas Symfony no único Worker restante. É possível observar:

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

### Conceitos obrigatórios

```text
resiliência do workload ≠ HA do Control Plane
HA ≠ backup
redundância de etcd ≠ snapshot de etcd
```

Não executar restore de `etcd` no cluster principal da formação.

## 6. Transição de Kustomize para Helm

Não misturar ownership do mesmo Deployment/Service entre Kustomize e Helm.

Antes de instalar a release Helm, remover apenas os dois recursos da aplicação geridos anteriormente via Kustomize. PostgreSQL, Secret e Namespace permanecem.

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

Validar:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab
```

## 7. Incidente 4 — Release candidata defeituosa

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
kubectl get pods -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl describe pod <NOVO_POD> -n s78-lab
```

### Causa raiz

`values-broken.yaml` altera o repositório da imagem para:

```text
registry.invalid/s78/symfony-demo
```

O domínio `.invalid` é utilizado deliberadamente para garantir que a imagem candidata não pode ser obtida.

Sintomas esperados incluem `ErrImagePull` e/ou `ImagePullBackOff`.

### Rollback

Identificar a revisão boa:

```bash
helm history symfony-lab -n s78-lab
```

Efetuar rollback, por exemplo para a revisão 1 se esta for a revisão boa no cluster concreto:

```bash
helm rollback symfony-lab 1 -n s78-lab --wait --timeout 3m
```

Não assumir cegamente que a revisão boa é sempre `1`: confirmar no histórico.

Validar:

```bash
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
```

## 8. PrometheusRule e reconciliação

Depois de criado o `PrometheusRule`:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

Pedir ao formando que altere, por exemplo, a annotation `summary` ou o campo `for`, e reaplique o recurso. O objetivo é observar a gestão declarativa do Custom Resource e a atuação do Operator, não memorizar a sintaxe da regra.

Validar os componentes do Operator:

```bash
kubectl get pods -n monitoring
kubectl get prometheus -A
kubectl get prometheusrule -A
```

## 9. Limpeza

Remover primeiro a release Helm da aplicação, se existir:

```bash
helm uninstall symfony-lab -n s78-lab || true
```

Remover monitorização:

```bash
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
```

Remover o laboratório:

```bash
kubectl delete namespace s78-lab --ignore-not-found
```

As CRDs do `kube-prometheus-stack` podem permanecer após a remoção da release, consoante o chart/versão utilizada. Não as remover automaticamente durante a formação sem confirmar que não são utilizadas por outros recursos do cluster.

## 10. Checklist final do formador

- [ ] Precheck concluído sem erros críticos.
- [ ] Imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` previamente validada.
- [ ] `postgres:16` disponível.
- [ ] StorageClass `local-path` funcional.
- [ ] Duas réplicas Symfony distribuídas pelos dois Workers.
- [ ] Chart `kube-prometheus-stack` escolhido e testado antes da sessão.
- [ ] Incidente de probe validado.
- [ ] Incidente de selector validado.
- [ ] Worker seguro para simular falha identificado.
- [ ] Helm install/upgrade/rollback testado.
- [ ] `PrometheusRule` aceite pela versão de CRDs instalada.
- [ ] Procedimento de limpeza testado.
