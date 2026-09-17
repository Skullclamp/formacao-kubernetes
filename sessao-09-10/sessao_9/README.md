# Sessão 9 — Baseline reutilizado na Sessão 10

A Sessão 9 deixa preparado o estado M3/M4 que será operado e reforçado na Sessão 10.

Este laboratório é **acompanhado pelo formador**. Não basta executar os comandos: em cada passo o formando deve saber **onde olhar no output, o que comparar, o que esperar e que conclusão retirar**.

```text
COMANDO
   ↓
ONDE OLHAR
   ↓
QUE VALOR PROCURAR
   ↓
COM O QUE COMPARAR
   ↓
O QUE ESPERAR
   ↓
O QUE CONCLUIR
```

---

# 1. Objetivo da sessão

Construir e validar uma baseline composta por:

```text
ConfigMap + Secret
        ↓
Deployment Symfony 1.1.0
        ↓
Service
        ↓
Ingress, quando utilizado

PostgreSQL StatefulSet
        ↓
PVC persistente
```

O Deployment Symfony desta sessão **ainda não contém resources nem probes**. Esses elementos entram propositadamente na Sessão 10, no bloco `01_resources_probes/`, para tornar visível a progressão M4 → M5.

## Conceitos abordados

- ConfigMap e configuração não sensível;
- Secret e configuração sensível;
- Deployment e réplicas;
- Service e selector;
- StatefulSet;
- PersistentVolumeClaim;
- StorageClass;
- relação entre aplicação e base de dados;
- imagem de container e versão da aplicação;
- Ingress como exposição opcional.

---

# 2. Antes de aplicar — perceber o que cada manifesto cria

## ConfigMap

Ficheiro:

```text
baseline/01-configmap.yaml
```

Conteúdo relevante:

```text
APP_ENV     → prod
APP_VERSION → 1.1.0
```

O objetivo é separar configuração da imagem do container.

## Secret

O ficheiro:

```text
baseline/02-secret.example.yaml
```

é apenas um **exemplo com placeholders**.

> Não o aplicar sem substituir os valores. Na formação, o Secret `postgres-credentials` pode ser pré-provisionado pelo formador para evitar exposição de credenciais.

## PostgreSQL

O manifesto `03-postgresql.yaml` cria:

```text
Service postgres
      ↓
StatefulSet postgres
      ↓
Pod postgres-0
      ↓
PVC data-postgres-0
```

A base de dados usa PostgreSQL 16 e armazenamento `local-path` com pedido de 2 GiB.

## Symfony

O Deployment cria **2 réplicas** da imagem:

```text
ghcr.io/skullclamp/symfony-demo:1.1.0
```

A label comum é:

```text
app=symfony-demo
```

O Service `symfony-demo` usa exatamente esse selector.

---

# 3. Aplicar a baseline

## O que estamos a fazer

Criar os objetos pela ordem das dependências: configuração, base de dados, aplicação e Service.

## Onde executar

No terminal configurado para o namespace de trabalho definido pelo formador.

## Comandos

```bash
kubectl apply -f baseline/01-configmap.yaml

# O Secret real deve já existir ou ser criado a partir do exemplo adaptado.
kubectl get secret postgres-credentials

kubectl apply -f baseline/03-postgresql.yaml
kubectl apply -f baseline/04-symfony-deployment.yaml
kubectl apply -f baseline/05-symfony-service.yaml
```

O Ingress é opcional:

```bash
kubectl apply -f baseline/06-ingress.example.yaml
```

> Antes de aplicar o Ingress, adaptar o host ao ambiente e confirmar a IngressClass utilizada no cluster.

### Explicação dos comandos

| Elemento | Significado |
|---|---|
| `kubectl apply -f` | cria o objeto ou atualiza-o declarativamente a partir do ficheiro |
| `kubectl get secret` | confirma a existência do Secret sem mostrar os respetivos valores |
| `baseline/...yaml` | manifesto usado como fonte declarativa |

---

# 4. Validar PostgreSQL e persistência

## Comandos

```bash
kubectl get statefulset postgres
kubectl get pod postgres-0 -o wide
kubectl get pvc
kubectl get svc postgres
```

## Onde olhar

### StatefulSet

Na coluna `READY`:

```text
1/1
```

