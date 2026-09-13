# A) Plano de Formação — Sessão 4
## Kubernetes Admin I — Instalação, Administração e Upgrade do Cluster

| Elemento | Definição |
|---|---|
| Duração | 4 horas / 240 minutos |
| Nível | Intermédio |
| Formandos | máximo 5 |
| Topologia | 2 VMs por formando |
| Control Plane | `k8s-cp-01` |
| Worker | `k8s-wk-01` |
| SO | Ubuntu 26.04.1 LTS |
| Kubernetes inicial | **1.35.8** — série 1.35.x |
| Kubernetes final | **1.36.4** — série 1.36.x |
| Runtime | **containerd 2.2.6** |
| CNI | Calico 3.32.2 |
| Operator | Tigera Operator 1.42.6 |
| Pod CIDR | **10.244.0.0/16** |
| Service CIDR | 10.96.0.0/12 |

> **Baseline técnica validada:** Kubernetes `1.35.8 → 1.36.4`, `containerd 2.2.6`, Calico `3.32.2` e Tigera Operator `1.42.6`. Antes de cada nova edição, os patches devem ser reconfirmados; uma alteração de versão só deve ser feita depois de revalidar o laboratório de ponta a ponta.

---

# 1. Objetivos específicos

No final da sessão, o formando deverá conseguir:

1. rever o modelo Control Plane/Worker e os principais componentes Kubernetes;
2. interpretar a estrutura dos comandos `kubectl` e flags mais utilizadas;
3. preparar Ubuntu para Kubernetes;
4. configurar `containerd` com CRI e `SystemdCgroup = true`;
5. instalar explicitamente Kubernetes `1.35.8`, evitando seleção acidental de outra minor ou patch não validado;
6. inicializar o Control Plane com `kubeadm init` numa versão explicitamente definida;
7. configurar e interpretar `kubeconfig` e contextos;
8. instalar Calico 3.32.2 através do Tigera Operator;
9. gerar o comando de join no Control Plane e integrar o Worker;
10. validar Nodes, CoreDNS, CNI e API;
11. aplicar `cordon`, `drain` e `uncordon`;
12. preparar um ponto de recuperação antes do upgrade;
13. executar um upgrade real Kubernetes `1.35.8 → 1.36.4`;
14. compreender o version skew temporário durante a atualização;
15. diagnosticar erros com base em evidências.

---

# 2. Decisão de compatibilidade e baseline oficial

A baseline oficial desta edição é o percurso **Kubernetes `1.35.8 → 1.36.4`**, escolhido por compatibilidade, reprodutibilidade e por ter sido validado de ponta a ponta no ambiente real da formação.

```text
Kubernetes 1.35.8
        ↓
Calico 3.32.2 validado
containerd 2.2.6 validado
        ↓
upgrade suportado por kubeadm
        ↓
Kubernetes 1.36.4
        ↓
Calico 3.32.2 continua na matriz validada
containerd 2.2.6 mantém-se
```

Traefik não é instalado nesta sessão; a compatibilidade é registada para as sessões posteriores de Ingress/Gateway.

Consultar [`compatibilidade.md`](compatibilidade.md).

---

# 3. Metodologia

A sessão mantém uma abordagem aproximadamente **40% explicação/demonstração e 60% prática**.

Percurso pedagógico:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO MANUAL
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
EVIDÊNCIA
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

Não existe script de instalação para o formando.

O formador alterna entre:

- explicação curta;
- demonstração controlada;
- execução individual nas duas VMs;
- observação do estado;
- recolha de evidências;
- perguntas de interpretação;
- troubleshooting orientado.

---

# 4. Conteúdos

## 4.1. Refresh Kubernetes

- orquestração e estado desejado;
- API Server, etcd, scheduler e controllers;
- kubelet, runtime, CNI e Pods;
- diferença entre `kubeadm`, `kubelet` e `kubectl`;
- estrutura `kubectl <verbo> <recurso> [flags]`;
- flags `-n`, `-A`, `-o wide`, `-o yaml`, `-w`, `--help`.

## 4.2. Preparação Linux

- hostnames e resolução;
- memória e CPU;
- swap como escolha do laboratório;
- módulos `overlay` e `br_netfilter`;
- `ip_forward` e bridge netfilter;
- cgroup v2;
- deteção de MicroK8s/k3s/Minikube ou cluster anterior;
- inspeção de repositórios Kubernetes residuais.

## 4.3. containerd 2.2.6

- cadeia `kubelet → CRI → containerd → runc → kernel`;
- instalação da baseline `2.2.6`;
- CRI ativo;
- `SystemdCgroup = true`;
- validação da configuração efetiva.

## 4.4. Kubernetes 1.35.8

- repositório `pkgs.k8s.io` da série 1.35;
- `apt-cache madison`;
- instalação do patch `1.35.8` com versão de pacote explícita;
- `apt-mark hold`;
- verificação antes do bootstrap.

## 4.5. Bootstrap do Control Plane

