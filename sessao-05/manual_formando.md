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
| **Foco pedagógico** | Administrar workloads, networking, storage, backup e recuperação |
| **Topologia** | 1 Control Plane + 2 Workers |
| **Kubernetes** | 1.36.4 |
| **Laboratório** | `labs/laboratorio_integrado_sessao_5.md` |
| **Namespace** | `sessao5` |
| **Mensagem central** | **Persistência ≠ Backup ≠ Alta Disponibilidade** |

---

# 1. Como utilizar este manual

Este manual acompanha o laboratório integrado e explica os conceitos necessários para interpretar o que o cluster está a fazer. Não substitui o laboratório nem deve ser usado como uma lista de comandos a memorizar.

A regra de trabalho é:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
OBJETO / COMANDO
   ↓
ESTADO ESPERADO
   ↓
EVIDÊNCIA
   ↓
EXPLICAR
```

Uma operação `kubectl apply` bem-sucedida prova apenas que a API aceitou o objeto. O resultado pedagógico exige observar o comportamento real do cluster.

---

# 2. Objetivos da sessão

No final da sessão deverás ser capaz de:

- explicar a cadeia `Deployment → ReplicaSet → Pod` e demonstrar reconciliação;
- distinguir `Deployment`, `DaemonSet`, `StatefulSet`, `Job` e `CronJob`;
- explicar identidade estável e ordinais num StatefulSet;
- utilizar um Headless Service para DNS individual de Pods;
- distinguir identidade de StatefulSet de persistência de dados;
- explicar `PV`, `PVC`, `StorageClass` e dynamic provisioning;
- interpretar `WaitForFirstConsumer`;
- identificar a afinidade ao Node de um PV local;
- explicar por que `local-path-provisioner` é um external provisioner e não um driver CSI;
- executar a Symfony Demo com uma base SQLite persistente numa PVC;
- diagnosticar um Service através de selectors, labels e EndpointSlices;
- validar entrada HTTP através de Ingress Traefik;
- interpretar `GatewayClass`, `Gateway` e `HTTPRoute`;
- executar um backup consistente de SQLite com a aplicação online;
- validar um backup com marcador, hash e `PRAGMA integrity_check`;
- compreender a finalidade de um CronJob;
- copiar um backup para fora do storage Kubernetes da aplicação;
- distinguir perda de Pod de perda lógica da PVC;
- restaurar uma base SQLite para uma nova PVC/PV;
- justificar, com evidência, **Persistência ≠ Backup ≠ Alta Disponibilidade**.

---

# 3. Baseline técnica

```text
Control Plane:             k8s-cp-01 / 192.168.50.46
Worker 1:                  k8s-wk-01 / 192.168.50.65
Worker 2:                  k8s-wk-03 / 192.168.50.102
Kubernetes:                1.36.4
containerd:                2.2.6
CNI:                       Calico

StorageClass:              local-path
Provisioner:               rancher.io/local-path
volumeBindingMode:         WaitForFirstConsumer
reclaimPolicy:             Delete

Gateway API:               v1.6.1
Traefik Chart:             41.5.0
Traefik Proxy:             v3.7.13
IngressClass:              traefik
GatewayClass:              traefik
entryPoint web:            8000
HTTP NodePort:             30080
HTTPS NodePort:            30443

Symfony Demo:              v3.1.0
Symfony:                   8.1
PHP:                       8.4
Imagem:                    ghcr.io/skullclamp/symfony-demo:1.1.0
Base de dados do lab:      SQLite
Ficheiro SQLite:           /var/www/html/data/database.sqlite
Namespace:                 sessao5
```

> A Sessão 5 usa SQLite deliberadamente para concentrar o exercício nos mecanismos Kubernetes. A integração completa da Symfony Demo com PostgreSQL não faz parte do percurso atual desta sessão.

---

# 4. Continuidade da topologia

A Sessão 4 termina com:

```text
k8s-cp-01
+
k8s-wk-01
```

Antes da Sessão 5, o formador adiciona `k8s-wk-03` fora dos 240 minutos, reutilizando o procedimento de `kubeadm join` já demonstrado. O preflight da Sessão 5 deve provar que os três Nodes estão `Ready` antes de depender desta topologia.

---

# 5. Controladores e reconciliação

Kubernetes trabalha continuamente para aproximar o estado observado do estado desejado.

```text
manifesto / comando
      ↓
