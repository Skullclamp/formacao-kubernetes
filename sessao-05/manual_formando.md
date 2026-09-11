# Manual do Formando
## Sessão 5 — Kubernetes Admin II: Workloads, Networking, Storage, Backup e Recuperação

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 5 de 10 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Módulo** | M8 |
| **Foco pedagógico** | Administrar workloads, networking, storage e recuperação no cluster |
| **Topologia** | 1 Control Plane + 2 Workers |
| **Ambiente validado** | Ubuntu 26.04.1 LTS on-premises |
| **Kubernetes** | 1.36.4 |
| **Laboratório** | `formando/labs/laboratorio_integrado_sessao_5.md` |
| **Mensagem central** | **Persistência ≠ Backup** |

---

# 1. Como utilizar este manual

Este manual foi concebido para funcionar como **guia de acompanhamento, estudo autónomo e consulta futura**. Não substitui o laboratório integrado e não deve ser lido como uma lista de comandos a memorizar.

Tal como na Sessão 4, cada conceito importante é trabalhado segundo uma sequência coerente:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
OBJETO / MANIFESTO / COMANDO
   ↓
CAMPOS / FLAGS
   ↓
ESTADO ESPERADO
   ↓
O QUE OBSERVAR
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

No laboratório, a regra mantém-se:

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

O objetivo é conseguir responder a três perguntas em cada exercício:

1. **Qual era o estado antes da alteração?**
2. **Que objeto ou controlador provocou a alteração?**
3. **Que evidência demonstra que o resultado corresponde ao pretendido?**

---

# 2. Objetivos da sessão

No final da sessão deverás ser capaz de:

- escolher entre `Deployment`, `DaemonSet`, `StatefulSet`, `Job` e `CronJob`;
- explicar a cadeia `Deployment → ReplicaSet → Pods`;
- observar a reconciliação de um Deployment após perda de um Pod;
- explicar o comportamento de um DaemonSet em Nodes elegíveis;
- explicar identidade estável, ordinais e ordenação num StatefulSet;
- explicar por que um StatefulSet **não garante distribuição dos Pods por Nodes**;
- compreender o papel de um Headless Service na identidade de rede de um StatefulSet;
- distinguir a identidade do StatefulSet da persistência dos seus dados;
- explicar `PV`, `PVC`, `StorageClass` e dynamic provisioning;
- interpretar `WaitForFirstConsumer`;
- explicar a afinidade do PV local ao Node escolhido;
- distinguir o `local-path-provisioner` de um driver CSI;
- executar PostgreSQL 16 num StatefulSet com storage persistente;
- validar persistência após recriação do Pod;
- explicar `ClusterIP`, DNS de Service e `EndpointSlice`;
- diagnosticar uma falha de Service causada por um selector incorreto;
- criar e validar um Ingress processado pelo Traefik;
- interpretar uma `GatewayClass` existente;
- criar `Gateway` e `HTTPRoute`;
- distinguir a porta do listener do Gateway da porta externa NodePort;
- executar um backup lógico de PostgreSQL através de um Job;
- explicar o papel de um CronJob;
- retirar uma cópia do backup para fora do cluster;
- distinguir perda de Pod de perda lógica dos dados;
- executar um restore PostgreSQL por streaming;
- justificar, com evidências, a afirmação **Persistência ≠ Backup**.

---

# 3. Baseline técnica validada

O percurso da Sessão 5 foi validado num cluster real com a seguinte baseline:

```text
Sistema operativo:       Ubuntu 26.04.1 LTS
Kernel:                   7.0.0-31-generic

Control Plane:            k8s-cp-01 / 192.168.50.46
Worker 1:                 k8s-wk-01 / 192.168.50.65
Worker 2:                 k8s-wk-03 / 192.168.50.102

Kubernetes:               1.36.4
containerd:               2.2.6
CNI:                      Calico

StorageClass:             local-path
Provisioner:              rancher.io/local-path
volumeBindingMode:        WaitForFirstConsumer
reclaimPolicy:            Delete

local-path-provisioner:   v0.0.37

Gateway API:              v1.6.1 — Standard Channel

Helm:                     v3.22.0
Traefik Helm Chart:       41.5.0
Traefik Proxy:            v3.7.13
Namespace Traefik:        traefik
IngressClass:             traefik
GatewayClass:             traefik

Traefik entryPoint web:   8000
Traefik entryPoint TLS:   8443
Service HTTP:             80 → NodePort 30080
Service HTTPS:            443 → NodePort 30443

Symfony Demo:             v3.1.0
Symfony:                  8.1
PHP:                      8.4
Imagem de laboratório:    ghcr.io/skullclamp/symfony-demo:1.1.0
PostgreSQL:               16
```

> As versões patch representam a baseline efetivamente validada nesta edição. Antes de reutilizar o laboratório noutra edição, devem ser reconfirmadas.

A validação automática final executou **48 verificações obrigatórias, com 48 OK, 0 avisos e 0 falhas**.

---

# 4. Continuidade da Sessão 4 para a Sessão 5

A Sessão 4 terminou com um cluster Kubernetes funcional e atualizado:

```text
Sessão 4
Kubernetes 1.35.x
      ↓
upgrade controlado
      ↓
Kubernetes 1.36.4
      ↓
cluster saudável
```

A Sessão 5 não volta a instalar o cluster. Parte desse estado e responde a outra pergunta:

> Como administramos workloads, networking e dados **dentro** do cluster já construído?

A progressão é:

