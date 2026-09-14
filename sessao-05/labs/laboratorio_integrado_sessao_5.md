# Laboratório Integrado — Sessão 5
## Kubernetes Admin II: Workloads, Networking, Storage, Backup e Recuperação

**Sessão:** 5  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`  
**Kubernetes:** `1.36.4`  
**Cenário:** cluster Kubernetes on-premises com Calico, `local-path-provisioner`, Traefik e Symfony Demo com SQLite

Este laboratório segue a mesma organização pedagógica do laboratório integrado da Sessão 4. O objetivo **não é copiar comandos sem os compreender**. Em cada checkpoint o formando deve conseguir explicar:

```text
O QUE ESTOU A FAZER
        ↓
PORQUE O ESTOU A FAZER
        ↓
QUE OBJETO / COMANDO ESTOU A USAR
        ↓
O QUE SIGNIFICAM AS FLAGS / CAMPOS IMPORTANTES
        ↓
QUAL É O RESULTADO ESPERADO
        ↓
O QUE DEVO OBSERVAR PARA O VALIDAR
        ↓
QUE EVIDÊNCIA PROVA O RESULTADO
```

A regra de trabalho é:

```text
COMPREENDER
    ↓
EXECUTAR MANUALMENTE
    ↓
OBSERVAR
    ↓
REGISTAR EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

> Nomes de Pods, ReplicaSets, UIDs, timestamps, PVs, PVCs e IPs de Pods variam entre execuções. Os outputs apresentados representam a evidência essencial e não texto para comparar carácter a carácter.

> Este laboratório foi validado de ponta a ponta num cluster real com Kubernetes `1.36.4`. Sempre que Events ou nomes gerados variarem entre versões/execuções, deve ser interpretada a causa e não comparado o texto literalmente.

---

# 0. Conceitos que vais comprovar no laboratório

Antes de executar os comandos, é importante perceber **o problema que cada objeto Kubernetes resolve**. Os conceitos seguintes não são teoria isolada: cada um será observado e validado mais à frente através de um checkpoint.

## 0.1. Workloads e Gestão de Pods

### Reconciliação e Deployment

A **reconciliação** é o mecanismo pelo qual os controladores Kubernetes comparam continuamente o **estado desejado** com o **estado observado** e atuam quando existe uma diferença.

Neste laboratório declaramos que deve existir uma réplica da Symfony Demo. Quando eliminamos manualmente o Pod:

```text
estado desejado = 1 réplica
estado observado = 0 réplicas
        ↓
Deployment / ReplicaSet detetam a diferença
        ↓
novo Pod é criado
        ↓
estado observado volta a 1 réplica
```

O objetivo não é “recuperar o mesmo Pod”. O Kubernetes cria **outro objeto Pod**, com nova identidade, para voltar ao estado desejado.

### DaemonSet

Um `DaemonSet` assegura a execução de uma cópia de um Pod em cada **Node elegível**.

Isto é diferente de dizer simplesmente “um Pod em todos os Nodes”. Um Node pode não ser elegível por causa de:

- taints;
- selectors;
- affinity;
- outras restrições de scheduling.

No cluster desta sessão, o Control Plane possui um taint `NoSchedule`. O DaemonSet do laboratório não tem a toleration correspondente, pelo que o resultado esperado é um Pod em cada Worker e nenhum Pod no Control Plane.

### StatefulSet e identidade nominal estável

Um `StatefulSet` atribui identidades previsíveis às suas réplicas:

```text
web-0
web-1
web-2
```

Ao contrário de um Deployment, em que os nomes dos Pods são normalmente descartáveis, o StatefulSet preserva o **nome e o ordinal** da réplica.

Neste laboratório apagamos `web-1`. O objeto Pod antigo desaparece e o seu UID deixa de existir, mas o StatefulSet volta a criar uma réplica chamada:

```text
web-1
```

Portanto:

```text
nome/ordinal estáveis
        ≠
mesmo objeto Pod
```

---

## 0.2. Networking e Exposição de Serviços

### Headless Service e DNS individual

Um Headless Service usa:

```yaml
clusterIP: None
```

Em vez de fornecer um único IP virtual para balanceamento, permite que o DNS do Kubernetes exponha diretamente a identidade das réplicas selecionadas.

Com o StatefulSet `web`, podemos resolver nomes como:

```text
web-0.web.sessao5.svc.cluster.local
web-1.web.sessao5.svc.cluster.local
```

O objetivo é conseguir localizar **uma réplica concreta**.

### Service e EndpointSlice

Um `Service` utiliza um `selector` para descobrir os Pods que devem receber tráfego.

A relação é:

```text
Service
  ↓ selector
labels dos Pods
  ↓
EndpointSlice
  ↓
IPs dos Pods elegíveis
```

No laboratório criamos deliberadamente um Service com um selector incorreto. O Service existe, mas não encontra backends válidos. O diagnóstico é feito comparando:

- selector do Service;
- labels dos Pods;
- `EndpointSlice` gerado.

Isto demonstra que **um Service existir não significa que tenha destinos para onde encaminhar tráfego**.

### Ingress com Traefik

Um `Ingress` descreve regras HTTP de entrada. Neste laboratório essas regras são processadas pelo Traefik.

Fluxo simplificado:

```text
cliente
  ↓ NodePort 30080
Traefik
  ↓ regra Ingress
Service symfony-demo
  ↓
Pod Symfony
```

O Ingress não executa a aplicação nem substitui o Service; define como pedidos HTTP externos devem chegar ao Service.

### Gateway API — Gateway e HTTPRoute

Gateway API separa responsabilidades de forma mais explícita:

```text
GatewayClass
    ↓
Gateway
    ↓
HTTPRoute
    ↓
Service
```

No laboratório:

- `GatewayClass` identifica o controlador Traefik;
- `Gateway` define o ponto de escuta (*listener*);
- `HTTPRoute` define as regras HTTP e o backend.

O `Gateway` aceita tráfego; o `HTTPRoute` determina **como esse tráfego é encaminhado**.

---

## 0.3. Armazenamento — Storage

### PVC e PV

Um `PersistentVolume` (`PV`) representa capacidade de armazenamento disponibilizada ao cluster. Não tem de corresponder literalmente a um único disco físico; é a representação Kubernetes do armazenamento disponível.

Um `PersistentVolumeClaim` (`PVC`) representa o pedido efetuado pelo workload:

```text
Pod
 ↓ usa
PVC
 ↓ pede
StorageClass / provisioner
 ↓ cria ou seleciona
PV
```

Neste laboratório a StorageClass `local-path` cria dinamicamente um PV local no Worker escolhido.

### `WaitForFirstConsumer`

A StorageClass usa:

```text
volumeBindingMode: WaitForFirstConsumer
```

Isto significa que uma PVC pode permanecer `Pending` **de propósito** enquanto ainda não existe um Pod consumidor.

A decisão é adiada para permitir coordenar storage e scheduling:

```text
PVC criada
   ↓
Pending
   ↓
Pod consumidor criado
   ↓
Scheduler escolhe Node
   ↓
provisioner cria PV compatível com esse Node
   ↓
PVC Bound
```

