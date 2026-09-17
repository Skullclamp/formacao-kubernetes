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
OUTPUT / ESTADO ESPERADO
        ↓
O QUE OBSERVAR
        ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
        ↓
EVIDÊNCIA
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

O CP8 depende da existência da CRD `PrometheusRule`, do Prometheus Operator e da instância Prometheus. Se esta preparação falhar, o exercício de reconciliação deixa de ser executável.

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
| `./monitoring/prepare-chart.sh 91.4.1` | prepara a versão de chart usada neste laboratório |
| `helm upgrade --install` | instala a release se não existir ou atualiza-a se já existir |
| `monitoring` | nome da release Helm |
| `--namespace monitoring` | coloca a release no Namespace `monitoring` |
| `--create-namespace` | cria o Namespace se ainda não existir |
| `-f monitoring/values-lab.yaml` | aplica os valores específicos do laboratório |
| `--wait` | espera pelas condições de disponibilidade conhecidas pelo Helm |
| `--timeout 10m` | limita a espera a dez minutos |

Validar:

```bash
helm status monitoring -n monitoring
kubectl get pods -n monitoring
kubectl get crd prometheusrules.monitoring.coreos.com
```

### O que observar

- release `monitoring` em estado `deployed`;
- Pods da stack de monitorização operacionais;
- CRD `prometheusrules.monitoring.coreos.com` registada na API.

### Checkpoint

**Não avançar para a formação** sem a stack preparada.

> Se o sistema operativo indicar que é necessário reiniciar algum Node, tratar essa manutenção **antes da formação**, numa janela controlada. Num cluster com apenas um Control Plane, não reiniciar o Control Plane durante o laboratório.

---

# CP0 — Enquadramento, materiais e precheck

## O que estamos a fazer

Confirmar que o cluster e as ferramentas necessárias estão disponíveis e criar uma baseline saudável da aplicação.

## Porque é necessário

Um incidente só é pedagogicamente útil se partir de um estado conhecido como bom. Sem baseline, um sintoma observado pode ser consequência de uma falha anterior e não do incidente que estamos a estudar.

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

### Explicação

| Elemento | Significado |
|---|---|
| `git clone --depth 1` | obtém apenas o estado mais recente do repositório, suficiente para o laboratório |
| `git pull --ff-only` | atualiza o clone sem criar merges automáticos locais |
| `bash 00-precheck/precheck.sh` | executa o script de validação do ambiente |

> `set -euo pipefail` pode existir dentro de scripts para controlo de erros. **Não o ativar manualmente no shell interativo do laboratório**, porque alguns comandos são pedagogicamente esperados falhar durante os incidentes.

O precheck confirma, entre outros pontos:

- API Kubernetes acessível;
- pelo menos 2 Workers `Ready`;
- StorageClass `local-path`;
- Calico operacional;
- Kustomize integrado no `kubectl`;
- Helm com suporte a `--take-ownership`;
- Prometheus Operator previamente preparado.

## 2. Renderizar a baseline

```bash
kubectl kustomize app/overlays/normal/
```

### O que este comando faz

`kubectl kustomize` **renderiza** os manifests resultantes da base e do overlay. Não altera o cluster.

Isto permite responder antes de aplicar:

```text
Que objetos vão ser criados?
Que valores finais terão?
Existe alguma alteração inesperada?
```

## 3. Aplicar a baseline

```bash
kubectl apply -k app/overlays/normal/

kubectl rollout status statefulset/postgres \
  -n s78-lab --timeout=180s

kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
```

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `kubectl apply -k` | renderiza a configuração Kustomize e envia o estado desejado para a API |
| `rollout status` | acompanha a convergência do recurso |
| `statefulset/postgres` | recurso stateful da base de dados |
| `deployment/symfony-demo` | Deployment da aplicação Web |
| `-n s78-lab` | limita a operação ao Namespace da aplicação |
| `--timeout=180s` | evita esperar indefinidamente |

