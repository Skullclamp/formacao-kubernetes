# Manual do Formando
## Sessão 4 — Kubernetes Admin I: Instalação, Administração e Upgrade do Cluster

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 4 de 10 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Módulo** | M7 |
| **Foco pedagógico** | Construir, observar, manter e atualizar um cluster Kubernetes |
| **Topologia** | 1 Control Plane + 1 Worker |
| **Ambiente** | Ubuntu 26.04.1 LTS on-premises |
| **Laboratório** | `formando/labs/laboratorio_integrado_sessao_4.md` |

---

# 1. Como utilizar este manual

Este manual foi concebido para funcionar como **guia de acompanhamento, estudo autónomo e consulta futura**. Não é uma simples lista de comandos e não substitui o laboratório.

O manual explica os conceitos e o raciocínio. O laboratório integrado mostra a sequência operacional completa que foi validada na prática.

A sequência de aprendizagem é:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
EXEMPLO
   ↓
COMANDO / MANIFESTO
   ↓
O QUE OBSERVAR
   ↓
INTERPRETAR O RESULTADO
   ↓
APLICAR NO LABORATÓRIO
```

Durante a sessão, a regra pedagógica é:

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

O objetivo não é memorizar comandos. É compreender **o estado do cluster antes da operação, a alteração provocada e a evidência que demonstra que o resultado é o esperado**.

---

# 2. Objetivos da sessão

No final da sessão, deverás ser capaz de:

- explicar a arquitetura básica de um cluster Kubernetes;
- distinguir Control Plane de Worker Node;
- explicar as funções de `kubeadm`, `kubelet` e `kubectl`;
- preparar Linux para Kubernetes;
- explicar a relação `kubelet → CRI → containerd → runc → kernel`;
- instalar explicitamente uma versão Kubernetes sem deixar a escolha ao APT;
- inicializar um Control Plane com `kubeadm`;
- compreender o papel do kubeconfig;
- instalar e validar uma rede CNI com Calico;
- adicionar um Worker ao cluster;
- observar Nodes, Pods, eventos e condições;
- compreender labels e selectors;
- aplicar `cordon`, `drain` e `uncordon`;
- construir um health gate antes de uma alteração de risco;
- executar um upgrade minor de forma sequencial;
- distinguir warnings transitórios de falhas persistentes;
- recolher evidência antes de formular uma hipótese de troubleshooting.

---

# 3. Baseline técnica validada

O laboratório desta sessão foi validado de ponta a ponta com a seguinte combinação:

```text
Sistema operativo:      Ubuntu 26.04.1 LTS
Kernel:                  7.0.0-31-generic
cgroups:                 v2

Control Plane:           k8s-cp-01 / 192.168.50.46
Worker:                  k8s-wk-01 / 192.168.50.65

Kubernetes inicial:      1.35.8
Kubernetes final:        1.36.4
Pacote APT inicial:      1.35.8-1.1
Pacote APT final:        1.36.4-1.1

containerd:              2.2.6
runc:                    1.3.6
Calico:                  3.32.2
Tigera Operator:         1.42.6

Pod CIDR:                10.244.0.0/16
Service CIDR:            10.96.0.0/12
Filesystem /:            40 GB no ambiente validado
```

> **Importante:** os 40 GB não são um requisito universal do Kubernetes. São a baseline prática deste laboratório. O problema observado foi um filesystem raiz com cerca de 10 GB, apesar de a VM ter um disco virtual maior. Isso originou `DiskPressure` durante a instalação do Calico.

As versões patch devem ser reconfirmadas antes de cada nova edição. O princípio pedagógico desta sessão é demonstrar um upgrade **1.35.x → 1.36.x**, sem saltar versões minor.

---

# 4. O modelo mental do Kubernetes

Kubernetes é uma plataforma de orquestração que trabalha principalmente através de um **modelo declarativo**.

Em vez de indicarmos todos os passos necessários para chegar a um resultado, descrevemos o estado que queremos obter.

```text
ESTADO DESEJADO
      ↓
API Server
      ↓
armazenamento do estado
      ↓
controllers observam diferenças
      ↓
reconciliação
      ↓
ESTADO OBSERVADO aproxima-se do DESEJADO
```

Exemplo conceptual:

```text
Desejado:   3 Pods da aplicação
Observado:  2 Pods
Diferença:  falta 1 Pod
Ação:       um controller cria o Pod em falta
```

A reconciliação não acontece apenas uma vez. Os controllers continuam a observar o cluster e tentam manter o estado real alinhado com o estado declarado.

## 4.1. Imperativo versus declarativo

Um comando como:

```bash
kubectl run exemplo --image=nginx
```

é uma operação imperativa: pedimos uma ação diretamente.

Um manifesto YAML descreve um objeto que queremos manter:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exemplo
spec:
  containers:
    - name: web
      image: nginx:1.28.0-alpine
```

Na prática profissional, o modelo declarativo é fundamental porque facilita versionamento, revisão, repetibilidade e automação.

### Resumo

```text
Imperativo  → faz esta ação agora
Declarativo → mantém o sistema neste estado
```

---

# 5. Arquitetura do cluster

Um cluster Kubernetes é composto por um **Control Plane** e por **Nodes** onde os workloads podem executar.

No nosso laboratório:

```text
                ┌───────────────────────┐
                │      k8s-cp-01        │
                │     CONTROL PLANE     │
                │                       │
                │ kube-apiserver        │
                │ etcd                  │
                │ scheduler             │
                │ controller-manager    │
                └───────────┬───────────┘
                            │ API
                            │
                ┌───────────▼───────────┐
                │      k8s-wk-01        │
                │        WORKER         │
                │                       │
                │ kubelet               │
                │ containerd            │
                │ kube-proxy            │
                │ Calico                │
                └───────────────────────┘
```

Esta topologia é adequada à formação, mas **não representa alta disponibilidade**. Em produção, o Control Plane é normalmente redundante.

## 5.1. Componentes do Control Plane

| Componente | Função principal |
|---|---|
| `kube-apiserver` | expõe a API Kubernetes e recebe pedidos de clientes e componentes |
| `etcd` | guarda o estado persistente do cluster |
| `kube-scheduler` | seleciona um Node adequado para Pods ainda não agendados |
| `kube-controller-manager` | executa controllers responsáveis por reconciliação |

### `kube-apiserver`

O API Server é a porta de entrada do cluster. Um `kubectl get nodes`, a criação de um Pod e a atualização de um Deployment passam pela API.

```text
kubectl
   ↓ HTTPS
kube-apiserver
   ↓
autenticação / autorização / validação
   ↓
estado do cluster
```

### `etcd`

`etcd` é a base de dados distribuída usada para armazenar o estado do cluster. Por isso, um plano de recuperação real de Kubernetes não se resume a guardar ficheiros YAML nem a reinstalar packages.

### `kube-scheduler`

O Scheduler observa Pods que ainda não têm Node atribuído. A decisão de scheduling pode considerar recursos, afinidades, restrições e outras políticas.

### `kube-controller-manager`

Os controllers comparam continuamente estado desejado e estado observado. Se um objeto deixar de cumprir o objetivo declarado, um controller pode tomar ações para corrigir a diferença.

## 5.2. Componentes dos Nodes

| Componente | Função principal |
|---|---|
| `kubelet` | agente do Node; garante que os Pods atribuídos ao Node são executados |
| `containerd` | runtime que gere o ciclo de vida dos containers |
| `runc` | runtime OCI de baixo nível usado para criar os processos dos containers |
| `kube-proxy` | implementa comportamento de rede associado a Services nesta instalação |
| CNI / Calico | fornece conectividade de rede aos Pods e funcionalidades de networking/policy |

---

# 6. `kubeadm`, `kubelet` e `kubectl`

Estes três nomes aparecem repetidamente, mas têm papéis muito diferentes.

| Ferramenta | Pergunta a que responde |
|---|---|
| `kubeadm` | Como inicializo, integro ou atualizo este cluster? |
| `kubelet` | Como mantenho os Pods deste Node em execução? |
| `kubectl` | Como comunico administrativamente com a API Kubernetes? |

## 6.1. `kubeadm`

É uma ferramenta de bootstrap e ciclo de vida do cluster.

Nesta sessão usamos:

```text
kubeadm init          → criar o primeiro Control Plane
kubeadm token create  → gerar credenciais temporárias de bootstrap
kubeadm join          → integrar o Worker
kubeadm upgrade plan  → analisar o upgrade possível
kubeadm upgrade apply → atualizar o primeiro Control Plane
kubeadm upgrade node  → atualizar configuração local de um Node adicional
```

## 6.2. `kubelet`

É um serviço local do sistema operativo:

```bash
systemctl status kubelet
```

O kubelet comunica com o API Server e com o runtime do Node.

## 6.3. `kubectl`

É um cliente. Não é o cluster e não precisa de correr como daemon.

```text
kubectl + kubeconfig
        ↓
      HTTPS
        ↓
   kube-apiserver
```

Por esta razão, executar `kubectl` no Worker sem kubeconfig administrativo pode produzir:

```text
The connection to the server localhost:8080 was refused
```

Isso **não significa automaticamente que o cluster está em baixo**. Significa, neste cenário, que aquele utilizador no Worker não tem contexto administrativo configurado.

---

# 7. Preparar Linux antes do bootstrap

Kubernetes depende de funcionalidades do kernel e de uma configuração coerente do host.

No laboratório, as verificações começam por:

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

## 7.1. Porque verificar o hostname?

Várias operações são específicas de um Node. Confundir os terminais pode levar, por exemplo, a tentar executar `kubeadm token create` no Worker.

```text
k8s-cp-01 → administração e Control Plane
k8s-wk-01 → Worker
```

## 7.2. Disco virtual não é o mesmo que filesystem utilizável

Um hipervisor pode apresentar um disco de 48 GB, enquanto o filesystem `/` continua com cerca de 10 GB.

```text
Disco virtual
   ↓
partição
   ↓
Physical Volume LVM
   ↓
Volume Group
   ↓
Logical Volume
   ↓
filesystem /
```

Por isso usamos em conjunto:

```bash
lsblk
pvs
vgs
lvs
df -h /
```

No ensaio desta sessão, a falta de espaço útil provocou `DiskPressure`, que levou a evictions de Pods. A correção foi aumentar o Logical Volume e o filesystem raiz.

> O procedimento de expansão LVM deve ser aplicado apenas depois de confirmar o layout real do disco. Não se deve copiar cegamente comandos de `growpart`, `pvresize` ou `lvextend` para outra topologia.

