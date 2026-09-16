# Laboratório Integrado — Sessões 7 e 8
## Continuidade, Troubleshooting e Operação Avançada de Kubernetes

**Sessões:** 7 e 8 de 10  
**Nível:** intermédio  
**Duração:** 4 horas  
**Topologia:** 1 Control Plane + 2 Worker Nodes  
**Runtime:** `containerd`  
**CNI:** Calico  
**StorageClass:** `local-path`  
**Aplicação:** Symfony Demo + PostgreSQL 16  
**Namespace:** `s78-lab`  
**Operator:** Prometheus Operator através de `kube-prometheus-stack`  
**Chart validado:** `kube-prometheus-stack` 91.4.1

Este documento é o **laboratório integrado das Sessões 7 e 8**. O objetivo não é executar comandos mecanicamente. Em cada checkpoint, o formando deve conseguir explicar:

```text
O que estou a fazer?
        ↓
Porque é necessário?
        ↓
Que conceito Kubernetes está envolvido?
        ↓
O que significam os comandos e flags relevantes?
        ↓
Que evidência prova o resultado?
```

Nos incidentes, o método obrigatório é:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

A progressão pedagógica global é:

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

> **Regra do laboratório:** um comando que termina sem erro prova apenas que esse comando terminou sem erro. Não prova, por si só, que a aplicação está saudável nem que o comportamento pretendido foi alcançado.

> **Limite do cenário:** este cluster tem apenas um Control Plane. Permite estudar os componentes do Control Plane e discutir Alta Disponibilidade, mas **não demonstra HA real do Control Plane**.

> **Identidade das máquinas:** as máquinas Ubuntu dos formandos são criadas de raiz. Não faz parte do procedimento normal recolher `machine-id`, UUID de firmware/disco, `systemUUID` ou identificadores equivalentes. Esses dados só devem ser investigados perante um sintoma concreto de clonagem ou identidade duplicada.

---

# Como ler os comandos deste laboratório

Algumas flags aparecem repetidamente. O formando deve saber interpretá-las:

```text
-n <namespace>       → executa a operação no Namespace indicado
-A                   → consulta todos os Namespaces
-f <ficheiro>        → usa um manifesto ou ficheiro de valores
-k <diretoria>       → usa uma diretoria Kustomize
-l <selector>        → filtra objetos por labels
-o wide              → mostra informação adicional, como IP e Node
-o yaml              → devolve a representação YAML do objeto
-o jsonpath='...'    → extrai campos concretos do objeto
--show-labels        → acrescenta as labels ao output
--sort-by=<campo>    → ordena o resultado pelo campo indicado
-w                   → mantém o comando em modo watch
--wait               → espera por condições de prontidão suportadas pela ferramenta
--timeout <tempo>    → limita o tempo de espera
--create-namespace   → cria o Namespace se ainda não existir
--take-ownership     → permite ao Helm assumir ownership de objetos existentes
--                    → termina a interpretação de opções do comando atual
|| true              → impede que um código de saída diferente de zero interrompa a sequência
```

Nem todas as flags são repetidas do zero em cada checkpoint. Em cada secção são explicados sobretudo os **comandos novos**, as flags que alteram o comportamento da operação e a evidência que deve ser observada.

---

# Estrutura dos materiais

A partir da diretoria `sessao-07-08/`:

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

# Distribuição das 4 horas

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

Confirmar que as ferramentas e o cluster estão utilizáveis antes de descarregar e aplicar os materiais do laboratório.

**Executar em:** terminal administrativo com acesso ao cluster.

## O que estamos a fazer e porquê

Antes de introduzir qualquer alteração, estabelecemos uma baseline mínima da infraestrutura. Se o cluster já estiver degradado, um erro observado mais tarde pode ser atribuído erradamente ao exercício.

Queremos confirmar quatro camadas:

```text
ferramentas locais
      +
API Kubernetes
      +
Nodes e storage
      +
rede/CNI
      =
ponto de partida confiável
```

## Conceitos a compreender

### `kubectl`

`kubectl` é o cliente de linha de comandos usado para comunicar com a API Kubernetes. Não fala diretamente com os Pods ou com o `containerd`; envia pedidos ao `kube-apiserver` de acordo com o contexto definido no `kubeconfig`.

### Helm

**Helm** é uma ferramenta de gestão de aplicações Kubernetes baseada em **charts**. Um chart agrupa templates Kubernetes, valores configuráveis e metadados. Quando um chart é instalado, o Helm cria uma **release** e mantém histórico das respetivas revisões.

Neste laboratório, Helm será usado para:

```text
instalar o Prometheus Operator
        +
gerir a aplicação Symfony como release
        +
executar upgrade
        +
observar histórico
        +
executar rollback
```

### CNI e Calico

O Kubernetes define o modelo de rede, mas precisa de uma implementação CNI para materializar essa rede. Neste cluster, o CNI é **Calico**, responsável pela conectividade dos Pods e pelo enforcement de `NetworkPolicy`.

### StorageClass

Uma `StorageClass` descreve uma classe de armazenamento e o provisionador associado. O laboratório usa `local-path` para provisionamento dinâmico dos volumes persistentes.

## Comandos

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

Confirmar também que a versão do Helm suporta a transferência de ownership usada no CP7:

```bash
helm upgrade --help | grep -- '--take-ownership'
```

## Como interpretar os comandos e flags

