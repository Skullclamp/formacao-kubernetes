# Sessão 10 — Micropráticas M6

## Cloud-native, Kustomize e Helm

**Duração total:** 50 minutos  
**Posição:** bloco anterior ao laboratório integrado final.

**Distribuição recomendada:** Cloud-native / 12-factor — 10 min; Kustomize — 20 min; Helm — 20 min.

Estas micropráticas são **acompanhadas pelo formador**. Em cada comando, o formando deve saber **onde olhar, o que comparar e o que concluir**.

```text
COMANDO
   ↓
CAMPO / OUTPUT A OBSERVAR
   ↓
COMPARAÇÃO
   ↓
CONCLUSÃO
```

---

# Preparação comum

## O que estamos a fazer

Garantir que os comandos são executados a partir da pasta correta e que a variável `NS` contém o namespace atual.

Os caminhos `m6_kustomize/...` e `m6_helm/...` são **caminhos relativos**. Se o terminal estiver noutra pasta, os comandos podem falhar mesmo que os ficheiros existam no repositório.

## Onde executar

Entrar primeiro na pasta da Sessão 10. Ajustar o caminho do clone se necessário:

```bash
cd ~/formacao-kubernetes/sessao-09-10/sessao_10

export NS="$(kubectl config view --minify \
  -o jsonpath='{..namespace}')"

printf 'PWD=%s\nNS=%s\n' "$PWD" "$NS"
```

### O que observar

O output deve mostrar:

```text
PWD=.../formacao-kubernetes/sessao-09-10/sessao_10
NS=<namespace de trabalho>
```

### Verificar os recursos das micropráticas

```bash
test -f m6_helm/symfony-demo/Chart.yaml \
  && echo "Chart encontrado" \
  || echo "ERRO: Chart não encontrado"

test -f m6_kustomize/overlays/dev/kustomization.yaml \
  && echo "Overlay DEV encontrado" \
  || echo "ERRO: Overlay DEV não encontrado"
```

Mensagem-chave:

```text
namespace atual do kubectl ≠ variável $NS
caminho existente no repositório ≠ caminho válido a partir de qualquer diretório
```

---

# 1. Cloud-native / 12-factor — 10 min

## O que estamos a fazer

Reconhecer, no cenário Symfony + PostgreSQL, decisões já alinhadas com práticas cloud-native.

## O que procurar no cenário

| Princípio | Evidência no laboratório | O que significa |
|---|---|---|
| configuração externalizada | ConfigMap + Secret | configuração separada da imagem |
| backing service | PostgreSQL | dependência externa tratada como serviço |
| processo Web replicável | Pods Symfony | aplicação pode ter várias réplicas |
| logs | stdout/stderr via `kubectl logs` | logs não dependem de ficheiro local persistente |
| build/release/run | imagem + configuração + Deployment | artefacto e configuração são conceitos separados |
| exposição | Service / Ingress | workload e ponto de acesso são objetos distintos |

## Comparação orientadora

Perguntar aos formandos:

```text
Se mudar APP_ENV, é necessário reconstruir a imagem?
Se um Pod Symfony morrer, os dados PostgreSQL desaparecem com ele?
O Service é o mesmo objeto que o Deployment?
```

O objetivo não é memorizar uma lista, mas relacionar cada princípio com um objeto real do laboratório.

---

# 2. Kustomize — 20 min

## O que estamos a fazer

Renderizar duas variantes da mesma base, identificar o que muda entre DEV e PROD, aplicar DEV e provar que o estado real corresponde ao YAML renderizado.

## Conceitos abordados

- base;
- overlay;
- `nameSuffix`;
- alteração de réplicas;
- `configMapGenerator`;
- patch;
- renderização sem aplicar;
- labels e selectors;
- Service e EndpointSlice.

## Estrutura

```text
m6_kustomize/
├── base/
└── overlays/
    ├── dev/
    └── prod/
```

## 2.1 Renderizar sem alterar o cluster

```bash
kubectl kustomize m6_kustomize/overlays/dev \
  > /tmp/kustomize-dev.yaml

kubectl kustomize m6_kustomize/overlays/prod \
  > /tmp/kustomize-prod.yaml
```

### Explicação

`kubectl kustomize` apenas **renderiza** os manifests resultantes. Não cria nem altera recursos no cluster.

O operador `>` grava o output num ficheiro para permitir comparação posterior.

