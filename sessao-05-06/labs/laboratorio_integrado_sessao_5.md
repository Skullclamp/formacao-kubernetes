# README-LAB — Sessão 5

## Laboratório Integrado — Administração e Governação de uma Aplicação Kubernetes

Laboratório integrado de 240 minutos. Ambiente: cluster partilhado (1 Control Plane + 2 Workers, Calico). Aplicação: Symfony Demo + PostgreSQL 16, Namespace `lab-admin`.

> **Pré-requisito crítico:** todos os manifests abaixo devem estar preparados, testados e disponíveis (repositório/pasta partilhada) **antes** da sessão. Os formandos aplicam, interpretam, alteram e diagnosticam — não escrevem YAML de raiz.

> **Namespace:** por omissão, este guião assume **um único Namespace `lab-admin`, partilhado por todos os formandos** (laboratório colaborativo, com alternância de quem opera o terminal). Se a formação decidir por Namespaces individuais (`lab-admin-f1`…`lab-admin-f5`), substituir `lab-admin` pelo Namespace de cada formando em todos os comandos abaixo, e coordenar centralmente qualquer alteração a Nodes (Fase 3), que são recursos cluster-scoped partilhados.

---

## 1. Checklist de preparação (antes da formação)

- [ ] Cluster acessível, `kubectl get nodes -o wide` devolve os 3 nós `Ready`.
- [ ] O Control Plane permanece não elegível para workloads aplicacionais normais (por exemplo, com taint `NoSchedule` adequado).
- [ ] `kubectl get sc` mostra uma StorageClass com provisionamento dinâmico.
- [ ] Calico operacional: `kubectl get pods -A | grep -i calico` sem erros e enforcement de `NetworkPolicy` previamente validado.
- [ ] CoreDNS operacional; Service e labels reais identificados previamente com `kubectl get pods -n kube-system --show-labels` e `kubectl get svc -n kube-system` para construir `allow-dns.yaml` sem assumir labels.
- [ ] Imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` acessível por pull a partir dos nós e configuração de runtime validada com `APP_ENV=prod` para esta imagem.
- [ ] Imagem `postgres:16` acessível por pull a partir dos nós.
- [ ] Nome da base de dados aplicacional (`POSTGRES_DB`) confirmado e igual no StatefulSet/Symfony/Job de backup.
- [ ] A rota `/ready` da aplicação foi testada previamente e **confirma dependência real do PostgreSQL**. Se não o fizer, o formador deve substituir `/ready`, antes da sessão, por uma rota HTTP validada que consulte efetivamente a base de dados.
- [ ] A imagem usada em `04-networking/pod-debug.yaml` foi previamente validada e contém `curl`, `nslookup` e `nc`; o laboratório não depende de ferramentas cuja existência na imagem não tenha sido confirmada.
- [ ] Todos os manifests da secção 2 testados de ponta a ponta pelo menos uma vez.
- [ ] Job de backup da **Fase 7 / diretoria** **`07-backup/`** testado e a produzir um artefacto identificável.
- [ ] Pelo menos dois Workers elegíveis e `Ready` para a Fase 3; o guião descobre dinamicamente o Worker usado no `nodeSelector`, sem depender de nomes ou IPs específicos.
- [ ] Antes da sessão, confirmar que nenhum Node possui já a label `disco=ssd`, para que a label criada pelo laboratório possa ser identificada e removida sem ambiguidade.
- [ ] `03-scheduling/symfony-antiaffinity-patch.yaml` validado com `requiredDuringSchedulingIgnoredDuringExecution`, `topologyKey: kubernetes.io/hostname` e estratégia de rollout compatível com apenas dois Workers (`maxSurge: 0`, `maxUnavailable: 1`).
- [ ] `ResourceQuota`/`LimitRange` da Fase 1 validados com margem para **todos** os Pods previstos no laboratório (PostgreSQL, 2× Symfony, `debug`, `client`, `intruder`, backup Job, `backup-reader`, `pod-pending-exemplo`) — só `pod-acima-da-quota.yaml` deve produzir a falha intencional de quota; nenhum outro Pod pode falhar por este motivo.

---

## 2. Estrutura de diretórios

```text
lab-admin/
├── 00-namespace.yaml
├── 01-governacao/
│   ├── limitrange.yaml
│   ├── resourcequota.yaml
│   └── pod-acima-da-quota.yaml
├── 02-aplicacao/
│   ├── symfony-deployment.yaml
│   ├── symfony-service.yaml
│   ├── postgres-statefulset.yaml
│   ├── postgres-service-headless.yaml
│   └── postgres-secret.yaml
├── 03-scheduling/
│   ├── symfony-nodeselector-patch.yaml
│   ├── symfony-antiaffinity-patch.yaml
│   └── pod-pending-exemplo.yaml
├── 04-networking/
│   └── pod-debug.yaml
├── 05-identidade/
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   ├── rolebinding.yaml
│   └── securitycontext-patch.yaml
├── 06-networkpolicy/
│   ├── default-deny.yaml
│   ├── allow-dns.yaml
│   ├── allow-client-app.yaml
│   ├── allow-app-db.yaml
│   ├── pod-client.yaml
│   └── pod-intruder.yaml
└── 07-backup/
    ├── backup-pvc.yaml
    ├── backup-job.yaml
    ├── backup-reader.yaml
    └── allow-backup-db.yaml
