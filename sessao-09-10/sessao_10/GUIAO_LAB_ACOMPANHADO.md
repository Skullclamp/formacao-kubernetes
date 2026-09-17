# Sessão 10 — Laboratório Integrado Acompanhado

## Kubernetes para Developers — consolidação M3 + M4 + M5 + M6

**Duração:** 80 minutos  
**Modalidade:** execução guiada com checkpoints  
**Cenário:** Symfony Demo + PostgreSQL 16

Este laboratório é **acompanhado pelo formador**. O objetivo não é executar uma sequência de comandos mecanicamente. Em cada bloco o formando deve conseguir responder:

```text
O que estou a fazer?
Porque estou a fazê-lo?
Que campo devo observar?
Com o que devo comparar esse campo?
Que resultado espero?
O que concluo a partir desse resultado?
```

A estrutura usada em todos os checkpoints é:

```text
O QUE ESTAMOS A FAZER
        ↓
CONCEITOS ABORDADOS
        ↓
COMANDO
        ↓
FLAGS / CAMPOS IMPORTANTES
        ↓
ONDE OLHAR NO OUTPUT
        ↓
O QUE COMPARAR
        ↓
O QUE ESPERAR
        ↓
COMO INTERPRETAR
        ↓
CHECKPOINT
```

---

# Distribuição temporal

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

# CP0 — Namespace e baseline M3/M4 — 10 min

## O que estamos a fazer

Criar um namespace individual e recuperar a baseline saudável construída na Sessão 9.

## Porque é necessário

Todos os exercícios seguintes alteram o mesmo Deployment. Precisamos primeiro de uma referência conhecida como boa para podermos comparar **antes / alteração / resultado**.

## Conceitos abordados

- namespace e isolamento lógico;
- contexto `kubectl`;
- Deployment;
- StatefulSet;
- Service;
- PVC;
- Secret e ConfigMap;
- baseline operacional.

## 1. Criar o namespace

Cada formando/par usa um namespace próprio:

```bash
export NS=s10-dev-01
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace="$NS"
```

### Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| `export NS=...` | guarda o nome do namespace numa variável da shell |
| `--dry-run=client` | gera o objeto localmente sem o criar imediatamente |
| `-o yaml` | apresenta o objeto em YAML |
| `| kubectl apply -f -` | envia o YAML gerado para `kubectl apply` através de stdin |
| `set-context --current --namespace` | define o namespace por omissão no contexto atual |

### Onde olhar

Confirmar:

```bash
kubectl config view --minify \
  -o jsonpath='namespace={..namespace}{"\n"}'
```

Esperado:

```text
namespace=s10-dev-01
```

Se aparecer outro namespace, **não avançar**: os recursos poderiam ser criados no local errado.

## 2. Aplicar a baseline

O Secret real deve estar pré-provisionado ou criado a partir do exemplo da Sessão 9, sem expor valores em ecrã.

```bash
kubectl -n "$NS" get secret postgres-credentials

kubectl -n "$NS" apply -f ../sessao_9/baseline/01-configmap.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/03-postgresql.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/04-symfony-deployment.yaml
kubectl -n "$NS" apply -f ../sessao_9/baseline/05-symfony-service.yaml
```

## 3. Validar a baseline automaticamente

```bash
bash 00_precheck/validar-baseline.sh
```

### O que o script verifica

O script confirma:

```text
Deployment Symfony
StatefulSet PostgreSQL
Services
PVC
Secret — apenas nomes das chaves
ConfigMap
rollouts
pg_isready
imagem Symfony
/health
/ready
/info
Metrics Server
```

### Onde olhar no output

Não olhar apenas para a última linha. Confirmar estas secções:

| Secção | Campo/resultado a procurar | Esperado |
|---|---|---|
| `Objetos principais` | Deployment / StatefulSet | Symfony `2/2`, PostgreSQL `1/1` |
| `Rollouts` | mensagens de sucesso | ambos concluídos |
| `PostgreSQL` | `pg_isready` | accepting connections |
| `PVC` | `STATUS` | `Bound` |
| `Imagem Symfony` | tag da imagem | `1.1.0` |
| `Endpoints internos` | respostas HTTP | `/health`, `/ready`, `/info` respondem |
| `Metrics` | `kubectl top pods` | métricas disponíveis |
| `Resultado` | linha final | `BASELINE VALIDADO` |

