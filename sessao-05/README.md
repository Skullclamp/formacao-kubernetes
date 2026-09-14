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
CNI:                    Calico 3.32.2

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
Base de dados do lab:   SQLite
Ficheiro SQLite:        /var/www/html/data/database.sqlite
Namespace lab:          sessao5
```

A baseline foi validada de ponta a ponta com 48 verificações obrigatórias: **48 OK, 0 avisos, 0 falhas**.

## Continuidade da topologia — preparação do formador

A Sessão 4 termina intencionalmente com:

```text
k8s-cp-01
+
k8s-wk-01
```

O segundo Worker, `k8s-wk-03 / 192.168.50.102`, é acrescentado pelo formador **antes da Sessão 5 e fora dos 240 minutos da aula**. O procedimento reutiliza o mesmo `kubeadm join` já praticado na Sessão 4; não é introduzido um segundo exercício de join apenas para preencher a topologia.

Antes de iniciar a Sessão 5, o formador valida obrigatoriamente:

```text
k8s-wk-03 Ready
Kubernetes 1.36.4
containerd 2.2.6
Calico operacional
```

A designação `k8s-wk-03` corresponde ao inventário real das VMs do laboratório. Não representa um checkpoint omitido e não implica que exista um `k8s-wk-02` que o formando devesse ter criado.

## Regra pedagógica

```text
COMPREENDER
    ↓
EXECUTAR MANUALMENTE
    ↓
OBSERVAR
    ↓
PROVOCAR / TESTAR
    ↓
REGISTAR EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

Cada `CPx` é um gate pedagógico: não se avança sem resultado esperado, evidência e interpretação. O molde comum das Sessões 4–8 está em [`../docs/padrao-laboratorios-kubernetes.md`](../docs/padrao-laboratorios-kubernetes.md).

## Percurso

```text
Deployment Symfony + reconciliação
        ↓
DaemonSet
        ↓
StatefulSet + identidade + Headless DNS
        ↓
PVC → StorageClass → provisioner → PV
        ↓
WaitForFirstConsumer + afinidade ao Node
        ↓
Symfony + SQLite persistente em PVC
        ↓
Service + DNS + EndpointSlice
        ↓
Ingress Traefik
        ↓
GatewayClass → Gateway → HTTPRoute
        ↓
Job + backup SQLite consistente
        ↓
CronJob
        ↓
backup fora do cluster
        ↓
perda de Pod
        ↓
persistência
        ↓
health gate antes da operação destrutiva
        ↓
eliminação lógica da PVC
        ↓
restore para nova PVC/PV
```

> Nesta sessão, SQLite é deliberadamente usado para concentrar a prática nos mecanismos Kubernetes de workload, storage, Service, entrada HTTP, backup e recuperação. A integração completa Symfony → PostgreSQL fica para uma sessão posterior.

## Laboratório único da sessão

Existe um único laboratório integrado:

[**Laboratório Integrado — Sessão 5**](labs/laboratorio_integrado_sessao_5.md)

O laboratório é manual e organizado por checkpoints com explicação, comandos, outputs, observação e evidência. Os manifests efetivamente usados pelo percurso atual, bem como os ficheiros históricos mantidos apenas como apoio, estão identificados em [`manifests/README.md`](manifests/README.md).

## Health gate obrigatório antes do CP17

Antes de eliminar a PVC da aplicação, confirmar que a situação saudável e o backup estão provados. Não avançar enquanto faltar qualquer uma destas evidências:

```text
Deployment Symfony saudável antes de ser escalado para 0
+
symfony-data Bound
+
backup-pvc Bound
+
Job de backup Complete
+
MARKER_BACKUP=persistencia-sessao5-ok
+
INTEGRITY_CHECK=ok
+
database-online.sqlite copiado para fora do cluster e não vazio
+
/health devolve HTTP 200
```

Esta regra impede atribuir ao exercício de perda lógica um problema que já existia antes da operação destrutiva. A checklist está também em [`folha_evidencias.md`](folha_evidencias.md).

## Nota sobre o Namespace

O Namespace `sessao5` é mantido porque este laboratório já foi validado de ponta a ponta com esse nome e vários FQDNs/evidências dependem dele. Para novos laboratórios, a convenção adotada é `s<sessão>-<slug>`, por exemplo `s6-governance`. A exceção da Sessão 5 está documentada no padrão comum e não deve ser reproduzida em novas sessões.

## Estrutura

```text
sessao-05/
├── README.md
├── manual_formando.md
├── folha_evidencias.md
├── labs/
│   └── laboratorio_integrado_sessao_5.md
└── manifests/
    ├── README.md
    ├── 01-daemonset-demo.yaml
    ├── 02-web-headless.yaml
    ├── 03-web-statefulset.yaml
    ├── 04-test-pvc.yaml
    ├── 05-test-pod.yaml
    ├── 10-symfony-service-broken.yaml
    ├── 11-symfony-ingress.yaml
    ├── 12-symfony-gateway.yaml
    ├── 13-symfony-httproute.yaml
    └── 17-backup-reader.yaml
```

A diretoria contém ainda manifests PostgreSQL de uma iteração anterior. Estes ficheiros estão assinalados no `manifests/README.md` como **apoio histórico / não usados no percurso atual** e não devem ser executados como parte dos checkpoints da versão SQLite do laboratório.

## Materiais

- [`manual_formando.md`](manual_formando.md) — explicação conceptual e operacional progressiva;
- [`labs/laboratorio_integrado_sessao_5.md`](labs/laboratorio_integrado_sessao_5.md) — laboratório manual completo;
- [`folha_evidencias.md`](folha_evidencias.md) — registo central dos checkpoints, health gate e evidência final;
- [`manifests/README.md`](manifests/README.md) — mapa dos manifests ativos e dos ficheiros históricos;
- [`manifests/`](manifests/) — manifests de apoio da sessão;
- [`../docs/padrao-laboratorios-kubernetes.md`](../docs/padrao-laboratorios-kubernetes.md) — molde canónico dos laboratórios Kubernetes.

## Regras críticas

1. Executar os comandos administrativos no `k8s-cp-01`.
2. Manter os Workers `k8s-wk-01` e `k8s-wk-03` `Ready`.
3. Não remover o taint `NoSchedule` do Control Plane apenas para “fazer caber” o laboratório.
4. StatefulSet não garante distribuição por Nodes nem alta disponibilidade.
5. `local-path-provisioner` é um external provisioner e não um driver CSI.
6. `WaitForFirstConsumer` pode manter uma PVC `Pending` até existir consumidor.
7. Um PV local fica dependente do Node selecionado.
8. `reclaimPolicy: Delete` é a configuração do laboratório, não uma recomendação universal de produção.
9. O Deployment Symfony criado no início é substituído no CP9 pela variante persistente com SQLite e mantém-se até aos testes de Service, Ingress e Gateway.
10. A integração completa Symfony → PostgreSQL fica para uma sessão posterior; os manifests PostgreSQL históricos desta diretoria não fazem parte do percurso atual.
11. GatewayClass `traefik` é pré-instalada; o formando cria apenas Gateway + HTTPRoute.
12. O listener HTTP do Gateway usa `8000`; o acesso externo usa NodePort `30080`.
13. O backup deve ser retirado do cluster antes da eliminação controlada da PVC.
14. Não iniciar o CP17 sem validar o health gate documentado nesta sessão.
15. O cenário de eliminação da PVC é “perda lógica dos dados”, não simulação de perda física do Worker.
16. **Persistência ≠ Backup.**

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
health gate
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