```text
CLUSTER PRONTO
     ↓
WORKLOADS
     ↓
IDENTIDADE
     ↓
STORAGE
     ↓
SERVICES / DNS
     ↓
INGRESS / GATEWAY API
     ↓
BACKUP
     ↓
FALHA CONTROLADA
     ↓
RESTORE
```

---

# 5. Modelo mental: objeto, controlador e reconciliação

A maior parte dos workloads desta sessão é gerida por controladores.

```text
Manifesto
   ↓
API Server
   ↓
estado desejado
   ↓
controller observa
   ↓
compara desejado vs observado
   ↓
atua
   ↓
novo estado observado
```

Se declararmos:

```text
replicas: 2
```

e apenas existir um Pod saudável, o controlador tenta repor a diferença.

A pergunta correta não é apenas:

> “O Pod está a correr?”

É também:

> “Quem é responsável por garantir que este Pod existe?”

---

# 6. Escolher o controlador de workload

| Objeto | Quando usar | Característica principal |
|---|---|---|
| `Deployment` | aplicações stateless e réplicas substituíveis | rollout e reconciliação de réplicas |
| `DaemonSet` | um agente por Node elegível | cobertura dos Nodes |
| `StatefulSet` | workloads que precisam de identidade estável e/ou storage por réplica | nome/ordinal estável e gestão ordenada |
| `Job` | tarefa finita | termina com sucesso ou falha |
| `CronJob` | tarefa finita recorrente | cria Jobs segundo um calendário |

Um critério simples:

```text
Serviço stateless contínuo?      → Deployment
Agente em cada Node elegível?    → DaemonSet
Identidade estável por réplica?  → StatefulSet
Tarefa que termina?              → Job
Tarefa que termina e repete?     → CronJob
```

---

# 7. Deployment

Um Deployment não executa diretamente os Pods. A relação principal é:

```text
Deployment
    ↓ gere
ReplicaSet
    ↓ gere
Pods
```

No laboratório criamos duas réplicas da aplicação Symfony:

```bash
kubectl create deployment symfony-demo \
  --image=ghcr.io/skullclamp/symfony-demo:1.1.0 \
  --replicas=2
```

## 7.1. O que observar

```bash
kubectl get deployment symfony-demo
kubectl get replicasets
kubectl get pods -l app=symfony-demo -o wide
```

O Deployment deve convergir para:

```text
READY   UP-TO-DATE   AVAILABLE
2/2     2            2
```

Os nomes exatos dos Pods e o hash do ReplicaSet podem variar.

## 7.2. Reconciliação

Quando eliminamos um Pod:

```bash
kubectl delete pod <POD>
```

o Deployment não “recupera aquele Pod”. O ReplicaSet cria **outro Pod** para repor o número de réplicas.

```text
2 desejados
2 observados
     ↓
eliminar 1 Pod
     ↓
1 observado
     ↓
controller deteta diferença
     ↓
cria Pod substituto
     ↓
2 observados
```

### Boa prática

Validar o controlador e não apenas o Pod individual:

```bash
kubectl rollout status deployment/symfony-demo
```

---

# 8. DaemonSet

Um DaemonSet procura manter um Pod em cada **Node elegível**.

No laboratório:

```text
k8s-cp-01 → taint NoSchedule
k8s-wk-01 → elegível
k8s-wk-03 → elegível
```

Por isso o resultado esperado é um Pod no `k8s-wk-01` e outro no `k8s-wk-03`.

> Não memorizar “DaemonSet = exatamente um Pod em todos os Nodes”. Taints, selectors, affinity e outras restrições podem tornar um Node não elegível.

## 8.1. Exemplo

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: daemon-demo
spec:
  selector:
    matchLabels:
      app: daemon-demo
  template:
    metadata:
      labels:
        app: daemon-demo
    spec:
      containers:
        - name: daemon-demo
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
```

Observar:

```bash
kubectl get daemonset daemon-demo
kubectl get pods -l app=daemon-demo -o wide
```

---

# 9. StatefulSet: identidade estável

StatefulSet resolve problemas diferentes de Deployment.

Num Deployment, as réplicas são normalmente substituíveis:

```text
pod-x7m2q
pod-p9v8b
```

Num StatefulSet existem ordinais:

```text
web-0
web-1
web-2
```

Os nomes fazem parte da identidade do workload.

## 9.1. O que o StatefulSet oferece

- nome estável por réplica;
- ordinal estável;
- criação e terminação ordenadas por omissão;
- integração com um Service governante;
- possibilidade de criar uma PVC por réplica através de `volumeClaimTemplates`.

## 9.2. O que não oferece automaticamente

StatefulSet **não significa**:

```text
alta disponibilidade
distribuição automática entre Nodes
backup
storage distribuído
```

Duas réplicas podem ser colocadas no mesmo Node se não existirem regras adicionais de scheduling.

Affinity e topology spread são aprofundados na Sessão 6.

---

# 10. StatefulSet pode existir sem storage próprio

É importante separar duas ideias:

```text
StatefulSet
→ identidade e ordenação
```

e:

```text
PVC / PV
→ persistência
```

O primeiro StatefulSet do laboratório, `web`, é usado para observar `web-0`, `web-1` e DNS individual. Pode existir sem `volumeClaimTemplates`.

Só depois introduzimos storage.

Isto evita a associação incorreta:

> “StatefulSet é simplesmente um Deployment com disco.”

---

# 11. Headless Service e DNS por Pod

Um Service normal recebe um `ClusterIP`. Um Headless Service usa:

```yaml
spec:
  clusterIP: None