```text
command -v <comando>
→ confirma se o executável está disponível no PATH

helm version --short
→ mostra a versão do cliente Helm de forma compacta

kubectl cluster-info
→ confirma comunicação com a API e mostra endpoints principais do cluster

kubectl get nodes -o wide
→ lista Nodes e acrescenta informação operacional, como IP, versão e função

kubectl get storageclass local-path
→ consulta diretamente a StorageClass exigida pelo laboratório

kubectl get pods -A
→ lista Pods em todos os Namespaces

| grep -i calico
→ filtra o output à procura de componentes Calico, ignorando maiúsculas/minúsculas

kubectl kustomize --help >/dev/null
→ confirma que o Kustomize integrado no kubectl está disponível; o output é descartado

helm upgrade --help
→ mostra as opções suportadas pelo comando upgrade

grep -- '--take-ownership'
→ procura literalmente a flag; o primeiro -- termina a interpretação de opções do grep
```

## O que observar para validar

- `git`, `kubectl` e Helm existem;
- `kubectl cluster-info` responde sem erro;
- existem dois Workers `Ready` e disponíveis para scheduling;
- `local-path` existe;
- existem componentes Calico;
- `kubectl kustomize` está disponível;
- Helm suporta `--take-ownership`.

Não é necessário recolher UUIDs/UIDs das máquinas Ubuntu dos formandos.

### CHECKPOINT CP0

```text
ferramentas disponíveis
API acessível
2 Workers Ready
StorageClass local-path disponível
Calico operacional
Kustomize disponível
Helm suporta --take-ownership
```

**Não avançar** se faltar um pré-requisito crítico.

**Evidência:** preencher CP0 em `folha_evidencias.md`.

---

# CP1 — Obter os materiais e criar a baseline com Kustomize

## Objetivo

Descarregar os manifests e restantes materiais necessários e criar um estado inicial conhecido como bom.

**Executar em:** terminal administrativo.

## O que estamos a fazer e porquê

Os formandos começam com máquinas novas. Por isso, o laboratório não assume que o repositório ou o chart externo já existem localmente.

A sequência é deliberada:

```text
descarregar materiais
        ↓
validar dependências
        ↓
renderizar configuração
        ↓
aplicar
        ↓
aguardar convergência
        ↓
recolher evidência
```

## Conceitos a compreender

### Git e repositório

Git é usado aqui como mecanismo de distribuição versionada dos manifests, charts, guiões e ficheiros de apoio. O repositório é a fonte declarativa dos materiais do laboratório.

### Kustomize

**Kustomize** permite compor e modificar manifests Kubernetes sem recorrer a templates com variáveis. Trabalha normalmente com:

```text
base
 ↓
configuração reutilizável

+

overlay
 ↓
variação aplicada sobre a base
```

Neste laboratório:

- `app/base/` contém a definição comum;
- `app/overlays/normal/` representa a baseline saudável;
- outros overlays introduzem incidentes controlados.

O Kustomize é **declarativo**: descrevemos o estado pretendido e deixamos o Kubernetes reconciliar o estado real.

## 1.1. Descarregar o repositório da formação

```bash
cd ~
git clone --depth 1 https://github.com/Skullclamp/formacao-kubernetes.git
cd ~/formacao-kubernetes/sessao-07-08
```

Confirmar os materiais:

```bash
ls -1
ls -1 app/base app/overlays helm monitoring incidents
```

### Como interpretar os comandos e flags

```text
cd ~
→ muda para a home do utilizador

git clone
→ cria uma cópia local do repositório remoto

--depth 1
→ descarrega apenas o estado mais recente do histórico; reduz tempo e espaço para a formação

cd ~/formacao-kubernetes/sessao-07-08
→ entra na diretoria a partir da qual os caminhos relativos do laboratório são válidos

ls -1
→ lista um item por linha, facilitando a verificação visual dos materiais
```

## 1.2. Descarregar o chart externo validado

A versão validada para este ambiente é `kube-prometheus-stack` **91.4.1**.

```bash
chmod +x 00-precheck/precheck.sh monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1
```

Confirmar o pacote:

```bash
ls -lh packages/kube-prometheus-stack-91.4.1.tgz
helm show chart packages/kube-prometheus-stack-91.4.1.tgz
```

### Conceito: chart Helm

Um **chart Helm** é um pacote de instalação que pode conter:

```text
Chart.yaml       → metadados do chart
values.yaml      → valores por omissão
templates/       → manifests Kubernetes parametrizados
crds/            → CRDs, quando aplicável
```

O ficheiro `.tgz` é o chart empacotado. Guardá-lo localmente reduz a dependência de Internet durante a sessão.

### Como interpretar os comandos

```text
chmod +x
→ acrescenta permissão de execução aos scripts

./monitoring/prepare-chart.sh 91.4.1
→ executa o script e passa 91.4.1 como argumento de versão

ls -lh
→ mostra tamanho e metadados do ficheiro num formato legível

helm show chart <pacote>
→ lê os metadados Chart.yaml do pacote sem o instalar
```

> Se a formação decorrer sem acesso à Internet, o formador deve disponibilizar previamente o `.tgz` validado.

## 1.3. Executar o precheck completo

```bash
./00-precheck/precheck.sh
```

O script valida ferramentas, API Kubernetes, Workers, `local-path`, Calico, Kustomize, suporte Helm a `--take-ownership` e presença do chart local.

O objetivo de um precheck é transformar pré-requisitos implícitos em verificações explícitas antes do laboratório avançar.

## 1.4. Renderizar a baseline

```bash
kubectl kustomize app/overlays/normal/
```

### O que significa renderizar

Renderizar é produzir o manifesto Kubernetes final **antes** de o enviar para a API. Isto permite observar exatamente o que o Kustomize vai gerar.

```text
base + overlay
      ↓
kubectl kustomize
      ↓
YAML final
```

