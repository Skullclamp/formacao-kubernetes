# Laboratório Integrado — Sessão 5
## Kubernetes Admin II: Workloads, Networking, Storage, Backup e Recuperação

**Sessão:** 5  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01` + `k8s-wk-03`  
**Kubernetes:** `1.36.4`  
**Cenário:** cluster Kubernetes on-premises com Calico, `local-path-provisioner`, Traefik e Symfony Demo com SQLite

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

> Nomes de Pods, ReplicaSets, UIDs, timestamps, PVs, PVCs e IPs de Pods variam entre execuções. Os outputs apresentados representam a evidência essencial e não texto para comparar carácter a carácter.

> Este laboratório foi validado de ponta a ponta num cluster real com Kubernetes `1.36.4`. Sempre que Events ou nomes gerados variarem entre versões/execuções, deve ser interpretada a causa e não comparado o texto literalmente.

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
Symfony:                   8.1
PHP:                       8.4
Imagem Symfony:            ghcr.io/skullclamp/symfony-demo:1.1.0
Base de dados:             SQLite
Ficheiro SQLite:           /var/www/html/data/database.sqlite
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
Symfony + SQLite persistente em PVC
      ↓
Service + DNS + EndpointSlice
      ↓
Ingress Traefik
      ↓
GatewayClass → Gateway → HTTPRoute
      ↓
Job de backup SQLite online
      ↓
CronJob
      ↓
backup fora do cluster
      ↓
perda de Pod → persistência
      ↓
eliminação da PVC → perda lógica
      ↓
restore → integrity_check
```

Todos os comandos administrativos são executados no **`k8s-cp-01`**. Os Workers executam workloads de acordo com o scheduler e as restrições de storage.

A infraestrutura seguinte deve existir antes do laboratório: Calico, CoreDNS, `local-path-provisioner`, StorageClass `local-path`, Gateway API CRDs, Traefik, IngressClass `traefik`, GatewayClass `traefik` e NodePorts `30080/30443`.

> Nesta sessão a Symfony Demo usa **uma réplica** quando está ligada ao ficheiro SQLite persistente. SQLite é usado para simplificar o caso prático e concentrar a atenção nos mecanismos Kubernetes. O escalamento horizontal da aplicação com estado partilhado não é o objetivo deste exercício.

## 0.1. Garantir o repositório e entrar na diretoria de trabalho

Os comandos `kubectl apply -f ../manifests/...` dependem dos recursos do repositório. Uma shell nova pode abrir em `$HOME`, por isso não assumimos que o terminal já se encontra dentro do clone.

```bash
clear

REPO_DIR="$HOME/formacao-kubernetes"
REPO_URL="https://github.com/Skullclamp/formacao-kubernetes.git"

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" switch main
  git -C "$REPO_DIR" pull --ff-only origin main
elif [ -e "$REPO_DIR" ]; then
  BACKUP_DIR="${REPO_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO_DIR" "$BACKUP_DIR"
  echo "Diretoria anterior preservada em: $BACKUP_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
else
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
fi

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short

cd "$REPO_DIR/sessao-05/labs"
pwd
ls ../manifests/
```

### O que observar

- a branch ativa deve ser `main`;
- `pull --ff-only` evita criar merges locais inesperados;
- se existir uma diretoria não-Git com o mesmo nome, ela é preservada antes do clone;
- o final de `pwd` deve ser:

```text
/formacao-kubernetes/sessao-05/labs
```

---

# CP1 — Pré-flight e namespace

### O que estamos a fazer

Confirmar a baseline antes de criar recursos da sessão.

### Porque é necessário

Se um componente base estiver indisponível, uma falha posterior pode ser atribuída ao workload errado.

