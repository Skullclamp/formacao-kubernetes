# Laboratório 2 — Kubernetes Básico

**Sessão:** 1  
**Módulo:** M2 — Fundamentos e Arquitetura Kubernetes  
**Nível:** intermédio  
**Foco:** contexto, API, Namespace, Pod, YAML, labels e selectors

Este laboratório aplica o mesmo padrão pedagógico da Sessão 4. Em cada checkpoint o formando deve conseguir explicar **o que está a fazer, porque é necessário, que conceito Kubernetes está envolvido, o significado dos comandos e flags relevantes e que evidência prova o resultado**.

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
CONCEITOS ABORDADOS
   ↓
COMANDO / MANIFESTO
   ↓
FLAGS / CAMPOS IMPORTANTES
   ↓
OUTPUT / ESTADO ESPERADO
   ↓
O QUE OBSERVAR
   ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
   ↓
EVIDÊNCIA
```

> Um `kubectl apply` sem erro prova apenas que a API aceitou a operação. É necessário observar o estado do recurso para confirmar o comportamento pretendido.

---

# CP1 — Confirmar contexto e comunicação com o cluster

## Objetivo

Confirmar que `kubectl` está configurado para o cluster pretendido e que a Kubernetes API responde.

## O que estamos a fazer e porquê

`kubectl` não comunica diretamente com os Pods. Usa a informação do `kubeconfig` e do contexto ativo para enviar pedidos ao `kube-apiserver`. Antes de criar recursos temos de saber **a que cluster estamos ligados**.

## Conceitos abordados neste CP

- Kubernetes API;
- `kubectl`;
- `kubeconfig`;
- contexto ativo;
- cluster e Nodes.

## Comandos

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces
```

## Como interpretar os comandos e flags

- `kubectl config current-context` mostra o contexto atualmente selecionado no `kubeconfig`;
- `kubectl cluster-info` confirma comunicação com a API e apresenta informação básica dos endpoints do cluster;
- `kubectl get nodes` consulta os objetos `Node` registados no cluster;
- `-o wide` acrescenta informação operacional, como IP e versão;
- `kubectl get namespaces` lista os Namespaces existentes.

## O que observar

Confirmar que:

```text
contexto ativo identificado
API Kubernetes responde
Nodes são visíveis
Namespaces podem ser consultados
```

### CHECKPOINT CP1

O formando consegue explicar o percurso simplificado:

```text
kubectl
   ↓
kubeconfig / contexto
   ↓
Kubernetes API
   ↓
cluster
```

**Evidência:** guardar o nome do contexto ativo e a listagem dos Nodes.

---

# CP2 — Criar um Namespace

## Objetivo

Criar um espaço lógico próprio para os recursos do laboratório.

## O que estamos a fazer e porquê

Um Namespace permite organizar e isolar logicamente recursos namespaced. Nesta sessão usamos `formacao` para que o Pod do laboratório não fique misturado com recursos de outros contextos.

## Conceitos abordados neste CP

- Namespace;
- recursos namespaced;
- organização lógica de objetos Kubernetes.

## Comandos

```bash
kubectl create namespace formacao
kubectl get namespace formacao
```

## Como interpretar os comandos

- `kubectl create namespace formacao` pede à API a criação de um objeto `Namespace` chamado `formacao`;
- `kubectl get namespace formacao` consulta especificamente esse objeto para validar a criação.

## O que observar

O Namespace deve aparecer com estado `Active`.

### CHECKPOINT CP2

```text
Namespace formacao existe
estado = Active
```

**Evidência:** guardar a linha devolvida por `kubectl get namespace formacao`.

---

# CP3 — Ler o manifesto antes de o aplicar

## Objetivo

Interpretar a estrutura mínima de um objeto Kubernetes declarado em YAML.

## O que estamos a fazer e porquê

Kubernetes trabalha fortemente com configuração declarativa. Antes de enviar o manifesto para a API, analisamos **que objeto queremos criar** e **qual o estado desejado declarado**.

Ficheiro utilizado:

```text
sessao-01/manifests/pod-demo.yaml
```

A partir da diretoria `sessao-01`:

```bash
cat manifests/pod-demo.yaml
```

## Conceitos abordados neste CP

- YAML;
- manifest Kubernetes;
- `apiVersion`;
- `kind`;
- `metadata`;
- `spec`;
- Pod;
- labels;
- imagem do container.

## Como interpretar os campos

| Campo | Função neste manifesto |
|---|---|
| `apiVersion: v1` | versão da API usada para este tipo de objeto |
| `kind: Pod` | tipo de recurso a criar |
| `metadata.name` | nome do Pod |
| `metadata.namespace` | Namespace onde o Pod será criado |
| `metadata.labels` | pares chave/valor usados para identificar e selecionar o recurso |
| `spec` | descrição do estado pretendido do Pod |
| `spec.containers` | containers que pertencem ao Pod |
| `image` | imagem usada pelo container |

Antes de avançar, responder:

1. Que objeto será criado?
2. Qual é o nome do recurso?
3. Em que Namespace ficará?
4. Que imagem será utilizada?
5. Que labels existem?
6. Onde está descrito o estado desejado?

