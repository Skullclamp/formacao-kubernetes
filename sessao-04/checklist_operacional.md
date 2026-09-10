# Checklist Operacional Manual — Sessão 4

## CP1 — Pré-requisitos Linux — ambos os nós

```bash
hostname
free -h
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

- [ ] CP = `k8s-cp-01`
- [ ] Worker = `k8s-wk-01`
- [ ] Linux preparado
- [ ] sem MicroK8s/k3s/Minikube/cluster anterior

## CP2 — containerd — ambos os nós

```bash
containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

- [ ] containerd 2.2.x
- [ ] CRI operacional
- [ ] `SystemdCgroup = true`

## CP3 — Kubernetes 1.35.x — ambos os nós

```bash
grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

- [ ] único repositório Kubernetes pretendido = série 1.35
- [ ] `kubeadm`, `kubelet` e `kubectl` = 1.35.x
- [ ] pacotes em hold

## CP4 — Bootstrap — apenas Control Plane

```bash
hostname
# esperado: k8s-cp-01
```

```bash
sudo kubeadm init \
  --kubernetes-version=<VERSAO_1_35_REAL> \
  --pod-network-cidr=192.168.0.0/16
```

- [ ] API Server responde
- [ ] kubeconfig configurado
- [ ] Control Plane registado
- [ ] `NotReady` antes do CNI compreendido

## CP5 — Calico / Tigera — Control Plane

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

- [ ] Calico 3.32.2 aplicado
- [ ] Tigera Operator esperado = 1.42.6
- [ ] CIDR = 192.168.0.0/16

## CP6 — Integrar Worker

### No Control Plane

```bash
hostname
# esperado: k8s-cp-01
set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig /etc/kubernetes/admin.conf
```

### No Worker

```bash
hostname
# esperado: k8s-wk-01
```

Executar **apenas** o `kubeadm join ...` real gerado no Control Plane.

- [ ] CP `Ready`
- [ ] Worker `Ready`
- [ ] CoreDNS `Running`
- [ ] Calico/Tigera saudável

## CP7 — Manutenção

```bash
kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
# interpretar a recusa do Pod direto
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl uncordon k8s-wk-01
```

- [ ] Worker novamente schedulable
- [ ] Pod direto não recriado

## CP8 — Recuperação antes do upgrade

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
```

- [ ] cluster 1.35.x saudável
- [ ] snapshot `pre-upgrade-1.35` do CP
- [ ] snapshot `pre-upgrade-1.35` do Worker

## CP9 — Upgrade do Control Plane para 1.36.x

```text
repo 1.36
→ kubeadm 1.36
→ kubeadm upgrade plan
→ kubeadm upgrade apply
→ drain
→ kubelet/kubectl 1.36
→ restart kubelet
→ uncordon
```

- [ ] Control Plane em 1.36.x
- [ ] Worker ainda pode estar em 1.35.x

## CP10 — Upgrade do Worker para 1.36.x

```text
repo 1.36
→ kubeadm 1.36
→ kubeadm upgrade node
→ drain
→ kubelet/kubectl 1.36
→ restart kubelet
→ uncordon
```

## CP11 — Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

- [ ] dois Nodes `Ready`
- [ ] dois Nodes em 1.36.x
- [ ] CoreDNS saudável
- [ ] Calico/Tigera saudável
- [ ] API acessível
