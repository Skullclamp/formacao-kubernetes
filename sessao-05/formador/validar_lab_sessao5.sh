#!/usr/bin/env bash
set -uo pipefail

# Validador técnico do Laboratório Integrado — Sessão 5
# Topologia esperada: k8s-cp-01 + k8s-wk-01 + k8s-wk-03
# Executa verificações de pré-requisitos e testes funcionais num namespace temporário.
# Gera um relatório TXT na diretoria atual.
#
# Uso:
#   chmod +x validar_lab_sessao5.sh
#   ./validar_lab_sessao5.sh
#
# Variáveis opcionais:
#   KEEP_NAMESPACE=1 ./validar_lab_sessao5.sh
#   TEST_SYMFONY=0   ./validar_lab_sessao5.sh
#
# Por omissão:
#   - cria namespace temporário;
#   - faz testes reais de workload/storage/networking;
#   - testa a imagem Symfony e /health;
#   - NÃO altera Calico, Traefik, StorageClass ou GatewayClass;
#   - elimina o namespace temporário no fim.

TS="$(date +%Y%m%d_%H%M%S)"
NS_TS="$(date +%Y%m%d-%H%M%S)"
REPORT="${PWD}/lab_sessao5_feedback_${TS}.txt"
NS="sessao5-validation-${NS_TS}"
KEEP_NAMESPACE="${KEEP_NAMESPACE:-0}"
TEST_SYMFONY="${TEST_SYMFONY:-1}"

PASS=0
WARN=0
FAIL=0

exec > >(tee -a "$REPORT") 2>&1

