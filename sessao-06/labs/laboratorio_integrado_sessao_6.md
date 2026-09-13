# Laboratório Integrado — Sessão 6
## Kubernetes Admin III: Recursos, Scheduling e Segurança

**Sessão:** 6  
**Módulo:** M9 — Recursos, Scheduling e Segurança  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Foco:** **GOVERNAR O CLUSTER**  
**Topologia:** `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`  
**Runtime:** containerd  
**CNI:** Calico  
**Namespace:** `s6-governance`

Este ficheiro acompanha a componente prática de toda a Sessão 6. O objetivo não é copiar uma sequência de comandos: em cada checkpoint deve ser possível explicar **que regra estamos a introduzir, onde essa regra é aplicada e que evidência demonstra o seu efeito**.

A sequência pedagógica é:

```text
MEDIR / OBSERVAR
      ↓
DECLARAR NECESSIDADES
      ↓
IMPOR LIMITES
      ↓
CONDICIONAR PLACEMENT
      ↓
ATRIBUIR IDENTIDADE
      ↓
AUTORIZAR O MÍNIMO NECESSÁRIO
      ↓
REDUZIR PRIVILÉGIOS DO PROCESSO
      ↓
PROTEGER DADOS SENSÍVEIS
      ↓
SEGMENTAR A REDE
      ↓
PROVOCAR / TESTAR
      ↓
RECOLHER EVIDÊNCIA
      ↓
EXPLICAR O RESULTADO
```

Em cada checkpoint utilizamos a mesma regra:

```text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
COMANDO / MANIFESTO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
OUTPUT ESPERADO
        ↓
O QUE OBSERVAR
        ↓
TESTE NEGATIVO
        ↓
EVIDÊNCIA
```

> Nomes de Pods, UIDs, timestamps, IPs e algumas mensagens de Events podem variar entre execuções. Os outputs apresentados representam a evidência essencial e não texto para comparar carácter a carácter.

> Este laboratório foi validado de ponta a ponta num cluster real com Kubernetes v1.36.4, containerd e Calico. Sempre que um Event variar entre versões, deve ser interpretada a causa e não comparado o texto literalmente.

---

# 0. Baseline e diretoria de trabalho

A Sessão 6 reutiliza o cluster construído e administrado nas sessões anteriores.

Baseline de referência:

```text
Control Plane:             k8s-cp-01
Worker 1:                  k8s-wk-01
Worker 2:                  k8s-wk-03
Runtime:                   containerd
CNI:                       Calico
Namespace do laboratório:  s6-governance
```

O Control Plane deve permanecer fora dos workloads normais. Os exercícios de scheduling utilizam os dois Worker Nodes.

## 0.1. Garantir o repositório e entrar na diretoria de trabalho

Uma shell nova pode abrir em `$HOME` e não dentro do repositório Git. O bloco seguinte funciona tanto quando o repositório já existe como numa primeira utilização:

```bash
clear

if [ -d "$HOME/formacao-kubernetes/.git" ]; then
  cd "$HOME/formacao-kubernetes"
  git pull --ff-only
else
  cd "$HOME"
  git clone https://github.com/Skullclamp/formacao-kubernetes.git
  cd "$HOME/formacao-kubernetes"
fi

git branch --show-current
git status --short

cd sessao-06/labs
pwd
```

### O que faz este bloco

- `-d` testa se a diretoria `.git` já existe;
- `git pull --ff-only` atualiza o clone apenas quando é possível fazer fast-forward, evitando criar um merge inesperado;
- `git branch --show-current` confirma a branch ativa;
- `git status --short` evidencia alterações locais antes do laboratório;
- `pwd` confirma a diretoria de trabalho.

O final de `pwd` deve ser:

```text
/formacao-kubernetes/sessao-06/labs
```

---

# CP1 — Pré-flight, CNI e Namespace

## O que estamos a fazer

Confirmar que a infraestrutura base está operacional **antes** de criar regras de governação.

## Porque é necessário

Se Calico, CoreDNS ou um Worker estiverem indisponíveis, uma falha posterior pode ser atribuída incorretamente a ResourceQuota, scheduling, RBAC ou NetworkPolicy.

Executar:

```bash
clear
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system
kubectl get networkpolicy -A
kubectl get events -A --sort-by=.lastTimestamp | tail -n 30
```

### Flags e opções

- `-A` / `--all-namespaces` consulta recursos em todos os Namespaces;
- `-o wide` acrescenta informação como IP e Node;
- `-n kube-system` limita a consulta ao Namespace `kube-system`;
- `--show-labels` mostra labels, úteis mais tarde para identificar CoreDNS;
- `--sort-by=.lastTimestamp` ordena Events pelo timestamp indicado;
- `tail -n 30` limita o output aos últimos 30 registos apresentados.

### Evidência mínima

```text
k8s-cp-01  Ready
k8s-wk-01  Ready
k8s-wk-03  Ready
Calico     operacional
CoreDNS    operacional
```

## 1.1. Criar o Namespace de forma repetível

```bash
kubectl create namespace s6-governance \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl config set-context --current --namespace=s6-governance
kubectl get namespace s6-governance
```

### Porque usamos `--dry-run=client -o yaml | kubectl apply -f -`?

O comando produz o manifesto do Namespace e entrega-o a `kubectl apply`. Assim, uma segunda execução não falha apenas porque o Namespace já existe.

> Mesmo com o Namespace configurado no contexto, vários comandos deste laboratório mantêm `-n s6-governance` para tornar o escopo explícito.

