# Laboratório Integrado — Sessão 7
## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

**Módulos:** M10 + M11  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** 1 Control Plane + 2 Worker Nodes  
**Runtime:** `containerd`  
**CNI:** Calico  
**StorageClass:** `local-path`  
**Aplicação:** Symfony Demo + PostgreSQL 16  
**Namespace:** `s7-lab`

---

# 1. Objetivo do laboratório

Este laboratório não separa artificialmente o M10 e o M11. Parte de uma aplicação funcional, introduz falhas controladas e conduz a turma por diagnóstico, recuperação, gestão declarativa, releases e reconciliação.

```text
Aplicação funcional
        ↓
falha controlada
        ↓
observação
        ↓
diagnóstico
        ↓
recuperação
        ↓
gestão com Helm / Kustomize
        ↓
rollback
        ↓
CRD / Custom Resource
        ↓
reconciliação
        ↓
validação
```

O laboratório é **acompanhado pelo formador**. Nos incidentes aplica-se sempre:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

> **Regra:** primeiro observar; só depois alterar.

> **Limite do cenário:** existe apenas um Control Plane. O laboratório demonstra resiliência de workloads e enquadra HA do Control Plane, mas não provoca a falha destrutiva do único Control Plane.

---

# 2. Distribuição das 4 horas

| Tempo | Atividade |
|---:|---|
| 10 min | CP0 — Enquadramento e precheck |
| 15 min | CP1 — HA, recuperação e método de troubleshooting |
| 45 min | CP2 — Incidentes: `Running ≠ Ready` + Service sem backends |
| 25 min | CP3 — Worker `NotReady` e resiliência |
| 15 min | CP4 — Control Plane, `etcd`, HA e recuperação |
| 15 min | **Intervalo** |
| 15 min | CP5 — Helm, Kustomize, CRD e Operator |
| 35 min | CP6 — Helm: adoção, upgrade defeituoso e rollback |
| 25 min | CP7 — Kustomize: base e overlays |
| 25 min | CP8 — Custom Resource e reconciliação |
| 15 min | CP9 — Desafio final e síntese |
| **240 min** | **Total** |

---

# 3. Preparação do formador — antes da sessão

A monitorização é preparada **antes da aula**, para não consumir tempo do laboratório.

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

Não avançar para a sessão sem esta preparação concluída.

---

# CP0 — Enquadramento e precheck

## Obter os materiais

```bash
cd ~
git clone --depth 1 https://github.com/Skullclamp/formacao-kubernetes.git
cd ~/formacao-kubernetes/sessao-07
chmod +x 00-precheck/precheck.sh
./00-precheck/precheck.sh
```

O precheck confirma:

- API Kubernetes acessível;
- 2 Workers `Ready` e disponíveis para scheduling;
- `local-path`;
- Calico;
- Kustomize integrado;
- Helm com suporte a `--take-ownership`;
- Prometheus Operator preparado pelo formador.

## Criar a baseline saudável

Primeiro renderizar:

```bash
kubectl kustomize app/overlays/normal/
```

Depois aplicar:

```bash
kubectl apply -k app/overlays/normal/

kubectl rollout status statefulset/postgres \
  -n s7-lab --timeout=180s

kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=180s
```

Recolher evidência:

```bash
kubectl get pods -n s7-lab -o wide
kubectl get pvc -n s7-lab
kubectl get svc -n s7-lab
kubectl get endpointslices -n s7-lab
```

### CHECKPOINT

Confirmar:

```text
postgres-0       → Running / Ready
PVC              → Bound
Symfony          → 2/2 Ready
réplicas Web     → Workers diferentes
Service          → backends disponíveis
```

---

# CP1 — HA, recuperação e troubleshooting

Antes dos incidentes, consolidar quatro distinções:

```text
Aplicação disponível
        ≠
Node disponível
        ≠
Control Plane disponível
        ≠
Dados recuperáveis
```

E:

```text
Réplicas     → disponibilidade
Persistência → sobrevivência ao ciclo de vida do Pod
Backup       → recuperação de dados
HA           → continuidade perante determinadas falhas
```

O método usado a partir deste ponto é:

```text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Teste
  ↓
Causa raiz
  ↓
Correção
  ↓
Validação
```

---

# CP2 — Dois incidentes Kubernetes