O comando ainda não altera o cluster.

## 1.5. Aplicar a baseline

```bash
kubectl apply -k app/overlays/normal/
```

### Como interpretar o comando

```text
kubectl apply
→ cria recursos que não existem e reconcilia recursos existentes com a definição declarativa

-k app/overlays/normal/
→ indica que a origem é uma diretoria Kustomize, não um único ficheiro YAML
```

`apply` não prova que os Pods ficaram saudáveis. Apenas prova que a API aceitou as definições.

## 1.6. Aguardar convergência

```bash
kubectl rollout status statefulset/postgres -n s78-lab --timeout=180s
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
```

### Conceitos: Deployment e StatefulSet

Um **Deployment** gere workloads normalmente stateless e os respetivos ReplicaSets/Pods. É adequado para as duas réplicas Web Symfony.

Um **StatefulSet** é usado para workloads que necessitam de identidade estável e associação previsível a storage. É usado para PostgreSQL.

### Como interpretar as flags

```text
rollout status
→ acompanha o progresso da atualização/convergência do workload

-n s78-lab
→ consulta o objeto no Namespace do laboratório

--timeout=180s
→ termina com erro se o estado esperado não for atingido em 180 segundos
```

## 1.7. Recolher evidência

```bash
kubectl get nodes -o wide
kubectl get pods -n s78-lab -o wide
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
kubectl get pvc -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

### Conceitos a observar

**PVC — PersistentVolumeClaim**  
É um pedido de armazenamento persistente. O estado `Bound` prova que o pedido foi associado a um volume.

**Service**  
Fornece um ponto de acesso estável a um conjunto dinâmico de Pods.

**EndpointSlice**  
Representa os endpoints que o Service pode utilizar. Ver o Service sem observar os EndpointSlices é insuficiente para provar que existem backends prontos.

**Events**  
Registam acontecimentos operacionais, como scheduling, pulls de imagem, falhas de probes ou mounts.

### Estado esperado

```text
postgres-0          → Running / Ready
symfony-demo Pod A  → Running / Ready / Worker 1
symfony-demo Pod B  → Running / Ready / Worker 2
PVC                 → Bound
Service             → dois endpoints prontos
```

O Deployment usa Pod Anti-Affinity obrigatória para manter as duas réplicas Web em Workers diferentes.

A estratégia de rollout é:

```yaml
maxSurge: 0
maxUnavailable: 1
```

### Porque esta estratégia foi escolhida

Com dois Workers e anti-affinity obrigatória, uma terceira réplica temporária não teria onde ser colocada.

```text
maxSurge: 0
→ não criar réplicas acima do número desejado

maxUnavailable: 1
→ permitir que uma réplica fique temporariamente indisponível durante a substituição
```

Isto permite atualizar uma réplica de cada vez sem criar um deadlock de scheduling.

### CHECKPOINT CP1

**Não avançar** enquanto PostgreSQL, Symfony, PVC e endpoints não estiverem saudáveis.

**Evidência:** preencher CP1 em `folha_evidencias.md`.

---

# CP2 — Helm, Prometheus Operator, CRDs e reconciliação

## Objetivo

Instalar a stack de monitorização através de Helm, identificar a extensão da API Kubernetes criada pelo Prometheus Operator e criar uma regra de monitorização que será usada durante os incidentes.

**Executar em:** terminal administrativo, dentro de `sessao-07-08/`.

## O que estamos a fazer e porquê

Este checkpoint liga três conceitos da Sessão 8:

```text
Helm
 ↓
instala e gere uma release complexa

CRDs
 ↓
estendem a API Kubernetes

Operator
 ↓
observa Custom Resources e reconcilia recursos
```

## Conceitos a compreender

### O que é Helm e para que serve

Helm é um gestor de aplicações para Kubernetes. Em vez de aplicar dezenas de manifests individualmente, podemos instalar um **chart** parametrizado.

Termos essenciais:

```text
Chart
→ pacote reutilizável com templates, valores e metadados

Values
→ configuração fornecida ao chart

Release
→ instância instalada de um chart num cluster

Revision
→ versão histórica dessa release após install/upgrade/rollback
```

Helm é útil para:

- instalar aplicações compostas por muitos recursos;
- parametrizar a mesma aplicação para ambientes diferentes;
- manter histórico de alterações;
- executar upgrades;
- executar rollbacks.

### O que é um CRD

Um **CustomResourceDefinition (CRD)** estende a API Kubernetes com um novo tipo de objeto.

Kubernetes conhece nativamente tipos como:

```text
Pod
Deployment
Service
ConfigMap
Secret
```

Depois de instalar determinados CRDs do Prometheus Operator, a API passa também a compreender tipos como:

```text
Prometheus
ServiceMonitor
PrometheusRule
Alertmanager
```

### O que é um Custom Resource

Um **Custom Resource (CR)** é uma instância de um tipo definido por um CRD.

```text
CRD PrometheusRule
        ↓
define o tipo
        ↓
PrometheusRule s78-lab-rules
        ↓
é uma instância desse tipo
```

### O que é um Controller/Operator

Um **Controller** observa o estado desejado na API e tenta aproximar o estado real desse estado desejado.

Um **Operator** é um Controller que incorpora lógica operacional específica de uma aplicação ou domínio.

No nosso caso:

```text
Prometheus CR
      ↓
Prometheus Operator observa
      ↓
reconcilia recursos necessários
      ↓
StatefulSet / Pods / configuração
```

## 2.1. Instalar a release de monitorização

```bash
helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
```

### Como interpretar o comando e flags

```text
helm upgrade --install
→ se a release existir, faz upgrade; se não existir, instala

