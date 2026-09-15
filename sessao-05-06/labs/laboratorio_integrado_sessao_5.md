# Laboratório Integrado — Sessão 5
## Kubernetes Admin II — Administração e Governação de uma Aplicação

**Sessão:** 5 de 10  
**Nível:** intermédio  
**Topologia:** 1 Control Plane + 2 Workers elegíveis  
**CNI:** Calico  
**Aplicação:** Symfony Demo + PostgreSQL 16  
**Namespace:** `lab-admin`

Este documento é o **único laboratório integrado da Sessão 5**. O objetivo não é apenas executar comandos: em cada checkpoint o formando deve saber **o que está a fazer, por que o faz, o que deve observar e que evidência prova o resultado**.

A sequência pedagógica segue o padrão comum da formação:

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
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
TESTE NEGATIVO / FALHA CONTROLADA, quando aplicável
   ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
   ↓
EVIDÊNCIA A REGISTAR
```

> **Regra do laboratório:** um `kubectl apply` sem erro prova apenas que a API aceitou o recurso. Não prova que o comportamento pretendido está a acontecer.

> **Portabilidade:** os comandos destinados aos formandos não dependem de nomes nem IPs específicos de Nodes. O Worker usado no exercício de `nodeSelector` é descoberto dinamicamente.

## Como ler os comandos deste laboratório

Ao longo do laboratório, o formando deve conseguir responder sempre a quatro perguntas:

1. **O que estou a fazer?** — que objeto ou comportamento Kubernetes estou a alterar/observar.
2. **Porque estou a fazê-lo?** — que problema operacional ou de governação o passo resolve.
3. **O que significa o comando e cada flag relevante?** — não basta copiar; é preciso perceber o efeito.
4. **O que devo observar para validar?** — que estado, output, Event, código HTTP ou falha controlada prova o resultado.

Flags e convenções usadas repetidamente:

```text
-n <namespace>       → executa a operação no Namespace indicado
-A                   → consulta todos os Namespaces
-f <ficheiro>        → lê a definição do recurso a partir de um ficheiro
-l <selector>        → filtra objetos por labels
-o wide              → acrescenta informação operacional, como Node/IP
-o jsonpath='...'    → extrai campos concretos do objeto devolvido pela API
--timeout=<tempo>    → limita quanto tempo o comando espera por convergência
--                    → termina as opções de kubectl; o que vem depois é executado dentro do container
$?                   → código de saída do comando anterior; 0 = sucesso, valor diferente de 0 = falha
```

Estas flags não são repetidas do zero em todas as secções. Em cada checkpoint são explicados os comandos novos, as flags que mudam o significado da operação e, sobretudo, **o que deve ser observado para validar o comportamento**.

---

# 0. Baseline e preparação do formador

Antes da sessão, o formador deve confirmar:

- cluster acessível com 3 Nodes `Ready`;
- Control Plane não elegível para workloads aplicacionais normais;
- pelo menos 2 Workers elegíveis e `Ready`;
- StorageClass com provisionamento dinâmico;
- Calico operacional e enforcement de `NetworkPolicy` previamente validado;
- CoreDNS operacional e respetivas labels/Service identificados;
- imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` acessível e validada com `APP_ENV=prod`;
- imagem `postgres:16` acessível;
- `POSTGRES_DB` coerente entre PostgreSQL, Symfony e Job de backup;
- rota `/ready` validada como dependente do PostgreSQL;
- imagem de diagnóstico de `04-networking/pod-debug.yaml` com `curl`, `nslookup` e `nc`;
- nenhum Node com a label `disco=ssd` antes do laboratório;
- `symfony-antiaffinity-patch.yaml` com Anti-Affinity obrigatória por `kubernetes.io/hostname` e rollout `maxSurge: 0`, `maxUnavailable: 1`;
- `ResourceQuota` com margem para todos os Pods previstos;
- todos os manifests testados de ponta a ponta.

O laboratório foi validado de ponta a ponta com Symfony Demo, PostgreSQL 16, Calico, CoreDNS e provisionamento dinâmico `local-path`. O restore completo não faz parte do percurso obrigatório do laboratório.

---

# Estrutura dos recursos

A partir da diretoria `sessao-05-06/`:

```text
sessao-05-06/
├── 00-namespace.yaml
├── 00-storage/
│   └── local-path-storage.yaml
├── 01-governacao/
│   ├── limitrange.yaml
│   ├── resourcequota.yaml
│   └── pod-acima-da-quota.yaml
├── 02-aplicacao/
│   ├── symfony-deployment.yaml
│   ├── symfony-service.yaml
│   ├── postgres-statefulset.yaml
│   ├── postgres-service-headless.yaml
│   └── postgres-secret.yaml
├── 03-scheduling/
│   ├── symfony-nodeselector-patch.yaml
│   ├── symfony-antiaffinity-patch.yaml
│   └── pod-pending-exemplo.yaml
├── 04-networking/
│   └── pod-debug.yaml
├── 05-identidade/
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   ├── rolebinding.yaml
│   └── securitycontext-patch.yaml
├── 06-networkpolicy/
│   ├── default-deny.yaml
│   ├── allow-dns.yaml
│   ├── allow-client-app.yaml
│   ├── allow-app-db.yaml
│   ├── pod-client.yaml
│   └── pod-intruder.yaml
├── 07-backup/
│   ├── backup-pvc.yaml
│   ├── backup-job.yaml
│   ├── backup-reader.yaml
│   └── allow-backup-db.yaml
└── labs/
    └── laboratorio_integrado_sessao_5.md
```

---

# CP0 — Obter os recursos e validar o cluster

## Objetivo

Garantir que o repositório está atualizado, que o cluster cumpre a baseline e que o Namespace do laboratório pode ser criado em segurança.

**Executar em:** terminal de administração com `kubectl` funcional e permissões para os recursos usados no laboratório.

## O que estamos a fazer e porquê

Não assumimos que a shell abriu dentro do repositório. Primeiro obtemos ou atualizamos a branch `main`; depois validamos Nodes, storage, CNI, DNS e políticas existentes antes de criar recursos.

## O que o formando deve perceber

Neste checkpoint, o objetivo não é “começar a aplicar YAML” o mais depressa possível. É estabelecer uma **baseline conhecida**. Se o cluster já tiver Nodes degradados, storage indisponível, CoreDNS com problemas ou uma label residual, qualquer erro posterior pode ser atribuído à alteração errada.

O formando deve distinguir:

```text
repositório correto
    +
cluster saudável
    +
dependências disponíveis
    =
ponto de partida confiável
```

## 0.1. Obter ou atualizar o repositório

```bash
clear

REPO_DIR="$HOME/formacao-kubernetes"
REPO_URL="https://github.com/Skullclamp/formacao-kubernetes.git"

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" switch main
  git -C "$REPO_DIR" pull --ff-only origin main
elif [ -e "$REPO_DIR" ]; then
  BACKUP_DIR="${REPO_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO_DIR" "$BACKUP_DIR"
  echo "Diretoria anterior preservada em: $BACKUP_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
else
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR/sessao-05-06"

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short
```

### Como interpretar os comandos

```text
clear
→ limpa apenas o ecrã; não altera o sistema

REPO_DIR=...
REPO_URL=...
→ guardam valores reutilizados nos comandos seguintes

[ -d "$REPO_DIR/.git" ]
→ testa se já existe um repositório Git válido

git -C "$REPO_DIR" ...
→ executa Git nessa diretoria sem depender da diretoria atual da shell

switch main
→ muda explicitamente para a branch usada na formação

pull --ff-only origin main
→ atualiza a branch local apenas por fast-forward; evita merges automáticos inesperados

[ -e "$REPO_DIR" ]
→ testa se já existe qualquer ficheiro/diretoria com esse nome

date +%Y%m%d-%H%M%S
→ produz um sufixo temporal para preservar uma diretoria anterior sem a destruir

git clone --branch main --single-branch ...
→ clona diretamente a branch main e não descarrega branches desnecessárias

cd "$REPO_DIR/sessao-05-06"
→ entra na diretoria a partir da qual os caminhos relativos dos manifests são válidos

branch --show-current
→ confirma a branch ativa

status --short
→ mostra alterações locais de forma compacta; idealmente deve estar vazio
```

### O que observar para validar

- `branch --show-current` deve devolver `main`;
- `status --short` não deve mostrar alterações inesperadas;
- a diretoria `sessao-05-06/` deve existir e conter os manifests usados no laboratório.

