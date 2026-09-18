# Laboratório Integrado — Sessões 9 e 10

## Kubernetes para Developers — fiabilidade, escala, ambientes, releases e troubleshooting

**Duração do percurso principal:** 120 minutos  
**Nível:** intermédio  
**Formandos:** até 5  
**Modalidade:** laboratório acompanhado pelo formador  
**Cenário:** Symfony Demo + PostgreSQL 16

---

# 1. Como utilizar este laboratório

Este é um **único laboratório acompanhado pelo formador**. Não é uma lista de comandos para executar mecanicamente.

A baseline construída anteriormente é usada como ponto de partida e, sobre a mesma aplicação, o laboratório percorre três etapas:

~~~text
CP1 — tornar o workload mais fiável e escalável
        ↓
CP2 — gerir variantes de configuração e releases
        ↓
CP3 — introduzir uma falha, diagnosticar e recuperar
~~~

Em cada etapa seguimos sempre a mesma estrutura:

~~~text
O QUE ESTAMOS A FAZER
        ↓
PORQUE É NECESSÁRIO
        ↓
CONCEITOS ABORDADOS
        ↓
ONDE EXECUTAR
        ↓
COMANDOS / MANIFESTOS
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
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
~~~

Nos incidentes, o método de troubleshooting é:

~~~text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Teste
  ↓
Causa raiz
  ↓
Correção
  ↓
Validação
~~~

> **Regra operacional:** primeiro observar; só depois alterar.

> **Regra de leitura:** não basta executar o comando. Em cada comando o formando deve conseguir responder: **que campo procuro, com o que o comparo e o que concluo?**

---

# 2. Distribuição dos 120 minutos

| Bloco | Tempo | Resultado esperado |
|---|---:|---|
| Preflight | 5 min | baseline conhecida e saudável |
| CP1 — Fiabilidade + escala | 35 min | resources/probes, hardening e scale-out por HPA |
| CP2 — Ambientes + releases | 35 min | Kustomize e Helm usados na prática |
| CP3 — Troubleshooting + rollback | 40 min | falha diagnosticada por evidência e recuperação validada |
| Síntese | 5 min | conclusões sustentadas por outputs |
| **Total** | **120 min** | |

