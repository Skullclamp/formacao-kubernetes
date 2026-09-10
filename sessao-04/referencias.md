# Referências — Sessão 4

## Bibliografia do projeto

- Nigel Poulton — *The Kubernetes Book*;
- Marko Lukša — *Kubernetes in Action*;
- Kelsey Hightower, Brendan Burns, Joe Beda — *Kubernetes: Up and Running*;
- Nigel Poulton — *Docker Deep Dive*.

Estas obras suportam os conceitos de arquitetura, Pods, Control Plane/Workers, runtime, controllers e operação. Os comandos e detalhes dependentes de versão são validados na documentação oficial.

## Documentação oficial

- Kubernetes — Installing kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Kubernetes — Creating a cluster with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- Kubernetes — Container runtimes: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Kubernetes — kubeadm join: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
- Kubernetes — kubeadm upgrade: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Kubernetes — Safely drain a Node: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- Kubernetes — kubeconfig: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
- Calico — instalação on-premises / Tigera Operator: https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises
- Calico — requisitos e compatibilidade: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
- containerd — documentação CRI: https://github.com/containerd/containerd/tree/main/docs/cri

## Regra de atualização

Antes de cada edição da formação, confirmar:

1. série Kubernetes disponível em `pkgs.k8s.io`;
2. versão `containerd` da imagem Ubuntu usada;
3. estrutura efetiva de `SystemdCgroup`;
4. release Calico/Tigera escolhida e respetiva compatibilidade;
5. requisitos e comandos de upgrade específicos da versão.