## 4. Recolher evidência

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get pvc -n s78-lab
kubectl get svc -n s78-lab
kubectl get endpointslices -n s78-lab
```

### Flags importantes

| Flag | Significado |
|---|---|
| `-n s78-lab` | consulta apenas o Namespace da aplicação |
| `-o wide` | mostra informação adicional, incluindo IP e Node onde o Pod corre |

### Estado esperado

```text
postgres-0       → Running / Ready
PVC              → Bound
Symfony          → Deployment 2/2
réplicas Web     → Workers diferentes
Service          → backends disponíveis
```

### Checkpoint — não avançar sem validar

A turma deve conseguir explicar:

- porque PostgreSQL é StatefulSet e a aplicação Web é Deployment;
- porque `Running` não é suficiente para concluir que um Pod está pronto;
- como o Service chega aos Pods através de endpoints;
- em que Workers estão as duas réplicas Symfony.

---

# CP1 — HA, recuperação e método de troubleshooting

## O que estamos a fazer

Construir o modelo mental que será usado durante todos os incidentes.

## Porque é necessário

Sem distinguir níveis de disponibilidade, é fácil concluir incorretamente que duas réplicas de uma aplicação significam que o cluster inteiro está em HA.

## Conceitos abordados

### 1. Disponibilidade da aplicação

Uma aplicação pode continuar a responder mesmo quando perde uma réplica.

### 2. Disponibilidade do Node

Um Worker pode ficar indisponível sem que o Control Plane deixe de funcionar.

### 3. Disponibilidade do Control Plane

O cluster deste laboratório possui apenas **um** Control Plane. Logo, existe um ponto único de falha ao nível do plano de controlo.

### 4. Recuperação de dados

HA não substitui backup. Réplicas, persistência e backup resolvem problemas diferentes.

Consolidar:

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

## Método operacional

Em todos os incidentes:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

### O formador deve reforçar

- **Sintoma** não é automaticamente a causa;
- um Event antigo ou transitório pode não ser a causa raiz;
- corrigir sem validar não demonstra recuperação;
- um comando ter terminado sem erro não prova que o serviço está saudável.

---

# CP2 — Dois incidentes Kubernetes

# Incidente A — `Running ≠ Ready`

## O que estamos a fazer

Introduzir uma readiness probe incorreta durante um rollout e observar a diferença entre o processo estar em execução e o Pod estar pronto para receber tráfego.

## Porque é necessário

Este incidente demonstra uma das distinções mais importantes em operação Kubernetes:

```text
Running ≠ Ready
```

## Conceitos abordados

- `readinessProbe`;
- condição `Ready` do Pod;
- rollout de Deployment;
- EndpointSlice e condição `ready`;
- anti-affinity;
- Events;
- diferença entre sintoma transitório e causa raiz persistente.

## Onde executar

Comandos Kubernetes no **Control Plane**.

## 1. Introduzir a falha controlada

```bash
kubectl apply -k app/overlays/incident-probe/
```

### O que está a acontecer

O overlay altera a readiness probe para um endpoint inexistente. O container pode continuar a executar, mas Kubernetes deixa de considerar a nova réplica pronta.

## 2. Observar o rollout

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
```

### Explicação

| Comando / flag | O que permite observar |
|---|---|
| `get deployment` | READY, UP-TO-DATE e AVAILABLE do Deployment |
| `get pods -o wide` | estado, readiness, IP e Worker de cada Pod |
| `get events` | acontecimentos registados pelos componentes Kubernetes |
| `--sort-by=.metadata.creationTimestamp` | ordena Events cronologicamente |

## 3. Aprofundar o Pod novo