## 1.2. Smoke-test do CNI em cada Worker

Ver um DaemonSet `calico-node` em `Running` não prova, por si só, que um novo Pod consegue criar a respetiva sandbox de rede. Vamos criar um pequeno Pod em cada Worker e confirmar que ambos recebem IP.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cni-smoke-wk01
  namespace: s6-governance
spec:
  nodeName: k8s-wk-01
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "sleep 300"]
      resources:
        requests:
          cpu: "10m"
          memory: "16Mi"
        limits:
          cpu: "50m"
          memory: "64Mi"
---
apiVersion: v1
kind: Pod
metadata:
  name: cni-smoke-wk03
  namespace: s6-governance
spec:
  nodeName: k8s-wk-03
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "sleep 300"]
      resources:
        requests:
          cpu: "10m"
          memory: "16Mi"
        limits:
          cpu: "50m"
          memory: "64Mi"
EOF

kubectl wait --for=condition=Ready pod/cni-smoke-wk01 \
  -n s6-governance --timeout=120s
kubectl wait --for=condition=Ready pod/cni-smoke-wk03 \
  -n s6-governance --timeout=120s

kubectl get pods -n s6-governance \
  -l '!does-not-exist' \
  -o wide | grep cni-smoke
```

Esperado: ambos os Pods `Running`, cada um no Worker indicado, com um IP atribuído pelo CNI.

> Aqui `nodeName` é deliberado: não estamos a testar o Scheduler; estamos a isolar a capacidade do kubelet/CNI para criar um novo Pod em cada Worker.

Se um Pod tiver `NODE` atribuído mas ficar em `ContainerCreating`, inspecionar:

```bash
kubectl describe pod cni-smoke-wk03 -n s6-governance
kubectl get pods -n kube-system -o wide | grep calico-node
```

Um `FailedCreatePodSandBox` é uma falha de runtime/CNI **depois** do placement e não um `FailedScheduling`.

Limpar o smoke-test:

```bash
kubectl delete pod cni-smoke-wk01 cni-smoke-wk03 \
  -n s6-governance
```

---

# CP2 — Capacity, Allocatable, Requests e Limits

## O que estamos a fazer

Observar primeiro a capacidade dos Nodes e depois declarar os recursos de um Pod.

## Porque é necessário

O Scheduler **contabiliza os `requests` como necessidade declarada** para decidir se um Pod é elegível para um Node. Isto não significa que reserve antecipadamente esse valor como utilização instantânea. Os `limits` definem o teto de utilização imposto ao container.

Consultar os Workers:

```bash
clear
kubectl describe node k8s-wk-01
kubectl describe node k8s-wk-03
```

Procurar:

```text
Capacity:
Allocatable:
Allocated resources:
```

### Interpretação

```text
Capacity
   ↓
capacidade total reportada pelo Node

Allocatable
   ↓
capacidade que Kubernetes considera disponível para Pods

Requests declarados
   ↓
necessidade contabilizada pelo Scheduler para elegibilidade
```

Criar um Pod com `requests` e `limits`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resources-demo
  namespace: s6-governance
  labels:
    app: resources-demo
spec:
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "250m"
          memory: "128Mi"
EOF
```

### Flags e sintaxe

- `kubectl apply` cria ou atualiza declarativamente um objeto;
- `-f -` indica que o manifesto é lido de **stdin** em vez de um ficheiro;
- `100m` significa `0,1` CPU;
- `64Mi` representa 64 MiB de memória binária;
- `requests` participam na decisão de scheduling;
- `limits` definem o teto de utilização do container.

Validar:

```bash
kubectl wait --for=condition=Ready pod/resources-demo \
  -n s6-governance --timeout=120s

kubectl get pod resources-demo -n s6-governance -o wide
kubectl describe pod resources-demo -n s6-governance

kubectl get pod resources-demo \
  -n s6-governance \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

No `describe`, localizar:

```text
Requests:
Limits:
Node:
```

## Teste negativo — request impossível

Antes de aplicar quotas, vamos provocar um caso em que o Pod é admitido pela API, mas não pode ser colocado em nenhum Node.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resources-impossible
  namespace: s6-governance
spec:
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "100"
          memory: "64Mi"
EOF
```

Observar:

```bash
kubectl get pod resources-impossible -n s6-governance -o wide
kubectl describe pod resources-impossible -n s6-governance
kubectl get events -n s6-governance \
  --field-selector involvedObject.name=resources-impossible \
  --sort-by=.lastTimestamp
```

Esperado:

```text
STATUS: Pending
NODE:   <none>
Event:  FailedScheduling
```

### Pergunta

> Porque é que o Pod existe na API mas continua `Pending`?

Porque o pedido foi aceite pela API, mas o Scheduler não encontrou nenhum Node com recursos suficientes para satisfazer o `request` declarado.

> O texto exato de `FailedScheduling` pode variar entre versões. A evidência essencial é a ausência de Node e a causa apresentada no Event.

Limpar o teste:

```bash
kubectl delete pod resources-impossible -n s6-governance
```

---

# CP3 — LimitRange e ResourceQuota

## O que estamos a fazer

Aplicar regras de recursos ao Namespace em dois níveis:

```text
LimitRange
   ↓
valores por container

ResourceQuota
   ↓
consumo agregado do Namespace
```

## 3.1. Aplicar LimitRange

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: container-policy
  namespace: s6-governance
