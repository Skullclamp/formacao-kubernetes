# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: da VM Ubuntu limpa ao cluster 1.36.4 atualizado

**Sessão:** 4  
**Duração da sessão:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**Cenário:** cluster Kubernetes on-premises com `kubeadm`, `containerd` e Calico

Este laboratório acompanha uma única história técnica. Tal como no laboratório da Sessão 3, o objetivo **não é copiar comandos sem os compreender**. Em cada etapa é explicado:

```text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
COMANDO
        ↓
OPÇÕES / FLAGS / CAMPOS
        ↓
OUTPUT ESPERADO
        ↓
O QUE OBSERVAR
        ↓
ERRO FREQUENTE / DECISÃO
        ↓
REGISTAR EVIDÊNCIA
```

A regra pedagógica da sessão é:

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

> **Baseline validada em laboratório:** este percurso foi executado de ponta a ponta em duas VMs Ubuntu 26.04.1 LTS, partindo de Kubernetes 1.35.8 e terminando em Kubernetes 1.36.4.

> **Como interpretar os outputs:** nomes de Pods, hashes, tokens, timestamps, endereços IP de Pods e tempos podem variar. Os blocos **Output esperado (exemplo)** mostram a evidência essencial que deve ser reconhecida, e não texto para comparar carácter a carácter.

---

# 0. Percurso e baseline

## 0.1. Baseline técnica validada

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
Filesystem /:            40 GB no laboratório validado
```

### Porque usamos `10.244.0.0/16` para os Pods?

A rede física das VMs é `192.168.50.0/24`. Um Pod CIDR `192.168.0.0/16` **sobrepor-se-ia** a essa rede, porque inclui o intervalo `192.168.50.0/24`.

O cluster usa, por isso:

```text
Rede física das VMs   192.168.50.0/24
Pod CIDR              10.244.0.0/16
Service CIDR          10.96.0.0/12
```

As redes de hosts, Pods e Services devem ser distintas.

## 0.2. História técnica do laboratório

```text
VMs Ubuntu preparadas
      ↓
Linux / módulos / sysctl / disco
      ↓
containerd 2.2.6 + runc 1.3.6
      ↓
Kubernetes 1.35.8
      ↓
kubeadm init no Control Plane
      ↓
Calico 3.32.2
      ↓
kubeadm join do Worker
      ↓
cluster 1.35.8 saudável
      ↓
Pod de teste
      ↓
cordon / drain / uncordon
      ↓
health gate + snapshot coordenado
      ↓
kubeadm upgrade apply 1.36.4
      ↓
kubelet/kubectl do Control Plane
      ↓
kubeadm upgrade node no Worker
      ↓
drain integral do Worker
      ↓
kubelet/kubectl do Worker
      ↓
cluster 1.36.4 saudável
```

## 0.3. Onde executar os comandos

| Operação | Nó | Porquê |
|---|---|---|
| `kubeadm init` | Control Plane | cria o primeiro nó do cluster e os componentes de controlo |
| `kubeadm token create` | Control Plane | o token de bootstrap pertence ao cluster já inicializado |
| `kubectl ...` administrativo | Control Plane | é aqui que configuramos o kubeconfig administrativo |
| `kubeadm join` | Worker | integra o Worker no cluster existente |
| `kubeadm upgrade apply` | Control Plane | atualiza os componentes do Control Plane |
| `kubeadm upgrade node` | Worker | atualiza a configuração local do kubelet do Worker |
| `systemctl` / `journalctl` | nó em diagnóstico | observa serviços e logs locais desse nó |

> O Worker **não recebe** `/etc/kubernetes/admin.conf` para uso interativo. Executar `kubectl get nodes` no Worker sem kubeconfig administrativo pode resultar numa tentativa de ligação a `http://localhost:8080` e em `connection refused`. Isto não significa que o Worker tenha saído do cluster.

---

# CP1 — Preparar e validar as duas VMs

Executar nos **dois nós**, salvo indicação em contrário.

## 1.1. Confirmar identidade e recursos

### O que estamos a fazer

Antes de instalar Kubernetes precisamos de saber exatamente em que VM estamos e confirmar rede, memória, swap, armazenamento e cgroups. Esta verificação evita erros como executar `kubeadm init` no Worker ou descobrir demasiado tarde que o filesystem raiz é demasiado pequeno.

### Comandos

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

### O que significa cada comando

| Comando | Função |
|---|---|
| `hostname` | mostra o nome do nó; permite distinguir CP de Worker |
| `ip -br address` | apresenta interfaces e IPs em formato resumido |
| `free -h` | mostra utilização de memória em formato legível |
| `swapon --show` | lista swap ativa; saída vazia significa ausência de swap ativa |
| `lsblk -f` | mostra discos, partições, LVM e filesystems |
| `df -h /` | mostra o espaço realmente utilizável pelo filesystem raiz |
| `stat -fc %T /sys/fs/cgroup` | identifica a versão/montagem de cgroups; em cgroup v2 surge `cgroup2fs` |

### Output esperado (exemplo)

```text
k8s-cp-01
...
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   40G  8.1G   30G  22% /
...
cgroup2fs
```

No Worker, o primeiro comando deve devolver:

```text
k8s-wk-01
```

### O que observar

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
cgroups       → cgroup2fs
swap          → vazio
filesystem /  → espaço suficiente; 40 GB no laboratório validado
```

> **Ponto crítico validado:** uma VM pode ter um disco virtual de 48 GB e, mesmo assim, o filesystem `/` ter apenas 10 GB. Kubernetes e containerd usam espaço real do filesystem, não o tamanho teórico do disco virtual.

---

## 1.2. Expandir o filesystem raiz quando necessário

### O que estamos a fazer

No laboratório validado, `/dev/sda` tinha 48 GB, mas `/dev/sda3` e o LVM utilizavam apenas parte desse espaço. O kubelet entrou em `DiskPressure` durante a instalação do Calico.

Esta secção **só é executada se o layout do formando corresponder** a `/dev/sda3` como PV de `ubuntu-vg` e `/dev/ubuntu-vg/ubuntu-lv` como LV raiz.

### Observar antes de alterar

```bash
lsblk
sudo pvs
sudo vgs
sudo lvs
```

| Comando | Função |
|---|---|
| `pvs` | mostra Physical Volumes LVM |
| `vgs` | mostra Volume Groups e espaço livre |
| `lvs` | mostra Logical Volumes |

Se existir espaço não particionado no disco:

```bash
sudo apt-get update
sudo apt-get install -y cloud-guest-utils