section() {
  printf '\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

ok() {
  PASS=$((PASS+1))
  printf '[OK] %s\n' "$*"
}

warn() {
  WARN=$((WARN+1))
  printf '[AVISO] %s\n' "$*"
}

fail() {
  FAIL=$((FAIL+1))
  printf '[FALHA] %s\n' "$*"
}

cleanup() {
  if [[ "$KEEP_NAMESPACE" == "1" ]]; then
    warn "KEEP_NAMESPACE=1: namespace $NS mantido para diagnóstico."
    return
  fi

  if command -v kubectl >/dev/null 2>&1; then
    kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

run_check() {
  local desc="$1"
  shift
  if "$@" >/tmp/lab_sessao5_check.out 2>/tmp/lab_sessao5_check.err; then
    ok "$desc"
    return 0
  else
    fail "$desc"
    sed 's/^/    /' /tmp/lab_sessao5_check.err || true
    return 1
  fi
}

section "LAB SESSÃO 5 — RELATÓRIO DE VALIDAÇÃO"
echo "Data: $(date --iso-8601=seconds 2>/dev/null || date)"
echo "Host: $(hostname)"
echo "Utilizador: $(id -un)"
echo "Namespace temporário: $NS"
echo "Relatório: $REPORT"

section "1. FERRAMENTAS LOCAIS"

if command -v kubectl >/dev/null 2>&1; then
  ok "kubectl encontrado: $(command -v kubectl)"
  kubectl version --client 2>/dev/null || true
else
  fail "kubectl não encontrado."
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  ok "curl encontrado."
else
  warn "curl não encontrado. Os testes HTTP externos serão limitados."
fi

section "2. CONTEXTO E ACESSO AO CLUSTER"

CTX="$(kubectl config current-context 2>/dev/null || true)"
if [[ -n "$CTX" ]]; then
  ok "Contexto kubectl atual: $CTX"
else
  fail "Não foi possível obter o contexto kubectl."
  exit 1
fi

if kubectl auth can-i get nodes >/dev/null 2>&1; then
  ok "Acesso à API Kubernetes funcional."
else
  fail "Sem permissões para consultar Nodes."
  exit 1
fi

section "3. NODES"

kubectl get nodes -o wide || true

READY_NODES="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"{c++} END{print c+0}')"
if (( READY_NODES >= 3 )); then
  ok "Existem pelo menos 3 Nodes Ready ($READY_NODES)."
else
  fail "Esperados pelo menos 3 Nodes Ready; encontrados $READY_NODES."
fi

for n in k8s-cp-01 k8s-wk-01 k8s-wk-03; do
  if kubectl get node "$n" >/dev/null 2>&1; then
    status="$(kubectl get node "$n" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "$status" == "True" ]]; then
      ok "$n existe e está Ready."
    else
      fail "$n existe mas não está Ready."
    fi
  else
    fail "Node esperado não encontrado: $n"
  fi
done

TAINTS="$(kubectl get node k8s-cp-01 -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' 2>/dev/null || true)"
if grep -Eq 'node-role\.kubernetes\.io/control-plane.*NoSchedule' <<<"$TAINTS"; then
  ok "Control Plane mantém taint NoSchedule."
else
  warn "Não foi detetado o taint NoSchedule esperado no Control Plane. O DaemonSet pode também correr no CP."
fi

section "4. COREDNS / STORAGE / TRAEFIK / GATEWAY API"

COREDNS_READY="$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | awk '$2 ~ /^[0-9]+\/[0-9]+$/ && $3=="Running"{c++} END{print c+0}')"
if (( COREDNS_READY >= 1 )); then
  ok "CoreDNS tem pelo menos um Pod Running."
else
  fail "CoreDNS não parece operacional."
fi

if kubectl get storageclass local-path >/dev/null 2>&1; then
  ok "StorageClass local-path existe."
  PROVISIONER="$(kubectl get storageclass local-path -o jsonpath='{.provisioner}' 2>/dev/null || true)"
  BINDING="$(kubectl get storageclass local-path -o jsonpath='{.volumeBindingMode}' 2>/dev/null || true)"
  RECLAIM="$(kubectl get storageclass local-path -o jsonpath='{.reclaimPolicy}' 2>/dev/null || true)"

  [[ "$PROVISIONER" == "rancher.io/local-path" ]] \
    && ok "Provisioner = rancher.io/local-path." \
    || warn "Provisioner encontrado: ${PROVISIONER:-desconhecido}"

  [[ "$BINDING" == "WaitForFirstConsumer" ]] \
    && ok "volumeBindingMode = WaitForFirstConsumer." \
    || warn "volumeBindingMode encontrado: ${BINDING:-desconhecido}"

  echo "reclaimPolicy: ${RECLAIM:-não reportada}"
else
  fail "StorageClass local-path não existe."
fi

if kubectl get namespace traefik >/dev/null 2>&1; then
  ok "Namespace traefik existe."
else
  fail "Namespace traefik não existe."
fi

if kubectl get ingressclass traefik >/dev/null 2>&1; then
  ok "IngressClass traefik existe."
else
  fail "IngressClass traefik não existe."
fi

if kubectl get gatewayclass traefik >/dev/null 2>&1; then
  ok "GatewayClass traefik existe."
else
  fail "GatewayClass traefik não existe."
fi

for crd in gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io; do
  if kubectl get crd "$crd" >/dev/null 2>&1; then
    ok "CRD presente: $crd"
  else
    fail "CRD ausente: $crd"
  fi
done

TRAEFIK_SVC="$(kubectl -n traefik get svc -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$TRAEFIK_SVC" ]]; then
  TRAEFIK_SVC="$(kubectl -n traefik get svc --no-headers 2>/dev/null | awk 'NR==1{print $1}')"
fi

if [[ -n "$TRAEFIK_SVC" ]]; then
  ok "Service Traefik detetado: $TRAEFIK_SVC"
  kubectl -n traefik get svc "$TRAEFIK_SVC" -o wide || true

  NODEPORTS="$(kubectl -n traefik get svc "$TRAEFIK_SVC" -o jsonpath='{range .spec.ports[*]}{.name}:{.port}->{.nodePort}{"\n"}{end}' 2>/dev/null || true)"
  echo "$NODEPORTS"

  if grep -q '30080' <<<"$NODEPORTS"; then
    ok "NodePort HTTP 30080 detetado."
  else
    warn "NodePort HTTP 30080 não detetado no Service Traefik."
  fi

  if grep -q '30443' <<<"$NODEPORTS"; then
    ok "NodePort HTTPS 30443 detetado."
  else
    warn "NodePort HTTPS 30443 não detetado no Service Traefik."
  fi
