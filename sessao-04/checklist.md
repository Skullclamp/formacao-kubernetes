# Checklist do Formando — Pré-requisitos

**Nome:** ____________________  **Posto:** ____________________

| Verificação | k8s-cp-01 | k8s-wk-01 |
|---|:---:|:---:|
| Hostname correto | ☐ | ☐ |
| IP registado | ☐ | ☐ |
| Resolução `/etc/hosts` | ☐ | ☐ |
| Swap desativado | ☐ | ☐ |
| `overlay` carregado | ☐ | ☐ |
| `br_netfilter` carregado | ☐ | ☐ |
| `ip_forward = 1` | ☐ | ☐ |
| `bridge-nf-call-iptables = 1` | ☐ | ☐ |
| cgroup v2 confirmado | ☐ | ☐ |
| Hora sincronizada | ☐ | ☐ |
| `containerd` ativo | ☐ | ☐ |
| `SystemdCgroup = true` | ☐ | ☐ |
| Socket containerd disponível | ☐ | ☐ |

## Comandos de evidência

```bash
hostname
ip -br address
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
systemctl is-active containerd
grep -n "SystemdCgroup" /etc/containerd/config.toml
sudo ss -lx | grep containerd
```

Antes de avançar, explica uma evidência que confirme que o Node está preparado.