sudo growpart -N /dev/sda 3
sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -r -L 40G /dev/ubuntu-vg/ubuntu-lv

df -h /
```

### Flags e argumentos importantes

| Elemento | Significado |
|---|---|
| `growpart -N` | simula a expansão da partição; não altera o disco |
| `/dev/sda 3` | disco `/dev/sda`, partição número 3 |
| `pvresize /dev/sda3` | informa o LVM de que o PV passou a ter mais espaço |
| `lvextend` | aumenta o Logical Volume |
| `-r` | redimensiona também o filesystem associado |
| `-L 40G` | define 40 GB como tamanho final do LV |

### Output esperado (exemplo)

```text
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   40G  7.0G   31G  19% /
```

> **Não executar** `resize2fs /dev/sda3`. Neste layout `/dev/sda3` é um PV LVM; o filesystem está no Logical Volume.

---

## 1.3. Desativar swap e preparar o kernel

### O que estamos a fazer

O kubelet e o runtime necessitam de suporte adequado do kernel para networking e gestão dos containers. Neste laboratório desativamos swap e carregamos os módulos `overlay` e `br_netfilter`.

```bash
sudo swapoff -a
```

- `swapoff` — desativa áreas de swap;
- `-a` — aplica a todas as áreas de swap ativas.

Criar a configuração de módulos:

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### O que fazem os módulos

| Módulo | Função |
|---|---|
| `overlay` | suporta OverlayFS, usado em camadas de filesystems de containers |
| `br_netfilter` | permite que tráfego de bridges seja processado pelas regras netfilter/iptables |

Configurar sysctl:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

| Parâmetro | Função |
|---|---|
| `net.bridge.bridge-nf-call-iptables=1` | permite filtrar tráfego bridged com iptables |
| `net.ipv4.ip_forward=1` | permite encaminhamento IPv4 entre interfaces/redes |

Validar:

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

### Output esperado (exemplo)

```text
overlay ...
br_netfilter ...
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

`swapon --show` deve ficar sem linhas de swap ativa.

---

## 1.4. Garantir resolução entre os nós

### O que estamos a fazer

O Control Plane e o Worker devem conseguir resolver os nomes um do outro. No laboratório validado:

```text
192.168.50.46  k8s-cp-01
192.168.50.65  k8s-wk-01
```

Adicionar/confirmar no `/etc/hosts` de **ambas as VMs** e testar:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

| Elemento | Significado |
|---|---|
| `getent hosts` | consulta a resolução de nomes usada pelo sistema |
| `ping -c 2` | envia exatamente dois pedidos ICMP |

### Output esperado (exemplo)

```text
192.168.50.46  k8s-cp-01
192.168.50.65  k8s-wk-01
...
2 packets transmitted, 2 received, 0% packet loss
```

---

## 1.5. Confirmar que não existe Kubernetes residual

### Porque é importante

Um cluster anterior pode deixar manifests, configuração CNI, certificados, sockets, packages ou repositórios que contaminam o laboratório.

```bash
snap list microk8s 2>/dev/null || true
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube' || true
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' kubeadm kubelet kubectl 2>/dev/null || true

grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

### O que observar

Numa VM preparada de raiz não deve existir um Control Plane Kubernetes anterior nem packages de uma minor diferente.

> Se a VM já tiver Kubernetes 1.36/1.37 de outro ensaio, **não fazer downgrade improvisado**. Repor a VM/snapshot limpo.

---

# CP2 — Instalar e configurar containerd 2.2.6

Executar nos **dois nós**.

## 2.1. Adicionar o repositório Docker

### O que estamos a fazer

O pacote `containerd.io` usado no laboratório é obtido do repositório oficial Docker. Configuramos a chave e o repositório no formato moderno `docker.sources`.

```bash
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### Flags do `curl`

| Flag | Função |
|---|---|
| `-f` | termina com erro perante HTTP 4xx/5xx |
| `-s` | modo silencioso |
| `-S` | mostra erros apesar de `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava a resposta no ficheiro indicado |

Criar o repositório:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
```

### O que significam os campos

| Campo | Função |
|---|---|
| `Types: deb` | repositório de packages binários Debian |
| `URIs` | endereço base do repositório |
| `Suites` | codename Ubuntu detetado automaticamente |
| `Components: stable` | canal estável |
| `Architectures` | arquitetura local, por exemplo `amd64` |
| `Signed-By` | chave usada para validar assinaturas do repositório |

### Output esperado

O `apt-get update` deve terminar sem `NO_PUBKEY`.

---

## 2.2. Descobrir e instalar a série 2.2.x

```bash
apt-cache madison containerd.io
```

`apt-cache madison` mostra versões disponíveis do package nos repositórios configurados.

Selecionar a primeira versão 2.2.x disponível:

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\./ {print $3; exit}'
)"

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
test -n "$CONTAINERD_PKG_VERSION"
```

### O que faz esta expressão

| Parte | Função |
|---|---|
| `$(...)` | substitui pelo output do comando interno |
| `awk '$3 ~ /^2\.2\./'` | seleciona linhas cuja terceira coluna começa por `2.2.` |
| `{print $3; exit}` | devolve a primeira versão encontrada e termina |
| `test -n` | falha se a variável estiver vazia |

No laboratório validado foi selecionado `2.2.6-1~ubuntu.26.04~resolute`.

Instalar e fixar:

```bash
sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
sudo apt-mark hold containerd.io
```

- `-y` — confirma automaticamente a instalação;
- `package=versão` — impede o APT de escolher silenciosamente outra versão;
- `apt-mark hold` — impede atualizações automáticas do package durante o laboratório.

---

## 2.3. Gerar configuração e ativar `SystemdCgroup`

### O que estamos a fazer

O kubelet e o runtime devem usar uma estratégia de cgroups coerente. Com systemd/cgroup v2, configuramos o runtime `runc` com `SystemdCgroup = true`.

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Editar:

```bash
sudo nano /etc/containerd/config.toml
```

Confirmar que:

```text
1. `cri` NÃO aparece em `disabled_plugins`
2. `SystemdCgroup = true`
```

Na configuração v3 do containerd 2.2.x, a opção do `runc` encontra-se na árvore do plugin CRI runtime.

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

| Comando | Função |
|---|---|
| `restart` | reinicia o serviço com a nova configuração |
| `enable` | configura arranque automático no boot |

Validar:

```bash
containerd --version
runc --version
sudo systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

