# Cheat-Sheet — Sessão 4

## Baseline

```text
Kubernetes inicial: 1.35.8
Kubernetes final:   1.36.4
containerd:         2.2.x
Calico:             3.32.2
Tigera Operator:    1.42.6
```

## Regra de nó

```text
kubeadm init          → k8s-cp-01
kubeadm token create  → k8s-cp-01
kubeadm join          → k8s-wk-01
```

Confirma sempre:

```bash
hostname
```

## Diagnosticar versão/repositório

```bash
grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true

dpkg-query -W -f='${Package} ${Version}\n' \
  kubeadm kubelet kubectl 2>/dev/null || true

apt-cache madison kubeadm
```

## Instalação inicial Kubernetes 1.35

```text
https://pkgs.k8s.io/core:/stable:/v1.35/deb/
```

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

test -n "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
```

## Bootstrap

```bash
K8S_PKG_VERSION="$(dpkg-query -W -f='${Version}' kubeadm)"
K8S_SEMVER="v${K8S_PKG_VERSION%%-*}"

sudo kubeadm init \
  --kubernetes-version="$K8S_SEMVER" \
  --pod-network-cidr=192.168.0.0/16
```

## Kubeconfig — Control Plane

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

## Calico

```bash
export CALICO_VERSION=v3.32.2
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

## Join — gerar no Control Plane

```bash
hostname
# k8s-cp-01

set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig /etc/kubernetes/admin.conf
```

No Worker executa apenas o `kubeadm join ...` real devolvido.

## Estado

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
```

## Manutenção

```bash
kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
kubectl uncordon k8s-wk-01
```

## Antes do upgrade

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
```

Snapshot das duas VMs: `pre-upgrade-1.35`.

## Upgrade para Kubernetes 1.36

```text
repo v1.36
→ kubeadm 1.36
→ kubeadm upgrade plan
→ kubeadm upgrade apply no CP
→ drain CP
→ kubelet/kubectl 1.36
→ uncordon CP
→ kubeadm upgrade node no Worker
→ drain Worker
→ kubelet/kubectl 1.36
→ uncordon Worker
→ validar
```

Repo de destino:

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```