## 7.3. Swap

Na baseline do laboratório usamos swap desativada:

```bash
sudo swapoff -a
```

É uma decisão de configuração do laboratório, coerente com o percurso `kubeadm` adotado. Não deve ser transformada numa afirmação genérica de que Kubernetes nunca pode funcionar com swap.

## 7.4. Módulos do kernel

```text
overlay       → suporte ao modelo de filesystem em camadas usado por containers
br_netfilter  → permite que tráfego de bridges seja observado pelas regras de netfilter
```

Carregamento:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

## 7.5. Forwarding e tráfego bridged

Na preparação do laboratório configuramos:

```text
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

`ip_forward=1` permite que o host encaminhe pacotes IPv4 entre interfaces/redes. O segundo parâmetro permite integrar tráfego bridged com o processamento netfilter usado pela solução de rede.

## 7.6. cgroup v2

No ambiente validado:

```bash
stat -fc %T /sys/fs/cgroup
```

produz:

```text
cgroup2fs
```

Os cgroups permitem controlar e contabilizar recursos associados a processos. Kubernetes, o kubelet e o runtime precisam de uma estratégia coerente para gerir esses grupos.

---

# 8. Runtime: CRI, containerd e runc

O kubelet não deve depender diretamente da implementação interna de cada runtime. A integração é realizada através do **Container Runtime Interface (CRI)**.

```text
kubelet
   ↓ CRI
containerd
   ↓
runc
   ↓
Linux kernel
```

## 8.1. CRI

CRI é uma interface/protocolo que permite ao kubelet trabalhar com runtimes compatíveis.

No laboratório, o endpoint é:

```text
/run/containerd/containerd.sock
```

Podemos pensar no socket como o ponto local através do qual kubelet e containerd comunicam.

## 8.2. containerd

A baseline usa `containerd 2.2.6`. A série 2.2 é adequada ao percurso Kubernetes 1.35/1.36 adotado nesta sessão.

A configuração é gerada a partir de:

```bash
containerd config default
```

Depois confirmamos dois aspetos essenciais:

```text
CRI ativo
SystemdCgroup = true
```

## 8.3. Porque `SystemdCgroup = true`?

Ubuntu usa `systemd`, e a baseline usa cgroup v2. Para evitar duas estratégias diferentes de gestão de cgroups, kubelet e runtime devem estar alinhados no driver `systemd`.

No containerd 2.x, a opção fica associada ao runtime `runc`.

## 8.4. `containerd.io` e `runc`

Na instalação validada, o package `containerd.io` forneceu também o `runc` utilizado pelo runtime. A combinação observada foi:

```text
containerd 2.2.6
runc       1.3.6
```

Isto é relevante para troubleshooting: quando se investiga uma falha de runtime, é importante saber **qual package forneceu efetivamente os binários**, e não apenas assumir com base no nome do comando.

---

# 9. Gestão explícita de versões Kubernetes

Uma formação reproduzível não deve instalar simplesmente:

```bash
sudo apt install kubeadm kubelet kubectl
```

sem controlar a origem e a versão.

## 9.1. Repositórios por minor

Nesta sessão usamos primeiro o repositório da minor 1.35 e, no upgrade, o da minor 1.36.

Exemplo conceptual:

```text
pkgs.k8s.io/core:/stable:/v1.35/deb/
                    │
                    └── minor pretendida
```

## 9.2. Descobrir a versão disponível

```bash
apt-cache madison kubeadm
```

permite observar as versões publicadas pelo repositório configurado.

No laboratório, a seleção é filtrada:

```bash
awk '$3 ~ /^1\.35\./ {print $3; exit}'
```

Interpretação:

| Fragmento | Significado |
|---|---|
| `$3` | terceira coluna da linha |
| `~` | corresponde a uma expressão regular |
| `/^1\.35\./` | começa por `1.35.` |
| `{print $3; exit}` | mostra a primeira correspondência e termina |

Isto evita que uma versão de outra minor seja escolhida silenciosamente.

## 9.3. `apt-mark hold`

Depois de instalar:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

O objetivo é impedir que um upgrade genérico do sistema altere estes packages sem intenção.

Durante um upgrade controlado usamos o padrão:

```text
unhold
  ↓
instalar versão exata
  ↓
validar
  ↓
hold novamente
```

---

# 10. Inicializar o Control Plane com `kubeadm`

A operação é executada apenas em `k8s-cp-01`.

No laboratório validado:

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

## 10.1. Significado dos argumentos

| Argumento | Função |
|---|---|
| `--kubernetes-version=v1.35.8` | fixa a versão usada no bootstrap |
| `--apiserver-advertise-address=192.168.50.46` | indica o endereço do Control Plane anunciado pelo API Server |
| `--pod-network-cidr=10.244.0.0/16` | reserva a rede destinada aos endereços dos Pods |
| `--cri-socket=unix:///run/containerd/containerd.sock` | escolhe explicitamente o runtime CRI local |

## 10.2. O que `kubeadm init` prepara

De forma simplificada:

```text
pré-flight checks
      ↓
certificados e kubeconfigs
      ↓
manifestos dos static Pods
      ↓
etcd + API Server + controllers + scheduler
      ↓
configuração kubelet
      ↓
bootstrap do cluster
```