```bash
kubectl describe pod <POD> -n s78-lab
kubectl logs <POD> -n s78-lab

kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `kubectl describe pod` | apresenta condições, probes, estado do container e Events associados ao Pod |
| `kubectl logs` | mostra o output do processo dentro do container |
| `-l kubernetes.io/service-name=symfony-demo` | filtra EndpointSlices pertencentes ao Service `symfony-demo` |
| `-o yaml` | mostra todos os campos necessários para interpretar `conditions.ready`, `serving` e `terminating` |

## Estado esperado

- novo Pod `Running`, mas `Ready=False`;
- readiness em `/ready-inexistente` com HTTP `404`;
- Deployment sem convergir para `2/2`;
- réplica saudável mantém `ready: true`;
- réplica não pronta pode continuar representada no EndpointSlice com `ready: false` e `serving: false`.

> **Atenção:** presença no EndpointSlice não significa que o endpoint esteja Ready/elegível para tráfego normal.

Pode surgir temporariamente `FailedScheduling` por anti-affinity durante o rollout. Se o Pod for posteriormente agendado e a readiness continuar a falhar, esse Event de scheduling **não** é a causa raiz.

## Perguntas orientadoras

- O container está em execução?
- O Pod está Ready?
- Que probe está a falhar?
- Que código HTTP é devolvido?
- O Pod aparece no EndpointSlice?
- Qual é o valor de `conditions.ready`?
- Que evidência identifica a causa raiz?

## 4. Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s

kubectl get deployment symfony-demo -n s78-lab
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Checkpoint — não avançar sem validar

```text
Deployment → 2/2
2 Pods     → Ready
2 endpoints → ready=true
```

### Evidência a registar

```text
Sintoma    → Pod Running mas NotReady
Evidência  → readiness HTTP 404 + endpoint ready=false
Causa      → readiness path incorreto
Correção   → restaurar overlay normal
Validação  → Deployment 2/2 + dois endpoints ready=true
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

## 2. Observar

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `--show-labels` | mostra as labels dos Pods, permitindo compará-las com o selector |
| `get svc ... -o yaml` | mostra a definição completa do Service, incluindo `spec.selector` |
| `get endpointslices` | mostra os backends derivados do selector do Service |

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

## 3. Testar a hipótese

Depois de identificar o selector configurado:

```bash
kubectl get pods -n s78-lab -l <CHAVE>=<VALOR>
```

### Flag importante

`-l` significa **label selector**. A consulta devolve apenas objetos cujas labels correspondem à expressão.

## Estado esperado

- Pods continuam `Running/Ready` com a label correta;
- Service continua a existir;
- selector incorreto não encontra Pods;
- EndpointSlice fica sem endpoints (`endpoints: null` no cenário de referência).

## 4. Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Porque usar `jsonpath`

`jsonpath` extrai apenas o campo necessário, evitando procurar manualmente o selector num YAML grande.

### Checkpoint — não avançar sem validar

```text
Pods         → Ready
selector     → corresponde às labels
EndpointSlice → volta a ter os backends esperados
```

---

# CP3 — Worker `NotReady` e resiliência

## O que estamos a fazer

Parar **apenas o kubelet** de um Worker escolhido e observar como o Control Plane deteta a indisponibilidade e tenta reconciliar o Deployment.

## Porque é necessário

Permite observar resiliência de workload sem desligar a VM nem provocar uma falha destrutiva. Também demonstra que o estado desejado não garante convergência imediata quando não existe um Node elegível.

## Conceitos abordados

- `kubelet`;
- heartbeat e condição `Ready` do Node;
- taints `NotReady` / `Unreachable`;
- eviction;
- Deployment controller;
- Scheduler;
- Pod anti-affinity obrigatória;
- EndpointSlice durante perda de Node;
- resiliência de workload versus HA do Control Plane.

## 1. Health gate

No **Control Plane**:

```bash
kubectl get nodes -o wide
kubectl get pod postgres-0 -n s78-lab -o wide
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
```

### O que estamos a decidir

Selecionar o Worker que contém uma réplica Symfony mas **não** o PostgreSQL. Assim o incidente foca a resiliência da aplicação Web sem interromper deliberadamente a base de dados.

## 2. Provocar a falha — ação exclusiva do formador

No **Worker selecionado**:

```bash
sudo systemctl stop kubelet
```

### Explicação

| Elemento | Significado |
|---|---|
| `sudo` | executa com privilégios administrativos |
| `systemctl stop kubelet` | pára o agente Kubernetes do Node |

