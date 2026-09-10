# Cheat-Sheet Manual — Sessão 4: Kubernetes Admin I

**Ambiente:** `k8s-cp-01` + `k8s-wk-01` · Kubernetes 1.37 · Ubuntu 26.04 LTS · containerd · Calico via Tigera Operator

> Este documento resume os comandos manuais. Não substitui a explicação do laboratório.

## Pré-requisitos — ambos os nós

```bash
hostname
ip -br address
free -h
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
getent hosts k8s-cp-01
getent hosts k8s-wk-01
```

Confirmar ausência de Kubernetes residual:

```bash
snap list microk8s 2>/dev/null
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

## containerd — ambos os nós

```bash
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Inspecionar manualmente:

```bash
sudo nano /etc/containerd/config.toml
```

Confirmar duas condições:

```text
1. "cri" não está em disabled_plugins
2. Dentro da secção runc.options do runtime CRI:
   SystemdCgroup = true
```

Na configuração gerada por containerd 2.x, localizar a secção com:

```bash
sudo grep -n -A12 -B2 \
"io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options" \
/etc/containerd/config.toml
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd

systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

## kubelet / kubeadm / kubectl — ambos os nós

```bash
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

## Bootstrap — APENAS `k8s-cp-01`

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Nunca executar `kubeadm init` no Worker.

Configurar `kubectl` no Control Plane:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, `NotReady` pode ser esperado.

## CNI — Calico via Tigera Operator — Control Plane

Usar a versão Calico previamente validada pelo formador para a edição da formação.

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

Enquanto ainda não houver Worker, alguns Deployments podem ficar `Pending` devido à taint `control-plane:NoSchedule`. Não remover a taint neste laboratório.

## Adicionar o Worker

No Control Plane:

```bash
sudo kubeadm token create --print-join-command
```

Copiar o comando real gerado.

No Worker:

```bash
sudo kubeadm join <ENDPOINT_REAL> --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

Não executar os placeholders literalmente.

## Validar após o join — no Control Plane

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Aguardar a convergência até os dois Nodes estarem `Ready` e CoreDNS/Calico operacionais.

## kubeconfig e contextos — Control Plane

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

## Manutenção

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide

kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
# interpretar a recusa

kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl uncordon k8s-wk-01

kubectl get nodes
kubectl get pod cordon-test
```

## Upgrade — planeamento

```bash
sudo kubeadm upgrade plan
```

## Diagnóstico

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl describe node <node>
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus

systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
```

**Regra geral:** observar primeiro, formular uma hipótese, validar e só depois corrigir.