```

Neste caso, o objetivo não é fornecer um único IP virtual para balanceamento. O DNS pode expor diretamente a identidade das réplicas.

Exemplo:

```text
web-0.web.sessao5.svc.cluster.local
web-1.web.sessao5.svc.cluster.local
```

Estrutura:

```text
<nome-do-pod>.<service>.<namespace>.svc.cluster.local
```

## 11.1. Porque é importante para workloads stateful?

Alguns sistemas precisam de encontrar instâncias específicas, e não apenas “qualquer réplica”.

```text
Service normal
cliente → nome Service → backend disponível
```

```text
Headless + StatefulSet
cliente → identidade concreta → web-1
```

---

# 12. Persistência: PV, PVC e StorageClass

Os três objetos não são equivalentes.

```text
Pod
 ↓ pede
PVC
 ↓ usa
StorageClass
 ↓ chama
Provisioner
 ↓ cria
PV
 ↓ fica ligado
PVC
```

## 12.1. PersistentVolumeClaim

Uma PVC exprime a necessidade do consumidor.

Exemplo:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

A PVC diz:

```text
quero armazenamento
classe = local-path
modo = ReadWriteOnce
capacidade solicitada = 1Gi
```

Não indica diretamente o diretório no Node.

## 12.2. PersistentVolume

O PV representa o volume disponibilizado ao cluster.

No laboratório, o PV gerado apresentou:

```text
provisioned-by: rancher.io/local-path
Node Affinity: kubernetes.io/hostname in [k8s-wk-03]
Path: /opt/local-path-provisioner/...
```

O nome, UID e caminho final variam entre execuções.

---

# 13. StorageClass e dynamic provisioning

A StorageClass utilizada é:

```text
name:               local-path
provisioner:        rancher.io/local-path
reclaimPolicy:      Delete
volumeBindingMode:  WaitForFirstConsumer
```

Dynamic provisioning evita criar manualmente cada PV antes da PVC.

```text
PVC criada
   ↓
provisioner observa
   ↓
PV criado quando necessário
   ↓
PVC Bound
```

## 13.1. O `local-path-provisioner` não é CSI

Neste laboratório utilizamos o Rancher Local Path Provisioner. É um **external provisioner** que participa no mecanismo de StorageClass e provisioning dinâmico.

Não deve ser apresentado como um driver CSI.

Esta distinção é importante porque:

```text
dynamic provisioning
      ≠
CSI obrigatoriamente
```

---

# 14. `WaitForFirstConsumer`

Com:

```text
volumeBindingMode: WaitForFirstConsumer
```

a PVC pode permanecer `Pending` até surgir um Pod que a consuma.

Isto é comportamento esperado:

```text
PVC criada
   ↓
Pending
   ↓
Pod consumidor criado
   ↓
scheduler escolhe Node
   ↓
provisioner cria volume adequado ao Node
   ↓
PVC Bound
```

No laboratório validado:

```text
Pod consumidor → k8s-wk-03
PV             → nodeAffinity k8s-wk-03
```

## 14.1. Porque é útil?

Em storage dependente de topologia, criar o volume demasiado cedo pode escolher uma localização incompatível com o futuro consumidor.

`WaitForFirstConsumer` permite que a decisão de scheduling participe no processo.

---

# 15. Storage local e afinidade ao Node

O local-path cria armazenamento local no Node.

No ambiente validado:

```text
/opt/local-path-provisioner/...
```

e o PV inclui afinidade ao Node onde foi provisionado.

Consequência:

```text
dados no k8s-wk-03
      ↓
Pod eliminado
      ↓
Pod recriado usando mesma PVC
      ↓
scheduler tem de respeitar afinidade do PV
      ↓
dados continuam acessíveis
```

Mas:

```text
perda física do k8s-wk-03
      ↓
disco local deixa de estar acessível
      ↓
local-path não replica os dados para outro Worker
```

Portanto:

> **local-path é adequado ao objetivo pedagógico desta sessão, mas não representa storage distribuído nem solução de HA.**

---

# 16. `reclaimPolicy: Delete`

A StorageClass do laboratório usa:

```text
reclaimPolicy: Delete
```

No teste validado:

```text
PVC Bound
   ↓
namespace/PVC eliminado
   ↓
PV eliminado
```

Isto demonstra que o ciclo de vida do volume pode estar associado ao da claim.

> `Delete` é a configuração utilizada no laboratório. Não deve ser apresentada como recomendação universal para produção.

A política adequada depende do storage, do risco, da operação e da estratégia de recuperação.

---

# 17. PostgreSQL como StatefulSet

A base de dados do caso transversal é PostgreSQL 16.

O objetivo da Sessão 5 é trabalhar:

```text
identidade
+
persistência
+
Service/DNS
+
backup
+
restore
```

Não é ainda construir toda a integração aplicacional Symfony → PostgreSQL. Essa implementação completa fica para a Sessão 9.

## 17.1. Variáveis do laboratório

```text
POSTGRES_DB       = symfony_demo
POSTGRES_USER     = postgres
POSTGRES_PASSWORD = Secret postgres-credentials
```

A password é lida através de:

```yaml
valueFrom:
  secretKeyRef:
    name: postgres-credentials
    key: password
```

Nesta sessão o Secret é usado como recurso necessário ao cenário. A gestão de configuração e secrets é aprofundada mais tarde.

## 17.2. Readiness

A readiness probe usa:

```bash
pg_isready
```

Objetivo:

```text
container arrancou
      ≠
