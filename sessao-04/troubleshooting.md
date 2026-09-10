# Matriz de Troubleshooting — Sessão 4

```text
Sintoma → Evidência → Hipótese → Validação → Correção
```

| Sintoma | Evidência inicial | Hipótese possível | Próximo passo |
|---|---|---|---|
| `kubeadm init` falha por memória | preflight output | RAM abaixo do mínimo | `free -h`; aumentar RAM da VM |
| `kubeadm init` falha por portas | `ss -ltnp` | Kubernetes/MicroK8s residual | identificar processo; não ignorar o preflight |
| `kubelite` ocupa 10250/10257/10259 | `ss -ltnp` | MicroK8s ativo | confirmar/remover/parar MicroK8s na VM de laboratório |
| CP `NotReady` após init | `kubectl get nodes` | CNI ainda ausente | instalar/validar CNI |
| CoreDNS `Pending` antes do Worker | Pods + Events | CP com `NoSchedule` e nenhum Worker | integrar Worker; aguardar scheduling |
| Pods Calico `Pending` | `get pods -o wide`, Events | sem nó schedulable | confirmar taints e existência do Worker |
| Operator não arranca | Pods `tigera-operator` | CRDs/imagem/API/compatibilidade | `describe`, Events |
| Calico degradado | `tigerastatus` | CIDR/rede/scheduling/compatibilidade | Pods, Events, logs |
| Worker não aparece | `get nodes` | join/token/API | kubelet logs, porta 6443 |
| `kubeadm join` diz token inválido | output | exemplo/placeholder ou token expirado | gerar novo `kubeadm token create --print-join-command` no CP |
| Worker `NotReady` | Node Conditions | CNI/runtime/kubelet | `describe node`, Calico, logs |
| `kubectl` no Worker tenta localhost:8080 | erro do cliente | ausência de kubeconfig | administrar a partir do CP ou configurar kubeconfig apropriado |
| `drain` recusa | output | Pod sem controller/DaemonSet | ler mensagem antes de acrescentar flags |
| Node fica `SchedulingDisabled` | `get nodes` | falta `uncordon` | `kubectl uncordon` |

## Comandos Kubernetes

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl cluster-info
```

## Comandos no host

```bash
free -h
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
swapon --show
sysctl net.ipv4.ip_forward
stat -fc %T /sys/fs/cgroup
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
containerd config dump | grep -i -A5 -B5 SystemdCgroup
```

> Não acrescentar `--force`, `--ignore-preflight-errors` ou outras flags para contornar um erro antes de interpretar a causa.