Os principais componentes do Control Plane são executados como **static Pods** geridos localmente pelo kubelet a partir de manifestos em `/etc/kubernetes/manifests/`.

## 10.3. Porque o Node pode ficar `NotReady` após o `init`?

Porque ainda não instalámos a rede CNI.

```text
Control Plane criado
       ↓
CNI ainda ausente
       ↓
rede de Pods incompleta
       ↓
Node pode surgir NotReady
```

Isso é um estado intermédio esperado, não uma razão para repetir `kubeadm init`.

---

# 11. kubeconfig e contextos

Depois do `kubeadm init`, o ficheiro administrativo é:

```text
/etc/kubernetes/admin.conf
```

No laboratório copiamos esse kubeconfig para:

```text
$HOME/.kube/config
```

para permitir ao utilizador administrativo executar `kubectl` sem indicar o ficheiro em cada comando.

## 11.1. O que contém um kubeconfig?

Conceptualmente:

```text
clusters    → onde está o API Server e em quem confiar
users       → credenciais
contexts    → associação entre cluster + user + namespace opcional
```

Um contexto pode ser visto como:

```text
contexto = cluster + identidade + namespace opcional
```

Comandos úteis:

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config view
```

> `admin.conf` contém credenciais privilegiadas. Não deve ser distribuído indiscriminadamente nem copiado para o Worker apenas para facilitar comandos administrativos.

---

# 12. Redes do cluster: host, Pod e Service

No laboratório coexistem três espaços de endereçamento:

```text
Rede das VMs   192.168.50.0/24
Pod CIDR       10.244.0.0/16
Service CIDR   10.96.0.0/12
```

Estas redes não devem sobrepor-se.

## 12.1. Porque não usamos `192.168.0.0/16` para Pods?

Porque `192.168.0.0/16` inclui `192.168.50.0/24`.

```text
192.168.0.0/16
└── contém 192.168.50.0/24
```

Isso criaria ambiguidade de routing entre a rede física dos hosts e a rede virtual dos Pods.

Por essa razão, a baseline validada usa:

```text
10.244.0.0/16
```

## 12.2. Service CIDR

O Service CIDR representa endereços virtuais atribuídos a Services do cluster. Na configuração `kubeadm` desta sessão usamos o valor predefinido:

```text
10.96.0.0/12
```

Não deve ser confundido com a rede dos Pods nem com os IPs físicos dos Nodes.

---

# 13. CNI, Calico e Tigera Operator

Kubernetes define o modelo de networking, mas depende de uma implementação CNI para fornecer a conectividade de Pods.

No laboratório usamos:

```text
Calico 3.32.2
Tigera Operator 1.42.6
```

## 13.1. O papel do Operator

Um Operator é software que observa recursos Kubernetes e executa lógica operacional para manter um componente no estado pretendido.

Nesta sessão, o Tigera Operator gere a instalação do Calico.

## 13.2. Instalação mínima da Sessão 4

Em vez de aplicar indiscriminadamente todos os recursos opcionais do exemplo completo da release, usamos apenas um recurso `Installation` controlado para o core networking.

Estrutura simplificada:

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
```

## 13.3. Campos principais

| Campo | Significado |
|---|---|
| `kind: Installation` | recurso interpretado pelo Tigera Operator |
| `cidr` | intervalo de endereços usado pelos Pods |
| `blockSize: 26` | tamanho dos blocos IPAM distribuídos aos Nodes; não é a máscara de cada Pod |
| `encapsulation: VXLANCrossSubnet` | política de encapsulamento VXLAN adotada pela instalação |
| `natOutgoing: Enabled` | permite NAT de saída para destinos externos ao pool |
| `nodeSelector: all()` | aplica o pool aos Nodes elegíveis |

## 13.4. CoreDNS e o CNI

É normal o CoreDNS não ficar funcional enquanto a rede de Pods não estiver operacional.

```text
kubeadm init
   ↓
CoreDNS criado
   ↓
CNI ainda ausente
   ↓
CoreDNS pode ficar Pending
   ↓
Calico converge
   ↓
CoreDNS pode executar normalmente
```

## 13.5. `tigerastatus`

No laboratório usamos principalmente:

```bash
kubectl get tigerastatus
```

O critério para o core Calico é:

```text
calico   AVAILABLE=True   PROGRESSING=False   DEGRADED=False
```

A instalação mínima não cria o recurso Tigera `APIServer`. Por isso, o componente `tiers` pode apresentar:

```text
Waiting for Tigera API server to be ready
```

Isso é uma consequência conhecida do âmbito reduzido deste laboratório e não deve ser confundido com falha do core networking quando `calico` e `ippools` estão disponíveis.

---

# 14. Integrar o Worker

O Worker entra no cluster através de um processo de bootstrap controlado.

## 14.1. Gerar o comando no Control Plane

No `k8s-cp-01`:

```bash
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

O resultado tem a forma:

```text
kubeadm join ENDERECO:6443 \
  --token TOKEN \
  --discovery-token-ca-cert-hash sha256:HASH