```

---

## 3. Fase 0 — Preparação (10 min)

```bash
kubectl apply -f 00-namespace.yaml

kubectl get nodes -o wide
kubectl get sc
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system
kubectl get networkpolicy -A
```

Não alteramos o `kubeconfig` do formando com `kubectl config set-context --current --namespace=...`: todos os comandos abaixo usam `-n lab-admin` explícito, o que é mais seguro e evita que o contexto do formando fique apontado para um Namespace já eliminado no final da sessão.

**Resultado esperado:** Namespace `lab-admin` criado; 3 nós `Ready`; StorageClass disponível; Calico sem erros; CoreDNS identificado; estado inicial de `NetworkPolicy` conhecido; Control Plane não utilizado como destino de workloads aplicacionais.

---

## 4. Fase 1 — Governação inicial (30 min)

```bash
kubectl apply -f 01-governacao/limitrange.yaml
kubectl apply -f 01-governacao/resourcequota.yaml

kubectl describe limitrange -n lab-admin
kubectl describe resourcequota -n lab-admin

kubectl run teste-sem-limites --image=nginx -n lab-admin
kubectl get pod teste-sem-limites \
  -n lab-admin \
  -o jsonpath='{.spec.containers[0].resources}'
kubectl delete pod teste-sem-limites -n lab-admin
```

Eliminar o Pod de teste é obrigatório: caso contrário continua a consumir quota e pode interferir com o Symfony/PostgreSQL da Fase 2.

**Falha intencional:** tentar criar um recurso que ultrapasse a quota (ex.: um segundo Pod com `requests.cpu` elevado).

```bash
kubectl apply -f 01-governacao/pod-acima-da-quota.yaml
```

**Resultado esperado:** erro `exceeded quota` — registar a mensagem completa como evidência.

---

## 5. Fase 2 — Aplicação e persistência (45 min)

```bash
kubectl apply -f 02-aplicacao/postgres-secret.yaml
kubectl apply -f 02-aplicacao/postgres-service-headless.yaml
kubectl apply -f 02-aplicacao/postgres-statefulset.yaml
kubectl apply -f 02-aplicacao/symfony-deployment.yaml
kubectl apply -f 02-aplicacao/symfony-service.yaml

kubectl rollout status statefulset/postgres -n lab-admin --timeout=120s
kubectl rollout status deployment/symfony -n lab-admin --timeout=120s

