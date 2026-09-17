# Sessão 10 — Laboratório Integrado Acompanhado

## Kubernetes para Developers — consolidação M3 + M4 + M5 + M6

**Duração:** 80 minutos  
**Modalidade:** execução guiada com checkpoints  
**Cenário:** Symfony Demo + PostgreSQL 16

## Distribuição temporal

| Bloco | Tempo |
|---|---:|
| 0. Namespace + baseline M3/M4 | 10 min |
| 1. Resources + probes | 15 min |
| 2. HPA | 10 min |
| 3. ServiceAccount + SecurityContext + NetworkPolicy | 15 min |
| 4. Release defeituosa + diagnóstico + rollback | 25 min |
| 5. Validação e síntese | 5 min |
| **Total** | **80 min** |

> O cenário `03_observabilidade_opcional/` foi validado, mas não entra nesta contagem. O troubleshooting principal é realizado no bloco da release defeituosa.

---

# 0. Namespace e baseline — 10 min

Cada formando/par usa um namespace próprio:

```bash
export NS=s10-dev-01
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace="$NS"
```

O Secret real deve estar pré-provisionado ou criado a partir do exemplo da Sessão 9, sem expor valores em ecrã.

Aplicar/reutilizar o baseline:

```bash
kubectl -n "$NS" apply -f ../sessao_9/baseline/01-configmap.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/03-postgresql.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/04-symfony-deployment.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/05-symfony-service.yaml
```

Validar:

```bash
bash 00_precheck/validar-baseline.sh
```

**Checkpoint:** PostgreSQL 1/1, Symfony 2/2, PVC Bound, `/health`, `/ready` e `/info` funcionais.

---

# 1. Resources + probes — 15 min

Antes de aplicar, pedir aos formandos que identifiquem o que **ainda não existe** no baseline Symfony.

```bash
kubectl -n "$NS" apply -f 01_resources_probes/deployment-resources-probes.yaml
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

Observar:

```bash
kubectl -n "$NS" get pods -l app=symfony-demo
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='requests.cpu={.spec.template.spec.containers[0].resources.requests.cpu}{"  limits.cpu="}{.spec.template.spec.containers[0].resources.limits.cpu}{"\n"}liveness={.spec.template.spec.containers[0].livenessProbe.httpGet.path}{"  readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

Mensagem-chave:

```text
Running ≠ Ready
```

**Checkpoint:** `100m/128Mi` requests, `500m/512Mi` limits, liveness `/health`, readiness `/ready`.

---

# 2. HPA — 10 min

Pré-condição:

```bash
kubectl -n "$NS" top pods
```

Aplicar:

```bash
kubectl -n "$NS" apply -f 02_hpa/hpa.yaml
kubectl -n "$NS" get hpa
```

Iniciar carga:

```bash
./02_hpa/gerar-carga.sh
```

Observar em terminal separado — usar comandos separados para HPA e Pods:

```bash
watch -n 5 'kubectl -n s10-dev-01 get hpa; echo; kubectl -n s10-dev-01 get pods -l app=symfony-demo'
```

Parar carga:

```bash
./02_hpa/parar-carga.sh
```

**Checkpoint principal:** observar scale-out e interpretar current/target/min/max. O scale-down pode ser confirmado mais tarde; no ensaio real o controlador regressou finalmente a `minReplicas=2` depois da estabilização.

> Numa turma de 5 formandos, escalonar os geradores de carga para não saturar o cluster.

---

# 3. Segurança + NetworkPolicy — 15 min

## 3.1 ServiceAccount e SecurityContext

Criar **primeiro** a ServiceAccount:

```bash
kubectl -n "$NS" apply -f 04_seguranca/serviceaccount.yaml
kubectl -n "$NS" get serviceaccount symfony-demo
```

Só depois aplicar o patch:

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 04_seguranca/patch-securitycontext.yaml
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

Validar todos os Pods da revisão ativa:

```bash
kubectl -n "$NS" get pods -l app=symfony-demo \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,SA:.spec.serviceAccountName,NODE:.spec.nodeName'
```

