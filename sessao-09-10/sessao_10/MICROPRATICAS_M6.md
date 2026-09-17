# Sessão 10 — Micropráticas M6

## Cloud-native, Kustomize e Helm

**Duração total:** 30 minutos  
**Posição:** bloco anterior ao laboratório integrado final.

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

# 2. Kustomize — 10 min

## O que estamos a fazer

Renderizar duas variantes da mesma base e identificar **apenas o que muda** entre DEV e PROD.

## Conceitos abordados

- base;
- overlay;
- `nameSuffix`;
- alteração de réplicas;
- `configMapGenerator`;
- patch;
- renderização sem aplicar.

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
kubectl kustomize m6_kustomize/overlays/dev > /tmp/kustomize-dev.yaml
kubectl kustomize m6_kustomize/overlays/prod > /tmp/kustomize-prod.yaml
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

### Pergunta que fecha o exercício

> O que mudou por causa do overlay e o que continuou a vir da base comum?

O formando deve perceber:

```text
BASE
 +
OVERLAY DEV
 =
variante DEV

BASE
 +
OVERLAY PROD
 =
variante PROD
```

## 2.3 Aplicar DEV

```bash
kubectl -n "$NS" apply -k m6_kustomize/overlays/dev
kubectl -n "$NS" rollout status deployment/symfony-demo-kustomize-dev --timeout=90s
```

### Flags importantes

| Elemento | Significado |
|---|---|
| `apply -k` | aplica uma kustomization em vez de um único ficheiro YAML |
| `rollout status` | acompanha a convergência do Deployment |
| `--timeout=90s` | limita a espera a 90 segundos |

## 2.4 Confirmar o que ficou aplicado

```bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev \
  -o jsonpath='replicas={.spec.replicas}{" cpuRequest="}{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'

kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev \
  -o jsonpath='APP_ENV={.data.APP_ENV}{"\n"}'
```

### Esperado

```text
replicas=1 cpuRequest=50m
APP_ENV=dev
```

### O que comparar

O resultado no cluster deve corresponder ao que foi visto no YAML renderizado DEV.

```text
render DEV → replicas=1, APP_ENV=dev, CPU=50m
cluster    → mesmos valores
```

## 2.5 Remover

```bash
kubectl -n "$NS" delete -k m6_kustomize/overlays/dev
```

Mensagem-chave:

```text
Kustomize = base + diferenças declarativas
Renderizar ≠ aplicar
```

---

# 3. Helm — 10 min

## O que estamos a fazer

Renderizar um Chart, criar uma release, consultar o seu estado e histórico e removê-la.

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

## 3.1 Renderizar primeiro

```bash
helm template symfony-demo-helm m6_helm/symfony-demo \
  > /tmp/symfony-demo-helm.yaml
```

### Onde olhar

No YAML renderizado, procurar:

```text
kind: Deployment
kind: Service
image: ghcr.io/skullclamp/symfony-demo:1.1.0
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

## 3.2 Instalar ou atualizar a release

```bash
helm upgrade --install symfony-demo-helm \
  m6_helm/symfony-demo \
  --namespace "$NS" \
  --set replicaCount=1
```

### Flags importantes

| Flag | Significado |
|---|---|
| `upgrade --install` | atualiza a release se existir; instala se ainda não existir |
| `--namespace "$NS"` | define o namespace da release |
| `--set replicaCount=1` | sobrepõe este valor sem editar `values.yaml` |

## 3.3 Observar a release

```bash
helm status symfony-demo-helm --namespace "$NS"
helm history symfony-demo-helm --namespace "$NS"
```

### Onde olhar no `helm status`

Procurar:

```text
STATUS: deployed
```

### Onde olhar no `helm history`

Comparar:

```text
REVISION   STATUS
1          deployed
```

Numa primeira instalação é esperado existir uma revisão inicial. Operações futuras de upgrade criariam novas revisões.

## 3.4 Confirmar os objetos no cluster

```bash
kubectl -n "$NS" get deployment,service \
  -l app.kubernetes.io/instance=symfony-demo-helm
```

Se o Chart usar essa label de release, deverão aparecer os objetos associados. Se não aparecerem, usar `helm status` para identificar os nomes gerados e consultá-los diretamente.

### Comparação importante

```text
helm template → YAML local, sem release
helm upgrade --install → release persistida no cluster
helm status/history → estado e histórico da release
```

## 3.5 Remover

```bash
helm uninstall symfony-demo-helm --namespace "$NS"
```

Depois confirmar:

```bash
helm status symfony-demo-helm --namespace "$NS"
```

É esperado que a release deixe de ser encontrada.

Mensagem-chave:

```text
Chart ≠ Release ≠ Revision
```

> As micropráticas reutilizam `symfony-demo-config` e `postgres-credentials` do baseline. O objetivo é compreender o fluxo de gestão por ambientes/releases, não aprofundar templating.

> A renderização/aplicação Kustomize e a instalação Helm foram verificadas estaticamente no pacote, mas não fizeram parte do ensaio runtime final de 16/09/2026. Ensaiar no cluster antes da aula se estas micropráticas forem utilizadas.
