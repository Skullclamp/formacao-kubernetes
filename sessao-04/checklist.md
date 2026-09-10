# Checklist do Formando — Preparação Manual das VMs

**Objetivo:** chegar ao `kubeadm init` com os dois nós corretamente preparados e Kubernetes **1.36.x** instalado.

## 1. Identidade e recursos

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| Hostname correto | ☐ | ☐ |
| IP registado | ☐ | ☐ |
| >= 2 vCPU | ☐ | ☐ |
| >= 2 GiB RAM | ☐ | ☐ |
| Resolução entre os nós | ☐ | ☐ |
| Relógio sincronizado | ☐ | ☐ |

## 2. Sem Kubernetes residual

```bash
snap list microk8s 2>/dev/null
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube'
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Antes do bootstrap, as VMs não devem ter outro cluster Kubernetes ativo.

## 3. Linux

```text
[ ] swap desativada
[ ] overlay carregado
[ ] br_netfilter carregado
[ ] net.ipv4.ip_forward = 1
[ ] bridge-nf-call-iptables = 1
[ ] cgroup v2
```

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

## 4. containerd / CRI

```text
[ ] containerd ativo
[ ] CRI não desativado
[ ] socket /run/containerd/containerd.sock disponível
[ ] SystemdCgroup = true na configuração efetiva
```

```bash
containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

## 5. Kubernetes inicial

```text
[ ] kubeadm 1.36.x
[ ] kubelet 1.36.x
[ ] kubectl 1.36.x
[ ] kubeadm/kubelet/kubectl em apt hold
```

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

> O destino 1.37.x só é configurado no bloco de upgrade, depois de o cluster 1.36.x estar construído e validado.