## 0.2. Validar infraestrutura

```bash
kubectl get nodes -o wide
kubectl get sc
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system
kubectl get networkpolicy -A
kubectl get nodes -l disco=ssd
```

### Como interpretar os comandos

```text
kubectl get nodes -o wide
→ consulta os Nodes e mostra informação adicional, incluindo versão, IP e função

kubectl get sc
→ lista StorageClasses; precisamos de uma classe com provisionamento dinâmico

kubectl get pods -A | grep -i calico
→ lista Pods de todos os Namespaces e filtra os componentes Calico sem distinguir maiúsculas/minúsculas

kubectl get pods -n kube-system --show-labels
→ mostra os Pods de sistema e as labels; permite confirmar como identificar CoreDNS

kubectl get svc -n kube-system
→ lista Services de sistema; permite confirmar o Service DNS e respetivas portas

kubectl get networkpolicy -A
→ mostra políticas já existentes em todos os Namespaces; evita confundir políticas prévias com as criadas no laboratório

kubectl get nodes -l disco=ssd
→ procura Nodes que já tenham a label usada no exercício de scheduling; antes do laboratório não deve devolver nenhum
```

### O que observar

- 3 Nodes `Ready`;
- Control Plane não utilizado como destino de workloads aplicacionais;
- 2 Workers disponíveis;
- StorageClass dinâmica disponível;
- Calico sem erros;
- CoreDNS operacional;
- nenhuma label `disco=ssd` preexistente.

## 0.3. Criar o Namespace

```bash
kubectl apply -f 00-namespace.yaml
kubectl get namespace lab-admin
```

Todos os comandos seguintes usam `-n lab-admin` explicitamente. Não alteramos o contexto atual do `kubeconfig`.

### Como interpretar e validar

```text
kubectl apply -f 00-namespace.yaml
→ cria ou reconcilia o Namespace definido no manifesto

kubectl get namespace lab-admin
→ consulta diretamente o Namespace criado
```

O estado esperado é `Active`. Usar `-n lab-admin` explicitamente nos comandos seguintes torna o alvo visível e reduz o risco de executar uma operação num Namespace errado.

### CHECKPOINT CP0

```text
branch main ativa
recursos da sessão disponíveis
3 Nodes Ready
StorageClass disponível
Calico e CoreDNS operacionais
nenhum Node previamente marcado disco=ssd
Namespace lab-admin Active
```

**Não avançar** se a infraestrutura base estiver degradada.

**Evidência:** guardar `kubectl get nodes -o wide`, `kubectl get sc` e a confirmação do Namespace.

---

# CP1 — Governação inicial com LimitRange e ResourceQuota

## Objetivo

Aplicar defaults de recursos ao Namespace e provar que uma quota pode impedir a criação de um workload que excede a política definida.

**Executar em:** terminal de administração, dentro de `sessao-05-06/`.

## O que estamos a fazer e porquê

`LimitRange` permite definir defaults/limites por objeto; `ResourceQuota` controla o consumo agregado do Namespace. Primeiro observamos um Pod que recebe recursos por defeito; depois provocamos uma falha controlada por quota.

## O que o formando deve perceber

```text
LimitRange
→ define defaults e limites aplicáveis a objetos individuais

ResourceQuota
→ controla o consumo agregado do Namespace

admission
→ pode aceitar, completar ou rejeitar um objeto antes de ele chegar ao scheduler/runtime
```

O teste desta fase não procura apenas “ver dois objetos criados”. Procura provar que as regras de governação **alteram efetivamente o comportamento da API**.

## 1.1. Aplicar governação

```bash
kubectl apply -f 01-governacao/limitrange.yaml
kubectl apply -f 01-governacao/resourcequota.yaml

kubectl describe limitrange -n lab-admin
kubectl describe resourcequota -n lab-admin
```

### Como interpretar os comandos

```text
kubectl apply -f ...
→ cria/reconcilia o LimitRange e a ResourceQuota a partir dos manifests

kubectl describe limitrange -n lab-admin
→ mostra os defaults/limites efetivamente registados pela API

kubectl describe resourcequota -n lab-admin
→ mostra limites, consumo Used e capacidade Hard do Namespace
```

### O que observar para validar

- os objetos existem no Namespace `lab-admin`;
- os valores mostrados por `describe` correspondem ao manifesto;
- em `ResourceQuota`, distinguir `Used` de `Hard`.

## 1.2. Provar a aplicação de defaults

```bash
kubectl run teste-sem-limites --image=nginx -n lab-admin

kubectl get pod teste-sem-limites \
  -n lab-admin \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'

kubectl delete pod teste-sem-limites -n lab-admin
```

### Como interpretar os comandos e flags

```text
kubectl run teste-sem-limites
→ cria um Pod simples sem requests/limits explícitos no comando

--image=nginx
→ define a imagem do container usado no Pod de teste

-o jsonpath='{.spec.containers[0].resources}...'
→ lê diretamente os requests/limits que ficaram gravados no Pod depois da admission

kubectl delete pod teste-sem-limites
→ remove o Pod de teste para libertar quota
```

O ponto essencial é comparar a intenção inicial — Pod sem recursos explícitos — com o objeto efetivamente armazenado pela API. Se aparecerem requests/limits, o `LimitRange` teve efeito.

### O que observar para validar

- o Pod é criado;
- o `jsonpath` devolve requests/limits coerentes com o `LimitRange`;
- depois do `delete`, o Pod deixa de consumir quota.

Eliminar o Pod de teste é obrigatório para não consumir quota nas fases seguintes.

## 1.3. Falha controlada — exceder a quota

```bash
kubectl apply -f 01-governacao/pod-acima-da-quota.yaml
```

### Como interpretar

`kubectl apply -f 01-governacao/pod-acima-da-quota.yaml` envia à API um objeto cuja reserva de recursos ultrapassa a quota. O resultado correto **é uma falha**: a rejeição é a evidência de que a política está a ser aplicada.

### Resultado esperado

A API deve rejeitar o recurso com mensagem semelhante a `exceeded quota`.

### O que observar para validar

- o erro refere explicitamente a `ResourceQuota`;
- o Pod não fica criado em `lab-admin`;
- a falha ocorre na admission, antes de existir qualquer problema de scheduling ou runtime.

### CHECKPOINT CP1

```text
LimitRange aplicado
ResourceQuota aplicado
Pod sem recursos explícitos recebeu defaults
Pod acima da quota foi rejeitado
```

**Evidência:** guardar os recursos atribuídos ao Pod de teste e a mensagem completa da rejeição por quota.

---

# CP2 — Disponibilizar a aplicação e o storage

## Objetivo

Disponibilizar PostgreSQL persistente e duas réplicas Symfony, observando as relações entre Secret, Service, StatefulSet, Deployment e PVC.

**Executar em:** terminal de administração, dentro de `sessao-05-06/`.

## O que estamos a fazer e porquê

Criamos primeiro a configuração e o endpoint estável da base de dados; depois o StatefulSet e a aplicação. Os rollouts são aguardados explicitamente antes de avançar para alterações de scheduling.

## O que o formando deve perceber

A aplicação é composta por objetos com responsabilidades diferentes:

```text
Secret
→ configuração sensível usada pelos workloads

Headless Service PostgreSQL
→ identidade DNS estável para o StatefulSet

StatefulSet
→ identidade estável do Pod PostgreSQL e associação ao volume persistente

Deployment Symfony
→ réplicas stateless geridas por ReplicaSet

Service Symfony
→ endpoint estável para chegar às réplicas

PVC
→ pedido de storage persistente
```

A ordem de aplicação não é arbitrária: primeiro disponibilizamos configuração e descoberta de serviço; depois os workloads que dependem delas.

## 2.0. Garantir o provisionamento dinâmico `local-path`

O `StatefulSet` PostgreSQL deste laboratório pede explicitamente:

```yaml
storageClassName: local-path
```

Isto significa que **não basta existir um PVC**: o cluster tem de ter uma `StorageClass` chamada `local-path` e um provisioner capaz de criar o respetivo PV. Num cluster Kubernetes instalado de raiz, esse provisioner pode não existir.

Sem esta dependência, o efeito típico aparece no ponto **2.2 — Aguardar convergência**: o PostgreSQL não consegue ficar `Ready`, o PVC permanece `Pending` e o `rollout status` termina por timeout. O erro parece ser do rollout, mas a causa está no storage.

### O que estamos a fazer e porquê