API Server
      ↓
estado desejado
      ↓
controller
      ↓
estado observado
      ↓
reconciliação
```

## 5.1. Deployment

A relação principal é:

```text
Deployment
    ↓
ReplicaSet
    ↓
Pod
```

Na edição atual do laboratório, a Symfony Demo começa com **uma réplica**. Isto é suficiente para demonstrar reconciliação e mantém o percurso coerente com a utilização posterior de um ficheiro SQLite persistente.

Se o Pod for eliminado:

```text
Pod antigo desaparece
      ↓
ReplicaSet observa défice
      ↓
novo Pod é criado
      ↓
UID é diferente
      ↓
número de réplicas volta ao desejado
```

O controlador não recupera o mesmo objeto Pod; cria outro objeto para repor o estado desejado.

---

# 6. DaemonSet

Um DaemonSet procura manter um Pod em cada **Node elegível**.

No laboratório:

```text
k8s-cp-01 → Control Plane com taint NoSchedule
k8s-wk-01 → elegível
k8s-wk-03 → elegível
```

Logo, o resultado esperado é um Pod do DaemonSet em cada Worker.

> “DaemonSet = um Pod em todos os Nodes” é uma simplificação. O comportamento real depende de taints, selectors, affinity e outras regras de elegibilidade.

---

# 7. StatefulSet: identidade estável

StatefulSet é usado primeiro para isolar o conceito de identidade.

```text
web-0
web-1
web-2
```

Cada réplica possui um ordinal estável. Se `web-1` for eliminado, o controlador volta a criar um Pod chamado `web-1`, mas com um novo UID.

```text
nome nominal estável
        ≠
mesmo objeto Pod
```

## 7.1. StatefulSet não implica storage

O StatefulSet `web` do laboratório não precisa de `volumeClaimTemplates` para demonstrar ordinais e identidade.

```text
StatefulSet
→ identidade / ordenação

PVC / PV
→ persistência
```

Separar estes conceitos evita a ideia incorreta de que StatefulSet é apenas “um Deployment com disco”.

---

# 8. Headless Service e DNS individual

Um Headless Service usa:

```yaml
spec:
  clusterIP: None
```

Com StatefulSet, permite resolver identidades individuais:

```text
web-0.web.sessao5.svc.cluster.local
web-1.web.sessao5.svc.cluster.local
```

Estrutura:

```text
<pod>.<service>.<namespace>.svc.cluster.local
```

O objetivo é chegar a uma réplica específica, em vez de obter um único IP virtual de Service para balanceamento.

---

# 9. PV, PVC e StorageClass

Os três conceitos têm funções diferentes:

```text
Pod
 ↓ consome
PVC
 ↓ solicita storage através de
StorageClass
 ↓ usa
Provisioner
 ↓ cria
PV
```

## 9.1. PVC

A PVC expressa uma necessidade:

```yaml
accessModes:
  - ReadWriteOnce
storageClassName: local-path
resources:
  requests:
    storage: 1Gi
```

A aplicação não precisa de conhecer o caminho físico do volume no Node.

## 9.2. PV

O PV representa o armazenamento disponibilizado ao cluster. No caso `local-path`, o PV fica associado ao Node onde o volume foi criado.

## 9.3. StorageClass

A classe do laboratório usa:

```text
name:               local-path
provisioner:        rancher.io/local-path
volumeBindingMode:  WaitForFirstConsumer
reclaimPolicy:      Delete
```

O `local-path-provisioner` é um **external provisioner**. Dynamic provisioning não implica obrigatoriamente CSI.

---

# 10. `WaitForFirstConsumer`

Com `WaitForFirstConsumer`, uma PVC pode permanecer `Pending` até existir um consumidor elegível.

```text
PVC criada
   ↓
