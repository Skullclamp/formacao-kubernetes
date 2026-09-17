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

# 1. Como utilizar este laboratório

Este é um **laboratório acompanhado pelo formador**. Não é uma ficha autónoma nem uma prova prática. O formador introduz cada checkpoint, explica o conceito, demonstra o objetivo do comando e orienta a leitura do resultado. Os formandos executam, observam, interpretam e registam evidência.

Todo o percurso está integrado neste documento. Não existem guiões Markdown separados por incidente.

Em cada checkpoint seguimos a mesma estrutura:

```text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS
        ↓
ONDE EXECUTAR
        ↓
COMANDOS / MANIFESTOS
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
ONDE OLHAR NO OUTPUT
        ↓
O QUE COMPARAR
        ↓
O QUE ESPERAR
        ↓
COMO INTERPRETAR
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
```

Nos incidentes, o método de troubleshooting é sempre:

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

> **Regra operacional:** primeiro observar; só depois alterar.

> **Regra de leitura:** não basta executar o comando. Em cada comando deve ser possível responder: **que campo procuro, com o que o comparo e o que concluo?**

> **Limite do cenário:** existe apenas um Control Plane. O laboratório demonstra resiliência de workloads e enquadra HA do Control Plane, mas não provoca a falha destrutiva do único Control Plane.

---

# 2. Distribuição das 4 horas

| Tempo | Atividade |
|---:|---|
| 10 min | CP0 — Enquadramento e precheck |
| 15 min | CP1 — HA, recuperação e método de troubleshooting |
| 45 min | CP2 — `Running ≠ Ready` + Service sem backends |
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

## O que estamos a fazer

Preparar a stack de monitorização antes da aula para que o tempo da sessão seja usado em troubleshooting, operação e reconciliação, e não na instalação do Prometheus Operator.

## Porque é necessário

O CP8 depende da existência da CRD `PrometheusRule`, do Prometheus Operator e da instância Prometheus.

## Onde executar

No **Control Plane**, com acesso administrativo ao cluster.

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

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `chmod +x` | torna o script executável |
| `helm upgrade --install` | instala a release se não existir ou atualiza-a se já existir |
| `--namespace monitoring` | usa o Namespace `monitoring` |
| `--create-namespace` | cria o Namespace se necessário |
| `-f` | fornece um ficheiro de values |
| `--wait` | espera pelas condições de disponibilidade conhecidas pelo Helm |
| `--timeout 10m` | limita a espera a dez minutos |

Validar:

```bash
helm status monitoring -n monitoring
kubectl get pods -n monitoring
kubectl get crd prometheusrules.monitoring.coreos.com
```

### Onde olhar no output

| Comando | Procurar | Esperado |
|---|---|---|
| `helm status` | campo `STATUS` | `deployed` |
| `kubectl get pods` | colunas `READY` e `STATUS` | Pods essenciais `Running` e Ready |
| `kubectl get crd` | nome da CRD | `prometheusrules.monitoring.coreos.com` |

### Checkpoint

**Não avançar para a formação** sem a stack preparada.

> Se o sistema operativo indicar que é necessário reiniciar algum Node, tratar essa manutenção **antes da formação**, numa janela controlada. Num cluster com apenas um Control Plane, não reiniciar o Control Plane durante o laboratório.

---

# CP0 — Enquadramento, materiais e baseline

## O que estamos a fazer

Confirmar que o cluster e as ferramentas necessárias estão disponíveis e criar uma baseline saudável da aplicação.

## Porque é necessário

Um incidente só é pedagogicamente útil se partir de um estado conhecido como bom. A baseline será o termo de comparação dos incidentes seguintes.

## Conceitos abordados

- baseline operacional;
- estado desejado;
- Deployment e StatefulSet;
- readiness;
- Service e EndpointSlice;
- persistência através de PVC;
- diferença entre **renderizar** e **aplicar** configuração declarativa.

## Onde executar

No **Control Plane**.

## 1. Obter ou atualizar os materiais

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

> `set -euo pipefail` é usado dentro de scripts para controlo de erros. **Não o ativar manualmente no shell interativo do laboratório**.

## 2. Renderizar antes de aplicar

```bash
kubectl kustomize app/overlays/normal/
```

### O que procurar

No YAML renderizado devem aparecer, entre outros, os objetos `Namespace`, `Secret`, `Service`, `Deployment` e `StatefulSet`.

