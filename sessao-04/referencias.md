# Referências — Sessão 4

## Bibliografia do projeto

- Nigel Poulton — *The Kubernetes Book*;
- Marko Lukša — *Kubernetes in Action*;
- Kelsey Hightower, Brendan Burns, Joe Beda — *Kubernetes: Up and Running*;
- Nigel Poulton — *Docker Deep Dive*.

Estas obras suportam os conceitos de arquitetura, Pods, Control Plane/Workers, runtime, controllers e operação. Os comandos e detalhes dependentes de versão são validados na documentação oficial.

## Documentação oficial Kubernetes

- Installing kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Creating a cluster with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- Container runtimes: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- kubeadm join: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
- Upgrading kubeadm clusters: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Upgrading Linux nodes: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/
- Version Skew Policy: https://kubernetes.io/releases/version-skew-policy/
- Safely Drain a Node: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- kubeconfig: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
- Kubernetes 1.36 release: https://kubernetes.io/releases/1.36/
- Patch releases: https://kubernetes.io/releases/patch-releases/

## Calico

- Self-managed on-premises / Tigera Operator: https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
- System requirements / versões Kubernetes testadas: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
- Upgrade Calico on Kubernetes: https://docs.tigera.io/calico/latest/operations/upgrading/kubernetes-upgrade

## containerd

- CRI / documentação: https://github.com/containerd/containerd/tree/main/docs/cri

## Baseline desta edição — setembro de 2026

```text
Kubernetes inicial: 1.36.4
Kubernetes destino: 1.37.0
Calico de referência: 3.32.2
```

A série Calico 3.32 é oficialmente testada com Kubernetes 1.34–1.36. A utilização depois do upgrade para Kubernetes 1.37 é uma combinação que deve ser **pré-validada em laboratório** e não deve ser apresentada como oficialmente testada pelo fornecedor enquanto a matriz Calico não incluir 1.37.

## Regra de atualização

Antes de cada edição da formação, confirmar:

1. patches atuais das séries Kubernetes 1.36 e 1.37;
2. repositórios `pkgs.k8s.io` de ambas as minors;
3. versão `containerd` da imagem Ubuntu;
4. estrutura efetiva de `SystemdCgroup`;
5. release Calico escolhida e respetiva matriz de compatibilidade;
6. percurso completo de upgrade Control Plane → Worker;
7. estado de CoreDNS e do CNI após o upgrade.
