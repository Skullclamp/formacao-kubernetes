# Atividade — Ordenar a Instalação

Distribuir fora de ordem:

```text
[CNI / Calico]
[containerd]
[kubeadm init]
[kubeadm join]
[pré-requisitos Linux]
[kubelet / kubeadm / kubectl]
[validação do cluster]
```

## Tarefa

1. Ordena os elementos.
2. Justifica cada transição.
3. Classifica-a como **dependência técnica** ou **ordem pedagógica**.
4. Indica em que nó se executa `kubeadm init`.
5. Indica em que nó se executa `kubeadm join`.
6. Responde: um Worker pode fazer `join` antes do CNI? O que poderias observar?
7. Se alguns Pods do Calico/CoreDNS ficarem `Pending` quando só existe o Control Plane com `NoSchedule`, isso prova que o CNI está avariado? Justifica.

**Tempo:** 5–7 minutos.