> Não parar `containerd`, não desligar a VM e não tocar no Control Plane. Este exercício simula perda de comunicação/gestão pelo kubelet, não falha física completa do Node.

## 3. Observar a evolução

No Control Plane:

```bash
kubectl get nodes -w
```

### Flag importante

`-w` significa **watch**: mantém a consulta aberta e mostra alterações à medida que a API recebe novos estados.

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

## Como interpretar

```text
estado desejado = 2 réplicas
        ↓
Worker deixa de estar Ready
        ↓
Controller tenta repor capacidade
        ↓
Scheduler procura Node elegível
        ↓
anti-affinity/taints podem impedir placement
        ↓
Pod pode permanecer Pending
```

No cenário de referência observou-se:

- Worker passa a `NotReady`;
- PostgreSQL permanece saudável no outro Worker;
- aplicação mantém um backend elegível, mas perde redundância;
- Pod antigo não desaparece instantaneamente;
- após os timers de eviction, é criada uma réplica de substituição;
- a réplica pode ficar `Pending` porque a anti-affinity obrigatória impede duas réplicas Symfony no mesmo Worker;
- endpoint do Worker indisponível pode aparecer com `ready: false`.

Mensagem-chave:

```text
Estado desejado ≠ convergência imediata
```

## 4. Recuperar o Worker

No Worker:

```bash
sudo systemctl start kubelet
sudo systemctl is-active kubelet
```

### Explicação

- `start kubelet` reinicia o agente;
- `is-active kubelet` confirma se o serviço está efetivamente ativo.

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

### Checkpoint — não avançar sem validar

```text
Worker       → Ready
PostgreSQL   → Ready
Deployment   → 2/2
Symfony Pods → 2 × 1/1 Running
Endpoints    → 2 × ready=true
```

Consolidar:

```text
Resiliência do workload ≠ HA do Control Plane
```

---

# CP4 — Control Plane, `etcd`, HA e recuperação

## O que estamos a fazer

Observar os componentes do único Control Plane e consultar o endpoint de readiness da API, sem provocar qualquer falha.

## Porque é necessário

Os formandos precisam de distinguir **Control Plane saudável neste momento** de **Control Plane altamente disponível**.

## Conceitos abordados

- `kube-apiserver`;
- `kube-controller-manager`;
- `kube-scheduler`;
- `etcd`;
- static Pods;
- endpoint `/readyz`;
- HA do Control Plane;
- backup e recovery de `etcd`.

## Onde executar

No **Control Plane**.

```bash
kubectl get pods -n kube-system -o wide \
  | grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler|etcd'

kubectl get --raw='/readyz?verbose'
```

### Explicação dos comandos

| Elemento | Significado |
|---|---|
| `-n kube-system` | consulta o Namespace onde residem componentes de sistema |
| `-o wide` | mostra Node, IP e informação adicional |
| `grep -E` | filtra apenas os componentes de Control Plane e `etcd` |
| `kubectl get --raw` | faz uma chamada direta a um endpoint HTTP da API Kubernetes |
| `/readyz?verbose` | mostra os checks internos de readiness da API de forma detalhada |

## O que observar

- `kube-apiserver`, controller-manager, scheduler e `etcd` estão no mesmo Control Plane;
- `/readyz?verbose` deve mostrar checks `ok` e terminar com `readyz check passed` num estado saudável;
- `etcd ok` prova saúde atual do backend da API, **não** redundância.

## Consolidar

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

```text
Control Plane saudável ≠ Control Plane altamente disponível
HA ≠ Backup ≠ Recovery
```

> **Não executar:** stop/restart de componentes do Control Plane, stop/restart de `etcd` ou restore destrutivo de snapshot neste cluster.

---

# INTERVALO — 15 minutos

---

# CP5 — Helm, Kustomize, CRD e Operator: mapa conceptual

## O que estamos a fazer

Introduzir os conceitos de gestão avançada que serão praticados nos CP seguintes e confirmar que as ferramentas/extensões necessárias existem.