A NetworkPolicy e o cenário isolado de readiness ficam em **optional/**. Foram mantidos porque já estão validados, mas não entram no percurso obrigatório de 120 minutos.

---

# 3. Preparação — pasta e namespace

## O que estamos a fazer

Confirmar que estamos na diretoria correta e identificar o Namespace onde o laboratório vai operar.

## Porque é necessário

Os comandos seguintes usam caminhos relativos. Se o terminal estiver noutra pasta, o ficheiro pode existir no repositório mas o comando falhar.

Além disso, todos os recursos devem ser observados e alterados no mesmo Namespace.

## Onde executar

No terminal com acesso kubectl ao cluster:

~~~bash
cd ~/formacao-kubernetes/sessao-09-10/lab-integrado

export NS="$(kubectl config view --minify   -o jsonpath='{..namespace}')"

printf 'PWD=%s\nNS=%s\n' "$PWD" "$NS"
~~~

## Explicação

| Elemento | O que faz |
|---|---|
| cd | muda para a raiz do laboratório |
| kubectl config view --minify | mostra apenas o contexto Kubernetes atualmente selecionado |
| jsonpath | extrai somente o Namespace do contexto |
| export NS=... | guarda esse Namespace numa variável da shell |
| printf | mostra explicitamente a pasta e o Namespace que serão usados |

## Onde olhar no output

Esperado:

~~~text
PWD=.../sessao-09-10/lab-integrado
NS=<namespace de trabalho>
~~~

## Como interpretar

Se PWD estiver incorreto, os caminhos relativos usados no laboratório podem falhar.

Se NS estiver vazio ou indicar outro Namespace, não avançar até corrigir o contexto.

---

# PREFLIGHT — Baseline saudável — 5 min

## O que estamos a fazer

Confirmar que a aplicação Symfony e o PostgreSQL estão num estado conhecido como saudável antes de começar a modificá-los.

## Porque é necessário

Não é possível diagnosticar corretamente uma alteração sem uma referência anterior.

A baseline funciona como termo de comparação:

~~~text
ANTES
estado conhecido como bom
        ↓
ALTERAÇÃO
        ↓
DEPOIS
novo estado observado
~~~

Sem esta referência, um valor diferente pode ser interpretado como problema mesmo que já existisse antes do exercício.

## Conceitos abordados

- baseline operacional;
- Deployment;
- StatefulSet;
- PVC;
- Service;
- readiness;
- endpoints de aplicação;
- imagem atualmente em execução.

## Onde executar

Na raiz do laboratório:

~~~bash
bash preflight/validar-baseline.sh
~~~

## O que o script está a fazer

O script não se limita a verificar se os objetos existem. Ele confirma condições concretas da baseline, incluindo:

~~~text
PostgreSQL      → StatefulSet operacional
PVC             → Bound
Symfony         → Deployment convergido
imagem          → versão estável 1.1.0
/health         → responde
/ready          → responde
ConfigMap       → presente
Secret          → presente
~~~

## Onde olhar no output

A validação deverá terminar com:

~~~text
BASELINE VALIDADO
~~~

e os estados relevantes devem corresponder a:

~~~text
PostgreSQL  → 1/1
PVC         → Bound
Symfony     → 2/2
imagem      → 1.1.0
/health     → OK
/ready      → OK
~~~

## O que comparar

Guardar esta referência:

~~~text
ANTES DO CP1
Deployment Symfony → 2/2
imagem             → 1.1.0
health             → OK
ready              → OK
PostgreSQL         → 1/1
PVC                → Bound
~~~

## Checkpoint — não avançar sem validar

Se a baseline não estiver saudável, parar aqui.

---

# CP1 — Fiabilidade + escala — 35 min

# CP1.1 — Resources e probes

## O que estamos a fazer

Substituir o Deployment inicial por uma versão que acrescenta:

~~~text
requests
limits
livenessProbe
readinessProbe
~~~

A imagem da aplicação mantém-se em 1.1.0 e continuam a existir duas réplicas.

## Porque é necessário

Um container em execução não fornece, por si só, informação suficiente para o Kubernetes decidir:

- quanta capacidade deve reservar;
- quanto CPU/memória o container pode consumir;
- se o processo continua vivo;
- se o Pod está preparado para receber tráfego.

Os resources e probes tornam essas decisões explícitas.

## Conceitos abordados

### Requests

Representam os recursos pedidos pelo container ao Scheduler.

Neste laboratório:

~~~text
CPU request    = 100m
memory request = 128Mi
~~~

### Limits

Definem o limite de consumo configurado para o container:

~~~text
CPU limit    = 500m
memory limit = 512Mi
~~~

### Liveness probe

Pergunta:

> O processo continua suficientemente saudável para permanecer em execução?

Neste laboratório:

~~~text
GET /health
~~~

### Readiness probe

Pergunta:

> Este Pod está preparado para receber tráfego através do Service?

Neste laboratório:

~~~text
GET /ready
~~~

Mensagem-chave:

~~~text
Running ≠ Ready
~~~

## Como está a ser feito no manifesto

O ficheiro:

~~~text
01_fiabilidade_escala/resources-probes/deployment-resources-probes.yaml
~~~

define:

~~~yaml
livenessProbe:
  httpGet:
    path: /health

readinessProbe:
  httpGet:
    path: /ready

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
~~~

A estratégia continua a ser RollingUpdate com:

~~~text
maxUnavailable = 0
maxSurge       = 1
~~~

Isto permite criar uma nova réplica antes de retirar uma réplica saudável.

## Aplicar

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/resources-probes/deployment-resources-probes.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

## Explicação dos comandos e flags

| Elemento | Significado |
|---|---|
| kubectl apply | envia o estado desejado do manifesto para a API |
| -n "$NS" | limita a operação ao Namespace do laboratório |
| -f | indica o ficheiro a aplicar |
| rollout status | acompanha a convergência do Deployment |
| --timeout=120s | termina a espera se o rollout não convergir em 120 segundos |

## Confirmar o estado realmente aplicado

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='requests.cpu={.spec.template.spec.containers[0].resources.requests.cpu}{" requests.memory="}{.spec.template.spec.containers[0].resources.requests.memory}{" limits.cpu="}{.spec.template.spec.containers[0].resources.limits.cpu}{" limits.memory="}{.spec.template.spec.containers[0].resources.limits.memory}{" liveness="}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
~~~

## Porque usamos jsonpath

O objetivo não é procurar manualmente seis valores dentro de um YAML grande.

O jsonpath extrai apenas os campos que queremos comparar.

## Onde olhar

Esperado:

~~~text
requests.cpu=100m
requests.memory=128Mi
limits.cpu=500m
limits.memory=512Mi
liveness=/health
readiness=/ready
~~~

## O que comparar

~~~text
MANIFESTO                       CLUSTER
100m CPU request          ↔     100m
128Mi memory request      ↔     128Mi
500m CPU limit            ↔     500m
512Mi memory limit        ↔     512Mi
/health                   ↔     /health
/ready                    ↔     /ready
~~~

## Como interpretar

Se manifesto e Deployment real coincidirem, o estado desejado convergiu para o cluster.

---

# CP1.2 — Hardening mínimo do workload

## O que estamos a fazer

Dar ao workload uma identidade própria e reduzir privilégios que não são necessários à aplicação.

## Porque é necessário

Um Pod não deve receber automaticamente mais acesso ou privilégios do que precisa para executar a sua função.

O objetivo não é transformar este bloco num laboratório completo de segurança, mas aplicar quatro decisões simples:

~~~text
ServiceAccount dedicada
token da API não montado
seccomp RuntimeDefault
privilege escalation desativada
~~~

## Conceitos abordados

- ServiceAccount;
- identidade de workload;
- automount do token Kubernetes;
- SecurityContext;
- seccomp;
- princípio de menor privilégio.

## Como está a ser feito

Primeiro é criada a ServiceAccount:

~~~yaml
kind: ServiceAccount
metadata:
  name: symfony-demo
automountServiceAccountToken: false
~~~

Depois o patch altera o Pod template do Deployment:

~~~text
serviceAccountName           → symfony-demo
automountServiceAccountToken → false
seccompProfile.type          → RuntimeDefault
allowPrivilegeEscalation     → false
~~~

A ordem é importante:

~~~text
criar ServiceAccount
        ↓
associar Deployment
~~~

Não devemos configurar primeiro uma identidade que ainda não existe.

## Aplicar

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/seguranca/serviceaccount.yaml

kubectl -n "$NS" patch deployment symfony-demo   --type strategic   --patch-file 01_fiabilidade_escala/seguranca/patch-securitycontext.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

## Explicação dos comandos

| Elemento | Significado |
|---|---|
| patch deployment | altera apenas os campos indicados em vez de substituir todo o Deployment |
| --type strategic | usa Strategic Merge Patch para combinar estruturas Kubernetes |
| --patch-file | lê o patch a partir do ficheiro indicado |
| rollout status | confirma que a nova revisão convergiu |

## Selecionar um Pod da nova configuração

~~~bash
POD="$(kubectl -n "$NS" get pods -l app=symfony-demo   -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.serviceAccountName}{"\n"}{end}'   | awk '$2=="symfony-demo"{print $1; exit}')"

echo "POD=$POD"
~~~

## Porque não usamos simplesmente items[0]

Durante um RollingUpdate podem coexistir Pods da revisão anterior e da revisão nova.

Selecionar simplesmente o primeiro elemento não prova que estamos a observar o Pod que recebeu a nova configuração.

Aqui procuramos explicitamente um Pod cuja ServiceAccount seja symfony-demo.

## Confirmar os campos

~~~bash
kubectl -n "$NS" get pod "$POD"   -o jsonpath='sa={.spec.serviceAccountName}{" automount="}{.spec.automountServiceAccountToken}{" seccomp="}{.spec.securityContext.seccompProfile.type}{" allowPrivilegeEscalation="}{.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}'
~~~

## Onde olhar

Esperado:

~~~text
sa=symfony-demo
automount=false
seccomp=RuntimeDefault
allowPrivilegeEscalation=false
~~~

## O que concluir

~~~text
ServiceAccount existe
+
Pod usa essa identidade
+
token automático desativado
+
seccomp ativo
+
privilege escalation desativada
=
hardening mínimo demonstrado
~~~

---

# CP1.3 — HPA e scale-out

## O que estamos a fazer

Criar um HorizontalPodAutoscaler que observa utilização média de CPU e pode alterar automaticamente o número de réplicas do Deployment.

## Porque é necessário

Até agora o número de réplicas era fixo.

O HPA introduz um ciclo de controlo:

~~~text
métricas de CPU
      ↓
HPA compara atual com target
      ↓
calcula número desejado de réplicas
      ↓
Deployment é escalado
      ↓
novos Pods são criados
~~~

## Como está a ser feito no manifesto

O HPA aponta para:

~~~text
Deployment/symfony-demo
~~~

e define:

~~~text
minReplicas        = 2
maxReplicas        = 5
averageUtilization = 50%
~~~

Isto significa que o HPA tenta manter a utilização média de CPU próxima do target de 50%, dentro do intervalo 2..5 réplicas.

> O target percentual depende dos CPU requests. É por isso que configurámos requests antes de trabalhar o HPA.

## 1. Confirmar que existem métricas

~~~bash
kubectl -n "$NS" top pods
~~~

## Onde olhar

Devem surgir valores de CPU e memória para os Pods.

Se não existirem métricas, não avançar para a interpretação do HPA.

## 2. Criar o HPA

~~~bash
kubectl -n "$NS" apply   -f 01_fiabilidade_escala/hpa/hpa.yaml

kubectl -n "$NS" get hpa symfony-demo
~~~

## Onde olhar

Campos principais:

| Campo | Significado |
|---|---|
| TARGETS | utilização atual comparada com o target |
| MINPODS | número mínimo de réplicas |
| MAXPODS | número máximo |
| REPLICAS | número atualmente controlado pelo HPA |

Esperado:

~~~text
target = 50%
min    = 2
max    = 5
~~~

## 3. Gerar carga

~~~bash
bash 01_fiabilidade_escala/hpa/gerar-carga.sh
~~~

## O que o script está a fazer

O script:

1. confirma que o HPA existe;
2. remove um eventual Pod de carga antigo;
3. cria o Pod hpa-load com BusyBox;
4. espera que o Pod esteja Ready;
5. testa explicitamente http://symfony-demo/health;
6. só depois inicia a interpretação da carga como válida.

O container executa várias chamadas HTTP concorrentes ao Service Symfony.

Mensagem-chave:

~~~text
Pod de carga Running
≠
carga funcional
~~~

A conectividade ao endpoint é validada antes de declarar a carga ativa.

## 4. Observar a resposta do HPA

~~~bash
for i in 1 2 3 4 5 6; do
  date '+%H:%M:%S'

  kubectl -n "$NS" get hpa symfony-demo

  kubectl -n "$NS" get deployment symfony-demo     -o jsonpath='replicas={.spec.replicas} ready={.status.readyReplicas}{"\n"}'

  echo
  sleep 10
done
~~~

## O que comparar

Não olhar apenas para o número final de Pods.

Comparar:

~~~text
TARGETS atual / 50%
        ↓
replicas antes
        ↓
replicas depois
~~~

Exemplo de interpretação:

~~~text
CPU média > 50%
+
réplicas aumentaram acima de 2
=
scale-out observado
~~~

O número exato de réplicas pode variar. O comportamento a demonstrar é a relação entre CPU acima do target e aumento de réplicas.

## O que não fazer

Não gastar o tempo principal à espera do scale-in.

O scale-down tem estabilização própria e pode ser observado mais tarde.

## 5. Parar a carga e repor o estado

~~~bash
bash 01_fiabilidade_escala/hpa/parar-carga.sh

kubectl -n "$NS" delete hpa symfony-demo --ignore-not-found

kubectl -n "$NS" scale deployment symfony-demo --replicas=2

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

## Checkpoint CP1 — não avançar sem validar

O formando deve conseguir explicar:

~~~text
requests ≠ limits

liveness ≠ readiness

Running ≠ Ready

HPA criado ≠ scale-out demonstrado

processo de carga ativo ≠ conectividade confirmada

CPU acima do target + aumento de réplicas
=
scale-out sustentado por evidência
~~~

---

# CP2 — Ambientes + releases — 35 min

# CP2.1 — Kustomize: base e overlays

## O que estamos a fazer

Usar uma única base de manifests e produzir duas variantes:

~~~text
DEV
PROD
~~~

sem copiar manualmente todos os YAML.

## Porque é necessário

Ambientes diferentes costumam partilhar a maior parte da configuração e divergir apenas em alguns valores.

Kustomize permite representar:

~~~text
BASE
  +
DIFERENÇAS DO AMBIENTE
  =
MANIFESTO RENDERIZADO
~~~

## Conceitos abordados

- base;
- overlay;
- nameSuffix;
- patches;
- configMapGenerator;
- alteração de réplicas;
- renderização;
- diferença entre metadata.name e labels.

## Como está a ser feito

O overlay DEV define:

~~~text
nameSuffix  → -dev
APP_ENV     → dev
replicas    → 1
CPU request → 50m
~~~

O overlay PROD define:

~~~text
nameSuffix  → -prod
APP_ENV     → prod
replicas    → 2
CPU request → 100m
~~~

Ambos reutilizam a mesma base.

## 1. Renderizar sem aplicar

~~~bash
kubectl kustomize   02_ambientes_releases/kustomize/overlays/dev   > /tmp/kustomize-dev.yaml

kubectl kustomize   02_ambientes_releases/kustomize/overlays/prod   > /tmp/kustomize-prod.yaml
~~~

## Explicação

kubectl kustomize apenas renderiza.

Não cria nem altera recursos no cluster.

O operador > grava o YAML gerado num ficheiro para permitir comparação.

Mensagem-chave:

~~~text
renderizar ≠ aplicar
~~~

## 2. Comparar DEV e PROD

~~~bash
diff -u   /tmp/kustomize-dev.yaml   /tmp/kustomize-prod.yaml || true
~~~

## Como ler o diff

~~~text
- linha presente na primeira versão
+ linha presente na segunda versão
~~~

## O que procurar

| Campo | DEV | PROD |
|---|---:|---:|
| APP_ENV | dev | prod |
| réplicas | 1 | 2 |
| CPU request | 50m | 100m |
| sufixo dos nomes | -dev | -prod |

## Ponto importante — nameSuffix não é label

O nome do Deployment muda:

~~~text
symfony-demo-kustomize
        ↓
symfony-demo-kustomize-dev
~~~

mas a label arbitrária da aplicação permanece:

~~~text
app=symfony-demo-kustomize
~~~

Logo:

~~~text
metadata.name → recebe -dev
label app     → mantém symfony-demo-kustomize
~~~

Mensagem-chave:

~~~text
metadata.name ≠ label
~~~

## 3. Aplicar DEV

~~~bash
kubectl -n "$NS" apply -k   02_ambientes_releases/kustomize/overlays/dev

kubectl -n "$NS" rollout status   deployment/symfony-demo-kustomize-dev   --timeout=90s
~~~

## Explicação

| Elemento | Significado |
|---|---|
| apply -k | aplica uma diretoria Kustomize |
| rollout status | acompanha a convergência do Deployment |
| --timeout=90s | limita a espera |

## 4. Comparar renderização com estado real

~~~bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev   -o jsonpath='replicas={.spec.replicas}{" ready="}{.status.readyReplicas}{" label="}{.spec.template.metadata.labels.app}{"\n"}'

kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev   -o jsonpath='APP_ENV={.data.APP_ENV}{"\n"}'
~~~

Esperado:

~~~text
replicas=1
ready=1
label=symfony-demo-kustomize
APP_ENV=dev
~~~

## 5. Provar que o Service tem backend utilizável

~~~bash
kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo-kustomize-dev   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
~~~

## Onde olhar

Esperado:

~~~text
<IP> ready=true serving=true
~~~

## Como interpretar

~~~text
overlay DEV
   ↓
Deployment 1 réplica
   ↓
Pod Ready
   ↓
Service encontra a label
   ↓
EndpointSlice ready=true
~~~

A existência do Service, por si só, não é a prova final.

## 6. Remover DEV

~~~bash
kubectl -n "$NS" delete -k   02_ambientes_releases/kustomize/overlays/dev
~~~

Confirmar a baseline principal:

~~~bash
kubectl -n "$NS" get deployment symfony-demo
~~~

Esperado:

~~~text
symfony-demo → 2/2
~~~

---

# CP2.2 — Helm: Chart, Values, Release e Revision

## O que estamos a fazer

Usar um Chart Helm para gerar e instalar uma nova instância da aplicação.

## Porque é necessário

Helm acrescenta ao processo de renderização o conceito de release.

A relação é:

~~~text
Chart + Values
      ↓
manifests renderizados
      ↓
Release instalada
      ↓
Revision no histórico
~~~

## Conceitos abordados

### Chart

Pacote com templates e valores.

### Values

Parâmetros usados pelos templates.

Neste Chart:

~~~text
replicaCount = 1
image        = 1.1.0
Service      = porta 80
CPU request  = 50m
memory       = 64Mi request / 512Mi limit
~~~

### Release

Instalação concreta do Chart num cluster e Namespace.

### Revision

Versão histórica da release gerida pelo Helm.

Mensagem-chave:

~~~text
Chart ≠ Release ≠ Revision
~~~

## Como está a ser feito no template

O nome do Deployment e do Service é derivado de Release.Name.

Com a release:

~~~text
symfony-demo-helm
~~~

os objetos renderizados recebem esse mesmo nome.

A imagem, réplicas e resources são lidos de values.yaml.

## 1. Definir o Chart

~~~bash
CHART="02_ambientes_releases/helm/symfony-demo"
~~~

## 2. Validar a estrutura do Chart

~~~bash
helm lint "$CHART"
~~~

## Onde olhar

Esperado:

~~~text
1 chart(s) linted, 0 chart(s) failed
~~~

Uma mensagem informativa sobre icon em Chart.yaml não é uma falha.

## 3. Renderizar antes de instalar

~~~bash
helm template symfony-demo-helm "$CHART"   --namespace "$NS"   > /tmp/symfony-demo-helm.yaml
~~~

## O que estamos a provar

O Chart consegue produzir manifests válidos antes de existir qualquer release.

~~~text
helm template
=
renderização
≠
instalação
~~~

## 4. Instalar a release

~~~bash
helm upgrade --install symfony-demo-helm "$CHART"   --namespace "$NS"   --set replicaCount=1   --wait   --timeout 120s
~~~

## Explicação das flags

| Elemento | Significado |
|---|---|
| upgrade --install | atualiza se existir; instala se ainda não existir |
| --namespace "$NS" | instala a release no Namespace do laboratório |
| --set replicaCount=1 | sobrepõe este valor sem editar values.yaml |
| --wait | aguarda condições de disponibilidade conhecidas pelo Helm |
| --timeout 120s | limita o tempo de espera |

## 5. Observar release e revision

~~~bash
helm status symfony-demo-helm   --namespace "$NS"

helm history symfony-demo-helm   --namespace "$NS"
~~~

## Onde olhar

No status:

~~~text
STATUS: deployed
REVISION: 1
~~~

No history, numa primeira instalação:

~~~text
REVISION  STATUS
1         deployed
~~~

## O que isto prova — e o que não prova

STATUS=deployed prova que a operação Helm terminou nesse estado.

Não prova, isoladamente, que a aplicação está funcional.

Por isso validamos também o workload.

## 6. Validar objetos e backend

~~~bash
kubectl -n "$NS" get deployment symfony-demo-helm

kubectl -n "$NS" get service symfony-demo-helm

kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo-helm   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
~~~

## O que comparar

~~~text
Helm status → deployed
Deployment  → Ready
Service     → existe
Endpoint    → ready=true / serving=true
~~~

## Conclusão

~~~text
STATUS=deployed
+
Deployment Ready
+
Service coerente
+
EndpointSlice ready=true
=
release operacional demonstrada
~~~

## 7. Remover a release

~~~bash
helm uninstall symfony-demo-helm   --namespace "$NS"
~~~

Confirmar que a baseline principal continua presente:

~~~bash
kubectl -n "$NS" get deployment symfony-demo
~~~

Esperado:

~~~text
symfony-demo → 2/2
~~~

## Checkpoint CP2 — não avançar sem validar

O formando deve conseguir explicar:

~~~text
renderizar ≠ aplicar

metadata.name ≠ label

Chart ≠ Release ≠ Revision

STATUS=deployed ≠ prova isolada de aplicação funcional
~~~

---

# CP3 — Falha + diagnóstico + recuperação — 40 min

## O que estamos a fazer

Introduzir deliberadamente uma release candidata que não consegue ficar Ready e diagnosticar a causa usando evidência do cluster.

Depois, recuperar a versão estável através de rollback e provar que o serviço voltou ao estado esperado.

## Porque é necessário

O objetivo não é decorar um comando de rollback.

O objetivo é praticar a sequência completa:

~~~text
detetar
→ observar
→ formular hipótese
→ testar
→ identificar causa raiz
→ corrigir
→ validar
~~~

## Conceitos abordados

- RollingUpdate;
- Deployment revision;
- ReplicaSet;
- Pod Running versus Ready;
- readiness probe;
- Events;
- EndpointSlice;
- rollback;
- estado declarativo versus recuperação operacional.

---

# CP3.1 — Registar a referência antes da falha

## O que estamos a fazer

Guardar os valores essenciais imediatamente antes de introduzir a candidata.

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='image={.spec.template.spec.containers[0].image}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{" replicas="}{.spec.replicas}{" ready="}{.status.readyReplicas}{"\n"}'
~~~

## Onde olhar

Esperado:

~~~text
image=...:1.1.0
readiness=/ready
replicas=2
ready=2
~~~

## Porque guardar estes valores

Depois da falha vamos comparar exatamente os mesmos campos.

---

# CP3.2 — Introduzir a release candidata

## Como está a ser feita a falha

O patch altera duas coisas na mesma revisão:

~~~text
imagem
1.1.0
   ↓
1.2.0-rc1

readiness
/ready
   ↓
/ready-errado
~~~

O caminho /ready-errado é deliberadamente inválido.

A intenção é produzir um caso determinístico em que:

~~~text
container inicia
mas
readiness falha
~~~

## Aplicar

~~~bash
kubectl -n "$NS" patch deployment symfony-demo   --type strategic   --patch-file 03_troubleshooting_rollback/patch-release-candidata.yaml

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=30s || true
~~~

## Como interpretar o timeout

O timeout não é ainda a causa raiz.

É apenas o sintoma:

~~~text
rollout não convergiu no tempo esperado
~~~

Não corrigir ainda.

---

# CP3.3 — Recolher evidência

## Passo A — Deployment, ReplicaSets e Pods

~~~bash
kubectl -n "$NS" get deployment symfony-demo

kubectl -n "$NS" get rs

kubectl -n "$NS" get pods   -l app=symfony-demo   -o wide
~~~

## Onde olhar

No Deployment:

~~~text
READY
AVAILABLE
UP-TO-DATE
~~~

Nos ReplicaSets:

~~~text
revisão antiga
revisão nova
número de réplicas
~~~

Nos Pods:

~~~text
READY
STATUS
NODE
~~~

## O que procurar

O padrão pedagógico esperado é:

~~~text
Pod candidato
STATUS  = Running
READY   = 0/1
~~~

Isto restringe a investigação:

~~~text
não parece um crash do processo
↓
investigar readiness
~~~

---

# CP3.4 — Identificar explicitamente o Pod candidato

## Porque é necessário

Durante um RollingUpdate podem coexistir Pods antigos e novos.

Não devemos assumir que o primeiro Pod devolvido pelo kubectl pertence à revisão candidata.

## Comando

~~~bash
CANDIDATE_POD="$(kubectl -n "$NS" get pods -l app=symfony-demo   -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}'   | awk '$2 ~ /1.2.0-rc1/ {print $1; exit}')"

echo "CANDIDATE_POD=$CANDIDATE_POD"
~~~

## O que estamos a fazer

Listamos:

~~~text
nome do Pod + imagem
~~~

e selecionamos o Pod cuja imagem termina em 1.2.0-rc1.

Assim, a evidência fica ligada à revisão correta.

---

# CP3.5 — Confirmar estado, imagem e readiness

~~~bash
kubectl -n "$NS" get pod "$CANDIDATE_POD"   -o jsonpath='phase={.status.phase}{" ready="}{.status.containerStatuses[0].ready}{" image="}{.spec.containers[0].image}{" readiness="}{.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
~~~

## Onde olhar

Esperado:

~~~text
phase=Running
ready=false
image=...:1.2.0-rc1
readiness=/ready-errado
~~~

## Comparação com a baseline

~~~text
BASELINE                 CANDIDATA
image 1.1.0        →     image 1.2.0-rc1
readiness /ready   →     readiness /ready-errado
Ready=true         →     Ready=false
~~~

Ainda falta provar que a probe está efetivamente a falhar.

---

# CP3.6 — Procurar a evidência nos Events

~~~bash
kubectl -n "$NS" describe pod "$CANDIDATE_POD"

kubectl -n "$NS" get events   --sort-by='.lastTimestamp'   | tail -25
~~~

## Onde olhar no describe

Ir à secção Events.

Procurar uma mensagem equivalente a:

~~~text
Readiness probe failed
HTTP 404
~~~

## O que comparar

Agora temos quatro peças de evidência:

~~~text
Pod está Running
Ready=false
readiness=/ready-errado
Event indica falha HTTP da readiness
~~~

## Causa raiz

Só agora a conclusão está sustentada:

~~~text
a release candidata não fica Ready
porque
a readiness probe aponta para um endpoint inválido
~~~

Mensagem-chave:

~~~text
sem evidência não há diagnóstico
sem causa raiz não há troubleshooting completo
~~~

---

# CP3.7 — Confirmar que a versão estável continua a servir

## O que estamos a fazer

Verificar se o Service ainda dispõe de um backend saudável enquanto a candidata não fica Ready.

~~~bash
kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo   -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{" terminating="}{.conditions.terminating}{"\n"}{end}'
~~~

## Onde olhar

Procurar pelo menos um endpoint:

~~~text
ready=true
serving=true
~~~

## Como interpretar

A estratégia do Deployment usa:

~~~text
maxUnavailable=0
maxSurge=1
~~~

Por isso o Kubernetes pode manter a réplica estável enquanto tenta introduzir a candidata.

A candidata não Ready não deve substituir prematuramente toda a capacidade saudável.

Mensagem-chave:

~~~text
release nova criada
≠
release nova apta a receber tráfego
~~~

---

# CP3.8 — Recuperar com rollback

## O que estamos a fazer

Pedir ao Deployment para recuperar uma revisão anterior e observar a convergência.

## Primeiro observar o histórico

~~~bash
kubectl -n "$NS" rollout history   deployment/symfony-demo
~~~

O histórico mostra revisões do Deployment.

## Executar rollback

~~~bash
kubectl -n "$NS" rollout undo   deployment/symfony-demo

kubectl -n "$NS" rollout status   deployment/symfony-demo   --timeout=120s
~~~

## Explicação

rollout undo não faz o número da revisão andar para trás.

A configuração anterior é recuperada através de uma nova revisão do Deployment.

## Validar o estado recuperado

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

## O que comparar

~~~text
BASELINE          INCIDENTE               RECUPERAÇÃO
1.1.0       →     1.2.0-rc1          →    1.1.0
/ready      →     /ready-errado       →    /ready
2/2 Ready   →     rollout bloqueado   →    2/2 Ready
~~~

## Nota declarativa

rollout undo recupera o estado no cluster.

Num fluxo declarativo ou GitOps, a fonte desejada deve igualmente ser corrigida ou reposta. Caso contrário, um apply ou pipeline futuro pode voltar a introduzir a configuração defeituosa.

## Checkpoint CP3 — não avançar sem validar

O formando deve conseguir reconstruir:

~~~text
SINTOMA
rollout não converge

EVIDÊNCIA
Pod Running
+
Ready=false
+
imagem 1.2.0-rc1
+
readiness /ready-errado
+
Event HTTP 404

CAUSA RAIZ
readiness inválida na candidata

CORREÇÃO
rollback

VALIDAÇÃO
imagem 1.1.0
+
readiness /ready
+
Deployment 2/2
~~~

---

# 4. Síntese final — 5 min

Cada formando deve conseguir explicar estas relações usando outputs observados no laboratório:

~~~text
Running ≠ Ready

Service existente ≠ Service com backend utilizável

desired state ≠ convergência imediata

requests são necessários para interpretar utilização percentual de CPU no HPA

HPA existente ≠ scale-out demonstrado

renderizar ≠ aplicar

metadata.name ≠ label

Chart ≠ Release ≠ Revision

STATUS=deployed ≠ aplicação funcional

falha observada ≠ causa raiz

correção aplicada ≠ recuperação validada
~~~

Regra final:

~~~text
sem evidência não há diagnóstico
sem causa raiz não há troubleshooting completo
sem validação pós-correção não há recuperação demonstrada
~~~

---

# 5. Recursos opcionais

Estes recursos permanecem no repositório porque já foram validados, mas não fazem parte dos 120 minutos.

## NetworkPolicy

Diretoria:

~~~text
optional/networkpolicy/
~~~

Permite demonstrar:

~~~text
antes da policy
cliente autorizado → responde
cliente bloqueado   → responde

depois da policy
cliente autorizado → responde
cliente bloqueado   → timeout
~~~

A existência da NetworkPolicy não é, isoladamente, prova de enforcement.

## Readiness isolada

Diretoria:

~~~text
optional/observabilidade/
~~~

Permite demonstrar isoladamente:

~~~text
Running ≠ Ready
~~~

sem depender do cenário de release candidata.

---

# 6. Cleanup final

## O que estamos a fazer

Remover recursos auxiliares conhecidos e repor o Symfony com duas réplicas.

~~~bash
bash cleanup/cleanup.sh
~~~

## O que o script preserva

~~~text
PostgreSQL
Deployment principal symfony-demo
Service principal symfony-demo
~~~

## O que remove ou repõe

~~~text
HPA temporário
NetworkPolicy opcional
Pods auxiliares
workload de observabilidade opcional
Symfony → 2 réplicas
~~~

## Regra de fecho

Não terminar com:

~~~text
parece estar tudo bem
~~~

Terminar com evidência:

~~~text
Deployment symfony-demo → 2/2
StatefulSet postgres     → 1/1
HPA temporário           → removido
Pods auxiliares          → removidos
=
cleanup validado
~~~
