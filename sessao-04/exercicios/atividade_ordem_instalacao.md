# Atividade — Ordenar a Instalação e Evolução do Cluster

## Parte A — Bootstrap

Distribuir fora de ordem:

```text
[CNI / Calico]
[containerd]
[kubeadm init]
[kubeadm join]
[pré-requisitos Linux]
[kubelet / kubeadm / kubectl 1.36.x]
[validação do cluster 1.36.x]
```

Ordena os elementos e justifica cada transição.

## Parte B — Upgrade

Distribuir fora de ordem:

```text
[mudar repositório para 1.37]
[atualizar kubeadm do Control Plane]
[kubeadm upgrade plan]
[kubeadm upgrade apply]
[drain do Control Plane]
[atualizar kubelet/kubectl do Control Plane]
[atualizar kubeadm do Worker]
[kubeadm upgrade node]
[drain do Worker]
[atualizar kubelet/kubectl do Worker]
[validação final 1.37.x]
```

Ordena e responde:

1. Porque o Control Plane vem antes do Worker?
2. Em que momento pode existir version skew?
3. Porque `kubeadm` é atualizado antes do `kubelet`?
4. Porque se valida o cluster novamente no final?

**Tempo:** 8–10 minutos.