Antes de criar o PostgreSQL, verificamos se o **Local Path Provisioner** está disponível. Se não estiver, instalamo-lo a partir do manifesto incluído no repositório da formação.

O manifesto usado em `00-storage/local-path-storage.yaml` corresponde à versão `v0.0.37` do `rancher/local-path-provisioner`, incluída localmente para que o laboratório não dependa de descarregar YAML externo durante a sessão.

```bash
if ! kubectl get storageclass local-path >/dev/null 2>&1 || \
   ! kubectl get deployment local-path-provisioner \
      -n local-path-storage >/dev/null 2>&1; then
  kubectl apply -f 00-storage/local-path-storage.yaml
fi

kubectl rollout status deployment/local-path-provisioner \
  -n local-path-storage \
  --timeout=120s

kubectl get storageclass local-path
kubectl get pods -n local-path-storage -o wide
```

### Como interpretar os comandos e flags

```text
kubectl get storageclass local-path
→ verifica se a StorageClass que o StatefulSet referencia existe

kubectl get deployment local-path-provisioner -n local-path-storage
→ verifica se o controller responsável pelo provisionamento está instalado

>/dev/null 2>&1
→ oculta stdout e stderr porque aqui queremos apenas testar sucesso/falha do comando

||
→ executa a condição seguinte quando a anterior falha; neste caso basta faltar a StorageClass ou o Deployment para instalar/reconciliar o provisioner

kubectl apply -f 00-storage/local-path-storage.yaml
→ instala/reconcilia Namespace, RBAC, Deployment, StorageClass e ConfigMap do Local Path Provisioner

kubectl rollout status deployment/local-path-provisioner
→ espera que o controller de storage esteja operacional antes de criar PVCs que dependem dele

-n local-path-storage
→ indica o Namespace onde o provisioner é executado

--timeout=120s
→ evita espera indefinida e transforma ausência de convergência numa falha observável
```

### O que observar para validar

- `deployment "local-path-provisioner" successfully rolled out` ou equivalente;
- `kubectl get storageclass local-path` devolve a classe `local-path`;
- o provisioner aparece `Running` e `Ready` em `local-path-storage`;
- a `StorageClass` apresenta `PROVISIONER` igual a `rancher.io/local-path`;
- só depois avançamos para o PostgreSQL.

> **Checkpoint de storage:** se `local-path` não existir ou o provisioner não estiver `Ready`, não avançar para 2.1. Caso contrário, o erro surgirá mais tarde como PVC `Pending`/rollout em timeout e será mais difícil identificar a causa.

## 2.1. Aplicar os recursos na ordem das dependências

```bash
kubectl apply -f 02-aplicacao/postgres-secret.yaml
kubectl apply -f 02-aplicacao/postgres-service-headless.yaml
kubectl apply -f 02-aplicacao/postgres-statefulset.yaml
kubectl apply -f 02-aplicacao/symfony-deployment.yaml
kubectl apply -f 02-aplicacao/symfony-service.yaml
```

### Como interpretar os comandos

Cada `kubectl apply -f` envia um manifesto diferente para a API:

```text
postgres-secret.yaml
→ cria as variáveis/credenciais consumidas pela base de dados e pela aplicação

postgres-service-headless.yaml
→ cria o Service sem ClusterIP usado para identidade estável do StatefulSet

postgres-statefulset.yaml
→ cria o PostgreSQL e o volumeClaimTemplate/PVC associado

symfony-deployment.yaml
→ cria e mantém as réplicas Symfony

symfony-service.yaml
→ cria um endpoint estável para chegar às réplicas selecionadas por labels
```

'''bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
'''


### O que observar para validar

O `apply` bem-sucedido significa apenas que os objetos foram aceites. A validação real vem no passo seguinte, quando os controllers convergem e os Pods ficam `Ready`.

## 2.2. Aguardar convergência

```bash
kubectl rollout status statefulset/postgres -n lab-admin --timeout=120s
kubectl rollout status deployment/symfony -n lab-admin --timeout=120s
```

`rollout status` não cria recursos; espera que o controller atinja o estado desejado ou termine por timeout.

### Como interpretar os comandos e flags

```text
kubectl rollout status statefulset/postgres
→ acompanha a convergência do StatefulSet até a réplica desejada estar pronta

kubectl rollout status deployment/symfony
→ acompanha o Deployment até as réplicas disponíveis coincidirem com o estado desejado

--timeout=120s
→ impede espera indefinida; se o estado não convergir, o comando termina com erro
```

### O que observar para validar

- ambos os comandos terminam com sucesso;
- se existir timeout, não avançar: investigar Pod, Events, imagem, probes, Secret e storage.

## 2.3. Observar workloads e storage

```bash
kubectl get pods -n lab-admin -o wide
kubectl get statefulset -n lab-admin
kubectl get deployment -n lab-admin
kubectl get svc -n lab-admin
kubectl get pvc -n lab-admin
kubectl get pv
```

### Como interpretar os comandos

```text
get pods -o wide
→ mostra estado, prontidão, IP e Node de cada Pod

get statefulset
→ mostra réplicas desejadas/atuais/ready do PostgreSQL

get deployment
→ mostra disponibilidade e estado do rollout Symfony

get svc
→ mostra os endpoints lógicos expostos no Namespace

get pvc
→ mostra pedidos de storage e respetivo estado, por exemplo Bound

get pv
→ mostra os volumes persistentes a nível de cluster; PV é cluster-scoped, ao contrário do PVC
```

### O que observar

```text
postgres-0        → Running / Ready
Symfony           → 2 réplicas Running / Ready
PVC PostgreSQL    → Bound
Service postgres  → headless
Service symfony   → disponível no Namespace
```

A ordem `Secret → Headless Service → StatefulSet` torna explícitas as dependências do PostgreSQL antes do arranque do workload.

### CHECKPOINT CP2

```text
PostgreSQL Ready
PVC Bound
Deployment Symfony 2/2 disponível
Services criados
sem Pods em CrashLoopBackOff ou Pending inesperado
```

**Evidência:** guardar `kubectl get pods -n lab-admin -o wide` e `kubectl get pvc -n lab-admin`.

---

# CP3 — Scheduling: seleção, distribuição e falha controlada

## Objetivo

Observar três comportamentos distintos do scheduler:

1. seleção obrigatória de um Worker por label;
2. distribuição obrigatória das réplicas Symfony por hostname;
3. um Pod não agendável por condição impossível.

**Executar em:** terminal de administração.

## O que o formando deve perceber

O scheduler não “escolhe um Node ao acaso”. Ele filtra Nodes que não satisfazem restrições e, entre os elegíveis, aplica regras de placement. Nesta fase queremos distinguir:

```text
nodeSelector
→ restringe a elegibilidade a Nodes com labels específicas

Pod Anti-Affinity
→ impede colocação conjunta de Pods que correspondem ao seletor

FailedScheduling
→ o objeto Pod existe, mas nenhum Node satisfaz as condições
```

Também deve ficar claro que a estratégia de rollout pode criar necessidades temporárias de capacidade e interagir com regras de Anti-Affinity.

## Health gate antes das alterações

```bash
kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

Não iniciar alterações de placement se as duas réplicas Symfony não estiverem saudáveis.

### Como interpretar

```text
rollout status deployment/symfony
→ confirma que o estado atual do Deployment já convergiu antes de o alterarmos

-l app=symfony
→ filtra apenas os Pods pertencentes à aplicação Symfony