### Output esperado (elementos relevantes)

```text
containerd containerd v2.2.6 ...
runc version 1.3.6
active
...
SystemdCgroup = true
...
io.containerd.cri.v1.images   ... ok
io.containerd.cri.v1.runtime  ... ok
```

### Modelo mental

```text
kubelet
   ↓ CRI
containerd
   ↓ OCI runtime
runc
   ↓
kernel Linux
```

---

# CP3 — Instalar exatamente Kubernetes 1.35.8

Executar nos **dois nós**.

## 3.1. Configurar o repositório da minor 1.35

### O que estamos a fazer

Os repositórios `pkgs.k8s.io` são organizados por minor. Usar explicitamente `v1.35` impede instalar 1.36/1.37 por engano.

```bash
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm
```

### O que significam os elementos principais

| Elemento | Função |
|---|---|
| `gpg --dearmor` | converte a chave para formato usado pelo APT |
| `--yes` | permite substituir o ficheiro de chave quando necessário |
| `signed-by=...` | associa este repositório à chave indicada |
| `/v1.35/deb/` | fixa a família de packages Kubernetes 1.35 |

### Output esperado (exemplo)

```text
kubeadm | 1.35.8-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb Packages
```

---

## 3.2. Selecionar explicitamente o patch

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

printf 'Kubernetes package: %s\n' "$K8S_PKG_VERSION"
test -n "$K8S_PKG_VERSION"
```

No laboratório validado:

```text
Kubernetes package: 1.35.8-1.1
```

Instalar:

```bash
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
```

### Para que serve cada componente

| Componente | Papel |
|---|---|
| `kubelet` | agente do nó; garante que os Pods atribuídos ao nó são executados |
| `kubeadm` | ferramenta de bootstrap e upgrade do cluster |
| `kubectl` | cliente administrativo da API Kubernetes |

> Antes de `kubeadm init`, o kubelet pode estar ativo mas reiniciar/aguardar configuração. Isso é normal: ainda não recebeu a configuração do cluster.

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
apt-mark showhold
```

### Output esperado

```text
v1.35.8
Kubernetes v1.35.8
Client Version: v1.35.8
...
kubeadm
kubectl
kubelet
```

**Não avançar se aparecer 1.36 ou 1.37.**

---

# CP4 — Inicializar o Control Plane

Executar **apenas no `k8s-cp-01`**.

## 4.1. Confirmar o nó

```bash
hostname

test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: kubeadm init só pode ser executado em k8s-cp-01"
  exit 1
}
```

`test` funciona aqui como uma guarda de segurança: se o hostname não for o esperado, o bloco `{ ... }` mostra a mensagem e termina.

---

## 4.2. Confirmar ausência de conflito de CIDR

### O que estamos a fazer

Antes de criar a rede de Pods, verificamos se `10.244.0.0/16` e `10.96.0.0/12` não correspondem já a redes locais diretamente ligadas.

```bash
ip route get 10.244.0.1
ip route get 10.96.0.1
```

No laboratório validado, ambos os destinos eram encaminhados pelo gateway normal da VM antes da criação do cluster, não por uma rota local conflitante.

> Se o host já usar uma destas redes, **não avançar**. O plano de endereçamento deve ser revisto.

---

## 4.3. Executar `kubeadm init`

### O que estamos a fazer

`kubeadm init` cria o primeiro Control Plane: certificados, kubeconfigs, manifests estáticos do API Server, etcd, Controller Manager e Scheduler, além da configuração inicial do kubelet.

Derivar a versão real instalada:

```bash
K8S_PKG_VERSION="$(dpkg-query -W -f='${Version}' kubeadm)"
K8S_SEMVER="v${K8S_PKG_VERSION%%-*}"
printf 'Bootstrap Kubernetes: %s\n' "$K8S_SEMVER"
```

No laboratório:

```text
Bootstrap Kubernetes: v1.35.8
```

Inicializar:

```bash
sudo kubeadm init \
  --kubernetes-version="$K8S_SEMVER" \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

### Flags do `kubeadm init`

| Flag | Função |
|---|---|
| `--kubernetes-version` | versão que o Control Plane deve usar |
| `--apiserver-advertise-address` | IP do Control Plane anunciado pelo API Server |
| `--pod-network-cidr` | bloco de endereços reservado para a rede de Pods |
| `--cri-socket` | socket CRI explícito do containerd |

### Output esperado (excerto)

```text
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:
  mkdir -p $HOME/.kube
  ...

Then you can join any number of worker nodes by running the following on each as root:
  kubeadm join 192.168.50.46:6443 ...
```

### O que observar

O `kubeadm init` terminar com sucesso não significa ainda que o Node esteja `Ready`. Ainda falta instalar o CNI.

---

## 4.4. Configurar o kubeconfig administrativo

### O que estamos a fazer

`kubectl` precisa de saber a que API Server se ligar e que credenciais usar. Copiamos o kubeconfig administrativo criado pelo kubeadm para a conta do formando **apenas no Control Plane**.

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

| Comando | Função |
|---|---|
| `mkdir -p` | cria a diretoria se ainda não existir |
| `cp` | copia o kubeconfig administrativo |
| `chown` | entrega o ficheiro ao utilizador atual |
| `chmod 600` | permite leitura/escrita apenas ao proprietário |

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

### Output esperado antes do CNI

```text
NAME        STATUS     ROLES           VERSION
k8s-cp-01   NotReady   control-plane   v1.35.8
```

CoreDNS pode estar `Pending` até existir rede CNI. Isto é esperado nesta etapa.

---

# CP5 — Instalar Calico 3.32.2

Executar no **Control Plane**.

## 5.1. Instalar CRDs e Tigera Operator

### O que estamos a fazer

O Calico fornece networking CNI e políticas de rede. Nesta sessão instalamos o Operator e apenas o recurso `Installation` necessário ao core networking.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

### Elementos importantes

| Elemento | Função |
|---|---|
| `export CALICO_VERSION=...` | guarda a versão numa variável reutilizável |
| `kubectl create -f URL` | cria os recursos YAML obtidos do URL |
| CRDs | adicionam tipos de recursos Calico/Tigera à API Kubernetes |
| Tigera Operator | reconcilia os recursos Calico desejados com o estado real |

Validar:

```bash
kubectl get pods -n tigera-operator -o wide
kubectl -n tigera-operator get deploy tigera-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

