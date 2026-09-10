# Checklist Operacional Manual — Sessão 4

Os checkpoints são validados **manualmente**. Não há script de instalação para o formando.

## CP1 — Pré-requisitos Linux

Executar nos dois nós:

```bash
hostname
free -h
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
getent hosts k8s-cp-01
getent hosts k8s-wk-01
```

## CP2 — containerd / CRI

```bash
containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

## CP3 — Kubernetes 1.36.x

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

Esperado: série 1.36.x coerente nos dois nós.

## CP4 — Bootstrap do Control Plane

**Apenas `k8s-cp-01`:**

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Depois configurar o kubeconfig e observar `NotReady` antes do CNI.

## CP5 — Calico / CNI

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

Alguns Pods podem ficar `Pending` enquanto só existir o Control Plane com `NoSchedule`.

## CP6 — Worker

Gerar o join no Control Plane e executar o comando real **apenas em `k8s-wk-01`**.

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Só avançar quando o cluster 1.36.x estiver saudável.

## CP7 — Manutenção

```bash
kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
# interpretar a recusa provocada pelo Pod direto
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl uncordon k8s-wk-01
```

O `--force` é usado apenas no exercício didático do Pod sem controller.

## CP8 — Upgrade do Control Plane

```text
repo 1.37
→ kubeadm 1.37
→ kubeadm upgrade plan
→ kubeadm upgrade apply v1.37.x
→ drain k8s-cp-01
→ kubelet + kubectl 1.37
→ restart kubelet
→ uncordon
```

Registar o version skew observado antes de prosseguir.

## CP9 — Upgrade do Worker

```text
repo 1.37
→ kubeadm 1.37
→ kubeadm upgrade node
→ drain k8s-wk-01 a partir do CP
→ kubelet + kubectl 1.37
→ restart kubelet
→ uncordon
```

## CP10 — Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Esperado:

```text
k8s-cp-01   Ready   control-plane   v1.37.x
k8s-wk-01   Ready   <none>          v1.37.x
```