monitoring
→ nome da release

packages/kube-prometheus-stack-91.4.1.tgz
→ chart local a instalar

--namespace monitoring
→ instala os recursos namespaced nesse Namespace

--create-namespace
→ cria o Namespace monitoring se ainda não existir

-f monitoring/values-lab.yaml
→ aplica os valores específicos deste laboratório

--wait
→ espera pelas condições de prontidão que o Helm verifica para os recursos criados

--timeout 10m
→ limita a espera a 10 minutos
```

## 2.2. Confirmar a release e os CRDs

```bash
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get prometheus -A
```

### Como interpretar

```text
helm list -n monitoring
→ lista releases Helm instaladas no Namespace monitoring

kubectl get crd
→ lista CustomResourceDefinitions; CRDs são cluster-scoped

grep monitoring.coreos.com
→ filtra os CRDs pertencentes à API do Prometheus Operator

kubectl get prometheus -A
→ consulta Custom Resources do tipo Prometheus em todos os Namespaces
```

## 2.3. Identificar a cadeia de reconciliação

```bash
kubectl get prometheus -n monitoring
kubectl get statefulset -n monitoring
kubectl get pods -n monitoring
```

O formando deve conseguir relacionar:

```text
CRD
 ↓
define novo tipo na API
 ↓
Prometheus Custom Resource
 ↓
Operator / Controller
 ↓
StatefulSet e Pods reconciliados
```

## 2.4. Criar o PrometheusRule pedagógico

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
kubectl describe prometheusrule s78-lab-rules -n monitoring
```

### O que estamos a criar

`PrometheusRule` é um Custom Resource. Neste laboratório contém uma regra que usa uma métrica de `kube-state-metrics` para detetar réplicas indisponíveis do Deployment Symfony.

A label:

```yaml
release: monitoring
```

é importante porque a instância Prometheus foi configurada para selecionar regras com essa label.

### `get` vs `describe`

```text
kubectl get
→ mostra estado resumido e campos principais

kubectl describe
→ mostra uma visão operacional mais detalhada, incluindo Events quando aplicável
```

### CHECKPOINT CP2

Confirmar:

```text
release monitoring instalada
Pods de monitorização Running
CRDs monitoring.coreos.com presentes
Prometheus CR existente
PrometheusRule aceite pela API
cadeia CR → Operator → recursos identificada
```

**Evidência:** preencher CP2 em `folha_evidencias.md`.

---

# CP3 — Incidente 1: rollout bloqueado por readiness

## Objetivo

Diagnosticar uma nova réplica que está `Running` mas não está `Ready`, provar o impacto no rollout e recuperar através da configuração declarativa correta.

**Preparação da falha:** executada pelo formador.

```bash
kubectl apply -k app/overlays/incident-probe/
```

Entregar aos formandos:

```text
incidents/01-probe.md
```

> Durante o diagnóstico, não abrir antecipadamente o patch do incidente. A causa deve ser obtida através da evidência do cluster.

## Conceitos a compreender

### `Running` não significa `Ready`

O estado `Running` indica que o container/processo está em execução. `Ready` indica que o Pod passou a condição de prontidão e pode receber tráfego através de Services.

```text
processo executa
      ↓
Running

readiness probe passa
      ↓
Ready
      ↓
pode entrar nos endpoints do Service
```

### Readiness probe

A readiness probe responde à pergunta:

> “Este Pod está pronto para receber tráfego agora?”

Quando falha, Kubernetes pode manter o container em execução, mas remove ou não adiciona esse Pod aos endpoints elegíveis do Service.

### Rollout

Um rollout é o processo de substituir progressivamente uma versão de Pods por outra. A readiness influencia o rollout porque uma nova réplica que nunca fica `Ready` impede a convergência completa.

## Sintoma esperado

```text
réplica anterior → Running / Ready
nova réplica     → Running / NotReady
```

## 3.1. Recolher evidência inicial

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

### O que observar

- número de réplicas `READY`, `UP-TO-DATE` e `AVAILABLE`;
- qual é o Pod novo;
- em que Node está cada Pod;
- que endpoints estão `ready=true` ou `ready=false`;
- Events relacionados com probes ou rollout.

## 3.2. Aprofundar o diagnóstico

Quando a hipótese justificar:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl logs <NOVO_POD> -n s78-lab
```

### Como interpretar

```text
kubectl describe pod
→ mostra estado dos containers, probes, condições, scheduling e Events do Pod

kubectl logs
→ mostra stdout/stderr da aplicação; é útil para distinguir falha da aplicação de falha de probe/configuração
```

Nem todos os problemas aparecem nos logs da aplicação. Uma probe pode estar mal configurada mesmo quando a aplicação funciona corretamente.

## 3.3. Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get pods -n s78-lab
kubectl get endpointslices -n s78-lab
```

### O que prova a recuperação

Não basta o `apply` terminar sem erro. É necessário observar:

```text
Deployment 2/2
2 Pods Ready
2 endpoints ready=true
```

### CHECKPOINT CP3

Mensagem-chave:

```text
Running ≠ Ready

readiness
  ↓
protege o tráfego
  +
protege o rollout
```

**Evidência:** preencher CP3 em `folha_evidencias.md` usando o método Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação.

---

# CP4 — Incidente 2: Service sem endpoints

## Objetivo

Diagnosticar um Service que existe mas não dispõe de backends utilizáveis.

**Preparação da falha:** executada pelo formador.

```bash
kubectl apply -k app/overlays/incident-service/
```

Entregar aos formandos:

```text
incidents/02-service.md
```