### Output esperado

```text
tigera-operator-...   1/1   Running   ...
quay.io/tigera/operator:v1.42.6
```

---

## 5.2. Aplicar a configuração mínima da rede

O manifesto usado nesta sessão é `../../manifests/calico_installation_sessao4.yaml` se estiveres dentro de `formando/labs/`. A partir da raiz `sessao-04`, o caminho é `manifests/calico_installation_sessao4.yaml`.

Antes de aplicar, observa:

```bash
cat ../../manifests/calico_installation_sessao4.yaml
```

Conteúdo relevante:

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

### O que significam os campos do YAML

| Campo | Função |
|---|---|
| `apiVersion` | API usada para interpretar o recurso |
| `kind: Installation` | pede ao Operator uma instalação Calico |
| `metadata.name: default` | nome exigido para a instalação principal |
| `ipPools` | define pools de IP para Pods |
| `blockSize: 26` | tamanho dos blocos IP atribuídos internamente aos nós |
| `cidr: 10.244.0.0/16` | intervalo global usado pelos Pods |
| `VXLANCrossSubnet` | encapsula VXLAN quando o tráfego atravessa sub-redes |
| `natOutgoing: Enabled` | aplica NAT à saída dos Pods para redes externas |
| `nodeSelector: all()` | pool disponível para todos os nós |

Aplicar:

```bash
kubectl create -f ../../manifests/calico_installation_sessao4.yaml
```

> O `custom-resources.yaml` completo da release também pode criar `APIServer`, `Goldmane` e `Whisker`. Não são objetivos da Sessão 4; por isso não os ativamos aqui.

---

## 5.3. Observar convergência

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get nodes -o wide
```

### Output esperado após convergência

```text
NAME      AVAILABLE   PROGRESSING   DEGRADED
calico    True        False         False
ippools   True        False         False
```

E:

```text
k8s-cp-01   Ready   control-plane   ...   v1.35.8
```

Pode surgir:

```text
tiers   DEGRADED=True   Waiting for Tigera API server to be ready
```

Nesta instalação mínima, isto é esperado porque não criámos o recurso Tigera `APIServer`. O critério de saúde do CNI para este laboratório é a linha `calico` com `Available=True`, `Progressing=False` e `Degraded=False`.

---

## 5.4. Diagnóstico de `DiskPressure`

Se o Tigera Operator entrar num ciclo de Pods `Evicted`, não reinstalar imediatamente o Calico. Primeiro observar:

```bash
kubectl get nodes
kubectl describe node k8s-cp-01
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
df -h /
df -i /
```

### Sinais observados no ensaio que falhou

```text
The node had condition: [DiskPressure]
nodefs.available < 10%
imagefs.available < 15%
```

O problema validado não era falta de inodes nem falha do Calico: o LV raiz tinha apenas ~10 GB utilizáveis. Depois da expansão para 40 GB, `DiskPressure` passou a `False` e o Operator estabilizou.

---

# CP6 — Integrar o Worker

## 6.1. Gerar o comando de join — apenas no Control Plane

### O que estamos a fazer

Criamos um token temporário de bootstrap e pedimos ao kubeadm para gerar a linha de `join` com o hash da CA do cluster.

```bash
hostname

sudo kubeadm token create \
  --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

### Flags

| Flag | Função |
|---|---|
| `--print-join-command` | imprime um comando de join pronto a adaptar/executar |
| `--kubeconfig=...` | indica explicitamente o kubeconfig administrativo |

### Output esperado (estrutura)

```text
kubeadm join 192.168.50.46:6443 \
  --token TOKEN_REAL \
  --discovery-token-ca-cert-hash sha256:HASH_REAL
```

> O token real é um segredo temporário. Não o colocar em documentação, screenshots públicos ou commits.

---

## 6.2. Executar o join — apenas no Worker

No `k8s-wk-01`, usar **os valores reais** gerados no Control Plane e acrescentar o socket CRI:

```bash
sudo kubeadm join 192.168.50.46:6443 \
  --token TOKEN_REAL \
  --discovery-token-ca-cert-hash sha256:HASH_REAL \
  --cri-socket=unix:///run/containerd/containerd.sock
```

### O que significa cada argumento

| Elemento | Função |
|---|---|
| `192.168.50.46:6443` | endpoint do Kubernetes API Server |
| `--token` | credencial temporária de bootstrap |
| `--discovery-token-ca-cert-hash` | valida a identidade da CA do cluster durante discovery |
| `--cri-socket` | força o uso do containerd configurado |
| `sudo` | `kubeadm join` necessita de privilégios administrativos no nó |

### Output esperado

```text
This node has joined the cluster
```

### Erros frequentes

Executar sem `sudo`:

```text
[ERROR IsPrivilegedUser]: user is not running as root
```

Escrever placeholders como `<TOKEN>` literalmente pode ser interpretado pelo shell como redirecionamento. Substituir sempre pelos valores reais, sem `< >`.

---

## 6.3. Validar o Worker no sítio certo

No **Worker**:

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd
sudo ls -l /etc/kubernetes/kubelet.conf
```

### Output esperado

```text
active
active
-rw------- ... /etc/kubernetes/kubelet.conf
```

No **Control Plane**:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide \
  --field-selector spec.nodeName=k8s-wk-01
```

### Output esperado após convergência

```text
k8s-wk-01   Ready   <none>   ...   v1.35.8
```

E no Worker:

```text
calico-node-...       1/1   Running
csi-node-driver-...   2/2   Running
kube-proxy-...        1/1   Running
```

> Durante alguns segundos pode surgir `NotReady`, `Init:*` ou `ContainerCreating` enquanto o CNI converge. O importante é não avançar enquanto esses estados persistirem.

