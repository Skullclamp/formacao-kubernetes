# Laboratório Integrado — Sessões 7 e 8

## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

Laboratório de 4 horas que integra:

- **Sessão 7:** Alta Disponibilidade, monitorização, troubleshooting e recuperação;
- **Sessão 8:** Helm, Kustomize, releases, CRDs, Custom Resources, Controllers e Operators.

Progressão pedagógica:

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
| Operador | Prometheus Operator através de `kube-prometheus-stack` |

As credenciais existentes neste laboratório são deliberadamente fictícias e destinam-se apenas à formação.

---

## 2. Estrutura

```text
sessao-07-08/
├── README.md
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
│       │   └── kustomization.yaml
│       ├── incident-probe/
│       │   ├── kustomization.yaml
│       │   └── patch-probe.yaml
│       └── incident-service/
│           ├── kustomization.yaml
│           └── patch-service.yaml
├── helm/
│   ├── app-lab/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       └── service.yaml
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
| 15 min | Baseline e recolha de evidência |
| 25 min | Kustomize e gestão declarativa |
| 35 min | Helm + Prometheus Operator + CRDs |
| 30 min | Incidente 1 — Pod `Running` mas não `Ready` |
| 15 min | **Intervalo** |
| 25 min | Incidente 2 — Service sem endpoints |
| 35 min | Incidente 3 — Worker `NotReady` |
| 35 min | Incidente 4 — release defeituosa e rollback |
| 25 min | Custom Resource, reconciliação, síntese e limpeza |
| **240 min** | **Total** |

---

## 4. Pré-validação

Executar a partir desta diretoria:

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./00-precheck/precheck.sh
```

O precheck valida, entre outros pontos:

- acesso à Kubernetes API;
- pelo menos dois Worker Nodes `Ready`;
- `local-path` disponível;
- presença de Calico;
- `kubectl kustomize`;
- Helm.

---

## 5. Criar a baseline com Kustomize

Visualizar primeiro:

```bash
kubectl kustomize app/overlays/normal/
```

Aplicar:

```bash
kubectl apply -k app/overlays/normal/
```

Aguardar:

```bash
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

Recolher evidência:

```bash
kubectl get nodes -o wide
kubectl get pods -n s78-lab -o wide
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
kubectl get pvc -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

A Pod Anti-Affinity do Deployment procura garantir uma réplica Symfony em cada Worker.

---

## 6. Preparar e instalar monitorização

O laboratório evita depender da Internet durante a formação. O formador deve escolher e validar previamente uma versão do `kube-prometheus-stack`.

Antes da sessão:

```bash
./monitoring/prepare-chart.sh <VERSAO_VALIDADA>
```

Durante a sessão:

```bash
helm install monitoring \
  ./packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 5m
```

Explorar:

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -A
```

Relação conceptual:

```text
CRD
 ↓
define um novo tipo na API
 ↓
Custom Resource
 ↓
instância desse tipo
 ↓
Controller / Operator
 ↓
reconciliação
```

---

## 7. Incidente 1 — Readiness

O formador provoca o incidente:

```bash
kubectl apply -k app/overlays/incident-probe/
```

Entregar ao formando:

```text
incidents/01-probe.md
```

Após o diagnóstico, repor a baseline:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

Mensagem-chave:

```text
Running ≠ Ready
```

---

## 8. Incidente 2 — Service / selector

Provocar:

```bash
kubectl apply -k app/overlays/incident-service/
```

Entregar:

```text
incidents/02-service.md
```

Repor:

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab
```

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

---

## 9. Incidente 3 — Worker `NotReady`

Entregar:

```text
incidents/03-node.md
```

Antes da falha, identificar a distribuição:

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

Se o cluster for partilhado, **apenas o formador** provoca a falha. Deve escolher o Worker que contém uma réplica Symfony mas **não** `postgres-0`.

No Worker selecionado:

```bash
sudo systemctl stop kubelet
```

Observar:

```bash
kubectl get nodes
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -A --sort-by=.lastTimestamp
```

Recuperar:

```bash
sudo systemctl start kubelet
```

Consolidar:

```text
resiliência do workload ≠ HA do Control Plane
HA ≠ backup
redundância de etcd ≠ snapshot de etcd
```

Não executar restore de `etcd` no cluster principal da formação.

---

## 10. Transição para gestão da aplicação com Helm

Kustomize e Helm não devem gerir simultaneamente os mesmos objetos. Antes de instalar a aplicação através do chart, remover apenas o Deployment e o Service Symfony criados pela baseline Kustomize:

```bash
kubectl delete deployment symfony-demo -n s78-lab
kubectl delete service symfony-demo -n s78-lab
```

PostgreSQL, PVC, Secret e Namespace permanecem.

Instalar a primeira release Helm:

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

---

## 11. Incidente 4 — Release candidata e rollback

Entregar:

```text
incidents/04-release.md
```

A candidata utiliza deliberadamente `values-broken.yaml`:

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

Recolher evidência:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Depois de identificada a revisão boa:

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait --timeout 3m
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

---

## 12. Custom Resource e reconciliação

Depois de instalado o Prometheus Operator:

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

O `PrometheusRule` permite trabalhar uma instância real de um recurso que não pertence à API Kubernetes base.

Pedir ao formando que altere um campo não destrutivo, por exemplo a annotation `summary` ou o tempo `for`, aplique novamente o ficheiro e observe o estado.

---

## 13. Método obrigatório de troubleshooting

Em todos os incidentes:

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

Cada cartão de incidente inclui uma grelha de registo. A resolução não é considerada completa apenas porque o serviço voltou a funcionar: o formando deve conseguir explicar a causa com evidência.

---

## 14. Limpeza

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

As CRDs instaladas pelo chart de monitorização podem permanecer no cluster. Não as remover automaticamente sem confirmar que não são utilizadas por outros componentes.

---

## 15. Material do formador

A resolução técnica e os resultados esperados estão em:

```text
solutions/SOLUCOES-FORMADOR.md
```

Este ficheiro **não deve ser usado como guião inicial dos formandos**. Como o repositório é público, a separação é apenas pedagógica; não existe controlo de acesso por diretoria.