## 2.2 Comparar DEV e PROD

```bash
diff -u /tmp/kustomize-dev.yaml /tmp/kustomize-prod.yaml || true
```

### Como ler `diff -u`

```text
- linha existente na primeira versão
+ linha existente na segunda versão
```

### O que procurar

A comparação deve permitir identificar estas diferenças declaradas pelos overlays:

| Elemento | DEV | PROD |
|---|---:|---:|
| `APP_ENV` | `dev` | `prod` |
| réplicas | `1` | `2` |
| CPU request | `50m` | `100m` |
| sufixo dos nomes | `-dev` | `-prod` |

Para confirmar os `resources` diretamente:

```bash
echo "=== DEV — resources ==="
grep -A8 -B2 'resources:' /tmp/kustomize-dev.yaml

echo
echo "=== PROD — resources ==="
grep -A8 -B2 'resources:' /tmp/kustomize-prod.yaml
```

### O que permanece igual

Neste cenário, por exemplo:

```text
CPU limit       → 250m nos dois ambientes
Memory request  → 64Mi nos dois ambientes
Memory limit    → 512Mi nos dois ambientes
```

Isto mostra que o overlay altera apenas os campos declarados e reutiliza o restante da base.

## 2.3 Compreender `nameSuffix` antes de aplicar

O `nameSuffix` altera os nomes dos recursos:

```text
symfony-demo-kustomize
        ↓
symfony-demo-kustomize-dev
```

No entanto, neste laboratório a label arbitrária:

```text
app=symfony-demo-kustomize
```

**não recebe automaticamente** o sufixo `-dev`.

O Deployment e o Service continuam a relacionar-se através de:

```text
Pod label            app=symfony-demo-kustomize
Deployment selector  app=symfony-demo-kustomize
Service selector     app=symfony-demo-kustomize
```

Mensagem-chave:

```text
nameSuffix altera nomes de recursos
≠
altera automaticamente todas as labels arbitrárias
```

## 2.4 Aplicar DEV

```bash
kubectl -n "$NS" apply -k m6_kustomize/overlays/dev

kubectl -n "$NS" rollout status \
  deployment/symfony-demo-kustomize-dev \
  --timeout=90s
```

### Flags importantes

| Elemento | Significado |
|---|---|
| `apply -k` | aplica uma `kustomization` em vez de um único ficheiro YAML |
| `rollout status` | acompanha a convergência do Deployment |
| `--timeout=90s` | limita a espera a 90 segundos |

## 2.5 Confirmar os valores aplicados

```bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev \
  -o jsonpath='replicas={.spec.replicas}{" readyReplicas="}{.status.readyReplicas}{" cpuRequest="}{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'

kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev \
  -o jsonpath='APP_ENV={.data.APP_ENV}{"\n"}'
```

### Esperado

```text
replicas=1 readyReplicas=1 cpuRequest=50m
APP_ENV=dev
```

### O que comparar

```text
render DEV → replicas=1, APP_ENV=dev, CPU=50m
cluster    → mesmos valores
```

A correspondência prova que o estado aplicado é coerente com o YAML que foi renderizado anteriormente.

## 2.6 Confirmar labels, selectors e backend

Primeiro observar o Pod usando a **label real**:

```bash
kubectl -n "$NS" get pods \
  -l app=symfony-demo-kustomize \
  --show-labels
```

> Não usar `-l app=symfony-demo-kustomize-dev`: o `-dev` pertence ao nome do recurso, não à label `app` deste cenário.

Confirmar depois os três valores que têm de coincidir:

```bash
echo "=== DEPLOYMENT ==="
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev \
  -o jsonpath='pod-label={.spec.template.metadata.labels.app}{"\n"}deployment-selector={.spec.selector.matchLabels.app}{"\n"}'

echo
echo "=== SERVICE ==="
kubectl -n "$NS" get service symfony-demo-kustomize-dev \
  -o jsonpath='service-selector={.spec.selector.app}{" port="}{.spec.ports[0].port}{" targetPort="}{.spec.ports[0].targetPort}{"\n"}'
```

Esperado:

```text
pod-label=symfony-demo-kustomize
deployment-selector=symfony-demo-kustomize
service-selector=symfony-demo-kustomize port=80 targetPort=http
```

Finalmente confirmar o backend derivado dessa relação:

```bash
kubectl -n "$NS" get endpointslices \
  -l kubernetes.io/service-name=symfony-demo-kustomize-dev \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
```