else
  fail "Não foi possível identificar o Service Traefik."
fi

section "5. CRIAR NAMESPACE TEMPORÁRIO"

if kubectl create namespace "$NS" >/dev/null 2>&1; then
  ok "Namespace $NS criado."
else
  fail "Não foi possível criar namespace $NS."
  exit 1
fi

K=(kubectl -n "$NS")

section "6. TESTE DE DAEMONSET"

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: daemon-test
spec:
  selector:
    matchLabels:
      app: daemon-test
  template:
    metadata:
      labels:
        app: daemon-test
    spec:
      containers:
        - name: test
          image: busybox:1.36
          command: ["sh","-c","sleep 600"]
YAML

if "${K[@]}" rollout status daemonset/daemon-test --timeout=300s >/dev/null 2>&1; then
  ok "DaemonSet ficou disponível."
else
  fail "DaemonSet não ficou disponível."
fi

DAEMON_NODES="$("${K[@]}" get pods -l app=daemon-test -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null || true)"
echo "$DAEMON_NODES" | sed 's/^/    /'
for wk in k8s-wk-01 k8s-wk-03; do
  if grep -qx "$wk" <<<"$DAEMON_NODES"; then
    ok "DaemonSet tem Pod em $wk."
  else
    fail "DaemonSet não tem Pod em $wk."
  fi
done

section "7. TESTE DE DYNAMIC PROVISIONING + PERSISTÊNCIA"

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: persist-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: persist-pod
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh","-c","sleep 600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: persist-pvc
YAML

if "${K[@]}" wait --for=condition=Ready pod/persist-pod --timeout=300s >/dev/null 2>&1; then
  ok "Pod consumidor do PVC ficou Ready."
else
  fail "Pod consumidor do PVC não ficou Ready."
fi

PVC_PHASE="$("${K[@]}" get pvc persist-pvc -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$PVC_PHASE" == "Bound" ]]; then
  ok "PVC transitou para Bound."
else
  fail "PVC não está Bound (estado: ${PVC_PHASE:-desconhecido})."
fi

if "${K[@]}" exec persist-pod -- sh -c 'printf "persistencia-ok" > /data/prova.txt' >/dev/null 2>&1; then
  ok "Dado de prova escrito no volume."
else
  fail "Não foi possível escrever no volume."
fi

"${K[@]}" delete pod persist-pod --wait=true >/dev/null 2>&1 || true

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: persist-pod
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh","-c","sleep 600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: persist-pvc
YAML

"${K[@]}" wait --for=condition=Ready pod/persist-pod --timeout=300s >/dev/null 2>&1 || true
PERSISTED="$("${K[@]}" exec persist-pod -- cat /data/prova.txt 2>/dev/null || true)"
if [[ "$PERSISTED" == "persistencia-ok" ]]; then
  ok "Persistência validada após recriação do Pod."
else
  fail "Persistência não validada; conteúdo obtido: ${PERSISTED:-vazio}"
fi

section "8. TESTE DE STATEFULSET + HEADLESS DNS"

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 2
YAML

if "${K[@]}" rollout status statefulset/web --timeout=300s >/dev/null 2>&1; then
  ok "StatefulSet web ficou Ready."
else
  fail "StatefulSet web não ficou Ready."
fi

if "${K[@]}" get pod web-0 >/dev/null 2>&1 && "${K[@]}" get pod web-1 >/dev/null 2>&1; then
  ok "Ordinais web-0 e web-1 confirmados."
else
  fail "Ordinais esperados do StatefulSet não encontrados."
fi

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: dns-test
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh","-c","sleep 600"]
YAML

"${K[@]}" wait --for=condition=Ready pod/dns-test --timeout=180s >/dev/null 2>&1 || true

DNS_NAME="web-1.web.${NS}.svc.cluster.local"
if "${K[@]}" exec dns-test -- nslookup "$DNS_NAME" >/dev/null 2>&1; then
  ok "DNS por Pod via Headless Service funciona: $DNS_NAME"