```

## 14.2. Significado dos elementos

| Elemento | Função |
|---|---|
| `ENDERECO:6443` | endpoint do API Server |
| `--token` | credencial temporária de bootstrap |
| `--discovery-token-ca-cert-hash` | permite ao Worker validar a identidade da CA do cluster |

No Worker, o comando é executado com privilégios:

```text
sudo kubeadm join ...
```

Sem `sudo`, o preflight devolve um erro relacionado com privilégios de root. A correção é executar o comando com os privilégios necessários, **não ignorar o preflight**.

## 14.3. Não executar placeholders literalmente

Isto é documentação:

```text
<IP_CONTROL_PLANE>
<TOKEN>
<HASH>
```

Os símbolos `<` e `>` têm significado para a shell. Devem ser substituídos pelos valores reais gerados.

## 14.4. Como validar corretamente

No Worker:

```bash
systemctl is-active kubelet
ls -l /etc/kubernetes/kubelet.conf
```

No Control Plane:

```bash
kubectl get nodes -o wide
```

O Worker não precisa do `admin.conf` para funcionar como Node.

---

# 15. Observar antes de alterar

Administrar Kubernetes não é apenas executar operações. É conseguir demonstrar o estado anterior e posterior.

Comandos básicos:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-wk-01
kubectl get tigerastatus
```

## 15.1. `get`, `describe` e `events`

```text
get       → fotografia resumida do estado
-o wide   → acrescenta informação operacional

describe  → detalhes, condições e eventos relacionados com um objeto

events    → sequência temporal de acontecimentos observados no cluster
```

Um diagnóstico sólido cruza várias fontes em vez de depender de uma única linha de output.

## 15.2. Condições dos Nodes

Duas condições particularmente importantes nesta sessão são:

```text
Ready
DiskPressure
```

Interpretação desejada:

```text
Ready=True
DiskPressure=False
```

`Ready=True` indica que o Node está disponível para o cluster. `DiskPressure=True` indica pressão de armazenamento suficiente para o kubelet tomar medidas de eviction.

---

# 16. Labels e selectors

Labels são pares chave/valor colocados nos metadados dos objetos.

Exemplo:

```yaml
metadata:
  labels:
    app: cordon-test
```

Podem ser usados para selecionar objetos:

```bash
kubectl get pods -l app=cordon-test
```

## 16.1. Label não é `nodeSelector`

Uma label descreve um objeto:

```text
app=cordon-test
```

Um `nodeSelector` exprime uma restrição de scheduling baseada em labels do Node:

```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-wk-01
```

No Pod de teste da sessão:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cordon-test
  labels:
    app: cordon-test
spec:
  nodeSelector:
    kubernetes.io/hostname: k8s-wk-01
  containers:
    - name: web
      image: nginx:1.28.0-alpine
      imagePullPolicy: IfNotPresent
  restartPolicy: Always
```

Interpretação:

| Campo | Função |
|---|---|
| `app: cordon-test` | label usada para identificar/selecionar o Pod |
| `nodeSelector` | força o Pod para o Worker indicado |
| `image` | imagem a executar |
| `imagePullPolicy: IfNotPresent` | só faz pull se a imagem não existir localmente |
| `restartPolicy: Always` | o kubelet tenta reiniciar o container enquanto o Pod existir |

Este Pod é criado diretamente e não é gerido por um Deployment. Essa diferença torna-se importante durante o `drain`.

---

# 17. Manutenção: `cordon`, `drain` e `uncordon`

## 17.1. `cordon`

```bash
kubectl cordon k8s-wk-01
```

Marca o Node como não elegível para novo scheduling normal.

O estado passa a incluir:

```text
SchedulingDisabled
```

Os Pods já existentes não são removidos apenas por causa do `cordon`.

## 17.2. `drain`

`drain` prepara um Node para manutenção, tentando evacuar Pods de forma controlada.

No exercício inicial usamos um selector para limitar o âmbito:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

### Flags

| Flag | Significado |
|---|---|
| `--ignore-daemonsets` | não tenta eliminar Pods controlados por DaemonSets |
| `--pod-selector=...` | restringe a operação aos Pods que correspondem à label indicada |

O Pod `cordon-test` é um Pod direto, sem controller. Por isso, o drain recusa removê-lo sem uma decisão explícita.

No exercício controlado acrescentamos:

```text
--force
```

Aqui `--force` significa aceitar a remoção de determinados Pods sem controller. Não é uma opção que deva ser acrescentada automaticamente sempre que um drain falha.

## 17.3. Porque os DaemonSets ficam no Node?

Um DaemonSet existe precisamente para garantir um Pod por Node elegível. Componentes como `calico-node`, o CSI node driver e `kube-proxy` são exemplos observados no laboratório.

## 17.4. `uncordon`

```bash
kubectl uncordon k8s-wk-01
```

volta a tornar o Node elegível para scheduling.

### Resumo

```text
cordon   → impedir novos agendamentos
   ↓
drain    → evacuar workloads apropriados
   ↓
manutenção
   ↓
uncordon → reabrir o Node ao scheduler
```

---

# 18. Health gates: quando é seguro avançar?

Uma alteração de risco deve ser precedida por um **health gate**.

Antes do upgrade verificamos:

```text
Nodes Ready
DiskPressure=False
Pods críticos estáveis
CoreDNS Running/Ready
Calico core saudável
containerd ativo
kubelet ativo
sem churn persistente de Pods
sem erros graves de runtime recorrentes
```

Exemplo de observação compacta:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

O valor pedagógico deste comando é cruzar, na mesma tabela:

```text
identidade do Node
+ condição Ready
+ pressão de disco
+ versão do kubelet
+ runtime
```

---

# 19. Recuperação antes do upgrade

No laboratório, depois de o health gate estar limpo, criamos snapshots **coordenados** das duas VMs.

```text
cluster saudável
      ↓
