# Laboratório Integrado — Sessão 5
## Kubernetes Admin II — Administração e Governação de uma Aplicação

**Sessão:** 5 de 10  
**Nível:** intermédio  
**Topologia:** 1 Control Plane + 2 Workers elegíveis  
**CNI:** Calico  
**Aplicação:** Symfony Demo + PostgreSQL 16  
**Namespace:** `lab-admin`

Este documento é o **único laboratório integrado da Sessão 5**. O objetivo não é apenas executar comandos: em cada checkpoint o formando deve saber **o que está a fazer, por que o faz, o que deve observar e que evidência prova o resultado**.

A sequência pedagógica segue o padrão comum da formação:

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
ONDE EXECUTAR
   ↓
COMANDOS / MANIFESTOS
   ↓
FLAGS / CAMPOS IMPORTANTES
   ↓
OUTPUT / ESTADO ESPERADO
   ↓
O QUE OBSERVAR
   ↓
TESTE NEGATIVO / FALHA CONTROLADA, quando aplicável
   ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
   ↓
EVIDÊNCIA A REGISTAR
```

> **Regra do laboratório:** um `kubectl apply` sem erro prova apenas que a API aceitou o recurso. Não prova que o comportamento pretendido está a acontecer.

> **Portabilidade:** os comandos destinados aos formandos não dependem de nomes nem IPs específicos de Nodes. O Worker usado no exercício de `nodeSelector` é descoberto dinamicamente.

---

# 0. Baseline e preparação do formador

Antes da sessão, o formador deve confirmar:

- cluster acessível com 3 Nodes `Ready`;
- Control Plane não elegível para workloads aplicacionais normais;
- pelo menos 2 Workers elegíveis e `Ready`;
- StorageClass com provisionamento dinâmico;
- Calico operacional e enforcement de `NetworkPolicy` previamente validado;
- CoreDNS operacional e respetivas labels/Service identificados;
- imagem `ghcr.io/skullclamp/symfony-demo:1.0.0` acessível e validada com `APP_ENV=prod`;
- imagem `postgres:16` acessível;
- `POSTGRES_DB` coerente entre PostgreSQL, Symfony e Job de backup;
- rota `/ready` validada como dependente do PostgreSQL;
- imagem de diagnóstico de `04-networking/pod-debug.yaml` com `curl`, `nslookup` e `nc`;
- nenhum Node com a label `disco=ssd` antes do laboratório;
- `symfony-antiaffinity-patch.yaml` com Anti-Affinity obrigatória por `kubernetes.io/hostname` e rollout `maxSurge: 0`, `maxUnavailable: 1`;
- `ResourceQuota` com margem para todos os Pods previstos;
- todos os manifests testados de ponta a ponta.

O laboratório foi validado de ponta a ponta com Symfony Demo, PostgreSQL 16, Calico, CoreDNS e provisionamento dinâmico `local-path`. O restore completo não faz parte do percurso obrigatório do laboratório.

---

# Estrutura dos recursos

A partir da diretoria `sessao-05-06/`:

```text
sessao-05-06/
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
├── 07-backup/
│   ├── backup-pvc.yaml
│   ├── backup-job.yaml
│   ├── backup-reader.yaml
│   └── allow-backup-db.yaml
└── labs/
    └── laboratorio_integrado_sessao_5.md
```

---

# CP0 — Obter os recursos e validar o cluster

## Objetivo

Garantir que o repositório está atualizado, que o cluster cumpre a baseline e que o Namespace do laboratório pode ser criado em segurança.

**Executar em:** terminal de administração com `kubectl` funcional e permissões para os recursos usados no laboratório.

## O que estamos a fazer e porquê

Não assumimos que a shell abriu dentro do repositório. Primeiro obtemos ou atualizamos a branch `main`; depois validamos Nodes, storage, CNI, DNS e políticas existentes antes de criar recursos.

## 0.1. Obter ou atualizar o repositório

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

cd "$REPO_DIR/sessao-05-06"

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short
```