Por isso, neste contexto, `Pending` não é automaticamente uma falha.

### InitContainer

Um `initContainer` é executado **antes** dos containers principais do Pod e tem de terminar com sucesso antes de estes arrancarem.

No cenário Symfony + SQLite usamos um initContainer para semear a PVC na primeira utilização:

```text
PVC vazia
  ↓
initContainer verifica se database.sqlite existe
  ↓
não existe → copia a base inicial da imagem
  ↓
existe → preserva os dados já presentes
  ↓
container Symfony arranca
```

Isto evita dois problemas:

1. montar uma PVC vazia sobre `/var/www/html/data` e esconder a base SQLite fornecida pela imagem;
2. voltar a copiar a base original numa recriação posterior e destruir dados persistentes.

---

## 0.4. Backup, Recuperação e Disaster Recovery

### Job

Um `Job` representa uma tarefa finita que deve terminar com sucesso.

É adequado para operações como:

```text
backup
restore
migração pontual
processamento batch
```

Neste laboratório utilizamos Jobs para criar e restaurar uma cópia consistente da base SQLite.

### CronJob

Um `CronJob` cria Jobs segundo um agendamento.

No laboratório o CronJob fica `suspend: true` para que a aula não dependa da hora real. Criamos depois manualmente um Job a partir do template do CronJob para provar que o template é executável.

### Persistência não é backup

Esta é a mensagem central da sessão.

```text
PERSISTÊNCIA
→ permite que os dados sobrevivam à substituição do Pod
```

```text
BACKUP
→ cria uma cópia independente e recuperável dos dados
```

No laboratório fazemos duas experiências distintas:

```text
CENÁRIO A
Pod eliminado
→ PVC permanece
→ database.sqlite permanece
→ persistência comprovada
```

```text
CENÁRIO B
PVC eliminada
→ storage primário desaparece
→ nova PVC / novo PV
→ restore do backup
→ dados recuperados
```

A cópia de backup é ainda retirada do PVC da aplicação para a máquina administrativa. Isso separa a cópia do **storage primário da aplicação**. Numa estratégia real de Disaster Recovery, o backup deve também estar fora do mesmo domínio de falha do storage/cluster de origem.

Conclusão:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

---

# 1. Como interpretar os comandos e as flags deste laboratório

As opções seguintes aparecem várias vezes. São explicadas aqui para evitar transformar cada checkpoint numa repetição mecânica, voltando a ser destacadas quando o significado contextual é importante.

| Sintaxe | Significado |
|---|---|
| `kubectl get <recurso>` | consulta o estado atual de um recurso |
| `-n <namespace>` | limita o comando ao Namespace indicado |
| `-A` | consulta todos os Namespaces |
| `-o wide` | acrescenta informação operacional como Node e IP |
| `-l chave=valor` | filtra recursos por label |
| `-o jsonpath='...'` | extrai campos concretos do objeto |
| `kubectl apply -f ficheiro.yaml` | cria/atualiza declarativamente os objetos do ficheiro |
| `-f -` | lê o manifesto de `stdin` em vez de um ficheiro |
| `kubectl rollout status` | aguarda e observa a convergência de um controlador |
| `--timeout=300s` | impõe um tempo máximo de espera de 300 segundos |
| `kubectl wait --for=...` | espera explicitamente por uma condição ou evento |
| `kubectl exec` | executa um comando dentro de um container |
| `-i` em `kubectl exec` | mantém `stdin` aberto, necessário quando enviamos conteúdo para o processo |
| `-c <container>` | escolhe um container específico num Pod com vários containers |
| `kubectl delete ... --wait=true` | remove o recurso e aguarda pela conclusão da eliminação |
| `kubectl patch ... -p` | altera apenas uma parte do objeto usando o patch fornecido |
| `kubectl scale --replicas=N` | altera o número de réplicas pretendido |
| `kubectl cp` | copia ficheiros entre a máquina administrativa e um container |
| `kubectl create job --from=cronjob/...` | cria um Job imediato a partir do template de um CronJob |
| `curl -i` | inclui código e cabeçalhos HTTP na resposta |
| `curl -H 'Host: ...'` | envia explicitamente o cabeçalho HTTP `Host` usado pelo routing |
| `test -s ficheiro` | termina com sucesso se o ficheiro existir e não estiver vazio |

Para qualquer comando, a pergunta deve ser:

```text
Que objeto estou a consultar ou alterar?
Que flag muda o comportamento do comando?
Que output prova o resultado?
```

---

# 2. Baseline e percurso

```text
Ubuntu:                    26.04.1 LTS
Control Plane:             k8s-cp-01 / 192.168.50.46
Worker 1:                  k8s-wk-01 / 192.168.50.65
Worker 2:                  k8s-wk-03 / 192.168.50.102
Kubernetes:                1.36.4
containerd:                2.2.6
CNI:                       Calico

StorageClass:              local-path
Provisioner:               rancher.io/local-path
volumeBindingMode:         WaitForFirstConsumer
reclaimPolicy:             Delete
local-path-provisioner:    v0.0.37

Gateway API:               v1.6.1
Helm:                      v3.22.0
Traefik Chart:             41.5.0
Traefik Proxy:             v3.7.13
IngressClass:              traefik
GatewayClass:              traefik
entryPoint web:            8000
HTTP NodePort:             30080
HTTPS NodePort:            30443

Symfony Demo:              v3.1.0
Symfony:                   8.1
PHP:                       8.4
Imagem Symfony:            ghcr.io/skullclamp/symfony-demo:1.1.0
Base de dados:             SQLite
Ficheiro SQLite:           /var/www/html/data/database.sqlite
Namespace do laboratório:  sessao5
```

História técnica:

```text
cluster saudável
      ↓
Deployment Symfony + reconciliação
      ↓
DaemonSet
      ↓
StatefulSet + identidade + Headless DNS
      ↓
PVC → StorageClass → provisioner → PV
      ↓
WaitForFirstConsumer
      ↓
Symfony + SQLite persistente em PVC
      ↓
Service + DNS + EndpointSlice
      ↓
Ingress Traefik
      ↓
GatewayClass → Gateway → HTTPRoute
      ↓
Job de backup SQLite online
      ↓
CronJob
      ↓
backup fora do storage primário
      ↓
perda de Pod → persistência
      ↓
eliminação da PVC → perda lógica
      ↓
restore → integrity_check
```

Todos os comandos administrativos são executados no **`k8s-cp-01`**. Os Workers executam workloads de acordo com o Scheduler e as restrições de storage.

A infraestrutura seguinte deve existir antes do laboratório: Calico, CoreDNS, `local-path-provisioner`, StorageClass `local-path`, Gateway API CRDs, Traefik, IngressClass `traefik`, GatewayClass `traefik` e NodePorts `30080/30443`.

> Nesta sessão a Symfony Demo usa **uma réplica** quando está ligada ao ficheiro SQLite persistente. SQLite é usado para simplificar o caso prático e concentrar a atenção nos mecanismos Kubernetes. O escalamento horizontal da aplicação com estado partilhado não é o objetivo deste exercício.