Isto significa que a única réplica desejada está pronta.

### Pod PostgreSQL

Comparar:

```text
READY   STATUS
1/1     Running
```

Se o Pod estiver `Running` mas `0/1`, ainda não está pronto para receber ligações.

### PVC

Na coluna `STATUS`, procurar:

```text
Bound
```

E confirmar a StorageClass:

```text
local-path
```

### Service

Confirmar que existe `postgres` na porta `5432`.

## O que comparar

```text
StatefulSet replicas desejadas → 1
Pod PostgreSQL                → 1/1 Running
PVC                           → Bound
Service                       → postgres:5432
```

## O que concluir

Só considerar a base de dados preparada quando:

```text
StatefulSet 1/1
+
postgres-0 1/1 Running
+
PVC Bound
```

Um PVC `Pending` significa que a persistência ainda não foi satisfeita, mesmo que os restantes manifests tenham sido aceites pela API.

---

# 5. Validar Symfony

## Comandos

```bash
kubectl get deployment symfony-demo
kubectl get pods -l app=symfony-demo -o wide
kubectl get svc symfony-demo -o wide
kubectl get endpointslices \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Onde olhar

### Deployment

Na coluna `READY`, procurar:

```text
2/2
```

### Pods

Para as duas réplicas Symfony, comparar:

```text
READY   STATUS
1/1     Running
1/1     Running
```

### Service

Confirmar:

```text
NAME          TYPE        PORT(S)
symfony-demo  ClusterIP   80/TCP
```

### EndpointSlice

Dentro de `endpoints:`, procurar os endereços dos Pods selecionados pelo Service.

O raciocínio é:

```text
Pods têm label app=symfony-demo
          ↓
Service procura app=symfony-demo
          ↓
EndpointSlice representa os backends encontrados
```

## Comparação importante

```text
label dos Pods      → app=symfony-demo
selector do Service → app=symfony-demo
                          ↑
                       COINCIDE
```

Se estes valores não coincidirem, o Service pode existir mas ficar sem backends.

---

# 6. Confirmar a versão e a configuração

## Comandos

```bash
kubectl get configmap symfony-demo-config \
  -o jsonpath='APP_ENV={.data.APP_ENV}{"\n"}APP_VERSION={.data.APP_VERSION}{"\n"}'

kubectl get deployment symfony-demo \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

## Esperado

```text
APP_ENV=prod
APP_VERSION=1.1.0
image=ghcr.io/skullclamp/symfony-demo:1.1.0
```

## O que comparar

A versão declarada no ConfigMap deve ser coerente com a imagem usada pelo Deployment:

```text
ConfigMap APP_VERSION → 1.1.0
Deployment image      → ...:1.1.0
```

---

# 7. Estado funcional esperado

A aplicação deve responder internamente a:

```text
/health → saúde básica
/ready  → prontidão, incluindo ligação à base de dados
/info   → versão e ambiente
```

A validação automática usada na Sessão 10 testa estes três endpoints através de um Pod temporário no cluster.

## Baseline a guardar mentalmente

Esta é a referência saudável que será usada na Sessão 10:

```text
PostgreSQL StatefulSet → 1/1
postgres-0             → 1/1 Running
PVC                    → Bound
Symfony Deployment     → 2/2
Symfony Pods           → 2 × 1/1 Running
Imagem                 → 1.1.0
Service selector       → coincide com app=symfony-demo
Service                → backends disponíveis
```

Tudo o que mudar na Sessão 10 deverá ser comparado com esta baseline.

---

# 8. Checkpoint final da Sessão 9

Não avançar enquanto não for possível responder **sim** a todas estas perguntas:

| Pergunta | Evidência |
|---|---|
| PostgreSQL está operacional? | StatefulSet `1/1` e `postgres-0 1/1 Running` |
| A persistência está disponível? | PVC `Bound` |
| Symfony tem as duas réplicas disponíveis? | Deployment `2/2` |
| O Service seleciona os Pods corretos? | selector e labels coincidem |
| A versão é a esperada? | ConfigMap e imagem indicam `1.1.0` |
| O Secret necessário existe? | `postgres-credentials` presente |

Mensagem-chave:

```text
Manifesto aceite pela API ≠ aplicação validada

Só avançamos quando o estado observado confirma o estado desejado.
```