---

## 6.4. Revogar o token usado

No **Control Plane**:

```bash
sudo kubeadm token list
sudo kubeadm token delete ID_DO_TOKEN
```

`ID_DO_TOKEN` corresponde aos primeiros seis caracteres do token, apresentados por `kubeadm token list`.

### Porque fazemos isto

O token já cumpriu o seu objetivo. Reduzimos a janela de exposição e, quando precisarmos de adicionar outro nó, geramos um novo token.

---

## 6.5. Health gate do runtime

No Worker:

```bash
sudo journalctl -k --since "-10 min" --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

### O que fazem as partes do comando

| Elemento | Função |
|---|---|
| `journalctl -k` | consulta mensagens do kernel |
| `--since "-10 min"` | limita a janela temporal |
| `--no-pager` | escreve diretamente no terminal |
| `grep -E` | usa expressão regular estendida |
| `-i` | ignora maiúsculas/minúsculas |
| `|| true` | evita que ausência de correspondências seja tratada como falha do shell |

Output esperado: **nenhuma linha `DENIED` ou `permission denied`**.

---

# CP7 — Scheduling, `cordon`, `drain` e `uncordon`

Os comandos `kubectl` desta secção são executados no **Control Plane**.

## 7.1. Criar um Pod explicitamente no Worker

### O que estamos a fazer

Vamos criar um Pod simples, gerido diretamente e sem Deployment. Isto permite observar como `drain` protege Pods sem controller e como `--force` altera esse comportamento.

Usar o manifesto `../../manifests/pod_cordon_test.yaml`:

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
      ports:
        - containerPort: 80
  restartPolicy: Always
```

### O que significam as etiquetas e campos

| Campo | Função |
|---|---|
| `kind: Pod` | cria diretamente um Pod, sem controller superior |
| `metadata.name` | nome do objeto |
| `labels.app=cordon-test` | etiqueta usada mais tarde por `--pod-selector` |
| `nodeSelector` | obriga o scheduler a escolher o nó com o hostname indicado |
| `containers` | lista de containers que compõem o Pod |
| `image` | imagem OCI a executar |
| `imagePullPolicy: IfNotPresent` | só descarrega a imagem se não existir localmente |
| `containerPort: 80` | documenta a porta usada pelo container |
| `restartPolicy: Always` | kubelet tenta manter o container do Pod em execução enquanto o Pod existir |

Aplicar:

```bash
kubectl apply -f ../../manifests/pod_cordon_test.yaml

kubectl wait \
  --for=condition=Ready \
  pod/cordon-test \
  --timeout=120s

kubectl get pod cordon-test -o wide
```

### Flags

| Flag | Função |
|---|---|
| `apply -f` | cria ou atualiza o objeto descrito no ficheiro |
| `--for=condition=Ready` | espera até o Pod declarar condição Ready |
| `--timeout=120s` | limita a espera a 120 segundos |
| `-o wide` | mostra informação adicional, incluindo o Node |

### Output esperado

```text
NAME          READY   STATUS    ...   NODE
cordon-test   1/1     Running   ...   k8s-wk-01
```

A etiqueta `app=cordon-test` e o `nodeSelector` têm funções diferentes: **label** classifica o Pod; **nodeSelector** condiciona onde ele pode ser executado.

---

## 7.2. Fazer `cordon`

### O que estamos a fazer

`cordon` marca o nó como não disponível para novo scheduling normal, mas **não termina Pods já existentes**.

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

### Output esperado

```text
k8s-wk-01   Ready,SchedulingDisabled
```

`SchedulingDisabled` não significa `NotReady`: o nó continua saudável, apenas fechado a novos workloads normais.

---

## 7.3. Primeiro `drain` seletivo — sem `--force`

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

### Flags

| Flag | Função |
|---|---|
| `--ignore-daemonsets` | não tenta remover Pods geridos por DaemonSets |
| `--pod-selector=app=cordon-test` | limita a operação aos Pods com esta label |

### Output esperado

```text
error: unable to drain node ...
cannot delete Pods that declare no controller
(use --force to override): default/cordon-test
```

### Porque falhou de propósito?

O Pod foi criado diretamente. Se for eliminado, não existe Deployment/ReplicaSet para o recriar. `drain` protege este tipo de Pod por omissão.

---

## 7.4. Repetir conscientemente com `--force`

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force
```

### O que altera `--force`

Neste contexto permite remover um Pod que não tem controller. **Não é uma flag para adicionar automaticamente sempre que um drain falha.**

### Output esperado

```text
Warning: deleting Pods that declare no controller: default/cordon-test
evicting pod default/cordon-test
pod/cordon-test evicted
node/k8s-wk-01 drained
```

Confirmar:

```bash
kubectl get pod cordon-test
```

Esperado:

```text
Error from server (NotFound): pods "cordon-test" not found
```

---

## 7.5. Reabrir o Worker

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

### Output esperado

```text
k8s-cp-01   Ready
k8s-wk-01   Ready
```

Confirmar diretamente a propriedade:

```bash
kubectl get node k8s-wk-01 \
  -o custom-columns='NAME:.metadata.name,UNSCHEDULABLE:.spec.unschedulable'
```

Esperado:

```text
NAME        UNSCHEDULABLE
k8s-wk-01   <none>
```

---

# CP8 — Health gate e snapshot antes do upgrade

## 8.1. Porque existe um health gate?

Um upgrade não deve ser usado para tentar corrigir um cluster que já está degradado. Primeiro provamos que o estado de origem é saudável; só depois alteramos versões.

No Control Plane:

```bash
echo "===== NÓS ====="
kubectl get nodes -o wide

echo "===== PODS ====="
kubectl get pods -A -o wide

echo "===== CALICO ====="
kubectl get tigerastatus

echo "===== CLUSTER INFO ====="
kubectl cluster-info

echo "===== EVENTOS RECENTES ====="
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

### O que observar

```text
Nodes                 Ready
DiskPressure          False
Calico core           True / False / False
CoreDNS               Running
Evicted recorrentes   não
ContainerStatusUnknown recorrentes não
```

Filtrar estados problemáticos:

```bash
kubectl get pods -A --field-selector=status.phase=Failed

kubectl get pods -A \
  | grep -E 'Evicted|ContainerStatusUnknown|CrashLoopBackOff|Error' \
  || true
```

