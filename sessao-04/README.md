# Sessão 4 — Kubernetes Admin I
## Instalação e Administração do Cluster

**Foco pedagógico:** **CONSTRUIR O CLUSTER**

Nesta sessão construímos um cluster Kubernetes on-premises com `kubeadm`, configuramos o runtime, instalamos a rede de Pods com Calico/Tigera Operator, adicionamos um Worker e praticamos operações básicas de administração e manutenção.

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

> Os recursos dependentes de versão devem ser novamente validados antes de cada edição da formação, em particular a combinação Kubernetes/Calico.

## Percurso da sessão

```text
pré-requisitos Linux
        ↓
containerd / CRI
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
cordon / drain / uncordon
        ↓
kubeadm upgrade plan
```

## Por onde começar

1. Leia o [`manual_formando.md`](manual_formando.md).
2. Valide o posto com [`checklist.md`](checklist.md).
3. Siga o [`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md).
4. Registe os checkpoints na [`folha_evidencias.md`](folha_evidencias.md).
5. Utilize o [`cheat_sheet.md`](cheat_sheet.md) apenas como referência rápida.
6. Em caso de erro, consulte [`troubleshooting.md`](troubleshooting.md) antes de repetir comandos.

## Estrutura

```text
sessao-04/
├── README.md
├── manual_formando.md
├── checklist.md
├── folha_evidencias.md
├── cheat_sheet.md
├── troubleshooting.md
├── labs/
│   ├── README.md
│   └── laboratorio_integrado_sessao_4.md
├── scripts/
│   ├── README.md
│   ├── preflight_check.sh
│   ├── verify_cluster.sh
│   └── fetch_calico_operator.sh
├── manifests/
│   ├── README.md
│   └── pod_cordon_test.yaml
└── exercicios/
    ├── README.md
    ├── atividade_ordem_instalacao.md
    ├── quiz_formativo.md
    └── upgrade_complementar.md
```

## Regra pedagógica

Os scripts são **auxiliares de validação e automação**. Não substituem a execução e interpretação manual dos passos principais.

```text
executar
   ↓
observar
   ↓
recolher evidência
   ↓
interpretar
   ↓
só depois corrigir/automatizar
```

## Segurança

Nunca faça commit de:

- `/etc/kubernetes/admin.conf`;
- ficheiros `kubeconfig` reais;
- tokens de `kubeadm join`;
- chaves privadas;
- passwords ou `.env` reais;
- outputs que contenham credenciais.

## Continuidade

No final da Sessão 4 teremos um cluster de dois nós funcional, com CNI ativo e acesso administrativo configurado. A Sessão 5 passa a trabalhar **Workloads, Networking, Storage e Recuperação**.
