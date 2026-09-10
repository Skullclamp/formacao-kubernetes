# Checklist do Formando — Preparação Manual das VMs

**Nome:** ____________________  **Posto:** ____________________

> Preencher através de comandos executados manualmente. Não utilizar scripts de validação.

## 1. Identidade e recursos

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| Hostname correto | ☐ | ☐ |
| IP registado | ☐ | ☐ |
| >= 2 vCPU | ☐ | ☐ |
| >= 2 GiB RAM | ☐ | ☐ |
| Resolução entre os dois nós | ☐ | ☐ |
| Hora sincronizada | ☐ | ☐ |

## 2. Ausência de Kubernetes residual

Confirmar que não existe MicroK8s, k3s, Minikube ou uma instalação kubeadm anterior ativa.

```bash
snap list microk8s 2>/dev/null
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube'
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Antes de `kubeadm init`, as portas exclusivas do Control Plane (`6443`, `2379`, `2380`, `10257`, `10259`) não devem estar ocupadas por uma instalação anterior.

## 3. Linux

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| Swap desativada | ☐ | ☐ |
| `overlay` carregado | ☐ | ☐ |
| `br_netfilter` carregado | ☐ | ☐ |
| `net.ipv4.ip_forward = 1` | ☐ | ☐ |
| `bridge-nf-call-iptables = 1` | ☐ | ☐ |
| cgroup v2 confirmado | ☐ | ☐ |

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

## 4. containerd / CRI

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| `containerd` ativo | ☐ | ☐ |
| CRI não desativado | ☐ | ☐ |
| `SystemdCgroup = true` efetivo | ☐ | ☐ |
| Socket `/run/containerd/containerd.sock` existe | ☐ | ☐ |

```bash
containerd --version
systemctl is-active containerd
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ss -lx | grep containerd
sudo ctr plugins ls | grep -i cri
```

## 5. Ferramentas Kubernetes

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| `kubeadm` 1.37.x | ☐ | ☐ |
| `kubelet` 1.37.x | ☐ | ☐ |
| `kubectl` 1.37.x (instalado no laboratório por uniformização) | ☐ | ☐ |
| pacotes em `apt hold` | ☐ | ☐ |

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

> `kubectl` não é necessário para o Worker desempenhar a função de Node; neste laboratório é instalado nos dois nós por uniformização do ambiente.

Antes de avançar para `kubeadm init`, escolhe uma evidência de cada secção e explica ao formador o que ela demonstra.