## Porque é necessário

Helm, Kustomize e Operators resolvem problemas diferentes. Antes da execução prática, os formandos devem perceber o papel de cada mecanismo.

## Conceitos abordados

### Helm

```text
Chart + Values
      ↓
Release
      ↓
Revision
```

- **Chart**: pacote de templates e valores;
- **Release**: instalação concreta de um Chart;
- **Revision**: entrada histórica criada por install/upgrade/rollback.

### Kustomize

```text
Base + Overlay
      ↓
manifestos renderizados
```

Kustomize compõe YAML declarativo sem usar templates Helm.

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

No Control Plane:

```bash
helm version --short
kubectl kustomize app/overlays/normal/ >/dev/null
kubectl get crd prometheusrules.monitoring.coreos.com
kubectl get deployments -n monitoring | grep -i operator
```

### Explicação

| Comando | Objetivo |
|---|---|
| `helm version --short` | confirma a versão do Helm disponível |
| `kubectl kustomize ... >/dev/null` | valida que a renderização Kustomize termina sem erro; o output é descartado |
| `kubectl get crd ...` | prova que o tipo `PrometheusRule` está registado na API |
| `grep -i operator` | filtra o Deployment do Operator, ignorando maiúsculas/minúsculas |

Consolidar:

```text
Chart ≠ Release ≠ Revision
CRD ≠ Custom Resource
CR + Controller/Operator → reconciliação
```

---

# CP6 — Helm: adoção, upgrade defeituoso e rollback

## O que estamos a fazer

Transferir para Helm a gestão do Deployment e Service Symfony já existentes, introduzir um upgrade defeituoso, diagnosticar a causa e recuperar através de rollback.

## Porque é necessário

Este fluxo demonstra operação real de releases sem apagar os objetos existentes e permite observar o histórico de revisões como evidência operacional.

## Conceitos abordados

- Chart;
- Values;
- Release;
- Revision;
- ownership;
- `helm template`;
- `kubectl diff`;
- `--take-ownership`;
- upgrade;
- `ImagePullBackOff`;
- rollback;
- configuration drift.

> PostgreSQL e Secret permanecem geridos fora da release Helm. Neste CP, Helm assume apenas o Deployment e o Service Symfony.

## 1. Renderizar antes de instalar

No Control Plane:

```bash
helm template symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-good.yaml \
  > /tmp/symfony-good.yaml

kubectl diff -n s78-lab -f /tmp/symfony-good.yaml || true
```

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `helm template` | renderiza os templates localmente sem criar uma release |
| `symfony-lab` | nome que será usado pela release |
| `./helm/app-lab` | diretoria do Chart |
| `-n s78-lab` | Namespace usado na renderização |
| `-f values-good.yaml` | valores da configuração conhecida como boa |
| `> /tmp/symfony-good.yaml` | grava o YAML renderizado num ficheiro temporário |
| `kubectl diff` | compara o manifesto pretendido com o estado no cluster sem aplicar |
| `|| true` | impede que diferenças esperadas terminem o fluxo do shell, já que `kubectl diff` pode devolver código diferente de zero quando existem diferenças |

### O que observar

O diff deve ser interpretado antes da adoção. Alterações de metadata/labels Helm são esperadas; alterações inesperadas a imagem, probes, replicas, resources ou selector devem ser investigadas.

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
| `--take-ownership` | permite ao Helm adotar recursos existentes correspondentes ao Chart |
| `--wait` | espera pela convergência dos recursos |
| `--timeout 180s` | termina a espera após 180 segundos |

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

### O que provar

```text
Deployment → 2/2
Helm       → deployed
Revision   → existe uma revisão conhecida como boa
Ownership  → Helm | symfony-lab
```

## 3. Introduzir upgrade defeituoso

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

### O que está a acontecer

O ficheiro `values-broken.yaml` define uma imagem num registry inválido. O Helm cria uma nova Revision e espera pelo rollout. Como a nova réplica não consegue obter a imagem, o comando deve terminar por timeout.