else
  fail "Falha na resolução DNS por Pod: $DNS_NAME"
fi

OLD_UID="$("${K[@]}" get pod web-1 -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
"${K[@]}" delete pod web-1 --wait=true >/dev/null 2>&1 || true
"${K[@]}" wait --for=create pod/web-1 --timeout=120s >/dev/null 2>&1 || true
"${K[@]}" wait --for=condition=Ready pod/web-1 --timeout=300s >/dev/null 2>&1 || true
NEW_UID="$("${K[@]}" get pod web-1 -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"

if [[ -n "$OLD_UID" && -n "$NEW_UID" && "$OLD_UID" != "$NEW_UID" ]]; then
  ok "StatefulSet recriou web-1 com o mesmo nome e novo UID."
else
  fail "Não foi possível validar a recriação de web-1."
fi

section "9. TESTE DA IMAGEM SYMFONY + SERVICE"

if [[ "$TEST_SYMFONY" == "1" ]]; then
  cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: symfony-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: symfony-test
  template:
    metadata:
      labels:
        app: symfony-test
    spec:
      containers:
        - name: app
          image: ghcr.io/skullclamp/symfony-demo:1.1.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 2
            timeoutSeconds: 2
            failureThreshold: 30
---
apiVersion: v1
kind: Service
metadata:
  name: symfony-test
spec:
  selector:
    app: symfony-test
  ports:
    - port: 80
      targetPort: 80
YAML

  if "${K[@]}" rollout status deployment/symfony-test --timeout=300s >/dev/null 2>&1; then
    ok "Imagem Symfony foi puxada e o Deployment ficou disponível."
  else
    fail "Symfony Deployment não ficou disponível (imagem, runtime ou arranque da aplicação)."
  fi

  cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: http-client
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh","-c","sleep 600"]
YAML
  "${K[@]}" wait --for=condition=Ready pod/http-client --timeout=180s >/dev/null 2>&1 || true

  HEALTH="$("${K[@]}" exec http-client -- wget -qO- http://symfony-test/health 2>/dev/null || true)"
  if [[ -n "$HEALTH" ]]; then
    ok "Symfony /health responde internamente."
    echo "    Resposta: $HEALTH"
  else
    fail "Symfony /health não respondeu através do Service."
  fi
else
  warn "TEST_SYMFONY=0: teste da imagem Symfony ignorado."
fi

section "10. TESTE DE INGRESS E GATEWAY API"

if [[ "$TEST_SYMFONY" == "1" ]]; then
  cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: symfony-test
spec:
  ingressClassName: traefik
  rules:
    - host: symfony-validation.lab
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: symfony-test
                port:
                  number: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: symfony-test
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      protocol: HTTP
      port: 8000
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: symfony-test
spec:
  parentRefs:
    - name: symfony-test
  hostnames:
    - symfony-gateway-validation.lab
  rules:
    - backendRefs:
        - name: symfony-test
          port: 80
