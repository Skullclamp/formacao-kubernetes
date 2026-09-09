# Folha de Evidências — Sessão 4

**Formando:** __________________________

## CP1 — Pré-requisitos

**Evidência:**
```text

```
**Interpretação:**

## CP2 — containerd / CRI

```text
containerd --version:
SystemdCgroup:
socket CRI:
```

## CP3 — Ferramentas Kubernetes

```text
kubeadm:
kubelet:
kubectl:
```

As versões são coerentes? __________

## CP4 — Após `kubeadm init`, antes do CNI

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Estado: __________

Porque é esperado?

## CP5 — Após Calico

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
kubectl get nodes
```

Que evidência confirma a rede operacional?

## CP6 — Após Worker join

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

## CP7 — `cordon` / `drain`

Resultado do `drain` sem `--force`:
```text

```

Porque recusou?

Resultado com `--force`:
```text

```

Porque o Pod não reapareceu?

## CP8 — Síntese

```text
Control Plane: ______________________________________________________
CRI: ________________________________________________________________
cordon: _____________________________________________________________
drain: ______________________________________________________________
uncordon: ___________________________________________________________
```
