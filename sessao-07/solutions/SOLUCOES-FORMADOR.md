# SOLUÇÕES DO FORMADOR — Laboratório Integrado Sessões 7 e 8

> Material de apoio ao formador. Não entregar como guião inicial aos formandos.
>
> **Nota de acesso:** este ficheiro está num repositório GitHub público. A designação «soluções do formador» é pedagógica e não constitui controlo de acesso técnico.

## Como conduzir este laboratório

Este é um **laboratório acompanhado pelo formador**, não uma prova prática autónoma. Em cada checkpoint, o formador deve introduzir o conceito e o objetivo antes da execução, explicar os comandos e flags relevantes e orientar a leitura do output observado no cluster.

Nos incidentes, o formador não revela imediatamente a causa raiz. Em vez disso, conduz a turma através de perguntas e evidência, ajudando os formandos a percorrerem:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

A turma executa os passos em conjunto, discute a interpretação dos resultados e só avança quando o checkpoint estiver validado. O objetivo é desenvolver raciocínio operacional e hábitos de troubleshooting, não avaliar quem consegue resolver sozinho um problema escondido.

## 1. Preparação, obtenção dos materiais e baseline

As máquinas Ubuntu dos formandos são criadas de raiz. Não é necessário pedir `machine-id`, UUID de firmware/disco, `systemUUID` ou identificadores equivalentes como parte do procedimento normal. Só investigar identidade de máquina se existir um sintoma real de clonagem ou duplicação.

### CP0 — validação mínima

Antes de descarregar os materiais, confirmar:

```bash
command -v git
command -v kubectl
command -v helm
helm version --short
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass local-path
kubectl get pods -A | grep -i calico
kubectl kustomize --help >/dev/null
helm upgrade --help | grep -- '--take-ownership'
```

### CP1 — download dos manifests e materiais

Cada formando descarrega o repositório no início do laboratório:

```bash
cd ~
git clone --depth 1 https://github.com/Skullclamp/formacao-kubernetes.git
cd ~/formacao-kubernetes/sessao-07-08
```

A versão do `kube-prometheus-stack` validada neste cluster é **91.4.1**. Preparar o pacote local:

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1
ls -lh packages/kube-prometheus-stack-91.4.1.tgz
```

Se a sessão tiver de decorrer sem Internet, o formador deve distribuir previamente o `.tgz` validado.

Executar depois o precheck completo:

```bash
./00-precheck/precheck.sh
```

Aplicar a baseline:

```bash
kubectl kustomize app/overlays/normal/
kubectl apply -k app/overlays/normal/
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab -o wide
kubectl get svc,endpointslices -n s78-lab
kubectl get pvc -n s78-lab
```

Resultado esperado:

- `postgres-0` em `Running` e `Ready`;
- duas réplicas de `symfony-demo` em `Running` e `Ready`;
- réplicas Symfony em Workers diferentes devido à Pod Anti-Affinity obrigatória;
- Service `symfony-demo` com dois endpoints prontos;
- PVC `Bound`.

A estratégia do Deployment usa `maxSurge: 0` e `maxUnavailable: 1`. Com apenas dois Workers e anti-affinity obrigatória, isto evita um deadlock de rollout: uma réplica antiga é libertada antes de criar a nova.

## 2. Monitorização, CRDs e Operator

Instalar a versão efetivamente validada:

```bash
helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
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

Criar a regra pedagógica antes dos incidentes:

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

A réplica antiga permanece `Ready`, pelo que o Service deverá continuar a dispor de pelo menos um endpoint utilizável.

### Evidência principal

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

A readiness probe aponta deliberadamente para um endpoint inexistente. A evidência esperada é uma falha HTTP da readiness probe. O processo continua em execução, mas Kubernetes não considera o novo Pod pronto para receber tráfego.

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

O Service fica com um selector que não corresponde às labels dos Pods.

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

Selecionar o outro Worker, onde corre uma réplica Symfony mas não `postgres-0`.

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

A transição para `NotReady` e eventual evicção não são instantâneas. Registar os tempos concretos observados.

Como existe anti-affinity obrigatória, Kubernetes não pode manter as duas réplicas Symfony no único Worker restante. É possível observar:

```text
1 réplica funcional no Worker saudável
+
1 réplica indisponível/Pending enquanto o outro Worker não regressar
```

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
kubectl get endpointslices -n s78-lab
```

## 6. Control Plane, etcd, HA e recuperação

O cluster da formação tem um único Control Plane. Portanto, este laboratório não demonstra HA real do Control Plane.

Recolher evidência dos componentes:

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -o wide | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
```

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

