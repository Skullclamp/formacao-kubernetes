# Laboratório Integrado — Sessão 4
## Construir e validar um cluster Kubernetes de dois nós

Este laboratório acompanha o percurso prático do Manual do Formando. O objetivo é chegar de duas VMs Ubuntu preparadas a um cluster Kubernetes funcional e administrável.

## Resultado esperado

```text
k8s-cp-01   Ready   control-plane
k8s-wk-01   Ready   <none>
```

com:

- `containerd` operacional;
- Kubernetes 1.37 instalado;
- Calico/Tigera Operator operacional;
- CoreDNS `Running`;
- `kubectl` administrativo funcional;
- manutenção básica (`cordon`, `drain`, `uncordon`) validada.

## Fase 1 — Preparar ambos os nós

Utilize o [`../checklist.md`](../checklist.md) e valide:

```text
[ ] hostname e IP
[ ] resolução entre nós
[ ] swap desativado
[ ] overlay e br_netfilter
[ ] ip_forward e bridge-nf-call-iptables
[ ] cgroup v2
[ ] sincronização horária
```

Pode usar, depois da validação manual:

```bash
../scripts/preflight_check.sh
```

**Checkpoint:** registe evidências em `CP1` da [`../folha_evidencias.md`](../folha_evidencias.md).

## Fase 2 — Instalar e validar containerd

Em ambos os nós:

1. instalar `containerd`;
2. gerar `/etc/containerd/config.toml`;
3. confirmar `SystemdCgroup = true`;
4. reiniciar o serviço;
5. validar `/run/containerd/containerd.sock`.

**Checkpoint:** `CP2`.

## Fase 3 — Instalar ferramentas Kubernetes

Em ambos os nós:

1. configurar `pkgs.k8s.io` para a série 1.37;
2. instalar `kubelet`, `kubeadm` e `kubectl`;
3. aplicar `apt-mark hold`;
4. comparar versões.

**Checkpoint:** `CP3`.

## Fase 4 — Bootstrap do Control Plane

Apenas em `k8s-cp-01`:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Depois configure `$HOME/.kube/config` conforme o Manual.

Observe:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, é esperado observar o Control Plane `NotReady` neste laboratório.

**Checkpoint:** `CP4`.

## Fase 5 — Instalar Calico via Tigera Operator

Antes da aula, a versão Calico deve ter sido validada pelo formador para a versão Kubernetes utilizada.

O script [`../scripts/fetch_calico_operator.sh`](../scripts/fetch_calico_operator.sh) apenas descarrega os recursos para inspeção; não os aplica automaticamente.

Depois de instalar CRDs, Operator e Custom Resources, valide:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
kubectl get pods -n kube-system
kubectl get nodes
```

**Checkpoint:** `CP5`.

## Fase 6 — Adicionar o Worker

No Control Plane, obtenha um comando atual:

```bash
kubeadm token create --print-join-command
```

Execute-o com `sudo` em `k8s-wk-01`.

Valide a partir do Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
```

**Checkpoint:** `CP6`.

## Fase 7 — kubeconfig e contextos

Explore:

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

Identifique `cluster`, `user`, `context` e `namespace` opcional.

## Fase 8 — Manutenção controlada

Crie o Pod de teste no Worker:

```bash
kubectl apply -f ../manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

Isole o Node:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

Primeiro experimente:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Interprete a recusa provocada pelo Pod sem controlador. Apenas no contexto deste exercício, depois de compreender a mensagem:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
```

Confirme que o Pod não é recriado e devolva o Worker ao serviço:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

**Checkpoint:** `CP7`.

## Fase 9 — Planeamento de upgrade

No Control Plane:

```bash
sudo kubeadm upgrade plan
```

Nesta sessão o objetivo é **interpretar** o plano, não executar um upgrade multi-node completo.

Para aprofundamento, consulte [`../exercicios/upgrade_complementar.md`](../exercicios/upgrade_complementar.md).

## Validação final

Execute:

```bash
../scripts/verify_cluster.sh
```

E confirme manualmente:

```text
[ ] dois Nodes Ready
[ ] Calico operacional
[ ] CoreDNS Running
[ ] API acessível
[ ] Worker schedulable depois do uncordon
```

Complete `CP8` da folha de evidências e explique ao formador o estado final do cluster.
