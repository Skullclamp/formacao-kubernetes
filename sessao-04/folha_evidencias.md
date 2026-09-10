# Folha de Evidências — Sessão 4

**Formando:** __________________________

Regista comandos e resultados observados manualmente.

## 1. Estado inicial

```text
k8s-cp-01 Kubernetes: __________________
k8s-wk-01 Kubernetes: __________________
containerd: _____________________________
SystemdCgroup: __________________________
```

Esperado: Kubernetes 1.36.x nos dois nós antes do bootstrap.

## 2. Depois de kubeadm init, antes do CNI

```text
Control Plane: __________________________
CoreDNS: ________________________________
```

Porque este estado é esperado? __________________________________________

## 3. Cluster 1.36.x saudável

```text
Control Plane Ready: ____________________
Worker Ready: ___________________________
CoreDNS: ________________________________
Calico/Tigera: __________________________
```

## 4. Manutenção

Resultado do `drain` sem `--force`:

```text

```

Porque recusou? __________________________________________________________

Estado depois do `uncordon`: ____________________________________________

## 5. Upgrade do Control Plane

```text
kubeadm antes: __________________________
destino de kubeadm upgrade plan: ________
kubeadm depois: _________________________
kubelet depois: _________________________
```

## 6. Version skew

Depois do upgrade do Control Plane e antes de terminar o Worker:

```text
k8s-cp-01: ______________________________
k8s-wk-01: ______________________________
```

Explica por que esta diferença temporária pode existir durante o processo:

__________________________________________________________________________

## 7. Upgrade do Worker

```text
kubeadm upgrade node: ___________________
kubelet depois: _________________________
```

## 8. Estado final

```text
k8s-cp-01: ______________________________
k8s-wk-01: ______________________________
CoreDNS: ________________________________
Calico/Tigera: __________________________
```

Conclusão técnica da sessão:

__________________________________________________________________________