Não parar o único Control Plane nem executar restore de `etcd` no cluster principal da formação.

## 7. Transição de Kustomize para Helm

O procedimento validado **não apaga** o Deployment nem o Service. A release Helm adota os objetos existentes, preservando continuidade.

### Renderizar e comparar

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

Confirmar que o diff não altera de forma inesperada `selector`, `replicas`, imagem, probes, resources, estratégia ou configuração funcional do Service.

É normal o Pod template receber `app.kubernetes.io/instance: symfony-lab`, o que pode provocar um rollout controlado.

### Transferir ownership

```bash
helm upgrade --install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait \
  --timeout 5m
```

Validar:

```bash
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Confirmar ownership:

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"  release="}{.metadata.annotations.meta\.helm\.sh/release-name}{"  namespace="}{.metadata.annotations.meta\.helm\.sh/release-namespace}{"\n"}'
```

Resultado esperado:

```text
managed-by=Helm  release=symfony-lab  namespace=s78-lab
```

Não avançar para o upgrade defeituoso enquanto as duas réplicas não estiverem `Running` e `Ready` e o Service não tiver dois endpoints prontos.

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

O comando deverá falhar por timeout. Não mostrar `values-broken.yaml` aos formandos antes do diagnóstico.

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

### Causa raiz esperada

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
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Mensagem-chave:

```text
rollback recupera conteúdo de uma revisão anterior
mas cria uma nova revisão no histórico
```

## 9. Alteração de Custom Resource e prova de reconciliação

Trabalhar sobre uma cópia temporária para poder repor facilmente o ficheiro original:

```bash
cp monitoring/prometheus-rule.yaml /tmp/prometheus-rule-reconcile.yaml

sed -i \
  's/Existem réplicas indisponíveis no Deployment symfony-demo/Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo/' \
  /tmp/prometheus-rule-reconcile.yaml
```

Registar antes e depois:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'

kubectl apply -f /tmp/prometheus-rule-reconcile.yaml

kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'
```

A alteração do CR prova apenas que a API aceitou um novo estado desejado. Para provar reconciliação, verificar o sistema gerido.

Num terminal:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

Noutro terminal da mesma máquina:

```bash
curl -sS http://127.0.0.1:9090/api/v1/rules \
  | python3 -c '
import sys, json
data=json.load(sys.stdin)
for group in data.get("data", {}).get("groups", []):
    for rule in group.get("rules", []):
        if rule.get("name") == "SymfonyDeploymentUnavailable":
            print("name       =", rule.get("name"))
            print("state      =", rule.get("state"))
            print("query      =", rule.get("query"))
            print("summary    =", rule.get("annotations", {}).get("summary"))
'
```

A nova `summary` deve aparecer na API do Prometheus. Com a aplicação saudável, `state=inactive` é esperado.

Repor a regra original:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
```

Relação final:

```text
CRD → tipo
CR → estado desejado
Controller/Operator → observa
reconciliação → propaga o estado
Prometheus → carrega a regra resultante
```

## 10. Limpeza

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

As CRDs do `kube-prometheus-stack` podem permanecer após a remoção da release. Não as remover automaticamente sem confirmar que não são utilizadas por outros componentes do cluster.

## 11. Checklist final do formador

- [ ] Máquinas dos formandos criadas de raiz; não exigir verificação de UUIDs sem sintoma que a justifique.
- [ ] Formandos descarregam os manifests e materiais no CP1.
- [ ] Chart `kube-prometheus-stack` 91.4.1 descarregado e disponível localmente.
- [ ] `precheck.sh` concluído sem erros críticos.
- [ ] Imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` validada no ambiente real.
- [ ] Imagem `postgres:16` disponível.
- [ ] StorageClass `local-path` funcional.
- [ ] Duas réplicas Symfony distribuídas pelos dois Workers.
- [ ] Rollout com `maxSurge: 0` e `maxUnavailable: 1` validado.
- [ ] `PrometheusRule` selecionado pela instância Prometheus.
- [ ] Cadeia `Prometheus CR → Operator → StatefulSet/Pods` identificada.
- [ ] Incidente de probe validado com uma réplica antiga ainda disponível.
- [ ] Incidente de selector validado.
- [ ] Worker seguro para simular falha identificado.
- [ ] Componentes do Control Plane e `etcd` identificados sem provocar indisponibilidade do Control Plane.
- [ ] Transição Kustomize → Helm validada com `--take-ownership` sem apagar Deployment/Service.
- [ ] Helm install/upgrade/rollback testado.
- [ ] Reconciliação do `PrometheusRule` confirmada também na API do Prometheus.
- [ ] Procedimento de limpeza testado.