spec:
  limits:
    - type: Container
      min:
        cpu: "10m"
        memory: "16Mi"
      max:
        cpu: "4"
        memory: "2Gi"
      defaultRequest:
        cpu: "100m"
        memory: "64Mi"
      default:
        cpu: "500m"
        memory: "256Mi"
EOF
```

Validar:

```bash
kubectl get limitrange -n s6-governance
kubectl describe limitrange container-policy -n s6-governance
```

### Campos importantes

- `min` define o mínimo permitido;
- `max` define o máximo permitido;
- `defaultRequest` é aplicado quando o container não declara request;
- `default` define o limit por omissão.

## 3.2. Confirmar defaults e ausência de retroatividade

Criar um Pod sem `resources`:

```bash
kubectl run defaulted-resources \
  --image=nginx:stable-alpine \
  --restart=Never \
  -n s6-governance
```

Observar os valores efetivos:

```bash
kubectl get pod defaulted-resources \
  -n s6-governance \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

Esperado:

```text
defaultRequest → cpu 100m / memory 64Mi
default        → cpu 500m / memory 256Mi
```

Comparar com o Pod criado antes do `LimitRange`:

```bash
kubectl get pod resources-demo \
  -n s6-governance \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

O `LimitRange` atua em admission/criação e **não altera retroativamente** objetos já existentes.

## 3.3. Aplicar ResourceQuota

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: s6-governance
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    pods: "20"
EOF
```

Consultar:

```bash
kubectl get resourcequota -n s6-governance
kubectl describe resourcequota namespace-quota -n s6-governance
```

Procurar `Used` e `Hard`.

## Teste negativo — exceder a quota

O próximo Pod pede `3 CPU`. Este valor está **dentro** do máximo individual do `LimitRange` (`4`), mas excede a quota agregada de `requests.cpu` (`2`). Assim, o exercício testa exatamente `ResourceQuota`.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-exceeded
  namespace: s6-governance
spec:
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "3"
          memory: "64Mi"
        limits:
          cpu: "3"
          memory: "128Mi"
EOF
```

Esperado: `Forbidden`, com referência a `namespace-quota` e `requests.cpu`.

Confirmar que o Pod não chegou a existir:

```bash
kubectl get pod quota-exceeded -n s6-governance
```

### Pergunta

> Esta falha ocorreu em admission ou no Scheduler?

Neste caso, o objeto é rejeitado em admission antes de chegar ao Scheduler, porque a criação faria ultrapassar a `ResourceQuota`.

Comparação essencial:

```text
resources-impossible
API aceita → objeto existe → Scheduler não encontra Node → Pending

quota-exceeded
Admission rejeita → objeto não existe → Scheduler nunca o recebe
```

---

# CP4 — Labels, nodeSelector e Node Affinity

## O que estamos a fazer

Passar de “qualquer Worker disponível” para “Workers que satisfazem uma regra explícita de placement”.

Escolher um Worker:

```bash
clear
kubectl get nodes
export LAB_WORKER=k8s-wk-01
```

Adicionar uma label própria da formação:

```bash
kubectl label node "$LAB_WORKER" \
  training.goldconsulting/workload=apps
```

Confirmar:

```bash
kubectl get nodes -L training.goldconsulting/workload
```

## 4.1. nodeSelector

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-selector-demo
  namespace: s6-governance
spec:
  nodeSelector:
    training.goldconsulting/workload: apps
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "50m"
          memory: "32Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
EOF
```

Validar:

```bash
kubectl wait --for=condition=Ready pod/node-selector-demo \
  -n s6-governance --timeout=120s
kubectl get pod node-selector-demo -n s6-governance -o wide
```

O Pod deve executar no Worker com a label `training.goldconsulting/workload=apps`.

## Teste negativo — selector impossível

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: selector-impossible
  namespace: s6-governance
spec:
  nodeSelector:
    training.goldconsulting/workload: does-not-exist
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "96Mi"
EOF
```

Observar:

```bash
kubectl get pod selector-impossible -n s6-governance -o wide
kubectl describe pod selector-impossible -n s6-governance
```

Esperado:

```text
STATUS: Pending
NODE:   <none>
Event:  FailedScheduling
```

O Event pode referir “node affinity/selector”; a redação varia por versão.

Eliminar:

```bash
kubectl delete pod selector-impossible -n s6-governance
```

## 4.2. Node Affinity obrigatória

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-demo
  namespace: s6-governance
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: training.goldconsulting/workload
                operator: In
                values:
                  - apps
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "50m"
          memory: "32Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
EOF
```

Validar:

```bash
kubectl wait --for=condition=Ready pod/node-affinity-demo \
  -n s6-governance --timeout=120s
kubectl get pod node-affinity-demo -n s6-governance -o wide
```

### Diferença conceptual

```text
nodeSelector
→ igualdade simples por labels

Node Affinity
→ expressões, operadores e regras obrigatórias ou preferenciais
```

`requiredDuringSchedulingIgnoredDuringExecution` significa que a regra é obrigatória **no momento do scheduling**. Vamos prová-lo, em vez de ficar apenas pela explicação.

Remover temporariamente a label do Worker:

```bash
kubectl label node "$LAB_WORKER" \
  training.goldconsulting/workload-

kubectl get nodes -L training.goldconsulting/workload
kubectl get pod node-affinity-demo -n s6-governance -o wide
```

Esperado: `node-affinity-demo` continua `Running` no mesmo Node. A alteração posterior da label não provoca expulsão automática por esta regra.

