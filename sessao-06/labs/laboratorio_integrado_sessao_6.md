# Laboratório Integrado — Sessão 6
## Kubernetes Admin III: Recursos, Scheduling e Segurança

**Sessão:** 6  
**Módulo:** M9 — Recursos, Scheduling e Segurança  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Foco:** **GOVERNAR O CLUSTER**  
**Topologia:** `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`  
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

## 0.1. Diretoria de trabalho

```bash
clear
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/sessao-06/labs"
pwd
```

### O que faz este bloco

- `git rev-parse --show-toplevel` devolve a raiz do repositório Git;
- `$(...)` executa o comando e coloca o resultado na variável `REPO_ROOT`;
- `cd` muda o terminal para a diretoria do laboratório;
- `pwd` confirma a diretoria atual.

O final de `pwd` deve ser:

```text
/sessao-06/labs
```

---

# CP1 — Pré-flight e Namespace

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

Criar o Namespace:

```bash
clear
kubectl create namespace s6-governance
kubectl config set-context --current --namespace=s6-governance
kubectl get namespace s6-governance
```

### Flags e opções

- `--current` altera apenas o contexto atualmente selecionado;
- `--namespace=s6-governance` define o Namespace por omissão para os comandos seguintes.

> Mesmo com o Namespace configurado no contexto, vários comandos deste laboratório mantêm `-n s6-governance` para tornar o escopo explícito.

---

# CP2 — Capacity, Allocatable, Requests e Limits

## O que estamos a fazer

Observar primeiro a capacidade dos Nodes e depois declarar os recursos de um Pod.

## Porque é necessário

O Scheduler necessita de `requests` para decidir se um Pod cabe num Node. Os `limits` definem o teto de utilização imposto ao container.

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
kubectl get pod resources-demo -n s6-governance -o wide
kubectl describe pod resources-demo -n s6-governance
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
kubectl get pod resources-impossible -n s6-governance
kubectl describe pod resources-impossible -n s6-governance
kubectl get events -n s6-governance --sort-by=.lastTimestamp
```

Esperado:

```text
STATUS: Pending
Event:  FailedScheduling
```

### Pergunta

> Porque é que o Pod existe na API mas continua `Pending`?

Porque o pedido foi aceite pela API, mas o Scheduler não encontrou nenhum Node com recursos suficientes para satisfazer o `request` declarado.

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

## 3.2. Confirmar defaults

Criar um Pod sem `resources`:

```bash
kubectl run defaulted-resources \
  --image=nginx:stable-alpine \
  --restart=Never \
  -n s6-governance
```

### Flags

- `--image` indica a imagem do container;
- `--restart=Never` cria diretamente um Pod em vez de um controlador que o recrie;
- `-n` define explicitamente o Namespace.

Observar os valores efetivos:

```bash
kubectl get pod defaulted-resources \
  -n s6-governance \
  -o jsonpath='{.spec.containers[0].resources}'
echo
```

Esperado: o Pod apresenta os defaults introduzidos pelo `LimitRange`.

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

Procurar:

```text
Used
Hard
```

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

Esperado: o pedido é rejeitado imediatamente.

### Pergunta

> Esta falha ocorreu em admission ou no Scheduler?

Neste caso, o objeto é rejeitado antes de chegar ao Scheduler, porque a criação faria ultrapassar a `ResourceQuota`.

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

### Flags

- `kubectl label` adiciona ou altera metadata de labels;
- `-L <label>` acrescenta essa label como coluna no output.

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
kubectl get pod selector-impossible -n s6-governance
kubectl describe pod selector-impossible -n s6-governance
```

Esperado:

```text
Pending
FailedScheduling
```

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
kubectl get pod node-affinity-demo -n s6-governance -o wide
```

### Diferença conceptual

```text
nodeSelector
→ igualdade simples por labels

Node Affinity
→ expressões, operadores e regras obrigatórias ou preferenciais
```

`requiredDuringSchedulingIgnoredDuringExecution` significa que a regra é obrigatória **no momento do scheduling**. Se a label mudar posteriormente, o Pod não é automaticamente expulso apenas por causa desta regra.

---

# CP5 — Pod Anti-Affinity

## O que estamos a fazer

Criar duas réplicas que não podem coexistir no mesmo hostname.

## Porque é necessário

Queremos demonstrar uma regra de distribuição de réplicas pelos dois Worker Nodes.

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

Aguardar:

```bash
kubectl rollout status deployment/antiaffinity-demo \
  -n s6-governance \
  --timeout=180s

kubectl get pods -n s6-governance \
  -l app=antiaffinity-demo \
  -o wide
