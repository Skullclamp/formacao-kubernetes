# Folha de Evidências — Sessão 4

**Formando:** __________________________

Regista comandos, versões e resultados observados manualmente.

## 1. Estado inicial das VMs

```text
Hostname Control Plane: ______________________
Hostname Worker: _____________________________
RAM / vCPU CP: _______________________________
RAM / vCPU Worker: ___________________________
Swap: ________________________________________
Resolução entre nós: _________________________
```

## 2. Runtime

```text
containerd CP: _______________________________
containerd Worker: ___________________________
CRI operacional: _____________________________
SystemdCgroup = true: ________________________
```

Esperado: `containerd` 2.2.x e CRI operacional nos dois nós.

## 3. Kubernetes antes do bootstrap

```text
Repositório configurado: _____________________
kubeadm CP: __________________________________
kubelet CP: __________________________________
kubectl CP: __________________________________
kubeadm Worker: ______________________________
kubelet Worker: ______________________________
kubectl Worker: ______________________________
apt hold: ____________________________________
```

Esperado: série **1.35.x** nos dois nós. Se aparecer 1.36 ou 1.37, não avançar até esclarecer a origem.

## 4. Depois de `kubeadm init`, antes do CNI

```text
Control Plane: _______________________________
CoreDNS: _____________________________________
```

Porque este estado é esperado?

__________________________________________________________________________

## 5. Calico / Tigera

```text
Calico: ______________________________________
Tigera Operator: _____________________________
CIDR observado: ______________________________
tigerastatus: ________________________________
```

Esperado nesta edição: Calico 3.32.2 e Tigera Operator 1.42.6.

## 6. Integração do Worker

O comando de criação do token foi executado em:

```text
[ ] k8s-cp-01
[ ] k8s-wk-01
```

O `kubeadm join` foi executado em:

```text
[ ] k8s-cp-01
[ ] k8s-wk-01
```

Estado após convergência:

```text
Control Plane Ready: _________________________
Worker Ready: ________________________________
CoreDNS: _____________________________________
Calico/Tigera: _______________________________
```

## 7. Manutenção

Resultado do `drain` sem `--force`:

```text

```

Porque recusou? __________________________________________________________

Estado depois do `uncordon`: ____________________________________________

## 8. Ponto de recuperação

```text
Cluster 1.35.x saudável antes do upgrade: ________________________________
Snapshot CP `pre-upgrade-1.35`: __________________________________________
Snapshot Worker `pre-upgrade-1.35`: ______________________________________
```

## 9. Upgrade do Control Plane

```text
kubeadm antes: _______________________________
destino de `kubeadm upgrade plan`: ___________
Control Plane depois: ________________________
kubelet depois: ______________________________
```

## 10. Version skew temporário

Depois de atualizar o Control Plane e antes de concluir o Worker:

```text
k8s-cp-01: ___________________________________
k8s-wk-01: ___________________________________
```

Porque esta diferença temporária é aceitável durante o processo?

__________________________________________________________________________

## 11. Upgrade do Worker

```text
Resultado de `kubeadm upgrade node`: _________
kubelet depois: ______________________________
```

## 12. Estado final

```text
k8s-cp-01: ___________________________________
k8s-wk-01: ___________________________________
CoreDNS: _____________________________________
Calico/Tigera: _______________________________
Worker schedulable: __________________________
```

Esperado: ambos os Nodes `Ready` em Kubernetes **1.36.x**.

### Conclusão técnica da sessão

__________________________________________________________________________
