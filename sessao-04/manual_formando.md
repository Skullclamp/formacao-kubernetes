# Manual do Formando — Sessão 4
## Kubernetes Admin I — Instalação e Administração do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Ambiente:** Ubuntu 26.04 LTS · Kubernetes 1.37 · containerd · Calico/Tigera Operator

---

# 1. Objetivo da sessão

Nesta sessão vais construir manualmente um cluster Kubernetes on-premises com dois nós:

```text
k8s-cp-01                 k8s-wk-01
Control Plane              Worker
     │                         │
     └────── Kubernetes ───────┘
```

O objetivo não é decorar uma sequência de comandos. Em cada etapa deves compreender:

```text
pré-condição → comando → alteração produzida → evidência → interpretação
```

No final, deverás conseguir instalar e validar o runtime, inicializar o Control Plane, configurar o CNI, integrar o Worker e executar operações básicas de manutenção.

---

# 2. Ambiente de referência

| Elemento | Valor |
|---|---|
| Control Plane | `k8s-cp-01` |
| Worker | `k8s-wk-01` |
| Sistema operativo | Ubuntu 26.04 LTS |
| Kubernetes | 1.37 |
| Runtime | `containerd` |
| CNI | Calico via Tigera Operator |
| Pod CIDR | `192.168.0.0/16` |
| Service CIDR | `10.96.0.0/12` |

Cada formando utiliza duas VMs. Em ambos os nós são instalados `containerd`, `kubelet` e `kubeadm`. Nesta formação instala-se também `kubectl` nos dois nós por uniformização, embora o Worker não necessite de um `kubectl` administrativo para desempenhar a função de Node.

---

# 3. Arquitetura mínima

## Control Plane

O Control Plane toma decisões e mantém o estado do cluster. Os principais componentes são:

- `kube-apiserver` — ponto de entrada da API Kubernetes;
- `etcd` — armazena o estado do cluster;
- `kube-scheduler` — escolhe Nodes para novos Pods;
- `kube-controller-manager` — executa controllers que reconciliam o estado desejado.

## Worker

O Worker executa workloads. Nesta sessão interessa sobretudo:

- `kubelet` — agente do Node;
- `kube-proxy` — componente de rede instalado pelo kubeadm;
- `containerd` — runtime de containers.

A relação com o runtime pode ser vista assim:

```text
kubelet
   ↓
CRI
   ↓
containerd
   ↓
runc
   ↓
Kernel Linux
```

O CRI é uma **interface**, não é o runtime.

---

# 4. Preparação do Linux

Antes de qualquer `kubeadm init` ou `join`, os dois nós devem ser preparados.

## 4.1 Identidade e resolução

Confirma:

```bash
hostnamectl
ip -br address
```

Nomes esperados:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
```

Garante resolução entre os dois nós através de DNS ou `/etc/hosts`:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

## 4.2 Confirmar que a VM está limpa

Uma VM de laboratório não deve chegar com MicroK8s, k3s, Minikube ou um cluster kubeadm anterior ainda ativo.

```bash
snap list microk8s 2>/dev/null
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Se antes do bootstrap surgirem processos como `kubelite`, `kube-apiserver`, `etcd`, `kube-scheduler` ou `kube-controller-manager`, investiga primeiro a origem. Não uses `--ignore-preflight-errors` apenas para esconder o problema.

## 4.3 Swap, módulos e sysctl

Neste laboratório trabalhamos com swap desativada:

```bash
swapon --show
sudo swapoff -a
```

Carregar módulos:

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

Configurar rede:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

No ambiente de referência esperamos cgroup v2 (`cgroup2fs`).

---

# 5. containerd e CRI

Instalar em ambos os nós:

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

## 5.1 CRI ativo

Verifica:

```bash
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
```

`cri` não deve estar em `disabled_plugins`.

## 5.2 SystemdCgroup

