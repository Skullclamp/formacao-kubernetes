# Laboratório Integrado — Sessões 7 e 8
## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

**Módulos:** M10 + M11  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** 1 Control Plane + 2 Worker Nodes  
**Runtime:** `containerd`  
**CNI:** Calico  
**StorageClass:** `local-path`  
**Aplicação:** Symfony Demo + PostgreSQL 16  
**Namespace da aplicação:** `s78-lab`  
**Namespace da monitorização:** `monitoring`

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

# 3. Preparação do formador — antes do laboratório

A monitorização é preparada **antes da aula**, para não consumir tempo do laboratório.

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

Não avançar para o laboratório sem esta preparação concluída.

> Se o sistema operativo indicar que é necessário reiniciar algum Node, tratar essa manutenção **antes da formação**, numa janela controlada. Num cluster com apenas um Control Plane, não reiniciar o Control Plane durante o laboratório.

---

# CP0 — Enquadramento e precheck

## Obter ou atualizar os materiais

Se ainda não existir clone local:

```bash
cd ~
git clone --depth 1 https://github.com/Skullclamp/formacao-kubernetes.git
```

Se o repositório já existir:

```bash
cd ~/formacao-kubernetes
git pull --ff-only origin main
```

Depois:

```bash
cd ~/formacao-kubernetes/sessao-07-08
bash 00-precheck/precheck.sh
```

> `set -euo pipefail` é usado dentro de scripts para controlo de erros. **Não o ativar manualmente no shell interativo do laboratório**, porque pode terminar a sessão perante comandos pedagógicos que falham intencionalmente.

O precheck confirma:

- API Kubernetes acessível;
- pelo menos 2 Workers `Ready`;
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
  -n s78-lab --timeout=180s

kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
```

Recolher evidência:

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
```

### CHECKPOINT

Confirmar:

```text
postgres-0       → Running / Ready
PVC              → Bound
Symfony          → Deployment 2/2
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
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
```

Identificar o Pod novo e aprofundar:

```bash
kubectl describe pod <POD> -n s78-lab
kubectl logs <POD> -n s78-lab

kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Evidência esperada:

- Pod `Running`, mas `Ready=False`;
- readiness em `/ready-inexistente` com HTTP `404`;
- Deployment sem convergir para `2/2`;
- o Pod não pronto pode continuar representado no EndpointSlice com `ready: false` e `serving: false`;
- a réplica saudável permanece `ready: true`.

> **Atenção:** estar presente no EndpointSlice não significa estar Ready/elegível para tráfego normal. Interpretar a condição `ready`.

Um `FailedScheduling` transitório por anti-affinity pode surgir durante o rollout. Não o confundir com a causa raiz se o Pod acabar agendado e a falha persistente for a readiness probe.

Perguntas orientadoras:

- O container está a executar?
- O Pod está `Ready`?
- Que probe está a falhar?
- O Pod aparece no EndpointSlice? Com que condição `ready`?
- Porque não termina o rollout?

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s

kubectl get deployment symfony-demo -n s78-lab
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
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
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab \
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
kubectl get pods -n s78-lab -l <CHAVE>=<VALOR>
```

No cenário validado, o selector incorreto não encontra Pods e o EndpointSlice fica sem endpoints (`endpoints: null`).

### Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
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
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

Escolher o Worker que contém uma réplica Symfony mas **não** o PostgreSQL.

> A ação disruptiva é executada pelo formador.

No Worker escolhido, parar **apenas o kubelet**:

```bash
sudo systemctl stop kubelet
```

> Não parar `containerd`, não desligar a VM e não tocar no Control Plane. Este cenário demonstra perda de heartbeat/gestão do Node, não uma falha física completa.

Observar em tempo real:

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Se surgir um Pod `Pending`:

```bash
kubectl describe pod <POD_PENDING> -n s78-lab
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

No cenário validado, o PostgreSQL manteve-se saudável no outro Worker; a aplicação conservou uma réplica Symfony elegível, mas perdeu redundância; a réplica de substituição ficou temporariamente `Pending` devido a anti-affinity/taints.

Mensagem intermédia:

```text
estado desejado ≠ convergência imediata
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
  -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Não avançar enquanto o Worker não estiver `Ready`, o Deployment não estiver `2/2` e os dois endpoints não estiverem `ready: true`.

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

1 único Control Plane saudável
→ disponibilidade atual, mas sem redundância do Control Plane

vários Control Planes + etcd redundante
→ HA do Control Plane

snapshot de etcd
→ ponto de recuperação do estado do cluster
```

Mensagem-chave:

```text
Control Plane saudável ≠ Control Plane altamente disponível
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

Consolidar desde já:

```text
CRD ≠ CR
CR + Controller/Operator → reconciliação
```

---

# CP6 — Helm: adoção, falha e rollback

A aplicação foi criada inicialmente por Kustomize. Agora o Deployment e o Service Symfony serão geridos como parte da release Helm. PostgreSQL e Secret permanecem fora desta adoção.

## 1. Renderizar antes de instalar

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

Interpretar o diff antes de continuar. A adoção pode introduzir labels de gestão Helm e provocar um rollout sem alterar a lógica funcional da aplicação.