Pending
   ↓
Pod consumidor criado
   ↓
Scheduler escolhe Node compatível
   ↓
volume é provisionado
   ↓
PVC Bound
```

Por isso:

```text
PVC Pending sem consumidor
≠
provisioner avariado
```

A investigação deve distinguir:

```text
Pod sem Node + FailedScheduling
→ scheduling

PVC Pending antes do consumidor
→ estado esperado com WaitForFirstConsumer

PVC Pending depois do consumidor
→ PVC/Events/provisioner

Pod com Node + FailedMount
→ mount/storage depois do placement
```

---

# 11. Storage local e afinidade ao Node

Um PV `local-path` fica dependente do Node onde foi criado.

```text
PVC
 ↓
PV local
 ↓
nodeAffinity
 ↓
Node concreto
```

Isto permite que os dados sobrevivam à recriação do Pod, desde que o Node e o storage local continuem disponíveis.

Não fornece:

```text
replicação entre Workers
storage distribuído
alta disponibilidade por si só
```

---

# 12. Symfony Demo com SQLite persistente

A imagem contém inicialmente:

```text
/var/www/html/data/database.sqlite
```

Quando uma PVC vazia é montada diretamente sobre `/var/www/html/data`, o conteúdo original da imagem nesse caminho fica oculto. Por isso o laboratório usa um `initContainer` para copiar a base inicial para a PVC apenas quando ainda não existe `database.sqlite`.

```text
imagem contém database.sqlite
        ↓
PVC vazia
        ↓
initContainer verifica
        ↓
copia base inicial uma única vez
        ↓
container principal monta a mesma PVC
```

A aplicação usa:

```text
strategy: Recreate
replicas: 1
```

Isto evita ter dois Pods da aplicação a escrever simultaneamente o mesmo ficheiro SQLite durante uma atualização.

## 12.1. Prova de persistência

O laboratório cria um marcador dentro da base:

```text
persistencia-sessao5-ok
```

Depois elimina o Pod sem eliminar a PVC. O novo Pod deve conseguir ler o mesmo marcador.

A prova só é válida porque o arranque do novo Pod **não recria o marcador**.

---

# 13. Service, selectors e EndpointSlice

Um Service seleciona Pods por labels.

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
      ↓
endereços dos backends
```

No laboratório, o Service é criado deliberadamente com:

```text
selector: app=symfony-demo-ERRO
```

enquanto os Pods possuem:

```text
app=symfony-demo
```

O Service pode existir sem erro de API e, ainda assim, não possuir endpoints válidos.

Sequência de diagnóstico:

```text
kubectl get svc
      ↓
ver selector
      ↓
kubectl get pods --show-labels
      ↓
kubectl get endpointslices
      ↓
comparar
      ↓
corrigir selector
      ↓
retestar
```

---

# 14. Ingress com Traefik

O Traefik é infraestrutura pré-instalada no cluster.

```text
cliente
  ↓ NodePort 30080
Traefik Service :80
  ↓
entryPoint web :8000
  ↓
Ingress
  ↓
Service symfony-demo :80
  ↓
Pod Symfony
```

O header `Host` determina a regra de routing usada no exercício:

```text
Host: symfony-ingress.lab
```

A evidência final é uma resposta HTTP `200` do endpoint `/health`.

---

# 15. Gateway API

Gateway API separa de forma explícita vários papéis:

```text
GatewayClass
     ↓
Gateway
     ↓
HTTPRoute
     ↓
Service
```

A `GatewayClass traefik` já existe. O formando cria `Gateway` e `HTTPRoute`.

## 15.1. Portas

É importante não confundir:

```text
Gateway listener       8000
Traefik entryPoint web 8000
Service Traefik          80
NodePort               30080
```

O cliente externo usa `30080`. O listener do Gateway usa `8000` na configuração do controller.

## 15.2. Condições importantes

No `HTTPRoute`, observar:

```text
Accepted=True
ResolvedRefs=True
```

Estas condições demonstram que a route foi aceite pelo parent e que as referências, como o Service backend, foram resolvidas.

