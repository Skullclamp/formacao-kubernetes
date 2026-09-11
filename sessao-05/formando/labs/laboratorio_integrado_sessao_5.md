# Laboratório Integrado — Sessão 5
## Kubernetes Admin II: Workloads, Networking, Storage, Backup e Recuperação

**Sessão:** 5  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`  
**Kubernetes:** `1.36.4`  
**Cenário:** cluster Kubernetes on-premises com Calico, `local-path-provisioner`, Traefik, Symfony Demo e PostgreSQL 16

Este laboratório segue a mesma organização pedagógica do laboratório integrado da Sessão 4. O objetivo **não é copiar comandos sem os compreender**. Em cada checkpoint deve ser possível explicar:

```text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
COMANDO / MANIFESTO
        ↓
FLAGS / CAMPOS
        ↓
OUTPUT ESPERADO
        ↓
O QUE OBSERVAR
        ↓
ERRO FREQUENTE / DECISÃO
        ↓
REGISTAR EVIDÊNCIA
```

A regra é:

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

> **Baseline validada:** este percurso foi ensaiado no cluster `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`, Kubernetes 1.36.4. O validador técnico do formador concluiu 48 verificações obrigatórias com **48 OK, 0 avisos e 0 falhas**.

> Nomes de Pods, ReplicaSets, UIDs, timestamps, PVs, PVCs e IPs de Pods variam. Os outputs apresentados representam a evidência essencial, não texto para comparar carácter a carácter.

---

# 0. Baseline e percurso

```text
Ubuntu:                    26.04.1 LTS
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
local-path-provisioner:    v0.0.37

Gateway API:               v1.6.1
Helm:                      v3.22.0
Traefik Chart:             41.5.0
Traefik Proxy:             v3.7.13
IngressClass:              traefik
GatewayClass:              traefik
entryPoint web:            8000
HTTP NodePort:             30080
HTTPS NodePort:            30443

Symfony Demo:              v3.1.0
Imagem Symfony:            ghcr.io/skullclamp/symfony-demo:1.1.0
PostgreSQL:                16
Namespace do laboratório:  sessao5
```

História técnica:

```text
cluster saudável
      ↓
Deployment Symfony + reconciliação
      ↓
DaemonSet
      ↓
StatefulSet + identidade + Headless DNS
      ↓
PVC → StorageClass → provisioner → PV
      ↓
WaitForFirstConsumer
      ↓
PostgreSQL StatefulSet
      ↓
Service + DNS + EndpointSlice
      ↓
Ingress Traefik
      ↓
GatewayClass → Gateway → HTTPRoute
      ↓
Job + CronJob
      ↓
backup fora do cluster
      ↓
perda de Pod → persistência
      ↓
eliminação da PVC → perda lógica
      ↓
restore
```

Todos os comandos administrativos são executados no **`k8s-cp-01`**. Os Workers executam workloads de acordo com o scheduler e as restrições de storage.

A infraestrutura seguinte já deve estar preparada antes do laboratório: Calico, CoreDNS, `local-path-provisioner`, StorageClass `local-path`, Gateway API CRDs, Traefik, IngressClass `traefik`, GatewayClass `traefik`, NodePorts `30080/30443`.

## 0.1. Diretoria de trabalho

Os comandos `kubectl apply -f ../../manifests/...` assumem que o repositório foi clonado e que o terminal está na mesma diretoria deste guião.

A partir de qualquer diretoria dentro do clone:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/sessao-05/formando/labs"
pwd
```

O final de `pwd` deve ser:

```text
/sessao-05/formando/labs
```

Confirmar também que os manifests estão acessíveis:

```bash
ls ../../manifests/
```

Se esta verificação falhar, corrigir a diretoria antes de avançar.

---

# CP1 — Pré-flight e namespace

### O que estamos a fazer

Confirmar a baseline antes de criar recursos da sessão.

### Porque é necessário