kubectl get pods -n lab-admin -o wide
kubectl get statefulset -n lab-admin
kubectl get pvc -n lab-admin
kubectl get pv
```

A ordem `Secret → Headless Service → StatefulSet` torna explícitas as dependências do PostgreSQL antes do arranque do workload.

**Resultado esperado:** `postgres-0` `Running` com PVC associado (`data-postgres-0` ou equivalente); Symfony com 2 réplicas `Running`.

---

## 6. Fase 3 — Scheduling (25 min)

### Experiência A — nodeSelector

Selecionar dinamicamente um Worker `Ready`, excluindo Control Plane e labels de função legacy `master`, e guardar o nome numa variável para reutilização no final do laboratório:

```bash
WORKER_SSD=$(kubectl get nodes \
  -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' \
  --no-headers | awk '$2 ~ /^Ready/ {print $1; exit}')

test -n "$WORKER_SSD" || { echo "Nenhum Worker Ready encontrado"; exit 1; }
echo "Worker selecionado: $WORKER_SSD"

kubectl label node "$WORKER_SSD" disco=ssd --overwrite
kubectl get node "$WORKER_SSD" --show-labels
```

Aplicar o patch ao Deployment Symfony:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-nodeselector-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -o wide -n lab-admin
```

O `nodeSelector` aplica-se ao **Symfony** (Deployment stateless), não ao PostgreSQL: mover o Pod do PostgreSQL entre Workers depende do comportamento da StorageClass (topologia, `ReadWriteOnce`), que não está garantido em todos os ambientes.

**Resultado esperado:** as réplicas Symfony ficam elegíveis apenas para o Worker com `disco=ssd`.

### Experiência B — Anti-Affinity

Antes de aplicar Anti-Affinity, remover explicitamente o `nodeSelector`. Caso contrário, a regra anterior restringiria ambas as réplicas ao mesmo Worker e entraria em conflito com a distribuição obrigatória por `hostname`.

```bash
kubectl patch deployment symfony -n lab-admin \
  --type=json \
  -p='[
    {"op":"remove","path":"/spec/template/spec/nodeSelector"}
  ]'
```

Aplicar a regra de Anti-Affinity:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-antiaffinity-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -o wide -n lab-admin
```

`symfony-antiaffinity-patch.yaml` deve usar `requiredDuringSchedulingIgnoredDuringExecution` com `topologyKey: kubernetes.io/hostname` — uma regra apenas `preferred` não garante o resultado esperado.

Como o laboratório tem exatamente **dois Workers elegíveis** e duas réplicas, o patch validado define também uma estratégia de rollout compatível com Anti-Affinity obrigatória:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
```

Com `maxSurge: 1` e `maxUnavailable: 0`, um rollout tentaria criar temporariamente uma terceira réplica. Com Anti-Affinity obrigatória e apenas dois Workers elegíveis, essa réplica ficaria `Pending` e o rollout poderia bloquear. Esta interação entre **estratégia de rollout** e **regras de placement** faz parte da evidência pedagógica da experiência.

**Resultado esperado:** as duas réplicas Symfony em Workers diferentes e rollout concluído sem Pod adicional permanentemente `Pending`.

### Experiência C — falha intencional de scheduling

```bash
kubectl apply -f 03-scheduling/pod-pending-exemplo.yaml
kubectl get pods -n lab-admin
kubectl describe pod pod-pending-exemplo -n lab-admin
kubectl get events -n lab-admin --sort-by=.lastTimestamp
```

**Resultado esperado:** Pod em `Pending`, evento `FailedScheduling` com a causa explícita (ex.: `nodeSelector` sem nó correspondente).

Depois de recolher a evidência, eliminar o Pod para não consumir quota nem interferir com as fases seguintes:

```bash
kubectl delete pod pod-pending-exemplo -n lab-admin
```

---

## Intervalo (15 min)

Pausa formal entre a Fase 3 e a Fase 4. Com esta pausa, o total do laboratório fecha em `10 + 30 + 45 + 25 + 15 + 25 + 30 + 30 + 20 + 10 = 240 min`.

---

## 7. Fase 4 — Networking e DNS (25 min)

O Pod de diagnóstico é criado a partir de um manifesto previamente validado. A imagem definida em `pod-debug.yaml` deve conter `curl`, `nslookup` e `nc`; não se assume que uma imagem genérica disponha destas ferramentas.

```bash
kubectl apply -f 04-networking/pod-debug.yaml
kubectl wait --for=condition=Ready pod/debug -n lab-admin --timeout=60s

kubectl exec debug -n lab-admin -- nslookup symfony
kubectl exec debug -n lab-admin -- nslookup postgres

kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony
```

**Resultado esperado:** resolução DNS de ambos os Services e `HTTP 200` no Service Symfony, sem despejar toda a página HTML no terminal.

Para provar explicitamente o salto `app → db`, este laboratório usa uma rota HTTP da aplicação que foi **validada antes da sessão como dependente do PostgreSQL**. Por omissão usa-se `/ready`; se essa rota não consultar a base de dados na imagem efetivamente utilizada, o formador deve substituir o caminho no guião antes da sessão.

```bash
kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

kubectl delete pod debug -n lab-admin
```

**Resultado esperado:** corpo semelhante a `{"status":"ready","database":"ok"}` e `HTTP 200`. Este teste evidencia `debug → app → db` de ponta a ponta. O Pod `debug` é eliminado explicitamente no final da fase.

Gateway API: apresentar apenas o diagrama conceptual `GatewayClass → Gateway → HTTPRoute → Service → Pods`, sem aplicar manifests nem instalar controller.

---

## 8. Fase 5 — Identidade, RBAC e hardening (30 min)

```bash
kubectl apply -f 05-identidade/serviceaccount.yaml
kubectl apply -f 05-identidade/role.yaml
kubectl apply -f 05-identidade/rolebinding.yaml

kubectl auth can-i get pods \
  --as=system:serviceaccount:lab-admin:app-reader -n lab-admin

kubectl auth can-i delete pods \
  --as=system:serviceaccount:lab-admin:app-reader -n lab-admin
```

Aplicar ao Deployment Symfony um patch previamente validado que inclua:

- `serviceAccountName: app-reader`;
- `automountServiceAccountToken: false`, porque a aplicação não necessita de comunicar diretamente com a Kubernetes API;
- o `SecurityContext` compatível com a imagem.

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 05-identidade/securitycontext-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
```

Exemplo conceptual da parte de identidade do patch:

```yaml
spec:
  template:
    spec:
      serviceAccountName: app-reader
      automountServiceAccountToken: false
```

**Atenção:** aplicar o patch de `SecurityContext` ao Deployment Symfony só é seguro se esta configuração já tiver sido **testada previamente contra a imagem** **`symfony-demo:1.0.0`**. Se incluir `runAsNonRoot: true`, confirmar que a imagem corre sem privilégios de root antes da sessão, para não confundir uma limitação da imagem com o próprio conceito de `SecurityContext`.

**Resultado esperado:** primeiro `can-i` → `yes`; segundo `can-i` → `no`; Deployment associado à ServiceAccount dedicada; token não montado desnecessariamente; Pods reiniciados e `Ready` com `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` e `seccompProfile: RuntimeDefault` (mais apenas as capabilities adicionais previamente validadas para esta imagem).

Confirmar:

```bash
kubectl get deployment symfony -n lab-admin \
  -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}{.spec.template.spec.automountServiceAccountToken}{"\n"}'

