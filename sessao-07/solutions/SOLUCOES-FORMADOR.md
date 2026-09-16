# SOLUÇÕES DO FORMADOR — Sessão 7
## M10 + M11 em 4 horas

> Material de apoio ao formador. O repositório é público; esta designação é apenas pedagógica.

## Princípio de condução

Este é um laboratório acompanhado. Em cada incidente, conduzir a turma por:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

Não revelar a causa raiz antes de existir evidência suficiente.

---

# 1. Preparação anterior à sessão

Preparar o Prometheus Operator fora das 4 horas:

```bash
cd ~/formacao-kubernetes/sessao-07
chmod +x monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1

helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
```

Validar:

```bash
helm status monitoring -n monitoring
kubectl get pods -n monitoring
kubectl get crd prometheusrules.monitoring.coreos.com
```

---

# 2. Baseline

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s7-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s7-lab --timeout=180s
kubectl get pods -n s7-lab -o wide
kubectl get pvc -n s7-lab
kubectl get endpointslices -n s7-lab
```

Esperado:

- `postgres-0` `Running/Ready`;
- PVC `Bound`;
- Symfony 2/2 `Ready`;
- réplicas Symfony em Workers diferentes;
- Service com dois backends prontos.

---

# 3. Incidente A — readiness

Introduzir:

```bash
kubectl apply -k app/overlays/incident-probe/
```

Causa raiz esperada: `readinessProbe` aponta para `/ready-inexistente`.

Evidência principal:

```bash
kubectl get pods -n s7-lab
kubectl describe pod <POD> -n s7-lab
kubectl get events -n s7-lab --sort-by=.lastTimestamp
kubectl get endpointslices -n s7-lab -o yaml
```

Mensagem:

```text
Running ≠ Ready
```

Recuperação:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s7-lab --timeout=180s
```

---

# 4. Incidente B — Service sem backends

Introduzir:

```bash
kubectl apply -k app/overlays/incident-service/
```

Causa raiz: selector `app: symfony-demo-inexistente` não corresponde às labels dos Pods.

Evidência:

```bash
kubectl get pods -n s7-lab --show-labels
kubectl get svc symfony-demo -n s7-lab -o yaml
kubectl get endpointslices -n s7-lab -o yaml
```

Mensagem:

```text
Service existente ≠ Service com backends
```

Recuperação:

```bash
kubectl apply -k app/overlays/normal/
```

---

# 5. Worker `NotReady`

Escolher o Worker que não contém `postgres-0`:

```bash
kubectl get pod postgres-0 -n s7-lab -o wide
kubectl get pods -n s7-lab -l app=symfony-demo -o wide
```

No Worker:

```bash
sudo systemctl stop kubelet
```

Observar:

```bash
kubectl get nodes -w
kubectl get pods -n s7-lab -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

É possível observar `FailedScheduling` porque a anti-affinity obrigatória impede colocar as duas réplicas no único Worker restante.

Recuperar:

```bash
sudo systemctl start kubelet
```

Depois:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s7-lab --timeout=300s
```

Reforçar:

```text
resiliência do workload ≠ HA do Control Plane
```

---

# 6. Control Plane e `etcd`

```bash
kubectl get pods -n kube-system -o wide \
  | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'

kubectl get --raw='/readyz?verbose'
```

Não parar o único Control Plane e não executar restore destrutivo de `etcd`.

Consolidar:

```text
vários Control Planes + etcd redundante → HA do Control Plane
snapshot de etcd                       → ponto de recuperação
```

---

# 7. Transição Kustomize → Helm

Renderizar e comparar:

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s7-lab -f /tmp/symfony-good.yaml || true
```

Adotar objetos existentes:

```bash
helm upgrade --install symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait \
  --timeout 5m
```

Validar:

```bash
helm list -n s7-lab
helm history symfony-lab -n s7-lab
kubectl get pods -n s7-lab
```

---

# 8. Upgrade defeituoso e rollback

Aplicar:

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

Causa raiz esperada:

```text
registry.invalid/s7/symfony-demo:1.0.0
```

O novo Pod deverá evidenciar `ErrImagePull`/`ImagePullBackOff`.

Diagnóstico:

```bash
helm history symfony-lab -n s7-lab
kubectl get pods -n s7-lab
kubectl describe pod <NOVO_POD> -n s7-lab
```

Rollback:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s7-lab --wait --timeout 3m
```

Não assumir que a revisão boa é sempre `1`; consultar o histórico.

---

# 9. Kustomize

A componente Kustomize reutiliza os próprios overlays do laboratório:

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml

diff -u /tmp/normal.yaml /tmp/probe.yaml || true
diff -u /tmp/normal.yaml /tmp/service.yaml || true
```

Reforçar:

```text
base + overlay → variante declarativa
```

---

# 10. CRD / Custom Resource / reconciliação

Criar a regra:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s7-lab-rules -n monitoring
```

Alterar temporariamente a `summary`:

```bash
cp monitoring/prometheus-rule.yaml /tmp/prometheus-rule-reconcile.yaml
sed -i \
  's/Existem réplicas indisponíveis no Deployment symfony-demo/Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo/' \
  /tmp/prometheus-rule-reconcile.yaml
kubectl apply -f /tmp/prometheus-rule-reconcile.yaml
```

Verificar `generation` e provar a alteração no Prometheus via port-forward/API.

```bash
kubectl get prometheusrule s7-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}'
```

Repor:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
```

Relação final:

```text
CRD → tipo
CR → estado desejado
Controller/Operator → observa
Reconciliação → propaga o estado
```

---

# 11. Critérios de sucesso

A sessão está pedagogicamente concluída quando os formandos conseguem explicar:

- por que `Running` não significa `Ready`;
- como Service selector, labels e EndpointSlice se relacionam;
- como controllers e Scheduler participam na recuperação;
- por que resiliência de workload não é HA do Control Plane;
- por que HA não substitui backup;
- a diferença entre Chart, Release e Revision;
- quando usar rollback;
- o modelo base + overlay de Kustomize;
- a relação CRD → Custom Resource → Controller → reconciliação.

## Limpeza

```bash
helm uninstall symfony-lab -n s7-lab || true
kubectl delete namespace s7-lab --ignore-not-found
```

Manter a monitorização instalada se ainda for necessária para demonstrações ou para a sessão seguinte. Não remover CRDs automaticamente.