---

# CP0 — Garantir o repositório e a diretoria de trabalho

## O que estamos a fazer

Garantir que estamos na versão atual da branch `main` e na diretoria a partir da qual os caminhos relativos para `../manifests/` são válidos.

## Porque é necessário

Um comando correto executado na diretoria errada pode falhar apenas porque o ficheiro não é encontrado. Queremos eliminar essa variável antes do laboratório.

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

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short

cd "$REPO_DIR/sessao-05/labs"
pwd
ls ../manifests/
```

### Comandos e flags importantes

- `git -C <dir>` executa o comando Git como se estivéssemos nessa diretoria;
- `switch main` seleciona a branch `main`;
- `pull --ff-only origin main` atualiza apenas por *fast-forward*, evitando criar um merge local inesperado;
- `clone --branch main --single-branch` obtém apenas a branch necessária;
- `pwd` prova a diretoria atual;
- `ls ../manifests/` confirma que os manifests referenciados pelo laboratório estão acessíveis.

### O que observar

```text
branch = main
pwd termina em /formacao-kubernetes/sessao-05/labs
../manifests/ contém os ficheiros da sessão
```

**Checkpoint:** não avançar se a diretoria ou branch não forem as esperadas.

---

# CP1 — Pré-flight e Namespace

## O que estamos a fazer

Confirmar a baseline antes de criar recursos da sessão.

## Porque é necessário

Se um componente base estiver indisponível, uma falha posterior pode ser atribuída ao workload errado. Primeiro provamos que a infraestrutura de que o lab depende está saudável.

```bash
clear
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass local-path
kubectl get pods -n local-path-storage -o wide
kubectl get pods -n traefik -o wide
kubectl get svc -n traefik
kubectl get ingressclass traefik
kubectl get gatewayclass traefik
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
```

### O que significam as opções

- `-o wide` acrescenta Node/IP e outros campos úteis;
- `-A` permite ver Pods de todos os Namespaces;
- `-n local-path-storage` e `-n traefik` tornam explícito onde estamos a procurar componentes de infraestrutura.

### O que observar

Evidência mínima:

```text
k8s-cp-01  Ready
k8s-wk-01  Ready
k8s-wk-03  Ready
StorageClass local-path existente
local-path-provisioner operacional
Traefik operacional
GatewayClass traefik existente/aceite
CRDs Gateway e HTTPRoute instaladas
Traefik Service com NodePorts 30080/30443
```

Criar o Namespace de forma repetível e defini-lo no contexto atual:

```bash
clear
kubectl create namespace sessao5 \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl config set-context --current --namespace=sessao5
kubectl get namespace sessao5
```

### Porque esta forma de criação?

- `--dry-run=client` gera o objeto localmente sem o criar diretamente;
- `-o yaml` transforma o resultado num manifesto;
- `| kubectl apply -f -` envia esse manifesto por `stdin` para `apply`;
- a operação torna-se repetível: se o Namespace já existir, `apply` reconcilia em vez de falhar por duplicação;
- `--current --namespace=sessao5` altera apenas o contexto atual.

### CHECKPOINT CP1

O Namespace `sessao5` existe e a infraestrutura de base está saudável.

---

# CP2 — Deployment Symfony e reconciliação

## O que estamos a fazer

Criar uma réplica da Symfony Demo, observar `Deployment → ReplicaSet → Pod`, eliminar o Pod e verificar que o controlador repõe a réplica.

## Porque é necessário

Queremos provar a reconciliação do estado desejado. Uma única réplica é suficiente e mantém o percurso compatível com a utilização posterior de SQLite.

```bash
clear
kubectl create deployment symfony-demo \
  --image=ghcr.io/skullclamp/symfony-demo:1.1.0 \
  --replicas=1

kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get deployment symfony-demo
kubectl get replicasets
kubectl get pods -l app=symfony-demo -o wide
```

### Flags e argumentos

- `create deployment symfony-demo` cria um Deployment chamado `symfony-demo`;
- `--image=...:1.1.0` define a imagem do container;
- `--replicas=1` declara uma réplica desejada;
- `rollout status` espera pela convergência do Deployment;
- `--timeout=300s` impede uma espera indefinida;
- `-l app=symfony-demo` mostra apenas Pods com essa label;
- `-o wide` permite também observar o Node atribuído.

Guardar a identidade do Pod atual:

```bash
clear
POD_ANTIGO=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')
UID_ANTIGO=$(kubectl get pod "$POD_ANTIGO" \
  -o jsonpath='{.metadata.uid}')
```

`jsonpath` é usado para extrair diretamente o nome e UID em vez de processar todo o YAML.

Eliminar o Pod e observar a reconciliação:

```bash
kubectl delete pod "$POD_ANTIGO" --wait=true
kubectl rollout status deployment/symfony-demo --timeout=300s

POD_NOVO=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')
UID_NOVO=$(kubectl get pod "$POD_NOVO" \
  -o jsonpath='{.metadata.uid}')

echo "POD_ANTIGO=$POD_ANTIGO"
echo "UID_ANTIGO=$UID_ANTIGO"
echo "POD_NOVO=$POD_NOVO"
echo "UID_NOVO=$UID_NOVO"
```

### O que observar

```text
antes: 1 Pod
eliminar Pod
       ↓
ReplicaSet deteta 0/1
       ↓
novo Pod
       ↓
Deployment volta a 1/1
```

O `UID_NOVO` deve ser diferente. O Kubernetes não recuperou o mesmo objeto; criou outro para voltar ao estado desejado.

### CHECKPOINT CP2

- uma réplica continua disponível;
- existe novo Pod/UID;
- o Deployment repôs automaticamente o estado desejado.

---

# CP3 — DaemonSet: um Pod por Node elegível

## O que estamos a fazer

Aplicar um DaemonSet e observar onde as suas réplicas são criadas.

## Porque é necessário

Queremos comprovar que um DaemonSet cria Pods em cada **Node elegível**, respeitando restrições de scheduling como o taint `NoSchedule` do Control Plane.

```bash
clear
kubectl apply -f ../manifests/01-daemonset-demo.yaml
kubectl rollout status daemonset/daemon-demo --timeout=300s
kubectl get daemonset daemon-demo
kubectl get pods -l app=daemon-demo -o wide
```

### Comandos e flags

- `apply -f` aplica o manifesto declarativo;
- `rollout status daemonset/...` acompanha a convergência do DaemonSet;
- `-l app=daemon-demo` seleciona apenas os Pods deste workload;
- `-o wide` é essencial aqui porque precisamos de observar em que Node cada Pod corre.

### O que observar

Com o taint `NoSchedule` do Control Plane:

```text
k8s-wk-01 → 1 Pod
k8s-wk-03 → 1 Pod
k8s-cp-01 → 0 Pods deste DaemonSet
```

Não concluas apenas pelo número total. Confirma a coluna `NODE`.

### CHECKPOINT CP3

O formando consegue explicar por que existem dois Pods e por que o Control Plane não recebeu uma réplica.

---

# CP4 — StatefulSet, ordinais e Headless Service

## O que estamos a fazer

Criar um Headless Service e um StatefulSet de Nginx com três réplicas.

## Porque é necessário

Antes de juntar storage à aplicação, queremos isolar a noção de **identidade estável** e preparar DNS individual por réplica.

```bash
clear
kubectl apply -f ../manifests/02-web-headless.yaml
kubectl apply -f ../manifests/03-web-statefulset.yaml
kubectl rollout status statefulset/web --timeout=300s
kubectl get statefulset web
kubectl get pods -l app=web -o wide
```

### O que observar no YAML

No Headless Service, procurar:

```yaml
clusterIP: None
```

No StatefulSet, relacionar:

```text
serviceName
selector
labels do template
replicas
```

Os selectors do controlador e as labels do template têm de corresponder.

### Resultado esperado

```text
web-0
web-1
web-2
```

Os ordinais fazem parte da identidade das réplicas.

> Um StatefulSet pode existir sem `volumeClaimTemplates`. **Identidade estável e persistência são conceitos diferentes.**

> Um StatefulSet **não garante distribuição por Nodes**. Se as réplicas surgirem em Nodes diferentes, isso é estado observado, não uma garantia do objeto.

### CHECKPOINT CP4

Três réplicas Ready com nomes ordinais previsíveis.

---

# CP5 — Headless DNS individual por Pod

## O que estamos a fazer

Criar um Pod de diagnóstico e resolver os nomes individuais das réplicas do StatefulSet.

## Porque é necessário

Queremos provar que o Headless Service permite localizar uma réplica específica e não apenas um endereço virtual de Service.

```bash
clear
kubectl run debug \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/debug --timeout=120s

