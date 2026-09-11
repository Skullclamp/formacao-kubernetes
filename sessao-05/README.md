# Sessão 5 — Kubernetes Admin II
## Workloads, Networking, Storage, Backup e Recuperação

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M8  
**Foco pedagógico:** **ADMINISTRAR WORKLOADS, REDE E DADOS**

A Sessão 5 parte do cluster Kubernetes 1.36.4 construído e atualizado na Sessão 4 e passa a trabalhar os principais mecanismos de operação dentro do cluster.

## Baseline validada

```text
Control Plane:          k8s-cp-01 / 192.168.50.46
Worker 1:               k8s-wk-01 / 192.168.50.65
Worker 2:               k8s-wk-03 / 192.168.50.102

Ubuntu:                 26.04.1 LTS
Kubernetes:             1.36.4
containerd:             2.2.6
CNI:                    Calico

StorageClass:           local-path
Provisioner:            rancher.io/local-path
volumeBindingMode:      WaitForFirstConsumer
reclaimPolicy:          Delete

Gateway API:            v1.6.1
Traefik Chart:          41.5.0
Traefik Proxy:          v3.7.13
IngressClass:           traefik
GatewayClass:           traefik
HTTP:                   80 → NodePort 30080
HTTPS:                  443 → NodePort 30443
Gateway listener HTTP:  8000

Symfony Demo:           v3.1.0
Imagem:                 ghcr.io/skullclamp/symfony-demo:1.1.0
PostgreSQL:             16
```

A baseline foi validada de ponta a ponta com 48 verificações obrigatórias: **48 OK, 0 avisos, 0 falhas**.

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
Deployment + reconciliação
        ↓
DaemonSet
        ↓
StatefulSet + identidade + Headless DNS
        ↓
PVC → StorageClass → provisioner → PV
        ↓
WaitForFirstConsumer + afinidade ao Node
        ↓
PostgreSQL StatefulSet
        ↓
Service + DNS + EndpointSlice
        ↓
Ingress Traefik
        ↓
GatewayClass → Gateway → HTTPRoute
        ↓
Job + pg_dump
        ↓
CronJob
        ↓
backup fora do cluster
        ↓
perda de Pod
        ↓
persistência
        ↓
eliminação da PVC
        ↓
restore
```

## Laboratório único da sessão

Tal como na Sessão 4, o formando segue um único percurso integrado:

[**Laboratório Integrado — Sessão 5**](formando/labs/laboratorio_integrado_sessao_5.md)

O laboratório é manual e organizado por checkpoints com explicação, comandos, outputs, observação e evidência. Os manifests usados nos checkpoints estão em [`manifests/`](manifests/).

## Materiais

- [`manual_formando.md`](manual_formando.md) — explicação conceptual e operacional progressiva;
- [`formando/labs/laboratorio_integrado_sessao_5.md`](formando/labs/laboratorio_integrado_sessao_5.md) — laboratório manual completo;
- [`labs/`](labs/) — pontos de entrada/compatibilidade do laboratório;
- [`manifests/`](manifests/) — 17 manifests usados no laboratório;
- [`formador/preparar_infra_sessao5.md`](formador/preparar_infra_sessao5.md) — preparação da infraestrutura antes da formação;
- [`formador/validar_lab_sessao5.sh`](formador/validar_lab_sessao5.sh) — validador técnico do ambiente, reservado ao formador.

## Regras críticas

1. Executar os comandos administrativos no `k8s-cp-01`.
2. Manter os Workers `k8s-wk-01` e `k8s-wk-03` `Ready`.
3. Não remover o taint `NoSchedule` do Control Plane apenas para “fazer caber” o laboratório.
4. StatefulSet não garante distribuição por Nodes nem alta disponibilidade.
5. `local-path-provisioner` é um external provisioner e não um driver CSI.
6. `WaitForFirstConsumer` pode manter uma PVC `Pending` até existir consumidor.
7. Um PV local fica dependente do Node selecionado.
8. `reclaimPolicy: Delete` é a configuração do laboratório, não uma recomendação universal de produção.
9. O Deployment Symfony criado no início mantém-se até aos testes de Service, Ingress e Gateway.
10. A integração completa Symfony → PostgreSQL fica para a Sessão 9.
11. GatewayClass `traefik` é pré-instalada; o formando cria apenas Gateway + HTTPRoute.
12. O listener HTTP do Gateway usa `8000`; o acesso externo usa NodePort `30080`.
13. O backup deve ser retirado do cluster antes da eliminação controlada da PVC.
14. O cenário de eliminação da PVC é “perda lógica dos dados”, não simulação de perda física do Worker.
15. **Persistência ≠ Backup.**

## Resultado esperado

No final, o formando deve conseguir demonstrar:

```text
workload correto
+
estado observado
+
storage persistente
+
DNS e Service
+
entrada HTTP
+
backup
+
falha controlada
+
restore
```

e explicar por que:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```