-o wide
→ permite ver em que Node cada réplica está colocada
```

### O que observar para validar

- duas réplicas Symfony `Ready`;
- nenhuma réplica em `Pending` ou `CrashLoopBackOff`;
- o ponto de partida é conhecido antes de mudar regras de placement.

## 3.1. Experiência A — `nodeSelector`

### O que estamos a fazer e porquê

Selecionamos dinamicamente um Worker `Ready`, aplicamos a label `disco=ssd` e restringimos o Deployment Symfony a Nodes com essa label.

```bash
WORKER_SSD=$(kubectl get nodes \
  -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' \
  --no-headers | awk '$2 ~ /^Ready/ {print $1; exit}')

test -n "$WORKER_SSD" || { echo "Nenhum Worker Ready encontrado"; exit 1; }
echo "Worker selecionado: $WORKER_SSD"

kubectl label node "$WORKER_SSD" disco=ssd --overwrite
kubectl get node "$WORKER_SSD" --show-labels
```

### Como interpretar a seleção do Worker

```text
-l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master'
→ exclui Nodes marcados como Control Plane ou com a label legacy master

--no-headers
→ remove o cabeçalho para facilitar o processamento por awk

awk '$2 ~ /^Ready/ {print $1; exit}'
→ escolhe o primeiro Node cujo estado começa por Ready e devolve apenas o nome

WORKER_SSD=$(...)
→ guarda o resultado do comando numa variável shell

test -n "$WORKER_SSD"
→ valida que a variável não ficou vazia; se ficou, o laboratório pára

kubectl label node "$WORKER_SSD" disco=ssd --overwrite
→ cria/atualiza a label usada pelo nodeSelector

--show-labels
→ permite confirmar que a label ficou realmente aplicada
```

### O que observar para validar

- a variável mostra o nome de um Worker `Ready`;
- `kubectl get node ... --show-labels` inclui `disco=ssd`;
- nenhum nome/IP de Node foi escrito manualmente no guião.

Aplicar o patch:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-nodeselector-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

### Como interpretar o patch e os comandos

```text
kubectl patch deployment symfony
→ altera apenas o Deployment existente, sem substituir o manifesto completo

--patch-file symfony-nodeselector-patch.yaml
→ lê a alteração a aplicar a partir do patch validado

nodeSelector
→ exige que o Node tenha a label indicada; Nodes sem disco=ssd deixam de ser elegíveis

rollout status
→ espera pela recriação das réplicas segundo o novo template

get pods ... -o wide
→ prova em que Node as réplicas acabaram por ser colocadas
```

### O que observar para validar

**Esperado:** as réplicas Symfony ficam elegíveis apenas para o Worker com `disco=ssd`. O `NODE` mostrado por `-o wide` deve corresponder ao Worker guardado em `WORKER_SSD`.

> O exercício altera apenas o Deployment Symfony. Não deslocamos deliberadamente o PostgreSQL entre Workers, porque a portabilidade do volume depende da StorageClass e da topologia do ambiente.

## 3.2. Experiência B — Anti-Affinity obrigatória

Antes da Anti-Affinity, remover o `nodeSelector` para não manter uma restrição incompatível com a distribuição por Workers diferentes:

```bash
kubectl patch deployment symfony -n lab-admin \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

### Como interpretar

```text
--type=json
→ usa JSON Patch, adequado para operações explícitas como remover um campo

-p='[...]'
→ fornece o patch diretamente na linha de comando

op: remove
→ remove o campo indicado

path: /spec/template/spec/nodeSelector
→ caminho exato, dentro do template do Pod, onde estava a restrição anterior
```

Remover este campo é necessário porque manter `nodeSelector: disco=ssd` obrigaria as duas réplicas ao mesmo Worker e entraria em conflito com a Anti-Affinity por hostname.

Aplicar o patch validado:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-antiaffinity-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

### Porque o rollout também interessa

O patch usa Anti-Affinity obrigatória por:

```text
requiredDuringSchedulingIgnoredDuringExecution
        +
topologyKey: kubernetes.io/hostname
```

Com duas réplicas e apenas dois Workers elegíveis, um rollout com `maxSurge: 1` tentaria criar temporariamente uma terceira réplica, que não teria hostname disponível compatível com a Anti-Affinity. Por isso o patch validado usa:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
```

### Como interpretar o patch de Anti-Affinity

```text
requiredDuringSchedulingIgnoredDuringExecution
→ regra obrigatória no momento do scheduling

topologyKey: kubernetes.io/hostname
→ considera cada hostname de Node como domínio de topologia distinto

maxSurge: 0
→ durante o rollout não cria réplicas extra acima do número desejado

maxUnavailable: 1
→ permite substituir uma réplica de cada vez, libertando capacidade para respeitar a Anti-Affinity
```

### O que observar para validar

**Esperado:** rollout concluído e uma réplica Symfony em cada Worker.

Se as duas réplicas surgirem no mesmo Node, a regra não está a produzir o efeito pretendido. Se aparecer uma terceira réplica `Pending` durante demasiado tempo, verificar a estratégia do rollout.

## 3.3. Experiência C — falha intencional de scheduling

```bash
kubectl apply -f 03-scheduling/pod-pending-exemplo.yaml
kubectl get pod pod-pending-exemplo -n lab-admin -o wide
kubectl describe pod pod-pending-exemplo -n lab-admin
kubectl get events -n lab-admin --sort-by=.lastTimestamp
```

### Como interpretar os comandos

```text
kubectl apply -f pod-pending-exemplo.yaml
→ cria deliberadamente um Pod com uma condição de scheduling impossível

kubectl get pod ... -o wide
→ mostra que o objeto existe mas ainda não recebeu Node

kubectl describe pod ...
→ mostra Conditions e Events associados ao Pod

kubectl get events --sort-by=.lastTimestamp
→ lista Events ordenados temporalmente; facilita encontrar a decisão recente do scheduler

kubectl delete pod ...
→ remove o recurso de diagnóstico depois de recolhida a evidência
```

### Resultado esperado

O Pod fica `Pending` e os Events apresentam `FailedScheduling`, indicando que os Nodes não satisfazem a condição de placement.

### O que observar para validar

- `STATUS=Pending`;
- coluna `NODE` vazia;
- Event `FailedScheduling`;
- mensagem explica que os Nodes não correspondem à condição definida.

Depois da evidência:

```bash
kubectl delete pod pod-pending-exemplo -n lab-admin
```

### CHECKPOINT CP3

```text
nodeSelector concentrou Symfony no Worker marcado
Anti-Affinity distribuiu as duas réplicas por hostnames diferentes
rollout concluiu sem terceira réplica bloqueada
Pod impossível ficou Pending com FailedScheduling
```

**Evidência:** guardar a distribuição dos Pods antes/depois e a causa de `FailedScheduling`.

---

# CP4 — Networking, DNS e cadeia aplicação → base de dados

## Objetivo

Provar resolução DNS dentro do cluster, acesso ao Service Symfony e prontidão da aplicação com dependência real do PostgreSQL.

**Executar em:** terminal de administração; os testes de rede são executados dentro do Pod `debug`.

## O que estamos a fazer e porquê

Criamos um Pod de diagnóstico com ferramentas previamente validadas. Não usamos a shell do Node para provar comunicação Pod-to-Service, porque queremos observar o percurso a partir da rede dos Pods.

## O que o formando deve perceber

A rede Kubernetes deve ser validada a partir do contexto certo. Um `curl` feito no Node prova conectividade do host; não prova necessariamente DNS, routing e políticas vistos por um Pod.

Nesta fase distinguimos:

```text
DNS
→ transforma o nome do Service num endereço utilizável

Service
→ fornece endpoint estável para chegar aos Pods selecionados

/ready
→ neste laboratório, prova simultaneamente aplicação acessível e dependência PostgreSQL funcional
```

## 4.1. Criar e aguardar o Pod de diagnóstico

```bash
kubectl apply -f 04-networking/pod-debug.yaml
kubectl wait --for=condition=Ready pod/debug -n lab-admin --timeout=60s
```

### Como interpretar os comandos

```text
kubectl apply -f pod-debug.yaml
→ cria o Pod de diagnóstico definido no manifesto

kubectl wait --for=condition=Ready pod/debug
→ espera explicitamente que a condição Ready seja verdadeira

--for=condition=Ready
→ define a condição que queremos observar

--timeout=60s
→ termina com erro se o Pod não ficar pronto dentro do limite
```

`kubectl wait` evita uma condição de corrida entre a criação do objeto Pod e a disponibilidade efetiva do container para `exec`.

### O que observar para validar

- o comando `wait` termina com `condition met`;
- só depois executamos comandos dentro do Pod.

## 4.2. Resolver os Services

```bash
kubectl exec debug -n lab-admin -- nslookup symfony
kubectl exec debug -n lab-admin -- nslookup postgres
```

### Como interpretar

```text
kubectl exec debug -n lab-admin -- nslookup symfony
→ executa nslookup dentro do container debug e consulta o Service Symfony

kubectl exec debug -n lab-admin -- nslookup postgres
→ faz o mesmo para o Service PostgreSQL

--
→ separa as flags do kubectl do comando que será executado dentro do container
```

**Esperado:** ambos os nomes resolvem para endereços do cluster.

### O que observar para validar

- o servidor DNS usado pelo Pod é o DNS do cluster;
- `symfony` resolve para o Service Symfony;
- `postgres` resolve para o endpoint esperado do Service headless;
- erros de resolução devem ser tratados como problema de DNS, não de HTTP.

## 4.3. Testar o Service Symfony

```bash
kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony
```

### Como interpretar o comando e as flags

```text
kubectl exec debug ... -- curl ...
→ executa curl a partir da rede do Pod de diagnóstico

-s
→ não mostra progress meter nem informação supérflua

-S
→ mesmo em modo silencioso, mantém as mensagens de erro

--max-time 5
→ limita o tempo total do pedido e evita espera indefinida

-o /dev/null
→ descarta o corpo HTML porque aqui queremos validar o estado HTTP

-w 'HTTP %{http_code}\n'
→ imprime explicitamente o código HTTP devolvido pelo Service
```

### O que observar para validar

**Esperado:** `HTTP 200`. Um `kubectl exec` bem-sucedido com `HTTP 000` não valida a aplicação; é o código HTTP que interessa.

## 4.4. Provar `debug → app → db`

A rota `/ready` usada neste laboratório foi previamente validada como dependente do PostgreSQL.

```bash
kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready
```

### Como interpretar

Neste segundo `curl` não usamos `-o /dev/null`, porque o corpo da resposta é parte da evidência. Queremos observar duas camadas:

```text
HTTP 200
→ o endpoint respondeu com sucesso

"database":"ok"
→ a própria aplicação confirmou acesso ao PostgreSQL
```

**Esperado:** corpo semelhante a:

```text
{"status":"ready","database":"ok"}
HTTP 200
```

Se existir `HTTP 200` mas não houver validação da base de dados no corpo, o endpoint escolhido não prova a cadeia `app → db`.

Eliminar o Pod temporário:

```bash
kubectl delete pod debug -n lab-admin
```

`kubectl delete pod` remove o recurso de diagnóstico para libertar quota e evitar que um Pod temporário interfira com fases posteriores.

## 4.5. Gateway API — apenas enquadramento conceptual

Nesta sessão não instalamos controller nem aplicamos manifests de Gateway API. A relação a compreender é:

```text
GatewayClass → Gateway → HTTPRoute → Service → Pods
```

### CHECKPOINT CP4

```text
DNS de symfony resolve
DNS de postgres resolve
Service Symfony responde HTTP 200
/ready confirma database=ok
Pod debug eliminado
```

**Evidência:** guardar os dois `nslookup` e a resposta de `/ready` com `HTTP 200`.

---

# CP5 — Identidade, RBAC e hardening do workload

## Objetivo

Dar ao workload Symfony uma identidade própria, aplicar menor privilégio na API e endurecer o contexto de segurança sem impedir a aplicação de arrancar.

**Executar em:** terminal de administração.

## O que estamos a fazer e porquê

Até aqui a aplicação funcionava, mas isso não significa que estivesse a usar a identidade e os privilégios mínimos adequados. Nesta fase separamos três conceitos:

```text
ServiceAccount
→ identidade do workload perante a Kubernetes API

Role + RoleBinding
→ ações autorizadas a essa identidade dentro do Namespace

SecurityContext
→ restrições de execução do processo/container no runtime
```

## O que o formando deve perceber

“Funcionar” e “estar minimamente privilegiado” são critérios diferentes. Queremos provar que o Symfony mantém disponibilidade **depois** de reduzir privilégios e que uma ação permitida e uma ação negada produzem resultados distintos.

## 5.1. Criar identidade e autorização

```bash
kubectl apply -f 05-identidade/serviceaccount.yaml
kubectl apply -f 05-identidade/role.yaml
kubectl apply -f 05-identidade/rolebinding.yaml
```

### Como interpretar os manifests

```text
serviceaccount.yaml
→ cria a identidade app-reader

role.yaml
→ define verbos/recursos permitidos dentro de lab-admin

rolebinding.yaml
→ associa a Role à ServiceAccount app-reader
```

`kubectl apply -f` apenas confirma que os objetos foram aceites. A prova de autorização vem com `kubectl auth can-i`.

## 5.2. Teste positivo e negativo de RBAC

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:lab-admin:app-reader \
  -n lab-admin

kubectl auth can-i delete pods \
  --as=system:serviceaccount:lab-admin:app-reader \
  -n lab-admin
```

### Como interpretar os comandos e flags

```text
kubectl auth can-i get pods
→ pergunta à API se a identidade indicada pode executar o verbo get sobre Pods

kubectl auth can-i delete pods
→ testa deliberadamente uma operação que não deve estar autorizada

--as=system:serviceaccount:lab-admin:app-reader
→ simula a chamada como a ServiceAccount app-reader

-n lab-admin
→ avalia a autorização no Namespace onde a Role é válida
```

### O que observar para validar

**Esperado:** primeiro comando `yes`; segundo comando `no`.

Isto prova menor privilégio: a identidade tem a capacidade necessária para leitura, mas não ganha automaticamente permissões de escrita/destruição.

## 5.3. Aplicar o `SecurityContext`

O patch foi previamente validado para a imagem usada no laboratório.

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 05-identidade/securitycontext-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
```

### Como interpretar

```text
kubectl patch deployment symfony --patch-file ...
→ altera o template dos Pods Symfony com a identidade e restrições de segurança definidas

rollout status
→ espera pela substituição das réplicas antigas pelas novas

--timeout=60s
→ transforma ausência de convergência numa falha observável, em vez de esperar indefinidamente
```

A configuração inclui:

```text
serviceAccountName: app-reader
automountServiceAccountToken: false
allowPrivilegeEscalation: false
capabilities.drop: [ALL]
seccompProfile: RuntimeDefault
```

### O que significam os campos

```text
serviceAccountName: app-reader
→ os Pods usam a identidade app-reader

automountServiceAccountToken: false
→ não monta automaticamente um token da API dentro do Pod quando a aplicação não precisa dele

allowPrivilegeEscalation: false
→ impede o processo de ganhar privilégios adicionais por mecanismos como setuid

capabilities.drop: [ALL]
→ remove capabilities Linux adicionais por defeito

seccompProfile: RuntimeDefault
→ aplica o perfil seccomp predefinido pelo runtime
```

Capabilities adicionais só devem existir se forem necessárias e previamente validadas para a imagem.

### O que observar para validar

- o rollout conclui;
- as duas réplicas voltam a `Ready`;
- endurecer segurança não deve ser aceite se quebrar a aplicação.

## 5.4. Confirmar a configuração efetiva

```bash
kubectl get deployment symfony -n lab-admin \
  -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}{.spec.template.spec.automountServiceAccountToken}{"\n"}'