YAML

  if "${K[@]}" wait --for=condition=Accepted gateway/symfony-test --timeout=120s >/dev/null 2>&1; then
    ok "Gateway foi aceite pelo controller."
  else
    fail "Gateway não ficou Accepted."
    "${K[@]}" describe gateway symfony-test || true
  fi

  INGRESS_CLASS="$("${K[@]}" get ingress symfony-test -o jsonpath='{.spec.ingressClassName}' 2>/dev/null || true)"
  [[ "$INGRESS_CLASS" == "traefik" ]] \
    && ok "Ingress associado à IngressClass traefik." \
    || fail "IngressClass inesperada: ${INGRESS_CLASS:-vazia}"

  ROUTE_PARENT="$("${K[@]}" get httproute symfony-test -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null || true)"
  [[ "$ROUTE_PARENT" == "symfony-test" ]] \
    && ok "HTTPRoute associado ao Gateway esperado." \
    || fail "HTTPRoute não está associado ao Gateway esperado."

  WORKER_IP="$(kubectl get node k8s-wk-01 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
  if command -v curl >/dev/null 2>&1 && [[ -n "$WORKER_IP" ]] && grep -q '30080' <<<"${NODEPORTS:-}"; then
    if curl --connect-timeout 5 --max-time 10 --fail --silent \
      -H 'Host: symfony-validation.lab' \
      "http://${WORKER_IP}:30080/health" >/tmp/ingress-health.out 2>/dev/null; then
      ok "Ingress responde externamente via ${WORKER_IP}:30080."
      sed 's/^/    /' /tmp/ingress-health.out || true
      echo
    else
      warn "Ingress não respondeu a partir desta VM em ${WORKER_IP}:30080. Pode ser firewall/roteamento/NodePort."
    fi

    if curl --connect-timeout 5 --max-time 10 --fail --silent \
      -H 'Host: symfony-gateway-validation.lab' \
      "http://${WORKER_IP}:30080/health" >/tmp/gateway-health.out 2>/dev/null; then
      ok "Gateway API responde externamente via ${WORKER_IP}:30080."
      sed 's/^/    /' /tmp/gateway-health.out || true
      echo
    else
      warn "Gateway API não respondeu externamente. Rever Traefik Gateway provider, listener 8000 e exposição NodePort."
    fi
  else
    warn "Teste HTTP externo não executado (curl/IP/NodePort indisponível)."
  fi
fi

section "11. TESTE POSTGRESQL + JOB DE BACKUP + RESTORE"

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
type: Opaque
stringData:
  password: validation-password
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          env:
            - name: POSTGRES_DB
              value: symfony_demo
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
          readinessProbe:
            exec:
              command: ["pg_isready","-U","postgres","-d","symfony_demo"]
            periodSeconds: 2
            timeoutSeconds: 2
            failureThreshold: 30
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: pg-client
spec:
  containers:
    - name: psql
      image: postgres:16
      command: ["sh","-c","sleep 900"]
      env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
YAML

"${K[@]}" wait --for=create pod/postgres-0 --timeout=120s >/dev/null 2>&1 || true
if "${K[@]}" wait --for=condition=Ready pod/postgres-0 --timeout=300s >/dev/null 2>&1; then
  ok "PostgreSQL StatefulSet ficou Ready com pg_isready."
else
  fail "PostgreSQL não ficou Ready."
  "${K[@]}" describe pod postgres-0 || true
fi

"${K[@]}" wait --for=condition=Ready pod/pg-client --timeout=300s >/dev/null 2>&1 || true

if "${K[@]}" exec pg-client -- psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
   -c "CREATE TABLE IF NOT EXISTS lab_marker(id integer PRIMARY KEY, mensagem text NOT NULL);" >/dev/null 2>&1 \
   && "${K[@]}" exec pg-client -- psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
   -c "INSERT INTO lab_marker(id,mensagem) VALUES (1,'validation-ok') ON CONFLICT (id) DO UPDATE SET mensagem=EXCLUDED.mensagem;" >/dev/null 2>&1; then
  ok "Dados de teste criados no PostgreSQL."
else
  fail "Falha ao criar dados de teste no PostgreSQL."
fi

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-backup
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: pg-dump
          image: postgres:16
          env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
          command:
            - sh
            - -c
            - |
              set -eu
              pg_dump -h postgres -U postgres -d symfony_demo -f /backup/dump.sql
              test -s /backup/dump.sql
          volumeMounts:
            - name: backup
              mountPath: /backup
      volumes:
        - name: backup
          persistentVolumeClaim:
            claimName: backup-pvc
YAML

if "${K[@]}" wait --for=condition=complete job/postgres-backup --timeout=300s >/dev/null 2>&1; then
  ok "Job de backup concluiu com sucesso."
else
  fail "Job de backup não concluiu."
  "${K[@]}" describe job postgres-backup || true
  "${K[@]}" logs job/postgres-backup || true
fi

cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: backup-reader
spec:
  containers:
    - name: reader
      image: busybox:1.36
      command: ["sh","-c","sleep 600"]
      volumeMounts:
        - name: backup
          mountPath: /backup
  volumes:
    - name: backup
      persistentVolumeClaim:
        claimName: backup-pvc