SYMFONY_POD=$(kubectl get pods \
  -n lab-admin \
  -l app=symfony \
  -o jsonpath='{.items[0].metadata.name}')

echo "Pod selecionado: $SYMFONY_POD"

kubectl get pod "$SYMFONY_POD" -n lab-admin \
  -o jsonpath='{.spec.containers[0].securityContext}{"\n"}'

kubectl get pods -n lab-admin -o wide
```

---

## 9. Fase 6 — NetworkPolicy (30 min)

Criar os Pods de teste e **esperar explicitamente que estejam `Ready`** antes do primeiro `kubectl exec`:

```bash
kubectl apply -f 06-networkpolicy/pod-client.yaml
kubectl apply -f 06-networkpolicy/pod-intruder.yaml

kubectl wait --for=condition=Ready pod/client -n lab-admin --timeout=120s
kubectl wait --for=condition=Ready pod/intruder -n lab-admin --timeout=120s
```

### Etapa A — baseline sem isolamento

```bash
kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Resultado esperado:** corpo de `/ready`, `HTTP 200` e código de saída `0`.

### Etapa B — default deny

```bash
kubectl apply -f 06-networkpolicy/default-deny.yaml

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 3 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Resultado esperado:** falha por timeout. Como o `default-deny` bloqueia também egress, o primeiro sintoma pode ser resolução DNS bloqueada (`HTTP 000`, código de saída do `curl` diferente de `0`, tipicamente `28`).

### Etapa C — reabrir apenas DNS

```bash
kubectl apply -f 06-networkpolicy/allow-dns.yaml