Repor imediatamente a label para os checkpoints seguintes:

```bash
kubectl label node "$LAB_WORKER" \
  training.goldconsulting/workload=apps
```

---

# CP5 — Pod Anti-Affinity

## O que estamos a fazer

Criar duas réplicas que não podem coexistir no mesmo hostname e depois provocar uma terceira réplica impossível de colocar nos dois Workers disponíveis.

## Porque é necessário

Queremos demonstrar simultaneamente distribuição e o custo de uma regra de Anti-Affinity obrigatória.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: antiaffinity-demo
  namespace: s6-governance
spec:
  replicas: 2
  selector:
    matchLabels:
      app: antiaffinity-demo
  template:
    metadata:
      labels:
        app: antiaffinity-demo
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: antiaffinity-demo
              topologyKey: kubernetes.io/hostname
      containers:
        - name: web
          image: nginx:stable-alpine
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
EOF
```

Aguardar e observar:

```bash
kubectl rollout status deployment/antiaffinity-demo \
  -n s6-governance \
  --timeout=180s

kubectl get pods -n s6-governance \
  -l app=antiaffinity-demo \
  -o wide
```

Esperado:

```text
Réplica 1 → um Worker
Réplica 2 → outro Worker
```

## 5.1. Teste negativo — escalar para três réplicas

```bash
kubectl scale deployment/antiaffinity-demo \
  -n s6-governance \
  --replicas=3

sleep 5

kubectl get pods -n s6-governance \
  -l app=antiaffinity-demo \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName'
```

Identificar a réplica com `NODE` vazio / `<none>` e descrevê-la:

```bash
kubectl describe pod <POD_SEM_NODE> -n s6-governance
```

Esperado: `PodScheduled=False` e `FailedScheduling`, com referência às regras de Pod Anti-Affinity.

> Não identificar um problema de scheduling apenas por `status.phase=Pending`. Um Pod pode estar em fase `Pending`, já ter `spec.nodeName` atribuído e encontrar-se em `ContainerCreating`. Para provar que **não foi agendado**, a evidência principal é `NODE=<none>` / `spec.nodeName` vazio e `PodScheduled=False`.

Repor o Deployment em duas réplicas:

```bash
kubectl scale deployment/antiaffinity-demo \
  -n s6-governance \
  --replicas=2

kubectl rollout status deployment/antiaffinity-demo \
  -n s6-governance \
  --timeout=180s

kubectl get pods -n s6-governance \
  -l app=antiaffinity-demo \
  -o wide
```

### Nota de troubleshooting para o formador

Se uma réplica tiver `NODE` atribuído mas ficar em `ContainerCreating`, consultar `kubectl describe pod`. Um Event `FailedCreatePodSandBox` aponta para runtime/CNI, não para a Anti-Affinity. Durante a validação deste laboratório foi observado um caso real de autenticação do CNI Calico após o Scheduler ter feito placement corretamente.

---

# CP6 — Taints e Tolerations

## O que estamos a fazer

Adicionar uma barreira a um Node e provar a diferença entre:

```text
taint      → repele

toleration → remove a barreira correspondente
```

Aplicar o taint ao Worker anteriormente marcado:

```bash
kubectl taint node "$LAB_WORKER" \
  training.goldconsulting/dedicated=lab:NoSchedule

kubectl describe node "$LAB_WORKER" | grep -i Taints
```

`NoSchedule` impede novo scheduling de Pods que não possuam toleration compatível; não expulsa automaticamente os Pods que já estavam em execução.

## 6.1. Pod sem toleration

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration
  namespace: s6-governance
spec:
  nodeSelector:
    training.goldconsulting/workload: apps
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "96Mi"
EOF
```

Observar:

```bash
kubectl get pod no-toleration -n s6-governance -o wide
kubectl describe pod no-toleration -n s6-governance
```

Esperado: `Pending`, `NODE=<none>` e `FailedScheduling`.

No cluster de referência, as causas podem mapear-se assim:

```text
k8s-wk-01 → corresponde ao nodeSelector, mas tem o taint do laboratório
k8s-wk-03 → não corresponde ao nodeSelector
k8s-cp-01 → tem o taint do Control Plane
```

## 6.2. Pod com toleration

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: toleration-demo
  namespace: s6-governance
spec:
  nodeSelector:
    training.goldconsulting/workload: apps
  tolerations:
    - key: training.goldconsulting/dedicated
      operator: Equal
      value: lab
      effect: NoSchedule
  containers:
    - name: web
      image: nginx:stable-alpine
      resources:
        requests:
          cpu: "50m"
          memory: "32Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
EOF
```

Validar:

```bash
kubectl wait --for=condition=Ready pod/toleration-demo \
  -n s6-governance --timeout=120s
kubectl get pod no-toleration toleration-demo \
  -n s6-governance -o wide
```

Esperado:

```text
no-toleration    → Pending / NODE <none>
toleration-demo  → Running / k8s-wk-01
```

> A toleration não “atrai” o Pod para o Node. Neste exemplo, quem restringe o placement ao Node marcado é o `nodeSelector`; a toleration apenas remove a barreira criada pelo taint.

Remover os Pods de teste e o taint:

```bash
kubectl delete pod no-toleration toleration-demo \
  -n s6-governance \
  --ignore-not-found

kubectl taint node "$LAB_WORKER" \
  training.goldconsulting/dedicated-

