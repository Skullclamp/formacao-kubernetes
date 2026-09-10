# Sessão 4 — Kubernetes Admin I
## Instalação, Administração e Upgrade do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M7  
**Foco pedagógico:** **CONSTRUIR E EVOLUIR O CLUSTER**

Nesta sessão, cada formando constrói manualmente um cluster Kubernetes on-premises com duas VMs, começa em **Kubernetes 1.35.x** e termina com um **upgrade real para 1.36.x**.

## Baseline da edição

```text
Control Plane:       k8s-cp-01
Worker:              k8s-wk-01
Ubuntu:              26.04 LTS
Kubernetes inicial:  1.35.8
Kubernetes final:    1.36.4
containerd:          2.2.x
Calico:              3.32.2
Tigera Operator:     1.42.6
Pod CIDR:            192.168.0.0/16
Service CIDR:        10.96.0.0/12
```

Os patches devem ser reconfirmados antes de cada nova edição da formação. O objetivo é manter o percurso `1.35.x → 1.36.x` e não depender de um patch antigo.

## Porque 1.35 → 1.36?

Esta combinação foi escolhida porque permite ensinar um upgrade minor real usando versões atualmente suportadas e, ao mesmo tempo, manter o CNI dentro da matriz oficial de testes do Calico 3.32. Consulta [`compatibilidade.md`](compatibilidade.md).

Traefik não é instalado na Sessão 4. É usado posteriormente para Ingress/Gateway; a sua política atual cobre pelo menos as três versões minor mais recentes de Kubernetes, incluindo 1.35 e 1.36 à data desta edição.

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

Não existe um script de instalação para o formando.

## Percurso

```text
pré-requisitos Linux
        ↓
containerd 2.2.x + CRI
        ↓
Kubernetes 1.35.x — versão explicitamente fixada
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
cluster 1.35.x validado
        ↓
cordon / drain / uncordon
        ↓
snapshot pre-upgrade-1.35
        ↓
upgrade Control Plane para 1.36.x
        ↓
upgrade Worker para 1.36.x
        ↓
cluster 1.36.x validado novamente
```

## Materiais

- [`plano_sessao_4.md`](plano_sessao_4.md) — plano pedagógico;
- [`manual_formando.md`](manual_formando.md) — explicação progressiva;
- [`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md) — laboratório manual completo;
- [`compatibilidade.md`](compatibilidade.md) — matriz de versões adotada;
- [`checklist.md`](checklist.md) — preparação das VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints manuais;
- [`folha_evidencias.md`](folha_evidencias.md) — evidências a recolher;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico orientado por evidências;
- [`manifests/`](manifests/) — Pod de teste para `cordon`/`drain`;
- [`exercicios/`](exercicios/) — atividades, quiz e consolidação do upgrade;
- [`referencias.md`](referencias.md) — documentação e bibliografia.

## Regras críticas

1. Antes de `init`, `token create` ou `join`, executar `hostname` e confirmar em que VM estamos.
2. `kubeadm init` e `kubeadm token create --print-join-command` executam-se **apenas no `k8s-cp-01`**.
3. `kubeadm join` executa-se **apenas no `k8s-wk-01`**.
4. Não copiar `/etc/kubernetes/admin.conf` para o Worker apenas para executar comandos administrativos.
5. Antes da instalação, verificar repositórios Kubernetes residuais e versões já instaladas.
6. A instalação inicial fixa explicitamente a versão 1.35.x; não usar instalação APT sem versão neste laboratório.
7. Se a VM já tiver Kubernetes 1.37 de um ensaio anterior, repor uma VM/snapshot limpo em vez de ensinar um downgrade improvisado.
8. O upgrade é `1.35.x → 1.36.x`; não se saltam versões minor.
9. Antes do upgrade, validar o cluster e criar o snapshot `pre-upgrade-1.35` das duas VMs.
10. Depois do upgrade, voltar a validar Nodes, CoreDNS e Calico.

## Resultado esperado

```text
NAME         STATUS   ROLES           VERSION
k8s-cp-01    Ready    control-plane   v1.36.x
k8s-wk-01    Ready    <none>          v1.36.x
```