snapshot CP
snapshot Worker
      ↓
upgrade
```

Os snapshots servem como ponto de retorno do **ambiente pedagógico**.

> Em produção, snapshots de VMs não substituem uma estratégia de backup e recuperação do cluster. É necessário considerar especialmente o estado persistente em `etcd`, certificados, configuração e workloads com dados.

Também não se deve tratar rollback de Kubernetes como simples downgrade de packages APT. Um upgrade altera componentes, configuração e estado distribuído.

---

# 20. Porque o upgrade é sequencial

A sessão demonstra:

```text
Kubernetes 1.35.8
        ↓
Kubernetes 1.36.4
```

Não saltamos diretamente para outra minor.

A ordem geral é:

```text
1. preparar versão destino
2. kubeadm do primeiro Control Plane
3. kubeadm upgrade plan
4. kubeadm upgrade apply
5. kubelet/kubectl do Control Plane
6. validar
7. kubeadm do Worker
8. kubeadm upgrade node
9. kubelet/kubectl do Worker
10. validar novamente
```

## 20.1. Porque atualizar `kubeadm` primeiro?

`kubeadm` é a ferramenta que conhece o workflow de upgrade e valida a versão destino. Por isso, o binário `kubeadm` é atualizado antes de executar o plano/aplicação do upgrade.

## 20.2. `kubeadm upgrade plan`

```bash
sudo kubeadm upgrade plan
```

analisa o estado e mostra o upgrade possível.

No ensaio validado, indicou:

```text
Cluster:    1.35.8
kubeadm:    1.36.4
Target:     1.36.4
```

Também mostrou as mudanças esperadas em componentes do Control Plane e addons.

> `upgrade plan` **não atualiza o cluster**. É uma operação de análise.

## 20.3. `kubeadm upgrade apply`

No primeiro Control Plane:

```bash
sudo kubeadm upgrade apply v1.36.4
```

No ensaio, a operação atualizou com sucesso:

```text
kube-apiserver            1.35.8 → 1.36.4
kube-controller-manager   1.35.8 → 1.36.4
kube-scheduler            1.35.8 → 1.36.4
kube-proxy                1.35.8 → 1.36.4
CoreDNS                   1.13.1 → 1.14.2
etcd                      3.6.6-0 → 3.6.8-0
```

Durante esta fase surgiram timeouts transitórios enquanto `etcd` reiniciava, mas o próprio `kubeadm` confirmou a recuperação do componente e terminou com `SUCCESS`.

A regra é avaliar **o resultado completo**, e não concluir que todo o upgrade falhou por causa de uma linha intermédia.

---

# 21. Versões mistas durante o upgrade

Depois de `kubeadm upgrade apply`, é normal encontrar temporariamente:

```text
API Server:          1.36.4
kubelet CP:          1.35.8
kubelet Worker:      1.35.8
kubectl client:      1.35.8
```

`kubectl get nodes` apresenta a versão do **kubelet do Node**, não a versão do API Server.

Isto explica um dos outputs mais importantes do laboratório:

```text
kubectl version
  Client Version: 1.35.8
  Server Version: 1.36.4

kubectl get nodes
  k8s-cp-01  ...  1.35.8
```

Não existe contradição: estamos a observar componentes diferentes em momentos diferentes de um upgrade sequencial.

---

# 22. Atualizar o kubelet do Control Plane

Antes de atualizar o kubelet para uma nova minor, o Node é drenado:

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

Num Control Plane criado por `kubeadm`, os componentes principais são static Pods e não são tratados como workloads normais a evacuar.

Depois atualizamos `kubelet` e `kubectl`, reiniciamos o serviço e validamos:

```text
kubelet ativo
Node Ready
kubelet 1.36.4
containerd 2.2.6
```

Só depois usamos:

```bash
kubectl uncordon k8s-cp-01
```

No ensaio, o Node passou brevemente por `NotReady,SchedulingDisabled` imediatamente após o restart do kubelet e depois convergiu para `Ready,SchedulingDisabled`. A mudança transitória foi observada antes de fazer `uncordon`.

---

# 23. Atualizar o Worker

No Worker, a sequência é diferente do primeiro Control Plane.

Primeiro:

```bash
sudo kubeadm upgrade node
```

Este comando atualiza a configuração local do kubelet para a nova versão de configuração. Não é equivalente a `kubeadm upgrade apply` e não atualiza o binário `kubelet` por magia.

Depois o Worker é drenado a partir do Control Plane, o package do kubelet é atualizado localmente e o serviço é reiniciado.

## 23.1. O Tigera Operator durante o drain

No laboratório observámos que o Tigera Operator podia estar no Worker. Como o Deployment possui tolerations amplas, preferimos tornar a colocação explícita durante a manutenção e fixá-lo temporariamente ao Control Plane.

Exemplo conceptual:

```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-cp-01
```

Depois do upgrade e `uncordon` do Worker, o `nodeSelector` temporário é removido.

> Esta é uma decisão operacional específica da topologia pedagógica de dois nós. Não é uma regra universal de upgrade Kubernetes.

---

# 24. Resultado final validado

O health gate final do laboratório produziu:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

Também verificámos:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

Todos os Pods ativos estavam `Running`, não existiam recursos em estados anómalos no filtro final e o core Calico permanecia saudável.

O percurso completo ficou assim:

```text
1.35.8 saudável
      ↓