PostgreSQL já aceita ligações
```

Quando o Pod passa a `Ready`, queremos uma evidência mais significativa do que apenas o processo estar em execução.

---

# 18. `volumeClaimTemplates`

No StatefulSet PostgreSQL, `volumeClaimTemplates` permite criar storage associado à réplica.

Conceito:

```text
postgres-0
   ↓
data-postgres-0
   ↓
PV local
```

Se existissem várias réplicas:

```text
postgres-0 → PVC própria
postgres-1 → PVC própria
postgres-2 → PVC própria
```

Cada réplica pode ter a sua claim.

Isto não significa que o conteúdo seja automaticamente replicado entre bases de dados.

---

# 19. Service `ClusterIP`

Um Service fornece um ponto estável para chegar a Pods selecionados.

```text
cliente
   ↓
postgres
   ↓
Service
   ↓ selector app=postgres
   ↓
EndpointSlice
   ↓
Pod postgres-0
```

No caso do Symfony:

```text
cliente
   ↓
symfony-demo
   ↓
ClusterIP
   ↓
Pods do Deployment
```

## 19.1. Service não “descobre aplicações” por nome humano

A ligação a Pods é feita através de labels e selectors.

Exemplo:

```yaml
selector:
  app: symfony-demo
```

Se o selector for:

```yaml
app: symfony-demo-ERRO
```

o Service pode existir perfeitamente, mas não terá backends válidos.

---

# 20. DNS de Service

Dentro do mesmo namespace:

```text
http://symfony-demo/health
postgres:5432
```

podem ser resolvidos através do DNS do cluster.

Forma completa:

```text
<service>.<namespace>.svc.cluster.local
```

Exemplo:

```text
symfony-demo.sessao5.svc.cluster.local
```

O DNS resolve o nome do Service. O encaminhamento para Pods depende depois da configuração do Service e dos seus endpoints.

---

# 21. EndpointSlice como evidência operacional

Nesta sessão usamos `EndpointSlice` como objeto principal para diagnosticar backends de Services.

```bash
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo
```

Perguntas:

```text
Existe EndpointSlice?
Tem addresses?
Esses IPs correspondem a Pods Ready?
O selector do Service corresponde às labels?
```

## 21.1. Sequência de diagnóstico

```text
Service não responde
       ↓
kubectl get svc
       ↓
ver selector
       ↓
kubectl get pods --show-labels
       ↓
kubectl get endpointslices
       ↓
comparar labels / endpoints
       ↓
corrigir
       ↓
retestar
```

Não começamos por reiniciar Pods aleatoriamente.

---

# 22. Traefik no laboratório

O Traefik é preparado antes do laboratório principal.

```text
Namespace:           traefik
IngressClass:        traefik
GatewayClass:        traefik

entryPoint web:      8000
entryPoint websecure:8443

Service:
HTTP   80  → NodePort 30080
HTTPS  443 → NodePort 30443
```

O mesmo Traefik processa:

```text
Ingress
+
Gateway API
```

Isto permite comparar os dois modelos mantendo o backend e a exposição externa constantes.

---

# 23. Ingress

Um Ingress descreve regras de entrada HTTP/HTTPS processadas por um Ingress Controller.

Exemplo conceptual:

```text
curl
Host: symfony-ingress.lab
      ↓
WorkerIP:30080
      ↓
Traefik Service
      ↓
entryPoint web :8000
      ↓
Ingress
      ↓
Service symfony-demo:80
      ↓
Pod Symfony
```

Manifesto:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: symfony-demo
spec:
  ingressClassName: traefik
  rules:
    - host: symfony-ingress.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: symfony-demo
                port:
                  number: 80
```

## 23.1. Teste externo

```bash
curl -H "Host: symfony-ingress.lab" \
  http://<WORKER-IP>:30080/health
```

No laboratório validado:

```json
{"status":"ok"}
```

---

# 24. Gateway API

Gateway API separa responsabilidades de forma mais explícita.

```text
GatewayClass
     ↓
Gateway
     ↓
HTTPRoute
     ↓
Service
```

## 24.1. GatewayClass

A `GatewayClass traefik` é pré-instalada antes do exercício.

O formando deve **interpretá-la**, não criá-la no laboratório principal:

```bash
kubectl get gatewayclass traefik
```

Esperado:

```text
CONTROLLER                      ACCEPTED
traefik.io/gateway-controller   True
```

## 24.2. Gateway

O Gateway representa a infraestrutura/listener aceite pelo controller.

No nosso Traefik:

```yaml
listeners:
  - name: http
    protocol: HTTP
    port: 8000
```

### Ponto crítico: porque 8000 e não 80?

Porque o listener do Gateway tem de corresponder ao entryPoint interno do Traefik utilizado nesta configuração:

```text
Gateway listener       8000
          ↓
Traefik entryPoint web 8000
          ↓
Service Traefik          80
          ↓
NodePort               30080
```

`8000` é a porta interna do listener; `30080` é a porta usada pelo cliente externo no Node.

---

# 25. HTTPRoute

O `HTTPRoute` associa regras HTTP ao Gateway.

Exemplo:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: symfony-demo
spec:
  parentRefs:
    - name: symfony-gateway
  hostnames:
    - symfony-gateway.lab
  rules:
    - backendRefs:
        - name: symfony-demo
          port: 80
