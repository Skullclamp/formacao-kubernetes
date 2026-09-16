# SOLUÇÕES DO FORMADOR — Sessões 7 e 8
## M10 + M11 — laboratório integrado de 4 horas

> Material de apoio ao formador. O repositório é público; esta designação é apenas pedagógica.

## Princípio de condução

Este é um laboratório acompanhado. Em cada incidente, conduzir a turma por:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

Não revelar a causa raiz antes de existir evidência suficiente.

---

# 1. Preparação anterior ao laboratório

Preparar o Prometheus Operator fora das 4 horas:

```bash
cd ~/formacao-kubernetes/sessao-07-08
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

Se algum Node indicar reinício pendente do sistema operativo, tratar a manutenção antes da formação. Não reiniciar o único Control Plane durante o laboratório.

> Depois da mudança de diretoria/namespace para `sessao-07-08/` e `s78-lab`, repetir o ensaio operacional completo antes da formação.

---

# 2. Baseline

Obter/atualizar o repositório e executar o precheck com:

```bash
cd ~/formacao-kubernetes/sessao-07-08
bash 00-precheck/precheck.sh
```

Não ativar `set -euo pipefail` manualmente no shell interativo.

Criar a baseline:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get endpointslices -n s78-lab
```

Esperado:

- `postgres-0` `Running/Ready`;
- PVC `Bound`;
- Symfony Deployment `2/2`;
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
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl describe pod <POD> -n s78-lab
kubectl logs <POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Comportamento esperado de referência:

- novo Pod `Running`, mas `Ready=False`;
- readiness devolve HTTP `404`;
- Deployment fica `1/2`;
- o Pod não pronto pode **continuar presente no EndpointSlice** com `ready: false` e `serving: false`;
- a réplica saudável permanece `ready: true`.

Se surgir `FailedScheduling` por anti-affinity e o Pod acabar posteriormente agendado, tratar esse Event como transitório; não é a causa raiz deste incidente.

Mensagem:

```text
Running ≠ Ready
Presença no EndpointSlice ≠ endpoint Ready
```

Recuperação:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Só encerrar quando o Deployment estiver `2/2` e os dois endpoints estiverem `ready: true`.

---

# 4. Incidente B — Service sem backends

Introduzir:

```bash
kubectl apply -k app/overlays/incident-service/
```

Causa raiz: selector `app: symfony-demo-inexistente` não corresponde às labels dos Pods.

Evidência:

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get pods -n s78-lab -l app=symfony-demo-inexistente
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Esperado:

- os Pods permanecem `Running/Ready`;
- o Service continua a existir;
- o selector incorreto não encontra Pods;
- o EndpointSlice fica sem endpoints (`endpoints: null`).

Mensagem:

```text
Service existente ≠ Service com backends
```

Recuperação:

```bash
kubectl apply -k app/overlays/normal/
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

---

# 5. Worker `NotReady`

Escolher o Worker que não contém `postgres-0`:

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

No Worker, parar **apenas** o kubelet:

```bash
sudo systemctl stop kubelet
```

Não parar `containerd`, não desligar a VM e não tocar no Control Plane.

Observar:

```bash
kubectl get nodes -w
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Comportamento esperado de referência:

- o Worker passa a `NotReady`;
- PostgreSQL permanece saudável no outro Worker;
- a aplicação mantém um backend elegível, mas perde redundância;
- o Pod antigo pode ser posteriormente marcado para remoção;
- a réplica de substituição pode ficar `Pending` devido a anti-affinity/taints;
- no EndpointSlice, o endpoint do Worker indisponível pode ficar `ready: false`, enquanto o outro permanece `ready: true`.

Reforçar:

```text
estado desejado ≠ convergência imediata
resiliência do workload ≠ HA do Control Plane
```

Recuperar:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

Depois:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Só encerrar quando Worker `Ready`, Deployment `2/2` e dois endpoints `ready: true`.

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
Control Plane saudável                  ≠ HA do Control Plane
vários Control Planes + etcd redundante → HA do Control Plane
snapshot de etcd                        → ponto de recuperação
HA                                      ≠ Backup ≠ Recovery
```

---

# 7. Transição Kustomize → Helm

Renderizar e comparar:

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

Adotar objetos existentes:

```bash
helm upgrade --install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait \
  --timeout 180s