### Output esperado

```text
No resources found
```

---

## 8.2. Confirmar versões antes do upgrade

No Control Plane:

```bash
kubeadm version -o short

kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

No Worker:

```bash
kubeadm version -o short
kubelet --version
containerd --version
```

### Estado esperado

```text
Control Plane kubelet   v1.35.8
Worker kubelet          v1.35.8
containerd              2.2.6 nos dois nós
```

---

## 8.3. Criar snapshots coordenados

Só depois de o health gate estar verde, criar snapshots das **duas VMs** no mesmo estado lógico.

Nome sugerido:

```text
S04-CP8-K8s-1.35.8-Healthy-Before-Upgrade
```

> Num laboratório descartável, estes snapshots são um ponto de retorno. Em produção, snapshots de VMs não substituem uma estratégia adequada de backup/restore de etcd e dados persistentes.

---

# CP9 — Upgrade do Control Plane: 1.35.8 → 1.36.4

## 9.1. Mudar o repositório para Kubernetes 1.36

Executar no **Control Plane**.

```bash
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm | head -n 20
```

### Output esperado no laboratório validado

```text
kubeadm | 1.36.4-1.1 | .../v1.36/deb Packages
kubeadm | 1.36.3-1.1 | ...
...
```

Selecionar:

```bash
K8S_136_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"

printf 'Kubernetes 1.36 selecionado: %s\n' \
  "$K8S_136_PKG_VERSION"
```

Esperado:

```text
Kubernetes 1.36 selecionado: 1.36.4-1.1
```

---

## 9.2. Atualizar primeiro apenas `kubeadm`

### Porque esta ordem?

O `kubeadm` novo precisa de conhecer tanto a versão atual como a versão de destino para calcular e executar o plano de upgrade. O kubelet só é atualizado mais tarde.

```bash
sudo apt-mark unhold kubeadm

sudo apt-get -s install \
  kubeadm="$K8S_136_PKG_VERSION"
```

### Flag `-s`

`apt-get -s` significa **simulate**: mostra o que seria alterado sem instalar.

Output esperado:

```text
The following packages will be upgraded:
  kubeadm
1 upgraded ...
Inst kubeadm [1.35.8-1.1] (1.36.4-1.1 ...)
```

Se a simulação estiver correta:

```bash
sudo apt-get install -y \
  kubeadm="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubeadm
```

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
```

### Estado intermédio esperado

```text
kubeadm   v1.36.4
kubelet   v1.35.8
kubectl   v1.35.8
```

Este desfasamento é temporário e intencional.

---

## 9.3. Calcular o plano de upgrade

```bash
sudo kubeadm upgrade plan
```

### O que faz

O comando executa preflight checks, verifica a saúde do cluster, lê a configuração do kubeadm e calcula as versões alvo. **Não aplica ainda o upgrade.**

### Output esperado — elementos importantes

```text
Cluster version: 1.35.8
kubeadm version: v1.36.4
Target version: v1.36.4
```

No laboratório validado, o plano indicou:

```text
kube-apiserver            v1.35.8 → v1.36.4
kube-controller-manager   v1.35.8 → v1.36.4
kube-scheduler            v1.35.8 → v1.36.4
kube-proxy                1.35.8  → v1.36.4
CoreDNS                   v1.13.1 → v1.14.2
etcd                      3.6.6-0 → 3.6.8-0
```

E os kubelets aparecem como componentes a atualizar manualmente depois.

Se surgir:

```text
remote version is much newer: v1.37.0; falling back to: stable-1.36
```

isto não é erro. O kubeadm está a limitar corretamente o upgrade à série 1.36.

---

## 9.4. Aplicar o upgrade do Control Plane

```bash
sudo kubeadm upgrade apply v1.36.4
```

### O que acontece internamente

O kubeadm:

```text
faz preflight checks
      ↓
renova/atualiza manifests estáticos
      ↓
atualiza etcd
      ↓
atualiza kube-apiserver
      ↓
atualiza controller-manager
      ↓
atualiza scheduler
      ↓
atualiza kubeconfigs/configuração
      ↓
atualiza CoreDNS e kube-proxy
```

### Output esperado no final

```text
[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.4".
```

Durante o restart do etcd/API Server podem surgir timeouts transitórios. O critério é o comando terminar com sucesso e os componentes convergirem novamente.

Validar:

```bash
kubectl version
kubectl get pods -n kube-system \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase'
```

### Output esperado

```text
Server Version: v1.36.4
...
coredns-...                   registry.k8s.io/coredns/coredns:v1.14.2          Running
etcd-k8s-cp-01                registry.k8s.io/etcd:3.6.8-0                     Running
kube-apiserver-k8s-cp-01      registry.k8s.io/kube-apiserver:v1.36.4           Running
kube-controller-manager-...   registry.k8s.io/kube-controller-manager:v1.36.4 Running
kube-proxy-...                 registry.k8s.io/kube-proxy:v1.36.4               Running
kube-scheduler-k8s-cp-01      registry.k8s.io/kube-scheduler:v1.36.4           Running
```

`kubectl get nodes` pode continuar a mostrar `v1.35.8` no Control Plane nesta fase porque a coluna `VERSION` corresponde à versão do **kubelet do Node**, ainda não atualizada.

---

## 9.5. Drain do Control Plane

Antes de atualizar o kubelet:

```bash
kubectl drain k8s-cp-01 \
  --ignore-daemonsets
```

### Porque drenamos o nó?

Reduzimos workloads normais durante a manutenção do kubelet. Pods estáticos do Control Plane não são geridos pelo scheduler e permanecem. Pods DaemonSet também são ignorados devido à flag.

### Output esperado

```text
node/k8s-cp-01 cordoned
Warning: ignoring DaemonSet-managed Pods: ...
evicting pod ...
node/k8s-cp-01 drained
```

Confirmar:

```bash
kubectl get nodes
```

Esperado:

```text
k8s-cp-01   Ready,SchedulingDisabled
k8s-wk-01   Ready
```

---

## 9.6. Atualizar kubelet e kubectl do Control Plane

```bash
sudo apt-mark unhold kubelet kubectl

sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"
```

A simulação deve listar **apenas** `kubelet` e `kubectl`.

