# Laboratório Integrado — Sessões 9 e 10

## Kubernetes para Developers — fiabilidade, escala, ambientes, releases e troubleshooting

**Duração do percurso principal:** 120 minutos  
**Nível:** intermédio  
**Formandos:** até 5  
**Modalidade:** laboratório acompanhado pelo formador  
**Cenário:** Symfony Demo + PostgreSQL 16

Este é **um único laboratório**. A baseline construída na Sessão 9 é o ponto de partida; a Sessão 10 evolui essa mesma aplicação até escala, hardening, gestão de ambientes/releases e troubleshooting.

A regra de trabalho é sempre:

~~~text
COMANDO
  ↓
ONDE OLHAR
  ↓
O QUE COMPARAR
  ↓
O QUE ESPERAR
  ↓
O QUE SIGNIFICA
  ↓
CONCLUSÃO
~~~

Nos incidentes:

~~~text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
~~~

---

## Distribuição dos 120 minutos

| Bloco | Tempo | Resultado esperado |
|---|---:|---|
| Preflight | 5 min | baseline conhecida e saudável |
| CP1 — Fiabilidade + escala | 35 min | resources/probes, hardening e scale-out por HPA |
| CP2 — Ambientes + releases | 35 min | Kustomize e Helm usados na prática |
| CP3 — Troubleshooting + rollback | 40 min | falha diagnosticada por evidência e recuperação validada |
| Síntese | 5 min | conclusões técnicas sustentadas por outputs |
| **Total** | **120 min** | |

