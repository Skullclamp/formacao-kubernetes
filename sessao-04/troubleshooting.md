# Troubleshooting — Sessão 4

Método:

```text
Sintoma → Evidência → Hipótese → Validação → Correção
```

| Sintoma | Hipótese possível | Primeiro passo |
|---|---|---|
| `kubeadm init` falha por memória | RAM insuficiente | `free -h` |
| `kubeadm init` falha por portas | Kubernetes/MicroK8s residual | `ss -ltnp` |
| `kubelite` ocupa portas Kubernetes | MicroK8s ativo | confirmar/remover na VM de laboratório |
| CP `NotReady` após init | CNI ainda ausente | `kubectl get nodes`, Pods e Events |
| CoreDNS `Pending` antes do Worker | sem nó schedulable | taints + Events |
| Pods Calico `Pending` | só existe CP com `NoSchedule` | `describe`, Events |
| `kubeadm join` diz token inválido | placeholder ou token expirado | gerar novo join no CP |
| Worker não aparece | join/API/kubelet | porta 6443 + logs kubelet |
| `kubectl` no Worker tenta `localhost:8080` | kubeconfig ausente | administrar pelo CP |
| APT continua a mostrar apenas 1.36 | repo ainda aponta para v1.36 | verificar `kubernetes.list` |
| `upgrade plan` não propõe 1.37 | kubeadm/repo/estado incorreto | versão + APT + plano |
| CP já está 1.37 e Worker 1.36 | version skew temporário durante o upgrade | continuar procedimento controlado |
| Worker continua a reportar v1.36 | kubelet não atualizado/reiniciado | versão local + `systemctl` |
| `drain` recusa durante upgrade | Pod sem controller/PDB | investigar; não usar `--force` automaticamente |
| Calico degrada depois do upgrade | compatibilidade/configuração | `tigerastatus`, Pods, Events |

## Comandos Kubernetes

```bash
kubectl get nodes -o wide
kubectl describe node <NODE>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
kubectl cluster-info
```

## Comandos no host

```bash
free -h
swapon --show
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
containerd config dump | grep -i -A5 -B5 SystemdCgroup
cat /etc/apt/sources.list.d/kubernetes.list
apt-cache madison kubeadm
```

## Regra de segurança operacional

Não acrescentar `--force`, `--ignore-preflight-errors` ou outra flag para contornar um erro antes de interpretar a causa.

No exercício didático do Pod direto, `drain --force` é intencional. Num **upgrade real**, a recusa do `drain` é um sinal para investigar primeiro.