### Como interpretar

```text
git -C ...        → executa Git na diretoria indicada
switch main       → garante a branch usada na formação
pull --ff-only    → atualiza sem criar merges locais inesperados
--single-branch   → clona apenas a branch necessária
```

## 0.2. Validar infraestrutura

```bash
kubectl get nodes -o wide
kubectl get sc
kubectl get pods -A | grep -i calico
kubectl get pods -n kube-system --show-labels
kubectl get svc -n kube-system
kubectl get networkpolicy -A
kubectl get nodes -l disco=ssd
```

### O que observar

- 3 Nodes `Ready`;
- Control Plane não utilizado como destino de workloads aplicacionais;
- 2 Workers disponíveis;
- StorageClass dinâmica disponível;
- Calico sem erros;
- CoreDNS operacional;
- nenhuma label `disco=ssd` preexistente.

## 0.3. Criar o Namespace

```bash
kubectl apply -f 00-namespace.yaml
kubectl get namespace lab-admin
```

Todos os comandos seguintes usam `-n lab-admin` explicitamente. Não alteramos o contexto atual do `kubeconfig`.

### CHECKPOINT CP0

```text
branch main ativa
recursos da sessão disponíveis
3 Nodes Ready
StorageClass disponível
Calico e CoreDNS operacionais
nenhum Node previamente marcado disco=ssd
Namespace lab-admin Active
```

**Não avançar** se a infraestrutura base estiver degradada.

**Evidência:** guardar `kubectl get nodes -o wide`, `kubectl get sc` e a confirmação do Namespace.

---

# CP1 — Governação inicial com LimitRange e ResourceQuota

## Objetivo

Aplicar defaults de recursos ao Namespace e provar que uma quota pode impedir a criação de um workload que excede a política definida.

**Executar em:** terminal de administração, dentro de `sessao-05-06/`.

## O que estamos a fazer e porquê

`LimitRange` permite definir defaults/limites por objeto; `ResourceQuota` controla o consumo agregado do Namespace. Primeiro observamos um Pod que recebe recursos por defeito; depois provocamos uma falha controlada por quota.

## 1.1. Aplicar governação

```bash
kubectl apply -f 01-governacao/limitrange.yaml
kubectl apply -f 01-governacao/resourcequota.yaml

kubectl describe limitrange -n lab-admin
kubectl describe resourcequota -n lab-admin
```

## 1.2. Provar a aplicação de defaults

```bash
kubectl run teste-sem-limites --image=nginx -n lab-admin

kubectl get pod teste-sem-limites \
  -n lab-admin \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'

kubectl delete pod teste-sem-limites -n lab-admin
```

### Flags importantes

```text
-n lab-admin     → Namespace alvo
-o jsonpath=...  → extrai diretamente o campo de recursos do Pod
```

Eliminar o Pod de teste é obrigatório para não consumir quota nas fases seguintes.

## 1.3. Falha controlada — exceder a quota

```bash
kubectl apply -f 01-governacao/pod-acima-da-quota.yaml
```

### Resultado esperado

A API deve rejeitar o recurso com mensagem semelhante a `exceeded quota`.

### CHECKPOINT CP1

```text
LimitRange aplicado
ResourceQuota aplicado
Pod sem recursos explícitos recebeu defaults
Pod acima da quota foi rejeitado
```

**Evidência:** guardar os recursos atribuídos ao Pod de teste e a mensagem completa da rejeição por quota.

---

# CP2 — Disponibilizar a aplicação e o storage

## Objetivo

Disponibilizar PostgreSQL persistente e duas réplicas Symfony, observando as relações entre Secret, Service, StatefulSet, Deployment e PVC.

**Executar em:** terminal de administração, dentro de `sessao-05-06/`.

## O que estamos a fazer e porquê

Criamos primeiro a configuração e o endpoint estável da base de dados; depois o StatefulSet e a aplicação. Os rollouts são aguardados explicitamente antes de avançar para alterações de scheduling.