A pergunta a responder é:

> **Que recursos serão enviados à API se aplicarmos este overlay?**

## 3. Aplicar e esperar pela baseline

```bash
kubectl apply -k app/overlays/normal/

kubectl rollout status statefulset/postgres \
  -n s78-lab --timeout=180s

kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
```

### Flags importantes

| Elemento | Significado |
|---|---|
| `apply -k` | aplica uma diretoria Kustomize |
| `rollout status` | acompanha a convergência do workload |
| `-n s78-lab` | limita a operação ao Namespace do laboratório |
| `--timeout=180s` | termina a espera após 180 segundos |

## 4. Recolher a baseline que será usada para comparação

```bash
kubectl get nodes
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get svc symfony-demo -n s78-lab
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Guia de leitura da baseline

| Output | Campo a observar | Estado de referência |
|---|---|---|
| Nodes | `STATUS` | todos `Ready` |
| Deployment | `READY` | `2/2` |
| Pods Symfony | `READY`, `STATUS`, `NODE` | dois Pods `1/1 Running`, em Workers diferentes |
| PostgreSQL | `READY`, `STATUS`, `NODE` | `postgres-0` `1/1 Running` |
| PVC | `STATUS` | `Bound` |
| EndpointSlice | `conditions.ready` | dois endpoints `ready: true` |

### O que guardar mentalmente

Esta é a referência saudável:

```text
Pods Symfony      → 2 × Ready
Deployment        → 2/2
Service selector  → corresponde às labels dos Pods
EndpointSlice     → 2 endpoints ready=true
Workers           → Ready
```

Tudo o que mudar nos incidentes deve ser comparado com esta baseline.

---

# CP1 — HA, recuperação e método de troubleshooting

## O que estamos a fazer

Definir o método usado em todos os incidentes e separar conceitos que são frequentemente confundidos.

## Conceitos abordados

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
Réplicas     → disponibilidade do workload
Persistência → dados sobrevivem ao ciclo de vida do Pod
Backup       → cópia para recuperação
HA           → continuidade perante determinadas falhas
Recovery     → capacidade de repor serviço/estado
```

## Como ler um incidente

Sempre que houver um problema, preencher mentalmente esta sequência:

| Etapa | Pergunta |
|---|---|
| Sintoma | O que deixou de funcionar? |
| Evidência | Que campo/output prova o sintoma? |
| Hipótese | Qual poderá ser a causa? |
| Teste | Que comando confirma ou rejeita a hipótese? |
| Causa raiz | Qual é a causa sustentada pela evidência? |
| Correção | O que altera a causa? |
| Validação | Que output prova que recuperou? |

---

# CP2 — Dois incidentes Kubernetes

# Incidente A — `Running` mas não `Ready`

## O que estamos a fazer

Introduzir deliberadamente uma `readinessProbe` inválida e observar a diferença entre **processo em execução** e **Pod pronto para receber tráfego**.

## Conceitos abordados

- `Running` versus `Ready`;
- readiness probe;
- Deployment rollout;
- EndpointSlice e condição `ready`;
- Events;
- diferença entre causa raiz e evento transitório.

## 1. Introduzir a falha

```bash
kubectl apply -k app/overlays/incident-probe/
```

## 2. Observar o sintoma

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
```

### Onde olhar

No `Deployment`, observar a coluna `READY`.

Esperado durante o incidente:

```text
READY
1/2
```

Nos Pods, **não olhar apenas para `STATUS`**. Comparar `READY` com `STATUS`.

Exemplo do padrão a procurar:

```text
NAME                         READY   STATUS    NODE
symfony-demo-...antigo       1/1     Running   k8s-wk-01
symfony-demo-...novo         0/1     Running   k8s-wk-03
```

### O que concluir

Se o Pod novo estiver `Running` mas `0/1`, então:

```text
container executa
≠
Pod pronto
```

Isto justifica investigar a readiness antes de investigar crashes.

## 3. Procurar a evidência da probe

Identificar o Pod `0/1` e executar:

```bash
kubectl describe pod <POD_NAO_READY> -n s78-lab
```

### Onde olhar no `describe`

Ir à secção **Events**, no final do output, e procurar mensagens que contenham:

```text
Readiness probe failed
```

No cenário de referência, a evidência importante é HTTP `404` no caminho `/ready-inexistente`.

Um fragmento equivalente a procurar é:

```text
Warning  Unhealthy  ...  Readiness probe failed: HTTP probe failed with statuscode: 404
```

### O que não confundir

Pode existir um `FailedScheduling` anterior por anti-affinity. Comparar o tempo e o estado atual:

- se o Pod já está atribuído a um Node, o scheduling acabou por ocorrer;
- se continua `0/1 Running` e a readiness dá `404`, a causa persistente é a probe.

## 4. Comparar os endpoints

```bash
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Onde olhar