### Comparação de referência

Guardar esta baseline mentalmente:

```text
PostgreSQL → 1/1
PVC        → Bound
Symfony    → 2/2
Imagem     → 1.1.0
/health    → responde
/ready     → responde
/info      → responde
Metrics    → disponíveis
```

**Checkpoint:** só avançar quando o script terminar com `BASELINE VALIDADO`.

---

# CP1 — Resources + probes — 15 min

## O que estamos a fazer

Adicionar ao Deployment Symfony pedidos/limites de recursos e probes de liveness/readiness.

## Porque é necessário

O Scheduler e o HPA dependem de informação de recursos. As probes permitem ao Kubernetes distinguir um processo em execução de uma aplicação saudável e pronta para receber tráfego.

## Conceitos abordados

- `requests`;
- `limits`;
- CPU em millicores;
- memória em MiB;
- liveness probe;
- readiness probe;
- RollingUpdate;
- `Running ≠ Ready`.

## 1. Aplicar

Antes de aplicar, pedir aos formandos que identifiquem o que **ainda não existe** no baseline Symfony.

```bash
kubectl -n "$NS" apply -f 01_resources_probes/deployment-resources-probes.yaml
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

### Flags importantes

| Flag | Significado |
|---|---|
| `-n "$NS"` | executa no namespace do formando |
| `rollout status` | acompanha a convergência do Deployment |
| `--timeout=120s` | termina a espera após 120 segundos |

## 2. Observar os Pods

```bash
kubectl -n "$NS" get pods -l app=symfony-demo
```

### Onde olhar

Comparar `READY` e `STATUS`:

```text
READY   STATUS
1/1     Running
```

Não basta ver `Running`. Um Pod pode estar `Running` mas `0/1`, logo não estar Ready.

## 3. Ler a configuração aplicada

```bash
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='requests.cpu={.spec.template.spec.containers[0].resources.requests.cpu}{" requests.memory="}{.spec.template.spec.containers[0].resources.requests.memory}{"\n"}limits.cpu={.spec.template.spec.containers[0].resources.limits.cpu}{" limits.memory="}{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}liveness={.spec.template.spec.containers[0].livenessProbe.httpGet.path}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

### Onde olhar e o que esperar

```text
requests.cpu=100m
requests.memory=128Mi
limits.cpu=500m
limits.memory=512Mi
liveness=/health
readiness=/ready
```

### O que comparar

```text
requests → capacidade usada pelo Scheduler e referência de utilização do HPA
limits   → teto de consumo configurado
liveness → /health
readiness → /ready
```

### Como interpretar

- `liveness` responde à pergunta: **o container deve continuar vivo?**
- `readiness` responde à pergunta: **o Pod pode receber tráfego?**

Mensagem-chave:

```text
Running ≠ Ready
```

**Checkpoint:** Pods `1/1 Running`, requests `100m/128Mi`, limits `500m/512Mi`, liveness `/health`, readiness `/ready`.

---

# CP2 — HPA — 10 min

## O que estamos a fazer

Criar um HorizontalPodAutoscaler baseado em CPU, gerar carga e observar o aumento do número de réplicas.

## Conceitos abordados

- Metrics Server;
- utilização de CPU;
- HPA;
- `minReplicas` e `maxReplicas`;
- target de utilização;
- scale-out e scale-in.

## 1. Confirmar métricas

```bash
kubectl -n "$NS" top pods
```

### Onde olhar

O comando deve devolver colunas semelhantes a:

```text
NAME   CPU(cores)   MEMORY(bytes)
```

Se devolver erro ou métricas indisponíveis, **não avançar para o HPA**.

## 2. Aplicar o HPA