YAML

"${K[@]}" wait --for=condition=Ready pod/backup-reader --timeout=300s >/dev/null 2>&1 || true

if "${K[@]}" exec backup-reader -- test -s /backup/dump.sql >/dev/null 2>&1; then
  ok "Dump existe e não está vazio no backup-pvc."
else
  fail "Dump ausente ou vazio no backup-pvc."
fi

LOCAL_DUMP="/tmp/lab_sessao5_${TS}_dump.sql"
if "${K[@]}" cp backup-reader:/backup/dump.sql "$LOCAL_DUMP" >/dev/null 2>&1 && [[ -s "$LOCAL_DUMP" ]]; then
  ok "kubectl cp retirou o dump do cluster com sucesso."
else
  fail "kubectl cp não conseguiu retirar o dump."
fi

# Destruir dados primários e recriar o StatefulSet
"${K[@]}" delete statefulset postgres --cascade=foreground --wait=true >/dev/null 2>&1 || true
"${K[@]}" delete pvc data-postgres-0 --wait=true >/dev/null 2>&1 || true

# Reaplicar só o StatefulSet
cat <<'YAML' | "${K[@]}" apply -f - >/dev/null
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          env:
            - name: POSTGRES_DB
              value: symfony_demo
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
          readinessProbe:
            exec:
              command: ["pg_isready","-U","postgres","-d","symfony_demo"]
            periodSeconds: 2
            timeoutSeconds: 2
            failureThreshold: 30
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 256Mi
YAML

"${K[@]}" wait --for=create pod/postgres-0 --timeout=120s >/dev/null 2>&1 || true
"${K[@]}" wait --for=condition=Ready pod/postgres-0 --timeout=300s >/dev/null 2>&1 || true

PRE_RESTORE="$("${K[@]}" exec pg-client -- psql -h postgres -U postgres -d symfony_demo -Atqc \
  "SELECT mensagem FROM lab_marker WHERE id=1;" 2>/dev/null || true)"

if [[ -z "$PRE_RESTORE" ]]; then
  ok "Após perda da PVC, os dados antigos já não estão presentes."
else
  warn "Foram encontrados dados antes do restore: $PRE_RESTORE"
fi

if [[ -s "$LOCAL_DUMP" ]]; then
  if "${K[@]}" exec -i pg-client -- psql -h postgres -U postgres -d symfony_demo -v ON_ERROR_STOP=1 \
      < "$LOCAL_DUMP" >/dev/null 2>&1; then
    ok "Restore por streaming através de pg-client executado."
  else
    fail "Restore por streaming falhou."
  fi
fi

POST_RESTORE="$("${K[@]}" exec pg-client -- psql -h postgres -U postgres -d symfony_demo -Atqc \
  "SELECT mensagem FROM lab_marker WHERE id=1;" 2>/dev/null || true)"

if [[ "$POST_RESTORE" == "validation-ok" ]]; then
  ok "Dados recuperados corretamente após o restore."
else
  fail "Dados não foram recuperados como esperado (valor: ${POST_RESTORE:-vazio})."
fi

rm -f "$LOCAL_DUMP" 2>/dev/null || true

section "12. RESUMO"

TOTAL=$((PASS+WARN+FAIL))
echo "Total de verificações: $TOTAL"
echo "OK:                   $PASS"
echo "Avisos:               $WARN"
echo "Falhas:               $FAIL"

if (( FAIL == 0 )); then
  echo
  echo "RESULTADO GLOBAL: APROVADO"
  echo "O ambiente passou todos os testes obrigatórios."
  EXIT_CODE=0
else
  echo
  echo "RESULTADO GLOBAL: REVER"
  echo "Existem falhas que devem ser corrigidas antes de usar o laboratório em formação."
  EXIT_CODE=2
fi

echo
echo "Relatório guardado em:"
echo "$REPORT"

if [[ "$KEEP_NAMESPACE" == "1" ]]; then
  echo
  echo "Namespace mantido para diagnóstico:"
  echo "$NS"
fi

exit "$EXIT_CODE"