### O que procurar

```text
<IP-do-Pod> ready=true serving=true
```

### Como interpretar

```text
Pod label
app=symfony-demo-kustomize
        ↓ coincide
Service selector
app=symfony-demo-kustomize
        ↓
EndpointSlice contém o Pod
        ↓
ready=true / serving=true
```

O nome do Service termina em `-dev`, mas a seleção do backend continua a ser feita pelas labels.

## 2.7 Remover e confirmar isolamento da baseline

```bash
kubectl -n "$NS" delete -k m6_kustomize/overlays/dev
```

Confirmar a remoção:

```bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev 2>&1 || true
kubectl -n "$NS" get service symfony-demo-kustomize-dev 2>&1 || true
kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev 2>&1 || true
```

É esperado obter `NotFound` para os três objetos.

Confirmar que a baseline original não foi removida:

```bash
kubectl -n "$NS" get deployment symfony-demo
```

Esperado:

```text
symfony-demo → 2/2
```

Mensagem-chave:

```text
Kustomize = base + diferenças declarativas
Renderizar ≠ aplicar
metadata.name ≠ label
```

---

# 3. Helm — 20 min

## O que estamos a fazer

Validar um Chart, renderizá-lo, criar uma release, consultar estado e histórico, provar os objetos e backends criados e remover a release sem afetar a baseline original.

## Conceitos abordados

```text
Chart + Values
      ↓
Release
      ↓
Revision
```

- **Chart**: pacote de templates;
- **Values**: parâmetros usados para renderizar os templates;
- **Release**: instalação concreta do Chart;
- **Revision**: versão histórica da release criada por operações Helm.

## 3.1 Validar o Chart

```bash
helm lint m6_helm/symfony-demo
```

### Onde olhar

Esperado:

```text
1 chart(s) linted, 0 chart(s) failed
```

Uma mensagem informativa como `Chart.yaml: icon is recommended` não corresponde a uma falha do Chart.

## 3.2 Renderizar primeiro

```bash
helm template symfony-demo-helm \
  m6_helm/symfony-demo \
  --namespace "$NS" \
  > /tmp/symfony-demo-helm.yaml
```

### Onde olhar

No YAML renderizado, procurar:

```text
kind: Deployment
kind: Service
name: symfony-demo-helm
image: ghcr.io/skullclamp/symfony-demo:1.1.0
replicas: 1
```

Os valores por omissão do Chart incluem:

```text
replicaCount = 1
CPU request  = 50m
memory       = 64Mi request / 512Mi limit
Service port = 80
```

### O que concluir

`helm template` gera manifests, mas ainda **não existe uma release no cluster**.

```text
renderização correta
≠
workload já instalado
```

## 3.3 Confirmar dependências reutilizadas

Este Chart reutiliza objetos da baseline:

```bash
kubectl -n "$NS" get configmap symfony-demo-config
kubectl -n "$NS" get secret postgres-credentials
kubectl -n "$NS" get deployment symfony-demo
```

### O que procurar

```text
ConfigMap symfony-demo-config   → existe
Secret postgres-credentials     → existe
Deployment symfony-demo         → 2/2
```

Se alguma dependência estiver em falta, não avançar para a instalação da release.

## 3.4 Instalar ou atualizar a release

```bash
helm upgrade --install symfony-demo-helm \
  m6_helm/symfony-demo \
  --namespace "$NS" \
  --set replicaCount=1 \
  --wait \
  --timeout 120s
```

### Flags importantes

| Flag | Significado |
|---|---|
| `upgrade --install` | atualiza a release se existir; instala se ainda não existir |
| `--namespace "$NS"` | define o namespace da release |
| `--set replicaCount=1` | sobrepõe este valor sem editar `values.yaml` |
| `--wait` | espera que os recursos principais fiquem prontos antes de terminar |
| `--timeout 120s` | limita essa espera a 120 segundos |

Se a release ainda não existir, é normal aparecer:

```text
Release "symfony-demo-helm" does not exist. Installing it now.
```

## 3.5 Observar a release

```bash
helm status symfony-demo-helm --namespace "$NS"
helm history symfony-demo-helm --namespace "$NS"
```

### Onde olhar no `helm status`

Procurar:

```text
STATUS: deployed
REVISION: 1
```

### Onde olhar no `helm history`

Numa primeira instalação é esperado:

```text
REVISION   STATUS
1          deployed
```

Operações futuras de upgrade criariam novas revisões.

## 3.6 Confirmar os objetos no cluster

Neste Chart, o nome do Deployment e do Service é o próprio nome da release.

```bash
kubectl -n "$NS" get deployment symfony-demo-helm
kubectl -n "$NS" get service symfony-demo-helm
```

### Onde olhar

No Deployment:

```text
READY → 1/1
AVAILABLE → 1
```

No Service:

```text
TYPE    → ClusterIP
PORT(S) → 80/TCP
```

Confirmar a imagem e o número de réplicas:

```bash
kubectl -n "$NS" get deployment symfony-demo-helm \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{" replicas="}{.spec.replicas}{" readyReplicas="}{.status.readyReplicas}{"\n"}'
```

Esperado:

```text
image=ghcr.io/skullclamp/symfony-demo:1.1.0 replicas=1 readyReplicas=1
```

## 3.7 Relacionar Service, Pod e EndpointSlice

```bash
kubectl -n "$NS" get service symfony-demo-helm \
  -o jsonpath='selector.app={.spec.selector.app}{" port="}{.spec.ports[0].port}{" targetPort="}{.spec.ports[0].targetPort}{"\n"}'

kubectl -n "$NS" get pods \
  -l app=symfony-demo-helm \
  -o wide

kubectl -n "$NS" get endpointslices \
  -l kubernetes.io/service-name=symfony-demo-helm \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{" serving="}{.conditions.serving}{"\n"}{end}'
```

### Esperado

```text
selector.app=symfony-demo-helm port=80 targetPort=http
Pod → 1/1 Running
Endpoint → ready=true serving=true
```

### O que concluir

```text
Helm STATUS=deployed
        ↓ não é a única prova
Deployment Ready
        +
Pod Running/Ready
        +
Service selector coerente
        +
EndpointSlice ready=true
        ↓
workload da release operacional
```

## 3.8 Comparar renderização com estado real

```text
helm template                     cluster real

imagem 1.1.0                →     imagem 1.1.0
replicas 1                  →     replicas 1
Deployment symfony-demo-helm →    Deployment 1/1
Service symfony-demo-helm   →     Service porta 80
selector                    →     encontra o Pod
Endpoint                    →     ready=true / serving=true
```

Esta comparação é a evidência de que o estado real corresponde ao que foi renderizado.

## 3.9 Remover a release

```bash
helm uninstall symfony-demo-helm \
  --namespace "$NS"
```

Confirmar:

```bash
helm list -n "$NS" | grep -E 'NAME|symfony-demo-helm' || true

kubectl -n "$NS" get deployment symfony-demo-helm 2>&1 || true
kubectl -n "$NS" get service symfony-demo-helm 2>&1 || true
```

É esperado que a release deixe de aparecer e que os objetos devolvam `NotFound`.

Confirmar finalmente que a baseline original permanece operacional:

```bash
kubectl -n "$NS" get deployment symfony-demo
```

Esperado:

```text
symfony-demo → 2/2
```

Mensagem-chave:

```text
Chart ≠ Release ≠ Revision
STATUS=deployed ≠ prova isolada de aplicação funcional
```

---

# Estado de validação destas micropráticas

As micropráticas de **Kustomize e Helm foram revalidadas em runtime no cluster de formação**, usando o namespace de validação da Sessão 10.

Foi confirmado em runtime:

- renderização DEV/PROD com Kustomize;
- diferenças de `APP_ENV`, réplicas, CPU request e nomes;
- aplicação e remoção do overlay DEV;
- correspondência entre labels do Pod e selectors de Deployment/Service;
- EndpointSlice Kustomize com backend `ready=true` e `serving=true`;
- `helm lint` sem falhas;
- `helm template` do Chart;
- instalação da release `symfony-demo-helm`;
- revisão inicial `deployed`;
- Deployment Helm `1/1` e Service na porta 80;
- imagem `1.1.0` e selector esperados;
- EndpointSlice Helm com backend `ready=true` e `serving=true`;
- `helm uninstall` e remoção dos objetos da release;
- preservação da baseline original `symfony-demo` em `2/2` após os cleanups.

As micropráticas reutilizam `symfony-demo-config` e `postgres-credentials` do baseline. O objetivo continua a ser compreender o fluxo de gestão por ambientes/releases, não aprofundar templating.