SYMFONY_POD=$(kubectl get pods \
  -n lab-admin \
  -l app=symfony \
  -o jsonpath='{.items[0].metadata.name}')

echo "Pod selecionado: $SYMFONY_POD"

kubectl get pod "$SYMFONY_POD" -n lab-admin \
  -o jsonpath='{.spec.containers[0].securityContext}{"\n"}'

kubectl get pods -n lab-admin -l app=symfony -o wide
```

### Como interpretar os comandos

```text
jsonpath sobre Deployment
→ lê a configuração desejada do template: ServiceAccount e automount

SYMFONY_POD=$(kubectl get pods ...)
→ descobre dinamicamente um Pod Symfony sem escrever o nome gerado pelo ReplicaSet

-l app=symfony
→ seleciona apenas Pods Symfony

-o jsonpath='{.items[0].metadata.name}'
→ devolve o nome do primeiro Pod correspondente

jsonpath sobre securityContext
→ lê a configuração efetivamente presente no Pod criado a partir do novo template

get pods -o wide
→ confirma simultaneamente Ready e placement depois do rollout
```

### O que observar para validar

- `app-reader`;
- `false` para `automountServiceAccountToken`;
- `securityContext` com os campos esperados;
- duas réplicas `Ready`.

### CHECKPOINT CP5

```text
ServiceAccount dedicada aplicada
get pods = yes
delete pods = no
automountServiceAccountToken = false
SecurityContext endurecido
2 réplicas Symfony continuam Ready
```

**Evidência:** guardar os dois `can-i`, a identidade do Deployment e o `securityContext` efetivo de um Pod.

---

# CP6 — NetworkPolicy: fechar tudo e reabrir apenas o necessário

## Objetivo

Demonstrar isolamento de rede por política, distinguindo DNS de tráfego aplicacional e provando simultaneamente um fluxo permitido e um fluxo bloqueado.

**Executar em:** terminal de administração; testes dentro dos Pods `client` e `intruder`.

## O que estamos a fazer e porquê

Começamos com comunicação livre, aplicamos `default-deny` para Ingress e Egress e reabrimos progressivamente apenas:

```text
DNS
client → Symfony
Symfony → PostgreSQL
```

O Pod `intruder` nunca recebe autorização para chegar ao PostgreSQL.

## O que o formando deve perceber

Uma `NetworkPolicy` não é validada pelo facto de o objeto existir. É validada por **tráfego real**.

A progressão foi desenhada para separar causas:

```text
sem policy
→ tudo funciona