Se um componente base estiver indisponível, uma falha posterior pode ser atribuída ao workload errado.

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass local-path
kubectl get pods -n local-path-storage -o wide
kubectl get pods -n traefik -o wide
kubectl get svc -n traefik
kubectl get ingressclass traefik
kubectl get gatewayclass traefik
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
```

Evidência mínima:

```text
k8s-cp-01  Ready
k8s-wk-01  Ready
k8s-wk-03  Ready
StorageClass local-path
GatewayClass traefik Accepted=True
Traefik Service NodePort 80:30080 e 443:30443
```

Criar o namespace e defini-lo no contexto atual:

```bash
kubectl create namespace sessao5
kubectl config set-context --current --namespace=sessao5
```

---

# CP2 — Deployment Symfony e reconciliação

### O que estamos a fazer

Criar duas réplicas da Symfony Demo e eliminar uma delas.

### Porque é necessário

Queremos observar a cadeia `Deployment → ReplicaSet → Pods` e a reconciliação do estado desejado.

```bash
kubectl create deployment symfony-demo \
  --image=ghcr.io/skullclamp/symfony-demo:1.1.0 \
  --replicas=2

kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get deployment symfony-demo
kubectl get replicasets
kubectl get pods -l app=symfony-demo -o wide
```

Guardar e eliminar um Pod:

```bash
POD_SYMFONY=$(kubectl get pods -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$POD_SYMFONY" --wait=true
kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get pods -l app=symfony-demo -o wide
```

### Evidência

- continuam a existir duas réplicas;
- o Pod substituto tem outra identidade;
- o Deployment permanece responsável pelo estado desejado.

> **Não eliminar este Deployment.** É reutilizado por Service, Ingress e Gateway API.

---

# CP3 — DaemonSet

### O que estamos a fazer

Executar um Pod em cada Node elegível.

### Porque é necessário

O exercício demonstra que “um Pod por Node” significa, de forma rigorosa, **um Pod por Node elegível**.

```bash
kubectl apply -f ../../manifests/01-daemonset-demo.yaml
kubectl rollout status daemonset/daemon-demo --timeout=300s
kubectl get pods -l app=daemon-demo -o wide
```

Resultado esperado com o taint `NoSchedule` do Control Plane:

```text
k8s-wk-01 → 1 Pod
k8s-wk-03 → 1 Pod
```

### Registar evidência

```bash
kubectl get daemonset daemon-demo
kubectl get pods -l app=daemon-demo -o wide
```

---

# CP4 — StatefulSet, ordinais e Headless Service

### O que estamos a fazer

Criar um Headless Service e um StatefulSet de Nginx.

### Porque é necessário

Antes de juntar storage, queremos isolar a noção de **identidade estável**.

```bash
kubectl apply -f ../../manifests/02-web-headless.yaml
kubectl apply -f ../../manifests/03-web-statefulset.yaml
kubectl rollout status statefulset/web --timeout=300s
kubectl get statefulset web
kubectl get pods -l app=web -o wide
```

Observar os ordinais:

```text
web-0
web-1
web-2
```

> Um StatefulSet pode existir sem `volumeClaimTemplates`. Identidade estável e persistência são conceitos diferentes.

> Um StatefulSet **não garante distribuição por Nodes**. Se as réplicas surgirem em Nodes diferentes, isso é estado observado, não uma garantia do objeto.

---

# CP5 — DNS individual por Pod

Criar um Pod de diagnóstico:

```bash
kubectl run debug \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/debug --timeout=120s
```

Testar:

```bash
kubectl exec debug -- nslookup web-0.web.sessao5.svc.cluster.local
kubectl exec debug -- nslookup web-1.web.sessao5.svc.cluster.local
```

Comparar com:

```bash
kubectl get pods -l app=web -o wide
```

### Evidência

O DNS individual resolve para o IP do Pod correspondente.

---

# CP6 — Identidade após recriação

Guardar UID e eliminar `web-1`:

```bash
OLD_UID=$(kubectl get pod web-1 -o jsonpath='{.metadata.uid}')
kubectl delete pod web-1 --wait=true
kubectl wait --for=create pod/web-1 --timeout=120s
kubectl wait --for=condition=Ready pod/web-1 --timeout=300s
NEW_UID=$(kubectl get pod web-1 -o jsonpath='{.metadata.uid}')

echo "OLD_UID=$OLD_UID"
echo "NEW_UID=$NEW_UID"
```

Esperado:

```text
nome     = web-1 novamente
UID      = diferente
ordinal  = 1 novamente
```

Isto demonstra identidade nominal estável, não a sobrevivência do mesmo objeto Pod.

---

# CP7 — PVC e `WaitForFirstConsumer`

### O que estamos a fazer

Criar uma PVC sem consumidor e observar o estado antes de criar o Pod.

```bash
kubectl apply -f ../../manifests/04-test-pvc.yaml
kubectl get pvc test-pvc
```

Com `WaitForFirstConsumer`, é esperado:

```text
test-pvc   Pending
```

Criar o consumidor:

```bash
kubectl apply -f ../../manifests/05-test-pod.yaml
kubectl wait --for=condition=Ready pod/test-storage --timeout=300s
kubectl get pod test-storage -o wide
kubectl get pvc test-pvc
kubectl get pv
```

Agora é esperado:

```text
PVC Pending → Bound
```

Guardar o PV e observar afinidade:

```bash
PV=$(kubectl get pvc test-pvc -o jsonpath='{.spec.volumeName}')
kubectl describe pv "$PV"
```

Procurar:

```text
pv.kubernetes.io/provisioned-by: rancher.io/local-path
Node Affinity: kubernetes.io/hostname in [<NODE>]
Path: /opt/local-path-provisioner/...
```

> `local-path-provisioner` é um **external provisioner**, não um driver CSI.

---

# CP8 — Persistência sem falso positivo

### O que estamos a fazer

Escrever dados **depois** de o Pod arrancar, eliminar o Pod e recriá-lo sem voltar a escrever o ficheiro.

```bash
kubectl exec test-storage -- \
  sh -c 'echo "Sessao 5 - persistencia OK" > /data/prova.txt'

kubectl exec test-storage -- cat /data/prova.txt
```

Eliminar e recriar:

```bash
kubectl delete pod test-storage --wait=true
kubectl apply -f ../../manifests/05-test-pod.yaml
kubectl wait --for=condition=Ready pod/test-storage --timeout=300s
kubectl exec test-storage -- cat /data/prova.txt
```

Esperado:

```text
Sessao 5 - persistencia OK
```

A prova seria inválida se o comando de arranque do novo Pod voltasse a criar `prova.txt`.

Limpar o PVC de teste depois da evidência:

```bash
kubectl delete pod test-storage --wait=true
kubectl delete pvc test-pvc --wait=true
```

---

# CP9 — PostgreSQL 16 como StatefulSet

### O que estamos a fazer

Criar Secret, Headless Service, StatefulSet persistente e cliente PostgreSQL.

```bash
kubectl apply -f ../../manifests/06-postgres-secret.yaml
kubectl apply -f ../../manifests/07-postgres-headless.yaml
kubectl apply -f ../../manifests/08-postgres-statefulset.yaml
kubectl apply -f ../../manifests/09-pg-client.yaml

kubectl wait --for=create pod/postgres-0 --timeout=120s
kubectl wait --for=condition=Ready pod/postgres-0 --timeout=300s
kubectl wait --for=condition=Ready pod/pg-client --timeout=300s
```

Observar:

```bash
kubectl get statefulset postgres
kubectl get pod postgres-0 -o wide
kubectl get pvc
kubectl get pv
kubectl describe pod postgres-0
```

A readiness usa `pg_isready`, por isso `Ready=True` significa mais do que “o processo foi criado”.

Criar dados determinísticos:

```bash
kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE IF NOT EXISTS lab_marker(id integer PRIMARY KEY, mensagem text NOT NULL);"

kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
  -c "INSERT INTO lab_marker(id,mensagem) VALUES (1,'Dados criados na Sessao 5') ON CONFLICT (id) DO UPDATE SET mensagem=EXCLUDED.mensagem;"

kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo \
  -c "SELECT * FROM lab_marker;"
```

---

# CP10 — Service, DNS e troubleshooting com EndpointSlice

### O que estamos a fazer

Criar deliberadamente um Service com selector errado.

### Porque é necessário

Queremos diagnosticar a cadeia `Service → selector → Pods → EndpointSlice` antes de corrigir.

```bash
kubectl apply -f ../../manifests/10-symfony-service-broken.yaml
kubectl get service symfony-demo -o yaml
kubectl get pods -l app=symfony-demo --show-labels
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo \
  -o wide
```

O problema está em:

```text
Service selector: app=symfony-demo-ERRO
Pod labels:       app=symfony-demo
```

Corrigir:

```bash
kubectl patch service symfony-demo \
  -p '{"spec":{"selector":{"app":"symfony-demo"}}}'
```

Validar:

```bash
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo \
  -o wide

kubectl exec debug -- wget -qO- http://symfony-demo/health
```

Esperado:

```json
{"status":"ok"}
```

---

# CP11 — Ingress com Traefik

Aplicar:

```bash
kubectl apply -f ../../manifests/11-symfony-ingress.yaml
kubectl get ingress symfony-demo
kubectl describe ingress symfony-demo
```

Obter o IP do Worker 1:

```bash
WORKER_IP=$(kubectl get node k8s-wk-01 \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

echo "$WORKER_IP"
```

No ambiente validado:

```text
192.168.50.65
```

Testar:

```bash
curl -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

Esperado:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

Fluxo:

```text
cliente :30080
  ↓
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

---

# CP12 — Gateway API

### O que estamos a fazer

Interpretar a GatewayClass pré-instalada e criar Gateway + HTTPRoute.

```bash
kubectl get gatewayclass traefik
```

Esperado:

```text
CONTROLLER                      ACCEPTED
traefik.io/gateway-controller   True
```

> O formando **não cria a GatewayClass**. Ela faz parte da infraestrutura preparada.

Criar Gateway e Route:

```bash
kubectl apply -f ../../manifests/12-symfony-gateway.yaml
kubectl apply -f ../../manifests/13-symfony-httproute.yaml

kubectl wait --for=condition=Accepted gateway/symfony-gateway --timeout=120s
kubectl get gateway symfony-gateway -o wide
kubectl get httproute symfony-demo -o yaml
```

No status do HTTPRoute procurar:

```text
Accepted=True
ResolvedRefs=True
```

Testar:

```bash
curl -i \
  -H "Host: symfony-gateway.lab" \
  "http://${WORKER_IP}:30080/health"
```

Esperado:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

### Ponto crítico das portas

```text
Gateway listener       8000
        ↓
Traefik entryPoint web 8000
        ↓
Service Traefik          80
        ↓
NodePort               30080
```

O listener **não** usa `30080`; essa é a porta externa do NodePort.

---

# CP13 — Job de backup

Criar PVC e Job:

```bash
kubectl apply -f ../../manifests/14-backup-pvc.yaml
kubectl apply -f ../../manifests/15-postgres-backup-job.yaml

kubectl wait --for=condition=complete job/postgres-backup --timeout=300s
kubectl logs job/postgres-backup
kubectl get pvc backup-pvc
```

Esperado:

```text
Backup criado com sucesso: /backup/dump.sql
```

O Job é adequado porque o backup é uma tarefa finita:

```text
iniciar → executar pg_dump → terminar
```

---

# CP14 — CronJob

```bash
kubectl apply -f ../../manifests/16-postgres-backup-cronjob.yaml
kubectl get cronjob postgres-backup-daily
kubectl get cronjob postgres-backup-daily -o yaml
```

Observar:

```text
schedule: 0 3 * * *
timeZone: Europe/Lisbon
suspend: true
```

O CronJob fica suspenso durante a aula para não introduzir uma execução dependente da hora do laboratório.

---

# CP15 — Retirar o backup para fora do cluster

Criar o leitor:

```bash
kubectl apply -f ../../manifests/17-backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader --timeout=300s
kubectl exec backup-reader -- ls -lh /backup
kubectl exec backup-reader -- tar --help >/dev/null
```

Copiar:

```bash
kubectl cp \
  backup-reader:/backup/dump.sql \
  ./dump-symfony_demo.sql

test -s ./dump-symfony_demo.sql
ls -lh ./dump-symfony_demo.sql
kubectl delete pod backup-reader --wait=true
```

Agora existe uma cópia do dump fora do storage Kubernetes usado no laboratório.

---

# CP16 — Falha controlada A: perda do Pod

### O que estamos a fazer

Eliminar apenas `postgres-0`.

```bash
kubectl delete pod postgres-0 --wait=true
kubectl wait --for=create pod/postgres-0 --timeout=120s
kubectl wait --for=condition=Ready pod/postgres-0 --timeout=300s
```

Validar:

```bash
kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo \
  -c "SELECT * FROM lab_marker;"
```

Esperado: os dados permanecem.

Conclusão:

```text
perda do Pod
→ StatefulSet reconcilia
→ mesma PVC
→ dados permanecem
→ PERSISTÊNCIA comprovada
```

Isto **não comprova backup nem tolerância à perda física do Worker**.

---

# CP17 — Falha controlada B: perda lógica dos dados

Confirmar primeiro que o dump externo existe:

```bash
test -s ./dump-symfony_demo.sql
```

Eliminar StatefulSet e PVC primária:

```bash
kubectl delete statefulset postgres \
  --cascade=foreground \
  --wait=true

kubectl delete pvc data-postgres-0 --wait=true
kubectl get pvc
kubectl get pv
```

Recriar PostgreSQL:

```bash
kubectl apply -f ../../manifests/08-postgres-statefulset.yaml
kubectl wait --for=create pod/postgres-0 --timeout=120s
kubectl wait --for=condition=Ready pod/postgres-0 --timeout=300s
kubectl get pvc data-postgres-0
kubectl get pv
```

Confirmar que o dado antigo já não existe:

```bash
kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
  -c "SELECT * FROM lab_marker;"
```

Esperado nesta fase:

```text
ERROR: relation "lab_marker" does not exist
```

Este erro faz parte do exercício. O cenário chama-se **perda lógica dos dados / eliminação da PVC**. Não é uma simulação de perda física do Worker.

---

# CP18 — Restore por streaming

### O que estamos a fazer

Enviar o ficheiro local diretamente para `psql` executado no `pg-client`.

```bash
kubectl exec -i pg-client -- \
  psql \
  -h postgres \
  -U postgres \
  -d symfony_demo \
  -v ON_ERROR_STOP=1 \
  < ./dump-symfony_demo.sql
```

Validar:

```bash
kubectl exec pg-client -- \
  psql -h postgres -U postgres -d symfony_demo \
  -c "SELECT * FROM lab_marker;"
```

Esperado:

```text
1 | Dados criados na Sessao 5
```

Fluxo:

```text
dump local
   ↓ stdin
kubectl exec -i
   ↓
psql em pg-client
   ↓
Service postgres
   ↓
postgres-0
```

Não é necessário copiar o dump para o Pod PostgreSQL.

---

# CP19 — Síntese, evidências e limpeza

A experiência deve permitir explicar:

```text
CENÁRIO A — Pod perdido
Pod desaparece
   ↓
StatefulSet recria
   ↓
PVC mantém-se
   ↓
dados mantêm-se
   ↓
PERSISTÊNCIA
```

```text
CENÁRIO B — PVC eliminada
storage primário desaparece
   ↓
novo volume vazio
   ↓
restore a partir de cópia externa
   ↓
dados recuperados
   ↓
BACKUP + RECUPERAÇÃO
```

Conclusão:

```text
PERSISTÊNCIA
     ≠
BACKUP
     ≠
ALTA DISPONIBILIDADE
```

Checklist final:

```text
[ ] Deployment → ReplicaSet → Pods observado
[ ] reconciliação demonstrada
[ ] DaemonSet nos Nodes elegíveis
[ ] StatefulSet e ordinais observados
[ ] Headless Service e DNS por Pod validados
[ ] PVC Pending antes do consumidor
[ ] WaitForFirstConsumer compreendido
[ ] PV criado dinamicamente
[ ] nodeAffinity do PV observada
[ ] persistência validada sem falso positivo
[ ] PostgreSQL Ready através de pg_isready
[ ] Service com selector errado diagnosticado
[ ] EndpointSlice usado como evidência
[ ] Ingress responde via NodePort 30080
[ ] Gateway listener 8000 compreendido
[ ] HTTPRoute Accepted=True e ResolvedRefs=True
[ ] Job de backup Complete
[ ] CronJob analisado e suspenso
[ ] dump copiado para fora do cluster
[ ] perda do Pod recuperada por persistência
[ ] perda lógica da PVC demonstrada
[ ] restore por streaming concluído
```

Limpeza:

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace sessao5 --wait=true
```

Não remover:

```text
Calico
CoreDNS
Traefik
GatewayClass traefik
Gateway API CRDs
local-path-provisioner
StorageClass local-path
```

## Troubleshooting: ordem mínima de evidência

Quando algo falhar:

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
selectors / EndpointSlices / PVC / conditions
  ↓
HIPÓTESE
  ↓
CORREÇÃO
  ↓
VALIDAÇÃO
```

Não acrescentar flags aleatórias, não apagar recursos indiscriminadamente e não confundir um estado transitório com uma falha persistente.
