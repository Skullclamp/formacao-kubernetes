# Checklist do Formando — Preparação Manual das VMs

**Nome:** ____________________  **Posto:** ____________________

> Executa as verificações manualmente. Não uses scripts de validação como substituto da observação.

## 1. Identidade e recursos

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| Hostname correto | ☐ | ☐ |
| >= 2 vCPU | ☐ | ☐ |
| >= 2 GiB RAM | ☐ | ☐ |
| IP registado | ☐ | ☐ |
| Resolução entre nós | ☐ | ☐ |
| Hora sincronizada | ☐ | ☐ |

## 2. VM limpa

```bash
snap list microk8s 2>/dev/null || true
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube' || true
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' kubeadm kubelet kubectl 2>/dev/null || true

grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

- [ ] sem Kubernetes residual;
- [ ] sem repositório 1.37 residual;
- [ ] se existir 1.37 instalado, repor snapshot/VM limpa antes de continuar.

## 3. Linux

| Verificação | CP | Worker |
|---|:---:|:---:|
| swap desativada | ☐ | ☐ |
| `overlay` | ☐ | ☐ |
| `br_netfilter` | ☐ | ☐ |
| `ip_forward = 1` | ☐ | ☐ |
| bridge iptables = 1 | ☐ | ☐ |
| cgroup v2 | ☐ | ☐ |

## 4. containerd

| Verificação | CP | Worker |
|---|:---:|:---:|
| série 2.2.x | ☐ | ☐ |
| serviço ativo | ☐ | ☐ |
| CRI ativo | ☐ | ☐ |
| `SystemdCgroup = true` | ☐ | ☐ |

```bash
containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

## 5. Kubernetes inicial

| Verificação | CP | Worker |
|---|:---:|:---:|
| `kubeadm` 1.35.x | ☐ | ☐ |
| `kubelet` 1.35.x | ☐ | ☐ |
| `kubectl` 1.35.x | ☐ | ☐ |
| pacotes em `apt hold` | ☐ | ☐ |

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

**Não avançar se qualquer componente Kubernetes estiver em 1.36 ou 1.37 antes do bootstrap.**
