# Matriz de Compatibilidade — Sessão 4

**Data de referência:** 10/09/2026

A baseline desta sessão foi escolhida para que a instalação e o upgrade utilizem combinações explicitamente suportadas ou testadas pelos projetos envolvidos e, sobretudo, uma combinação **validada de ponta a ponta no ambiente real da formação**.

| Componente | Versão adotada | Kubernetes 1.35 | Kubernetes 1.36 | Observação |
|---|---:|:---:|:---:|---|
| Kubernetes | **1.35.8 → 1.36.4** | — | — | percurso de upgrade validado nesta edição |
| containerd | **2.2.6** | sim | sim | versão utilizada e validada nas duas fases do laboratório |
| Calico | **3.32.2** | testado oficialmente | testado oficialmente | Calico 3.32 testa Kubernetes 1.34, 1.35 e 1.36 |
| Tigera Operator | **1.42.6** | sim | sim | versão do Operator utilizada com Calico 3.32.2 |
| CoreDNS | gerido por kubeadm | sim | sim | não é fixado manualmente nesta sessão; kubeadm gere o add-on no ciclo de upgrade |
| kube-proxy | gerido por kubeadm | sim | sim | não é fixado manualmente; kubeadm atualiza a configuração/add-on durante o upgrade |
| Traefik | 3.7.x, sessão posterior | sim | sim | não é instalado na Sessão 4; a compatibilidade é validada antes da sessão em que Ingress/Gateway é utilizado |

## Baseline oficial desta edição

O percurso técnico de referência é:

```text
Kubernetes 1.35.8
        ↓
containerd 2.2.6
Calico 3.32.2
Tigera Operator 1.42.6
        ↓
upgrade suportado por kubeadm
        ↓
Kubernetes 1.36.4
        ↓
mesmo runtime e CNI validados
```

Esta escolha permite demonstrar um upgrade minor real com uma baseline conservadora, reproduzível e já ensaiada no laboratório da formação.

## Regra para novas edições

Antes de cada nova turma, o formador deve voltar a confirmar:

1. disponibilidade dos patches `1.35.8` e `1.36.4`, ou definir novos patches apenas depois de revalidar o laboratório;
2. matriz Kubernetes/containerd;
3. matriz Kubernetes/Calico;
4. versão do Tigera Operator incluída na release Calico escolhida;
5. requisitos do Traefik antes da sessão em que o Ingress/Gateway for instalado;
6. execução completa do percurso de instalação, join, manutenção e upgrade no ambiente de referência.

Uma nova versão não deve ser adotada apenas por ser mais recente: a baseline da formação só muda depois de existir **compatibilidade confirmada + execução prática validada + atualização coerente do plano, manual, laboratório e recursos de apoio**.

## Fontes oficiais

- Kubernetes — Releases e patch releases;
- Kubernetes v1.36 — Upgrading kubeadm clusters from 1.35.x to 1.36.x;
- Calico — System requirements;
- Calico — Component versions;
- containerd — Kubernetes support matrix;
- Traefik — Kubernetes requirements.