default-deny
→ tudo fica bloqueado

allow DNS
→ nomes resolvem, mas HTTP/TCP continuam bloqueados

allow client → app + app → db
→ apenas a cadeia necessária volta a funcionar

intruder → db
→ continua bloqueado
```

O formando deve perceber também que, quando existe isolamento de Ingress e Egress, um fluxo entre workloads pode precisar de autorização nos dois extremos.

## 6.1. Criar os clientes de teste e esperar por `Ready`

```bash
kubectl apply -f 06-networkpolicy/pod-client.yaml
kubectl apply -f 06-networkpolicy/pod-intruder.yaml

kubectl wait --for=condition=Ready pod/client -n lab-admin --timeout=120s
kubectl wait --for=condition=Ready pod/intruder -n lab-admin --timeout=120s
```

### Como interpretar

```text
pod-client.yaml / pod-intruder.yaml
→ criam dois Pods com labels diferentes para representar origem autorizada e origem não autorizada

kubectl wait --for=condition=Ready
→ garante que o container existe e está pronto antes do primeiro exec

--timeout=120s
→ falha se o Pod não ficar pronto, evitando que um erro de arranque seja confundido com NetworkPolicy
```

### O que observar para validar

Ambos os `wait` devem terminar com `condition met`.

## 6.2. Baseline — antes do isolamento

```bash
kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

### Como interpretar

```text
curl ... http://symfony/ready
→ testa a cadeia completa client → Symfony → PostgreSQL

-w '\nHTTP %{http_code}\n'
→ torna o código HTTP parte explícita da evidência

echo $?
→ mostra o código de saída do curl: 0 significa sucesso operacional do comando
```

**Esperado:** `database=ok`, `HTTP 200` e exit code `0`.

Este baseline é obrigatório: sem ele não saberíamos se uma falha posterior foi introduzida pela política ou já existia.

### O que observar para validar

Só avançar se o baseline estiver saudável. Caso contrário, investigar aplicação/DNS/rede antes de aplicar qualquer política.

## 6.3. Aplicar `default-deny`

```bash
kubectl apply -f 06-networkpolicy/default-deny.yaml
kubectl get networkpolicy -n lab-admin

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 3 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

### Como interpretar

```text
kubectl apply -f default-deny.yaml
→ passa a isolar Ingress e Egress dos Pods abrangidos pela política

kubectl get networkpolicy
→ confirma a presença do objeto, mas não prova enforcement

curl ... -o /dev/null -w ...
→ testa o comportamento real depois do isolamento

HTTP 000
→ curl não recebeu uma resposta HTTP válida; pode ter falhado antes da camada HTTP

echo $?
→ deve ser diferente de 0
```

**Esperado:** falha. Como o egress DNS também fica bloqueado, o primeiro sintoma pode ser timeout de resolução, `HTTP 000` e exit code diferente de `0`.

### O que observar para validar

- a política existe;
- o tráfego que funcionava no baseline deixa de funcionar;
- a causa pode aparecer como resolução DNS bloqueada, o que é coerente com egress deny.

## 6.4. Reabrir apenas DNS

```bash
kubectl apply -f 06-networkpolicy/allow-dns.yaml

kubectl exec client -n lab-admin -- nslookup symfony
kubectl exec client -n lab-admin -- nslookup postgres

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 3 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Esperado:** DNS funciona novamente, mas HTTP continua bloqueado.

### Como interpretar

```text
kubectl apply -f allow-dns.yaml
→ autoriza apenas o tráfego necessário para chegar ao CoreDNS

nslookup symfony / postgres
→ prova que o DNS voltou a funcionar

curl ...
→ verifica se o fluxo aplicacional continua bloqueado
```

### O que observar para validar

- `nslookup` volta a resolver;
- o `curl` continua a falhar;
- isto demonstra que DNS e autorização de tráfego aplicacional são camadas diferentes.

Esta etapa prova que:

```text
resolver nomes ≠ autorizar comunicação aplicacional
```

## 6.5. Reabrir os fluxos aplicacionais necessários

```bash
kubectl apply -f 06-networkpolicy/allow-client-app.yaml
kubectl apply -f 06-networkpolicy/allow-app-db.yaml

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

### Como interpretar

```text
allow-client-app.yaml
→ autoriza o egress do client para Symfony e o ingress correspondente em Symfony

allow-app-db.yaml
→ autoriza o egress do Symfony para PostgreSQL e o ingress correspondente em PostgreSQL

curl /ready
→ valida de uma só vez que os dois saltos necessários estão funcionais
```

### O que observar para validar

**Esperado:** `database=ok`, `HTTP 200`, exit code `0`.

A recuperação do fluxo não deve ocorrer antes destas autorizações; se ocorrer, rever selectors e policyTypes.

## 6.6. Teste negativo obrigatório — `intruder → db`

```bash
kubectl exec intruder -n lab-admin -- \
  nc -zvw3 postgres 5432

echo $?
```

### Como interpretar o comando e as flags

```text
nc postgres 5432
→ tenta abrir uma ligação TCP ao PostgreSQL

-z
→ modo scan/zero-I/O: testa a porta sem iniciar uma sessão de aplicação

-v
→ mostra informação detalhada sobre a tentativa

-w3
→ limita a espera da ligação a aproximadamente 3 segundos

echo $?
→ prova que o teste terminou com falha
```

### O que observar para validar

**Esperado:** timeout/conexão bloqueada e exit code diferente de `0`.

Este é o teste negativo que prova a fronteira de segurança: o DNS pode resolver `postgres`, mas o `intruder` continua sem autorização TCP/5432.

## 6.7. Interpretar o contrato das políticas

Com `default-deny` de Ingress e Egress, os fluxos entre workloads são autorizados nos dois extremos:

```text
allow-client-app.yaml
  client  ── egress HTTP ──> Symfony
  Symfony <── ingress HTTP ── client

allow-app-db.yaml
  Symfony    ── egress TCP/5432 ──> PostgreSQL
  PostgreSQL <── ingress TCP/5432 ── Symfony

allow-backup-db.yaml
  role=backup ── egress TCP/5432 ──> PostgreSQL
  PostgreSQL  <── ingress TCP/5432 ── role=backup
```

`allow-dns.yaml` é diferente: autoriza o egress dos Pods de `lab-admin` para o CoreDNS no Namespace do sistema; este laboratório não cria uma política adicional no Namespace do DNS.

Confirmar o estado final:

```bash
kubectl get networkpolicy -n lab-admin
```

`kubectl get networkpolicy` é útil para inventário: permite confirmar que as políticas esperadas existem. A prova de que estão corretas continua a ser o conjunto de testes positivo/negativo executado acima.

### O que observar para validar

Devem estar presentes `default-deny`, a autorização DNS e as políticas dos fluxos `client → app`, `app → db` e, mais tarde, `backup → db`.

### CHECKPOINT CP6

```text
baseline client → app → db = OK
default-deny = comunicação bloqueada
DNS reaberto sem reabrir HTTP
client → app → db = OK depois das allows
intruder → db = BLOQUEADO
```

**Evidência:** registar `HTTP 200/0` do fluxo permitido e a falha/exit code do `intruder`.

---

# CP7 — Persistência e backup independente

## Objetivo

Provar duas propriedades diferentes:

1. os dados sobrevivem à recriação do Pod PostgreSQL;
2. existe um backup independente, guardado noutro PVC, contendo a evidência criada.

**Executar em:** terminal de administração.

## O que estamos a fazer e porquê

Persistência e backup resolvem problemas diferentes. O PVC mantém dados fora do ciclo de vida do Pod, mas continua a fazer parte do sistema de storage operacional. Um backup é uma cópia independente que pode ser validada e usada num processo de recuperação.

## O que o formando deve perceber

```text
apagar/recriar Pod
→ testa persistência

criar dump noutro PVC
→ testa existência de backup independente