```bash
kubectl -n "$NS" apply -f 02_hpa/hpa.yaml
kubectl -n "$NS" get hpa
```

A configuração usada é:

```text
minReplicas = 2
maxReplicas = 5
target CPU  = 50%
```

### Onde olhar no `kubectl get hpa`

As colunas importantes são:

```text
TARGETS      MINPODS   MAXPODS   REPLICAS
actual/50%   2         5         N
```

### Como ler `TARGETS`

Exemplo:

```text
82%/50%
```

significa:

```text
CPU atual média = 82%
target           = 50%
```

Como o valor atual está acima do target, o HPA tem motivo para aumentar réplicas.

## 3. Iniciar carga

```bash
./02_hpa/gerar-carga.sh
```

O script não considera a carga válida apenas porque o Pod `hpa-load` está `Running/Ready`. Antes de apresentar `Carga ativa`, confirma:

```text
HPA symfony-demo existe
        +
hpa-load fica Ready
        +
hpa-load consegue aceder a http://symfony-demo/health
        ↓
carga considerada válida
```

Esperado no output:

```text
=== HPA | Preflight HTTP a partir do Pod de carga ===
Preflight HTTP: OK
Carga ativa e conectividade ao endpoint confirmada.
```

Se o Pod estiver `Running` mas não conseguir chegar ao Service, o script termina com erro e remove o Pod de carga. Isto evita confundir **processo de carga em execução** com **pedidos efetivamente enviados à aplicação**.

Noutro terminal:

```bash
watch -n 5 "kubectl -n ${NS} get hpa; echo; kubectl -n ${NS} get pods -l app=symfony-demo"
```

### Flag importante

`watch -n 5` repete os comandos de 5 em 5 segundos.

### O que comparar ao longo do tempo

```text
ANTES DA CARGA
TARGETS abaixo/próximo de 50%
REPLICAS = 2

DURANTE A CARGA
TARGETS acima de 50%
REPLICAS aumenta
Pods novos aparecem
```

No ensaio de referência foi observado:

```text
2 → 4 → 5 réplicas
```

O percurso exato pode variar com a carga e o timing; a evidência principal é **REPLICAS aumentar em resposta a CPU acima do target**.

## 4. Parar carga

```bash
./02_hpa/parar-carga.sh
```

### O que esperar depois

A CPU deve descer. O scale-down não é imediato devido à estabilização do controlador. No ensaio real, o HPA regressou finalmente a `minReplicas=2`.

**Checkpoint principal:** explicar corretamente `current/target/min/max` e observar scale-out.

> Numa turma de 5 formandos, escalonar os geradores de carga para não saturar o cluster.

---

# CP3 — Segurança + NetworkPolicy — 15 min

# CP3A — ServiceAccount e SecurityContext

## O que estamos a fazer

Associar uma ServiceAccount dedicada ao workload e reduzir privilégios no Pod/container.

## Conceitos abordados

- ServiceAccount;
- token da ServiceAccount;
- `automountServiceAccountToken`;
- seccomp;
- `allowPrivilegeEscalation`;
- segurança por defeito mínimo.

## 1. Criar primeiro a ServiceAccount

```bash
kubectl -n "$NS" apply -f 04_seguranca/serviceaccount.yaml
kubectl -n "$NS" get serviceaccount symfony-demo
```

### Onde olhar

O objeto `symfony-demo` deve existir antes do Deployment passar a referenciá-lo.

## 2. Aplicar o SecurityContext

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 04_seguranca/patch-securitycontext.yaml

kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

### Flags importantes

| Elemento | Significado |
|---|---|
| `patch deployment` | altera campos específicos do Deployment existente |
| `--type strategic` | usa Strategic Merge Patch para recursos Kubernetes suportados |
| `--patch-file` | lê o patch a partir do ficheiro |

O patch define:

```text
serviceAccountName              = symfony-demo
automountServiceAccountToken    = false
seccompProfile.type             = RuntimeDefault
allowPrivilegeEscalation        = false
```

## 3. Confirmar a revisão ativa