## 4. Diagnosticar

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

### Explicação

| Comando | Evidência procurada |
|---|---|
| `helm status` | estado atual da release |
| `helm history` | sequência das revisions e respetivos estados |
| `get deployment` | impacto no rollout |
| `get pods` | identificação da réplica nova e da réplica antiga saudável |
| `describe pod` | razão concreta de `ErrImagePull` / `ImagePullBackOff` |
| `jsonpath` da imagem | imagem efetivamente declarada no Pod template do Deployment |

No cenário de referência, a imagem defeituosa é:

```text
registry.invalid/s78/symfony-demo:1.0.0
```

Um `FailedScheduling` transitório devido à anti-affinity pode surgir antes de o Pod ser agendado. Se depois o Pod estiver agendado e persistir `ImagePullBackOff`, a causa raiz é a imagem/registry inválido.

## 5. Rollback

Primeiro consultar o histórico:

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

### Conceito essencial

`helm rollback` reutiliza o conteúdo de uma revisão anterior, mas cria **uma nova Revision**. Não apaga a revisão falhada e não faz o contador voltar atrás.

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

### Checkpoint — não avançar sem validar

```text
Helm        → deployed
histórico   → mantém revision falhada + nova revision de rollback
Deployment  → 2/2
imagem      → ghcr.io/skullclamp/symfony-demo:1.0.0
Endpoints   → dois ready=true
```

---

# CP7 — Kustomize: base e overlays

## O que estamos a fazer

Usar os próprios manifests do laboratório para perceber como Kustomize compõe uma base comum com overlays que representam variantes.

## Porque é necessário

Evita duplicação integral de manifests e mostra como pequenas diferenças podem ser declaradas de forma controlada.

## Conceitos abordados

- `Kustomization`;
- base;
- overlay;
- patch;
- renderização declarativa;
- `diff`;
- ownership e risco de múltiplos gestores sobre o mesmo objeto.

## Estrutura

```text
app/
├── base/
└── overlays/
    ├── normal/
    ├── incident-probe/
    └── incident-service/
```

## 1. Renderizar variantes sem alterar o cluster

```bash
kubectl kustomize app/overlays/normal/ > /tmp/normal.yaml
kubectl kustomize app/overlays/incident-probe/ > /tmp/probe.yaml
kubectl kustomize app/overlays/incident-service/ > /tmp/service.yaml

diff -u /tmp/normal.yaml /tmp/probe.yaml || true
diff -u /tmp/normal.yaml /tmp/service.yaml || true
```

### Explicação

| Elemento | Significado |
|---|---|
| `kubectl kustomize` | renderiza manifests sem os aplicar |
| `>` | redireciona o YAML para um ficheiro temporário |
| `diff -u` | mostra diferenças em formato unificado |
| `|| true` | permite continuar mesmo quando `diff` encontra diferenças, que neste exercício são esperadas |

Relacionar:

```text
base comum
   +
overlay
   ↓
variante declarativa
```

## 2. Verificar ownership após adoção Helm

```bash
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}{" | "}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}'
```

### Porque isto é importante

Depois do CP6, Helm é responsável pelo Deployment e Service Symfony. Voltar a executar `kubectl apply -k` sobre esses objetos pode introduzir drift ou conflito de gestão.

> Depois da adoção Helm, Kustomize é usado aqui para **renderizar e comparar**, não para reaplicar Deployment/Service Symfony.

Um `kubectl diff` vazio não deve ser interpretado como prova de ownership. A prova é feita através das labels/anotações Helm.

### Checkpoint

A turma deve conseguir explicar:

```text
base + overlay → variante declarativa
```

E responder:

```text
Quem gere atualmente o Deployment e o Service Symfony? → Helm
```

---

# CP8 — CRD, Custom Resource, Operator e reconciliação

## O que estamos a fazer

Criar um `PrometheusRule`, alterar temporariamente o seu estado desejado e provar que a alteração foi reconciliada pelo Operator/Prometheus.

## Porque é necessário