A NetworkPolicy e o cenário isolado de readiness ficam em **optional/**. São recursos validados, mas não entram no percurso obrigatório.

---

# Preparação — pasta e namespace

Executar a partir da raiz deste laboratório:

~~~bash
cd ~/formacao-kubernetes/sessao-09-10/lab-integrado

export NS="$(kubectl config view --minify -o jsonpath='{..namespace}')"

printf 'PWD=%s\nNS=%s\n' "$PWD" "$NS"
~~~

## Onde olhar

Esperado:

~~~text
PWD=.../sessao-09-10/lab-integrado
NS=<namespace de trabalho>
~~~

Se NS estiver vazio ou apontar para outro namespace, não avançar.

---

# Preflight — 5 min

O precheck completo é responsabilidade do formador antes da aula. Durante o percurso cronometrado, o formando confirma apenas a baseline:

~~~bash
bash preflight/validar-baseline.sh
~~~

## Onde olhar

A validação deve confirmar, entre outros pontos:

~~~text
PostgreSQL  → 1/1
PVC         → Bound
Symfony     → 2/2
imagem      → 1.1.0
/health     → OK
/ready      → OK
~~~

## Conclusão

~~~text
baseline saudável
=
referência para todas as comparações seguintes
~~~

Se a baseline não estiver validada, não iniciar o CP1.

---

# CP1 — Fiabilidade + escala — 35 min

## Objetivo

Evoluir o Deployment estável para um workload com recursos, probes, identidade dedicada, hardening básico e autoscaling.

## 1. Resources e probes

Aplicar a versão já preparada:

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/resources-probes/deployment-resources-probes.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

Confirmar os campos essenciais:

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='requests.cpu={.spec.template.spec.containers[0].resources.requests.cpu}{" requests.memory="}{.spec.template.spec.containers[0].resources.requests.memory}{" limits.cpu="}{.spec.template.spec.containers[0].resources.limits.cpu}{" limits.memory="}{.spec.template.spec.containers[0].resources.limits.memory}{" liveness="}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
~~~

### Onde olhar / comparar

Esperado:

~~~text
requests.cpu=100m
requests.memory=128Mi
limits.cpu=500m
limits.memory=512Mi
liveness=/health
readiness=/ready
~~~

Conclusão:

~~~text
resources declarados
+
probes corretas
=
base necessária para operar e escalar o workload com evidência
~~~

## 2. Hardening mínimo

Criar a ServiceAccount e aplicar o patch de segurança:

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/seguranca/serviceaccount.yaml

kubectl -n "$NS" patch deployment symfony-demo   --type strategic   --patch-file 01_fiabilidade_escala/seguranca/patch-securitycontext.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

Selecionar um Pod da revisão convergida e observar:

~~~bash
POD="$(kubectl -n "$NS" get pods -l app=symfony-demo   -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.serviceAccountName}{"\n"}{end}'   | awk '$2=="symfony-demo"{print $1; exit}')"

kubectl -n "$NS" get pod "$POD"   -o jsonpath='sa={.spec.serviceAccountName}{" automount="}{.spec.automountServiceAccountToken}{" seccomp="}{.spec.securityContext.seccompProfile.type}{" allowPrivilegeEscalation="}{.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}'
~~~

Esperado:

~~~text
sa=symfony-demo
automount=false
seccomp=RuntimeDefault
allowPrivilegeEscalation=false
~~~

## 3. HPA — observar apenas scale-out

Confirmar primeiro que existem métricas:

~~~bash
kubectl -n "$NS" top pods
~~~

Aplicar o HPA e iniciar carga:

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/hpa/hpa.yaml

bash 01_fiabilidade_escala/hpa/gerar-carga.sh
~~~

Recolher seis amostras, de 10 em 10 segundos:

~~~bash
for i in 1 2 3 4 5 6; do
  date '+%H:%M:%S'
  kubectl -n "$NS" get hpa symfony-demo
  kubectl -n "$NS" get deployment symfony-demo     -o jsonpath='replicas={.spec.replicas} ready={.status.readyReplicas}{"\n"}'
  echo
  sleep 10
done
~~~

### Onde olhar

No HPA:

~~~text
TARGETS    → atual / 50%
MINPODS    → 2
MAXPODS    → 5
REPLICAS   → número atual
~~~

### O que comparar

~~~text
CPU abaixo/acima de 50%
        ↓
réplicas antes/depois
~~~

O objetivo é observar **scale-out**. Não gastar tempo do percurso principal à espera do scale-in.

Parar a carga e repor o estado:

~~~bash
bash 01_fiabilidade_escala/hpa/parar-carga.sh

kubectl -n "$NS" delete hpa symfony-demo --ignore-not-found
kubectl -n "$NS" scale deployment symfony-demo --replicas=2
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
~~~

## Checkpoint CP1

O formando deve conseguir explicar:

~~~text
requests ≠ limits
liveness ≠ readiness
processo de carga ativo ≠ endpoint acessível
HPA criado ≠ scale-out demonstrado
Running ≠ Ready
~~~

---

# CP2 — Ambientes + releases — 35 min

O objetivo é contactar **Kustomize e Helm no mesmo laboratório**, sem transformar este bloco numa exploração exaustiva das duas ferramentas.

## 1. Kustomize — base e overlays

Renderizar DEV e PROD sem alterar o cluster:

~~~bash
kubectl kustomize   02_ambientes_releases/kustomize/overlays/dev   > /tmp/kustomize-dev.yaml

kubectl kustomize   02_ambientes_releases/kustomize/overlays/prod   > /tmp/kustomize-prod.yaml

diff -u /tmp/kustomize-dev.yaml /tmp/kustomize-prod.yaml || true
~~~

### O que procurar

~~~text
DEV                 PROD
APP_ENV=dev         APP_ENV=prod
replicas=1          replicas=2
CPU=50m             CPU=100m
nome ...-dev        nome ...-prod
~~~

Mensagem-chave:

~~~text
nameSuffix altera nomes de recursos
≠
altera automaticamente a label app
~~~

Aplicar DEV:

~~~bash
kubectl -n "$NS" apply -k   02_ambientes_releases/kustomize/overlays/dev

kubectl -n "$NS" rollout status   deployment/symfony-demo-kustomize-dev   --timeout=90s
~~~

Confirmar o essencial:

~~~bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev   -o jsonpath='replicas={.spec.replicas}{" ready="}{.status.readyReplicas}{" label="}{.spec.template.metadata.labels.app}{"\n"}'

kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev   -o jsonpath='APP_ENV={.data.APP_ENV}{"\n"}'

kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo-kustomize-dev   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{"\n"}{end}'
~~~

Esperado:

~~~text
replicas=1
ready=1
APP_ENV=dev
label=app=symfony-demo-kustomize
Endpoint ready=true
~~~

Remover DEV:

~~~bash
kubectl -n "$NS" delete -k   02_ambientes_releases/kustomize/overlays/dev
~~~

## 2. Helm — Chart, renderização e release

Definir o Chart:

~~~bash
CHART="02_ambientes_releases/helm/symfony-demo"
~~~

Validar e renderizar:

~~~bash
helm lint "$CHART"

helm template symfony-demo-helm "$CHART"   --namespace "$NS"   > /tmp/symfony-demo-helm.yaml
~~~

### Onde olhar

No lint:

~~~text
1 chart(s) linted, 0 chart(s) failed
~~~

O aviso sobre icon em Chart.yaml é informativo.

Instalar a release:

~~~bash
helm upgrade --install symfony-demo-helm "$CHART"   --namespace "$NS"   --set replicaCount=1   --wait   --timeout 120s
~~~

Observar release e workload:

~~~bash
helm status symfony-demo-helm --namespace "$NS"
helm history symfony-demo-helm --namespace "$NS"

kubectl -n "$NS" get deployment symfony-demo-helm
kubectl -n "$NS" get service symfony-demo-helm

kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo-helm   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
~~~

### Conclusão

~~~text
STATUS=deployed
≠
prova isolada de aplicação funcional

release deployed
+
Deployment Ready
+
Service coerente
+
Endpoint ready=true
=
evidência operacional
~~~

Remover a release:

~~~bash
helm uninstall symfony-demo-helm --namespace "$NS"
~~~

Confirmar que a baseline principal continua operacional:

~~~bash
kubectl -n "$NS" get deployment symfony-demo
~~~

Esperado:

~~~text
symfony-demo → 2/2
~~~

## Checkpoint CP2

O formando deve conseguir explicar:

~~~text
renderizar ≠ aplicar
metadata.name ≠ label
Chart ≠ Release ≠ Revision
deployed ≠ aplicação funcional
~~~

---

# CP3 — Falha + diagnóstico + recuperação — 40 min

Este é o checkpoint central de troubleshooting. Não revelar a causa antes de recolher evidência.

## 1. Registar a baseline imediata

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{" replicas="}{.spec.replicas}{" ready="}{.status.readyReplicas}{"\n"}'
~~~

Esperado:

~~~text
image=...:1.1.0
readiness=/ready
replicas=2
ready=2
~~~

## 2. Introduzir a release candidata

~~~bash
kubectl -n "$NS" patch deployment symfony-demo   --type strategic   --patch-file 03_troubleshooting_rollback/patch-release-candidata.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=30s || true
~~~

O timeout é um **sintoma**, não a causa raiz.

## 3. Recolher evidência

~~~bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get rs
kubectl -n "$NS" get pods -l app=symfony-demo -o wide
~~~

Identificar o Pod candidato pela imagem, não pela posição na lista:

~~~bash
CANDIDATE_POD="$(kubectl -n "$NS" get pods -l app=symfony-demo   -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}'   | awk '$2 ~ /1.2.0-rc1/ {print $1; exit}')"

echo "CANDIDATE_POD=$CANDIDATE_POD"
~~~

Ler os campos determinantes:

~~~bash
kubectl -n "$NS" get pod "$CANDIDATE_POD"   -o jsonpath='phase={.status.phase}{" ready="}{.status.containerStatuses[0].ready}{" image="}{.spec.containers[0].image}{" readiness="}{.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'

kubectl -n "$NS" describe pod "$CANDIDATE_POD"

kubectl -n "$NS" get events   --sort-by='.lastTimestamp' | tail -25
~~~

### Onde olhar

Procurar a convergência destas evidências:

~~~text
container/Pod phase → Running
Ready               → false
image               → 1.2.0-rc1
readiness path      → /ready-errado
Events              → Readiness probe failed / HTTP 404
~~~

Conclusão:

~~~text
Running ≠ Ready
~~~

A causa raiz só deve ser aceite quando imagem, readiness e Events apontam para o mesmo problema.

## 4. Confirmar que o Service ainda tem backend estável

~~~bash
kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
~~~

O esperado é existir pelo menos um backend da versão estável com:

~~~text
ready=true
serving=true
~~~

Isto permite discutir por que razão um RollingUpdate com maxUnavailable=0 pode preservar serviço estável enquanto a candidata não fica Ready.

## 5. Recuperar

~~~bash
kubectl -n "$NS" rollout history deployment/symfony-demo

kubectl -n "$NS" rollout undo deployment/symfony-demo

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

Validar a recuperação:

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{" replicas="}{.spec.replicas}{" ready="}{.status.readyReplicas}{"\n"}'
~~~

Esperado:

~~~text
image=...:1.1.0
readiness=/ready
replicas=2
ready=2
~~~

Nota: rollout undo recupera o estado do cluster, mas num fluxo declarativo/GitOps é também necessário repor a fonte declarativa.

## Checkpoint CP3

O formando deve conseguir reconstruir:

~~~text
Sintoma
  ↓
rollout não converge

Evidência
  ↓
Running + Ready=false + 404 + /ready-errado

Causa raiz
  ↓
readiness inválida na release candidata

Correção
  ↓
rollback

Validação
  ↓
1.1.0 + /ready + 2/2
~~~

---

# Síntese — 5 min

Cada formando deve conseguir explicar, usando evidência recolhida no laboratório:

~~~text
Running ≠ Ready
Service criado ≠ Service com backend utilizável
desired state ≠ convergência imediata
renderizar ≠ aplicar
Chart ≠ Release ≠ Revision
deployed ≠ aplicação funcional
falha observada ≠ causa raiz
correção aplicada ≠ recuperação validada
~~~

---

# Recursos opcionais

Não fazem parte dos 120 minutos.

## NetworkPolicy

~~~text
optional/networkpolicy/
~~~

Mantém o exercício validado com cliente autorizado e cliente bloqueado. Deve ser usado para aprofundamento ou quando este conteúdo não tenha sido trabalhado anteriormente.

## Readiness isolada

~~~text
optional/observabilidade/
~~~

Mantém o cenário determinístico Running mas NotReady para demonstração adicional.

---

# Cleanup final

Se for necessário repor o namespace após exercícios adicionais:

~~~bash
bash cleanup/cleanup.sh
~~~

O script preserva PostgreSQL e o Deployment/Service principal do Symfony, remove recursos auxiliares conhecidos e repõe o Symfony em 2 réplicas.