grep da evidência no dump
→ prova que o backup contém o dado criado antes
```

Por isso, “o Pod voltou e os dados estão lá” não é prova de que exista backup.

## Health gate antes da falha controlada

```bash
kubectl get pod postgres-0 -n lab-admin

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready
```

Só avançar se PostgreSQL estiver `Ready` e `/ready` devolver `HTTP 200`.

### Como interpretar

O `get pod` confirma o estado do PostgreSQL e o `curl /ready` confirma a cadeia aplicacional completa. Este health gate separa uma falha introduzida pelo exercício de uma falha já existente.

### O que observar para validar

- `postgres-0` `Ready`;
- `/ready` com `database=ok` e `HTTP 200`.

## 7.1. Parte A — provar persistência

Obter dinamicamente as credenciais não-secretas necessárias ao comando:

```bash
APP_DB=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_DB)
APP_USER=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_USER)

echo "Base de dados: $APP_DB"
echo "Utilizador: $APP_USER"
```

### Como interpretar os comandos

```text
kubectl exec postgres-0 -- printenv POSTGRES_DB
→ lê a variável de ambiente da base de dados dentro do container

kubectl exec postgres-0 -- printenv POSTGRES_USER
→ lê o utilizador configurado no mesmo workload

APP_DB=$(...)
APP_USER=$(...)
→ command substitution: guarda o output do comando em variáveis shell

echo ...
→ torna explícitos os valores que serão usados nos comandos seguintes
```

Desta forma, o guião não assume um nome de base de dados ou utilizador específico.

Criar a evidência usando `psql` dentro do próprio container PostgreSQL:

```bash
kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "CREATE TABLE IF NOT EXISTS teste (id serial PRIMARY KEY, valor text);"

kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "INSERT INTO teste (valor) VALUES ('evidencia-lab-s5');"
```

### Como interpretar `psql`

```text
psql
→ cliente PostgreSQL já disponível na imagem postgres

-U "$APP_USER"
→ utilizador com que a sessão liga à base de dados

-d "$APP_DB"
→ base de dados alvo

-c "..."
→ executa diretamente a instrução SQL fornecida

CREATE TABLE IF NOT EXISTS
→ garante que a tabela existe sem falhar se o laboratório for repetido

INSERT INTO ...
→ cria a evidência que iremos procurar depois da recriação e no backup
```

Não é necessário instalar `psql` no Node de administração porque o cliente é executado dentro do próprio container PostgreSQL.

### O que observar para validar

- `CREATE TABLE` ou mensagem equivalente de sucesso;
- `INSERT 0 1`, confirmando uma linha inserida.

Provocar a recriação do Pod:

```bash
kubectl delete pod postgres-0 -n lab-admin

until kubectl get pod postgres-0 -n lab-admin >/dev/null 2>&1; do
  sleep 1
done

kubectl wait --for=condition=Ready pod/postgres-0 \
  -n lab-admin \
  --timeout=120s
```

### Como interpretar os comandos

```text
kubectl delete pod postgres-0
→ elimina apenas a instância Pod; o StatefulSet continua a desejar uma réplica

until kubectl get pod postgres-0 ...; do sleep 1; done
→ espera que o novo objeto Pod volte a existir na API

>/dev/null 2>&1
→ esconde stdout e stderr enquanto estamos apenas a testar existência

kubectl wait --for=condition=Ready
→ espera que a nova instância esteja realmente pronta antes do SELECT
```

### O que observar para validar

- o Pod é eliminado;
- o StatefulSet recria `postgres-0`;
- o novo Pod fica `Ready`;
- não confundimos “objeto recriado” com “dados preservados”; essa prova vem no `SELECT`.

Validar os dados depois da recriação:

```bash
kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "SELECT * FROM teste;"
```

### Como interpretar

O `SELECT * FROM teste;` lê os dados **depois** da recriação do Pod. Se a linha existir, a evidência sobreviveu ao ciclo de vida do Pod porque ficou no volume persistente.

### O que observar para validar

**Esperado:** o registo `evidencia-lab-s5` continua presente.

Conclusão intermédia:

```text
Pod eliminado
    ↓
Pod recriado
    ↓
mesmo PVC
    ↓
dados preservados
```

## 7.2. Parte B — criar um backup independente

```bash
kubectl apply -f 07-backup/backup-pvc.yaml
kubectl apply -f 07-backup/allow-backup-db.yaml
kubectl apply -f 07-backup/backup-job.yaml

kubectl wait --for=condition=complete \
  job/backup-postgres \
  -n lab-admin \
  --timeout=120s
```

### Como interpretar os comandos

```text
backup-pvc.yaml
→ cria um PVC separado para armazenar o artefacto de backup

allow-backup-db.yaml
→ abre apenas o fluxo de rede necessário do Job de backup para PostgreSQL

backup-job.yaml
→ cria um Job finito que executa o dump

kubectl wait --for=condition=complete job/backup-postgres
→ espera pela condição de conclusão do Job; Ready não é a condição relevante para Jobs

--timeout=120s
→ torna falha de conclusão observável
```

O Job usa a mesma `POSTGRES_DB` da aplicação e, como o `default-deny` continua ativo, recebe apenas os fluxos mínimos necessários através de `allow-backup-db.yaml` e da política DNS já existente.

### O que observar para validar

- o Job atinge `Complete`;
- não existe falha de DNS/rede para PostgreSQL;
- o PVC de backup existe separadamente do PVC de dados.

Se o PVC de backup for `ReadWriteOnce`, eliminar o Job concluído antes de montar o volume no reader:

```bash
kubectl delete job backup-postgres -n lab-admin --wait=true

kubectl apply -f 07-backup/backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader -n lab-admin --timeout=60s
```

### Como interpretar

```text
kubectl delete job backup-postgres --wait=true
→ remove o Job e espera pela eliminação dos seus Pods antes de montar o mesmo PVC noutro Pod

--wait=true
→ não devolve controlo até o recurso ter sido eliminado

backup-reader.yaml
→ cria um Pod temporário cuja função é apenas inspecionar o PVC de backup

kubectl wait --for=condition=Ready pod/backup-reader
→ garante que o volume está montado e o container pronto antes dos exec
```

Esta ordem evita conflitos em ambientes onde o PVC é `ReadWriteOnce`.

Validar o artefacto:

```bash
kubectl exec backup-reader -n lab-admin -- \
  ls -lh /backup/backup.sql

kubectl exec backup-reader -n lab-admin -- \
  wc -c /backup/backup.sql

kubectl exec backup-reader -n lab-admin -- \
  grep -F "evidencia-lab-s5" /backup/backup.sql
```

### Como interpretar os comandos

```text
ls -lh /backup/backup.sql
→ confirma existência e mostra tamanho legível

wc -c /backup/backup.sql
→ devolve o número exato de bytes; tamanho > 0 prova que o ficheiro não está vazio

grep -F "evidencia-lab-s5" /backup/backup.sql
→ procura literalmente a evidência criada; -F trata o padrão como texto fixo
```

### O que observar

- `backup.sql` existe;
- tamanho maior que zero;
- contém `evidencia-lab-s5`;
- `backup-reader` monta o PVC de backup, não o PVC de dados do PostgreSQL.

A regra a reter é:

```text
Pod ≠ dados
PVC ≠ backup
Persistência ≠ backup
```

> Um restore completo fica fora do percurso obrigatório e pode ser tratado como extensão.

### CHECKPOINT CP7

```text
dados preservados após recriação do Pod
Job de backup Complete
backup.sql existe e não está vazio
backup.sql contém evidencia-lab-s5
backup guardado em PVC separado
```

**Evidência:** guardar o `SELECT`, o estado `Complete`, o tamanho do ficheiro e o `grep` da evidência.

---

# CP8 — Evidência final e limpeza

## Objetivo

Fechar o laboratório sem deixar estado cluster-scoped ou storage do exercício por tratar e consolidar as evidências recolhidas.

**Executar em:** terminal de administração.

## O que estamos a fazer e porquê

A limpeza é parte do laboratório. Alguns recursos são namespaced e desaparecem com o Namespace; outros, como Nodes e respetivas labels, são cluster-scoped. O storage pode ainda depender da `reclaimPolicy`.

## O que o formando deve perceber

```text
apagar Namespace
→ remove recursos namespaced

label de Node
→ não é removida pelo Namespace