kubectl describe node "$LAB_WORKER" | grep -i Taints
```

Esperado: `Taints: <none>`.

---

# CP7 — ServiceAccount e RBAC

## O que estamos a fazer

Criar uma identidade de workload e conceder-lhe apenas leitura de Pods e ConfigMaps no Namespace.

A relação é:

```text
ServiceAccount
      ↓
RoleBinding
      ↓
Role
      ↓
get/list Pods e ConfigMaps
```

Aplicar:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: s6-governance
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader-role
  namespace: s6-governance
rules:
  - apiGroups: [""]
    resources:
      - pods
      - configmaps
    verbs:
      - get
      - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: s6-governance
subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: s6-governance
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-reader-role
EOF
```

Validar objetos e regras:

```bash
kubectl get serviceaccount app-reader -n s6-governance -o yaml
kubectl describe role app-reader-role -n s6-governance
kubectl describe rolebinding app-reader-binding -n s6-governance
```

> `automountServiceAccountToken: true` fica explícito para tornar o comportamento pedagógico visível. Neste checkpoint não criamos um Pod com `app-reader`; o RBAC é testado por impersonation.

## 7.1. Testar autorização

```bash
SA_ID="system:serviceaccount:s6-governance:app-reader"

echo "$SA_ID"

kubectl auth can-i get pods \
  -n s6-governance \
  --as="$SA_ID"

kubectl auth can-i delete pods \
  -n s6-governance \
  --as="$SA_ID"

kubectl auth can-i get secrets \
  -n s6-governance \
  --as="$SA_ID"
```

Esperado:

```text
get pods      → yes
delete pods   → no
get secrets   → no
```

### Flags

- `kubectl auth can-i` pergunta ao API Server se uma ação seria autorizada;
- `--as=<identidade>` usa impersonation para testar outra identidade;
- a identidade administrativa que executa o comando necessita de permissão para impersonation.

---

# CP8 — SecurityContext

## O que estamos a fazer

Executar um workload de laboratório com privilégios reduzidos e verificar o comportamento real.

## Porque é necessário

Hardening não consiste em copiar configurações “fortes”; consiste em aplicar o menor conjunto de privilégios compatível com o workload.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: security-demo
  namespace: s6-governance
spec:
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: shell
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          id
          sleep 3600
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      resources:
        requests:
          cpu: "25m"
          memory: "16Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
EOF
```

Esperar que fique Ready:

```bash
kubectl wait \
  --for=condition=Ready \
  pod/security-demo \
  -n s6-governance \
  --timeout=120s

kubectl get pod security-demo -n s6-governance -o wide
kubectl describe pod security-demo -n s6-governance
```

## 8.1. Confirmar execução non-root

```bash
kubectl exec -n s6-governance security-demo -- id
```

Esperado:

```text
uid=10001 gid=10001 groups=10001
```

## 8.2. Confirmar filesystem read-only

```bash
kubectl exec -n s6-governance security-demo -- \
  sh -c 'touch /teste-escrita'
```

Esperado: `Read-only file system` e código de saída diferente de zero.

> `readOnlyRootFilesystem: true` não deve ser aplicado cegamente a todas as aplicações. Workloads que necessitam de escrita devem receber volumes graváveis apenas nos caminhos necessários.

## 8.3. Confirmar ausência de token automático

```bash
kubectl exec -n s6-governance security-demo -- \
  sh -c 'ls -la /var/run/secrets/kubernetes.io/serviceaccount 2>&1 || true'

kubectl get pod security-demo \
  -n s6-governance \
  -o jsonpath='automountServiceAccountToken: {.spec.automountServiceAccountToken}{"\n"}'
```

Esperado: o diretório não existe e `automountServiceAccountToken: false`.

## 8.4. Inspecionar a configuração efetiva

```bash
kubectl get pod security-demo \
  -n s6-governance \
  -o jsonpath='
runAsNonRoot: {.spec.containers[0].securityContext.runAsNonRoot}
runAsUser: {.spec.containers[0].securityContext.runAsUser}
runAsGroup: {.spec.containers[0].securityContext.runAsGroup}
allowPrivilegeEscalation: {.spec.containers[0].securityContext.allowPrivilegeEscalation}
readOnlyRootFilesystem: {.spec.containers[0].securityContext.readOnlyRootFilesystem}
seccompProfile: {.spec.securityContext.seccompProfile.type}
capabilities.drop: {.spec.containers[0].securityContext.capabilities.drop}
'
```

Esperado:

```text
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
seccompProfile: RuntimeDefault
capabilities.drop: ["ALL"]
```

---

# CP9 — Secret de laboratório

## O que estamos a fazer

Criar um Secret com valores exclusivamente fictícios e analisar o modelo de proteção.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: db-demo
  namespace: s6-governance
type: Opaque
stringData:
  username: demo
  password: lab-only-not-a-real-secret
EOF
```

Consultar apenas metadata e chaves:

```bash
kubectl describe secret db-demo -n s6-governance
```

Opcionalmente, mostrar tipo e nomes das chaves sem imprimir os valores:

```bash
kubectl get secret db-demo \
  -n s6-governance \
  -o go-template='Type: {{.type}}{{"\n"}}Keys:{{range $k, $v := .data}} {{$k}}{{end}}{{"\n"}}'
```

### Campo importante

`stringData` permite fornecer texto aquando da criação. Kubernetes converte o conteúdo para a representação usada no campo `data`.

