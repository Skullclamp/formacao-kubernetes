# Laboratório Integrado — Sessões 7 e 8

## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

Laboratório de 4 horas que integra:

- **Sessão 7:** Alta Disponibilidade, monitorização, troubleshooting e recuperação;
- **Sessão 8:** Helm, Kustomize, releases, CRDs, Custom Resources, Controllers e Operators.

A progressão pedagógica é:

```text
OBSERVAR
   ↓
DIAGNOSTICAR
   ↓
RECUPERAR
   ↓
GERIR CONFIGURAÇÃO
   ↓
GERIR RELEASES
   ↓
ROLLBACK
   ↓
ESTENDER A API
   ↓
RECONCILIAR
   ↓
VALIDAR
```

Método obrigatório em todos os incidentes:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

---

## 1. Ambiente de referência

| Elemento | Definição |
|---|---|
| Namespace | `s78-lab` |
| Cluster | 1 Control Plane + 2 Worker Nodes |
| Runtime | `containerd` |
| CNI | Calico |
| StorageClass | `local-path` |
| Aplicação | Symfony Demo |
| Imagem | `ghcr.io/skullclamp/symfony-demo:1.0.0` |
| Base de dados | PostgreSQL 16 |
| Ferramentas | `git`, `kubectl`, Kustomize integrado, Helm |
| Operator | Prometheus Operator via `kube-prometheus-stack` |
| Chart validado | `kube-prometheus-stack` 91.4.1 |

As credenciais existentes neste laboratório são deliberadamente fictícias e destinam-se apenas à formação.

> **Limite do cenário:** um cluster com apenas um Control Plane não demonstra Alta Disponibilidade real do Control Plane. A HA do Control Plane e a redundância de `etcd` são analisadas tecnicamente, mas não simuladas de forma destrutiva neste cluster.

> **Identidade das máquinas:** as máquinas Ubuntu dos formandos são criadas de raiz para a formação. Não faz parte do procedimento normal verificar `machine-id`, UUID de firmware/disco ou identificadores equivalentes. Esses identificadores só devem ser investigados se existir um sintoma concreto de clonagem ou identidade duplicada.

---

## 2. Estrutura dos materiais

```text
sessao-07-08/
├── lab-integrado.md
├── folha_evidencias.md
├── 00-precheck/
│   └── precheck.sh
├── app/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── postgres-secret.yaml
│   │   ├── postgres-service.yaml
│   │   ├── postgres-statefulset.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── normal/
│       ├── incident-probe/
│       └── incident-service/
├── helm/
│   ├── app-lab/
│   └── values/
│       ├── values-good.yaml
│       └── values-broken.yaml
├── monitoring/
│   ├── values-lab.yaml
│   ├── prometheus-rule.yaml
│   └── prepare-chart.sh
├── packages/
│   └── README.md
├── incidents/
│   ├── 01-probe.md
│   ├── 02-service.md
│   ├── 03-node.md
│   └── 04-release.md
└── solutions/
    └── SOLUCOES-FORMADOR.md
```

---

## 3. Distribuição das 4 horas

| Tempo | Atividade |
|---:|---|
| 15 min | CP0/CP1 — Pré-validação, obtenção dos materiais, baseline e evidência |
| 25 min | Kustomize e gestão declarativa |
| 35 min | Helm + Prometheus Operator + CRDs + regra pedagógica |
| 30 min | Incidente 1 — rollout bloqueado por readiness |
| 15 min | **Intervalo** |
| 25 min | Incidente 2 — Service sem endpoints |
| 35 min | Incidente 3 — Worker `NotReady` + Control Plane/`etcd` |
| 35 min | Incidente 4 — release Helm defeituosa e rollback |
| 25 min | Custom Resource, reconciliação, síntese e limpeza |
| **240 min** | **Total** |

---

# CP0 — Pré-validação mínima do ambiente

## Objetivo

Confirmar que o ambiente base está utilizável antes de descarregar e aplicar os materiais do laboratório.