kubectl exec client -n lab-admin -- nslookup symfony
kubectl exec client -n lab-admin -- nslookup postgres

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 3 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Resultado esperado:** DNS volta a resolver, mas HTTP continua bloqueado. Isto demonstra que **resolver nomes e autorizar tráfego aplicacional são permissões distintas**.

### Etapa D — autorizar apenas os fluxos aplicacionais necessários

```bash
kubectl apply -f 06-networkpolicy/allow-client-app.yaml
kubectl apply -f 06-networkpolicy/allow-app-db.yaml

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?

kubectl exec intruder -n lab-admin -- nc -zvw3 postgres 5432
echo $?
```

**Resultado esperado:** `client → app → db` devolve `/ready`, `HTTP 200` e código de saída `0`; `intruder → db` falha por timeout/conexão bloqueada e devolve código de saída diferente de `0`.

**Contrato das políticas:** `default-deny.yaml` deve isolar **Ingress e Egress**. Por isso, cada fluxo entre workloads isolados tem de ser autorizado nos dois extremos.

Para reduzir ambiguidades na escrita dos manifests, cada ficheiro que autoriza um fluxo **entre workloads do laboratório** deve conter **dois objetos `NetworkPolicy`**, separados por `---`:

1. uma `NetworkPolicy` cujo `podSelector` seleciona os Pods de **origem** e autoriza o `egress`;
2. uma `NetworkPolicy` cujo `podSelector` seleciona os Pods de **destino** e autoriza o `ingress`.

Uma `NetworkPolicy` só rege os Pods selecionados pelo seu próprio `podSelector`; autorizar apenas um dos lados não torna o fluxo bidirecionalmente permitido perante um `default-deny` de Ingress e Egress.

```text
allow-client-app.yaml
  objeto 1: client   ── egress HTTP ──> Symfony
  objeto 2: Symfony <── ingress HTTP ── client

allow-app-db.yaml
  objeto 1: Symfony    ── egress TCP/5432 ──> PostgreSQL
  objeto 2: PostgreSQL <── ingress TCP/5432 ── Symfony

allow-backup-db.yaml
  objeto 1: role=backup ── egress TCP/5432 ──> PostgreSQL
  objeto 2: PostgreSQL  <── ingress TCP/5432 ── role=backup
```

**Exceção — `allow-dns.yaml`:** este ficheiro não segue a regra dos dois objetos do laboratório. O `default-deny` é aplicado ao Namespace `lab-admin`, enquanto o CoreDNS está normalmente em `kube-system`. Assim, `allow-dns.yaml` contém a regra de **egress** dos Pods isolados para o DNS do cluster, usando o Service/labels reais identificados na Fase 0. Não se cria, neste laboratório, uma `NetworkPolicy` adicional em `kube-system` apenas para representar o lado de ingress do CoreDNS.