kubectl exec debug -- nslookup web-0.web.sessao5.svc.cluster.local
kubectl exec debug -- nslookup web-1.web.sessao5.svc.cluster.local
kubectl get pods -l app=web -o wide
```

### Flags importantes

- `kubectl run debug` cria um Pod simples de diagnóstico;
- `--restart=Never` cria um Pod isolado, não um Deployment;
- `--command -- sleep 3600` substitui o comando por `sleep`, mantendo o Pod vivo;
- `kubectl wait --for=condition=Ready` evita testar DNS antes do Pod estar operacional;
- `kubectl exec debug -- ...` executa `nslookup` dentro da rede do cluster;
- `--` separa opções do `kubectl` do comando executado no container.

### O que observar

Compara o IP devolvido por `nslookup` com os IPs em:

```bash
kubectl get pods -l app=web -o wide
```

### CHECKPOINT CP5

`web-0...` e `web-1...` resolvem para os IPs das respetivas réplicas.

---

# CP6 — Identidade após recriação de uma réplica StatefulSet

## O que estamos a fazer

Guardar o UID de `web-1`, eliminar o Pod e comparar a nova instância.

## Porque é necessário

Queremos provar que a identidade nominal é estável sem confundir essa estabilidade com a sobrevivência do mesmo objeto Pod.

```bash
clear
OLD_UID=$(kubectl get pod web-1 -o jsonpath='{.metadata.uid}')
kubectl delete pod web-1 --wait=true
kubectl wait --for=create pod/web-1 --timeout=120s
kubectl wait --for=condition=Ready pod/web-1 --timeout=300s
NEW_UID=$(kubectl get pod web-1 -o jsonpath='{.metadata.uid}')

echo "OLD_UID=$OLD_UID"
echo "NEW_UID=$NEW_UID"
```

### O que observar

```text
nome     = web-1 novamente
UID      = diferente
ordinal  = 1 novamente
```

Se o UID fosse igual, não teríamos demonstrado a criação de um novo objeto.

### CHECKPOINT CP6

```text
nome estável
+
ordinal estável
+
UID diferente
```

---

# CP7 — PVC, PV e `WaitForFirstConsumer`

## O que estamos a fazer

Criar uma PVC sem consumidor, observar `Pending`, criar um Pod consumidor e observar a transição para `Bound` e a criação dinâmica do PV.

## Porque é necessário

Queremos compreender a cadeia PVC → StorageClass → provisioner → PV e provar que `Pending` pode ser um estado esperado com `WaitForFirstConsumer`.

Criar a PVC:

```bash
clear
kubectl apply -f ../manifests/04-test-pvc.yaml
kubectl get pvc test-pvc
```

### O que observar

Com `WaitForFirstConsumer`:

```text
test-pvc   Pending
```

Isto ainda não prova uma falha.

Criar o consumidor:

```bash
clear
kubectl apply -f ../manifests/05-test-pod.yaml
kubectl wait --for=condition=Ready pod/test-storage --timeout=300s
kubectl get pod test-storage -o wide
kubectl get pvc test-pvc
kubectl get pv
```

Agora esperamos:

```text
PVC Pending → Bound
```

Guardar o nome do PV e inspecioná-lo:

```bash
clear
PV=$(kubectl get pvc test-pvc -o jsonpath='{.spec.volumeName}')
kubectl describe pv "$PV"
```

### O que observar no PV

```text
pv.kubernetes.io/provisioned-by: rancher.io/local-path
Node Affinity: kubernetes.io/hostname in [<NODE>]
Path: /opt/local-path-provisioner/...
```

A `nodeAffinity` do PV mostra que este storage local depende do Worker em que foi criado.

> `local-path-provisioner` é um **external provisioner**, não um driver CSI.

### Troubleshooting — scheduling vs. storage

```text
Pod Pending + NODE=<none> + FailedScheduling
→ problema de elegibilidade/scheduling

PVC Pending sem consumidor + WaitForFirstConsumer
→ estado esperado antes de existir consumidor

PVC continua Pending depois de existir consumidor
→ descrever PVC, Events e provisioner

Pod já tem NODE, mas fica ContainerCreating + FailedMount
→ problema de volume/mount após scheduling
```

### CHECKPOINT CP7

O formando consegue explicar por que a PVC começa `Pending`, quando passa a `Bound` e a relação entre o Node do Pod e a `nodeAffinity` do PV.

---

# CP8 — Persistência sem falso positivo

## O que estamos a fazer

Escrever dados **depois** de o Pod arrancar, eliminar o Pod e recriá-lo sem voltar a escrever o ficheiro.

## Porque é necessário

Se o Pod recriado voltasse a escrever automaticamente o mesmo conteúdo, poderíamos concluir erradamente que os dados vieram do PV. A prova tem de distinguir claramente escrita inicial de leitura posterior.

```bash
clear
kubectl exec test-storage -- \
  sh -c 'echo "Sessao 5 - persistencia OK" > /data/prova.txt'