> Base64 é codificação, não encriptação. Um Secret não deve ser apresentado como “automaticamente seguro em repouso”. A proteção depende, entre outros controlos, de RBAC e da configuração de encriptação em repouso do cluster.

Revalidar RBAC:

```bash
kubectl auth can-i get secrets \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader
```

Esperado:

```text
no
```

---

# CP10 — NetworkPolicy com Calico

## O que estamos a fazer

Partir de comunicação livre, aplicar `default deny` e reabrir apenas os fluxos necessários.

A progressão será:

```text
Tudo comunica
      ↓
Default deny
      ↓
DNS + aplicação + PostgreSQL bloqueados
      ↓
Permitir DNS
      ↓
Permitir cliente → aplicação
      ↓
Permitir aplicação → PostgreSQL
      ↓
Confirmar cliente → PostgreSQL bloqueado
```

## 10.1. Pré-validação de Calico e DNS

```bash
clear
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system

kubectl get pods \
  -n kube-system \
  -l k8s-app=kube-dns \
  -o wide \
  --show-labels
```

Antes de aplicar a policy de DNS, confirmar a label real dos Pods que prestam o serviço DNS.

> No cluster de referência a label validada é `k8s-app=kube-dns`. Se o cluster usado na formação tiver outra label, adaptar a policy antes de aplicar.

## 10.2. Criar workloads de diagnóstico

Os próximos recursos não substituem funcionalmente a Symfony Demo. Servem para isolar a variável **rede**.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: net-app
  namespace: s6-governance
spec:
  replicas: 1
  selector:
    matchLabels:
      component: app
  template:
    metadata:
      labels:
        component: app
    spec:
      containers:
        - name: web
          image: nginx:stable-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "96Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: net-app
  namespace: s6-governance
spec:
  selector:
    component: app
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: net-db
  namespace: s6-governance
spec:
  replicas: 1
  selector:
    matchLabels:
      component: db
  template:
    metadata:
      labels:
        component: db
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: db-demo
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-demo
                  key: password
            - name: POSTGRES_DB
              value: lab
          ports:
            - containerPort: 5432
          resources:
            requests:
              cpu: "50m"
              memory: "96Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: net-db
  namespace: s6-governance
spec:
  selector:
    component: db
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: v1
kind: Pod
metadata:
  name: net-client
  namespace: s6-governance
  labels:
    role: client
spec:
  containers:
    - name: client
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "10m"
          memory: "16Mi"
        limits:
          cpu: "50m"
          memory: "64Mi"
EOF
```

Aguardar:

```bash
kubectl rollout status deployment/net-app \
  -n s6-governance --timeout=180s
kubectl rollout status deployment/net-db \
  -n s6-governance --timeout=180s
kubectl wait --for=condition=Ready pod/net-client \
  -n s6-governance --timeout=120s

kubectl get pods -n s6-governance -o wide
kubectl get svc -n s6-governance
```

## 10.3. Baseline — confirmar comunicação antes das policies

Guardar os `ClusterIP` para podermos testar conectividade sem depender do DNS depois do `default deny`:

```bash
NET_APP_IP=$(kubectl get svc net-app \
  -n s6-governance \
  -o jsonpath='{.spec.clusterIP}')

NET_DB_IP=$(kubectl get svc net-db \
  -n s6-governance \
  -o jsonpath='{.spec.clusterIP}')

echo "net-app: $NET_APP_IP"
echo "net-db:  $NET_DB_IP"
```

### DNS

Usar o FQDN completo com ponto final. Isto evita resultados ambíguos provocados pela expansão dos search domains do cliente DNS do BusyBox.

```bash
kubectl exec -n s6-governance net-client -- \
  nslookup net-app.s6-governance.svc.cluster.local.
```

Esperado: o nome resolve para o `ClusterIP` de `net-app`.

### Cliente → aplicação

```bash
kubectl exec -n s6-governance net-client -- \
  wget -T 3 -qO- http://net-app
```

Esperado: HTML da página padrão do nginx.

### Cliente → PostgreSQL

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

Esperado:

```text
exit=0
```

Baseline esperado:

```text
DNS                         → OK
net-client → net-app:80     → OK
net-client → net-db:5432    → OK
```

## 10.4. Aplicar default deny

Confirmar primeiro que ainda não existem policies no Namespace:

```bash
kubectl get networkpolicy -n s6-governance
```

Aplicar:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: s6-governance
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
```

`podSelector: {}` seleciona todos os Pods do Namespace. Como não existem regras `ingress` nem `egress`, os Pods selecionados ficam isolados nas duas direções.

Confirmar:

```bash
kubectl get networkpolicy -n s6-governance
kubectl describe networkpolicy default-deny-all -n s6-governance
```

### Provar bloqueio de DNS

```bash
kubectl exec -n s6-governance net-client -- \
  nslookup net-app.s6-governance.svc.cluster.local.
```

Esperado: falha/timeout. Não usar `timeout` **dentro** do container para este teste; alguns utilitários BusyBox podem interferir com o processo principal do Pod.

### Provar bloqueio HTTP sem depender de DNS

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c "wget -T 3 -qO- http://$NET_APP_IP; echo \"exit=\$?\""
```

Esperado: timeout e `exit` diferente de zero.

### Provar bloqueio PostgreSQL sem depender de DNS

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c "nc -w 2 $NET_DB_IP 5432 </dev/null; echo \"exit=\$?\""
```

Esperado: `exit` diferente de zero.