```bash
clear
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

Criar o namespace de forma repetível e defini-lo no contexto atual:

```bash
clear
kubectl create namespace sessao5 \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl config set-context --current --namespace=sessao5
kubectl get namespace sessao5
```

---

# CP2 — Deployment Symfony e reconciliação

### O que estamos a fazer

Criar uma réplica da Symfony Demo e eliminar o respetivo Pod.

### Porque é necessário

Queremos observar a cadeia `Deployment → ReplicaSet → Pod` e a reconciliação do estado desejado. Uma única réplica é suficiente para demonstrar o mecanismo e mantém o percurso alinhado com a utilização posterior de SQLite.

```bash
clear
kubectl create deployment symfony-demo \
  --image=ghcr.io/skullclamp/symfony-demo:1.1.0 \
  --replicas=1

kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get deployment symfony-demo
kubectl get replicasets
kubectl get pods -l app=symfony-demo -o wide
```

Guardar a identidade atual e eliminar o Pod:

```bash
clear
POD_ANTIGO=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')
UID_ANTIGO=$(kubectl get pod "$POD_ANTIGO" \
  -o jsonpath='{.metadata.uid}')

kubectl delete pod "$POD_ANTIGO" --wait=true
kubectl rollout status deployment/symfony-demo --timeout=300s

POD_NOVO=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')
UID_NOVO=$(kubectl get pod "$POD_NOVO" \
  -o jsonpath='{.metadata.uid}')

echo "POD_ANTIGO=$POD_ANTIGO"
echo "UID_ANTIGO=$UID_ANTIGO"
echo "POD_NOVO=$POD_NOVO"
echo "UID_NOVO=$UID_NOVO"
```

### Evidência

- continua a existir uma réplica disponível;
- o Pod substituto tem outra identidade;
- o Deployment repôs automaticamente o estado desejado.

---

# CP3 — DaemonSet

### O que estamos a fazer

Executar um Pod em cada Node elegível.

### Porque é necessário

O exercício demonstra que “um Pod por Node” significa, de forma rigorosa, **um Pod por Node elegível**.

```bash
clear
kubectl apply -f ../manifests/01-daemonset-demo.yaml
kubectl rollout status daemonset/daemon-demo --timeout=300s
kubectl get daemonset daemon-demo
kubectl get pods -l app=daemon-demo -o wide
```

Resultado esperado com o taint `NoSchedule` do Control Plane:

```text
k8s-wk-01 → 1 Pod
k8s-wk-03 → 1 Pod
```

---

# CP4 — StatefulSet, ordinais e Headless Service

### O que estamos a fazer

Criar um Headless Service e um StatefulSet de Nginx.

### Porque é necessário

Antes de juntar storage à aplicação, queremos isolar a noção de **identidade estável**.

```bash
clear
kubectl apply -f ../manifests/02-web-headless.yaml
kubectl apply -f ../manifests/03-web-statefulset.yaml
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
clear
kubectl run debug \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/debug --timeout=120s

kubectl exec debug -- nslookup web-0.web.sessao5.svc.cluster.local
kubectl exec debug -- nslookup web-1.web.sessao5.svc.cluster.local
kubectl get pods -l app=web -o wide
```

### Evidência

O DNS individual resolve para o IP do Pod correspondente.

---

# CP6 — Identidade após recriação

Guardar UID e eliminar `web-1`:

```bash
clear
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
clear
kubectl apply -f ../manifests/04-test-pvc.yaml
kubectl get pvc test-pvc
```

Com `WaitForFirstConsumer`, é esperado:

```text
test-pvc   Pending
```

Criar o consumidor:

```bash
clear
kubectl apply -f ../manifests/05-test-pod.yaml
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
clear
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

### Troubleshooting — não confundir scheduling com storage

Um Pod `Pending` não significa automaticamente “problema do Scheduler”, e uma PVC `Pending` também não significa automaticamente “provisioner avariado”. Identificar primeiro a camada que falhou:

```text
Pod Pending + NODE=<none> + FailedScheduling
→ problema de elegibilidade/scheduling

PVC Pending sem consumidor + WaitForFirstConsumer
→ estado esperado antes de existir um consumidor elegível

PVC continua Pending depois de existir consumidor
→ kubectl describe pvc + Events + estado do provisioner

Pod já tem NODE, mas fica ContainerCreating + FailedMount/FailedAttachVolume
→ problema de volume/mount/attach, não de scheduling
```