```bash
kubectl -n "$NS" get pods -l app=symfony-demo \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,SA:.spec.serviceAccountName,NODE:.spec.nodeName'
```

### Onde olhar

Procurar Pods com:

```text
READY=true
SA=symfony-demo
```

Não selecionar cegamente o primeiro Pod durante um RollingUpdate, porque pode pertencer à revisão anterior.

## 4. Inspecionar um Pod da nova revisão

```bash
POD=$(kubectl -n "$NS" get pod -l app=symfony-demo \
  -o jsonpath='{range .items[?(@.spec.serviceAccountName=="symfony-demo")]}{.metadata.name}{"\n"}{end}' | head -1)

kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='SA={.spec.serviceAccountName}{"\n"}Automount={.spec.automountServiceAccountToken}{"\n"}Seccomp={.spec.securityContext.seccompProfile.type}{"\n"}AllowPrivilegeEscalation={.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}'
```

Esperado:

```text
SA=symfony-demo
Automount=false
Seccomp=RuntimeDefault
AllowPrivilegeEscalation=false
```

## 5. Confirmar ausência do token montado

```bash
kubectl -n "$NS" exec "$POD" -- sh -c \
  'if [ -d /var/run/secrets/kubernetes.io/serviceaccount ]; then echo "TOKEN MONTADO"; else echo "TOKEN NÃO MONTADO"; fi'
```

Esperado:

```text
TOKEN NÃO MONTADO
```

### O que concluir

A ServiceAccount existe e é usada pelo Pod, mas o token não é montado automaticamente.

---

# CP3B — NetworkPolicy

## O que estamos a fazer

Provar primeiro que dois clientes conseguem aceder ao Symfony e, depois, aplicar uma policy que permite apenas o cliente com a label autorizada.

## Conceitos abordados

- NetworkPolicy;
- `podSelector`;
- ingress;
- allow-list;
- teste positivo e teste negativo.

A policy seleciona Pods Symfony com:

```text
app=symfony-demo
```

E permite origem apenas de Pods com:

```text
access=symfony-demo
```

na porta TCP 80.

## 1. Criar clientes e validar o ANTES

Para tornar a experiência repetível, remover primeiro uma policy ou clientes deixados por uma execução anterior:

```bash
kubectl -n "$NS" delete networkpolicy symfony-demo-ingress --ignore-not-found
kubectl -n "$NS" delete -f 05_networkpolicy/clientes.yaml --ignore-not-found

kubectl -n "$NS" apply -f 05_networkpolicy/clientes.yaml
kubectl -n "$NS" wait --for=condition=Ready pod/client-allowed --timeout=60s
kubectl -n "$NS" wait --for=condition=Ready pod/client-blocked --timeout=60s

kubectl -n "$NS" get pods client-allowed client-blocked --show-labels
./05_networkpolicy/testar-antes.sh
```

Os clientes usam um `sleep` de 24 horas para evitar que terminem durante uma sessão longa. Mesmo assim, o script valida explicitamente que ambos estão `Running` e `Ready` antes de testar a rede.

### Onde olhar

Antes da policy, confirmar primeiro:

```text
client-allowed → Running / Ready / access=symfony-demo
client-blocked → Running / Ready / access=blocked
NetworkPolicy symfony-demo-ingress → ausente
```

Depois, o script deve mostrar que **ambos** conseguem chegar ao mesmo endpoint `/health`:

```text
client-allowed -> resposta válida
client-blocked -> resposta válida
Baseline de conectividade: OK
```

Isto é essencial: se `client-blocked` já falhar antes da policy, não podemos atribuir a falha posterior à NetworkPolicy.

## 2. Validar e aplicar a policy

```bash
kubectl -n "$NS" apply --dry-run=server -f 05_networkpolicy/networkpolicy.yaml
kubectl -n "$NS" apply -f 05_networkpolicy/networkpolicy.yaml
./05_networkpolicy/testar-depois.sh
```

### Flag importante

`--dry-run=server` envia o objeto à API para validação/admission, mas não o persiste.

### Onde olhar depois