## Incidente A — `Running ≠ Ready`

O formador introduz a falha:

```bash
kubectl apply -k app/overlays/incident-probe/
```

Observar:

```bash
kubectl get deployment symfony-demo -n s7-lab
kubectl get pods -n s7-lab -o wide
kubectl get events -n s7-lab --sort-by=.lastTimestamp
```

Identificar o Pod novo e aprofundar:

```bash
kubectl describe pod <POD> -n s7-lab
kubectl logs <POD> -n s7-lab

kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Perguntas orientadoras:

- O container está a executar?
- O Pod está `Ready`?
- Que probe está a falhar?
- O endpoint não pronto recebe tráfego?
- Porque não termina o rollout?

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=180s
```

Mensagem-chave:

```text
Running ≠ Ready
```

O guião detalhado está em [`incidents/01-probe.md`](incidents/01-probe.md).

---

## Incidente B — Service sem backends

Introduzir a falha:

```bash
kubectl apply -k app/overlays/incident-service/
```

Observar:

```bash
kubectl get pods -n s7-lab --show-labels
kubectl get svc symfony-demo -n s7-lab -o yaml
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Relacionar:

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
      ↓
backends
```

Testar o selector observado:

```bash
kubectl get pods -n s7-lab -l <CHAVE>=<VALOR>
```

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s7-lab
```

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

O guião detalhado está em [`incidents/02-service.md`](incidents/02-service.md).

---

# CP3 — Worker `NotReady` e resiliência

## Health gate

```bash
kubectl get nodes -o wide
kubectl get pod postgres-0 -n s7-lab -o wide
kubectl get pods -n s7-lab -l app=symfony-demo -o wide
```

Escolher o Worker que contém uma réplica Symfony mas **não** o PostgreSQL.

> A ação disruptiva é executada pelo formador.

No Worker escolhido:

```bash
sudo systemctl stop kubelet
```

Observar em tempo real:

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s7-lab -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

Se surgir um Pod `Pending`:

```bash
kubectl describe pod <POD_PENDING> -n s7-lab
```

Relacionar:

```text
estado desejado = 2 réplicas
        ↓
Worker indisponível
        ↓
Controller tenta repor
        ↓
Scheduler procura Node elegível
        ↓
anti-affinity pode impedir placement
```

## Recuperar

No Worker:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

Validar:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=300s
kubectl get pods -n s7-lab -o wide
```

Mensagem-chave:

```text
Resiliência do workload ≠ HA do Control Plane
```

O guião detalhado está em [`incidents/03-node.md`](incidents/03-node.md).

---

# CP4 — Control Plane, `etcd`, HA e recuperação

Apenas observação e enquadramento. **Não parar o Control Plane.**

```bash
kubectl get pods -n kube-system -o wide \
  | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'

kubectl get --raw='/readyz?verbose'
```

Consolidar:

```text
2 Pods Web em 2 Workers
→ resiliência do workload

vários Control Planes + etcd redundante
→ HA do Control Plane

snapshot de etcd
→ ponto de recuperação do estado do cluster
```

Mensagem-chave:

```text
HA ≠ Backup ≠ Recovery
```

---

# INTERVALO — 15 minutos

---

# CP5 — M11: mapa conceptual curto

## Helm e Kustomize

```text
                 Manifests
                    │
             ┌──────┴──────┐
             │             │
           Helm        Kustomize
             │             │
      Chart + Values    Base + Overlay
             │             │
          Release       variante
```

## Extensão da API

```text
CRD
 ↓
novo tipo
 ↓
Custom Resource
 ↓
Controller / Operator
 ↓
reconciliação
 ↓
estado desejado
```

---

# CP6 — Helm: adoção, falha e rollback

A aplicação foi criada inicialmente por Kustomize. Agora será gerida como release Helm.

## 1. Renderizar antes de instalar

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s7-lab -f /tmp/symfony-good.yaml || true
```

## 2. Transferir ownership para Helm

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
kubectl get pods -n s7-lab -o wide
```

## 3. Introduzir um upgrade defeituoso

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que a candidata não fique operacional.

Diagnosticar:

```bash
helm history symfony-lab -n s7-lab
kubectl get pods -n s7-lab -o wide
kubectl describe pod <NOVO_POD> -n s7-lab
kubectl get events -n s7-lab --sort-by=.lastTimestamp
```