kubectl exec test-storage -- cat /data/prova.txt
```

`kubectl exec` executa o comando no Pod; `sh -c` permite usar a redireção `>` dentro do container.

Eliminar e recriar o consumidor:

```bash
kubectl delete pod test-storage --wait=true
kubectl apply -f ../manifests/05-test-pod.yaml
kubectl wait --for=condition=Ready pod/test-storage --timeout=300s
kubectl exec test-storage -- cat /data/prova.txt
```

Esperado:

```text
Sessao 5 - persistencia OK
```

### O que observar

No segundo arranque não executamos novamente o `echo`. Apenas lemos o ficheiro. Assim, o valor só pode ter vindo do armazenamento persistente.

Limpar o recurso de teste:

```bash
clear
kubectl delete pod test-storage --wait=true
kubectl delete pvc test-pvc --wait=true
```

### CHECKPOINT CP8

Mesmo valor antes e depois da recriação do Pod, sem reescrita automática.

---

# CP9 — Symfony Demo com SQLite persistente e InitContainer

## O que estamos a fazer

Substituir o Deployment inicial por uma variante que monta uma PVC em `/var/www/html/data` e usa um initContainer para semear a base SQLite apenas na primeira utilização.

## Porque é necessário

A imagem contém uma base inicial em:

```text
/var/www/html/data/database.sqlite
```

Montar uma PVC vazia nesse caminho ocultaria o conteúdo da imagem. O initContainer resolve o bootstrap sem destruir dados posteriores.

Eliminar o Deployment inicial e criar PVC + Deployment:

```bash
clear
kubectl delete deployment symfony-demo --wait=true

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: symfony-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: symfony-demo
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: symfony-demo
  template:
    metadata:
      labels:
        app: symfony-demo
    spec:
      initContainers:
        - name: seed-sqlite
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - sh
            - -c
            - |
              set -eu
              if [ ! -f /mnt-data/database.sqlite ]; then
                cp /var/www/html/data/database.sqlite /mnt-data/database.sqlite
              fi
              chmod 0666 /mnt-data/database.sqlite
          volumeMounts:
            - name: data
              mountPath: /mnt-data
      containers:
        - name: symfony-demo
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 2
          volumeMounts:
            - name: data
              mountPath: /var/www/html/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: symfony-data
EOF
```

### Campos YAML importantes

- `kind: PersistentVolumeClaim` cria o pedido de storage;
- `accessModes: ReadWriteOnce` indica o modo de acesso pedido;
- `storageClassName: local-path` escolhe a classe do laboratório;
- `strategy.type: Recreate` evita sobreposição de dois Pods durante uma atualização deste workload SQLite;
- `initContainers` executa antes do container principal;
- `if [ ! -f ... ]` garante que o seed só acontece se a base ainda não existir;
- `volumeMounts` liga o mesmo volume ao initContainer e à aplicação em caminhos diferentes;
- `persistentVolumeClaim.claimName` associa o volume `data` à PVC `symfony-data`;
- `readinessProbe` só marca o Pod como Ready quando `/health` responde.

Validar:

```bash
kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get pod -l app=symfony-demo -o wide
kubectl get pvc symfony-data
```

### Criar um marcador de laboratório

```bash
clear
POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -i "$POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
$pdo->exec('CREATE TABLE IF NOT EXISTS lab_marker (id INTEGER PRIMARY KEY, valor TEXT NOT NULL)');
$pdo->exec("INSERT OR REPLACE INTO lab_marker (id, valor) VALUES (1, 'persistencia-sessao5-ok')");
echo $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn(), PHP_EOL;
PHP
```

### Flags importantes

- `-i` mantém `stdin` aberto para enviar o bloco PHP ao processo;
- `-c symfony-demo` escolhe o container principal e evita qualquer ambiguidade num Pod com initContainer;
- o bloco PHP cria um marcador determinístico que será usado mais tarde para provar persistência, backup e restore.

Esperado:

```text
persistencia-sessao5-ok
```

Observar o PV associado:

```bash
PV=$(kubectl get pvc symfony-data -o jsonpath='{.spec.volumeName}')
kubectl describe pv "$PV"
```

### CHECKPOINT CP9

```text
Symfony Ready
+
symfony-data Bound
+
marcador criado
+
PV/nodeAffinity identificados
```

---

# CP10 — Service, selector e EndpointSlice

## O que estamos a fazer

Criar deliberadamente um Service com selector errado, observar a ausência de backends válidos e corrigir o selector.

## Porque é necessário

Queremos aprender a diagnosticar a cadeia:

```text
Service
  ↓ selector
labels dos Pods
  ↓
EndpointSlice
  ↓
backends
```

Criar o Service quebrado:

```bash
clear
kubectl apply -f ../manifests/10-symfony-service-broken.yaml
kubectl get service symfony-demo -o yaml
kubectl get pods -l app=symfony-demo --show-labels
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo \
  -o wide
```

### O que observar

```text
Service selector: app=symfony-demo-ERRO
Pod labels:       app=symfony-demo
```

O Service foi aceite pela API, mas não possui destinos corretos.

Corrigir apenas o selector:

```bash
clear
kubectl patch service symfony-demo \
  -p '{"spec":{"selector":{"app":"symfony-demo"}}}'
```

- `patch` altera apenas parte do objeto;
- `-p` fornece o conteúdo do patch JSON.

Revalidar:

```bash
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo \
  -o wide

kubectl exec debug -- wget -qO- http://symfony-demo/health
```

- `wget -qO-` reduz mensagens auxiliares e escreve o corpo da resposta em `stdout`;
- executar dentro de `debug` valida DNS/Service a partir da rede do cluster.

Esperado:

```json
{"status":"ok"}
```

### CHECKPOINT CP10

Depois da correção, o EndpointSlice contém o backend e o Service responde.

---

# CP11 — Ingress com Traefik

## O que estamos a fazer

Criar uma regra Ingress e testar o acesso HTTP a partir da máquina administrativa através do NodePort do Traefik.

## Porque é necessário

Queremos observar a diferença entre:

```text
Service interno
        e
