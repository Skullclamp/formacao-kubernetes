# Folha de Evidências — Sessão 4

**Formando:** __________________________

> Registar comandos e resultados observados manualmente. Não usar scripts como evidência principal.

## CP1 — Pré-requisitos

```text
Hostname CP:
Hostname Worker:
RAM CP:
RAM Worker:
Swap:
Resolução de nomes:
cgroup:
```

**Interpretação:**

---

## CP2 — containerd / CRI

```text
containerd --version:
CRI ativo:
SystemdCgroup:
socket CRI:
```

**Que evidência confirma que o kubelet poderá comunicar com o runtime?**

---

## CP3 — Ferramentas Kubernetes

```text
kubeadm:
kubelet:
kubectl:
apt hold:
```

As versões são coerentes? __________

---

## CP4 — Após `kubeadm init`, antes do CNI

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Estado do Control Plane: __________________

Estado do CoreDNS: ________________________

Porque é esperado nesta fase?

---

## CP5 — CNI aplicado, antes/depois da integração do Worker

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

Regista:

```text
Control Plane Ready?:
Pods Pending?:
Motivo observado nos Events, se aplicável:
```

> Se só existir o Control Plane e tiver `NoSchedule`, alguns Deployments podem aguardar a entrada do Worker.

---

## CP6 — Após `kubeadm join`

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

```text
Worker Ready?:
CoreDNS Running?:
Calico convergiu?:
```

Que evidência confirma que a rede de Pods está operacional?

---

## CP7 — `cordon` / `drain`

Resultado do `drain` sem `--force`:

```text

```

Porque recusou?

Resultado com `--force`:

```text

```

Porque o Pod não reapareceu?

Estado depois de `uncordon`:

```text

```

---

## CP8 — Síntese

```text
Control Plane:
Worker:
CRI:
CNI:
CoreDNS:
cordon:
drain:
uncordon:
```

**Uma decisão operacional importante que retiraste deste laboratório:**