Instalar:

```bash
sudo apt-get install -y \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Porque `daemon-reload`?

Pede ao systemd para reler unidades/configurações instaladas antes do restart do serviço.

Validar:

```bash
sudo systemctl is-active kubelet
kubelet --version
kubectl version --client
kubectl get nodes
```

### Output esperado

```text
active
Kubernetes v1.36.4
Client Version: v1.36.4
...
k8s-cp-01   Ready,SchedulingDisabled   ...   v1.36.4
k8s-wk-01   Ready                      ...   v1.35.8
```

Um `NotReady` durante alguns segundos imediatamente após o restart pode ser transitório. **Não fazer uncordon até voltar a `Ready`.**

Confirmar o Scheduler:

```bash
kubectl wait \
  --namespace=kube-system \
  --for=condition=Ready \
  pod/kube-scheduler-k8s-cp-01 \
  --timeout=120s
```

Depois reabrir:

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes
```

### Estado esperado

```text
k8s-cp-01   Ready   control-plane   ...   v1.36.4
k8s-wk-01   Ready   <none>          ...   v1.35.8
```

Este version skew temporário é esperado durante o upgrade sequencial.

---

# CP10 — Upgrade do Worker para 1.36.4

## 10.1. Atualizar `kubeadm` no Worker

Executar no **Worker**:

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'

sudo apt-mark unhold kubeadm

sudo apt-get -s install \
  kubeadm="$K8S_136_PKG_VERSION"
```

### Output esperado

```text
The following packages will be upgraded:
  kubeadm
Inst kubeadm [1.35.8-1.1] (1.36.4-1.1 ...)
```

Instalar:

```bash
sudo apt-get install -y \
  kubeadm="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubeadm
```

Validar:

```bash
kubeadm version -o short
kubelet --version
```

Esperado:

```text
v1.36.4
Kubernetes v1.35.8
```

---

## 10.2. Atualizar a configuração local do Worker

```bash
sudo kubeadm upgrade node
```

### O que faz

Num Worker, este comando **não atualiza o Control Plane**. Atualiza a configuração local do kubelet para o estado esperado pela nova minor.

### Output esperado — elementos relevantes

```text
Skipping prepull. Not a control plane node.
Skipping phase. Not a control plane node.
...
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
```

Pode surgir um warning sobre `KubeProxyConfiguration bindAddress`; no laboratório validado não bloqueou a operação.

O binário do kubelet continua em `v1.35.8` até à etapa de package upgrade.

---

## 10.3. Fixar temporariamente o Tigera Operator no Control Plane

### Porque fazemos isto?

No nosso cluster de dois nós, o Tigera Operator estava no Worker antes do drain. O Deployment possui tolerations que podem permitir scheduling em situações que tornam o drain menos previsível. Durante esta manutenção fixamo-lo temporariamente no Control Plane.

Executar no **Control Plane**:

```bash
kubectl get deployment tigera-operator \
  -n tigera-operator \
  -o wide
```

Aplicar patch:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='merge' \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "nodeSelector": {
            "kubernetes.io/hostname": "k8s-cp-01"
          }
        }
      }
    }
  }'
```

### O que significam as flags e o patch

| Elemento | Função |
|---|---|
| `kubectl patch deployment` | altera apenas parte de um objeto existente |
| `-n tigera-operator` | seleciona o namespace |
| `--type=merge` | aplica um JSON merge patch |
| `-p` | fornece o patch diretamente na linha de comandos |
| `nodeSelector` | obriga os novos Pods deste Deployment a usar `k8s-cp-01` |

Aguardar rollout:

```bash
kubectl rollout status deployment/tigera-operator \
  -n tigera-operator \
  --timeout=120s

kubectl get pod -n tigera-operator -o wide
```

### Output esperado

```text
deployment "tigera-operator" successfully rolled out
...
tigera-operator-...   1/1   Running   0   ...   k8s-cp-01
```

---

## 10.4. Drain integral do Worker

Executar no **Control Plane**:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets
```

Ao contrário do CP7, este drain é **integral** porque está associado à manutenção real do kubelet.

Não acrescentar `--force` ou `--delete-emptydir-data` automaticamente se surgir erro. Primeiro interpretar a mensagem.

### Output esperado

```text
node/k8s-wk-01 cordoned
Warning: ignoring DaemonSet-managed Pods: calico-node..., csi-node-driver..., kube-proxy...
evicting pod ...
node/k8s-wk-01 drained
```

Confirmar:

```bash
kubectl get nodes

kubectl get pods -A -o wide \
  --field-selector spec.nodeName=k8s-wk-01
```

Esperado:

```text
k8s-wk-01   Ready,SchedulingDisabled
```

E apenas DaemonSets essenciais permanecem no Worker:

```text
calico-node-...       Running
csi-node-driver-...   Running
kube-proxy-...        Running
```

---

## 10.5. Atualizar kubelet e kubectl do Worker

Executar no **Worker**:

```bash
sudo apt-mark unhold kubelet kubectl

sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"
```

A simulação deve listar apenas `kubelet` e `kubectl`.

Instalar:

```bash
sudo apt-get install -y \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Validar **localmente**:

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd

kubeadm version -o short
kubelet --version
kubectl version --client

apt-mark showhold \
  | grep -E '^(containerd.io|kubeadm|kubelet|kubectl)$'
```

### Output esperado

```text
active
active
v1.36.4
Kubernetes v1.36.4
Client Version: v1.36.4
containerd.io
kubeadm
kubectl
kubelet
```

No Control Plane, confirmar:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

### Output esperado

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

---

## 10.6. Health gate do runtime e `uncordon`

No Worker:

```bash
sudo journalctl -k --since "-10 min" --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Output esperado: sem `DENIED` e sem `permission denied`.

No Control Plane:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

### Output esperado

```text
k8s-cp-01   Ready   control-plane   ...   v1.36.4
k8s-wk-01   Ready   <none>          ...   v1.36.4
```

---

## 10.7. Remover o `nodeSelector` temporário do Tigera Operator

No Control Plane:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='json' \
  -p='[
    {
      "op": "remove",
      "path": "/spec/template/spec/nodeSelector"
    }
  ]'