Executar no terminal administrativo:

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
```

Confirmar também que o Helm utilizado suporta a transferência explícita de ownership que será usada no CP7:

```bash
helm upgrade --help | grep -- '--take-ownership'
```

Critérios mínimos:

- `git`, `kubectl` e Helm disponíveis;
- API Kubernetes acessível;
- dois Worker Nodes em estado `Ready` e disponíveis para scheduling;
- `StorageClass` `local-path` disponível;
- Calico presente;
- Kustomize integrado no `kubectl`;
- Helm com suporte para `--take-ownership`.

Não é necessário recolher ou comparar UUIDs/UIDs das máquinas Ubuntu dos formandos, porque estas máquinas são criadas de raiz.

**Não avançar** se faltar um pré-requisito crítico.

---

# CP1 — Obter os materiais e criar a baseline com Kustomize

## Objetivo

Cada formando começa por descarregar os manifests e restantes materiais necessários e, só depois, cria um estado conhecido como bom.

### 1. Descarregar o repositório da formação

As máquinas dos formandos partem de um estado novo, pelo que o procedimento normal é um clone limpo:

```bash
cd ~
git clone --depth 1 https://github.com/Skullclamp/formacao-kubernetes.git
cd ~/formacao-kubernetes/sessao-07-08
```

Confirmar que os materiais principais existem:

```bash
ls -1
ls -1 app/base app/overlays helm monitoring incidents
```

### 2. Descarregar o chart externo validado

A versão validada neste ambiente é `kube-prometheus-stack` **91.4.1**.

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1
```

Confirmar o pacote:

```bash
ls -lh packages/kube-prometheus-stack-91.4.1.tgz
helm show chart packages/kube-prometheus-stack-91.4.1.tgz
```

> Se a formação tiver de decorrer sem acesso à Internet, o formador deve disponibilizar previamente este `.tgz`. O restante laboratório usa sempre o pacote local.

### 3. Executar o precheck completo dos materiais e do cluster

```bash
./00-precheck/precheck.sh
```

O precheck valida as ferramentas, a API Kubernetes, os Workers, o StorageClass, Calico, Kustomize e a presença do chart local.

### 4. Renderizar antes de aplicar

```bash
kubectl kustomize app/overlays/normal/
```

`kubectl kustomize` permite observar o manifesto final produzido a partir da base e do overlay.

### 5. Aplicar a baseline

```bash
kubectl apply -k app/overlays/normal/
```

### 6. Aguardar a baseline

```bash
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

### 7. Recolher evidência

```bash
kubectl get nodes -o wide
kubectl get pods -n s78-lab -o wide
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
kubectl get pvc -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Resultado esperado:

```text
postgres-0          → Running / Ready
symfony-demo Pod A  → Running / Ready / Worker 1
symfony-demo Pod B  → Running / Ready / Worker 2
PVC                 → Bound
Service             → dois endpoints prontos
```

O Deployment utiliza Pod Anti-Affinity obrigatória para colocar as duas réplicas Web em Workers diferentes.

A estratégia de rollout é deliberadamente:

```yaml
maxSurge: 0
maxUnavailable: 1
```

Com apenas dois Workers e anti-affinity obrigatória, uma terceira réplica temporária não teria onde ser agendada. Esta estratégia permite substituir uma réplica de cada vez sem bloquear o rollout por scheduling.

### Checkpoint

Preencher **CP1** em `folha_evidencias.md`.

---

# CP2 — Prometheus Operator, CRDs e reconciliação

## Instalar a release a partir do pacote local

```bash
helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
```

## Identificar a extensão da API

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -A
```

Identificar a cadeia real:

```bash
kubectl get prometheus -n monitoring
kubectl get statefulset -n monitoring
kubectl get pods -n monitoring
```

Relação a consolidar:

```text
CRD
 ↓
define um novo tipo de recurso
 ↓
Prometheus Custom Resource
 ↓
Operator / Controller
 ↓