> O sucesso de `kubectl apply` prova apenas que a API aceitou a NetworkPolicy. O bloqueio observado é a evidência de enforcement pelo CNI.

## 10.5. Permitir apenas DNS

Aplicar a policy seguinte após confirmar a label real do CoreDNS:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: s6-governance
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

As NetworkPolicies são **aditivas**. `allow-dns` não substitui `default-deny-all`; acrescenta apenas egress UDP/TCP 53 para os Pods DNS selecionados.

Validar resolução:

```bash
kubectl exec -n s6-governance net-client -- \
  nslookup net-app.s6-governance.svc.cluster.local.
```

Esperado: DNS volta a funcionar.

Confirmar que os restantes fluxos continuam bloqueados:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c "wget -T 3 -qO- http://$NET_APP_IP; echo \"exit=\$?\""

kubectl exec -n s6-governance net-client -- \
  sh -c "nc -w 2 $NET_DB_IP 5432 </dev/null; echo \"exit=\$?\""
```

Esperado:

```text
DNS                         → OK
net-client → net-app:80     → BLOQUEADO
net-client → net-db:5432    → BLOQUEADO
```

## 10.6. Permitir cliente → aplicação

Quando ambos os lados estão isolados, precisamos das duas permissões:

```text
egress do cliente
        +
ingress da aplicação
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-egress-to-app
  namespace: s6-governance
spec:
  podSelector:
    matchLabels:
      role: client
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              component: app
      ports:
        - protocol: TCP
          port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-ingress-to-app
  namespace: s6-governance
spec:
  podSelector:
    matchLabels:
      component: app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: client
      ports:
        - protocol: TCP
          port: 80
EOF
```

Testar HTTP:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'wget -T 3 -qO- http://net-app >/dev/null; echo "exit=$?"'
```

Esperado: `exit=0`.

Confirmar que cliente → PostgreSQL permanece bloqueado:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

Esperado: `exit` diferente de zero.

## 10.7. Permitir aplicação → PostgreSQL

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-egress-to-db
  namespace: s6-governance
spec:
  podSelector:
    matchLabels:
      component: app
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              component: db
      ports:
        - protocol: TCP
          port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-ingress-to-db
  namespace: s6-governance
spec:
  podSelector:
    matchLabels:
      component: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              component: app
      ports:
        - protocol: TCP
          port: 5432
EOF
```

Testar a partir do Pod da aplicação:

```bash
kubectl exec -n s6-governance deploy/net-app -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

Esperado: `exit=0`.

## 10.8. Provar o fluxo que permanece proibido

Cliente → PostgreSQL:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

Esperado: `exit` diferente de zero.

Confirmar que HTTP continua permitido:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'wget -T 3 -qO- http://net-app >/dev/null; echo "exit=$?"'
```

Esperado: `exit=0`.

Consultar as policies:

```bash
kubectl get networkpolicy -n s6-governance
kubectl describe networkpolicy -n s6-governance
```

### Evidência final de rede

```text
DNS                      PERMITIDO
cliente → aplicação      PERMITIDO
aplicação → PostgreSQL   PERMITIDO
cliente → PostgreSQL     BLOQUEADO
```

> Uma NetworkPolicy só está validada quando conseguimos demonstrar simultaneamente um caminho autorizado e um caminho que permanece bloqueado.

---

# CP11 — Síntese: mapear regra → camada → evidência

| Controlo | Camada principal | Evidência |
|---|---|---|
| Requests | Scheduling | `describe pod` / Event |
| Limits | Runtime/cgroups | manifesto efetivo / comportamento |
| LimitRange | Admission | defaults/restrições observados |
| ResourceQuota | Admission | criação rejeitada / `Used` vs `Hard` |
| nodeSelector / Affinity | Scheduling | Node escolhido / `FailedScheduling` |
| Taint / Toleration | Scheduling | Pod elegível ou `Pending` |
| ServiceAccount + RBAC | Authorization | `kubectl auth can-i` |
| SecurityContext | Segurança do processo | UID, filesystem, token, capabilities |
| Secret | Dados sensíveis | acesso limitado / metadata |
| NetworkPolicy | Rede L3/L4 | fluxo permitido + fluxo bloqueado |

## 11.1. Recolher fotografia final antes da limpeza

```bash
clear

echo "=== QUOTA ==="
kubectl describe resourcequota namespace-quota -n s6-governance

echo
echo "=== PLACEMENT ==="
kubectl get pods -n s6-governance -o wide

echo
echo "=== LABELS / TAINTS ==="
kubectl get nodes -L training.goldconsulting/workload
kubectl describe node k8s-wk-01 | grep -i Taints

echo
echo "=== RBAC ==="
SA_ID="system:serviceaccount:s6-governance:app-reader"
echo -n "get pods: "
kubectl auth can-i get pods -n s6-governance --as="$SA_ID"
echo -n "delete pods: "
kubectl auth can-i delete pods -n s6-governance --as="$SA_ID"
echo -n "get secrets: "
kubectl auth can-i get secrets -n s6-governance --as="$SA_ID"

echo
echo "=== SECURITYCONTEXT ==="
kubectl exec -n s6-governance security-demo -- id
kubectl get pod security-demo \
  -n s6-governance \
  -o jsonpath='automountServiceAccountToken: {.spec.automountServiceAccountToken}{"\n"}seccompProfile: {.spec.securityContext.seccompProfile.type}{"\n"}allowPrivilegeEscalation: {.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}readOnlyRootFilesystem: {.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}'

