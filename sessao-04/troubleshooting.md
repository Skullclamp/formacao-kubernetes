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
| CoreDNS `Pending` antes do Worker | nenhum nó schedulable | verificar taints e Events |
| Worker não entra | token/API/kubelet | validar comando real de join e porta 6443 |
| `kubeadm token create` falha com admin kubeconfig | comando executado no Worker | voltar ao `k8s-cp-01` e criar token lá |
| `kubeadm join` falha com `IsPrivilegedUser` | comando executado sem privilégios | usar `sudo kubeadm join ...`; não ignorar o preflight |
| Bash responde `IP_CONTROL_PLANE: No such file or directory` | placeholder `<IP_CONTROL_PLANE>` executado literalmente | usar o comando real produzido pelo Control Plane |
| `kubectl` no Worker tenta `localhost:8080` | Worker sem kubeconfig administrativo | administrar o cluster a partir do CP |
| `drain` recusa o Pod de teste | Pod direto sem controller | é o comportamento esperado; no exercício usar seletivamente `--pod-selector=app=cordon-test` |
| aparecem muitos `tigera-operator` `Evicted`/`ContainerStatusUnknown` | drain integral do Worker num cluster pequeno e/ou falha do runtime ao terminar containers | parar o drain, confirmar estado do nó, Events e journal do kubelet; não avançar para upgrade |
| `runc ... unable to signal init: permission denied` | falha na terminação de containers; AppArmor é uma hipótese a confirmar | procurar `apparmor="DENIED"` no journal do kernel e registar versões de containerd/runc; não desativar AppArmor por tentativa |
| `tigerastatus` mostra `goldmane`/`whisker` `Degraded` | componentes opcionais de observabilidade não convergiram | na Sessão 4 usar apenas o `Installation` Calico mínimo; não mascarar falhas do runtime |
| upgrade não apresenta 1.36 | repo ainda aponta para 1.35 | verificar `kubernetes.list` e `apt-cache madison kubeadm` |
| aparece literalmente `<PKG_...>` num comando APT | foi usado um exemplo antigo/placeholder | parar e calcular a versão real com `apt-cache madison`; não executar placeholders |
| Worker permanece 1.35 | kubelet ainda não atualizado/reiniciado | verificar `kubelet --version` e serviço |
| Calico degrada após upgrade | CNI/scheduling/configuração | `tigerastatus`, Pods e Events |

## Caso real: `kubeadm token create` no Worker

Sintoma:

```text
k8sadmin@k8s-wk-01:~$ sudo kubeadm token create --print-join-command
error: failed to load admin kubeconfig: open /root/.kube/config: no such file or directory
```

O detalhe decisivo está no próprio prompt: `k8s-wk-01`. O comando `kubeadm token create` necessita de acesso administrativo à API e deve ser executado no Control Plane.

### Correção

No Control Plane:

```bash
hostname
# esperado: k8s-cp-01

set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

Depois, no Worker, executar com `sudo` apenas o comando `kubeadm join ...` real devolvido.

Não copiar `/etc/kubernetes/admin.conf` para o Worker apenas para conseguir executar `kubeadm token create`.

## Caso real: `kubectl` no Worker tenta localhost:8080

Depois de um `join` bem-sucedido, o Worker possui `/etc/kubernetes/kubelet.conf`, mas não recebe automaticamente um kubeconfig administrativo para o utilizador interativo.

No Worker, validar localmente:

```bash
sudo systemctl is-active kubelet
sudo systemctl status kubelet --no-pager
sudo ls -l /etc/kubernetes/kubelet.conf
```

No Control Plane, validar o estado global:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
```

## Caso real: muitos Pods `tigera-operator` Evicted

Num cluster pedagógico com apenas um Control Plane e um Worker, um `drain` integral do Worker pode envolver componentes de sistema que não fazem parte do objetivo do exercício. O Tigera Operator tem tolerations amplas e pode voltar a ser colocado num nó marcado como unschedulable, originando churn durante um drain.

Para a demonstração de `cordon`/`drain`, a Sessão 4 passa a atuar **apenas** sobre o Pod `app=cordon-test`:

```bash
kubectl cordon k8s-wk-01

kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

O primeiro comando deve recusar o Pod direto por não ter controller. Depois, apenas neste exercício:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force

kubectl uncordon k8s-wk-01
```

Isto demonstra a semântica do `drain` sem evacuar CoreDNS/Tigera/outros componentes do laboratório.

> No upgrade real do Worker, o drain integral continua a fazer parte do procedimento de manutenção. Antes dele, o cluster tem de estar saudável e deve ser verificado onde estão os componentes críticos.

## Caso real: `runc ... unable to signal init: permission denied`

Foi observado no Worker um erro do runtime ao tentar terminar containers. Enquanto este erro existir, **não avançar para o upgrade**.

Recolher primeiro evidência no Worker:

```bash
containerd --version
runc --version

dpkg -S "$(command -v runc)" 2>/dev/null || true
apt-cache policy containerd.io containerd runc apparmor

sudo aa-status
sudo journalctl -k --since "-30 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|audit.*DENIED|runc|containerd'

sudo journalctl -u kubelet -n 100 --no-pager \
  | grep -Ei 'unable to signal init|permission denied|KillContainer|KillPodSandbox'
```

Se o journal do kernel mostrar `apparmor="DENIED"` associado a `runc`/`containerd`, a hipótese AppArmor fica confirmada. Até essa evidência existir, trata-se apenas de uma hipótese.

**Não desativar AppArmor globalmente nem acrescentar workarounds permanentes apenas para fazer o laboratório avançar.** Primeiro identificar a combinação exata de packages e a origem da negação.

## Caso real: `tigerastatus` com Goldmane/Whisker degradados

O ficheiro `custom-resources.yaml` completo do Calico 3.32.2 também ativa APIServer, Goldmane e Whisker. Esses componentes não são objetivos da Sessão 4.

O laboratório passa por isso a usar `manifests/calico_installation_sessao4.yaml`, contendo apenas o recurso `Installation` necessário ao CNI/core networking. Esta simplificação reduz ruído e consumo de recursos, mas **não deve ser usada para esconder um erro do runtime**.

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

## Gate de saúde antes de qualquer upgrade

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

No Worker:

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd
sudo journalctl -u kubelet -n 80 --no-pager
```

Não avançar se existirem Nodes `NotReady`, ciclos de `Evicted`/`ContainerStatusUnknown`, componentes Calico `Degraded` ou erros persistentes de terminação do runtime.

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

> Não acrescentar `--force`, `--ignore-preflight-errors` ou alterações de segurança antes de compreender a causa do problema.