```

Duas condições são particularmente importantes:

```text
Accepted=True
ResolvedRefs=True
```

- `Accepted=True` — o controller aceitou a route para aquele parent;
- `ResolvedRefs=True` — as referências, como o Service backend, foram resolvidas.

No laboratório:

```bash
curl -H "Host: symfony-gateway.lab" \
  http://<WORKER-IP>:30080/health
```

deve devolver:

```json
{"status":"ok"}
```

---

# 26. Ingress versus Gateway API

Neste laboratório não apresentamos Gateway API como simples “renomeação” de Ingress.

| Aspeto | Ingress | Gateway API |
|---|---|---|
| Entrada | recurso `Ingress` | `GatewayClass` + `Gateway` + Routes |
| Separação de papéis | menor | mais explícita |
| Extensibilidade | baseada no modelo Ingress/controller | modelo de APIs de routing mais estruturado |
| Backend no exercício | `symfony-demo` | `symfony-demo` |
| Controller | Traefik | Traefik |
| Entrada externa | NodePort `30080` | NodePort `30080` |

O objetivo pedagógico é comparar **modelos de configuração**, não mudar simultaneamente controller, aplicação e rede externa.

---

# 27. Job

Um Job representa uma tarefa finita.

```text
criar Pod
   ↓
executar trabalho
   ↓
exit 0
   ↓
Job Complete
```

No laboratório, o Job executa:

```bash
pg_dump
```

e escreve:

```text
/backup/dump.sql
```

num PVC dedicado.

## 27.1. Porque Job e não Deployment?

Um Deployment procura manter um processo contínuo.

O backup deve:

```text
começar
executar
terminar
registar sucesso/falha
```

Esse comportamento corresponde a um Job.

## 27.2. `backoffLimit`

```yaml
spec:
  backoffLimit: 2
```

limita tentativas adicionais perante falha.

Não transforma uma falha lógica num sucesso; apenas controla o comportamento de repetição.

---

# 28. CronJob

Um CronJob cria Jobs de acordo com uma expressão de calendário.

No laboratório:

```yaml
schedule: "0 3 * * *"
timeZone: "Europe/Lisbon"
suspend: true
```

Interpretação:

```text
schedule   → 03:00
timeZone   → Europe/Lisbon
suspend    → não executar automaticamente durante a aula
```

Mantemos `suspend: true` para evitar que a execução dependa da hora exata da sessão.

O formando observa a configuração sem introduzir uma tarefa automática imprevisível no meio do laboratório.

---

# 29. Backup lógico de PostgreSQL

Persistir o diretório de dados e criar um dump são mecanismos diferentes.

```text
PVC PostgreSQL
→ mantém ficheiros de dados do workload
```

```text
pg_dump
→ produz representação lógica exportável
```

No laboratório:

```text
PostgreSQL
   ↓ pg_dump
backup-pvc
   ↓
backup-reader
   ↓ kubectl cp
./dump-symfony_demo.sql
   ↓
cópia fora do cluster
```

## 29.1. Porque copiar o dump para fora?

Se o único backup estiver num volume sujeito ao mesmo domínio de falha, a proteção é limitada.

O laboratório introduz esta distinção:

```text
dados primários no cluster
+
backup no cluster
      ↓
ainda existe risco comum
```

Ao retirar uma cópia:

```text
cluster
   ↓
dump
   ↓
máquina administrativa
```

passamos a ter uma cópia fora daquele storage de laboratório.

Isto continua a ser um exercício pedagógico, não uma política completa de backup empresarial.

---

# 30. `kubectl cp` e o Pod `backup-reader`

O Job terminado não é usado diretamente como ponto de cópia.

Criamos um Pod temporário que monta `backup-pvc`:

```text
backup-pvc
    ↓
backup-reader
    ↓
kubectl cp
```

O `kubectl cp` depende de `tar` no container usado no exercício. Por isso validamos:

```bash
kubectl exec backup-reader -- tar --help >/dev/null
```

Depois:

```bash
kubectl cp \
  backup-reader:/backup/dump.sql \
  ./dump-symfony_demo.sql
```

Finalmente confirmamos:

```bash
test -s ./dump-symfony_demo.sql
```

`-s` verifica que o ficheiro existe e tem tamanho superior a zero.

---

# 31. Falha controlada A — perda do Pod

Primeiro eliminamos apenas:

```text
postgres-0
```

O StatefulSet recria o Pod.

A PVC permanece.

```text
Pod perdido
   ↓
StatefulSet reconcilia
   ↓
mesmo nome postgres-0
   ↓
nova UID do Pod
   ↓
mesma PVC
   ↓
dados continuam
```

Isto demonstra:

```text
persistência perante recriação do Pod
```

Não demonstra backup e não demonstra sobrevivência à perda física do Worker.

---

# 32. Falha controlada B — eliminação da PVC / perda lógica dos dados

Depois do backup externo estar confirmado, eliminamos o StatefulSet e a PVC de dados no cenário controlado.

Com `reclaimPolicy: Delete`, o volume associado pode ser eliminado.

Depois recriamos o PostgreSQL.

Resultado esperado antes do restore:

```text
base de dados nova
dados lab_marker ausentes
```

Este cenário é chamado:

> **perda lógica dos dados / eliminação da PVC**

Não é descrito como simulação de perda física do Worker.

---

# 33. Restore por streaming

O restore é feito através do cliente PostgreSQL:

```bash
kubectl exec -i pg-client -- \
  psql \
  -h postgres \
  -U postgres \
  -d symfony_demo \
  -v ON_ERROR_STOP=1 \
  < ./dump-symfony_demo.sql