O script confirma primeiro as precondições e a própria policy:

```text
client-allowed → Running / Ready / access=symfony-demo
client-blocked → Running / Ready / access=blocked
policy → app=symfony-demo / allowedAccess=symfony-demo / port=80
```

Depois usa **o mesmo Service, a mesma porta e o mesmo endpoint `/health`** nos dois clientes.

Esperado:

```text
client-allowed → responde
client-blocked → wget: download timed out
```

Uma falha genérica do comando não é suficiente. Se o Pod estiver terminado, o `kubectl exec` falhar, o DNS falhar ou surgir outro erro, o script **não** declara a NetworkPolicy validada.

### Comparação que prova a policy

```text
ANTES
allowed → /health funciona
blocked → /health funciona

DEPOIS
allowed → /health funciona
blocked → /health termina por timeout
```

### O que concluir

A evidência de uma NetworkPolicy não é apenas o objeto existir nem apenas existir um comando com exit code diferente de zero. Neste cenário, a conclusão é sustentada pela combinação:

```text
ambos os clientes Running/Ready
        +
labels confirmadas
        +
mesmo destino /health
        +
cliente permitido responde
        +
cliente bloqueado termina por timeout
        ↓
resultado coerente com a NetworkPolicy aplicada
```

**Checkpoint:** `client-allowed` funciona; `client-blocked` falha por timeout; Symfony continua disponível.

---

# CP4 — Release defeituosa + diagnóstico + rollback — 25 min

## O que estamos a fazer

Aplicar uma candidata `1.2.0-rc1` com uma readiness incorreta, diagnosticar o problema sem corrigir imediatamente e recuperar com `rollout undo`.

## Porque é necessário

Este é o bloco principal de troubleshooting: o objetivo é aprender a construir uma conclusão a partir de várias evidências, não adivinhar a causa.

## Conceitos abordados

- RollingUpdate;
- ReplicaSet e revisão;
- readiness;
- disponibilidade durante rollout;
- Events;
- logs;
- diagnóstico por evidência;
- rollback.

## 1. Registar o estado estável ANTES

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

Guardar a referência:

```text
Deployment → 2/2
image      → ghcr.io/skullclamp/symfony-demo:1.1.0
readiness  → /ready
```

## 2. Validar o patch sem alterar

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml \
  --dry-run=server -o yaml >/dev/null
```

### O que significa

A API valida a estrutura do patch, mas o Deployment não é alterado.

## 3. Aplicar a candidata

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml
```

O patch introduz simultaneamente:

```text
image     → ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
readiness → /ready-errado
```

## 4. Observar sem bloquear a sessão

```bash
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=30s || true
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get rs
kubectl -n "$NS" get pods -l app=symfony-demo -o wide
```

### Onde olhar

| Output | Campo | O que procurar |
|---|---|---|
| Deployment | `READY` | rollout não converge para todas as réplicas novas Ready |
| ReplicaSets | `DESIRED/CURRENT/READY` | coexistência da revisão estável e da candidata |
| Pods | `READY`, `STATUS` | Pod candidato pode estar `Running` mas `0/1` |

### Interpretação

Se a candidata está `Running` mas não `Ready`, investigar readiness antes de concluir que existe um crash.

## 5. Identificar o Pod candidato pela imagem

```bash
POD_RC=$(kubectl -n "$NS" get pods -l app=symfony-demo \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
  | awk '$2 ~ /1\.2\.0-rc1/ {print $1; exit}')

echo "$POD_RC"
```

### Porque fazemos isto

Durante um RollingUpdate coexistem revisões. Selecionar `.items[0]` poderia escolher um Pod estável antigo. Aqui selecionamos pela imagem da candidata.

## 6. Recolher evidência antes de corrigir

```bash
kubectl -n "$NS" describe pod "$POD_RC"
kubectl -n "$NS" logs "$POD_RC" --tail=60
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -25
```

### Onde olhar no `describe`

Na secção **Events**, procurar:

```text
Readiness probe failed
HTTP ... 404
```

### Onde olhar nos logs