> Não abrir antecipadamente o patch do incidente. O objetivo é chegar à causa pela relação entre Service, selectors, labels e EndpointSlices.

## Conceitos a compreender

### Service

Um Service fornece um endereço virtual estável e seleciona Pods através de labels.

```text
Service selector
      ↓
labels dos Pods
      ↓
Pods selecionados
      ↓
EndpointSlices
      ↓
tráfego para backends
```

Um Service pode existir perfeitamente na API e, ainda assim, não ter qualquer backend.

### Labels e selectors

**Labels** são pares chave/valor associados a objetos.  
**Selectors** são critérios usados para escolher objetos com determinadas labels.

Se o selector do Service não corresponder às labels dos Pods, os Pods não entram nos EndpointSlices desse Service.

### EndpointSlice

EndpointSlice é a representação operacional dos endpoints de rede associados a um Service. É uma das melhores evidências para responder:

> “Para onde pode este Service enviar tráfego neste momento?”

## Sintoma esperado

```text
Pods    → Running / Ready
Service → existe
backends → ausentes
```

## 4.1. Diagnóstico

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab
```

### Como interpretar os comandos e flags

```text
--show-labels
→ mostra as labels dos Pods diretamente na tabela

-o yaml
→ permite inspecionar o selector real do Service registado na API

kubectl get endpointslices
→ mostra se existem endpoints associados ao Service
```

### Estratégia de diagnóstico

Não assumir imediatamente falha de CNI, DNS ou aplicação. Primeiro provar a cadeia mais direta:

```text
selector do Service
      ?
labels dos Pods
      ?
EndpointSlice
```

## 4.2. Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get endpointslices -n s78-lab
```

### CHECKPOINT CP4

Mensagem-chave:

```text
Service existente ≠ Service com backends
```

A correção só está validada quando os endpoints voltam a aparecer.

**Evidência:** preencher CP4 em `folha_evidencias.md`.

---

# CP5 — Incidente 3: Worker `NotReady`

## Objetivo

Observar como Kubernetes reage à perda de um Worker, distinguir estado de Pod de disponibilidade real e perceber o efeito de taints, tolerations, eviction e anti-affinity.

> Num cluster partilhado, a ação disruptiva é executada exclusivamente pelo formador.

## Conceitos a compreender

### Kubelet

O **kubelet** é o agente Kubernetes executado em cada Node. Entre outras responsabilidades, mantém comunicação com o Control Plane e reporta estado do Node e dos Pods.

Quando o kubelet deixa de reportar, o Control Plane deixa de conseguir confirmar o estado atual desse Node.

### `NotReady`

Um Node `NotReady` significa que Kubernetes deixou de o considerar saudável para operação normal. A mudança não é necessariamente instantânea; depende dos mecanismos de deteção e tolerância configurados.

### Taints e tolerations

Um **taint** aplicado a um Node pode impedir scheduling ou provocar eviction de Pods que não tenham uma toleration correspondente.

Em falhas de Node, Kubernetes pode aplicar taints como:

```text
node.kubernetes.io/not-ready
node.kubernetes.io/unreachable
```

Os Pods têm normalmente tolerations temporárias para estas condições, razão pela qual a eviction não ocorre imediatamente.

### Pod Anti-Affinity

Neste laboratório, a anti-affinity é obrigatória por hostname. Isto impede as duas réplicas Symfony de correrem no mesmo Worker.

É uma excelente demonstração de que:

```text
réplicas desejadas
      ≠
capacidade real disponível
```

## 5.1. Health gate antes da falha

```bash
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab
```

### Como interpretar a flag `-l`

```text
-l app=symfony-demo
→ devolve apenas Pods cuja label app tenha o valor symfony-demo
```

Escolher o Worker que contém uma réplica Symfony mas **não** contém `postgres-0`. Isto mantém o incidente focado na camada Web e evita introduzir desnecessariamente uma falha do volume local da base de dados.

## 5.2. Provocar a falha

No Worker selecionado, o formador executa:

```bash
sudo systemctl stop kubelet
```

### Como interpretar

```text
sudo
→ executa o comando com privilégios administrativos

systemctl stop kubelet
→ para o serviço kubelet no Node; não desliga o Node nem o containerd
```

Parar o kubelet não significa que os containers desapareçam imediatamente. O runtime pode continuar a executar containers existentes enquanto o Control Plane perde visibilidade/controlo atualizado sobre o Node.

## 5.3. Observar a transição

```bash
kubectl get nodes -w
```

Noutro terminal:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -A --sort-by=.lastTimestamp
```

### Como interpretar as flags

```text
-w
→ mantém o comando aberto e mostra alterações à medida que chegam

-A
→ consulta Events de todos os Namespaces

--sort-by=.lastTimestamp
→ ordena Events pelo instante do último registo
```

### O que observar

Registar tempos reais, não assumir valores fixos:

```text
kubelet parado
   ↓
Node passa a NotReady
   ↓
endpoint do Node afetado deixa de estar ready
   ↓
após toleration/eviction, Pod é marcado para remoção
   ↓
Deployment tenta criar substituição
   ↓