StatefulSet e Pods reconciliados
```

## Criar o Custom Resource pedagógico

Criar a regra **antes dos incidentes**, para integrar monitorização com troubleshooting:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

A configuração do Prometheus seleciona explicitamente regras com a label:

```yaml
release: monitoring
```

A regra utiliza métricas de `kube-state-metrics` para identificar réplicas indisponíveis do Deployment Symfony.

### Checkpoint

Preencher **CP2** em `folha_evidencias.md`.

---

# CP3 — Incidente 1: rollout bloqueado por readiness

## Preparação pelo formador

```bash
kubectl apply -k app/overlays/incident-probe/
```

Entregar aos formandos:

```text
incidents/01-probe.md
```

## Sintoma esperado

```text
réplica antiga → Running / Ready
nova réplica   → Running / NotReady
```

A nova readiness probe está incorreta. O processo pode continuar `Running`, mas o novo Pod não deve entrar nos endpoints do Service.

## Evidência inicial

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Depois utilizar, quando a hipótese o justificar:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl logs <NOVO_POD> -n s78-lab
```

## Recuperação

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

Mensagem-chave:

```text
Running ≠ Ready

readiness
  ↓
protege o tráfego
  +
protege o rollout
```

### Checkpoint

Preencher **CP3** em `folha_evidencias.md`.

---

# CP4 — Incidente 2: Service sem endpoints

## Preparação pelo formador

```bash
kubectl apply -k app/overlays/incident-service/
```

Entregar aos formandos:

```text
incidents/02-service.md
```

## Sintoma

```text
Pods    → Running / Ready
Service → existe
endpoints da aplicação → ausentes
```

## Diagnóstico

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab
```

O objetivo é provar a relação:

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlices
```

Não assumir imediatamente um problema de CNI ou DNS.

## Recuperação

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab
```

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

### Checkpoint

Preencher **CP4** em `folha_evidencias.md`.

---

# CP5 — Incidente 3: Worker `NotReady`

> Num cluster partilhado, a ação disruptiva é executada exclusivamente pelo formador.

## Health gate

Identificar primeiro onde executam PostgreSQL e as duas réplicas Web:

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab
```

Escolher o Worker que contém uma réplica Symfony mas **não** `postgres-0`.

## Provocar a falha

No Worker selecionado:

```bash
sudo systemctl stop kubelet
```

## Observar

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -A --sort-by=.lastTimestamp
```

A transição de um Node para `NotReady` e os mecanismos de evicção não são instantâneos. Registar os tempos realmente observados em vez de assumir um valor fixo.

Como a anti-affinity é obrigatória, o único Worker saudável não pode executar simultaneamente as duas réplicas Symfony. O cenário pode apresentar:

```text
1 réplica funcional
+
1 réplica indisponível/Pending
```

## Recuperar

No Worker:

```bash
sudo systemctl start kubelet
```

Validar:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

### Checkpoint

Preencher **CP5** em `folha_evidencias.md`.

---

# CP6 — Control Plane, `etcd`, HA e recuperação

## Objetivo

Relacionar a experiência do Worker com a arquitetura real do Control Plane sem destruir o único Control Plane disponível.

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -o wide | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
```

Identificar:

```text
kube-apiserver
kube-controller-manager
kube-scheduler
etcd
```

Consolidar:

```text
2 Pods Web em 2 Workers
        ↓
resiliência do workload

        ≠

HA do Control Plane
```

E:

```text
redundância de etcd → disponibilidade
snapshot de etcd    → ponto de recuperação
```

O cluster dispõe de um único Control Plane, portanto não é correto afirmar que esta topologia fornece HA do Control Plane.

> Não parar o único Control Plane nem executar restore de `etcd` no cluster principal durante este laboratório.

### Checkpoint

Preencher **CP6** em `folha_evidencias.md`.

---

# CP7 — Transição controlada de Kustomize para Helm

A baseline atual foi criada por Kustomize. A partir deste checkpoint, o Deployment e o Service Symfony passam a ser geridos pela release Helm `symfony-lab`.