### CHECKPOINT CP3

O formando consegue explicar a estrutura `apiVersion → kind → metadata → spec` e identificar a intenção do manifesto antes de o executar.

**Evidência:** registar as respostas às seis perguntas anteriores.

---

# CP4 — Criar o Pod a partir de YAML e observar o estado

## Objetivo

Aplicar o manifesto à API Kubernetes e validar que o Pod chega ao estado esperado.

## O que estamos a fazer e porquê

`kubectl apply` envia a configuração declarada para a API. Depois consultamos o recurso para distinguir **manifesto aceite** de **workload efetivamente em execução**.

## Comandos

```bash
kubectl apply -f manifests/pod-demo.yaml
kubectl get pods -n formacao -o wide
```

## Como interpretar os comandos e flags

| Elemento | Significado |
|---|---|
| `kubectl apply` | cria ou atualiza o recurso para aproximar o estado real do manifesto declarado |
| `-f manifests/pod-demo.yaml` | usa o ficheiro indicado como fonte da configuração |
| `get pods` | consulta objetos Pod |
| `-n formacao` | limita a operação ao Namespace `formacao` |
| `-o wide` | acrescenta informação operacional, como Node e IP do Pod |

Se for necessário perceber por que razão o Pod não está no estado esperado:

```bash
kubectl describe pod web-demo -n formacao
```

- `describe` apresenta informação detalhada, condições e Events associados ao recurso.

## O que observar

Confirmar:

```text
Pod web-demo existe
Namespace = formacao
STATUS = Running
Node atribuído
IP do Pod atribuído
```

> Se o Pod ainda estiver em `ContainerCreating`, observar durante alguns segundos antes de concluir que existe uma falha. Se permanecer fora de `Running`, usar `describe` para recolher evidência.

### CHECKPOINT CP4

O Pod foi aceite pela API **e** atingiu o estado operacional esperado.

**Evidência:** guardar `kubectl get pods -n formacao -o wide`.

---

# CP5 — Observar labels e utilizar um selector

## Objetivo

Comprovar que labels identificam recursos e que selectors permitem selecionar objetos com base nessas labels.

## O que estamos a fazer e porquê

Kubernetes usa labels e selectors extensivamente para relacionar objetos. Nesta introdução vamos apenas observar as labels do Pod e filtrar a listagem por `app=web`.

## Conceitos abordados neste CP

- label;
- selector;
- relação entre metadata e seleção de recursos.

## Consultar labels

```bash
kubectl get pods -n formacao --show-labels
```

- `--show-labels` acrescenta as labels ao output da listagem.

## Selecionar apenas Pods com `app=web`

```bash
kubectl get pods -n formacao -l app=web
```

- `-l` significa *label selector*;
- `app=web` é a condição usada para selecionar os recursos.

Comparar com um selector que não corresponde:

```bash
kubectl get pods -n formacao -l app=inexistente
```

## O que observar

```text
app=web         → web-demo é devolvido
app=inexistente → nenhum Pod é devolvido
```

O teste negativo demonstra que o selector não pesquisa texto livre: compara as labels efetivamente atribuídas aos recursos.

### CHECKPOINT CP5

O formando consegue explicar:

```text
label    = metadata atribuída ao recurso
selector = condição utilizada para encontrar recursos por labels
```

**Evidência:** guardar a listagem com `--show-labels` e comparar os dois selectors.

---

# CP6 — Limpeza e validação final

## Objetivo

Remover os recursos do laboratório e confirmar o efeito da eliminação do Namespace.

## O que estamos a fazer e porquê

O Pod pertence ao Namespace `formacao`. Ao remover o Namespace, os recursos namespaced nele contidos são também eliminados. Isto deixa o cluster preparado para os exercícios seguintes.

## Conceitos abordados neste CP

- ciclo de vida de recursos Kubernetes;
- escopo de Namespace;
- limpeza controlada;
- validação pós-operação.

## Comando

```bash
kubectl delete namespace formacao
```

Validar:

```bash
kubectl get namespace formacao
```

O resultado esperado é uma mensagem equivalente a `NotFound`, porque o Namespace já não deverá existir depois de a eliminação terminar.

### CHECKPOINT CP6

```text
Namespace formacao removido
Pod web-demo removido com o Namespace
estado final validado
```

**Evidência:** guardar a confirmação da remoção ou o `NotFound` da consulta final.

---

# Questões de consolidação

1. Que papel desempenha o contexto ativo do `kubectl`?
2. O que acrescenta `-o wide` a uma listagem?
3. Qual é a função de `-n formacao`?
4. O que representa `-f` em `kubectl apply -f ...`?
5. Qual é a diferença entre uma label e um selector?
6. Porque não é suficiente concluir que o Pod está funcional apenas porque `kubectl apply` terminou sem erro?
7. Que informação adicional pode ser obtida através de `kubectl describe`?

# Regra de evidência da Sessão 1 — Módulo 2

```text
contexto identificado
+
API acessível
+
Namespace criado
+
manifesto compreendido
+
Pod aplicado e Running
+
labels observadas
+
selector positivo e negativo validados
+
recursos removidos no final
```