scheduling pode falhar por anti-affinity/capacidade
```

Com apenas um Worker saudável e anti-affinity obrigatória, é possível observar:

```text
1 réplica funcional
+
1 réplica indisponível/Pending
```

Isto não significa que o controlador deixou de reconciliar. Significa que **não existe um destino elegível** para satisfazer o estado desejado.

## 5.4. Recuperar

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

### O que prova a recuperação

```text
Worker volta a Ready
Deployment converge para 2/2
réplicas voltam a Workers diferentes
Service volta a dois endpoints prontos
```

### CHECKPOINT CP5

O formando deve conseguir explicar:

```text
resiliência do workload ≠ HA do Control Plane ≠ backup/recuperação de dados
```

**Evidência:** preencher CP5 em `folha_evidencias.md`.

---

# CP6 — Control Plane, `etcd`, Alta Disponibilidade e recuperação

## Objetivo

Relacionar a falha de Worker observada no CP5 com a arquitetura do Control Plane e distinguir claramente disponibilidade, redundância, backup e recuperação.

**Executar em:** terminal administrativo.

## Conceitos a compreender

### Control Plane

O Control Plane toma decisões e mantém o estado de controlo do cluster. Os principais componentes são:

```text
kube-apiserver
→ ponto de entrada da API Kubernetes

kube-controller-manager
→ executa controllers que reconciliam estado desejado e real

kube-scheduler
→ escolhe Nodes para novos Pods

etcd
→ base de dados distribuída onde o Kubernetes guarda o estado do cluster
```

### `etcd`

`etcd` é uma base de dados chave/valor distribuída e consistente usada pelo Kubernetes para persistir o estado da API.

Sem `etcd`, o Control Plane perde a fonte persistente do estado do cluster.

### Alta Disponibilidade

Alta Disponibilidade procura reduzir pontos únicos de falha através de redundância.

```text
2 Pods Web em 2 Workers
→ resiliência do workload

vários Control Planes + etcd redundante
→ arquitetura de HA do Control Plane
```

O nosso cluster tem apenas **um** Control Plane. Logo, não possui HA real do Control Plane.

### HA não é backup

```text
redundância
→ ajuda a continuar a operar perante falha de um membro

snapshot/backup
→ fornece um ponto de recuperação do estado/dados
```

Um sistema pode estar redundante e replicar rapidamente uma corrupção. Por isso, redundância não substitui backup.

## 6.1. Identificar os componentes

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -o wide | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'
```

### Como interpretar

```text
-n kube-system
→ consulta o Namespace que contém muitos componentes internos do cluster

-o wide
→ mostra, entre outros dados, o Node onde cada Pod executa

grep -E
→ ativa expressões regulares estendidas; o símbolo | significa alternativa
```

O formando deve identificar que os componentes do Control Plane executam no único Control Plane existente.

## 6.2. Consolidar a diferença entre continuidade e recuperação

```text
redundância de etcd → disponibilidade
snapshot de etcd    → ponto de recuperação
```

> Não parar o único Control Plane nem executar restore de `etcd` no cluster principal durante este laboratório.

### CHECKPOINT CP6

O formando deve conseguir responder:

- Porque é que duas réplicas Web não tornam o Control Plane altamente disponível?
- Porque é que três membros `etcd` não substituem snapshots?
- Que componente recebe os pedidos `kubectl`?
- Que componente agenda novos Pods?
- Onde é persistido o estado do cluster?

**Evidência:** preencher CP6 em `folha_evidencias.md`.

---

# CP7 — Transição controlada de Kustomize para Helm

## Objetivo

Transferir a gestão do Deployment e Service Symfony de uma baseline aplicada com Kustomize para uma release Helm, sem apagar os objetos existentes e sem criar uma interrupção artificial.

**Executar em:** terminal administrativo, dentro de `sessao-07-08/`.

## O que estamos a fazer e porquê

Kustomize e Helm podem produzir manifests Kubernetes, mas usam modelos de gestão diferentes.

```text
Kustomize
→ compõe YAML declarativo

Helm
→ renderiza templates + values e mantém uma release com histórico
```

Neste exercício não queremos que dois mecanismos diferentes sejam tratados como gestores concorrentes do mesmo objeto. Por isso, fazemos uma transição explícita de ownership.

## Conceitos a compreender

### Release Helm

Uma **release** é a instalação gerida pelo Helm. A release guarda histórico de revisões e permite upgrades e rollbacks.

### Ownership Helm

Helm usa labels e annotations para identificar os recursos que pertencem a uma release, incluindo metadados como:

```text
app.kubernetes.io/managed-by=Helm
meta.helm.sh/release-name
meta.helm.sh/release-namespace
```

### Porque não apagamos o Deployment e o Service

Apagar os objetos e voltar a criá-los funcionaria, mas introduziria uma interrupção desnecessária e esconderia um problema operacional importante: como adotar objetos existentes de forma controlada.

O procedimento validado é:

```text
renderizar
   ↓
comparar
   ↓
confirmar ausência de mudanças perigosas
   ↓
transferir ownership
   ↓
validar rollout e endpoints
```

## 7.1. Renderizar a baseline Helm

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml
```

### Como interpretar o comando e flags

```text
helm template
→ renderiza os templates localmente; não cria uma release nem altera o cluster

symfony-lab
→ nome de release usado durante a renderização

./helm/app-lab
→ diretoria do chart local

-n s78-lab
→ define o Namespace usado na renderização

-f helm/values/values-good.yaml
→ sobrepõe valores do chart com a baseline conhecida como boa

> /tmp/symfony-good.yaml
→ redireciona stdout para um ficheiro temporário
```

## 7.2. Comparar com o estado atual

```bash
kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

### Conceito: diff declarativo

`kubectl diff` compara o estado atual do cluster com o manifesto que seria aplicado.

Antes da adoção, confirmar que não surgem alterações inesperadas em:

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

É esperado aparecerem labels de Helm e a label `app.kubernetes.io/instance` no Pod template.

### Porque usar `|| true`

`kubectl diff` devolve um código de saída diferente de zero quando existem diferenças. Neste contexto isso é esperado e não significa necessariamente erro. `|| true` evita interromper uma sequência de comandos apenas porque existem diferenças a analisar.