---

# 16. Job de backup SQLite online

Persistência e backup resolvem problemas diferentes.

```text
PVC
→ mantém o ficheiro para além do ciclo de vida do Pod

backup
→ cria uma cópia independente que pode ser usada no restore
```

Copiar diretamente um ficheiro SQLite enquanto a aplicação escreve pode produzir uma cópia inconsistente. O laboratório usa a API de backup SQLite através de `SQLite3::backup()`.

```text
source database.sqlite
       ↓ SQLite3::backup()
backup database-online.sqlite
       ↓
PRAGMA integrity_check
       ↓
SHA256
```

O Job deve terminar com evidência equivalente a:

```text
MARKER_BACKUP=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
```

## 16.1. Porque a aplicação pode continuar online?

A API de backup SQLite cria uma cópia consistente através do mecanismo próprio da base de dados. O exercício não depende de copiar cegamente o ficheiro enquanto está a ser usado.

---

# 17. CronJob

Um CronJob cria Jobs segundo uma expressão de calendário.

No laboratório:

```yaml
schedule: "0 3 * * *"
timeZone: Europe/Lisbon
suspend: true
```

Interpretar:

```text
03:00 no fuso Europe/Lisbon
+
suspenso durante a aula
```

Para não depender da hora da formação, é criado manualmente um Job a partir do template do CronJob.

---

# 18. Retirar o backup para fora do cluster

`backup-pvc` continua a ser storage `local-path`. Se a cópia existir apenas noutro PVC do mesmo Node, continua exposta a um domínio de falha comum.

Por isso o laboratório cria `backup-reader` e utiliza `kubectl cp`:

```text
backup-pvc
    ↓
backup-reader
    ↓ kubectl cp
máquina de administração
    ↓
database-online.sqlite
```

A validação mínima inclui:

```bash
test -s ./database-online.sqlite
```

Isto prova que existe uma cópia não vazia fora do storage Kubernetes utilizado pela aplicação.

---

# 19. Health gate antes da operação destrutiva

Antes de eliminar a PVC primária, é obrigatório provar que o estado anterior é saudável e que o backup é recuperável.

Validar:

```text
Deployment Symfony saudável
symfony-data Bound
backup-pvc Bound
Job de backup Complete
MARKER_BACKUP=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
database-online.sqlite copiado para fora do cluster
/health = HTTP 200
```

Se algum ponto falhar, parar e diagnosticar antes de apagar storage.

---

# 20. Falha controlada A — perda do Pod

Eliminar apenas o Pod da aplicação:

```text
Pod desaparece
   ↓
Deployment reconcilia
   ↓
mesma PVC
   ↓
mesmo database.sqlite
   ↓
marcador continua disponível
```

Conclusão:

```text
perda do Pod
→ persistência resolve
→ backup não foi necessário
```

---

# 21. Falha controlada B — eliminação da PVC

Agora o exercício é diferente:

```text
Deployment escalado para 0
      ↓
PVC symfony-data eliminada
      ↓
PV antigo removido por reclaimPolicy Delete
      ↓
dados primários deixam de existir
```

Este cenário representa **perda lógica do storage primário**, não perda física do Worker.

A recuperação exige o backup.

---

# 22. Restore para nova PVC/PV

O laboratório cria uma nova PVC `symfony-data` e um Job de restore que monta simultaneamente:

```text
backup-pvc      → read-only
symfony-data    → destino novo
```

O restore copia:

```text
database-online.sqlite
        ↓
database.sqlite
```

Depois valida:

```text
MARKER_RESTORE=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
SHA256_RESTORE=<mesmo hash>
```

A aplicação é novamente escalada para uma réplica e deve confirmar:

```text
MARKER_FINAL=persistencia-sessao5-ok
INTEGRITY_FINAL=ok
/health = HTTP 200
```

O PV resultante é um **novo PV**, mesmo que a claim volte a chamar-se `symfony-data`.

---

# 23. Persistência, backup e Alta Disponibilidade

## Persistência

```text
Pod eliminado
→ PVC permanece
→ dados permanecem
```