Control Plane → 1.36.4
      ↓
Worker ainda 1.35.8
      ↓
Worker → 1.36.4
      ↓
cluster convergido
      ↓
1.36.4 saudável
```

---

# 25. Troubleshooting orientado por evidências

A abordagem da sessão é:

```text
SINTOMA
   ↓
RECOLHER EVIDÊNCIA
   ↓
FORMULAR HIPÓTESE
   ↓
VALIDAR HIPÓTESE
   ↓
CORRIGIR
   ↓
VALIDAR NOVAMENTE
```

Não usamos:

```text
erro → experimentar flags aleatórias → esconder o erro
```

## 25.1. `DiskPressure` durante a instalação do Calico

### Sintoma

Pods começam a ser evicted e o Node reporta pressão de disco.

### Evidência

```bash
kubectl describe node <NODE>
df -h /
lsblk
pvs
vgs
lvs
```

### Causa observada no laboratório

O disco virtual tinha capacidade suficiente, mas o LV do filesystem raiz não tinha sido expandido.

### Aprendizagem

```text
tamanho do disco virtual ≠ tamanho disponível em /
```

## 25.2. `kubectl` no Worker tenta `localhost:8080`

### Sintoma

```text
The connection to the server localhost:8080 was refused
```

### Interpretação

O utilizador não tem kubeconfig administrativo configurado naquele Node.

### Correção no laboratório

Administrar o cluster a partir do Control Plane e validar localmente no Worker com `systemctl`, `kubelet --version` e os ficheiros de configuração apropriados.

## 25.3. `kubeadm token create` falha no Worker

O token é criado no Control Plane porque a operação precisa de credenciais administrativas para comunicar com a API.

```text
Control Plane → cria token
Worker        → executa join
```

## 25.4. Erro de chave GPG no repositório Docker

Durante a preparação do upgrade observámos:

```text
NO_PUBKEY 7EA0A9C3F273FCD8
```

A solução foi recriar a configuração atual do repositório Docker usando `/etc/apt/keyrings/docker.asc` e um ficheiro `docker.sources`, e só depois repetir `apt-get update`.

A aprendizagem é importante: um APT que avisa que está a reutilizar índices anteriores não deve ser tratado como se todos os repositórios tivessem sido atualizados com sucesso.

## 25.5. AppArmor / runc

Num ensaio anterior surgiram mensagens como:

```text
unable to signal init: permission denied
apparmor="DENIED"
```

Na instalação limpa validada com `containerd 2.2.6` e `runc 1.3.6`, o problema **não voltou a ser reproduzido**, mesmo após criação/remoção de Pods, drains e upgrade.

A conclusão correta é limitada à evidência:

```text
problema anterior não reproduzido na baseline limpa validada
```

Não concluímos que “AppArmor estava avariado” nem que uma determinada versão do runtime é, por si só, a causa ou a cura.

Não se desativa AppArmor globalmente como primeira tentativa de troubleshooting.

## 25.6. Warnings de arranque do kubelet

Após o restart do kubelet no Worker apareceram de forma transitória mensagens como:

```text
checkpoint is not found
no imagefs label for configured runtime
```

O Node convergiu para:

```text
Ready=True
DiskPressure=False
```

As mensagens não continuaram a repetir-se como falha persistente.

A regra é:

```text
uma linha de log isolada
        ≠
falha operacional persistente
```

Devemos verificar recorrência, condições do Node, estado dos Pods e impacto real.

---

# 26. Comandos de observação que deves dominar

| Objetivo | Comando |
|---|---|
| Nodes | `kubectl get nodes -o wide` |
| Pods de todos os namespaces | `kubectl get pods -A -o wide` |
| Estado Calico | `kubectl get tigerastatus` |
| Eventos recentes | `kubectl get events -A --sort-by=.lastTimestamp` |
| Detalhes de um Node | `kubectl describe node <NODE>` |
| Versão API/client | `kubectl version` |
| Versão kubelet local | `kubelet --version` |
| Serviço kubelet | `systemctl is-active kubelet` |
| Serviço containerd | `systemctl is-active containerd` |
| Logs kubelet | `journalctl -u kubelet --since "-10 min" --no-pager` |
| Logs kernel | `journalctl -k --since "-10 min" --no-pager` |

## Flags frequentes do `kubectl`

| Flag | Função |
|---|---|
| `-n <namespace>` | restringe a um namespace |
| `-A` | inclui todos os namespaces |
| `-o wide` | apresenta colunas adicionais |
| `-o yaml` | mostra a representação YAML do recurso |
| `-l chave=valor` | filtra através de labels |
| `--field-selector` | filtra por campos do objeto |
| `--sort-by` | ordena pelo campo indicado |
| `--no-headers` | omite cabeçalhos quando apropriado |

---

# 27. Pontos-chave da sessão

```text
Kubernetes trabalha por estado desejado e reconciliação.

Control Plane gere o cluster.
Worker executa workloads.

kubeadm ≠ kubelet ≠ kubectl.

kubelet comunica com containerd através do CRI.

Hosts, Pods e Services usam redes distintas.