Com `local-path-provisioner`, investigar sobretudo `kubectl describe pvc`, `kubectl describe pod`, Events e logs do provisioner. `FailedAttachVolume` é mais típico de storage que exige attach; não deve ser assumido neste laboratório.

---

# CP8 — Persistência sem falso positivo

### O que estamos a fazer

Escrever dados **depois** de o Pod arrancar, eliminar o Pod e recriá-lo sem voltar a escrever o ficheiro.

```bash
clear
kubectl exec test-storage -- \
  sh -c 'echo "Sessao 5 - persistencia OK" > /data/prova.txt'

kubectl exec test-storage -- cat /data/prova.txt

kubectl delete pod test-storage --wait=true
kubectl apply -f ../manifests/05-test-pod.yaml
kubectl wait --for=condition=Ready pod/test-storage --timeout=300s
kubectl exec test-storage -- cat /data/prova.txt
```

Esperado:

```text
Sessao 5 - persistencia OK
```

A prova seria inválida se o comando de arranque do novo Pod voltasse a criar `prova.txt`.

Limpar o PVC de teste:

```bash
clear
kubectl delete pod test-storage --wait=true
kubectl delete pvc test-pvc --wait=true
```

---

# CP9 — Symfony Demo com SQLite persistente

### O que estamos a fazer

Substituir o Deployment inicial por uma variante com uma PVC montada em `/var/www/html/data`.

### Porque é necessário

A imagem contém uma base SQLite inicial em:

```text
/var/www/html/data/database.sqlite
```

Se montássemos diretamente uma PVC vazia sobre `/var/www/html/data`, o conteúdo existente na imagem ficaria oculto. Por isso utilizamos um `initContainer` que copia a base inicial apenas quando a PVC ainda não contém `database.sqlite`.

Eliminar o Deployment inicial e criar a PVC + Deployment persistente:

```bash
clear
kubectl delete deployment symfony-demo --wait=true

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: symfony-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: symfony-demo
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: symfony-demo
  template:
    metadata:
      labels:
        app: symfony-demo
    spec:
      initContainers:
        - name: seed-sqlite
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - sh
            - -c
            - |
              set -eu
              if [ ! -f /mnt-data/database.sqlite ]; then
                cp /var/www/html/data/database.sqlite /mnt-data/database.sqlite
              fi
              chmod 0666 /mnt-data/database.sqlite
          volumeMounts:
            - name: data
              mountPath: /mnt-data
      containers:
        - name: symfony-demo
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 2
          volumeMounts:
            - name: data
              mountPath: /var/www/html/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: symfony-data
EOF

kubectl rollout status deployment/symfony-demo --timeout=300s
kubectl get pod -l app=symfony-demo -o wide
kubectl get pvc symfony-data
```

### Porque `strategy: Recreate`?

A aplicação utiliza um ficheiro SQLite único. Nesta sessão evitamos ter dois Pods da aplicação a escrever simultaneamente o mesmo ficheiro durante uma atualização.

### Criar um marcador de laboratório

```bash
clear
POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -i "$POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
$pdo->exec('CREATE TABLE IF NOT EXISTS lab_marker (id INTEGER PRIMARY KEY, valor TEXT NOT NULL)');
$pdo->exec("INSERT OR REPLACE INTO lab_marker (id, valor) VALUES (1, 'persistencia-sessao5-ok')");
echo $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn(), PHP_EOL;
PHP
```

Esperado:

```text
persistencia-sessao5-ok
```

Observar o PV associado:

```bash
clear
PV=$(kubectl get pvc symfony-data -o jsonpath='{.spec.volumeName}')
kubectl describe pv "$PV"
```

Ponto essencial:

```text
PVC symfony-data
      ↓
PV local
      ↓
nodeAffinity
      ↓
dados fisicamente dependentes desse Worker
```

---

# CP10 — Service, DNS e troubleshooting com EndpointSlice

### O que estamos a fazer

Criar deliberadamente um Service com selector errado.

### Porque é necessário