```text
allow-dns.yaml
  Pods isolados ── egress UDP/TCP 53 ──> CoreDNS
```

`pod-client.yaml` e `pod-intruder.yaml` devem usar imagens previamente validadas com as ferramentas necessárias; em particular, `intruder` precisa de `nc` para o teste à porta 5432.

Confirmar as políticas efetivamente aplicadas:

```bash
kubectl get networkpolicy -n lab-admin
```

**Resultado esperado (obrigatório registar as evidências):**

```text
client → app        OK
app → db            OK
intruder → db       BLOQUEADO
```

---

## 10. Fase 7 — Persistência e backup (20 min)

### Parte A — Persistência

Obter dinamicamente do próprio Pod PostgreSQL o nome da base de dados e o utilizador configurados pelo Secret. Desta forma o guião não depende de valores escritos manualmente nem assume o utilizador `postgres`:

```bash
APP_DB=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_DB)
APP_USER=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_USER)

echo "Base de dados: $APP_DB"
echo "Utilizador: $APP_USER"
```

Criar a evidência nessa base de dados através do cliente `psql` que já existe no container PostgreSQL — **não é necessário instalar `psql` no Control Plane**:

```bash
kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "CREATE TABLE IF NOT EXISTS teste (id serial PRIMARY KEY, valor text);"

kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "INSERT INTO teste (valor) VALUES ('evidencia-lab-s5');"

kubectl delete pod postgres-0 -n lab-admin

# esperar que o StatefulSet recrie o objeto antes de aguardar Ready
until kubectl get pod postgres-0 -n lab-admin >/dev/null 2>&1; do
  sleep 1
done

kubectl wait --for=condition=Ready pod/postgres-0 -n lab-admin --timeout=120s

kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c "SELECT * FROM teste;"
```

**Resultado esperado:** o registo `evidencia-lab-s5` continua presente após a recriação do Pod.

### Parte B — Backup

```bash
kubectl apply -f 07-backup/backup-pvc.yaml
kubectl apply -f 07-backup/allow-backup-db.yaml
kubectl apply -f 07-backup/backup-job.yaml
kubectl wait --for=condition=complete job/backup-postgres -n lab-admin --timeout=120s
```

**Atenção — base de dados e NetworkPolicy:** `backup-job.yaml` deve executar `pg_dump` sobre a **mesma base de dados definida em `POSTGRES_DB`/`APP_DB`**, obtendo esse valor da mesma configuração/Secret usada pela aplicação. O objetivo é garantir que o artefacto contém precisamente os dados cuja persistência foi validada na Parte A.

A partir da Fase 6, `default-deny.yaml` isola Ingress e Egress. `backup-job.yaml` deve ter a label `role: backup`, e `allow-backup-db.yaml` deve permitir apenas o mínimo necessário:

```text
backup Job ── egress DNS UDP/TCP 53 ──> CoreDNS
backup Job ── egress TCP/5432 ────────> PostgreSQL
PostgreSQL <── ingress TCP/5432 ─────── role=backup
```

Não se remove a `NetworkPolicy` para o backup funcionar — acrescenta-se o fluxo mínimo necessário, reforçando o princípio de menor privilégio.

Se o PVC de backup usar `ReadWriteOnce`, eliminar o Job concluído antes de montar o mesmo PVC no `backup-reader`, garantindo que o Pod do Job deixa de manter o volume associado:

```bash
kubectl delete job backup-postgres -n lab-admin --wait=true

kubectl apply -f 07-backup/backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader -n lab-admin --timeout=60s

kubectl exec backup-reader -n lab-admin -- ls -lh /backup/backup.sql
kubectl exec backup-reader -n lab-admin -- wc -c /backup/backup.sql
kubectl exec backup-reader -n lab-admin -- \
  grep -F "evidencia-lab-s5" /backup/backup.sql
```

