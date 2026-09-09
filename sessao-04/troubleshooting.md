# Matriz de Troubleshooting — Sessão 4

```text
Sintoma → Evidência → Hipótese → Validação → Correção
```

| Sintoma | Evidência inicial | Hipótese possível | Próximo passo |
|---|---|---|---|
| `kubeadm init` falha | preflight output | swap/runtime/rede | `swapon --show`, `systemctl status containerd` |
| CP `NotReady` após init | `kubectl get nodes` | CNI em falta | estado Calico/CoreDNS |
| CoreDNS `Pending` | Pods `kube-system` | rede de Pods indisponível | `tigerastatus`, `calico-system` |
| Operator não arranca | Pods `tigera-operator` | CRDs/imagem/API/compatibilidade | `describe`, Events |
| Calico degradado | `tigerastatus` | CIDR/rede/compatibilidade | Pods, `describe`, logs |
| Worker não aparece | `get nodes` | join/token/API | kubelet logs, porta 6443 |
| Worker `NotReady` | Node Conditions | CNI/runtime/kubelet | `describe node`, Calico |
| `kubectl` falha | erro do cliente | kubeconfig/contexto/API | `current-context`, `cluster-info` |
| `drain` recusa | output | Pod sem controller/DaemonSet | ler mensagem antes de flags |
| Node fica `SchedulingDisabled` | `get nodes` | falta `uncordon` | `kubectl uncordon` |

## Comandos Kubernetes

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A
kubectl get tigerastatus
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
kubectl cluster-info
```

## Comandos host

```bash
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
swapon --show
sysctl net.ipv4.ip_forward
stat -fc %T /sys/fs/cgroup
```

> Não acrescentar `--force` ou flags para contornar um erro antes de interpretar a causa.