Ver `metadata.generation` aumentar prova apenas que a API Kubernetes aceitou uma alteração no Custom Resource. Para provar reconciliação, é necessário observar a configuração resultante no sistema gerido.

## Conceitos abordados

- CRD;
- Custom Resource;
- Controller;
- Operator;
- desired state;
- `metadata.generation`;
- reconciliação;
- API do Prometheus.

## 1. Identificar a extensão da API e o Operator

No Control Plane:

```bash
kubectl get crd prometheusrules.monitoring.coreos.com
kubectl api-resources | grep -E 'PrometheusRule|Prometheus'
kubectl get deployments -n monitoring | grep -i operator
```

### Explicação

| Comando | O que prova |
|---|---|
| `get crd` | o tipo está registado na API |
| `api-resources` | Kubernetes expõe os novos tipos como recursos consultáveis |
| `get deployments ... operator` | existe um controller/operator disponível para reconciliar |

## 2. Criar o Custom Resource

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring
```

### Flag importante

`-f` indica o ficheiro YAML que contém o recurso a enviar para a API.

> O `PrometheusRule` existe no Namespace `monitoring`. A expressão PromQL dentro da regra observa o Deployment no Namespace `s78-lab`. São duas coisas diferentes.

Registar geração e `summary`:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

## 3. Alterar o estado desejado

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

### Explicação das flags e campos

| Elemento | Significado |
|---|---|
| `kubectl patch` | altera parcialmente um objeto existente |
| `--type='json'` | usa JSON Patch |
| `-p` | fornece as operações de patch |
| `op: replace` | substitui o valor existente |
| `path` | caminho JSON do campo a alterar |
| `value` | novo valor pretendido |

Confirmar:

```bash
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

### O que observar

- a `summary` mudou;
- `metadata.generation` aumentou.

> Isto prova **alteração do estado desejado**, mas ainda não prova reconciliação.

## 4. Provar a reconciliação no Prometheus

No primeiro terminal do Control Plane:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

### Explicação

| Elemento | Significado |
|---|---|
| `port-forward` | cria um encaminhamento local temporário para um recurso no cluster |
| `svc/...` | usa o Service Prometheus como destino |
| `9090:9090` | porta local 9090 → porta 9090 do destino |

> Manter apenas **um** `port-forward` para `127.0.0.1:9090` na mesma máquina. Se a porta já estiver ocupada por um forward ativo, reutilizá-lo.

Num segundo terminal do mesmo Control Plane:

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

### O que o script faz

1. consulta `http://127.0.0.1:9090/api/v1/rules`;
2. interpreta a resposta JSON;
3. procura o grupo `s78-lab.rules`;
4. procura a regra `SymfonyDeploymentUnavailable`;
5. mostra nome, estado e `summary` carregada pelo Prometheus.

### Evidência de reconciliação

A `summary` alterada deve aparecer na API do Prometheus.

`state=inactive` é normal enquanto o Deployment Symfony estiver saudável, porque a expressão de alerta não está verdadeira.

```text
generation aumentou
        ↓
API aceitou novo desired state
        ↓
Operator/Prometheus reconciliou
        ↓
summary alterada aparece na API do Prometheus
```

## 5. Repor o estado original

```bash
kubectl apply -f monitoring/prometheus-rule.yaml
kubectl get prometheusrule s78-lab-rules -n monitoring \
  -o jsonpath='generation={.metadata.generation}{"\n"}summary={.spec.groups[0].rules[0].annotations.summary}{"\n"}'
```

Repetir a consulta à API do Prometheus e confirmar que a `summary` original voltou a ser apresentada. Terminar depois o `port-forward` com `Ctrl+C` no terminal onde está ativo.

### Checkpoint — não avançar sem validar

```text
CRD               → existe
Custom Resource   → existe em monitoring
alteração do spec → generation aumenta
Prometheus API    → mostra summary alterada
reposição         → Prometheus volta a mostrar summary original
```

Consolidar:

