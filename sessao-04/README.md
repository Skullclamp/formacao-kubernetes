# Sessão 4 — Kubernetes Admin I
## Instalação, Administração e Upgrade do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M7  
**Foco pedagógico:** **CONSTRUIR E EVOLUIR O CLUSTER**

Nesta sessão, cada formando constrói manualmente um cluster Kubernetes on-premises com duas VMs, começa em **Kubernetes 1.35.8** e termina com um **upgrade real para 1.36.4**.

O percurso desta edição foi validado de ponta a ponta em laboratório.

## Baseline validada

```text
Control Plane:       k8s-cp-01 / 192.168.50.46
Worker:              k8s-wk-01 / 192.168.50.65
Ubuntu:              26.04.1 LTS
Kernel:              7.0.0-31-generic
Kubernetes inicial:  1.35.8
Kubernetes final:    1.36.4
containerd:          2.2.6
runc:                1.3.6
Calico:              3.32.2
Tigera Operator:     1.42.6
Pod CIDR:            10.244.0.0/16
Service CIDR:        10.96.0.0/12
Filesystem /:        40 GB no ambiente validado
```

O Pod CIDR `10.244.0.0/16` foi escolhido para não sobrepor a rede física `192.168.50.0/24` usada pelos hosts do laboratório.

Os patches devem ser reconfirmados antes de cada nova edição da formação. A baseline acima representa a combinação efetivamente ensaiada nesta edição.

## Porque 1.35 → 1.36?

Esta combinação permite ensinar um upgrade minor real mantendo o CNI dentro da matriz de testes adotada para Calico 3.32. Consulta [`compatibilidade.md`](compatibilidade.md).

Traefik não é instalado na Sessão 4. É usado posteriormente para Ingress/Gateway.

## Regra pedagógica

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

## Percurso

```text
pré-requisitos Linux + validação do disco
        ↓
containerd 2.2.6 + runc 1.3.6 + CRI
        ↓
Kubernetes 1.35.8 — versão explicitamente fixada
        ↓
kubeadm init — APENAS k8s-cp-01
        ↓
kubeconfig
        ↓
Calico 3.32.2 / Tigera Operator 1.42.6
        ↓
kubeadm token create — APENAS k8s-cp-01
        ↓
kubeadm join — APENAS k8s-wk-01
        ↓
cluster 1.35.8 validado
        ↓
cordon / drain / uncordon
        ↓
health gate + snapshot coordenado
        ↓
upgrade Control Plane para 1.36.4
        ↓
upgrade Worker para 1.36.4
        ↓
cluster 1.36.4 validado novamente
```

## Laboratório único da sessão

A Sessão 4 utiliza um único laboratório integrado:

[**Laboratório Integrado — da VM Ubuntu limpa ao cluster Kubernetes 1.36.4 atualizado**](labs/laboratorio_integrado_sessao_4.md)

O laboratório concentra-se no percurso prático, nos outputs essenciais, nos checkpoints e nas evidências. As explicações detalhadas dos conceitos, argumentos, flags e decisões ficam no manual do formando.

## Materiais

- [`plano_sessao_4.md`](plano_sessao_4.md) — plano pedagógico;
- [`manual_formando.md`](manual_formando.md) — explicação progressiva e consolidação;
- [`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md) — laboratório único da sessão;
- [`compatibilidade.md`](compatibilidade.md) — matriz de versões adotada;
- [`checklist.md`](checklist.md) — preparação das VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints manuais;
- [`folha_evidencias.md`](folha_evidencias.md) — evidências a recolher;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico orientado por evidências;
- [`manifests/`](manifests/) — manifests usados no laboratório;
- [`referencias.md`](referencias.md) — documentação e bibliografia.

## Regras críticas

1. Antes de `init`, `token create` ou `join`, executar `hostname` e confirmar em que VM estamos.
2. `kubeadm init`, `kubeadm token create` e os comandos administrativos `kubectl` executam-se no `k8s-cp-01`.
3. `kubeadm join` e `kubeadm upgrade node` executam-se no `k8s-wk-01`.
4. Não copiar `/etc/kubernetes/admin.conf` para o Worker apenas para executar comandos administrativos.
5. A instalação inicial fixa explicitamente Kubernetes `1.35.8`; não usar instalação APT sem versão neste laboratório.
6. O Pod CIDR é `10.244.0.0/16`; não usar `192.168.0.0/16` nesta topologia porque sobrepõe a rede física do laboratório.
7. Validar o espaço útil de `/`; um disco virtual grande não garante que o LV/filesystem raiz tenha espaço suficiente.
8. Se surgir `DiskPressure`, parar e diagnosticar antes de continuar.
9. O upgrade é `1.35.8 → 1.36.4`; não se saltam versões minor.
10. Antes do upgrade, validar o cluster e criar snapshots coordenados das duas VMs.
11. O Control Plane é atualizado antes do Worker.
12. Antes de atualizar um kubelet entre minors, drenar o respetivo nó.
13. Não acrescentar `--force`, `--ignore-preflight-errors` ou desativar AppArmor como resposta automática a um erro.
14. Depois do upgrade, voltar a validar Nodes, CoreDNS, Calico, runtime e journals relevantes.

## Resultado esperado

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

E:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```