```

### Flags

- `rollout status` acompanha o progresso do controlador;
- `--timeout=180s` impede espera indefinida;
- `-l app=...` filtra objetos pela label indicada.

Esperado:

```text
Réplica 1 → um Worker
Réplica 2 → outro Worker
```

### Pergunta

> O que aconteceria com 3 réplicas e apenas 2 Workers elegíveis usando esta Anti-Affinity obrigatória?

Uma das réplicas poderia permanecer `Pending`, porque a terceira não encontraria um hostname que satisfizesse a regra.

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
```

### Sintaxe

```text
chave=valor:efeito
```

`NoSchedule` impede novo scheduling de Pods que não possuam toleration compatível.

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
kubectl get pod no-toleration -n s6-governance
kubectl describe pod no-toleration -n s6-governance
```

Esperado: `Pending`.

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
kubectl get pod toleration-demo -n s6-governance -o wide
```

> A toleration não “atrai” o Pod para o Node. Neste exemplo, quem restringe o placement ao Node marcado é o `nodeSelector`; a toleration apenas permite ultrapassar o taint.

Remover o teste negativo e o taint:

```bash
kubectl delete pod no-toleration -n s6-governance
kubectl taint node "$LAB_WORKER" \
  training.goldconsulting/dedicated-
```

O sufixo `-` remove o taint com essa chave.

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

Validar objetos:

```bash
kubectl get serviceaccount,role,rolebinding -n s6-governance
```

## 7.1. Provar uma permissão

```bash
kubectl auth can-i get pods \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader
```

Esperado:

```text
yes
```

## 7.2. Provar duas negações

```bash
kubectl auth can-i delete pods \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader

kubectl auth can-i get secrets \
  -n s6-governance \
  --as=system:serviceaccount:s6-governance:app-reader
```

Esperado:

```text
no
no
```

### Flags

- `kubectl auth can-i` pergunta ao API Server se uma ação seria autorizada;
- `--as=<identidade>` usa impersonation para testar outra identidade;
- a identidade administrativa que executa o comando necessita de permissão para impersonation.

### Evidência

```text
get pods      → yes
delete pods   → no
get secrets   → no
```

> Neste checkpoint a ServiceAccount é testada por impersonation. Não precisamos de criar um Pod apenas para demonstrar RBAC.

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
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - "id; sleep 3600"
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
  --timeout=90s
```

### Flags

- `--for=condition=Ready` espera por uma condição do objeto;
- `--timeout=90s` termina a espera após 90 segundos.

Confirmar UID/GID:

```bash
kubectl exec -n s6-governance security-demo -- id
```

Esperado: UID/GID `10001`, não `0`.

### Porque existe `--` em kubectl exec?

O primeiro `--` termina as opções de `kubectl`; tudo o que aparece depois é o comando executado dentro do container.

Confirmar que o token da ServiceAccount não foi montado:

```bash
kubectl exec -n s6-governance security-demo -- \
  sh -c 'test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo "token ausente: OK"'
```

Testar o filesystem read-only:

```bash
kubectl exec -n s6-governance security-demo -- \
  sh -c 'touch /probe'
```

Esperado: falha de escrita.

Consultar o manifesto efetivo:

```bash
kubectl get pod security-demo -n s6-governance -o yaml
```

Identificar:

```text
runAsNonRoot
runAsUser
runAsGroup
allowPrivilegeEscalation
capabilities.drop
seccompProfile
readOnlyRootFilesystem
automountServiceAccountToken
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

### Campo importante

`stringData` permite fornecer texto aquando da criação. Kubernetes converte o conteúdo para a representação usada no campo `data`.

> Base64 é codificação, não encriptação. Não utilizar credenciais reais no laboratório e não ensinar a leitura do Secret em YAML como operação normal de consumo.

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
Tudo bloqueado
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
```

Antes de aplicar a policy de DNS, identificar as labels reais dos Pods que prestam o serviço DNS.

> Em muitos clusters kubeadm/CoreDNS encontra-se `k8s-app=kube-dns`, mas o laboratório deve confirmar o valor real em vez de o assumir.

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
kubectl rollout status deployment/net-app -n s6-governance --timeout=180s
kubectl rollout status deployment/net-db -n s6-governance --timeout=180s
kubectl wait --for=condition=Ready pod/net-client -n s6-governance --timeout=120s
```

## 10.3. Baseline — confirmar comunicação antes das policies

Cliente → aplicação:

```bash
kubectl exec -n s6-governance net-client -- \
  wget -T 3 -qO- http://net-app
```

### Flags do wget

- `-T 3` define timeout de 3 segundos;
- `-q` reduz output adicional;
- `-O-` envia o corpo da resposta para stdout.

Cliente → PostgreSQL:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

`-w 2` limita a espera do `nc` a 2 segundos.