**Resultado esperado:** o Job terminou com sucesso; `backup-reader` monta **exclusivamente o PVC de backup** (não o PVC de dados do PostgreSQL); `backup.sql` existe, tem tamanho > 0 e contém `evidencia-lab-s5`. Assim é validado não apenas o ficheiro, mas também que o backup inclui os dados criados na Parte A.

A evidência pedagógica é:

```text
Pod ≠ dados
PVC ≠ backup
Persistência ≠ backup
```

> **Delimitação:** esta fase demonstra persistência e criação/validação de backup. Um exercício completo de restore fica fora do percurso obrigatório de 240 minutos e pode ser disponibilizado como extensão.

---

## 11. Fase 8 — Evidência final e limpeza (10 min)

Cada formando mostra ao formador as evidências recolhidas ao longo do laboratório. No final:

```bash
# guardar os PVs associados ao Namespace antes da eliminação
LAB_PVS=$(kubectl get pv \
  -o custom-columns=NAME:.metadata.name,NAMESPACE:.spec.claimRef.namespace \
  --no-headers | awk '$2 == "lab-admin" {print $1}')

echo "PVs do laboratório: ${LAB_PVS:-nenhum}"

kubectl delete namespace lab-admin --wait=true

# se a shell tiver sido reiniciada, recuperar o Worker pela label criada pelo laboratório
if [ -z "${WORKER_SSD:-}" ]; then
  WORKER_SSD=$(kubectl get nodes -l disco=ssd -o jsonpath='{.items[0].metadata.name}')
fi

test -n "$WORKER_SSD" || { echo "Worker com disco=ssd não encontrado"; exit 1; }
kubectl label node "$WORKER_SSD" disco-

# verificar especificamente os PVs que pertenciam a lab-admin
for PV in $LAB_PVS; do
  if kubectl get pv "$PV" >/dev/null 2>&1; then
    kubectl get pv "$PV"
  else
    echo "$PV removido"
  fi
done
```

**Resultado esperado:** Namespace eliminado, label removida do Worker selecionado na Fase 3 e nenhum PV do laboratório deixado inadvertidamente em estado `Released`. Em StorageClasses com `reclaimPolicy: Delete`, os PVs identificados devem desaparecer; com `Retain`, devem permanecer e ser tratados pelo procedimento de limpeza do ambiente.

> **Atenção:** eliminar o Namespace não remove a label aplicada ao Worker na Fase 3 (recurso cluster-scoped). Os nomes dos PVs do laboratório são capturados antes da eliminação do Namespace para evitar confundi-los com volumes de outros exercícios. Se a StorageClass usar `reclaimPolicy: Retain`, esses PVs podem permanecer após a eliminação dos PVCs; executar o procedimento de limpeza definido para o ambiente e não assumir que a eliminação do Namespace remove storage externo.

---

## 12. Estado de validação técnica

Este guião foi validado de ponta a ponta num cluster de referência com **1 Control Plane + 2 Workers**, Calico, CoreDNS, provisionamento dinâmico `local-path`, Symfony Demo e PostgreSQL 16. Durante o ensaio foram corrigidos os seguintes pontos antes desta versão:

- runtime Symfony ajustado para `APP_ENV=prod`;
- rollout com Anti-Affinity obrigatória ajustado para `maxSurge: 0` / `maxUnavailable: 1`;
- descoberta dinâmica do Worker e do Pod Symfony, sem nomes/IPs específicos;
- `kubectl wait` antes de `exec` em Pods de teste;
- testes HTTP com status e código de saída observáveis;
- progressão `baseline → default deny → DNS → fluxos aplicacionais` em `NetworkPolicy`;
- `POSTGRES_DB` e `POSTGRES_USER` obtidos dinamicamente na validação de persistência;
- evidência de backup confirmada num PVC separado;
- limpeza final validada, distinguindo os PVs de `lab-admin` dos volumes pertencentes a outros Namespaces.

O restore completo continua deliberadamente fora do percurso obrigatório de 240 minutos.

