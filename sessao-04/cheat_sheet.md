# Cheat-Sheet — Sessão 4: Kubernetes Admin I

**Ambiente:** `k8s-cp-01` + `k8s-wk-01` · Kubernetes 1.37 · Ubuntu 26.04 LTS · `containerd` · Calico via Tigera Operator

## Pré-requisitos

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
getent hosts k8s-cp-01 k8s-wk-01
```

Esperado:

```text
swap desativado
overlay carregado
br_netfilter carregado
ip_forward = 1
bridge-nf-call-iptables = 1
cgroup2fs
nomes resolvidos
```

## containerd

```bash
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl is-active containerd
sudo ss -lx | grep containerd
```

## Kubernetes 1.37

```bash
kubeadm version
kubelet --version
kubectl version --client
```

## Bootstrap do Control Plane

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, no laboratório é esperado observar o Control Plane `NotReady`.

## Calico via Tigera Operator

A versão Calico deve ser confirmada antes da formação.

Descarregar para inspeção:

```bash
CALICO_VERSION=vX.Y.Z ./scripts/fetch_calico_operator.sh
```

Depois de validar a release e o Pod CIDR, aplicar os recursos descarregados de acordo com o Manual/Laboratório:

```bash
kubectl create -f calico-vX.Y.Z/v1_crd_projectcalico_org.yaml
kubectl create -f calico-vX.Y.Z/tigera-operator.yaml
```

Inspecionar e ajustar `custom-resources.yaml` para o Pod CIDR `192.168.0.0/16` antes de aplicar:

```bash
grep -n 'cidr:' calico-vX.Y.Z/custom-resources.yaml
kubectl create -f calico-vX.Y.Z/custom-resources.yaml
```

Validar:

```bash
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
kubectl get tigerastatus
kubectl get pods -n kube-system
kubectl get nodes
```

## Worker join

No Control Plane:

```bash
kubeadm token create --print-join-command
```

No Worker, executar com `sudo` o comando gerado.

Depois:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
```

## kubeconfig e contextos

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <contexto>
```

## Cordon / Drain / Uncordon

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide

kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl uncordon k8s-wk-01
```

`--force` é utilizado neste exercício para demonstrar conscientemente o comportamento de um Pod sem controlador. Não é uma flag a acrescentar por rotina.

## Upgrade — planeamento

```bash
sudo kubeadm upgrade plan
```

Não executar um upgrade completo durante o percurso principal da Sessão 4.

## Diagnóstico

```bash
kubectl get nodes
kubectl get pods -A
kubectl describe node <node>
kubectl get events -A
kubectl get tigerastatus

systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
```

## Regra geral

```text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Validação
  ↓
Correção
```