## 7.3. Transferir ownership para Helm

```bash
helm upgrade --install symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  --take-ownership \
  --wait \
  --timeout 5m
```

### Como interpretar as flags

```text
upgrade --install
→ instala se a release não existir; faz upgrade se já existir

--take-ownership
→ ignora a verificação de ownership Helm existente e permite que a release passe a gerir os objetos compatíveis já existentes

--wait
→ espera por condições mínimas de prontidão segundo o Helm

--timeout 5m
→ limita a espera a cinco minutos
```

> Mesmo com `--wait`, fazemos depois `kubectl rollout status`. Helm e Kubernetes não respondem exatamente à mesma pergunta operacional; queremos provar a convergência completa do Deployment.

## 7.4. Validar a baseline Helm

```bash
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

### `helm list` vs `helm history`

```text
helm list
→ mostra o estado atual das releases

helm history
→ mostra as revisões históricas de uma release específica
```

Confirmar ownership:

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"  release="}{.metadata.annotations.meta\.helm\.sh/release-name}{"  namespace="}{.metadata.annotations.meta\.helm\.sh/release-namespace}{"\n"}'
```

### Conceito: JSONPath

JSONPath permite extrair apenas os campos relevantes de um objeto devolvido pela API, evitando ler todo o YAML.

Resultado esperado:

```text
managed-by=Helm  release=symfony-lab  namespace=s78-lab
```

### CHECKPOINT CP7

Não avançar para a release defeituosa enquanto não existir:

```text
release symfony-lab deployed
Deployment 2/2
2 Pods Ready
2 endpoints prontos
ownership Helm confirmado
```

**Evidência:** preencher CP7 em `folha_evidencias.md`.

---

# CP8 — Incidente 4: release Helm defeituosa e rollback

## Objetivo

Aplicar uma release candidata defeituosa, diagnosticar a falha sem consultar previamente a causa, preservar a evidência histórica e recuperar através de `helm rollback`.

Entregar aos formandos:

```text
incidents/04-release.md
```

> Não abrir previamente `values-broken.yaml`. A causa deve ser descoberta a partir do comportamento da release e do cluster.

## Conceitos a compreender

### Upgrade Helm

`helm upgrade` renderiza novamente o chart com os valores indicados e tenta reconciliar os recursos geridos pela release.

Cada alteração bem sucedida ou tentativa registada pode gerar uma nova **revision** no histórico.

### Revisão

Uma revisão representa um estado histórico da release. O histórico permite saber:

```text
que estado foi aplicado
quando
com que resultado
```

### Rollback

`helm rollback` reaplica o estado de uma revisão anterior, mas cria **uma nova revisão**. Não apaga a revisão falhada.

Isto é importante para auditabilidade:

```text
rev. boa
   ↓
rev. defeituosa / failed
   ↓
rollback
   ↓
nova rev. deployed com estado recuperado
```

## 8.1. Aplicar a candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

### Como interpretar

```text
helm upgrade symfony-lab
→ atualiza a release existente

-f values-broken.yaml
→ usa um conjunto de valores candidato diferente da baseline conhecida como boa

--wait --timeout 90s
→ espera convergência até ao limite de 90 segundos
```

O comando é esperado falhar no exercício. A falha do comando é o **sintoma inicial**, não a causa raiz.

## 8.2. Diagnosticar

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
kubectl describe pod <NOVO_POD> -n s78-lab
```

### O que cada comando responde

```text
helm status
→ qual é o estado atual da release?

helm history
→ que revisão anterior era conhecida como boa e o que aconteceu à candidata?

kubectl get deployment
→ o rollout convergiu? quantas réplicas estão Ready/Available?

kubectl get pods
→ que Pod está degradado e em que estado?

kubectl get endpointslices
→ o Service ainda dispõe de pelo menos um backend utilizável?

kubectl get events
→ que eventos operacionais explicam a falha?

kubectl describe pod
→ qual é a causa operacional específica observada no novo Pod?
```

Aplicar sempre:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz
```

### Porque não editar manualmente o Deployment

Se a release é gerida por Helm, uma alteração manual cria **configuration drift**:

```text
estado no cluster
      ≠
estado conhecido pela release Helm
```

O exercício pretende recuperar através do mecanismo que gere a aplicação, preservando histórico e coerência declarativa.

## 8.3. Identificar a revisão boa

```bash
helm history symfony-lab -n s78-lab
```

Não assumir que a revisão boa é sempre `1`. Identificá-la pelo histórico observado.

## 8.4. Executar rollback

```bash
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait --timeout 3m
```

### Como interpretar

```text
helm rollback symfony-lab <REVISAO_BOA>
→ cria uma nova revisão cujo estado deriva da revisão indicada

--wait
→ aguarda condições de prontidão suportadas pelo Helm

--timeout 3m
→ limita a operação a três minutos
```

## 8.5. Validar recuperação

```bash
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

### Estado esperado

```text
revisão defeituosa permanece no histórico
nova revisão de rollback = deployed
Deployment 2/2
2 Pods Ready
2 endpoints prontos
```

### CHECKPOINT CP8

Mensagem-chave:

```text
rollback restaura o estado de uma revisão anterior
mas cria uma nova revisão no histórico
```

**Evidência:** preencher CP8 em `folha_evidencias.md`.

---

# CP9 — Alterar um Custom Resource e provar reconciliação

## Objetivo

Alterar um `PrometheusRule` e provar não apenas que a API Kubernetes aceitou a alteração, mas também que o sistema gerido pelo Operator recebeu e carregou o novo estado.

**Executar em:** terminal administrativo.

## Conceitos a compreender

### Estado desejado e reconciliação

Quando alteramos um Custom Resource, estamos a mudar **estado desejado** na API.

```text
Custom Resource alterado
        ↓