```text
CRD              → define o tipo
Custom Resource  → declara estado desejado
Controller       → observa alterações
Operator         → aplica lógica operacional
Reconciliação    → aproxima o estado real do estado desejado
```

---

# CP9 — Desafio final e validação global

## O que estamos a fazer

Aplicar o método de troubleshooting sem partir imediatamente para uma correção e, no fim, provar que o ambiente ficou saudável depois de todos os exercícios.

## Porque é necessário

O objetivo final não é memorizar comandos, mas escolher evidência útil e construir uma sequência de diagnóstico coerente.

## Conceitos abordados

- observabilidade operacional;
- sequência de diagnóstico;
- correlação entre Pod, Deployment, Service, EndpointSlice e Events;
- decisão entre correção e rollback;
- validação pós-incidente.

## Cenário proposto

> Foi efetuado um upgrade da aplicação. A nova versão deixou de estar disponível através do Service.

Antes de executar comandos, a turma propõe uma sequência de diagnóstico.

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

### Porque esta sequência é útil

- `get` dá uma visão rápida do estado;
- `describe` acrescenta condições e Events associados ao objeto;
- `logs` mostra o comportamento da aplicação;
- Events ajudam a perceber scheduling, probes e pull de imagens;
- Service + EndpointSlice mostram se existem backends utilizáveis;
- só depois da evidência se escolhe a correção.

Se o problema estiver associado à release:

```bash
helm history symfony-lab -n s78-lab
helm rollback symfony-lab <REVISAO_BOA> -n s78-lab --wait
```

## Validação global obrigatória

No Control Plane:

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

### Explicação das verificações

| Verificação | O que prova |
|---|---|
| `kubectl get nodes` | todos os Nodes regressaram a `Ready` |
| `postgres-0 -o wide` | base de dados saudável e respetiva localização |
| Deployment | estado desejado `2/2` alcançado |
| Pods com `-l app=symfony-demo` | duas réplicas Web saudáveis |
| `jsonpath` da imagem | imagem boa efetivamente restaurada |
| `helm status` | release atual em `deployed` |
| `helm history` | preservação da revision falhada e da revision de rollback |
| EndpointSlice com `jsonpath` | cada backend está `ready=true`, `serving=true`, `terminating=false` |

### Estado final esperado

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

No final, os formandos devem conseguir explicar, e não apenas repetir:

```text
Running ≠ Ready

Service existente ≠ Service com backends

Estado desejado ≠ convergência imediata

Resiliência do workload ≠ HA do Control Plane

Control Plane saudável ≠ Control Plane altamente disponível

HA ≠ Backup ≠ Recovery

Chart ≠ Release ≠ Revision

Base + Overlay → variante Kustomize

CRD ≠ Custom Resource

CR + Controller/Operator → reconciliação

Sem evidência não há diagnóstico.
Sem causa raiz não há troubleshooting completo.
Sem validação pós-correção não há recuperação demonstrada.
```

---

# Limpeza

## O que estamos a fazer

Remover apenas os recursos pedagógicos desta aplicação, mantendo a stack de monitorização preparada pelo formador.

## Porque é necessário

O `PrometheusRule` está no Namespace `monitoring`, não no Namespace `s78-lab`. Apagar apenas `s78-lab` não remove esse Custom Resource.

```bash
kubectl delete prometheusrule s78-lab-rules \
  -n monitoring --ignore-not-found

helm uninstall symfony-lab -n s78-lab || true
kubectl delete namespace s78-lab --ignore-not-found
```

### Explicação

| Elemento | Significado |
|---|---|
| `delete prometheusrule` | remove o CR pedagógico criado no CP8 |
| `--ignore-not-found` | não considera erro se o recurso já tiver sido removido |
| `helm uninstall` | remove os recursos geridos pela release Helm |
| `|| true` | permite continuar a limpeza mesmo que a release já não exista |
| `delete namespace s78-lab` | remove os restantes recursos namespaced da aplicação |

> Não remover CRDs do Prometheus Operator durante a aula. A monitorização é infraestrutura preparada pelo formador e pode ser necessária para outras demonstrações.