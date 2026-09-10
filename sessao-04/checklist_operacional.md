# Checklist Operacional Manual — Sessão 4

Este recurso acompanha o laboratório. Cada checkpoint é validado **manualmente** com comandos e observação.

## CP1 — Pré-requisitos Linux — ambos os nós

```bash
hostname
ip -br address
free -h
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
getent hosts k8s-cp-01
getent hosts k8s-wk-01
```

**Só avançar se:** identidade, rede, memória, swap, módulos, sysctl, cgroup e resolução estiverem corretos.

---

## CP2 — containerd / CRI — ambos os nós

```bash
containerd --version
systemctl status containerd --no-pager
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

**Só avançar se:**

```text
containerd ativo
CRI disponível
CRI não desativado
SystemdCgroup = true
/run/containerd/containerd.sock disponível
```

---

## CP3 — ferramentas Kubernetes — ambos os nós

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

**Esperado:** série 1.37 coerente nos dois nós e pacotes em `hold`.

---

## CP4 — bootstrap — apenas no Control Plane

Executar o bootstrap **apenas em `k8s-cp-01`**:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Configurar o `kubectl` do utilizador:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

**Observação pedagógica:** antes do CNI, o Control Plane pode estar `NotReady` e o CoreDNS ainda não estar operacional.

---

## CP5 — aplicar o CNI — no Control Plane

Aplicar os recursos Calico/Tigera definidos para a edição da formação.

Acompanhar:

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

**Importante:** enquanto só existir o Control Plane com a taint `node-role.kubernetes.io/control-plane:NoSchedule`, alguns Deployments podem permanecer `Pending`. Não remover a taint. Avançar para a integração do Worker quando a rede base do Control Plane estiver disponível.

---

## CP6 — integrar o Worker

No Control Plane:

```bash
sudo kubeadm token create --print-join-command
```

Copiar o comando real gerado e executá-lo **apenas no `k8s-wk-01`**, com privilégios:

```bash
sudo kubeadm join <ENDPOINT_REAL> --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

> Não escrever literalmente `<TOKEN_REAL>`, `<HASH_REAL>`, `VALOR_REAL` ou `...`.

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Aguardar a convergência.

**Resultado esperado:**

```text
k8s-cp-01   Ready   control-plane
k8s-wk-01   Ready   <none>
CoreDNS     Running
Calico      operacional
```

---

## CP7 — manutenção do Worker

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide

kubectl cordon k8s-wk-01
kubectl get nodes

kubectl drain k8s-wk-01 --ignore-daemonsets
# ler e explicar a recusa causada pelo Pod direto

kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl get pod cordon-test

kubectl uncordon k8s-wk-01
kubectl get nodes
```

**Resultado final:** Worker `Ready`, schedulable e sem `cordon-test`.

---

## CP8 — validação final manual

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Confirmar manualmente:

```text
[ ] Control Plane Ready
[ ] Worker Ready
[ ] Worker schedulable
[ ] Calico operacional
[ ] CoreDNS Running
[ ] API acessível
[ ] contexto kubectl conhecido
[ ] Pod cordon-test removido
```