```

### O que significa

Aqui usamos **JSON Patch**, não merge patch:

| Campo | Função |
|---|---|
| `op: remove` | remove o elemento indicado |
| `path` | caminho JSON dentro do objeto Kubernetes |
| `/spec/template/spec/nodeSelector` | remove o `nodeSelector` temporário que adicionámos |

Aguardar:

```bash
kubectl rollout status deployment/tigera-operator \
  -n tigera-operator \
  --timeout=120s

kubectl get pod -n tigera-operator -o wide
```

O Operator pode ficar no CP ou no Worker. O importante é estar `1/1 Running` e sem churn.

---

# CP11 — Validação final do cluster

## 11.1. Confirmar nós, Pods e CNI

No Control Plane:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'

kubectl get pods -A -o wide
kubectl get tigerastatus

kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded

kubectl version
```

### Output esperado final

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

Todos os Pods essenciais devem estar `Running`, e o filtro de fases deve devolver:

```text
No resources found
```

Versões:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

Calico:

```text
calico    True    False    False    ...    All objects available
ippools   True    False    False    ...    All objects available
```

---

## 11.2. Interpretar mensagens transitórias do kubelet

Durante o restart do kubelet do Worker, no laboratório validado apareceram mensagens como:

```text
Failed to read data from checkpoint
checkpoint="kubelet_internal_checkpoint"
```

E:

```text
eviction manager: failed to check if we have separate container filesystem. Ignoring.
err="no imagefs label for configured runtime"
```

Estas mensagens apareceram no arranque e **não se repetiram como falha persistente**. O nó permaneceu `Ready`, `DiskPressure=False` e com workloads funcionais.

Filtrar novamente depois de alguns minutos:

```bash
sudo journalctl -u kubelet --since "-5 min" --no-pager \
  | grep -Ei \
    'Failed to watch|ContainerStatus from runtime service failed|permission denied|unable to signal init|apparmor.*DENIED|checkpoint is not found|no imagefs label' \
  || true
```

A interpretação deve basear-se em recorrência e impacto operacional, não apenas na existência isolada da palavra `error`.

---

## 11.3. Validar que o incidente AppArmor/runc não reapareceu

No nó que queremos verificar:

```bash
sudo journalctl -k --since "-15 min" --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

### Resultado validado nesta edição

```text
nenhum apparmor="DENIED"
nenhum unable to signal init
nenhum permission denied relacionado com runc
```

A conclusão correta é:

> O problema anterior de AppArmor/runc **não se reproduziu** na instalação limpa validada com containerd 2.2.6 e runc 1.3.6.

Não concluir que AppArmor era definitivamente a causa de todos os problemas anteriores, nem que uma versão específica corrige universalmente o incidente.

---

# 12. Evidências a entregar

Registar em `../../folha_evidencias.md` ou no formato indicado pelo formador.

| Checkpoint | Evidência mínima |
|---|---|
| CP1 | hostname, IP, `df -h /`, cgroup v2, swap |
| CP2 | containerd/runc, CRI `ok`, `SystemdCgroup=true` |
| CP3 | kubeadm/kubelet/kubectl 1.35.8 e holds |
| CP4 | `kubeadm init` concluído e CP acessível por kubectl |
| CP5 | Calico core saudável e Pod CIDR 10.244.0.0/16 |
| CP6 | dois Nodes `Ready`, componentes Calico no Worker |
| CP7 | `SchedulingDisabled`, recusa sem `--force`, eviction controlada e `uncordon` |
| CP8 | health gate saudável e snapshot coordenado |
| CP9 | Control Plane 1.36.4 e Worker temporariamente 1.35.8 |
| CP10 | ambos os kubelets 1.36.4, runtime 2.2.6, sem DiskPressure |
| CP11 | Client/Server 1.36.4, Pods saudáveis, sem erros persistentes de runtime |

---

# 13. Se algo correr mal

O método de troubleshooting é sempre:

```text
PARAR
  ↓
OBSERVAR O ESTADO ATUAL
  ↓
RECOLHER EVIDÊNCIA
  ↓
IDENTIFICAR O NÓ / COMPONENTE
  ↓
INTERPRETAR A CAUSA
  ↓
CORRIGIR OU RESTAURAR
  ↓
VALIDAR NOVAMENTE
```

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
kubectl get tigerastatus
```

No nó afetado:

```bash
sudo systemctl status kubelet --no-pager
sudo systemctl status containerd --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
sudo journalctl -k --since "-30 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|audit.*DENIED|runc|containerd' \
  || true
sudo ls -la /etc/kubernetes/tmp/ 2>/dev/null || true
```

### Regra operacional

```text
não ignorar preflights automaticamente
não adicionar --force por tentativa
não desativar AppArmor globalmente
não fazer downgrade APT improvisado
não avançar para o próximo nó se o atual estiver degradado
```

Num laboratório descartável, se o upgrade deixar o cluster num estado inconsistente e a causa não puder ser corrigida com segurança, restaurar os snapshots coordenados criados no CP8.

Consulta também:

- [`../../troubleshooting.md`](../../troubleshooting.md)
- [`../../compatibilidade.md`](../../compatibilidade.md)
- [`../../checklist_operacional.md`](../../checklist_operacional.md)
- [`../../folha_evidencias.md`](../../folha_evidencias.md)

---

# 14. Síntese do que foi aprendido

No final deste laboratório, o formando deve conseguir explicar, e não apenas repetir, a seguinte sequência:

```text
Linux preparado
   ↓
containerd / CRI / runc
   ↓
kubeadm + kubelet + kubectl
   ↓
Control Plane
   ↓
CNI / Calico
   ↓
Worker join
   ↓
Scheduling e manutenção
   ↓
Health gate
   ↓
Upgrade sequencial
   ↓
Validação final
```

E deve conseguir distinguir claramente:

```text
cordon   → impede novo scheduling normal

drain    → prepara o nó para manutenção, evacuando Pods aplicáveis

uncordon → volta a disponibilizar o nó ao scheduler

kubeadm upgrade apply → atualiza o Control Plane

kubeadm upgrade node  → atualiza a configuração do nó Worker

kubelet version       → é a VERSION apresentada para cada Node

containerd            → runtime CRI usado pelo kubelet
```

O laboratório só está concluído quando o formando consegue **executar, observar e explicar** cada uma destas transições.