echo
echo "=== SECRET ==="
kubectl describe secret db-demo -n s6-governance

echo
echo "=== NETWORKPOLICIES ==="
kubectl get networkpolicy -n s6-governance
```

### Pergunta final

> Em que checkpoints a API aceitou o objeto, mas o efeito só ficou provado depois de observar o comportamento do cluster?

Scheduling, SecurityContext e NetworkPolicy são exemplos claros onde “objeto criado” não é sinónimo de “resultado validado”. O teste da Anti-Affinity mostrou ainda que um Pod pode já ter sido agendado e falhar depois na criação da sandbox; é por isso que a camada da falha deve ser identificada pela evidência.

### Nota sobre reinícios de Pods de diagnóstico

Se um Pod de diagnóstico apresentar `RESTARTS > 0`, não assumir imediatamente crash. Inspecionar:

```bash
kubectl describe pod net-client -n s6-governance
kubectl logs net-client -n s6-governance --previous
```

Distinguir, por exemplo, `Reason: Completed / Exit Code: 0` de `OOMKilled` ou de uma falha da aplicação.

---

# CP12 — Limpeza

## O que estamos a fazer

Remover todos os recursos namespaced, desfazer alterações feitas diretamente nos Nodes e repor o Namespace por omissão do contexto.

Eliminar o Namespace:

```bash
kubectl delete namespace s6-governance --wait=true
```

Remover a label de laboratório:

```bash
kubectl label node k8s-wk-01 \
  training.goldconsulting/workload- \
  2>/dev/null || true
```

Garantir que o taint também não permanece:

```bash
kubectl taint node k8s-wk-01 \
  training.goldconsulting/dedicated- \
  2>/dev/null || true
```

Repor o Namespace por omissão:

```bash
kubectl config set-context \
  --current \
  --namespace=default
```

### Porque usamos `|| true`?

Se a label ou o taint já tiverem sido removidos, o comando pode devolver erro. `|| true` impede que essa situação inofensiva interrompa uma sequência de limpeza.

## 12.1. Confirmar estado final

```bash
echo "=== CONTEXTO ==="
kubectl config view \
  --minify \
  -o jsonpath='{..namespace}{"\n"}'

echo
echo "=== NAMESPACE ==="
kubectl get namespace s6-governance

echo
echo "=== NODES ==="
kubectl get nodes -L training.goldconsulting/workload

echo
echo "=== TAINT WK01 ==="
kubectl describe node k8s-wk-01 | grep -i Taints
```

Esperado:

```text
namespace atual                 → default
s6-governance                   → NotFound
WORKLOAD em k8s-wk-01           → vazio
Taints em k8s-wk-01             → <none>
```

---

# Checklist final do formando

- [ ] Confirmei que estava na diretoria correta do repositório.
- [ ] Validei Nodes, Calico, CoreDNS e criação de rede em ambos os Workers.
- [ ] Consultei `Capacity` e `Allocatable` antes de definir recursos.
- [ ] Distingo `request` de `limit` e sei que o Scheduler contabiliza requests declarados para elegibilidade.
- [ ] Provo um `FailedScheduling` através de Events e da ausência de `spec.nodeName`.
- [ ] Distingo `LimitRange` de `ResourceQuota`.
- [ ] Consigo explicar por que uma rejeição por quota não é um problema do Scheduler.
- [ ] Consigo controlar placement com labels e `nodeSelector`.
- [ ] Distingo `nodeSelector` de Node Affinity.
- [ ] Demonstrei `IgnoredDuringExecution` removendo e repondo a label do Node.
- [ ] Demonstrei Pod Anti-Affinity com duas réplicas distribuídas e uma terceira não agendável.
- [ ] Sei distinguir `Pending` não agendado de `ContainerCreating` já associado a um Node.
- [ ] Distingo taint de toleration.
- [ ] Sei que toleration não implica placement obrigatório.
- [ ] Criei uma ServiceAccount e RBAC namespaced mínimo.
- [ ] Demonstrei pelo menos um `yes` e dois `no` com `kubectl auth can-i`.
- [ ] Validei execução non-root, seccomp, filesystem read-only, capabilities e ausência de token automático.
- [ ] Sei explicar porque Base64 não é encriptação.
- [ ] Confirmei enforcement de NetworkPolicy com Calico.
- [ ] Testei DNS com FQDN completo e distingui falha de DNS de falha de conectividade por ClusterIP.
- [ ] Demonstrei cliente → aplicação e aplicação → PostgreSQL permitidos.
- [ ] Demonstrei cliente → PostgreSQL bloqueado.
- [ ] Removi recursos, labels e taints e repus o contexto em `default`.

---

# Regra de evidência da Sessão 6

O laboratório fica concluído quando o formando consegue apresentar e explicar:

```text
preflight e CNI validados
+
quota aplicada
+
requests/limits visíveis
+
Pending explicado por Event e NODE <none>
+
placement justificado
+
IgnoredDuringExecution demonstrado
+
anti-affinity positiva e negativa demonstradas
+
taint/toleration demonstrados
+
permissão RBAC "yes"
+
permissões RBAC "no"
+
SecurityContext verificado
+
Secret tratado sem exposição desnecessária
+
DNS permitido de forma explícita
+
cliente → aplicação permitido
+
aplicação → PostgreSQL permitido
+
cliente → PostgreSQL bloqueado
+
cluster limpo no final
```
