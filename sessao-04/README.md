# Sessão 4 — Kubernetes Admin I
## Instalação e Administração do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M7  
**Foco pedagógico:** **CONSTRUIR O CLUSTER**

Nesta sessão, cada formando constrói manualmente um cluster Kubernetes on-premises com duas VMs. O objetivo não é executar scripts de instalação: é compreender cada pré-condição, executar cada comando, observar o estado produzido e interpretar a evidência.

## Topologia de referência

```text
                 k8s-cp-01                    k8s-wk-01
              Control Plane                    Worker
                  │                              │
                  └──────── cluster ─────────────┘

Ubuntu 26.04 LTS · Kubernetes 1.37 · containerd · Calico/Tigera Operator
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
kubelet + kubeadm + kubectl
        ↓
kubeadm init (APENAS k8s-cp-01)
        ↓
kubeconfig
        ↓
Control Plane NotReady antes do CNI
        ↓
Calico / Tigera Operator
        ↓
Control Plane Ready
        ↓
kubeadm join (APENAS k8s-wk-01)
        ↓
Worker Ready
        ↓
convergência Calico + CoreDNS
        ↓
cordon / drain / uncordon
        ↓
validação final
```

## Materiais

- [`plano_sessao_4.md`](plano_sessao_4.md) — objetivos, conteúdos, metodologia e distribuição temporal;
- [`manual_formando.md`](manual_formando.md) — explicação progressiva dos conceitos e procedimentos;
- [`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md) — laboratório manual completo;
- [`checklist.md`](checklist.md) — preparação manual das duas VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints CP1–CP8;
- [`folha_evidencias.md`](folha_evidencias.md) — evidências a recolher durante o laboratório;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida de comandos;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico orientado por evidências;
- [`manifests/`](manifests/) — manifest usado na manutenção do Worker;
- [`exercicios/`](exercicios/) — atividade, quiz e aprofundamento de upgrades;
- [`referencias.md`](referencias.md) — fontes bibliográficas e documentação oficial.

## Regras críticas

1. `kubeadm init` executa-se **apenas no `k8s-cp-01`**.
2. `kubeadm join` executa-se **apenas no `k8s-wk-01`**.
3. Não executar literalmente placeholders como `<TOKEN>`, `<HASH>`, `VALOR_REAL` ou `...`.
4. Não remover a taint `control-plane:NoSchedule` neste laboratório.
5. Depois do `join`, dar tempo ao Calico/Tigera e CoreDNS para convergirem antes de diagnosticar uma falha.
6. Antes do bootstrap, confirmar que não existe MicroK8s, k3s, Minikube ou outro cluster Kubernetes residual.
7. Não usar `--ignore-preflight-errors` para esconder um problema que ainda não foi compreendido.

## Resultado esperado

```text
NAME         STATUS   ROLES
k8s-cp-01    Ready    control-plane
k8s-wk-01    Ready    <none>
```

No final, o formando deve conseguir explicar não apenas **que comandos executou**, mas **porque foram necessários e que evidência confirma que funcionaram**.