## Backup

```text
dados primários perdidos
→ cópia independente disponível
→ restore
→ integridade validada
```

## Alta Disponibilidade

O laboratório não transforma SQLite + `local-path` numa solução de HA.

```text
uma réplica Symfony
+
um ficheiro SQLite
+
PV local a um Worker
```

é adequado para demonstrar mecanismos Kubernetes, mas não representa uma arquitetura distribuída tolerante à perda física do Node.

Conclusão:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

---

# 24. Troubleshooting orientado por evidência

Antes de corrigir, classificar a camada da falha.

| Evidência | Interpretação inicial |
|---|---|
| Pod `Pending`, `NODE=<none>`, `FailedScheduling` | scheduling |
| PVC `Pending` sem consumidor e `WaitForFirstConsumer` | estado esperado |
| PVC continua `Pending` depois do consumidor | provisioning/storage |
| Pod tem Node e apresenta `FailedMount` | mount/storage |
| Service sem addresses no EndpointSlice | selector/labels/backends |
| HTTPRoute sem `Accepted=True` | aceitação/routing |
| HTTPRoute sem `ResolvedRefs=True` | referência a backend/objeto |
| backup sem `INTEGRITY_CHECK=ok` | backup não validado |

Método:

```text
SINTOMA
  ↓
kubectl get
  ↓
kubectl describe
  ↓
Events
  ↓
logs quando aplicável
  ↓
CLASSIFICAR A CAMADA
  ↓
HIPÓTESE
  ↓
CORREÇÃO
  ↓
VALIDAÇÃO
```

---

# 25. Resumo da sessão

```text
Deployment reconcilia
DaemonSet cobre Nodes elegíveis
StatefulSet fornece identidade estável
Headless Service fornece DNS individual
PVC solicita storage
StorageClass + provisioner criam PV
WaitForFirstConsumer coordena storage e scheduling
local-path implica afinidade ao Node
SQLite persistente vive numa PVC
Service depende de selectors e EndpointSlices
Ingress e Gateway API encaminham HTTP
Job executa trabalho finito
CronJob agenda Jobs
SQLite3::backup cria cópia consistente
PRAGMA integrity_check valida a base
perda do Pod é resolvida por persistência
perda da PVC exige backup + restore
Persistência ≠ Backup ≠ Alta Disponibilidade
```

---

# 26. Exercícios de consolidação

1. Explica por que `web-1` pode reaparecer com o mesmo nome e UID diferente.
2. Explica por que uma PVC `Pending` pode ser normal com `WaitForFirstConsumer`.
3. Indica que evidência distingue `FailedScheduling` de `FailedMount`.
4. Explica por que um Service pode existir sem conseguir encaminhar tráfego.
5. Distingue `IngressClass`, `GatewayClass`, `Gateway` e `HTTPRoute`.
6. Explica por que copiar diretamente um ficheiro SQLite em utilização pode ser inadequado.
7. Justifica a utilização de `PRAGMA integrity_check` e SHA256 no backup/restore.
8. Explica por que `backup-pvc` sozinho não é proteção suficiente contra perda física do Worker.
9. Distingue a recuperação após perda de Pod da recuperação após eliminação da PVC.
10. Explica por que este laboratório não deve ser apresentado como uma arquitetura de Alta Disponibilidade.

## Regra final de evidência

A Sessão 5 está concluída quando consegues **apresentar e explicar**:

```text
reconciliação de Deployment
+
DaemonSet em Nodes elegíveis
+
identidade de StatefulSet + Headless DNS
+
WaitForFirstConsumer observado
+
PV local + nodeAffinity interpretados
+
persistência SQLite comprovada
+
Service quebrado diagnosticado por selector/EndpointSlice
+
Ingress funcional
+
Gateway + HTTPRoute aceites/resolvidos
+
backup SQLite com marcador + integrity_check
+
backup copiado para fora do cluster
+
perda de Pod recuperada sem restore
+
eliminação da PVC recuperada por restore
+
Persistência ≠ Backup ≠ Alta Disponibilidade
```