## 4. Rollback

Identificar a revisão boa no histórico:

```bash
helm history symfony-lab -n s7-lab
```

Depois:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s7-lab \
  --wait \
  --timeout 3m
```

Validar:

```bash
helm history symfony-lab -n s7-lab
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=180s
kubectl get pods -n s7-lab
```

Consolidar:

```text
Chart ≠ Release ≠ Revision

upgrade
  ↓
falha
  ↓
evidência
  ↓
rollback
  ↓
validação
```

O guião detalhado está em [`incidents/04-release.md`](incidents/04-release.md).

---

# CP7 — Kustomize: base e overlays

O objetivo deste bloco é perceber o modelo de composição já utilizado nos incidentes.

Estrutura:

```text
app/
├── base/
└── overlays/
    ├── normal/
    ├── incident-probe/
    └── incident-service/
```

Comparar as renderizações sem alterar o cluster:

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml
```

Observar diferenças:

```bash
diff -u /tmp/normal.yaml /tmp/probe.yaml || true
diff -u /tmp/normal.yaml /tmp/service.yaml || true
```

Relacionar:

```text
base comum
   +
overlay
   ↓
variante declarativa
```

Pergunta de consolidação:

> Porque é preferível alterar apenas o que difere entre variantes em vez de duplicar integralmente todos os manifests?

---

# CP8 — CRD, Custom Resource e reconciliação

O Prometheus Operator já foi preparado pelo formador.

## 1. Identificar extensões da API

```bash
kubectl get crd | grep monitoring.coreos.com
kubectl api-resources | grep -E 'PrometheusRule|Prometheus'
kubectl get deployment -n monitoring
```

## 2. Criar o Custom Resource pedagógico

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s7-lab-rules -n monitoring
```

Registar a geração atual:

```bash
kubectl get prometheusrule s7-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}'
```

## 3. Alterar o estado desejado

```bash
cp monitoring/prometheus-rule.yaml /tmp/prometheus-rule-reconcile.yaml

sed -i \
  's/Existem réplicas indisponíveis no Deployment symfony-demo/Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo/' \
  /tmp/prometheus-rule-reconcile.yaml

kubectl apply -f /tmp/prometheus-rule-reconcile.yaml
```

Confirmar que `generation` aumentou:

```bash
kubectl get prometheusrule s7-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}'
```

## 4. Provar a reconciliação no sistema gerido

Num terminal:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

Noutro terminal:

```bash
curl -sS http://127.0.0.1:9090/api/v1/rules \
  | grep -o 'Reconciliação observada[^"}]*' \
  | head
```

Repor a regra original:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
```

Consolidar:

```text
CRD              → define o tipo
Custom Resource  → declara estado desejado
Controller       → observa
Operator         → aplica lógica operacional
Reconciliação    → aproxima estado real do desejado
```

---

# CP9 — Desafio final

## Cenário

> Foi efetuado um upgrade da aplicação. A nova versão deixou de estar disponível através do Service.

A turma deve propor a sequência de diagnóstico **antes de executar comandos**.

Sequência de referência:

```text
kubectl get
     ↓
kubectl describe
     ↓
logs
     ↓
Events
     ↓
Service
     ↓
EndpointSlice
     ↓
hipótese
     ↓
teste
     ↓
correção ou rollback
     ↓
validação
```

Se o problema estiver associado à release:

```bash
helm history symfony-lab -n s7-lab
helm rollback symfony-lab <REVISAO_BOA> -n s7-lab --wait
```

---

# Síntese final

```text
Running ≠ Ready

Service existente ≠ Service com backends

Resiliência do workload ≠ HA do Control Plane

HA ≠ Backup ≠ Recovery

Chart ≠ Release ≠ Revision

CRD ≠ Custom Resource

Sem evidência não há diagnóstico.
Sem validação não há recuperação demonstrada.
```

---

# Limpeza

A monitorização foi preparada pelo formador e **não deve ser removida pelos formandos** no final da sessão.

Remover apenas os recursos da aplicação quando indicado:

```bash
helm uninstall symfony-lab -n s7-lab || true
kubectl delete namespace s7-lab --ignore-not-found
```

Não remover CRDs do Prometheus Operator durante a aula.