```

## 33.1. Elementos importantes

| Elemento | Função |
|---|---|
| `kubectl exec -i` | mantém stdin aberto |
| `psql` | cliente PostgreSQL |
| `-h postgres` | usa o Service DNS |
| `-U postgres` | utilizador |
| `-d symfony_demo` | base de dados |
| `-v ON_ERROR_STOP=1` | termina perante erro SQL |
| `< ficheiro.sql` | envia o dump local para stdin |

Fluxo:

```text
dump local
   ↓ stdin
kubectl exec -i
   ↓
psql em pg-client
   ↓ rede Kubernetes
Service postgres
   ↓
postgres-0
```

Não é necessário copiar primeiro o dump para o Pod PostgreSQL.

---

# 34. Persistência ≠ Backup

Esta é a mensagem central da sessão.

## 34.1. Persistência

No laboratório:

```text
eliminar Pod
   ↓
PVC permanece
   ↓
dados permanecem
```

A persistência ajuda o workload a sobreviver à substituição do processo/Pod.

## 34.2. Backup

```text
dados primários
   ↓
cópia independente
   ↓
possibilidade de restore
```

Um backup só demonstra valor quando a recuperação é testada.

## 34.3. O laboratório prova as duas coisas separadamente

```text
CENÁRIO A
Pod eliminado
→ dados continuam
→ persistência comprovada
```

```text
CENÁRIO B
PVC eliminada
→ dados desaparecem
→ dump externo restaurado
→ recuperação comprovada
```

Conclusão:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

---

# 35. Troubleshooting orientado por evidências

A metodologia mantém a abordagem iniciada nas sessões anteriores:

```text
SINTOMA
   ↓
RECOLHER EVIDÊNCIA
   ↓
FORMULAR HIPÓTESE
   ↓
VALIDAR HIPÓTESE
   ↓
CORRIGIR
   ↓
VALIDAR NOVAMENTE
```

## 35.1. PVC fica `Pending`

Observar:

```bash
kubectl get pvc
kubectl describe pvc <PVC>
kubectl get storageclass
kubectl get pods -n local-path-storage
kubectl get events --sort-by=.lastTimestamp
```

Perguntar:

```text
StorageClass existe?
Provisioner está Running?
É WaitForFirstConsumer?
Já existe Pod consumidor?
Existem Events de provisioning?
```

Um PVC `Pending` antes do primeiro consumidor pode ser completamente normal com `WaitForFirstConsumer`.

## 35.2. Pod com PVC não agenda

Observar:

```bash
kubectl describe pod <POD>
kubectl describe pv <PV>
```

Procurar:

```text
nodeAffinity
taints
selectors
recursos
volume binding
```

Num PV local, a afinidade ao Node é uma restrição real.

## 35.3. Service existe mas não responde

Observar:

```bash
kubectl get svc <SERVICE> -o yaml
kubectl get pods --show-labels
kubectl get endpointslices \
  -l kubernetes.io/service-name=<SERVICE>
```

Um Service sem endpoints frequentemente indica incompatibilidade selector/labels ou ausência de Pods Ready.

## 35.4. Ingress devolve `404`

Primeiro separar camadas:

```text
NodePort responde?
Traefik está Running?
Host header está correto?
IngressClass é traefik?
Ingress aponta para Service certo?
Service tem EndpointSlice?
```

Testar:

```bash
curl -v \
  -H "Host: symfony-ingress.lab" \
  http://<WORKER-IP>:30080/health