```

Validar:

```bash
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
```

Esperado: `Helm | symfony-lab` nos dois objetos e Deployment `2/2` antes do incidente seguinte.

---

# 8. Upgrade defeituoso e rollback

Aplicar:

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

Causa raiz esperada:

```text
registry.invalid/s78/symfony-demo:1.0.0
```

Diagnóstico:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

O `describe` deverá revelar a falha de pull/resolução de `registry.invalid`. Se existir um `FailedScheduling` transitório antes do agendamento, não o confundir com a causa raiz persistente.

Rollback:

```bash
helm history symfony-lab -n s78-lab
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab --wait --timeout 180s
```

Não assumir que a revisão boa é sempre `1`; consultar o histórico.

Explicar:

```text
rollback para uma revisão anterior
≠ voltar ao mesmo número de revision
```

O rollback cria uma nova revision.

Validar:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

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

Depois da adoção Helm, **não executar `kubectl apply -k` sobre o Deployment e o Service Symfony**. Helm é agora o mecanismo responsável por esses objetos.

Um `kubectl diff` vazio não prova ownership, porque a lógica de apply considera o estado `last-applied`. Para ownership, verificar labels/anotações Helm.

---

# 10. CRD / Custom Resource / reconciliação

Criar a regra:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Explicar explicitamente:

```text
namespace do PrometheusRule → monitoring
namespace observado no PromQL → s78-lab
```

Alterar temporariamente apenas a `summary`:

```bash
kubectl patch prometheusrule s78-lab-rules \
  -n monitoring \
  --type='json' \
  -p='[
    {
      "op":"replace",
      "path":"/spec/groups/0/rules/0/annotations/summary",
      "value":"Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo"
    }
  ]'
```

Verificar que `generation` aumentou:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Provar a alteração no Prometheus.

Num terminal:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

Não abrir um segundo `port-forward` para a mesma porta local na mesma máquina. Se `9090` já estiver ocupada por um forward ativo, reutilizá-lo.

Noutro terminal no mesmo Control Plane:

```bash
sleep 10
python3 - <<'PY'
import json
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:9090/api/v1/rules") as r:
    data = json.load(r)

found = False
for group in data["data"]["groups"]:
    if group.get("name") != "s78-lab.rules":
        continue
    for rule in group.get("rules", []):
        if rule.get("name") == "SymfonyDeploymentUnavailable":
            print("name=" + rule.get("name", ""))
            print("state=" + rule.get("state", ""))
            print("summary=" + rule.get("annotations", {}).get("summary", ""))
            found = True

if not found:
    print("REGRA_NAO_ENCONTRADA")
PY
```

A prova de reconciliação é a nova `summary` aparecer na API do Prometheus. `state=inactive` é normal se o Deployment estiver saudável.

Repor:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Repetir a consulta à API e confirmar a `summary` original. Terminar depois o `port-forward` com `Ctrl+C`.

Relação final:

```text
CRD → tipo
CR → estado desejado
Controller/Operator → observa
Reconciliação → propaga o estado
```

---

# 11. Critérios de sucesso e validação global

Antes de terminar, validar:

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

O laboratório está pedagogicamente concluído quando os formandos conseguem explicar:

- por que `Running` não significa `Ready`;
- por que um Pod NotReady pode aparecer no EndpointSlice com `ready=false`;
- como Service selector, labels e EndpointSlice se relacionam;
- por que estado desejado não significa convergência imediata;
- como controllers e Scheduler participam na recuperação;
- por que resiliência de workload não é HA do Control Plane;
- por que Control Plane saudável não implica HA;
- por que HA não substitui backup;
- a diferença entre Chart, Release e Revision;
- que rollback cria uma nova revision;
- quando usar rollback;
- o modelo base + overlay de Kustomize;
- por que não se deve misturar gestão Kustomize/Helm dos mesmos objetos sem estratégia;
- a relação CRD → Custom Resource → Controller/Operator → reconciliação.

## Limpeza

```bash
kubectl delete prometheusrule s78-lab-rules \
  -n monitoring --ignore-not-found
helm uninstall symfony-lab -n s78-lab || true
kubectl delete namespace s78-lab --ignore-not-found
```

Manter a monitorização instalada se ainda for necessária para demonstrações posteriores. Não remover CRDs automaticamente.