Dentro de `endpoints:`, localizar para cada endpoint:

```yaml
conditions:
  ready: true|false
  serving: true|false
```

Esperado:

```text
endpoint do Pod saudável   → ready=true
endpoint do Pod não Ready  → ready=false
```

> O Pod pode continuar representado no EndpointSlice. O que interessa é a condição `ready`, não apenas a presença do endereço.

## 5. Recuperar e comparar com a baseline

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s

kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Checkpoint — não avançar sem validar

```text
Deployment → 2/2
Pods       → 2 × 1/1 Running
Endpoints  → 2 × ready=true
```

Mensagem-chave:

```text
Running ≠ Ready
```

---

# Incidente B — Service existente, mas sem backends

## O que estamos a fazer

Alterar deliberadamente o selector do Service para que deixe de corresponder às labels dos Pods.

## Porque é necessário

Um Service pode existir e estar configurado sem possuir qualquer backend utilizável.

```text
Service existente ≠ Service com backends
```

## Conceitos abordados

- labels;
- selector de Service;
- EndpointSlice;
- descoberta de backends;
- relação entre objeto Service e Pods.

## Onde executar

No **Control Plane**.

## 1. Introduzir a falha

```bash
kubectl apply -k app/overlays/incident-service/
```

## 2. Observar em três passos — Pods, selector, endpoints

Não interpretar os três outputs ao mesmo tempo. Fazer a comparação seguinte pela ordem indicada.

### Passo A — confirmar que os Pods continuam saudáveis e identificar a label

```bash
kubectl get pods -n s78-lab --show-labels
```

### Onde olhar

Localizar as duas réplicas Symfony e comparar três elementos:

```text
READY   STATUS    LABELS
1/1     Running   ... app=symfony-demo ...
```

O valor importante é:

```text
app=symfony-demo
```

### O que concluir

Se os Pods estão `1/1 Running`, então **o problema não é que os Pods tenham deixado de executar**.

Registar mentalmente:

```text
label real dos Pods = app=symfony-demo
```

### Passo B — ver o selector que o Service está realmente a usar

```bash
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'
```

### Porque usamos `jsonpath`

Para não obrigar o formando a procurar manualmente dentro de um YAML grande. Queremos apenas o valor que precisa de ser comparado.

Esperado durante o incidente:

```text
selector=symfony-demo-inexistente
```

### Comparação que o formando deve fazer

```text
Pods:     app=symfony-demo
Service:  app=symfony-demo-inexistente
                 ↑
            NÃO COINCIDE
```

Esta comparação é a evidência principal da hipótese.

### Passo C — provar que o selector não encontra Pods

```bash
kubectl get pods -n s78-lab \
  -l app=symfony-demo-inexistente
```

### Onde olhar

Esperado: nenhuma linha de Pod correspondente, ou mensagem equivalente a:

```text
No resources found in s78-lab namespace.
```

A flag `-l` significa **label selector**. Estamos a fazer manualmente a mesma pergunta lógica que o Service faz:

> Existem Pods com esta label?

A resposta deve ser **não**.

## 3. Confirmar o impacto no EndpointSlice

```bash
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Onde olhar no YAML

Procurar a chave:

```yaml
endpoints:
```

No cenário de referência, a secção aparece sem backends, por exemplo:

```yaml
endpoints: null
```

ou equivalente sem entradas em `endpoints`.

### O que comparar

| Baseline | Incidente |
|---|---|
| Pods `1/1 Running` | Pods continuam `1/1 Running` |
| selector `app=symfony-demo` | selector `app=symfony-demo-inexistente` |
| 2 endpoints | nenhum endpoint utilizável |

### Diagnóstico completo

```text
Sintoma    → Service sem backends
Evidência  → Pods Ready; selector não coincide; selector encontra 0 Pods; EndpointSlice sem endpoints
Causa raiz → selector errado no Service
```

## 4. Recuperar

```bash
kubectl apply -k app/overlays/normal/

kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'

kubectl get pods -n s78-lab \
  -l app=symfony-demo

kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### O que deve mudar após a recuperação

```text
selector=symfony-demo
```

O comando com `-l app=symfony-demo` deve voltar a listar as duas réplicas Symfony e o EndpointSlice deve voltar a conter os dois endpoints.

### Checkpoint — não avançar sem validar

```text
Pods          → 2 × Ready
selector      → app=symfony-demo
selector test → encontra os Pods Symfony
EndpointSlice → 2 endpoints ready=true
```

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

---

# CP3 — Worker `NotReady` e resiliência

## O que estamos a fazer

Parar **apenas o kubelet** de um Worker escolhido e observar como o Control Plane deteta a indisponibilidade e tenta reconciliar o Deployment.

## Porque é necessário

Demonstra que o estado desejado não garante convergência imediata quando não existe capacidade elegível para reagendar uma réplica.

## Conceitos abordados

- `kubelet`;
- heartbeat e condição `Ready`;
- taints `NotReady` / `Unreachable`;
- eviction;
- Deployment controller;
- Scheduler;
- anti-affinity obrigatória;
- EndpointSlice;
- resiliência de workload versus HA do Control Plane.

## 1. Registar a situação antes da falha

```bash
kubectl get nodes
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

### O que comparar

- todos os Nodes devem estar `Ready`;
- identificar em que Worker está `postgres-0`;
- escolher para a falha o **outro Worker**, que contém uma réplica Symfony mas não PostgreSQL.

## 2. Provocar a falha — apenas o formador

No Worker escolhido:

```bash
sudo systemctl stop kubelet
```

Não parar `containerd`, não desligar a VM e não tocar no Control Plane.

## 3. Observar a mudança do Node

No Control Plane:

```bash
kubectl get nodes -w
```

### Onde olhar

Na coluna `STATUS` do Worker alvo:

```text
Ready → NotReady
```

`-w` significa **watch** e mantém a consulta aberta para mostrar alterações.

## 4. Observar o impacto no workload

Noutro terminal:

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### O que procurar em cada output

| Output | Campo/secção | Esperado durante o incidente |
|---|---|---|
| Deployment | `READY` | pode ficar `1/2` |
| Pods | `STATUS`, `NODE` | réplica no Worker afetado deixa de ser uma capacidade fiável; replacement pode surgir `Pending` |
| Events | mensagens `FailedScheduling` | razões de scheduling, anti-affinity e/ou taints |
| EndpointSlice | `conditions.ready` | um backend saudável `true`, outro pode ficar `false` |
| PostgreSQL | `READY/STATUS` | permanece saudável no Worker não afetado |

Se existir um Pod `Pending`:

```bash
kubectl describe pod <POD_PENDING> -n s78-lab
```

### Onde olhar no `describe`

Na secção **Events**, procurar `FailedScheduling` e ler a mensagem completa. O objetivo não é decorar a mensagem; é identificar **por que nenhum Node é elegível**.

Pergunta orientadora:

> O controlador quer 2 réplicas. Porque é que o Scheduler ainda não consegue colocar a segunda?

A resposta deve ser suportada por Events, não apenas por suposição.

## 5. Recuperar

No Worker:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

No Control Plane:

```bash
kubectl get nodes
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=300s
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Comparar antes / falha / recuperação

```text
ANTES       Worker Ready     Deployment 2/2    2 endpoints Ready
FALHA       Worker NotReady  Deployment 1/2    redundância reduzida
RECUPERAÇÃO Worker Ready     Deployment 2/2    2 endpoints Ready
```

Mensagem-chave:

```text
Estado desejado ≠ convergência imediata
Resiliência do workload ≠ HA do Control Plane
```

---

# CP4 — Control Plane, `etcd`, HA e recuperação

## O que estamos a fazer

Observar os componentes do único Control Plane e consultar o endpoint de readiness da API, sem provocar qualquer falha.

## Conceitos abordados

- `kube-apiserver`;
- `kube-controller-manager`;
- `kube-scheduler`;
- `etcd`;
- static Pods;
- `/readyz`;
- HA do Control Plane;
- backup e recovery de `etcd`.

## Comandos

```bash
kubectl get pods -n kube-system -o wide \
  | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'

kubectl get --raw='/readyz?verbose'
```

