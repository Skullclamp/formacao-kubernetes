# Troubleshooting — Sessão 4

Método:

```text
Sintoma → Evidência → Hipótese → Validação → Correção → Nova validação
```

| Sintoma | Hipótese provável | Verificação / decisão |
|---|---|---|
| instalou Kubernetes 1.37 em vez de 1.35 | repositório residual ou packages 1.37 já instalados | inspecionar APT e `dpkg-query`; em laboratório repor VM limpa |
| `kubeadm init` usa versão diferente da esperada | bootstrap não foi fixado | usar `--kubernetes-version=<1.35.x real>` |
| `kubeadm init` falha por portas | Kubernetes/MicroK8s residual | `ss -ltnp`; não ignorar preflight |
| `kubelite` ocupa portas | MicroK8s ativo | identificar/remover no laboratório |
| Node `NotReady` após init | CNI ainda ausente | instalar/validar Calico |
| CoreDNS `Pending` antes do Worker | nenhum nó schedulable | verificar taint e Events |
| Worker não entra | token/API/kubelet | validar comando real de join e porta 6443 |
| `kubeadm token create` falha com admin kubeconfig | comando executado no Worker | voltar ao `k8s-cp-01` e criar token lá |
| `kubectl` no Worker tenta localhost:8080 | Worker sem kubeconfig administrativo | administrar a partir do CP |
| `drain` recusa | Pod sem controller/PDB | ler a mensagem; não usar `--force` automaticamente |
| upgrade não apresenta 1.36 | repo ainda aponta para 1.35 | verificar `kubernetes.list` e `apt-cache madison kubeadm` |
| Worker permanece 1.35 | kubelet ainda não atualizado/reiniciado | verificar `kubelet --version` e serviço |
| Calico degrada após upgrade | CNI/scheduling/configuração | `tigerastatus`, Pods e Events |

## Caso real: `kubeadm token create` no Worker

Sintoma:

```text
k8sadmin@k8s-wk-01:~$ sudo kubeadm token create --print-join-command
error: failed to load admin kubeconfig: open /root/.kube/config: no such file or directory
```

O detalhe decisivo está no próprio prompt:

```text
k8s-wk-01
```

O comando `kubeadm token create` cria/gera credenciais de bootstrap **no cluster** e necessita de acesso administrativo à API. Deve ser executado no Control Plane.

### Correção

No Control Plane:

```bash
hostname
# esperado: k8s-cp-01

set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig /etc/kubernetes/admin.conf
```

Depois, no Worker, executar **apenas o comando `kubeadm join ...` devolvido**.

### O que não fazer

Não copiar `/etc/kubernetes/admin.conf` para o Worker apenas para conseguir executar `kubeadm token create`. Isso transforma um erro de localização do comando numa distribuição desnecessária de credenciais administrativas.

## Caso real: APT instala 1.37 em vez de 1.35

Primeiro recolher evidência:

```bash
grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true

dpkg-query -W -f='${Package} ${Version}\n' \
  kubeadm kubelet kubectl 2>/dev/null || true

apt-cache policy kubeadm kubelet kubectl
apt-cache madison kubeadm
```

No laboratório, queremos uma VM limpa com o repositório `v1.35` e instalação **explicitamente versionada**:

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

test -n "$K8S_PKG_VERSION"
```

Se o sistema já tiver packages 1.37 instalados de um ensaio anterior, a solução pedagógica é restaurar o snapshot inicial e recomeçar. Não introduzimos um downgrade APT improvisado no percurso normal.

## Diagnóstico geral

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus

systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 80 --no-pager

cat /etc/apt/sources.list.d/kubernetes.list
apt-cache madison kubeadm
containerd --version
containerd config dump | grep -i -A5 -B5 SystemdCgroup
```

> Não acrescentar `--force` ou `--ignore-preflight-errors` antes de compreender a causa do problema.