## 2.1. Aplicar os recursos na ordem das dependências

```bash
kubectl apply -f 02-aplicacao/postgres-secret.yaml
kubectl apply -f 02-aplicacao/postgres-service-headless.yaml
kubectl apply -f 02-aplicacao/postgres-statefulset.yaml
kubectl apply -f 02-aplicacao/symfony-deployment.yaml
kubectl apply -f 02-aplicacao/symfony-service.yaml
```

## 2.2. Aguardar convergência

```bash
kubectl rollout status statefulset/postgres -n lab-admin --timeout=120s
kubectl rollout status deployment/symfony -n lab-admin --timeout=120s
```

`rollout status` não cria recursos; espera que o controller atinja o estado desejado ou termine por timeout.

## 2.3. Observar workloads e storage

```bash
kubectl get pods -n lab-admin -o wide
kubectl get statefulset -n lab-admin
kubectl get deployment -n lab-admin
kubectl get svc -n lab-admin
kubectl get pvc -n lab-admin
kubectl get pv
```

### O que observar

```text
postgres-0        → Running / Ready
Symfony           → 2 réplicas Running / Ready
PVC PostgreSQL    → Bound
Service postgres  → headless
Service symfony   → disponível no Namespace
```

A ordem `Secret → Headless Service → StatefulSet` torna explícitas as dependências do PostgreSQL antes do arranque do workload.

### CHECKPOINT CP2

```text
PostgreSQL Ready
PVC Bound
Deployment Symfony 2/2 disponível
Services criados
sem Pods em CrashLoopBackOff ou Pending inesperado
```

**Evidência:** guardar `kubectl get pods -n lab-admin -o wide` e `kubectl get pvc -n lab-admin`.

---

# CP3 — Scheduling: seleção, distribuição e falha controlada

## Objetivo

Observar três comportamentos distintos do scheduler:

1. seleção obrigatória de um Worker por label;
2. distribuição obrigatória das réplicas Symfony por hostname;
3. um Pod não agendável por condição impossível.

**Executar em:** terminal de administração.

## Health gate antes das alterações