API guarda novo estado desejado
        ↓
Controller/Operator observa
        ↓
reconcilia
        ↓
sistema gerido aproxima-se do novo estado
```

### `generation`

`metadata.generation` aumenta quando a especificação desejada do recurso muda. É útil para provar que houve uma nova versão declarativa da configuração.

### `resourceVersion`

`metadata.resourceVersion` identifica uma versão interna do objeto no armazenamento Kubernetes. Pode mudar em atualizações do objeto e é usada pela API para controlo de concorrência/watch.

Não confundir:

```text
generation
→ versão lógica da configuração desejada

resourceVersion
→ versão interna do objeto na API
```

## 9.1. Criar uma cópia temporária da regra

```bash
cp monitoring/prometheus-rule.yaml /tmp/prometheus-rule-reconcile.yaml

sed -i \
  's/Existem réplicas indisponíveis no Deployment symfony-demo/Reconciliação observada: existem réplicas indisponíveis no Deployment symfony-demo/' \
  /tmp/prometheus-rule-reconcile.yaml
```

### Como interpretar

```text
cp origem destino
→ cria uma cópia para não alterar o ficheiro original do repositório

sed -i
→ altera o ficheiro diretamente in-place

s/texto_antigo/texto_novo/
→ substitui a primeira ocorrência correspondente em cada linha
```

## 9.2. Registar versão antes e depois

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'

kubectl apply -f /tmp/prometheus-rule-reconcile.yaml

kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation} resourceVersion={.metadata.resourceVersion}{"\n"}'
```

### O que isto prova

Se a `generation` aumentar, provamos que o estado desejado do Custom Resource foi alterado na API.

Ainda não provámos que o Prometheus carregou essa alteração.

## 9.3. Provar a reconciliação no sistema gerido

Num terminal:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

### Conceito: port-forward

`kubectl port-forward` cria um túnel temporário entre uma porta local e uma porta de um recurso no cluster.

```text
127.0.0.1:9090
      ↓
kubectl
      ↓
Service Prometheus:9090
```

O terminal deve permanecer aberto enquanto o túnel estiver ativo.

Noutro terminal **da mesma máquina**:

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

### Como interpretar os comandos e flags

```text
curl
→ efetua um pedido HTTP à API do Prometheus

-sS
→ modo silencioso, mas continua a mostrar erros

|
→ envia o stdout do comando da esquerda para stdin do comando da direita

python3 -c '...'
→ executa um pequeno programa Python fornecido diretamente na linha de comandos
```

O Python percorre a resposta JSON da API, procura a regra `SymfonyDeploymentUnavailable` e imprime apenas os campos relevantes.

### O que observar

A nova `summary` deve aparecer na API do Prometheus.

Se a aplicação estiver saudável:

```text
state = inactive
```

é esperado. Significa:

```text
regra carregada
+
expressão atualmente falsa
```

`inactive` não significa que a regra esteja ausente ou avariada.

## 9.4. Repor a regra original

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
```

### CHECKPOINT CP9

O formando deve conseguir provar a cadeia completa:

```text
CRD
 ↓
Custom Resource alterado
 ↓
generation aumenta
 ↓
Operator / Controller observa
 ↓
reconciliação
 ↓
Prometheus carrega a nova configuração
 ↓
API /api/v1/rules mostra a nova summary
```

**Evidência:** preencher CP9 em `folha_evidencias.md`.

---

# Síntese final

No final do laboratório, o formando deverá conseguir explicar, com evidência real do cluster:

```text
Running ≠ Ready

Service existente ≠ Service com backends

estado desejado ≠ garantia imediata de convergência

resiliência do workload ≠ HA do Control Plane

HA ≠ Backup / Recuperação

Chart ≠ Release ≠ Revision

CRD ≠ Custom Resource

Custom Resource + Controller/Operator → reconciliação

release defeituosa → diagnóstico → rollback → validação
```

## Relações essenciais da Sessão 8

```text
Kustomize
→ compõe manifests declarativos

Helm
→ empacota, parametriza e gere releases com histórico

CRD
→ estende a API com um novo tipo

Custom Resource
→ instância desse tipo

Controller / Operator
→ observa e reconcilia
```

## Regra final da sessão

```text
Sem evidência não há validação.
Sem causa raiz não há troubleshooting concluído.
Sem validação após a correção não há recuperação demonstrada.
```

---

# Limpeza

## Objetivo

Remover os recursos do laboratório quando já não forem necessários, preservando deliberadamente CRDs que possam ser partilhados por outros componentes.

```bash
helm uninstall symfony-lab -n s78-lab || true
helm uninstall monitoring -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace s78-lab --ignore-not-found
```

### Como interpretar

```text
helm uninstall
→ remove uma release e os recursos que o Helm gere para essa release

|| true
→ permite continuar a limpeza se a release já não existir

kubectl delete namespace
→ elimina o Namespace e os recursos namespaced que contém

--ignore-not-found
→ não trata a ausência do objeto como erro
```

As CRDs instaladas pelo chart podem permanecer após a remoção da release porque são recursos **cluster-scoped** e podem ser usados por outras instâncias. Não as remover automaticamente sem confirmar que não existem dependências.

---

# Material do formador

A resolução técnica e os resultados esperados encontram-se em:

```text
solutions/SOLUCOES-FORMADOR.md
```

Como o repositório é público, esta separação é apenas pedagógica; não constitui controlo de acesso técnico.