entrada HTTP externa
```

Aplicar e observar:

```bash
clear
kubectl apply -f ../manifests/11-symfony-ingress.yaml
kubectl get ingress symfony-demo
kubectl describe ingress symfony-demo
```

Obter o IP de um Worker:

```bash
WORKER_IP=$(kubectl get node k8s-wk-01 \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

echo "$WORKER_IP"
```

Testar:

```bash
curl -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

### Flags importantes

- `curl -i` mostra código e cabeçalhos HTTP;
- `-H "Host: ..."` envia o hostname usado pela regra de routing;
- `30080` é o NodePort externo do Traefik nesta baseline.

Esperado:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

### Percurso a explicar

```text
cliente :30080
  ↓
Traefik Service :80
  ↓
entryPoint web :8000
  ↓
Ingress
  ↓
Service symfony-demo :80
  ↓
Pod Symfony
```

### CHECKPOINT CP11

O formando consegue explicar cada salto do pedido até ao Pod e demonstra HTTP 200.

---

# CP12 — Gateway API: Gateway e HTTPRoute

## O que estamos a fazer

Interpretar a `GatewayClass` pré-instalada e criar `Gateway` + `HTTPRoute` para a mesma aplicação.

## Porque é necessário

Queremos comparar o modelo Ingress com a separação explícita de responsabilidades da Gateway API.

```bash
clear
kubectl get gatewayclass traefik

kubectl apply -f ../manifests/12-symfony-gateway.yaml
kubectl apply -f ../manifests/13-symfony-httproute.yaml

kubectl wait --for=condition=Accepted gateway/symfony-gateway --timeout=120s
kubectl get gateway symfony-gateway -o wide
kubectl get httproute symfony-demo -o yaml
```

### O que observar

No status do HTTPRoute:

```text
Accepted=True
ResolvedRefs=True
```

- `Accepted=True` indica que o controller aceitou a Route para o parent indicado;
- `ResolvedRefs=True` indica que referências como o Service backend foram resolvidas.

Testar:

```bash
curl -i \
  -H "Host: symfony-gateway.lab" \
  "http://${WORKER_IP}:30080/health"
```

Esperado:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

### Ponto crítico das portas

```text
Gateway listener       8000
        ↓
Traefik entryPoint web 8000
        ↓
Service Traefik          80
        ↓
NodePort               30080
```

O listener do Gateway **não** usa `30080`; `30080` é a porta externa do NodePort.

### CHECKPOINT CP12

Gateway aceite, referências resolvidas e pedido HTTP encaminhado até ao mesmo Service backend.

---

# CP13 — Job de backup SQLite online

## O que estamos a fazer

Criar uma PVC para backups e executar um Job que usa a API `SQLite3::backup()` para produzir uma cópia consistente da base enquanto a aplicação permanece online.

## Porque é necessário

Copiar diretamente um ficheiro SQLite durante escrita pode produzir uma cópia inconsistente. O objetivo não é apenas “ter outro ficheiro”; é criar uma cópia que possa ser validada e restaurada.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: sqlite-online-backup
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: backup
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - php
            - -r
            - |
              $sourcePath = '/source/database.sqlite';
              $backupPath = '/backup/database-online.sqlite';

              if (file_exists($backupPath)) {
                  unlink($backupPath);
              }

              $source = new SQLite3($sourcePath, SQLITE3_OPEN_READONLY);
              $backup = new SQLite3($backupPath);

              if (!$source->backup($backup)) {
                  fwrite(STDERR, "ERRO_BACKUP\n");
                  exit(1);
              }

              $backup->close();
              $source->close();

              $check = new PDO('sqlite:' . $backupPath);
              echo 'MARKER_BACKUP=' .
                  $check->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                  PHP_EOL;

              echo 'INTEGRITY_CHECK=' .
                  $check->query('PRAGMA integrity_check')->fetchColumn() .
                  PHP_EOL;

              echo 'SHA256_BACKUP=' .
                  hash_file('sha256', $backupPath) .
                  PHP_EOL;
          volumeMounts:
            - name: source
              mountPath: /source
              readOnly: true
            - name: backup
              mountPath: /backup
      volumes:
        - name: source
          persistentVolumeClaim:
            claimName: symfony-data
        - name: backup
          persistentVolumeClaim:
            claimName: backup-pvc
EOF
```

### Campos importantes

- `kind: Job` indica tarefa finita;
- `backoffLimit: 1` limita novas tentativas após falha;
- `restartPolicy: Never` impede reinício local infinito do container;
- source é montado `readOnly: true` porque o Job de backup não deve modificar a base original;
- `SQLite3::backup()` cria a cópia através da API SQLite;
- `PRAGMA integrity_check` valida a estrutura lógica da cópia;
- `SHA256_BACKUP` cria uma impressão digital para comparação posterior.

Esperar pela conclusão:

```bash
kubectl wait \
  --for=condition=Complete \
  job/sqlite-online-backup \
  --timeout=300s

kubectl logs job/sqlite-online-backup
kubectl get pvc symfony-data backup-pvc -o wide
kubectl get deployment symfony-demo
```

### O que observar

```text
Job Complete
MARKER_BACKUP=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
Symfony continua disponível
```

Validar saúde HTTP:

```bash
curl -sS -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

- `-sS` reduz output de progresso, mas mantém mensagens de erro;
- `-i` mantém visível o código HTTP.

> `backup-pvc` continua a ser storage `local-path`. Uma cópia noutro PVC do mesmo domínio de storage não substitui um backup independente contra perda física desse Worker.

### CHECKPOINT CP13

Job concluído, marcador presente, `integrity_check=ok`, hash registado e aplicação saudável.

---

# CP14 — CronJob de backup

## O que estamos a fazer

Transformar o mesmo princípio de backup numa tarefa agendada e executar o template manualmente.

## Porque é necessário

Um backup operacional costuma ser recorrente. O CronJob acrescenta a dimensão temporal sem alterar o princípio do Job.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sqlite-backup-daily
spec:
  schedule: "0 3 * * *"
  timeZone: Europe/Lisbon
  suspend: true
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: backup
              image: ghcr.io/skullclamp/symfony-demo:1.1.0
              command:
                - php
                - -r
                - |
                  $sourcePath = '/source/database.sqlite';
                  $backupPath = '/backup/database-cron.sqlite';

                  if (file_exists($backupPath)) {
                      unlink($backupPath);
                  }

                  $source = new SQLite3($sourcePath, SQLITE3_OPEN_READONLY);
                  $backup = new SQLite3($backupPath);

                  if (!$source->backup($backup)) {
                      fwrite(STDERR, "ERRO_BACKUP\n");
                      exit(1);
                  }

                  $backup->close();
                  $source->close();

                  $check = new PDO('sqlite:' . $backupPath);
                  echo 'MARKER_CRON=' .
                      $check->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                      PHP_EOL;
                  echo 'INTEGRITY_CHECK=' .
                      $check->query('PRAGMA integrity_check')->fetchColumn() .
                      PHP_EOL;
          volumeMounts:
            - name: source
              mountPath: /source
              readOnly: true
            - name: backup
              mountPath: /backup
          volumes:
            - name: source
              persistentVolumeClaim:
                claimName: symfony-data
            - name: backup
              persistentVolumeClaim:
                claimName: backup-pvc
EOF
```

### Campos importantes

- `schedule: "0 3 * * *"` representa 03:00 diariamente;
- `timeZone: Europe/Lisbon` torna explícito o fuso do agendamento;
- `suspend: true` impede execução automática durante a aula;
- `concurrencyPolicy: Forbid` impede execuções sobrepostas;
- `jobTemplate` é o modelo a partir do qual o CronJob cria Jobs.

Observar e executar manualmente:

```bash
kubectl get cronjob sqlite-backup-daily -o wide

kubectl create job \
  --from=cronjob/sqlite-backup-daily \
  sqlite-backup-manual

kubectl wait \
  --for=condition=Complete \
  job/sqlite-backup-manual \
  --timeout=300s

kubectl logs job/sqlite-backup-manual
```

`--from=cronjob/...` copia o `jobTemplate` do CronJob para um Job imediato.

Esperado:

```text
MARKER_CRON=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
```

### CHECKPOINT CP14

O formando consegue explicar a relação `CronJob → Job → Pod` e provar que o template agendado produz um backup válido.

---

# CP15 — Retirar uma cópia do storage primário

## O que estamos a fazer

Montar a `backup-pvc` num Pod leitor e copiar `database-online.sqlite` para a máquina administrativa.

## Porque é necessário

Um backup guardado apenas no mesmo storage Kubernetes continua exposto a parte dos mesmos domínios de falha. Queremos pelo menos separar a cópia do PVC primário da aplicação e praticar a extração do artefacto.

Criar o leitor:

```bash
clear
kubectl apply -f ../manifests/17-backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader --timeout=300s
kubectl exec backup-reader -- ls -lh /backup
```

Copiar:

```bash
clear
kubectl cp \
  backup-reader:/backup/database-online.sqlite \
  ./database-online.sqlite

test -s ./database-online.sqlite
ls -lh ./database-online.sqlite
kubectl delete pod backup-reader --wait=true
```

### Comandos e flags

- `kubectl cp origem destino` copia o ficheiro do container para a máquina onde `kubectl` está a ser executado;
- `test -s` valida que o ficheiro existe e não está vazio;
- `ls -lh` mostra tamanho em formato legível.

### O que observar

```text
database-online.sqlite existe localmente
+
tamanho > 0
```

> Isto coloca a cópia **fora do PVC/storage primário da aplicação**. Numa estratégia real, a cópia deve ainda ser transferida para armazenamento independente do mesmo cluster/domínio de falha.

### CHECKPOINT CP15

Existe uma cópia local não vazia e o formando consegue explicar por que persistência e backup continuam a ser conceitos distintos.

---

# CP16 — Falha controlada A: perda do Pod da aplicação

## O que estamos a fazer

Eliminar apenas o Pod Symfony, mantendo a PVC intacta.

## Porque é necessário

Queremos demonstrar uma falha de processo/Pod que deve ser recuperada pela combinação:

```text
Deployment + PVC
```

sem utilizar o backup.

```bash
clear
POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$POD" --wait=true
kubectl rollout status deployment/symfony-demo --timeout=300s

NEW_POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')
```

Consultar apenas o marcador existente:

```bash
kubectl exec -i "$NEW_POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
echo $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn(), PHP_EOL;
PHP
```

Esperado:

```text
persistencia-sessao5-ok
```

### O que observar

```text
perda do Pod
→ Deployment reconcilia
→ mesma PVC
→ mesmo database.sqlite
→ marcador continua presente
→ PERSISTÊNCIA comprovada
```

Não foi necessário restaurar qualquer backup.

### CHECKPOINT CP16

Dados sobrevivem à recriação do Pod exclusivamente através da persistência.

---

# CP17 — Falha controlada B: eliminação lógica da PVC

## O que estamos a fazer

Remover o consumidor, eliminar a PVC `symfony-data` e observar a remoção do PV antigo com `reclaimPolicy: Delete`.

## Porque é necessário

Queremos criar um cenário em que **a persistência já não é suficiente**. É aqui que a existência de uma cópia de backup passa a ser necessária.

Primeiro remover Jobs que possam manter volumes em utilização e parar a aplicação:

```bash
clear
kubectl delete job sqlite-online-backup sqlite-backup-manual \
  --ignore-not-found \
  --wait=true

kubectl scale deployment/symfony-demo --replicas=0
kubectl wait \
  --for=delete pod \
  -l app=symfony-demo \
  --timeout=120s || true
```

### Flags importantes

- `--ignore-not-found` torna a limpeza idempotente;
- `--replicas=0` declara que o Deployment deve ficar temporariamente sem Pods;
- `--for=delete` espera pela eliminação dos Pods;
- `|| true` impede que uma ausência já resolvida interrompa a sequência.

Guardar o PV antigo e eliminar a PVC:

```bash
clear
OLD_PV=$(kubectl get pvc symfony-data \
  -o jsonpath='{.spec.volumeName}')

echo "OLD_PV=$OLD_PV"

kubectl delete pvc symfony-data --wait=true

for i in $(seq 1 60); do
  if ! kubectl get pv "$OLD_PV" >/dev/null 2>&1; then
    echo "PV_ANTIGO_REMOVIDO=SIM"
    break
  fi
  sleep 2
done

kubectl get pv "$OLD_PV" 2>&1 || true
```

### O que observar

Com `reclaimPolicy: Delete`, o PV antigo deixa de existir depois da eliminação da claim.

> Este cenário representa **perda lógica da PVC**. Não representa perda física do Worker.

### CHECKPOINT CP17

A PVC primária foi eliminada e o PV antigo já não está disponível. A recuperação passa agora a depender do backup.

---

# CP18 — Restore para uma nova PVC/PV

## O que estamos a fazer

Criar uma nova PVC, criar um Job de restore e repor `database.sqlite` a partir de `backup-pvc`.

## Porque é necessário

Um backup só demonstra valor quando conseguimos **recuperar dados e validar a aplicação depois do restore**.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: symfony-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: sqlite-restore
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: restore
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - php
            - -r
            - |
              $source = '/backup/database-online.sqlite';
              $restore = '/restore/database.sqlite';

              if (!file_exists($source)) {
                  fwrite(STDERR, "BACKUP_NAO_ENCONTRADO\n");
                  exit(1);
              }

              if (!copy($source, $restore)) {
                  fwrite(STDERR, "ERRO_RESTORE\n");
                  exit(1);
              }

              chmod($restore, 0666);

              $pdo = new PDO('sqlite:' . $restore);
              echo 'MARKER_RESTORE=' .
                  $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                  PHP_EOL;

              $integrity = $pdo->query('PRAGMA integrity_check')->fetchColumn();
              echo 'INTEGRITY_CHECK=' . $integrity . PHP_EOL;

              echo 'SHA256_BACKUP=' . hash_file('sha256', $source) . PHP_EOL;
              echo 'SHA256_RESTORE=' . hash_file('sha256', $restore) . PHP_EOL;

              if ($integrity !== 'ok') {
                  fwrite(STDERR, "INTEGRIDADE_INVALIDA\n");
                  exit(1);
              }
          volumeMounts:
            - name: backup
              mountPath: /backup
              readOnly: true
            - name: restore
              mountPath: /restore
      volumes:
        - name: backup
          persistentVolumeClaim:
            claimName: backup-pvc
        - name: restore
          persistentVolumeClaim:
            claimName: symfony-data
EOF
```

### O que observar no manifesto

- o backup é montado `readOnly`;
- a nova PVC é montada em `/restore`;
- o Job falha se o backup não existir ou não puder ser copiado;
- `PRAGMA integrity_check` tem de devolver `ok`;
- os hashes do backup e do ficheiro restaurado devem ser iguais.

Esperar e validar:

```bash
kubectl wait \
  --for=condition=Complete \
  job/sqlite-restore \
  --timeout=300s

kubectl logs job/sqlite-restore
kubectl get pvc symfony-data backup-pvc -o wide
```

Esperado:

```text
MARKER_RESTORE=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
SHA256_RESTORE=<mesmo hash>
```

Reativar a aplicação:

```bash
clear
kubectl scale deployment/symfony-demo --replicas=1
kubectl rollout status deployment/symfony-demo --timeout=300s

POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -i "$POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
echo 'MARKER_FINAL=' .
    $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
    PHP_EOL;
echo 'INTEGRITY_FINAL=' .
    $pdo->query('PRAGMA integrity_check')->fetchColumn() .
    PHP_EOL;
PHP

curl -sS -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

Esperado:

```text
MARKER_FINAL=persistencia-sessao5-ok
INTEGRITY_FINAL=ok
HTTP/1.1 200 OK
{"status":"ok"}
```

Observar que o PV é novo:

```bash
clear
NEW_PV=$(kubectl get pvc symfony-data \
  -o jsonpath='{.spec.volumeName}')

echo "OLD_PV=$OLD_PV"
echo "NEW_PV=$NEW_PV"

kubectl get pod -l app=symfony-demo -o wide
kubectl get pvc -o wide
kubectl describe pv "$NEW_PV"
```

### CHECKPOINT CP18

```text
OLD_PV != NEW_PV
+
marcador recuperado
+
integrity_check=ok
+
hashes iguais
+
HTTP 200
```

Isto demonstra recuperação para **novo storage**, não apenas reutilização do volume antigo.

---

# CP19 — Síntese, evidências e limpeza

## O que devemos conseguir explicar

### Cenário A — perda do Pod

```text
Pod desaparece
   ↓
Deployment reconcilia
   ↓
PVC mantém-se
   ↓
database.sqlite mantém-se
   ↓
PERSISTÊNCIA
```

### Cenário B — perda lógica da PVC

```text
storage primário desaparece
   ↓
PV antigo é removido
   ↓
nova PVC / novo PV
   ↓
restore a partir do backup
   ↓
PRAGMA integrity_check = ok
   ↓
BACKUP + RECUPERAÇÃO
```

Conclusão:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

## Checklist final de autoavaliação

- [ ] Consigo explicar a relação `Deployment → ReplicaSet → Pod` e demonstrar reconciliação.
- [ ] Sei explicar o que muda e o que se mantém quando um Pod é substituído.
- [ ] Consigo explicar por que um DaemonSet cria Pods apenas nos Nodes elegíveis.
- [ ] Distingo identidade estável de StatefulSet de persistência de dados.
- [ ] Consigo validar DNS individual de Pods através de um Headless Service.
- [ ] Consigo explicar por que o nome `web-1` pode manter-se enquanto o UID do Pod muda.
- [ ] Distingo Service, selector, EndpointSlice e backend.
- [ ] Consigo explicar o percurso HTTP de Ingress até ao Pod.
- [ ] Distingo `GatewayClass`, `Gateway` e `HTTPRoute`.
- [ ] Distingo PVC de PV e consigo explicar a cadeia de dynamic provisioning.
- [ ] Consigo explicar `WaitForFirstConsumer` e distinguir um `Pending` esperado de uma falha.
- [ ] Consigo distinguir falha de scheduling de falha de provisionamento/mount usando `describe` e Events.
- [ ] Consigo identificar o PV criado dinamicamente e interpretar a respetiva `nodeAffinity`.
- [ ] Consigo provar persistência sem criar um falso positivo no arranque do Pod.
- [ ] Consigo explicar o papel do `initContainer` no seed da base SQLite.
- [ ] Consigo executar e validar um backup SQLite online através de um Job.
- [ ] Consigo explicar a finalidade de um CronJob e a relação `CronJob → Job → Pod`.
- [ ] Sei usar `PRAGMA integrity_check` como evidência de consistência do backup/restore.
- [ ] Sei explicar por que um backup mantido apenas noutro PVC local não protege contra perda física do Worker.
- [ ] Consigo provar que a perda do Pod é recuperada pela persistência sem recorrer ao backup.
- [ ] Consigo explicar a diferença entre perda do Pod, perda lógica da PVC e perda física do Node/storage.
- [ ] Consigo restaurar a aplicação para uma nova PVC/PV e validar marcador, integridade, hash e health endpoint.
- [ ] Para os comandos principais consigo explicar **o que fazem, porque são usados, as flags relevantes e o output que valida o resultado**.
- [ ] Distingo claramente **persistência**, **backup** e **Alta Disponibilidade**.

## Regra de evidência da Sessão 5

O laboratório fica concluído quando o formando consegue **apresentar e explicar**, e não apenas executar:

```text
Deployment reconciliado após perda de Pod
+
DaemonSet apenas nos Nodes elegíveis
+
StatefulSet com identidade nominal demonstrada
+
Headless DNS validado
+
PVC Pending antes do consumidor por WaitForFirstConsumer
+
PVC Bound e PV dinamicamente criado depois do consumidor
+
camada da falha identificada por NODE / PVC / Events / mount
+
persistência comprovada sem falso positivo
+
InitContainer de seed explicado
+
Service quebrado diagnosticado por selector + EndpointSlice
+
Ingress funcional e percurso explicado
+
Gateway + HTTPRoute aceites e resolvidos
+
backup SQLite online com integrity_check=ok
+
CronJob compreendido e execução manual validada
+
backup copiado para fora do storage primário da aplicação
+
perda do Pod recuperada pela persistência
+
eliminação lógica da PVC demonstrada
+
nova PVC / novo PV após restore
+
aplicação saudável e dados recuperados
+
PERSISTÊNCIA ≠ BACKUP ≠ ALTA DISPONIBILIDADE
```

## Limpeza

```bash
clear
kubectl config set-context --current --namespace=default
kubectl delete namespace sessao5 --wait=true
rm -f ./database-online.sqlite
```

### Porque limpar desta forma?

- repomos o Namespace por omissão antes de eliminar `sessao5`;
- eliminar o Namespace remove os recursos namespaced criados pelo laboratório;
- removemos a cópia local apenas no final, depois de concluída a validação de restore.

Não remover:

```text
Calico
CoreDNS
Traefik
GatewayClass traefik
Gateway API CRDs
local-path-provisioner
StorageClass local-path
```

Esses componentes pertencem à infraestrutura base e serão reutilizados noutras sessões.

---

# Troubleshooting — ordem mínima de evidência

Quando algo falhar, não corrigir imediatamente. Seguir:

```text
SINTOMA
  ↓
kubectl get
  ↓
kubectl describe
  ↓
Events
  ↓
logs quando aplicável
  ↓
selectors / EndpointSlices / PVC / conditions
  ↓
CLASSIFICAR A CAMADA
  ↓
HIPÓTESE
  ↓
CORREÇÃO MÍNIMA
  ↓
VALIDAÇÃO
```

Perguntas de diagnóstico:

```text
O Pod ainda não tem Node?
→ scheduling

O Pod tem Node mas não inicia e existem FailedMount/erros de volume?
→ storage/mount

A PVC continua Pending?
→ validar WaitForFirstConsumer, consumidor, provisioner e Events

O Service não tem backends?
→ selector/labels/EndpointSlice

Ingress/Gateway foram aceites mas o backend não responde?
→ validar Service e EndpointSlice antes de culpar o controller

O Job terminou com Failed?
→ kubectl describe job + logs do Pod do Job
```

Não acrescentar flags aleatórias, não apagar recursos indiscriminadamente e não confundir um estado transitório com uma falha persistente.