```

## 35.5. Gateway não encaminha

Observar:

```bash
kubectl get gateway
kubectl describe gateway <GATEWAY>
kubectl get httproute -o yaml
```

Condições:

```text
Gateway Accepted / Programmed
HTTPRoute Accepted=True
HTTPRoute ResolvedRefs=True
```

Confirmar ainda:

```text
Gateway listener = 8000
Traefik entryPoint web = 8000
Service externo = NodePort 30080
```

## 35.6. PostgreSQL Pod está `Running` mas não `Ready`

Observar:

```bash
kubectl get pod postgres-0
kubectl describe pod postgres-0
kubectl logs postgres-0
```

A readiness probe com `pg_isready` ajuda a distinguir processo iniciado de serviço pronto.

## 35.7. Job de backup falha

Observar:

```bash
kubectl get job postgres-backup
kubectl describe job postgres-backup
kubectl logs job/postgres-backup
kubectl get pvc backup-pvc
```

Validar:

```text
DNS postgres
credenciais
DB symfony_demo
PVC montada
pg_dump
espaço
```

---

# 36. Como interpretar outputs importantes

## 36.1. `kubectl get pods -o wide`

| Coluna | Significado |
|---|---|
| `READY` | containers prontos / total |
| `STATUS` | estado resumido |
| `RESTARTS` | reinícios |
| `IP` | IP do Pod |
| `NODE` | Node escolhido pelo scheduler |

`Running` não implica necessariamente `Ready`.

## 36.2. `kubectl get pvc`

Exemplo:

```text
NAME              STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
data-postgres-0   Bound    2Gi        RWO            local-path
```

- `Pending` — claim ainda não ligada a PV;
- `Bound` — claim ligada a volume;
- `STORAGECLASS` — política/provisioner selecionado.

## 36.3. `kubectl get pv`

Observar:

```text
CAPACITY
ACCESS MODES
RECLAIM POLICY
STATUS
CLAIM
STORAGECLASS
```

## 36.4. `kubectl get gateway`

`PROGRAMMED=True` indica que o controller programou a infraestrutura necessária para o Gateway, dentro das capacidades do ambiente.

## 36.5. HTTPRoute

No YAML de status procurar:

```yaml
type: Accepted
status: "True"
```

e:

```yaml
type: ResolvedRefs
status: "True"
```

---

# 37. Comandos de observação que deves dominar

| Objetivo | Comando |
|---|---|
| Nodes | `kubectl get nodes -o wide` |
| Pods | `kubectl get pods -o wide` |
| Controladores | `kubectl get deploy,ds,sts` |
| Rollout Deployment | `kubectl rollout status deployment/<nome>` |
| Rollout DaemonSet | `kubectl rollout status daemonset/<nome>` |
| StatefulSet | `kubectl get statefulset` |
| Services | `kubectl get svc` |
| EndpointSlices | `kubectl get endpointslices` |
| PVC | `kubectl get pvc` |
| PV | `kubectl get pv` |
| StorageClass | `kubectl get storageclass` |
| Ingress | `kubectl get ingress` |
| GatewayClass | `kubectl get gatewayclass` |
| Gateway | `kubectl get gateway` |
| HTTPRoute | `kubectl get httproute` |
| Jobs | `kubectl get jobs` |
| CronJobs | `kubectl get cronjobs` |
| Events | `kubectl get events --sort-by=.lastTimestamp` |
| Detalhes | `kubectl describe <tipo> <nome>` |
| Logs | `kubectl logs <pod>` |

Flags frequentes:

| Flag | Função |
|---|---|
| `-n <namespace>` | restringe a um namespace |
| `-A` | todos os namespaces |
| `-o wide` | colunas adicionais |
| `-o yaml` | representação YAML |
| `-l chave=valor` | label selector |
| `--sort-by` | ordena por campo |
| `--timeout` | limita o tempo de espera |
| `--for=condition=...` | espera por uma condição |
| `--for=create` | espera pela criação do recurso |
| `-i` em `kubectl exec` | mantém stdin ligado ao processo remoto |

---

# 38. Pontos-chave da sessão

```text
Deployment gere ReplicaSets e réplicas substituíveis.

DaemonSet mantém Pods em Nodes elegíveis.

StatefulSet fornece identidade estável e ordenação.
StatefulSet não garante distribuição por Nodes.
StatefulSet pode existir sem volumeClaimTemplates.

Headless Service permite identidade DNS por Pod.

PVC exprime necessidade.
PV representa volume.
StorageClass define a classe/política de provisioning.

local-path-provisioner é external provisioner, não CSI.

WaitForFirstConsumer adia o binding/provisioning até existir consumidor.

Storage local implica afinidade ao Node.

reclaimPolicy Delete não é backup.

Service usa selectors.
EndpointSlice mostra backends.

Ingress e Gateway API podem usar o mesmo Traefik.

Gateway listener 8000 é interno.
NodePort 30080 é a entrada externa HTTP.

Job é finito.
CronJob cria Jobs recorrentes.