### Onde olhar no primeiro output

Na coluna `NODE`, verificar onde estão:

```text
etcd
kube-apiserver
kube-controller-manager
kube-scheduler
```

No nosso cenário, todos estão no mesmo `k8s-cp-01`.

### O que concluir

```text
todos Running no único CP
→ Control Plane saudável agora

não existem outros CP
→ não existe redundância do Control Plane
```

### Onde olhar em `/readyz?verbose`

Procurar explicitamente:

```text
[+]etcd ok
[+]etcd-readiness ok
...
readyz check passed
```

### O que este output prova — e o que não prova

| Prova | Não prova |
|---|---|
| API está Ready agora | que exista HA |
| API consegue comunicar com `etcd` | que `etcd` seja redundante |
| checks internos passaram | que exista backup |

Consolidar:

```text
2 Pods Web em 2 Workers → resiliência do workload
1 Control Plane          → sem HA do Control Plane
snapshot etcd            → ponto de recuperação
HA                       ≠ Backup ≠ Recovery
```

> **Não executar:** stop/restart de componentes do Control Plane, stop/restart de `etcd` ou restore destrutivo neste cluster.

---

# INTERVALO — 15 minutos

---

# CP5 — Helm, Kustomize, CRD e Operator: mapa conceptual

## O que estamos a fazer

Introduzir os conceitos que serão praticados nos CP seguintes e confirmar que as ferramentas/extensões necessárias existem.

## Conceitos abordados

### Helm

```text
Chart + Values
      ↓
Release
      ↓
Revision
```

- **Chart**: pacote de templates;
- **Values**: valores usados para renderizar os templates;
- **Release**: instalação concreta do Chart;
- **Revision**: versão histórica da release.

### Kustomize

```text
Base + Overlay
      ↓
manifestos renderizados
```

### CRD, CR e Operator

```text
CRD
 ↓
define novo tipo na API
 ↓
Custom Resource
 ↓
declara estado desejado
 ↓
Controller / Operator
 ↓
reconciliação
```

## Confirmar ferramentas

```bash
helm version --short
kubectl kustomize app/overlays/normal/ >/dev/null
kubectl get crd prometheusrules.monitoring.coreos.com
kubectl get deployments -n monitoring | grep -i operator
```

### Onde olhar

| Comando | Procurar |
|---|---|
| `helm version --short` | versão Helm válida |
| `kubectl kustomize ... >/dev/null` | ausência de erro de renderização |
| `kubectl get crd` | CRD existente |
| `get deployments ... operator` | Operator disponível/Ready |

Mensagem-chave:

```text
CRD ≠ CR
CR + Controller/Operator → reconciliação
```

---

# CP6 — Helm: adoção, upgrade defeituoso e rollback

## O que estamos a fazer

Transferir o Deployment e o Service Symfony para gestão Helm, introduzir uma revisão defeituosa, diagnosticar a causa e recuperar por rollback.

## Conceitos abordados

- `helm template`;
- `kubectl diff`;
- ownership;
- Chart, Release e Revision;
- upgrade;
- `--wait` e `--timeout`;
- `ImagePullBackOff`;
- rollback e histórico.

## 1. Renderizar e comparar antes de instalar

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

### Flags / elementos importantes

| Elemento | Significado |
|---|---|
| `helm template` | renderiza YAML sem criar uma release |
| `-f values-good.yaml` | usa os valores conhecidos como bons |
| `>` | grava o YAML renderizado num ficheiro |
| `kubectl diff` | mostra diferenças sem alterar o cluster |
| `|| true` | evita terminar o fluxo quando `diff` devolve código diferente de zero por existirem diferenças |

### Onde olhar

No diff, procurar mudanças funcionais inesperadas em:

- `image`;
- probes;
- réplicas;
- ports;
- resources.

Labels/anotações de gestão Helm podem aparecer e são esperadas.

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

### Flags importantes

| Flag | Significado |
|---|---|
| `--install` | instala se a release ainda não existir |
| `--take-ownership` | permite que Helm passe a gerir objetos já existentes |
| `--wait` | espera pela convergência |
| `--timeout 180s` | limita a espera |

Validar ownership:

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{" release="}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'

kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{" release="}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
```

Esperado:

```text
managed-by=Helm release=symfony-lab
```

Isto é a evidência de ownership. Um `kubectl diff` vazio **não** prova ownership.

## 3. Criar uma revisão defeituosa

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o comando termine por timeout.

## 4. Diagnosticar por camadas

### Primeiro: histórico Helm

```bash
helm history symfony-lab -n s78-lab
```

### Onde olhar

Comparar as colunas `REVISION` e `STATUS`.

Esperado após a falha:

```text
REVISION 1  ... superseded/deployed anterior
REVISION 2  ... failed
```

A pergunta é:

> A falha criou uma nova revisão? Qual o estado dessa revisão?

### Segundo: estado do workload

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
```

Procurar:

```text
Deployment READY → 1/2
novo Pod         → ErrImagePull ou ImagePullBackOff
```

### Terceiro: confirmar a causa raiz

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
```

Na secção **Events**, procurar `Failed to pull image`, `ErrImagePull`, `ImagePullBackOff` ou erro de resolução do registry.

Depois confirmar a imagem declarada:

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

Esperado durante o incidente:

```text
image=registry.invalid/s78/symfony-demo:1.0.0
```

### Comparação que fecha o diagnóstico

```text
Helm history  → revisão nova failed
Pod           → ImagePullBackOff
Events        → falha de pull/resolução
Deployment    → registry.invalid/...
```

Conclusão: causa raiz = imagem/registry inválido.

Um `FailedScheduling` transitório só é causa raiz se persistir e impedir o Pod de ser agendado.

## 5. Rollback

Consultar primeiro:

```bash
helm history symfony-lab -n s78-lab
```

Escolher a revisão boa e executar:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab \
  --wait \
  --timeout 180s
```

## 6. Validar o rollback

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

### Onde olhar

- `helm status` → `STATUS: deployed`;
- `helm history` → aparece **uma nova revision** de rollback;
- Deployment → `2/2`;
- imagem → `ghcr.io/skullclamp/symfony-demo:1.0.0`.

Mensagem-chave:

```text
Chart ≠ Release ≠ Revision
Rollback recupera conteúdo anterior, mas cria uma nova revision.
```

---

# CP7 — Kustomize: base, overlays e comparação declarativa

## O que estamos a fazer

Observar como Kustomize produz variantes a partir de uma base comum e comparar renderizações **sem reaplicar** os objetos Symfony agora geridos por Helm.

## Conceitos abordados

- base;
- overlay;
- patch;
- renderização;
- diff declarativo;
- ownership e fronteiras de gestão.

## 1. Renderizar variantes

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml
```

## 2. Comparar exatamente o que muda

```bash
diff -u /tmp/normal.yaml /tmp/probe.yaml || true
diff -u /tmp/normal.yaml /tmp/service.yaml || true
```

### Como ler um `diff -u`

```text
- linha removida/estado anterior
+ linha adicionada/novo estado
```

No overlay de probe, procurar a alteração do caminho da readiness.

No overlay de Service, procurar a alteração do selector.

A pergunta é:

> Qual é a alteração mínima introduzida pelo overlay relativamente à base saudável?

## 3. Comparar com o cluster sem alterar

```bash
kubectl kustomize app/overlays/normal/ > /tmp/s78-kustomize-render.yaml
kubectl diff -n s78-lab -f /tmp/s78-kustomize-render.yaml || true
```

### Como interpretar

- output com diferenças → mostra alterações que um apply declararia;
- sem output → não existem diferenças declarativas relevantes segundo a semântica do `kubectl diff` naquele momento;
- **não usar este resultado para concluir ownership**.

> Depois da adoção Helm, **não voltar a fazer `kubectl apply -k` sobre Deployment/Service Symfony**. Helm é o mecanismo responsável por esses objetos.

---

# CP8 — CRD, Custom Resource e reconciliação

## O que estamos a fazer

Criar um `PrometheusRule`, alterar o seu estado desejado e provar que o Operator/Prometheus reconciliou essa alteração.

## Conceitos abordados

- CRD;
- Custom Resource;
- `metadata.generation`;
- Controller/Operator;
- reconciliação;
- diferença entre alterar a API Kubernetes e provar efeito no sistema gerido.

## 1. Confirmar o tipo e o controller

```bash
kubectl get crd prometheusrules.monitoring.coreos.com
kubectl api-resources | grep -E 'PrometheusRule|Prometheus'
kubectl get deployments -n monitoring | grep -i operator
```

### Onde olhar

- CRD existe;
- `PrometheusRule` aparece como recurso da API;
- deployment do Operator está disponível.

## 2. Criar o Custom Resource

```bash
kubectl apply -f monitoring/prometheus-rule.yaml

kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

### Atenção ao namespace

```text
PrometheusRule existe em → monitoring
PromQL observa          → s78-lab
```

Não são o mesmo conceito.

### O que registar antes da alteração

Exemplo:

```text
generation=1
summary=Existem réplicas indisponíveis no Deployment symfony-demo
```

Os números concretos podem variar se o recurso já tiver sido alterado antes. O importante é guardar o valor **antes** para comparar **depois**.

## 3. Alterar apenas a `summary`

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

Repetir:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

### O que comparar

```text
ANTES   generation=N    summary=original
DEPOIS  generation=N+1  summary=Reconciliação observada: ...
```

### O que isto prova

Prova que **o estado desejado guardado na API Kubernetes mudou**.

### O que ainda não prova

Ainda não prova que Prometheus recebeu essa alteração.

## 4. Provar a reconciliação no Prometheus

Num terminal:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

Noutro terminal no mesmo Control Plane:

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

### Onde olhar

Esperado após a alteração:

```text
name=SymfonyDeploymentUnavailable
state=inactive
summary=Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo
```

### Como interpretar

- `summary` modificada na API do Prometheus → **reconciliação provada**;
- `state=inactive` → normal se o Deployment estiver saudável;
- `generation` ter aumentado sozinho não seria prova suficiente de reconciliação.

## 5. Repor e provar nova reconciliação

```bash
kubectl apply -f monitoring/prometheus-rule.yaml

kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Repetir a consulta Python.

### O que comparar

```text
Kubernetes API  → summary voltou ao original
Prometheus API  → summary também voltou ao original
```

Só quando os dois lados coincidem é que a reposição ficou demonstrada.

Mensagem-chave:

```text
CRD ≠ CR
Generation aumentou ≠ reconciliação provada
CR + Controller/Operator → reconciliação
```

Terminar o `port-forward` com `Ctrl+C`.

---

# CP9 — Desafio final e validação global

## O que estamos a fazer

Aplicar o método completo de troubleshooting sem receber imediatamente a causa raiz e provar que o ambiente terminou saudável.

## Antes de executar comandos

A turma deve propor a ordem de investigação:

```text
estado geral
   ↓
Pod / Deployment
   ↓
Events / describe / logs
   ↓
Service / EndpointSlice
   ↓
Helm history, se aplicável
   ↓
hipótese
   ↓
teste
   ↓
correção
   ↓
validação
```

## Validação global obrigatória

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

### Guia de leitura final

| Verificação | Onde olhar | Esperado |
|---|---|---|
| Nodes | coluna `STATUS` | todos `Ready` |
| PostgreSQL | `READY/STATUS` | `1/1 Running` |
| Deployment | `READY` | `2/2` |
| Pods Symfony | `READY`, `STATUS`, `NODE` | dois `1/1 Running`, distribuídos pelos Workers |
| Imagem | valor do `jsonpath` | `ghcr.io/skullclamp/symfony-demo:1.0.0` |
| Helm | `STATUS` | `deployed` |
| Helm history | revisões | falha histórica preservada e revisão atual boa |
| EndpointSlice | `ready`, `serving`, `terminating` | dois `ready=true`, `serving=true`, `terminating=false` |

## Regra de fecho

Não terminar com frases como “parece estar bom”. Terminar com evidência:

```text
Todos os Nodes Ready
+ PostgreSQL 1/1
+ Deployment 2/2
+ imagem correta
+ Helm deployed
+ dois endpoints Ready
= recuperação validada
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

Generation aumentou ≠ reconciliação provada

CR + Controller/Operator → reconciliação

Sem evidência não há diagnóstico.
Sem causa raiz não há troubleshooting completo.
Sem validação pós-correção não há recuperação demonstrada.
```

---

# Limpeza

A monitorização foi preparada pelo formador e **não deve ser removida pelos formandos** no final do laboratório.

```bash
kubectl delete prometheusrule s78-lab-rules \
  -n monitoring --ignore-not-found

helm uninstall symfony-lab -n s78-lab || true
kubectl delete namespace s78-lab --ignore-not-found
```

Não remover CRDs do Prometheus Operator durante a aula.
