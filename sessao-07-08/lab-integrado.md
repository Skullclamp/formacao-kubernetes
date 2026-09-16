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
| Ferramentas | `kubectl`, Kustomize integrado, Helm |
| Operator | Prometheus Operator via `kube-prometheus-stack` |

As credenciais existentes neste laboratório são deliberadamente fictícias e destinam-se apenas à formação.

> **Limite do cenário:** um cluster com apenas um Control Plane não demonstra Alta Disponibilidade real do Control Plane. A HA do Control Plane e a redundância de `etcd` são analisadas tecnicamente, mas não simuladas de forma destrutiva neste cluster.

---

## 2. Estrutura

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
| 15 min | CP0/CP1 — Pré-validação, baseline e evidência |
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

# CP0 — Pré-validação

## Objetivo

Provar que o ambiente está preparado antes de introduzir qualquer incidente.

Executar a partir de `sessao-07-08/`:

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./00-precheck/precheck.sh
```

O precheck valida:

- `kubectl` e Helm;
- acesso à API Kubernetes;
- pelo menos dois Worker Nodes exatamente em estado `Ready` e disponíveis para scheduling;
- `StorageClass` `local-path`;
- presença de Calico;
- Kustomize integrado no `kubectl`.

### Checkpoint

Registar o resultado em `folha_evidencias.md`.

**Não avançar** se faltar um pré-requisito crítico.

---

# CP1 — Baseline da aplicação com Kustomize

## Objetivo

Criar um estado conhecido como bom antes de provocar falhas.

### 1. Renderizar antes de aplicar

```bash
kubectl kustomize app/overlays/normal/
```

`kubectl kustomize` permite observar o manifesto final produzido a partir da base e do overlay.

### 2. Aplicar

```bash
kubectl apply -k app/overlays/normal/
```

### 3. Aguardar a baseline

```bash
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

### 4. Recolher evidência

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

## Preparação antes da formação

O laboratório não deve depender da Internet durante a sessão. O formador escolhe e testa previamente uma versão de `kube-prometheus-stack`:

```bash
./monitoring/prepare-chart.sh <VERSAO_VALIDADA>
```

O pacote deverá ficar em:

```text
packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz
```

Não é fixada neste repositório uma versão que ainda não tenha sido validada no cluster real.

## Instalar a release

```bash
helm install monitoring \
  ./packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 5m
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

## Criar um Custom Resource pedagógico

Criar a regra **antes dos incidentes**, para integrar monitorização com troubleshooting:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

A configuração do Prometheus seleciona explicitamente regras com:

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

Entregar:

```text
incidents/01-probe.md
```

## Sintoma esperado

```text
réplica antiga → Running / Ready
nova réplica   → Running / NotReady
```

A nova readiness probe aponta deliberadamente para um endpoint inexistente. O processo pode continuar `Running`, mas o novo Pod não deve entrar nos endpoints do Service.

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

Entregar:

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

Isto permite discutir disponibilidade, capacidade e regras de placement.

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

# CP7 — Transição de Kustomize para Helm

Kustomize e Helm não devem gerir simultaneamente os mesmos objetos neste exercício.

Remover apenas Deployment e Service Symfony criados pela baseline Kustomize:

```bash
kubectl delete deployment symfony-demo -n s78-lab
kubectl delete service symfony-demo -n s78-lab
```

Permanecem:

```text
Namespace
Secret
PostgreSQL StatefulSet
PVC
Headless Service PostgreSQL
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

## Health gate obrigatório

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

**Não avançar** para a release defeituosa se a baseline Helm não estiver saudável.

Preencher **CP7** em `folha_evidencias.md`.

---

# CP8 — Incidente 4: release defeituosa e rollback

Entregar:

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

O ficheiro defeituoso utiliza deliberadamente:

```text
registry.invalid/s78/symfony-demo
```

Com a estratégia de rollout do laboratório, uma réplica anterior permanece disponível enquanto o novo Pod deverá evidenciar a falha de obtenção da imagem.

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

Sintomas esperados incluem:

```text
ErrImagePull
ImagePullBackOff
```

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
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

Fluxo:

```text
release candidata
   ↓
falha
   ↓
evidência
   ↓
causa raiz
   ↓
rollback
   ↓
validação
```

Preencher **CP8** em `folha_evidencias.md`.

---

# CP9 — Alterar um Custom Resource e observar reconciliação

Consultar a regra criada no início:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

Alterar um campo não destrutivo de `monitoring/prometheus-rule.yaml`, por exemplo:

```text
annotations.summary
```

ou:

```text
for: 1m
```

Aplicar novamente:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring -o yaml
```

Relacionar:

```text
CRD
 ↓
Custom Resource
 ↓
estado desejado alterado
 ↓
Controller / Operator observa
 ↓
reconciliação
```

Não é objetivo programar um Operator.

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