---

## 13. Notas de operação para o formador

- O laboratório não depende de nomes nem IPs específicos de Nodes. O Worker usado no `nodeSelector` é descoberto dinamicamente na Fase 3 e guardado em `WORKER_SSD` para reutilização na limpeza.
- Confirmar antes da formação que o Control Plane não será utilizado como destino de workloads aplicacionais.
- Confirmar que nenhum Node possui previamente a label `disco=ssd`; esta condição torna inequívoca a label criada pelo laboratório.
- Confirmar que a imagem Symfony é executada com a configuração validada (`APP_ENV=prod` nesta versão); `APP_ENV=dev` não deve ser usado se a imagem não incluir `DebugBundle`.
- Confirmar que o patch de Anti-Affinity mantém `maxSurge: 0` e `maxUnavailable: 1`; com apenas dois Workers e Anti-Affinity obrigatória, `maxSurge: 1` pode bloquear o rollout ao tentar criar temporariamente uma terceira réplica.
- Após aplicar os workloads da Fase 2, aguardar explicitamente pelos rollouts do StatefulSet PostgreSQL e do Deployment Symfony antes de iniciar scheduling.
- Os ficheiros `symfony-nodeselector-patch.yaml`, `symfony-antiaffinity-patch.yaml` e `securitycontext-patch.yaml` devem ser testados como patches sobre o Deployment `symfony` efetivamente usado no laboratório.
- Se a Experiência C (Fase 3) não gerar `Pending` no primeiro `apply`, ter um segundo manifest de reserva com uma condição impossível diferente.
- O Job de backup deve ser idempotente ou o Namespace deve ser recriado entre turmas, para evitar conflitos de nome em `backup-postgres`.
- Confirmar que `default-deny.yaml` isola Ingress e Egress e que cada política de autorização cobre explicitamente os dois lados do fluxo que pretende permitir.
- Após criar `client` e `intruder`, usar sempre `kubectl wait` antes do primeiro `kubectl exec`; sem esta espera, o Pod pode existir na API antes de o container estar disponível.
- Nos testes HTTP de validação, preferir corpo curto/status HTTP e código de saída (`HTTP 200`/`0` ou `HTTP 000`/erro) em vez de depender apenas da presença ou ausência de texto.
- Confirmar que `allow-dns.yaml` foi construído a partir das labels/Service reais do CoreDNS do cluster.
- Confirmar que `/ready` (ou a rota escolhida antes da sessão) depende efetivamente do PostgreSQL; não usar uma rota que apenas valide o processo HTTP.
- Confirmar que a Parte A obtém `POSTGRES_DB` e `POSTGRES_USER` dinamicamente do Pod/Secret e executa `psql` dentro do container PostgreSQL; não exigir `psql` instalado no Control Plane.
- Confirmar que o Job executa `pg_dump` sobre a mesma `POSTGRES_DB` usada na Parte A e que `backup.sql` contém `evidencia-lab-s5`.
- Confirmar que o Pod do Job é eliminado antes do `backup-reader` quando o PVC de backup é `ReadWriteOnce`.
- Confirmar que o `backup-reader` termina ou é removido com o Namespace sem manter mounts ativos desnecessários.
- Na limpeza, capturar os nomes dos PVs cujo `claimRef.namespace` é `lab-admin` antes de eliminar o Namespace e verificar apenas esses PVs; não usar a listagem global como prova isolada, pois o cluster pode conter volumes de outros laboratórios.
- Cada ficheiro que autoriza um fluxo **entre workloads isolados** (`allow-client-app.yaml`, `allow-app-db.yaml` e `allow-backup-db.yaml`) deve conter **dois objetos `NetworkPolicy`**: origem/`egress` e destino/`ingress`. `allow-dns.yaml` é a exceção, porque autoriza egress do Namespace `lab-admin` para o CoreDNS em `kube-system`; o laboratório não cria uma política adicional no Namespace do DNS.