PVC/PV
→ comportamento final depende da política de reclaim do storage
```

Por isso, a limpeza tem de ser validada e não apenas assumida.

## 8.1. Capturar os PVs do laboratório antes de eliminar o Namespace

```bash
LAB_PVS=$(kubectl get pv \
  -o custom-columns=NAME:.metadata.name,NAMESPACE:.spec.claimRef.namespace \
  --no-headers | awk '$2 == "lab-admin" {print $1}')

echo "PVs do laboratório: ${LAB_PVS:-nenhum}"
```

Guardamos os nomes antes da eliminação para não confundir os PVs desta sessão com volumes de outros exercícios existentes no cluster.

### Como interpretar os comandos e flags

```text
kubectl get pv
→ consulta PVs a nível de cluster

-o custom-columns=NAME:...,NAMESPACE:...
→ mostra apenas o nome do PV e o Namespace do claim associado

--no-headers
→ remove a linha de cabeçalho para facilitar processamento

awk '$2 == "lab-admin" {print $1}'
→ filtra apenas PVs reclamados por PVCs de lab-admin e devolve os nomes

LAB_PVS=$(...)
→ guarda essa lista antes de o Namespace desaparecer

${LAB_PVS:-nenhum}
→ mostra "nenhum" apenas se a variável estiver vazia
```

### O que observar para validar

A lista capturada deve corresponder apenas aos volumes pertencentes ao laboratório atual.

## 8.2. Eliminar o Namespace

```bash
kubectl delete namespace lab-admin --wait=true
```

### Como interpretar

```text
kubectl delete namespace lab-admin --wait=true
→ pede a eliminação do Namespace e espera pela conclusão do processo

--wait=true
→ evita iniciar a limpeza cluster-scoped enquanto os recursos namespaced ainda estão a terminar
```

Eliminar o Namespace elimina os recursos namespaced do laboratório, mas **não remove labels aplicadas a Nodes**, porque Nodes são recursos cluster-scoped.

### O que observar para validar

O comando deve confirmar `namespace "lab-admin" deleted`.

## 8.3. Remover a label criada no CP3 — scheduling

Se a variável ainda existir:

```bash
if [ -z "${WORKER_SSD:-}" ]; then
  WORKER_SSD=$(kubectl get nodes -l disco=ssd -o jsonpath='{.items[0].metadata.name}')
fi

test -n "$WORKER_SSD" || { echo "Worker com disco=ssd não encontrado"; exit 1; }

kubectl label node "$WORKER_SSD" disco-
```

### Como interpretar

```text
[ -z "${WORKER_SSD:-}" ]
→ verifica se a variável não existe ou está vazia

kubectl get nodes -l disco=ssd -o jsonpath=...
→ recupera dinamicamente o Node marcado, caso a shell tenha perdido a variável original

test -n "$WORKER_SSD"
→ impede um comando de label com alvo vazio

kubectl label node "$WORKER_SSD" disco-
→ a sintaxe label- remove a label, em vez de lhe atribuir um valor vazio
```

### O que observar para validar

O output deve indicar que o Node foi `unlabeled`.

## 8.4. Verificar apenas os PVs que pertenciam ao laboratório

```bash
for PV in $LAB_PVS; do
  if kubectl get pv "$PV" >/dev/null 2>&1; then
    kubectl get pv "$PV"
  else
    echo "$PV removido"
  fi
done
```

### Como interpretar os comandos

```text
for PV in $LAB_PVS; do ... done
→ percorre apenas os PVs capturados antes da eliminação

kubectl get pv "$PV" >/dev/null 2>&1
→ testa silenciosamente se o PV ainda existe

if ...; then kubectl get pv "$PV"
→ se existir, mostra o estado para interpretação

else echo "$PV removido"
→ se já não existir, regista explicitamente a remoção
```

### Como interpretar o resultado

- com `reclaimPolicy: Delete`, os PVs provisionados dinamicamente devem desaparecer;
- com `reclaimPolicy: Retain`, podem permanecer e têm de ser tratados pelo procedimento de limpeza do ambiente;
- uma listagem global de PVs não é prova suficiente se o cluster tiver volumes de outros laboratórios.

### O que observar para validar

- Namespace eliminado;
- label `disco=ssd` removida;
- cada PV do laboratório ou desapareceu conforme esperado ou ficou identificado para tratamento segundo a `reclaimPolicy`.

### CHECKPOINT CP8

```text
Namespace lab-admin eliminado
label disco=ssd removida do Worker selecionado
PVs do laboratório identificados e verificados
nenhum recurso do exercício ficou inadvertidamente por tratar
```

**Evidência:** guardar a confirmação da eliminação do Namespace, da remoção da label e o estado final dos PVs capturados.

---

# Síntese: o que deve ser compreendido antes de considerar um checkpoint concluído

Em todos os checkpoints, o formando deve conseguir explicar em voz própria:

```text
1. que estado do cluster existia antes da operação;
2. que objeto/comportamento o comando altera ou observa;
3. porque aquele comando é executado naquele momento;
4. o significado das flags que alteram o seu comportamento;
5. qual é o output/estado esperado;
6. que evidência distingue sucesso real de um simples "comando sem erro";
7. onde procurar a causa se o resultado divergir.
```

O laboratório não deve ser usado como uma lista de comandos para copiar. O objetivo é construir capacidade operacional: **compreender → executar → observar → testar → explicar → avançar**.

---

# Checklist de autoavaliação

No fim da sessão, devo conseguir afirmar:

- [ ] Consigo explicar a diferença entre `LimitRange` e `ResourceQuota`.
- [ ] Consigo interpretar porque um Pod pode ser aceite pela API e ficar `Pending` no scheduler.
- [ ] Consigo distinguir `nodeSelector` de Pod Anti-Affinity.
- [ ] Consigo explicar por que a estratégia de rollout interfere com Anti-Affinity obrigatória.
- [ ] Consigo validar DNS, Service e a dependência aplicação → base de dados.
- [ ] Consigo testar RBAC com uma ação permitida e outra negada.
- [ ] Consigo interpretar os principais campos de um `SecurityContext` de menor privilégio.
- [ ] Consigo explicar `default-deny` e reabrir apenas os fluxos necessários com `NetworkPolicy`.
- [ ] Consigo distinguir persistência de backup.
- [ ] Consigo recolher evidência antes de concluir que uma configuração funciona.

---

# Regra de evidência da Sessão 5

```text
APLICAR
   ≠
VALIDAR

Objeto criado
   ↓
Estado observado
   ↓
Comportamento testado
   ↓
Teste positivo / negativo quando aplicável
   ↓
Evidência recolhida
   ↓
Conclusão técnica
```

Na Sessão 5, uma conclusão só é aceite quando existe evidência do comportamento real: quota rejeitada, placement observado, `FailedScheduling`, `HTTP 200`, ação RBAC negada, fluxo de rede bloqueado, dados preservados ou backup validado.

---

# Mapa final do laboratório

```text
Namespace e governação
        ↓
Aplicação + PostgreSQL + PVC
        ↓
Scheduling e distribuição
        ↓
DNS + Service + readiness
        ↓
ServiceAccount + RBAC + SecurityContext
        ↓
Default deny + allow mínimo
        ↓
Persistência + backup independente
        ↓
Evidências + limpeza
```

---

# Notas de operação para o formador

- Validar antes da formação que o Control Plane não recebe workloads aplicacionais normais.
- Confirmar que nenhum Node possui previamente `disco=ssd`.
- Manter `APP_ENV=prod` na imagem Symfony usada nesta versão.
- Manter `maxSurge: 0` e `maxUnavailable: 1` no patch de Anti-Affinity enquanto o laboratório tiver exatamente dois Workers elegíveis.
- Aguardar sempre os rollouts do CP2 antes de iniciar scheduling.
- Usar `kubectl wait` antes do primeiro `exec` em Pods temporários.
- Confirmar que `allow-dns.yaml` corresponde às labels reais do CoreDNS do cluster.
- Confirmar que `/ready` depende efetivamente do PostgreSQL.
- Obter `POSTGRES_DB` e `POSTGRES_USER` dinamicamente; não exigir `psql` instalado no Node.
- Confirmar que `backup.sql` contém `evidencia-lab-s5`.
- Eliminar o Job antes do `backup-reader` quando o PVC de backup for `ReadWriteOnce`.
- Na limpeza, verificar apenas os PVs cujo `claimRef.namespace` era `lab-admin`.
- Não confundir `PVC`, `backup` e `restore`: são conceitos e operações diferentes.