Com containerd 2.x, não assumas que existe uma linha `SystemdCgroup = false` pronta a substituir. Localiza primeiro a secção do runtime CRI:

```bash
sudo grep -n -A12 -B2 \
"io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options" \
/etc/containerd/config.toml
```

Edita manualmente:

```bash
sudo nano /etc/containerd/config.toml
```

Na secção `runc.options`, garante:

```text
SystemdCgroup = true
```

Reinicia e valida a configuração efetiva:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

O socket esperado é:

```text
/run/containerd/containerd.sock
```

---

# 6. kubelet, kubeadm e kubectl

Executar nos dois nós.

Adicionar o repositório Kubernetes 1.37:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Instalar:

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Confirmar versões:

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

Antes de `kubeadm init` ou `join`, o `kubelet` pode ainda não estar plenamente operacional como Node. Isso não é `CrashLoopBackOff`: estamos a observar um serviço systemd do host.

---

# 7. Bootstrap do Control Plane

Esta secção executa-se **apenas em `k8s-cp-01`**.

Antes do bootstrap:

```bash
hostname
free -h
systemctl is-active containerd
swapon --show
sudo ss -ltnp | grep -E ':(6443|2379|2380|10257|10259)\b'
```

Inicializar:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

O `kubeadm` executa preflight checks, cria certificados, configura o kubelet e cria os static Pods do Control Plane.

No final, guarda o comando de `join`, mas **não publiques tokens reais**.

## 7.1 Configurar kubeconfig

Como utilizador normal no Control Plane:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

Nesta fase é normal observar o Control Plane como `NotReady`, porque ainda não existe uma rede CNI funcional.

---

# 8. CNI — Calico com Tigera Operator

Kubernetes define o modelo de rede, mas depende de uma implementação CNI para ligar Pods.

Nesta sessão utilizamos Calico através do Tigera Operator. A edição de referência foi ensaiada com Calico `v3.32.2`; antes de uma nova edição da formação, a versão deve ser novamente validada face à versão Kubernetes utilizada.

No Control Plane:

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Validar o Operator:

```bash
kubectl get pods -n tigera-operator
```

Obter e inspecionar a configuração:

```bash
curl -LO \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

grep -n 'cidr:' custom-resources.yaml
```

O IP pool deve ser coerente com o Pod CIDR `192.168.0.0/16`. Corrige o ficheiro antes de aplicar se necessário.

```bash
kubectl create -f custom-resources.yaml
```

Acompanhar:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get nodes
```

## 8.1 Porque podem existir Pods Pending?

O Control Plane criado pelo kubeadm tem a taint:

```text
node-role.kubernetes.io/control-plane:NoSchedule
```

Enquanto ainda não existir Worker, alguns Deployments do Calico/Tigera e o CoreDNS podem permanecer `Pending` por falta de um Node schedulable.

Confirma através dos Events:

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-cp-01 | grep -i Taints
```

Neste laboratório **não removemos a taint do Control Plane**. Integramos o Worker e aguardamos a reconciliação normal.

---

# 9. Adicionar o Worker

No Control Plane, gera um comando atual:

```bash
sudo kubeadm token create --print-join-command
```

No **`k8s-wk-01`**, executa o comando real devolvido:

```bash
sudo kubeadm join <ENDPOINT_REAL> --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

Os elementos entre `< >` são placeholders de documentação. Não executes literalmente `<TOKEN_REAL>`, `VALOR_REAL`, `HASH_REAL` ou `...`.

> **Regra crítica:** no Worker executa-se `kubeadm join`, nunca `kubeadm init`. Um `init` no Worker cria outro Control Plane independente em vez de integrar o nó no cluster existente.

No Control Plane, acompanha:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Logo após o `join`, o Worker pode ficar temporariamente `NotReady` e os componentes podem demorar alguns minutos a convergir.

Resultado final esperado:

```text
k8s-cp-01   Ready   control-plane
k8s-wk-01   Ready   <none>
```

CoreDNS e Calico devem ficar operacionais.

---

# 10. kubeconfig e contextos

O `kubeconfig` indica ao `kubectl`:

```text
cluster + identidade + contexto + namespace opcional
```

Comandos:

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

`/etc/kubernetes/admin.conf` e a cópia em `$HOME/.kube/config` dão privilégios administrativos elevados. Não devem ser publicados nem distribuídos como credenciais normais.

No Worker, `kubectl` pode estar instalado, mas sem kubeconfig administrativo não deve ser usado para validar o cluster. A administração desta sessão é feita a partir do Control Plane.

---

# 11. Manutenção do Worker

## 11.1 Pod direto

Aplicar o manifest preparado:

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

O `nodeSelector` fixa o Pod em `k8s-wk-01`. Não existe Deployment nem ReplicaSet a geri-lo.

## 11.2 Cordon

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

`cordon` impede novo scheduling; não remove os Pods atuais.

## 11.3 Drain

Primeiro sem `--force`:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

A recusa perante o Pod direto é intencional: não existe um controller capaz de o recriar.

Depois de interpretar a mensagem:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
```

O Pod é removido e não reaparece porque ninguém reconcilia esse estado desejado.

## 11.4 Uncordon

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

O Worker deve voltar a `Ready` e schedulable.

---

# 12. Upgrade — compreender antes de executar

Nesta sessão o objetivo é interpretar:

```bash
sudo kubeadm upgrade plan
```

Um upgrade Kubernetes não é simplesmente `apt upgrade`. Deve ser planeado, respeitar a ordem de componentes/nós e ser validado após cada intervenção. O exercício completo encontra-se em [`exercicios/upgrade_complementar.md`](exercicios/upgrade_complementar.md).

---

# 13. Troubleshooting orientado por evidências

Usa sempre:

```text
Sintoma → Evidência → Hipótese → Validação → Correção → Nova validação
```

Comandos úteis:

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Cenários importantes desta sessão:

- memória insuficiente bloqueia o preflight;
- portas ocupadas podem indicar Kubernetes residual;
- `kubelite` aponta para MicroK8s;
- `NotReady` antes do CNI pode ser esperado;
- Pods `Pending` antes do Worker podem resultar da taint `NoSchedule`;
- token inválido deve ser resolvido gerando novo `join command` no Control Plane;
- `kubectl` sem kubeconfig pode tentar um endpoint local e falhar;
- `drain` não deve ser forçado sem interpretar a causa.

Consulta também [`troubleshooting.md`](troubleshooting.md).

---

# 14. Resumo

No final da sessão deves conseguir explicar esta sequência:

```text
Linux preparado
      ↓
containerd / CRI operacional
      ↓
kubelet + kubeadm + kubectl
      ↓
kubeadm init no Control Plane
      ↓
kubeconfig
      ↓
CNI / Calico
      ↓
kubeadm join no Worker
      ↓
2 Nodes Ready
      ↓
CoreDNS + Calico operacionais
      ↓
cordon / drain / uncordon
```

## Questões de consolidação

1. Qual a diferença entre runtime e CRI?
2. Porque usamos `SystemdCgroup = true`?
3. Porque o Control Plane pode ficar `NotReady` antes do CNI?
4. Porque alguns Pods podem ficar `Pending` antes de existir Worker?
5. Porque `kubeadm init` e `kubeadm join` não são intercambiáveis?
6. O que contém um contexto kubeconfig?
7. Qual a diferença entre `cordon` e `drain`?
8. Porque o Pod direto não reaparece depois do `drain --force`?
9. Porque não devemos ignorar automaticamente preflight errors?
10. Para que serve `kubeadm upgrade plan`?

Na Sessão 5, o cluster deixa de ser o objeto principal de construção e passa a ser a plataforma onde vais executar, expor e persistir workloads.
