# Sessão 4 — Kubernetes Admin I
## Instalação, Administração e Upgrade do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M7  
**Foco pedagógico:** **CONSTRUIR E EVOLUIR O CLUSTER**

Nesta sessão, cada formando constrói manualmente um cluster Kubernetes on-premises com duas VMs, começa na série **1.36.x** e termina com um **upgrade real para 1.37.x**.

O objetivo não é executar scripts de instalação. É compreender cada pré-condição, executar cada comando, observar o estado produzido, registar evidência e explicar o resultado.

## Topologia de referência

```text
                 k8s-cp-01                    k8s-wk-01
              Control Plane                    Worker
                  │                              │
                  └──────── cluster ─────────────┘

Ubuntu 26.04 LTS · containerd · Calico/Tigera Operator
Kubernetes inicial: 1.36.x
Kubernetes final:   1.37.x
Baseline ensaiada:  1.36.4 → 1.37.0
Pod CIDR: 192.168.0.0/16 · Service CIDR: 10.96.0.0/12
```

Cada formando utiliza **duas VMs**: uma para o Control Plane e outra para o Worker. Com até cinco formandos, a infraestrutura de sala pode exigir até dez VMs.

## Regra da sessão

```text
COMPREENDER
    ↓
EXECUTAR MANUALMENTE
    ↓
OBSERVAR
    ↓
REGISTAR EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

Os scripts usados pelo formador para ensaio e validação técnica **não fazem parte deste repositório de apoio ao formando**.

## Percurso

```text
pré-requisitos Linux
        ↓
containerd + CRI
        ↓
Kubernetes 1.36.x
        ↓
kubeadm init (APENAS k8s-cp-01)
        ↓
kubeconfig
        ↓
Control Plane NotReady antes do CNI
        ↓
Calico / Tigera Operator
        ↓
kubeadm join (APENAS k8s-wk-01)
        ↓
convergência Calico + CoreDNS
        ↓
cluster 1.36.x validado
        ↓
cordon / drain / uncordon
        ↓
upgrade Control Plane para 1.37.x
        ↓
upgrade Worker para 1.37.x
        ↓
cluster 1.37.x validado novamente
```

## Porque instalar 1.36 e atualizar para 1.37?

A Sessão 4 passa a mostrar o ciclo de vida real de um cluster:

```text
instalar → validar → operar → manter → atualizar → validar novamente
```

O upgrade deixa assim de ser apenas uma discussão teórica. O formando observa também o **version skew temporário** existente durante uma atualização controlada.

## Materiais

- [`plano_sessao_4.md`](plano_sessao_4.md) — objetivos, conteúdos, metodologia e distribuição temporal;
- [`manual_formando.md`](manual_formando.md) — explicação progressiva do percurso;
- [`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md) — laboratório manual completo;
- [`checklist.md`](checklist.md) — preparação das VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints manuais do laboratório;
- [`folha_evidencias.md`](folha_evidencias.md) — evidências a recolher;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico orientado por evidências;
- [`manifests/`](manifests/) — Pod usado na demonstração de `cordon`/`drain`;
- [`exercicios/`](exercicios/) — atividades, quiz e consolidação do upgrade;
- [`referencias.md`](referencias.md) — bibliografia e documentação oficial.

## Regras críticas

1. `kubeadm init` executa-se **apenas no `k8s-cp-01`**.
2. `kubeadm join` executa-se **apenas no `k8s-wk-01`**.
3. Não executar literalmente placeholders como `<TOKEN>`, `<HASH>`, `<PKG_1_37>` ou `...`.
4. A instalação inicial usa o repositório `pkgs.k8s.io` da série **1.36**; o upgrade exige mudar para a série **1.37**.
5. O Control Plane é atualizado antes do Worker.
6. Num upgrade minor do `kubelet`, o nó é drenado antes da atualização do `kubelet`.
7. Não usar `--force` num `drain` de upgrade como resposta automática.
8. Depois do upgrade, validar Nodes, CoreDNS e CNI novamente.
9. Não remover a taint `control-plane:NoSchedule` neste laboratório.
10. Antes do bootstrap, confirmar que não existe MicroK8s, k3s, Minikube ou outro Kubernetes residual.

## Nota importante sobre Calico

Calico 3.32 é oficialmente testado com Kubernetes 1.34–1.36. A combinação usada depois do upgrade para 1.37 deve ser **pré-validada pelo formador** ou substituída por uma release Calico que passe a declarar Kubernetes 1.37 como versão testada.

É importante distinguir:

```text
funcionou no nosso laboratório
            ≠
combinação oficialmente testada pelo fornecedor
```

## Resultado esperado

```text
NAME         STATUS   ROLES           VERSION
k8s-cp-01    Ready    control-plane   v1.37.x
k8s-wk-01    Ready    <none>          v1.37.x
```

No final, o formando deve conseguir explicar não apenas **que comandos executou**, mas **por que motivo foram necessários, como o cluster mudou de 1.36 para 1.37 e que evidência confirma que continua saudável**.