## 2. Transferir ownership para Helm

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
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
```

Só avançar quando:

```text
Deployment → 2/2
Helm       → deployed
ownership  → Helm | symfony-lab
```

## 3. Introduzir um upgrade defeituoso

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o comando termine por timeout e que a nova revisão fique `failed`.

Diagnosticar:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

No cenário validado, a causa raiz é uma imagem num registry inválido:

```text
registry.invalid/s78/symfony-demo:1.0.0
```

O Pod novo evidencia `ErrImagePull`/`ImagePullBackOff`. Um `FailedScheduling` transitório por anti-affinity não deve ser confundido com a causa raiz se o Pod acabar por ser agendado.

## 4. Rollback

Identificar a revisão boa no histórico:

```bash
helm history symfony-lab -n s78-lab
```

Depois:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab \
  --wait \
  --timeout 180s
```

> O rollback usa o conteúdo de uma revisão anterior, mas cria uma **nova revisão** no histórico.

Validar:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
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
nova revision
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

Comparar as renderizações **sem alterar o cluster**:

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml

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

> Depois da adoção pelo Helm, **não voltar a executar `kubectl apply -k` sobre o Deployment e o Service Symfony**. Evitar que dois mecanismos de gestão alterem os mesmos objetos sem uma estratégia explícita.

Para confirmar ownership, usar metadata Helm:

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
```

Um `kubectl diff` vazio não deve ser interpretado como prova de ownership; a comparação `kubectl apply` é influenciada pelo estado `last-applied`.

Pergunta de consolidação:

> Porque é preferível alterar apenas o que difere entre variantes em vez de duplicar integralmente todos os manifests?

---

# CP8 — CRD, Custom Resource e reconciliação

O Prometheus Operator já foi preparado pelo formador.

## 1. Identificar extensões da API

```bash
kubectl get crd prometheusrules.monitoring.coreos.com
kubectl api-resources | grep -E 'PrometheusRule|Prometheus'
kubectl get deployments -n monitoring | grep -i operator
```

## 2. Criar o Custom Resource pedagógico

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
```

> O `PrometheusRule` existe no namespace `monitoring`. A expressão PromQL que contém pode observar o Deployment no namespace `s78-lab`. Não confundir o namespace do CR com o namespace referido pela regra.

Registar a geração e a `summary` atuais:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

## 3. Alterar o estado desejado

Alterar apenas a `summary`:

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

Confirmar que `generation` aumentou:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

## 4. Provar a reconciliação no sistema gerido

Num terminal no Control Plane:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

> Manter apenas **um** `port-forward` para `127.0.0.1:9090` na mesma máquina. Se a porta estiver ocupada porque outro terminal já tem o forward ativo, reutilizar esse processo em vez de abrir outro.

Noutro terminal no mesmo Control Plane, aguardar alguns segundos e consultar a API do Prometheus filtrando explicitamente o grupo e a regra:

```bash
sleep 10

python3 - <<'PY'
import json
import urllib.request

url = "http://127.0.0.1:9090/api/v1/rules"

with urllib.request.urlopen(url) as r:
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

A evidência de reconciliação é a nova `summary` aparecer na API do Prometheus. `state=inactive` é normal enquanto o Deployment Symfony estiver saudável.

## 5. Repor e validar o estado original

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Repetir a consulta à API e confirmar que a `summary` original voltou a ser apresentada. Depois terminar o `port-forward` com `Ctrl+C` no terminal onde está ativo.

Consolidar:

```text
CRD              → define o tipo
Custom Resource  → declara estado desejado
Controller       → observa
Operator         → aplica lógica operacional
Reconciliação    → aproxima estado real do desejado
```

---

# CP9 — Desafio final e validação global

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
helm history symfony-lab -n s78-lab
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait
```

## Validação global obrigatória

Antes de terminar o laboratório:

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

Confirmar:

```text
Nodes       → todos Ready
PostgreSQL  → 1/1 Running
Deployment  → 2/2
Symfony     → duas réplicas 1/1 Running, distribuídas pelos Workers
Imagem      → ghcr.io/skullclamp/symfony-demo:1.0.0
Helm        → deployed
Endpoints   → dois ready=true, serving=true, terminating=false
```

---

# Síntese final

```text
Running ≠ Ready

Service existente ≠ Service com backends

Estado desejado ≠ convergência imediata

Resiliência do workload ≠ HA do Control Plane

Control Plane saudável ≠ Control Plane altamente disponível

HA ≠ Backup ≠ Recovery

Chart ≠ Release ≠ Revision

CRD ≠ Custom Resource

CR + Controller/Operator → reconciliação

Sem evidência não há diagnóstico.
Sem causa raiz não há troubleshooting completo.
Sem validação pós-correção não há recuperação demonstrada.
```

---

# Limpeza

A monitorização foi preparada pelo formador e **não deve ser removida pelos formandos** no final do laboratório.

Remover o Custom Resource pedagógico criado no namespace `monitoring`:

```bash
kubectl delete prometheusrule s78-lab-rules \
  -n monitoring --ignore-not-found
```

Remover os recursos da aplicação quando indicado:

```bash
helm uninstall symfony-lab -n s78-lab || true
kubectl delete namespace s78-lab --ignore-not-found
```

Não remover CRDs do Prometheus Operator durante a aula.