Antes das policies, ambos os caminhos devem ser alcançáveis ao nível de rede.

## 10.4. Aplicar default deny

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

`podSelector: {}` seleciona todos os Pods do Namespace.

Repetir os dois testes anteriores.

Esperado: deixam de funcionar.

> O sucesso de `kubectl apply` prova apenas que a API aceitou o objeto. O bloqueio observado é a evidência de enforcement pelo CNI.

## 10.5. Permitir DNS

Depois de confirmar a label real do DNS, aplicar a policy seguinte. Se a label no cluster for diferente, alterar o `podSelector` antes de executar.

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

Validar resolução:

```bash
kubectl exec -n s6-governance net-client -- nslookup net-app
```

## 10.6. Permitir cliente → aplicação

Precisamos de duas permissões quando ambos os lados estão isolados:

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

Testar:

```bash
kubectl exec -n s6-governance net-client -- \
  wget -T 3 -qO- http://net-app
```

Esperado: funciona.

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

Esperado: ligação TCP possível.

## 10.8. Provar um fluxo proibido

Cliente → PostgreSQL:

```bash
kubectl exec -n s6-governance net-client -- \
  sh -c 'nc -w 2 net-db 5432 </dev/null; echo "exit=$?"'
```

Esperado: falha ou timeout.

Consultar as policies:

```bash
kubectl get networkpolicy -n s6-governance
kubectl describe networkpolicy -n s6-governance
```

### Evidência final de rede

```text
cliente → aplicação      PERMITIDO
aplicação → PostgreSQL   PERMITIDO
cliente → PostgreSQL     BLOQUEADO
DNS                      PERMITIDO
```

> Uma NetworkPolicy só está validada quando conseguimos demonstrar simultaneamente um caminho autorizado e um caminho que permanece bloqueado.

---

# CP11 — Síntese: mapear regra → camada → evidência

Completar a tabela:

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

Pergunta final:

> Em que checkpoints a API aceitou o objeto, mas o efeito só ficou provado depois de observar o comportamento do cluster?

Resposta esperada: scheduling, SecurityContext e NetworkPolicy são exemplos claros onde “objeto criado” não é sinónimo de “resultado validado”.

---

# CP12 — Limpeza

## O que estamos a fazer

Remover todos os recursos namespaced e desfazer alterações feitas diretamente nos Nodes.

Eliminar o Namespace:

```bash
kubectl delete namespace s6-governance --wait=true
```

Remover a label de laboratório:

```bash
kubectl label node "$LAB_WORKER" \
  training.goldconsulting/workload-
```

Garantir que o taint também não permanece:

```bash
kubectl taint node "$LAB_WORKER" \
  training.goldconsulting/dedicated- 2>/dev/null || true
```

### Porque usamos `|| true`?

Se o taint já tiver sido removido no CP6, `kubectl taint ...-` pode devolver erro. `|| true` impede que essa situação interrompa um script ou sequência de limpeza.

Confirmar estado final:

```bash
kubectl get ns s6-governance
kubectl get nodes -L training.goldconsulting/workload
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp | tail -n 20
```

Esperado:

```text
Namespace s6-governance inexistente
label de laboratório removida
taint de laboratório removido
cluster operacional
```

---

# Checklist final do formando

- [ ] Consultei `Capacity` e `Allocatable` antes de definir recursos.
- [ ] Distingo `request` de `limit`.
- [ ] Provo um `FailedScheduling` através de Events.
- [ ] Distingo `LimitRange` de `ResourceQuota`.
- [ ] Consigo explicar por que uma rejeição por quota não é um problema do Scheduler.
- [ ] Consigo controlar placement com labels e `nodeSelector`.
- [ ] Distingo `nodeSelector` de Node Affinity.
- [ ] Consigo explicar o efeito de Pod Anti-Affinity com dois Workers.
- [ ] Distingo taint de toleration.
- [ ] Sei que toleration não implica placement obrigatório.
- [ ] Criei uma ServiceAccount e RBAC namespaced mínimo.
- [ ] Demonstrei pelo menos um `yes` e dois `no` com `kubectl auth can-i`.
- [ ] Validei execução non-root e redução de privilégios.
- [ ] Sei explicar porque Base64 não é encriptação.
- [ ] Confirmei enforcement de NetworkPolicy com Calico.
- [ ] Demonstrei um fluxo permitido e um fluxo bloqueado.
- [ ] Removi alterações aplicadas aos Nodes no final.

---

# Regra de evidência da Sessão 6

O laboratório fica concluído quando o formando consegue apresentar e explicar:

```text
quota aplicada
+
requests/limits visíveis
+
Pending explicado por Event
+
placement justificado
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
fluxo de rede permitido
+
fluxo de rede bloqueado
+
cluster limpo no final
```