Queremos diagnosticar a cadeia `Service → selector → Pods → EndpointSlice` antes de corrigir.

```bash
clear
kubectl apply -f ../manifests/10-symfony-service-broken.yaml
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
clear
kubectl patch service symfony-demo \
  -p '{"spec":{"selector":{"app":"symfony-demo"}}}'

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

```bash
clear
kubectl apply -f ../manifests/11-symfony-ingress.yaml
kubectl get ingress symfony-demo
kubectl describe ingress symfony-demo

WORKER_IP=$(kubectl get node k8s-wk-01 \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

echo "$WORKER_IP"

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
clear
kubectl get gatewayclass traefik

kubectl apply -f ../manifests/12-symfony-gateway.yaml
kubectl apply -f ../manifests/13-symfony-httproute.yaml

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
clear
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

# CP13 — Job de backup SQLite online

### O que estamos a fazer

Criar uma PVC para backups e executar um Job que usa a API de backup do SQLite.

### Porque é necessário

Copiar diretamente o ficheiro de uma base SQLite enquanto a aplicação escreve pode produzir uma cópia inconsistente. Neste exercício utilizamos `SQLite3::backup()` para criar uma cópia consistente **sem parar a aplicação**.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: sqlite-online-backup
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: backup
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - php
            - -r
            - |
              $sourcePath = '/source/database.sqlite';
              $backupPath = '/backup/database-online.sqlite';

              if (file_exists($backupPath)) {
                  unlink($backupPath);
              }

              $source = new SQLite3($sourcePath, SQLITE3_OPEN_READONLY);
              $backup = new SQLite3($backupPath);

              if (!$source->backup($backup)) {
                  fwrite(STDERR, "ERRO_BACKUP\n");
                  exit(1);
              }

              $backup->close();
              $source->close();

              $check = new PDO('sqlite:' . $backupPath);
              echo 'MARKER_BACKUP=' .
                  $check->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                  PHP_EOL;

              echo 'INTEGRITY_CHECK=' .
                  $check->query('PRAGMA integrity_check')->fetchColumn() .
                  PHP_EOL;

              echo 'SHA256_BACKUP=' .
                  hash_file('sha256', $backupPath) .
                  PHP_EOL;
          volumeMounts:
            - name: source
              mountPath: /source
              readOnly: true
            - name: backup
              mountPath: /backup
      volumes:
        - name: source
          persistentVolumeClaim:
            claimName: symfony-data
        - name: backup
          persistentVolumeClaim:
            claimName: backup-pvc
EOF

kubectl wait \
  --for=condition=Complete \
  job/sqlite-online-backup \
  --timeout=300s

kubectl logs job/sqlite-online-backup
kubectl get pvc symfony-data backup-pvc -o wide
kubectl get deployment symfony-demo
```

Esperado:

```text
MARKER_BACKUP=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
```

A aplicação deve continuar disponível:

```bash
clear
curl -sS -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

> `backup-pvc` continua a ser storage `local-path`. Uma cópia noutro PVC do mesmo Worker não protege contra perda física desse Worker. Por isso o laboratório retira também uma cópia para fora do cluster.

---

# CP14 — CronJob de backup

### O que estamos a fazer

Transformar o mesmo princípio de backup numa tarefa agendada.

O CronJob fica suspenso para não depender da hora da aula. Criamos depois um Job manual a partir do template do CronJob.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sqlite-backup-daily
spec:
  schedule: "0 3 * * *"
  timeZone: Europe/Lisbon
  suspend: true
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: backup
              image: ghcr.io/skullclamp/symfony-demo:1.1.0
              command:
                - php
                - -r
                - |
                  $sourcePath = '/source/database.sqlite';
                  $backupPath = '/backup/database-cron.sqlite';

                  if (file_exists($backupPath)) {
                      unlink($backupPath);
                  }

                  $source = new SQLite3($sourcePath, SQLITE3_OPEN_READONLY);
                  $backup = new SQLite3($backupPath);

                  if (!$source->backup($backup)) {
                      fwrite(STDERR, "ERRO_BACKUP\n");
                      exit(1);
                  }

                  $backup->close();
                  $source->close();

                  $check = new PDO('sqlite:' . $backupPath);
                  echo 'MARKER_CRON=' .
                      $check->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                      PHP_EOL;
                  echo 'INTEGRITY_CHECK=' .
                      $check->query('PRAGMA integrity_check')->fetchColumn() .
                      PHP_EOL;
          volumeMounts:
            - name: source
              mountPath: /source
              readOnly: true
            - name: backup
              mountPath: /backup
          volumes:
            - name: source
              persistentVolumeClaim:
                claimName: symfony-data
            - name: backup
              persistentVolumeClaim:
                claimName: backup-pvc
EOF

kubectl get cronjob sqlite-backup-daily -o wide

kubectl create job \
  --from=cronjob/sqlite-backup-daily \
  sqlite-backup-manual

kubectl wait \
  --for=condition=Complete \
  job/sqlite-backup-manual \
  --timeout=300s

kubectl logs job/sqlite-backup-manual
```

Esperado:

```text
MARKER_CRON=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
```

---

# CP15 — Retirar o backup para fora do cluster

Criar um Pod leitor da `backup-pvc`:

```bash
clear
kubectl apply -f ../manifests/17-backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader --timeout=300s
kubectl exec backup-reader -- ls -lh /backup
```

Copiar a base de backup para a máquina de administração:

```bash
clear
kubectl cp \
  backup-reader:/backup/database-online.sqlite \
  ./database-online.sqlite

test -s ./database-online.sqlite
ls -lh ./database-online.sqlite
kubectl delete pod backup-reader --wait=true
```

Agora existe uma cópia fora do storage Kubernetes usado pela aplicação.

> **Persistência ≠ Backup.** Um PVC persistente ajuda a sobreviver à recriação do Pod; não substitui uma política de backup.

---

# CP16 — Falha controlada A: perda do Pod da aplicação

### O que estamos a fazer

Eliminar apenas o Pod Symfony, mantendo a PVC.

```bash
clear
POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$POD" --wait=true
kubectl rollout status deployment/symfony-demo --timeout=300s

NEW_POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -i "$NEW_POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
echo $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn(), PHP_EOL;
PHP
```

Esperado:

```text
persistencia-sessao5-ok
```

Conclusão:

```text
perda do Pod
→ Deployment reconcilia
→ mesma PVC
→ mesmo database.sqlite
→ dados permanecem
→ PERSISTÊNCIA comprovada
```

---

# CP17 — Falha controlada B: eliminação da PVC

### O que estamos a fazer

Simular perda lógica do storage primário e recuperar os dados a partir da cópia mantida em `backup-pvc`.

Primeiro retirar consumidores que possam manter a PVC original em utilização:

```bash
clear
kubectl delete job sqlite-online-backup sqlite-backup-manual \
  --ignore-not-found \
  --wait=true

kubectl scale deployment/symfony-demo --replicas=0
kubectl wait \
  --for=delete pod \
  -l app=symfony-demo \
  --timeout=120s || true
```

Guardar a identidade do PV e eliminar a PVC:

```bash
clear
OLD_PV=$(kubectl get pvc symfony-data \
  -o jsonpath='{.spec.volumeName}')

echo "OLD_PV=$OLD_PV"

kubectl delete pvc symfony-data --wait=true

for i in $(seq 1 60); do
  if ! kubectl get pv "$OLD_PV" >/dev/null 2>&1; then
    echo "PV_ANTIGO_REMOVIDO=SIM"
    break
  fi
  sleep 2
done

kubectl get pv "$OLD_PV" 2>&1 || true
```

Com `reclaimPolicy: Delete`, o PV associado acaba por ser removido pelo provisioner.

> Este cenário representa **eliminação lógica da PVC**. Não representa perda física do Worker.

---

# CP18 — Restore para uma nova PVC

### O que estamos a fazer

Criar uma PVC vazia e restaurar `database-online.sqlite` para o novo volume.

```bash
clear
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: symfony-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 256Mi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: sqlite-restore
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: restore
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          command:
            - php
            - -r
            - |
              $source = '/backup/database-online.sqlite';
              $restore = '/restore/database.sqlite';

              if (!file_exists($source)) {
                  fwrite(STDERR, "BACKUP_NAO_ENCONTRADO\n");
                  exit(1);
              }

              if (!copy($source, $restore)) {
                  fwrite(STDERR, "ERRO_RESTORE\n");
                  exit(1);
              }

              chmod($restore, 0666);

              $pdo = new PDO('sqlite:' . $restore);
              echo 'MARKER_RESTORE=' .
                  $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
                  PHP_EOL;

              $integrity = $pdo->query('PRAGMA integrity_check')->fetchColumn();
              echo 'INTEGRITY_CHECK=' . $integrity . PHP_EOL;

              echo 'SHA256_BACKUP=' . hash_file('sha256', $source) . PHP_EOL;
              echo 'SHA256_RESTORE=' . hash_file('sha256', $restore) . PHP_EOL;

              if ($integrity !== 'ok') {
                  fwrite(STDERR, "INTEGRIDADE_INVALIDA\n");
                  exit(1);
              }
          volumeMounts:
            - name: backup
              mountPath: /backup
              readOnly: true
            - name: restore
              mountPath: /restore
      volumes:
        - name: backup
          persistentVolumeClaim:
            claimName: backup-pvc
        - name: restore
          persistentVolumeClaim:
            claimName: symfony-data
EOF

kubectl wait \
  --for=condition=Complete \
  job/sqlite-restore \
  --timeout=300s

kubectl logs job/sqlite-restore
kubectl get pvc symfony-data backup-pvc -o wide
```

Esperado:

```text
MARKER_RESTORE=persistencia-sessao5-ok
INTEGRITY_CHECK=ok
SHA256_BACKUP=<hash>
SHA256_RESTORE=<mesmo hash>
```

Reativar a aplicação:

```bash
clear
kubectl scale deployment/symfony-demo --replicas=1
kubectl rollout status deployment/symfony-demo --timeout=300s

POD=$(kubectl get pod -l app=symfony-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -i "$POD" -c symfony-demo -- php <<'PHP'
<?php
$pdo = new PDO('sqlite:/var/www/html/data/database.sqlite');
echo 'MARKER_FINAL=' .
    $pdo->query('SELECT valor FROM lab_marker WHERE id=1')->fetchColumn() .
    PHP_EOL;
echo 'INTEGRITY_FINAL=' .
    $pdo->query('PRAGMA integrity_check')->fetchColumn() .
    PHP_EOL;
PHP

curl -sS -i \
  -H "Host: symfony-ingress.lab" \
  "http://${WORKER_IP}:30080/health"
```

Esperado:

```text
MARKER_FINAL=persistencia-sessao5-ok
INTEGRITY_FINAL=ok
HTTP/1.1 200 OK
{"status":"ok"}
```

Observar que o PV é novo:

```bash
clear
NEW_PV=$(kubectl get pvc symfony-data \
  -o jsonpath='{.spec.volumeName}')

echo "OLD_PV=$OLD_PV"
echo "NEW_PV=$NEW_PV"

kubectl get pod -l app=symfony-demo -o wide
kubectl get pvc -o wide
kubectl describe pv "$NEW_PV"
```

---

# CP19 — Síntese, evidências e limpeza

A experiência deve permitir explicar:

```text
CENÁRIO A — Pod perdido
Pod desaparece
   ↓
Deployment recria
   ↓
PVC mantém-se
   ↓
database.sqlite mantém-se
   ↓
PERSISTÊNCIA
```

```text
CENÁRIO B — PVC eliminada
storage primário desaparece
   ↓
PV antigo é removido
   ↓
nova PVC / novo PV
   ↓
restore a partir do backup
   ↓
PRAGMA integrity_check = ok
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

## Checklist final de autoavaliação

- [ ] Consigo explicar a relação `Deployment → ReplicaSet → Pod` e demonstrar reconciliação.
- [ ] Consigo explicar por que um DaemonSet cria Pods apenas nos Nodes elegíveis.
- [ ] Distingo identidade estável de StatefulSet de persistência de dados.
- [ ] Consigo validar DNS individual de Pods através de um Headless Service.
- [ ] Consigo explicar por que o nome `web-1` pode manter-se enquanto o UID do Pod muda.
- [ ] Consigo explicar `WaitForFirstConsumer` e distinguir um `Pending` esperado de uma falha.
- [ ] Consigo distinguir falha de scheduling de falha de provisionamento/mount de storage usando `describe` e Events.
- [ ] Consigo identificar o PV criado dinamicamente e interpretar a respetiva `nodeAffinity`.
- [ ] Consigo provar persistência sem criar um falso positivo no arranque do Pod.
- [ ] Consigo explicar o papel do `initContainer` no seed da base SQLite.
- [ ] Consigo diagnosticar um Service com selector incorreto através de labels e EndpointSlice.
- [ ] Consigo validar Ingress Traefik e explicar o percurso até ao Pod.
- [ ] Consigo distinguir a porta do listener Gateway da porta externa NodePort.
- [ ] Consigo interpretar `Accepted=True` e `ResolvedRefs=True` num HTTPRoute.
- [ ] Consigo executar e validar um backup SQLite online através de `SQLite3::backup()`.
- [ ] Sei usar `PRAGMA integrity_check` como uma das evidências de consistência do backup/restore.
- [ ] Consigo explicar a finalidade de um CronJob e criar uma execução manual a partir do seu template.
- [ ] Sei explicar por que um backup mantido apenas noutro PVC local não protege contra perda física do Worker.
- [ ] Consigo provar que a perda do Pod é recuperada por persistência sem recorrer ao backup.
- [ ] Consigo explicar a diferença entre perda do Pod, perda lógica da PVC e perda física do Node/storage.
- [ ] Consigo restaurar a aplicação para uma nova PVC/PV e validar marcador, integridade e health endpoint.
- [ ] Distingo claramente **persistência**, **backup** e **Alta Disponibilidade**.

## Regra de evidência da Sessão 5

O laboratório fica concluído quando o formando consegue **apresentar e explicar**, e não apenas executar:

```text
Deployment reconciliado após perda de Pod
+
DaemonSet apenas nos Nodes elegíveis
+
StatefulSet com identidade nominal demonstrada
+
Headless DNS validado
+
PVC Pending antes do consumidor por WaitForFirstConsumer
+
PVC Bound e PV dinamicamente criado depois do consumidor
+
camada da falha identificada por NODE / PVC / Events / mount
+
persistência comprovada sem falso positivo
+
Service quebrado diagnosticado por selector + EndpointSlice
+
Ingress funcional
+
Gateway + HTTPRoute aceites e resolvidos
+
backup SQLite online com integrity_check=ok
+
CronJob compreendido e execução manual validada
+
backup copiado para fora do storage Kubernetes da aplicação
+
perda do Pod recuperada pela persistência
+
eliminação lógica da PVC demonstrada
+
nova PVC / novo PV após restore
+
aplicação saudável e dados recuperados
+
PERSISTÊNCIA ≠ BACKUP ≠ ALTA DISPONIBILIDADE
```

Limpeza:

```bash
clear
kubectl config set-context --current --namespace=default
kubectl delete namespace sessao5 --wait=true
rm -f ./database-online.sqlite
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
CLASSIFICAR A CAMADA
  ↓
HIPÓTESE
  ↓
CORREÇÃO
  ↓
VALIDAÇÃO
```

Antes de corrigir, perguntar explicitamente:

```text
O Pod ainda não tem Node?
→ scheduling

O Pod tem Node mas não inicia e existem FailedMount/erros de volume?
→ storage/mount

A PVC continua Pending?
→ validar WaitForFirstConsumer, consumidor, provisioner e Events

O Service não tem endpoints?
→ selector/labels/EndpointSlice
```

Não acrescentar flags aleatórias, não apagar recursos indiscriminadamente e não confundir um estado transitório com uma falha persistente.