- guarda de papel com `hostname`;
- `kubeadm init --kubernetes-version=v1.35.8`;
- Pod CIDR `10.244.0.0/16`;
- kubeconfig;
- observação do `NotReady` antes do CNI.

## 4.6. CNI

- Calico 3.32.2;
- Tigera Operator 1.42.6;
- CRDs e Custom Resources;
- namespaces `tigera-operator` e `calico-system`;
- taint do Control Plane;
- convergência da rede de Pods.

## 4.7. Integração do Worker

- `kubeadm token create --print-join-command` **só no Control Plane**;
- `--kubeconfig /etc/kubernetes/admin.conf` explícito;
- `kubeadm join` **só no Worker**;
- não distribuir `admin.conf` ao Worker;
- validação dos dois Nodes.

## 4.8. Administração

- kubeconfig e contextos;
- `cordon`;
- `drain`;
- comportamento de Pod sem controller;
- uso deliberado de `--force` apenas no exercício;
- `uncordon`.

## 4.9. Recuperação e upgrade 1.35.8 → 1.36.4

- validar cluster antes de atualizar;
- snapshots `pre-upgrade-1.35.8`;
- mudança do repositório para a série 1.36;
- upgrade de `kubeadm` para `1.36.4`;
- `kubeadm upgrade plan`;
- `kubeadm upgrade apply v1.36.4` no Control Plane;
- drain antes do upgrade minor do kubelet;
- atualização de kubelet/kubectl;
- `kubeadm upgrade node` no Worker;
- version skew temporário;
- validação final de Nodes, CoreDNS, kube-proxy e Calico.

---

# 5. Distribuição do tempo

| Tempo | Conteúdo / atividade | Tipo |
|---:|---|---|
| 10 min | Refresh Kubernetes | síntese visual |
| 10 min | Topologia, papéis e compatibilidade | conceito |
| 20 min | Pré-requisitos Linux | prática |
| 15 min | containerd 2.2.6 / CRI / cgroups | prática guiada |
| 15 min | Instalação Kubernetes 1.35.8 com versão fixada | prática |
| 15 min | **Intervalo** | — |
| 25 min | `kubeadm init` + kubeconfig + observação | prática |
| 20 min | Calico/Tigera Operator | prática |
| 20 min | token no CP + join do Worker + convergência | prática |
| 15 min | `cordon` / `drain` / `uncordon` | prática |
| 55 min | snapshot + upgrade 1.35.8 → 1.36.4 | prática orientada |
| 20 min | validação final + troubleshooting + síntese | consolidação |
| **240 min** | **Total** | |

---

# 6. Atividades práticas

## Atividade 1 — ordem da construção

Os formandos ordenam:

```text
Linux → runtime → ferramentas Kubernetes → init → CNI → token → join → validação
```

## Atividade 2 — identificar o nó correto

O formador apresenta comandos e os formandos indicam:

```text
Control Plane / Worker / qualquer nó
```

Exemplo crítico:

```bash
kubeadm token create --print-join-command
```

Resposta: **Control Plane**.

## Atividade 3 — evidência de versão

Antes do `init`, cada formando deve demonstrar:

```text
containerd 2.2.6
kubeadm 1.35.8
kubelet 1.35.8
kubectl 1.35.8
```

## Atividade 4 — manutenção

Pod direto → `cordon` → `drain` → interpretar recusa → decisão explícita → `uncordon`.

## Atividade 5 — upgrade

Cada formando executa:

```text
cluster 1.35.8 saudável
→ snapshot
→ Control Plane 1.36.4
→ observar version skew
→ Worker 1.36.4
→ validação final
```

---

# 7. Adaptação a até 5 formandos

Cada formando trabalha com um par de VMs próprio. O formador mantém um ambiente de referência previamente validado.

Durante operações sensíveis, a turma avança por checkpoints comuns:

```text
CP1 Linux
CP2 runtime 2.2.6
CP3 Kubernetes 1.35.8
CP4 Control Plane
CP5 CNI
CP6 Worker
CP7 manutenção
CP8 snapshot
CP9 upgrade Control Plane 1.36.4
CP10 upgrade Worker 1.36.4
CP11 final
```

Se um formando ficar bloqueado durante demasiado tempo, recolhe evidência antes de repor snapshot ou usar o ambiente de contingência.

---

# 8. Avaliação formativa

O formando demonstra competência quando consegue:

- distinguir claramente Control Plane e Worker;
- justificar a escolha `1.35.8 → 1.36.4`;
- provar que instalou a versão pretendida;
- explicar CRI/CNI;
- gerar o join no nó correto;
- interpretar `NotReady`, `Pending` e Events;
- explicar `cordon` vs `drain`;
- descrever a estratégia de recuperação;
- executar a sequência de upgrade na ordem correta;
- validar o cluster final.

---

# 9. Resultado esperado

```text
k8s-cp-01   Ready   control-plane   v1.36.4
k8s-wk-01   Ready   <none>          v1.36.4
```

Calico/Tigera e CoreDNS devem estar saudáveis e o Worker novamente schedulable.