Procurar erros da aplicação. Se a aplicação está a arrancar normalmente e o problema persistente aparece apenas na readiness, isso reduz a probabilidade de crash da aplicação.

### Onde olhar nos Events

Usar a cronologia para separar acontecimentos transitórios de falhas persistentes.

`--sort-by='.lastTimestamp'` ordena Events pelo timestamp e `tail -25` mostra os 25 mais recentes.

## 7. Confirmar a causa diretamente no Pod

```bash
kubectl -n "$NS" get pod "$POD_RC" \
  -o jsonpath='Image={.spec.containers[0].image}{"\n"}Readiness={.spec.containers[0].readinessProbe.httpGet.path}{"\n"}Ready={.status.containerStatuses[0].ready}{"\n"}'
```

Esperado:

```text
Image=ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
Readiness=/ready-errado
Ready=false
```

### Comparação que fecha o diagnóstico

```text
ANTES              CANDIDATA
image=1.1.0         image=1.2.0-rc1
readiness=/ready    readiness=/ready-errado
Ready=true          Ready=false
```

Com `Readiness probe failed` nos Events, a causa fica sustentada por evidência:

```text
Causa raiz → path de readiness inválido na release candidata
```

## 8. Provar que o Service continua disponível

Enquanto a candidata falha:

```bash
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/health
echo
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/ready
echo
```

### O que observar

Os pedidos devem continuar a responder através da réplica estável.

Isto demonstra:

```text
release candidata falhou
≠
serviço obrigatoriamente indisponível
```

## 9. Rollback

Primeiro observar o histórico:

```bash
kubectl -n "$NS" rollout history deployment/symfony-demo
```

Depois:

```bash
kubectl -n "$NS" rollout undo deployment/symfony-demo
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```

### O que esperar

O Deployment deve regressar ao estado estável.

> Se surgir o warning sobre `last-applied-configuration`, explicá-lo: `rollout undo` restaura o estado no cluster, mas não reescreve automaticamente a configuração declarativa usada anteriormente por `kubectl apply`.

## 10. Validar o rollback

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get pods -l app=symfony-demo
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

Esperado:

```text
Deployment → 2/2
image      → ghcr.io/skullclamp/symfony-demo:1.1.0
readiness  → /ready
Pods       → Ready
```

### Antes / falha / recuperação

```text
ANTES       1.1.0      /ready         Deployment 2/2
FALHA       1.2.0-rc1  /ready-errado  candidata Ready=false
RECUPERAÇÃO 1.1.0      /ready         Deployment 2/2
```

Mensagem-chave:

```text
Sem evidência não há diagnóstico.
Sem causa raiz não há troubleshooting completo.
Sem validação pós-correção não há recuperação demonstrada.
```

---

# CP5 — Validação e síntese — 5 min

## O que estamos a fazer

Confirmar que todas as alterações pretendidas permanecem ativas e que o rollback deixou a aplicação novamente saudável.

## Comandos

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

## Guia de leitura final

| Verificação | Onde olhar | Esperado |
|---|---|---|
| Symfony Deployment | `READY` | `2/2` |
| Pods Symfony | `READY/STATUS` | todos `1/1 Running` |
| imagem | `jsonpath` | `...:1.1.0` |
| readiness | `jsonpath` | `/ready` |
| HPA | `MINPODS/MAXPODS` | `2/5` |
| NetworkPolicy | objeto | `symfony-demo-ingress` presente |
| `/health` | resposta HTTP | sucesso |
| `/ready` | resposta HTTP | sucesso |

## Fecho esperado

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

## Perguntas de síntese

O formando deve conseguir explicar:

```text
Porque é que Running não significa Ready?
Que informação é usada pelo HPA?
Porque é que uma NetworkPolicy precisa de teste positivo e negativo?
Como distinguimos uma revisão estável de uma candidata durante um rollout?
Que evidência provou a causa da falha?
Que evidência provou a recuperação?
```

A sessão só fica concluída quando os resultados são **observados e interpretados**, não apenas quando os comandos terminam sem erro.
