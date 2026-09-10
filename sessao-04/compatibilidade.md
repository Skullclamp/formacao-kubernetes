# Matriz de Compatibilidade — Sessão 4

**Data de referência:** 10/09/2026

A baseline desta sessão foi escolhida para que a instalação e o upgrade utilizem combinações explicitamente suportadas ou testadas pelos projetos envolvidos.

| Componente | Versão adotada | Kubernetes 1.35 | Kubernetes 1.36 | Observação |
|---|---:|:---:|:---:|---|
| Kubernetes | 1.35.8 → 1.36.4 | — | — | ambas são releases suportadas à data desta edição |
| containerd | 2.2.x | recomendado | recomendado | série comum recomendada para as duas versões de Kubernetes |
| Calico | 3.32.2 | testado oficialmente | testado oficialmente | Calico 3.32 testa Kubernetes 1.34, 1.35 e 1.36 |
| Tigera Operator | 1.42.6 | sim | sim | versão do Operator indicada para Calico 3.32.2 |
| CoreDNS | gerido por kubeadm | sim | sim | não é fixado manualmente nesta sessão; kubeadm gere o add-on no ciclo de upgrade |
| kube-proxy | gerido por kubeadm | sim | sim | não é fixado manualmente; kubeadm atualiza a configuração/add-on durante o upgrade |
| Traefik | 3.7.x, sessão posterior | sim | sim | não é instalado na Sessão 4; Traefik suporta pelo menos as três minors Kubernetes mais recentes |

## Porque não terminar em Kubernetes 1.37 nesta edição?

Kubernetes 1.37 está suportado, mas o Calico 3.32 é oficialmente testado apenas com Kubernetes 1.34–1.36. Como queremos que o laboratório de formação tenha uma baseline conservadora e reproduzível, usamos:

```text
Kubernetes 1.35.8
        ↓
upgrade suportado
        ↓
Kubernetes 1.36.4
```

Isto permite demonstrar um upgrade minor real sem sair da matriz oficial de testes do Calico 3.32.

## Regra para novas edições

Antes de cada nova turma, o formador deve voltar a confirmar:

1. patch mais recente disponível na série 1.35;
2. patch mais recente disponível na série 1.36;
3. matriz Kubernetes/containerd;
4. matriz Kubernetes/Calico;
5. versão do Tigera Operator incluída na release Calico escolhida;
6. requisitos do Traefik antes da sessão em que o Ingress/Gateway for instalado.

## Fontes oficiais

- Kubernetes — Releases e patch releases;
- Kubernetes v1.36 — Upgrading kubeadm clusters from 1.35.x to 1.36.x;
- Calico — System requirements;
- Calico — Component versions;
- containerd — Kubernetes support matrix;
- Traefik — Kubernetes requirements.