**Não apagar** o Deployment nem o Service. A transição validada no ambiente real faz adoção dos objetos existentes para evitar uma interrupção artificial.

### 1. Renderizar a baseline Helm

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml
```

### 2. Comparar com o estado atual

```bash
kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

Antes de avançar, confirmar que não existem alterações inesperadas em:

```text
selector
replicas
image
readinessProbe
livenessProbe
resources
strategy
service.selector
service.port
```

É esperado surgirem labels Helm e a label `app.kubernetes.io/instance` no Pod template.

### 3. Transferir ownership para Helm

```bash
helm upgrade --install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait \
  --timeout 5m
```

### 4. Validar a baseline Helm

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

**Não avançar** para a release defeituosa se as duas réplicas não estiverem `Running` e `Ready` e se o Service não tiver dois endpoints prontos.

Preencher **CP7** em `folha_evidencias.md`.

---

# CP8 — Incidente 4: release defeituosa e rollback

Entregar aos formandos:

```text
incidents/04-release.md
```

Aplicar a candidata:

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

O comando é esperado falhar dentro do exercício. Não abrir previamente `values-broken.yaml`: a causa deve ser encontrada por evidência do cluster.

## Diagnóstico

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl describe pod <NOVO_POD> -n s78-lab
```

Aplicar sempre:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz
```

Não editar manualmente o Deployment para corrigir a release.

## Rollback

Identificar no histórico a revisão conhecida como boa:

```bash
helm history symfony-lab -n s78-lab
```

Depois:

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait --timeout 3m
```

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
rollback restaura o estado de uma revisão anterior
mas cria uma nova revisão no histórico
```

Preencher **CP8** em `folha_evidencias.md`.

---

# CP9 — Alterar um Custom Resource e provar reconciliação

O objetivo não é apenas provar que a API Kubernetes aceitou a alteração. É provar que a alteração chegou ao sistema gerido pelo Operator.

### 1. Criar uma cópia temporária da regra

```bash
cp monitoring/prometheus-rule.yaml /tmp/prometheus-rule-reconcile.yaml

sed -i \
  's/Existem réplicas indisponíveis no Deployment symfony-demo/Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo/' \
  /tmp/prometheus-rule-reconcile.yaml
```

### 2. Registar a versão antes e depois

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'

kubectl apply -f /tmp/prometheus-rule-reconcile.yaml

kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'
```

A `generation` deverá aumentar, provando que o estado desejado do CR mudou.

### 3. Provar que o Prometheus recebeu a alteração

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

A nova `summary` deve aparecer na API do Prometheus.

Se a aplicação estiver saudável, `state=inactive` é esperado: a regra está carregada, mas a condição de alerta é falsa.

Relação a consolidar:

```text
CRD
 ↓
Custom Resource alterado
 ↓
Operator / Controller observa
 ↓
reconciliação
 ↓
Prometheus carrega o novo estado
```

### 4. Repor a regra original

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
```

Preencher **CP9** em `folha_evidencias.md`.

---

# Síntese final

O formando deverá conseguir explicar com evidência:

```text
Running ≠ Ready
Service existente ≠ Service com backends
resiliência do workload ≠ HA do Control Plane
HA ≠ Backup / Recuperação
CRD ≠ Custom Resource
Custom Resource + Controller → reconciliação
release defeituosa → diagnóstico → rollback → validação
```

Regra da sessão:

```text
Sem evidência não há validação.
Sem causa raiz não há troubleshooting concluído.
Sem validação após a correção não há recuperação demonstrada.
```

---

# Limpeza

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

As CRDs instaladas pelo chart de monitorização podem permanecer após a remoção da release. Não as remover automaticamente sem confirmar que não são utilizadas por outros componentes do cluster.

---

# Material do formador

A resolução técnica e os resultados esperados estão em:

```text
solutions/SOLUCOES-FORMADOR.md
```

Como o repositório é público, esta separação é apenas pedagógica; não existe controlo de acesso por diretoria.
