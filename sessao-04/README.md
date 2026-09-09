# Sessão 4 — Kubernetes Admin I
## Instalação e Administração do Cluster

## Foco

**CONSTRUIR O CLUSTER**

A Sessão 4 marca a transição de Docker para a administração de uma plataforma Kubernetes.

## Ambiente de referência

```text
Control Plane:   k8s-cp-01
Worker:          k8s-wk-01
SO:              Ubuntu 26.04 LTS
Kubernetes:      1.37
Runtime:         containerd
CNI:             Calico via Tigera Operator
Pod CIDR:        192.168.0.0/16
Service CIDR:    10.96.0.0/12
```

## Percurso

```text
pré-requisitos Linux
        ↓
containerd
        ↓
kubelet / kubeadm / kubectl
        ↓
kubeadm init
        ↓
kubeconfig
        ↓
Calico / CNI
        ↓
kubeadm join
        ↓
validação
        ↓
manutenção
```

## Organização prevista

- `labs/` — exercícios práticos da sessão;
- `scripts/` — utilitários auxiliares;
- `manifests/` — recursos Kubernetes/Calico usados no laboratório;
- `exercicios/` — consolidação e prática complementar.

> Os recursos executáveis dependentes de versão devem ser validados antes de cada edição da formação.