Persistência ≠ Backup.
Backup sem restore testado é proteção incompleta.
```

---

# 39. Exercícios de consolidação

## Exercício 1 — Escolher o workload

Indica o objeto mais adequado e justifica:

1. API web stateless com três réplicas.
2. Agente de recolha de logs em cada Worker.
3. Base de dados que precisa de identidade estável.
4. Exportação de base de dados que deve terminar.
5. Exportação diária às 03:00.

## Exercício 2 — Reconciliação

Tens um Deployment com:

```text
replicas desejadas = 2
Pods observados     = 2
```

Eliminas um Pod manualmente.

Explica:

- o que acontece ao número de réplicas;
- que controlador participa;
- porque o novo Pod não precisa do mesmo nome.

## Exercício 3 — StatefulSet

Explica por que:

```text
web-0
web-1
```

é uma diferença operacional relevante face aos nomes gerados por um Deployment.

Depois responde:

> Um StatefulSet de duas réplicas garante uma réplica em cada Worker?

Justifica.

## Exercício 4 — PVC `Pending`

Uma PVC usa:

```text
StorageClass: local-path
volumeBindingMode: WaitForFirstConsumer
```

Foi criada, mas ainda não existe consumidor.

O estado `Pending` representa necessariamente falha? Explica.

## Exercício 5 — Node Affinity do PV

O PV mostra:

```text
kubernetes.io/hostname in [k8s-wk-03]
```

O que acontece se um Pod que usa essa PVC tentar ser agendado noutro Worker?

## Exercício 6 — Service sem endpoints

O Service existe, mas:

```bash
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo
```

não apresenta addresses úteis.

Indica pelo menos três evidências que recolherias antes de alterar a aplicação.

## Exercício 7 — Portas Traefik

Explica a diferença entre:

```text
Gateway listener     8000
Service HTTP           80
NodePort            30080
```

## Exercício 8 — Gateway API

Ordena:

```text
Service
HTTPRoute
GatewayClass
Gateway
cliente
```

e explica o papel de cada objeto.

## Exercício 9 — Persistência

Eliminamos `postgres-0`, mas a PVC permanece e os dados continuam.

O que foi comprovado?

O que **não** foi comprovado?

## Exercício 10 — Backup

Porque é insuficiente afirmar “temos backup” apenas porque existe:

```text
/backup/dump.sql
```

num PVC dentro do mesmo cluster?

## Exercício 11 — Restore

Explica o fluxo:

```bash
kubectl exec -i pg-client -- psql ... < dump.sql
```

O ficheiro é copiado para `postgres-0` antes do restore?

## Exercício 12 — Cenários de falha

Compara:

```text
A) eliminar Pod postgres-0
B) eliminar PVC data-postgres-0
```

Que mecanismo permite recuperar em cada cenário?

---

# 40. Autoavaliação

No final da sessão, confirma se consegues afirmar:

- [ ] Sei escolher entre Deployment, DaemonSet, StatefulSet, Job e CronJob.
- [ ] Sei explicar `Deployment → ReplicaSet → Pods`.
- [ ] Sei demonstrar reconciliação após perda de um Pod.
- [ ] Sei explicar “um Pod por Node elegível” num DaemonSet.
- [ ] Sei explicar ordinais e identidade estável num StatefulSet.
- [ ] Sei explicar por que StatefulSet não implica HA nem dispersão de Pods.
- [ ] Sei explicar a função do Headless Service.
- [ ] Sei resolver um nome DNS individual de uma réplica.
- [ ] Sei distinguir PV, PVC e StorageClass.
- [ ] Sei explicar dynamic provisioning.
- [ ] Sei interpretar `WaitForFirstConsumer`.
- [ ] Sei explicar a afinidade de um PV local ao Node.
- [ ] Sei explicar por que local-path não é CSI nem storage distribuído.
- [ ] Sei validar persistência após recriação de Pod.
- [ ] Sei interpretar `reclaimPolicy: Delete`.
- [ ] Sei diagnosticar um Service com EndpointSlice.
- [ ] Sei testar DNS interno.
- [ ] Sei explicar Ingress, IngressClass e Ingress Controller.
- [ ] Sei interpretar GatewayClass.
- [ ] Sei criar Gateway e HTTPRoute.
- [ ] Sei procurar `Accepted=True` e `ResolvedRefs=True`.
- [ ] Sei distinguir listener 8000, Service 80 e NodePort 30080.
- [ ] Sei explicar Job e CronJob.
- [ ] Sei criar e validar um `pg_dump`.
- [ ] Sei retirar uma cópia do dump para fora do cluster.
- [ ] Sei distinguir perda de Pod de perda dos dados.
- [ ] Sei executar um restore por streaming.
- [ ] Sei justificar **Persistência ≠ Backup**.

---

# 41. Delimitação de âmbito

## Incluído nesta sessão

- Deployment, ReplicaSet e reconciliação;
- DaemonSet;
- StatefulSet;
- identidade estável e Headless Service;
- PV, PVC, StorageClass e dynamic provisioning;
- local-path e `WaitForFirstConsumer`;
- PostgreSQL 16 stateful;
- Services, DNS e EndpointSlice;
- Ingress com Traefik;
- Gateway API: GatewayClass, Gateway e HTTPRoute;
- Job e CronJob;
- backup lógico;
- falhas controladas;
- restore.

## Deliberadamente não aprofundado

- affinity e topology spread avançados — Sessão 6;
- quotas, requests/limits e scheduling avançado — Sessão 6;
- RBAC e políticas de segurança — Sessão 6;
- alta disponibilidade do Control Plane — Sessão 7;
- observabilidade aprofundada — Sessão 7;
- integração completa Symfony → PostgreSQL através de ConfigMaps/Secrets e manifests de aplicação — Sessão 9;
- storage distribuído/CSI empresarial em profundidade;
- estratégias empresariais completas de backup, retenção e disaster recovery.

---

# 42. Laboratório e recursos de apoio

O procedimento operacional completo encontra-se em:

```text
sessao-05/formando/labs/laboratorio_integrado_sessao_5.md
```

Manifests de referência:

```text
sessao-05/manifests/
```

O script:

```text
sessao-05/formador/validar_lab_sessao5.sh
```

é um recurso de **validação do formador**. Não substitui a execução manual do laboratório pelo formando.

O laboratório manual obriga a:

```text
executar
→ observar
→ interpretar
→ registar evidência
→ explicar
```

---

# 43. Fontes e leituras recomendadas

A preparação conceptual do manual é coerente com a bibliografia disponibilizada na formação, nomeadamente:

- *The Kubernetes Book* — workloads, Services, storage, reconciliação e operação;
- *Kubernetes in Action* — controllers, StatefulSets, Services, DNS e persistência;
- *Kubernetes: Up & Running* — workloads, Services, storage e práticas operacionais.

Para execução do laboratório devem também ser consultadas as documentações oficiais dos componentes usados na baseline:

- Kubernetes;
- Gateway API;
- Traefik;
- Rancher Local Path Provisioner;
- PostgreSQL.

As versões concretas devem ser novamente validadas quando a formação for atualizada.

---

# 44. Síntese final

A Sessão 5 parte de um cluster já construído e passa a administrar o que vive dentro dele:

```text
Deployment
    ↓
reconciliação

DaemonSet
    ↓
Node elegível

StatefulSet
    ↓
identidade estável
    ↓
Headless Service

PVC
    ↓
StorageClass
    ↓
Provisioner
    ↓
PV local
    ↓
persistência

Service
    ↓
EndpointSlice
    ↓
DNS

Traefik
   ├── Ingress
   └── Gateway API

PostgreSQL
    ↓
Job / pg_dump
    ↓
cópia fora do cluster
    ↓
perda controlada
    ↓
restore
```

A conclusão operacional é:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

Na Sessão 6, a administração avança para **recursos, scheduling e segurança**.
