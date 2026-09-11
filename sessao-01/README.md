# Sessão 1 — Fundamentos de Containers e Kubernetes

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

No final da sessão deverá compreender os fundamentos de virtualização, containers e Kubernetes, executar operações básicas com containers e criar os primeiros recursos Kubernetes através de `kubectl` e YAML.

## Documentação da sessão

- [Plano da Sessão 1](plano_sessao_1.md)
- [Manual do formando](manual_formando.md)
- [Cheatsheet](cheatsheet.md)
- [Checklist de validação](checklist.md)

## Percurso

```text
Virtualização
    ↓
Containers e VMs
    ↓
Imagens / Runtime / Registry
    ↓
Networking / Volumes / Segurança
    ↓
Orquestração
    ↓
Kubernetes
    ↓
Control Plane / Worker Nodes
    ↓
kubectl / kubeconfig
    ↓
YAML / Pod / Namespace / Labels / Selectors
```

## Laboratórios

1. [Fundamentos de containers](labs/01-fundamentos-containers.md)
2. [Kubernetes básico](labs/02-kubernetes-basico.md)

## Ficheiros de apoio

- [`manifests/pod-demo.yaml`](manifests/pod-demo.yaml)
- [`cheatsheet.md`](cheatsheet.md)
- [`checklist.md`](checklist.md)

## Antes de começar

```bash
cd formacao-kubernetes
git pull
cd sessao-01
```

Confirme que tem acesso às ferramentas utilizadas no laboratório:

```bash
docker version
kubectl version --client
kubectl config current-context
```

> Nesta sessão o objetivo principal é compreender os fundamentos. Dockerfiles, construção de imagens, Deployments, Services, Ingress, PV/PVC, RBAC e outros objetos serão aprofundados nas sessões seguintes.
