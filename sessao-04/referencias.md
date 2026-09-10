# Referências — Sessão 4

## Documentação oficial usada para a baseline técnica

### Kubernetes

- **Kubernetes Releases / Patch Releases** — confirmar as minors suportadas e os patches disponíveis antes de cada edição.
- **Installing kubeadm** — instalação através de `pkgs.k8s.io` e repositórios separados por minor.
- **Upgrading kubeadm clusters from 1.35.x to 1.36.x** — sequência oficial do upgrade adotado nesta sessão.
- **Upgrading Linux nodes** — atualização de `kubeadm`, `kubelet` e `kubectl` por nó.
- **Version Skew Policy** — versões temporariamente diferentes durante um upgrade controlado.
- **kubeadm token** / **kubeadm token create** — criação de bootstrap tokens e geração do comando `join`.

Baseline de referência desta edição:

```text
Kubernetes 1.35.8 → 1.36.4
```

Não se saltam versões minor durante o upgrade.

### containerd

- **containerd RELEASES.md / Kubernetes support matrix** — matriz de versões recomendadas por minor Kubernetes.

A série adotada é:

```text
containerd 2.2.x
```

É uma série recomendada em comum para Kubernetes 1.35 e 1.36.

### Calico / Tigera Operator

- **Calico System requirements** — matriz de Kubernetes testada pelo projeto.
- **Calico Component versions** — relação entre a release Calico e o Tigera Operator.

Baseline desta edição:

```text
Calico 3.32.2
Tigera Operator 1.42.6
```

Calico 3.32 é oficialmente testado com Kubernetes 1.34, 1.35 e 1.36.

### Traefik

- **Traefik Kubernetes requirements** — política de compatibilidade com versões Kubernetes.

Traefik **não é instalado na Sessão 4**. A referência é mantida porque será utilizado posteriormente na formação para Ingress/Gateway. A política atual cobre pelo menos as três versões minor Kubernetes mais recentes, incluindo 1.35 e 1.36 nesta edição.

---

## Bibliografia de apoio conceptual

As obras disponibilizadas no projeto são utilizadas para conceitos relativamente estáveis, e não como fonte única para comandos/versionamento de 2026:

- *The Kubernetes Book* — arquitetura, objetos, modelo declarativo e controllers;
- *Kubernetes: Up and Running* — arquitetura, API e operação do cluster;
- *Kubernetes in Action* — Pods, Nodes, controllers, Services e troubleshooting;
- *Docker Deep Dive* — containers, runtimes e fundamentos complementares;
- *Ultimate Docker Container Book* — conceitos de containers e imagens.

## Princípio de utilização das fontes

```text
CONCEITO ESTÁVEL
      ↓
livros + documentação oficial

COMANDO / VERSÃO / COMPATIBILIDADE
      ↓
documentação oficial atual + ensaio técnico
```

Antes de uma nova turma, voltar a confirmar patches Kubernetes, versão containerd, matriz Calico e requisitos do Traefik.