```bash
kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

Não iniciar alterações de placement se as duas réplicas Symfony não estiverem saudáveis.

## 3.1. Experiência A — `nodeSelector`

### O que estamos a fazer e porquê

Selecionamos dinamicamente um Worker `Ready`, aplicamos a label `disco=ssd` e restringimos o Deployment Symfony a Nodes com essa label.

```bash
WORKER_SSD=$(kubectl get nodes \
  -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' \
  --no-headers | awk '$2 ~ /^Ready/ {print $1; exit}')

test -n "$WORKER_SSD" || { echo "Nenhum Worker Ready encontrado"; exit 1; }
echo "Worker selecionado: $WORKER_SSD"

kubectl label node "$WORKER_SSD" disco=ssd --overwrite
kubectl get node "$WORKER_SSD" --show-labels
```

Aplicar o patch:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-nodeselector-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

### Campos importantes

```text
nodeSelector    → exige que o Node tenha a label indicada
--patch-file    → lê o patch a partir do ficheiro validado
-o wide         → mostra, entre outros dados, o Node escolhido
```

**Esperado:** as réplicas Symfony ficam elegíveis apenas para o Worker com `disco=ssd`.

> O exercício altera apenas o Deployment Symfony. Não deslocamos deliberadamente o PostgreSQL entre Workers, porque a portabilidade do volume depende da StorageClass e da topologia do ambiente.

## 3.2. Experiência B — Anti-Affinity obrigatória

Antes da Anti-Affinity, remover o `nodeSelector` para não manter uma restrição incompatível com a distribuição por Workers diferentes:

```bash
kubectl patch deployment symfony -n lab-admin \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

Aplicar o patch validado:

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 03-scheduling/symfony-antiaffinity-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
kubectl get pods -n lab-admin -l app=symfony -o wide
```

### Porque o rollout também interessa

O patch usa Anti-Affinity obrigatória por:

```text
requiredDuringSchedulingIgnoredDuringExecution
        +
topologyKey: kubernetes.io/hostname
```

Com duas réplicas e apenas dois Workers elegíveis, um rollout com `maxSurge: 1` tentaria criar temporariamente uma terceira réplica, que não teria hostname disponível compatível com a Anti-Affinity. Por isso o patch validado usa:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
```

**Esperado:** rollout concluído e uma réplica Symfony em cada Worker.

## 3.3. Experiência C — falha intencional de scheduling

```bash
kubectl apply -f 03-scheduling/pod-pending-exemplo.yaml
kubectl get pod pod-pending-exemplo -n lab-admin -o wide
kubectl describe pod pod-pending-exemplo -n lab-admin
kubectl get events -n lab-admin --sort-by=.lastTimestamp
```

### Resultado esperado

O Pod fica `Pending` e os Events apresentam `FailedScheduling`, indicando que os Nodes não satisfazem a condição de placement.

Depois da evidência:

```bash
kubectl delete pod pod-pending-exemplo -n lab-admin
```

### CHECKPOINT CP3

```text
nodeSelector concentrou Symfony no Worker marcado
Anti-Affinity distribuiu as duas réplicas por hostnames diferentes
rollout concluiu sem terceira réplica bloqueada
Pod impossível ficou Pending com FailedScheduling
```

**Evidência:** guardar a distribuição dos Pods antes/depois e a causa de `FailedScheduling`.

---

# CP4 — Networking, DNS e cadeia aplicação → base de dados

## Objetivo

Provar resolução DNS dentro do cluster, acesso ao Service Symfony e prontidão da aplicação com dependência real do PostgreSQL.

**Executar em:** terminal de administração; os testes de rede são executados dentro do Pod `debug`.

## O que estamos a fazer e porquê

Criamos um Pod de diagnóstico com ferramentas previamente validadas. Não usamos a shell do Node para provar comunicação Pod-to-Service, porque queremos observar o percurso a partir da rede dos Pods.

## 4.1. Criar e aguardar o Pod de diagnóstico

```bash
kubectl apply -f 04-networking/pod-debug.yaml
kubectl wait --for=condition=Ready pod/debug -n lab-admin --timeout=60s
```

`kubectl wait` evita uma condição de corrida entre a criação do objeto Pod e a disponibilidade efetiva do container para `exec`.

## 4.2. Resolver os Services

```bash
kubectl exec debug -n lab-admin -- nslookup symfony
kubectl exec debug -n lab-admin -- nslookup postgres
```

**Esperado:** ambos os nomes resolvem para endereços do cluster.

## 4.3. Testar o Service Symfony

```bash
kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony
```

### Flags relevantes

```text
-sS             → modo silencioso, mas mostra erros
--max-time 5    → limita a espera total
-o /dev/null    → descarta o corpo HTML
-w ...          → mostra explicitamente o código HTTP
```

**Esperado:** `HTTP 200`.

## 4.4. Provar `debug → app → db`

A rota `/ready` usada neste laboratório foi previamente validada como dependente do PostgreSQL.

```bash
kubectl exec debug -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready
```

**Esperado:** corpo semelhante a:

```text
{"status":"ready","database":"ok"}
HTTP 200
```

Eliminar o Pod temporário:

```bash
kubectl delete pod debug -n lab-admin
```

## 4.5. Gateway API — apenas enquadramento conceptual

Nesta sessão não instalamos controller nem aplicamos manifests de Gateway API. A relação a compreender é:

```text
GatewayClass → Gateway → HTTPRoute → Service → Pods
```

### CHECKPOINT CP4

```text
DNS de symfony resolve
DNS de postgres resolve
Service Symfony responde HTTP 200
/ready confirma database=ok
Pod debug eliminado
```

**Evidência:** guardar os dois `nslookup` e a resposta de `/ready` com `HTTP 200`.

---

# CP5 — Identidade, RBAC e hardening do workload

## Objetivo

Dar ao workload Symfony uma identidade própria, aplicar menor privilégio na API e endurecer o contexto de segurança sem impedir a aplicação de arrancar.

**Executar em:** terminal de administração.

## 5.1. Criar identidade e autorização

```bash
kubectl apply -f 05-identidade/serviceaccount.yaml
kubectl apply -f 05-identidade/role.yaml
kubectl apply -f 05-identidade/rolebinding.yaml
```

## 5.2. Teste positivo e negativo de RBAC

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:lab-admin:app-reader \
  -n lab-admin

kubectl auth can-i delete pods \
  --as=system:serviceaccount:lab-admin:app-reader \
  -n lab-admin
```

### Como interpretar

```text
get pods        → deve ser permitido
delete pods     → deve ser negado
--as=...        → simula a identidade da ServiceAccount indicada
```

**Esperado:** primeiro comando `yes`; segundo comando `no`.

## 5.3. Aplicar o `SecurityContext`

O patch foi previamente validado para a imagem usada no laboratório.

```bash
kubectl patch deployment symfony -n lab-admin \
  --patch-file 05-identidade/securitycontext-patch.yaml

kubectl rollout status deployment/symfony -n lab-admin --timeout=60s
```

A configuração inclui:

```text
serviceAccountName: app-reader
automountServiceAccountToken: false
allowPrivilegeEscalation: false
capabilities.drop: [ALL]
seccompProfile: RuntimeDefault
```

Capabilities adicionais só devem existir se forem necessárias e previamente validadas para a imagem.

## 5.4. Confirmar a configuração efetiva

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

kubectl get pods -n lab-admin -l app=symfony -o wide
```

### CHECKPOINT CP5

```text
ServiceAccount dedicada aplicada
get pods = yes
delete pods = no
automountServiceAccountToken = false
SecurityContext endurecido
2 réplicas Symfony continuam Ready
```

**Evidência:** guardar os dois `can-i`, a identidade do Deployment e o `securityContext` efetivo de um Pod.

---

# CP6 — NetworkPolicy: fechar tudo e reabrir apenas o necessário

## Objetivo

Demonstrar isolamento de rede por política, distinguindo DNS de tráfego aplicacional e provando simultaneamente um fluxo permitido e um fluxo bloqueado.

**Executar em:** terminal de administração; testes dentro dos Pods `client` e `intruder`.

## O que estamos a fazer e porquê

Começamos com comunicação livre, aplicamos `default-deny` para Ingress e Egress e reabrimos progressivamente apenas:

```text
DNS
client → Symfony
Symfony → PostgreSQL
```

O Pod `intruder` nunca recebe autorização para chegar ao PostgreSQL.

## 6.1. Criar os clientes de teste e esperar por `Ready`

```bash
kubectl apply -f 06-networkpolicy/pod-client.yaml
kubectl apply -f 06-networkpolicy/pod-intruder.yaml

kubectl wait --for=condition=Ready pod/client -n lab-admin --timeout=120s
kubectl wait --for=condition=Ready pod/intruder -n lab-admin --timeout=120s
```

## 6.2. Baseline — antes do isolamento

```bash
kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Esperado:** `database=ok`, `HTTP 200` e exit code `0`.

Este baseline é obrigatório: sem ele não saberíamos se uma falha posterior foi introduzida pela política ou já existia.

## 6.3. Aplicar `default-deny`

```bash
kubectl apply -f 06-networkpolicy/default-deny.yaml
kubectl get networkpolicy -n lab-admin

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 3 \
  -o /dev/null \
  -w 'HTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Esperado:** falha. Como o egress DNS também fica bloqueado, o primeiro sintoma pode ser timeout de resolução, `HTTP 000` e exit code diferente de `0`.

## 6.4. Reabrir apenas DNS

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

**Esperado:** DNS funciona novamente, mas HTTP continua bloqueado.

Esta etapa prova que:

```text
resolver nomes ≠ autorizar comunicação aplicacional
```

## 6.5. Reabrir os fluxos aplicacionais necessários

```bash
kubectl apply -f 06-networkpolicy/allow-client-app.yaml
kubectl apply -f 06-networkpolicy/allow-app-db.yaml

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready

echo $?
```

**Esperado:** `database=ok`, `HTTP 200`, exit code `0`.

## 6.6. Teste negativo obrigatório — `intruder → db`

```bash
kubectl exec intruder -n lab-admin -- \
  nc -zvw3 postgres 5432

echo $?
```

**Esperado:** timeout/conexão bloqueada e exit code diferente de `0`.

## 6.7. Interpretar o contrato das políticas

Com `default-deny` de Ingress e Egress, os fluxos entre workloads são autorizados nos dois extremos:

```text
allow-client-app.yaml
  client  ── egress HTTP ──> Symfony
  Symfony <── ingress HTTP ── client

allow-app-db.yaml
  Symfony    ── egress TCP/5432 ──> PostgreSQL
  PostgreSQL <── ingress TCP/5432 ── Symfony

allow-backup-db.yaml
  role=backup ── egress TCP/5432 ──> PostgreSQL
  PostgreSQL  <── ingress TCP/5432 ── role=backup
```

`allow-dns.yaml` é diferente: autoriza o egress dos Pods de `lab-admin` para o CoreDNS no Namespace do sistema; este laboratório não cria uma política adicional no Namespace do DNS.

Confirmar o estado final:

```bash
kubectl get networkpolicy -n lab-admin
```

### CHECKPOINT CP6

```text
baseline client → app → db = OK
default-deny = comunicação bloqueada
DNS reaberto sem reabrir HTTP
client → app → db = OK depois das allows
intruder → db = BLOQUEADO
```

**Evidência:** registar `HTTP 200/0` do fluxo permitido e a falha/exit code do `intruder`.

---

# CP7 — Persistência e backup independente

## Objetivo

Provar duas propriedades diferentes:

1. os dados sobrevivem à recriação do Pod PostgreSQL;
2. existe um backup independente, guardado noutro PVC, contendo a evidência criada.

**Executar em:** terminal de administração.

## Health gate antes da falha controlada

```bash
kubectl get pod postgres-0 -n lab-admin

kubectl exec client -n lab-admin -- \
  curl -sS --max-time 5 \
  -w '\nHTTP %{http_code}\n' \
  http://symfony/ready
```

Só avançar se PostgreSQL estiver `Ready` e `/ready` devolver `HTTP 200`.

## 7.1. Parte A — provar persistência

Obter dinamicamente as credenciais não-secretas necessárias ao comando:

```bash
APP_DB=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_DB)
APP_USER=$(kubectl exec postgres-0 -n lab-admin -- printenv POSTGRES_USER)

echo "Base de dados: $APP_DB"
echo "Utilizador: $APP_USER"
```

Criar a evidência usando `psql` dentro do próprio container PostgreSQL:

```bash
kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "CREATE TABLE IF NOT EXISTS teste (id serial PRIMARY KEY, valor text);"

kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "INSERT INTO teste (valor) VALUES ('evidencia-lab-s5');"
```

Não é necessário instalar `psql` no Node de administração.

Provocar a recriação do Pod:

```bash
kubectl delete pod postgres-0 -n lab-admin

until kubectl get pod postgres-0 -n lab-admin >/dev/null 2>&1; do
  sleep 1
done

kubectl wait --for=condition=Ready pod/postgres-0 \
  -n lab-admin \
  --timeout=120s
```

Validar os dados depois da recriação:

```bash
kubectl exec postgres-0 -n lab-admin -- \
  psql -U "$APP_USER" -d "$APP_DB" -c \
  "SELECT * FROM teste;"
```

**Esperado:** o registo `evidencia-lab-s5` continua presente.

Conclusão intermédia:

```text
Pod eliminado
    ↓
Pod recriado
    ↓
mesmo PVC
    ↓
dados preservados
```

## 7.2. Parte B — criar um backup independente

```bash
kubectl apply -f 07-backup/backup-pvc.yaml
kubectl apply -f 07-backup/allow-backup-db.yaml
kubectl apply -f 07-backup/backup-job.yaml

kubectl wait --for=condition=complete \
  job/backup-postgres \
  -n lab-admin \
  --timeout=120s
```

O Job usa a mesma `POSTGRES_DB` da aplicação e, como o `default-deny` continua ativo, recebe apenas os fluxos mínimos necessários através de `allow-backup-db.yaml` e da política DNS já existente.

Se o PVC de backup for `ReadWriteOnce`, eliminar o Job concluído antes de montar o volume no reader:

```bash
kubectl delete job backup-postgres -n lab-admin --wait=true

kubectl apply -f 07-backup/backup-reader.yaml
kubectl wait --for=condition=Ready pod/backup-reader -n lab-admin --timeout=60s
```

Validar o artefacto:

```bash
kubectl exec backup-reader -n lab-admin -- \
  ls -lh /backup/backup.sql

kubectl exec backup-reader -n lab-admin -- \
  wc -c /backup/backup.sql

kubectl exec backup-reader -n lab-admin -- \
  grep -F "evidencia-lab-s5" /backup/backup.sql
```

### O que observar

- `backup.sql` existe;
- tamanho maior que zero;
- contém `evidencia-lab-s5`;
- `backup-reader` monta o PVC de backup, não o PVC de dados do PostgreSQL.

A regra a reter é:

```text
Pod ≠ dados
PVC ≠ backup
Persistência ≠ backup
```

> Um restore completo fica fora do percurso obrigatório e pode ser tratado como extensão.

### CHECKPOINT CP7

```text
dados preservados após recriação do Pod
Job de backup Complete
backup.sql existe e não está vazio
backup.sql contém evidencia-lab-s5
backup guardado em PVC separado
```

**Evidência:** guardar o `SELECT`, o estado `Complete`, o tamanho do ficheiro e o `grep` da evidência.

---

# CP8 — Evidência final e limpeza

## Objetivo

Fechar o laboratório sem deixar estado cluster-scoped ou storage do exercício por tratar e consolidar as evidências recolhidas.

**Executar em:** terminal de administração.

## 8.1. Capturar os PVs do laboratório antes de eliminar o Namespace

```bash
LAB_PVS=$(kubectl get pv \
  -o custom-columns=NAME:.metadata.name,NAMESPACE:.spec.claimRef.namespace \
  --no-headers | awk '$2 == "lab-admin" {print $1}')

echo "PVs do laboratório: ${LAB_PVS:-nenhum}"
```

Guardamos os nomes antes da eliminação para não confundir os PVs desta sessão com volumes de outros exercícios existentes no cluster.

## 8.2. Eliminar o Namespace

```bash
kubectl delete namespace lab-admin --wait=true
```

Eliminar o Namespace elimina os recursos namespaced do laboratório, mas **não remove labels aplicadas a Nodes**, porque Nodes são recursos cluster-scoped.

## 8.3. Remover a label criada na Fase de scheduling

Se a variável ainda existir:

```bash
if [ -z "${WORKER_SSD:-}" ]; then
  WORKER_SSD=$(kubectl get nodes -l disco=ssd -o jsonpath='{.items[0].metadata.name}')
fi

test -n "$WORKER_SSD" || { echo "Worker com disco=ssd não encontrado"; exit 1; }

kubectl label node "$WORKER_SSD" disco-
```

## 8.4. Verificar apenas os PVs que pertenciam ao laboratório

```bash
for PV in $LAB_PVS; do
  if kubectl get pv "$PV" >/dev/null 2>&1; then
    kubectl get pv "$PV"
  else
    echo "$PV removido"
  fi
done
```

### Como interpretar

- com `reclaimPolicy: Delete`, os PVs provisionados dinamicamente devem desaparecer;
- com `reclaimPolicy: Retain`, podem permanecer e têm de ser tratados pelo procedimento de limpeza do ambiente;
- uma listagem global de PVs não é prova suficiente se o cluster tiver volumes de outros laboratórios.

### CHECKPOINT CP8

```text
Namespace lab-admin eliminado
label disco=ssd removida do Worker selecionado
PVs do laboratório identificados e verificados
nenhum recurso do exercício ficou inadvertidamente por tratar
```

**Evidência:** guardar a confirmação da eliminação do Namespace, da remoção da label e o estado final dos PVs capturados.

---

# Checklist de autoavaliação

No fim da sessão, devo conseguir afirmar:

- [ ] Consigo explicar a diferença entre `LimitRange` e `ResourceQuota`.
- [ ] Consigo interpretar porque um Pod pode ser aceite pela API e ficar `Pending` no scheduler.
- [ ] Consigo distinguir `nodeSelector` de Pod Anti-Affinity.
- [ ] Consigo explicar por que a estratégia de rollout interfere com Anti-Affinity obrigatória.
- [ ] Consigo validar DNS, Service e a dependência aplicação → base de dados.
- [ ] Consigo testar RBAC com uma ação permitida e outra negada.
- [ ] Consigo interpretar os principais campos de um `SecurityContext` de menor privilégio.
- [ ] Consigo explicar `default-deny` e reabrir apenas os fluxos necessários com `NetworkPolicy`.
- [ ] Consigo distinguir persistência de backup.
- [ ] Consigo recolher evidência antes de concluir que uma configuração funciona.

---

# Regra de evidência da Sessão 5

```text
APLICAR
   ≠
VALIDAR

Objeto criado
   ↓
Estado observado
   ↓
Comportamento testado
   ↓
Teste positivo / negativo quando aplicável
   ↓
Evidência recolhida
   ↓
Conclusão técnica
```

Na Sessão 5, uma conclusão só é aceite quando existe evidência do comportamento real: quota rejeitada, placement observado, `FailedScheduling`, `HTTP 200`, ação RBAC negada, fluxo de rede bloqueado, dados preservados ou backup validado.

---

# Mapa final do laboratório

```text
Namespace e governação
        ↓
Aplicação + PostgreSQL + PVC
        ↓
Scheduling e distribuição
        ↓
DNS + Service + readiness
        ↓
ServiceAccount + RBAC + SecurityContext
        ↓
Default deny + allow mínimo
        ↓
Persistência + backup independente
        ↓
Evidências + limpeza
```

---

# Notas de operação para o formador

- Validar antes da formação que o Control Plane não recebe workloads aplicacionais normais.
- Confirmar que nenhum Node possui previamente `disco=ssd`.
- Manter `APP_ENV=prod` na imagem Symfony usada nesta versão.
- Manter `maxSurge: 0` e `maxUnavailable: 1` no patch de Anti-Affinity enquanto o laboratório tiver exatamente dois Workers elegíveis.
- Aguardar sempre os rollouts da Fase 2 antes de iniciar scheduling.
- Usar `kubectl wait` antes do primeiro `exec` em Pods temporários.
- Confirmar que `allow-dns.yaml` corresponde às labels reais do CoreDNS do cluster.
- Confirmar que `/ready` depende efetivamente do PostgreSQL.
- Obter `POSTGRES_DB` e `POSTGRES_USER` dinamicamente; não exigir `psql` instalado no Node.
- Confirmar que `backup.sql` contém `evidencia-lab-s5`.
- Eliminar o Job antes do `backup-reader` quando o PVC de backup for `ReadWriteOnce`.
- Na limpeza, verificar apenas os PVs cujo `claimRef.namespace` era `lab-admin`.
- Não confundir `PVC`, `backup` e `restore`: são conceitos e operações diferentes.