Escolher explicitamente um Pod com `SA=symfony-demo` e confirmar:

```bash
POD=$(kubectl -n "$NS" get pod -l app=symfony-demo \
  -o jsonpath='{range .items[?(@.spec.serviceAccountName=="symfony-demo")]}{.metadata.name}{"\n"}{end}' | head -1)

kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='SA={.spec.serviceAccountName}{"\n"}Automount={.spec.automountServiceAccountToken}{"\n"}Seccomp={.spec.securityContext.seccompProfile.type}{"\n"}AllowPrivilegeEscalation={.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}'

kubectl -n "$NS" exec "$POD" -- sh -c \
  'if [ -d /var/run/secrets/kubernetes.io/serviceaccount ]; then echo "TOKEN MONTADO"; else echo "TOKEN NÃO MONTADO"; fi'
```

Esperado: SA dedicada, `Automount=false`, `RuntimeDefault`, `allowPrivilegeEscalation=false`, token não montado.

## 3.2 NetworkPolicy

Criar clientes e validar o **antes**:

```bash
kubectl -n "$NS" apply -f 05_networkpolicy/clientes.yaml
kubectl -n "$NS" wait --for=condition=Ready pod/client-allowed --timeout=60s
kubectl -n "$NS" wait --for=condition=Ready pod/client-blocked --timeout=60s
./05_networkpolicy/testar-antes.sh
```

Aplicar:

```bash
kubectl -n "$NS" apply --dry-run=server -f 05_networkpolicy/networkpolicy.yaml
kubectl -n "$NS" apply -f 05_networkpolicy/networkpolicy.yaml
./05_networkpolicy/testar-depois.sh
```

**Checkpoint:** `client-allowed` funciona; `client-blocked` falha por timeout; Symfony mantém 2/2.

---

# 4. Release defeituosa + diagnóstico + rollback — 25 min

Confirmar estado estável:

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

Dry-run e aplicação da candidata:

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml \
  --dry-run=server -o yaml >/dev/null

kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml
```

Observar sem bloquear a sessão:

```bash
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=30s || true
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get rs
kubectl -n "$NS" get pods -l app=symfony-demo -o wide
```

Identificar a candidata pela imagem:

```bash
POD_RC=$(kubectl -n "$NS" get pods -l app=symfony-demo \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
  | awk '$2 ~ /1\.2\.0-rc1/ {print $1; exit}')
```

Diagnosticar **antes** de corrigir:

```bash
kubectl -n "$NS" describe pod "$POD_RC"
kubectl -n "$NS" logs "$POD_RC" --tail=60
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -25
```

Confirmar a causa:

```bash
kubectl -n "$NS" get pod "$POD_RC" \
  -o jsonpath='Image={.spec.containers[0].image}{"\n"}Readiness={.spec.containers[0].readinessProbe.httpGet.path}{"\n"}Ready={.status.containerStatuses[0].ready}{"\n"}'
```

Esperado:

```text
Image=...:1.2.0-rc1
Readiness=/ready-errado
Ready=false
```

Enquanto a candidata falha, provar que a versão estável continua disponível:

```bash
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/health
echo
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/ready
echo
```

Rollback:

```bash
kubectl -n "$NS" rollout history deployment/symfony-demo
kubectl -n "$NS" rollout undo deployment/symfony-demo
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

> Se surgir o warning sobre `last-applied-configuration`, explicá-lo: `rollout undo` restaura o estado no cluster, mas não reescreve a configuração declarativa usada por `kubectl apply`.

---

# 5. Validação e síntese — 5 min

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get pods -l app=symfony-demo
kubectl -n "$NS" get hpa
kubectl -n "$NS" get networkpolicy
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'

kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/health
echo
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/ready
echo
```

Fecho esperado:

```text
PostgreSQL/PVC              ✅
Symfony 1.1.0               ✅
resources + probes          ✅
HPA                         ✅
ServiceAccount/Seccomp      ✅
NetworkPolicy               ✅
troubleshooting             ✅
rollback                    ✅
/health + /ready            ✅
```