CNI é necessário para a rede de Pods.

Ready=True não elimina a necessidade de observar outras condições.

DiskPressure é uma condição operacional relevante.

cordon ≠ drain ≠ uncordon.

upgrade plan observa; upgrade apply altera.

A versão mostrada em `kubectl get nodes` é a versão do kubelet.

Upgrades minor são sequenciais.

Antes de alterar: observar.
Depois de alterar: validar novamente.
```

---

# 28. Exercícios de consolidação

## Exercício 1 — Arquitetura

Explica, por palavras tuas, o que acontece desde o momento em que executas:

```bash
kubectl get nodes
```

até receberes uma resposta. Inclui `kubectl`, kubeconfig e API Server.

## Exercício 2 — Runtime

Ordena corretamente:

```text
runc
kubelet
kernel
containerd
CRI
```

Depois explica a função de cada elemento.

## Exercício 3 — Redes

Tens:

```text
rede física: 192.168.50.0/24
```

Explica por que motivo `192.168.0.0/16` não é uma boa escolha para Pod CIDR neste ambiente e por que `10.244.0.0/16` evita essa sobreposição.

## Exercício 4 — Estado intermédio

Depois de `kubeadm upgrade apply v1.36.4` observas:

```text
kubectl version       → Server v1.36.4
kubectl get nodes     → k8s-cp-01 v1.35.8
```

Existe uma contradição? Justifica.

## Exercício 5 — Manutenção

Explica a diferença entre:

```text
cordon
drain
uncordon
```

e indica por que motivo `--force` não deve ser acrescentado automaticamente a um drain que falhou.

## Exercício 6 — Troubleshooting

Um Node aparece:

```text
Ready=True
DiskPressure=True
```

Que evidências recolherias antes de tentar corrigir o problema?

## Exercício 7 — Sequência do upgrade

Coloca pela ordem correta:

```text
upgrade do kubelet Worker
kubeadm upgrade plan
kubeadm upgrade node
upgrade do kubelet Control Plane
kubeadm upgrade apply
upgrade kubeadm no Control Plane
upgrade kubeadm no Worker
health gate final
```

---

# 29. Autoavaliação

No final da sessão, confirma se consegues afirmar:

- [ ] Sei explicar estado desejado, estado observado e reconciliação.
- [ ] Sei identificar os principais componentes do Control Plane e dos Nodes.
- [ ] Sei distinguir `kubeadm`, `kubelet` e `kubectl`.
- [ ] Sei explicar CRI, containerd, runc e cgroups.
- [ ] Sei verificar o espaço real do filesystem e interpretar `DiskPressure`.
- [ ] Sei explicar por que o Pod CIDR não pode sobrepor-se à rede das VMs.
- [ ] Sei explicar o papel do CNI e do Calico.
- [ ] Sei explicar kubeconfig e contextos.
- [ ] Sei gerar o join no Control Plane e executá-lo no Worker.
- [ ] Sei explicar labels e `nodeSelector`.
- [ ] Sei aplicar e interpretar `cordon`, `drain` e `uncordon`.
- [ ] Sei construir um health gate antes de um upgrade.
- [ ] Sei explicar a sequência `1.35.x → 1.36.x`.
- [ ] Sei interpretar um estado temporário com versões diferentes no mesmo cluster.
- [ ] Sei distinguir um warning transitório de uma falha persistente através de evidências.

---

# 30. Laboratório e recursos de apoio

O procedimento operacional completo encontra-se em:

```text
sessao-04/formando/labs/laboratorio_integrado_sessao_4.md
```

Recursos complementares da sessão:

- [`README.md`](README.md) — enquadramento da sessão;
- [`compatibilidade.md`](compatibilidade.md) — matriz de versões adotada;
- [`checklist.md`](checklist.md) — preparação das VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints operacionais;
- [`folha_evidencias.md`](folha_evidencias.md) — registo de evidências;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico por evidências;
- [`manifests/`](manifests/) — manifestos utilizados na sessão;
- [`referencias.md`](referencias.md) — bibliografia e documentação oficial.

---

# 31. Fontes e leituras recomendadas

A preparação conceptual deste manual é coerente com a bibliografia disponibilizada na formação, nomeadamente:

- *The Kubernetes Book* — modelo declarativo, estado desejado, reconciliação, Control Plane, CNI e CRI;
- *Kubernetes in Action* — arquitetura, Pods, Nodes, scheduling e operação do cluster;
- *Kubernetes: Up & Running* — arquitetura e administração de clusters Kubernetes.

Para procedimentos que dependem da versão, deve prevalecer a documentação oficial da versão utilizada no laboratório:

- Kubernetes v1.36 — Cluster Architecture: https://v1-36.docs.kubernetes.io/docs/concepts/architecture/
- Kubernetes — Container Runtimes / CRI e cgroup drivers: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Kubernetes v1.36 — Upgrading kubeadm clusters 1.35.x → 1.36.x: https://v1-36.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Calico — System requirements e versões Kubernetes testadas: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
- containerd — Kubernetes support matrix: https://github.com/containerd/containerd/blob/main/RELEASES.md

> Livros são excelentes para conceitos e modelos mentais. Para comandos, versões suportadas, compatibilidade e procedimentos de upgrade, consultar sempre a documentação oficial correspondente à versão em utilização.
