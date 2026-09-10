# Cheat-Sheet — Sessão 4

## Versões

```text
Kubernetes inicial: 1.36.x
Kubernetes final:   1.37.x
Baseline:           1.36.4 → 1.37.0
```

## Refresh kubectl

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n kube-system -o wide
kubectl describe node <NODE>
kubectl get events -A --sort-by=.lastTimestamp
```

```text
-n <ns>    namespace
-A         todos os namespaces
-o wide    mais detalhe
-o yaml    YAML
-w         watch
--help     ajuda
```

## Pré-requisitos

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
stat -fc %T /sys/fs/cgroup
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

## containerd

```bash
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

## Instalação inicial — repositório 1.36

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

## Bootstrap

**Control Plane:**

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

**Gerar join:**

```bash
sudo kubeadm token create --print-join-command
```

**Worker:** executar o comando real devolvido pelo CP. Nunca executar `<TOKEN>`, `<HASH>` ou `...` literalmente.

## Calico / CoreDNS

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get pods -n kube-system -o wide
```

## Manutenção

```bash
kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
kubectl uncordon k8s-wk-01
```

## Upgrade para 1.37

Repositório:

```text
https://pkgs.k8s.io/core:/stable:/v1.37/deb/
```

### Control Plane

```text
kubeadm 1.37
→ kubeadm upgrade plan
→ kubeadm upgrade apply v1.37.x
→ drain k8s-cp-01
→ kubelet + kubectl 1.37
→ restart kubelet
→ uncordon
```

### Worker

```text
kubeadm 1.37
→ kubeadm upgrade node
→ drain k8s-wk-01
→ kubelet + kubectl 1.37
→ restart kubelet
→ uncordon
```

## Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Esperado: ambos os Nodes `Ready` em `v1.37.x`.
