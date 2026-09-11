# Cheatsheet — Sessão 1

Referência rápida à **finalidade**, sintaxe, opções mais utilizadas e estruturas trabalhadas na sessão.

> Convenções: valores entre `< >` devem ser substituídos. Elementos entre `[ ]` são opcionais.

## Docker

### `docker run`

**Para que serve:** cria um novo container a partir de uma imagem e inicia a sua execução. Se a imagem não existir localmente, Docker tenta obtê-la do registry configurado.

**Sintaxe**

```bash
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-d` | `--detach` | Executa o container em segundo plano |
| `-i` | `--interactive` | Mantém a entrada standard aberta |
| `-t` | `--tty` | Aloca um terminal |
| `-p` | `--publish` | Publica uma porta, por exemplo `<host>:<container>` |
| `-v` | `--volume` | Monta um volume ou caminho |
| `-e` | `--env` | Define uma variável de ambiente |
| — | `--env-file` | Lê variáveis de ambiente de um ficheiro |
| — | `--name` | Define o nome do container |
| — | `--network` | Liga o container a uma rede |
| — | `--rm` | Remove automaticamente o container quando termina |

Exemplo:

```bash
docker run --name web-demo -d -p 8080:80 nginx
```

### `docker ps`

**Para que serve:** lista os containers. Sem opções mostra apenas os containers em execução; com `-a` inclui também os containers parados.

**Sintaxe**

```bash
docker ps [OPTIONS]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-a` | `--all` | Mostra também containers parados |
| `-q` | `--quiet` | Mostra apenas os IDs |
| `-f` | `--filter` | Filtra os resultados |
| — | `--format` | Formata a saída |
| — | `--no-trunc` | Não trunca a informação apresentada |

### `docker logs`

**Para que serve:** consulta a saída de logs produzida por um container. É particularmente útil para observar o arranque de uma aplicação e diagnosticar erros.

**Sintaxe**

```bash
docker logs [OPTIONS] CONTAINER
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-f` | `--follow` | Continua a acompanhar novos logs |
| `-n` | `--tail` | Mostra apenas as últimas linhas |
| `-t` | `--timestamps` | Apresenta timestamps |
| — | `--since` | Mostra logs posteriores ao instante indicado |
| — | `--until` | Mostra logs anteriores ao instante indicado |

### `docker stop`

**Para que serve:** solicita a paragem de um ou mais containers em execução, permitindo uma terminação controlada antes de recorrer a uma paragem forçada.

**Sintaxe**

```bash
docker stop [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-t` | `--timeout` | Define o tempo de espera antes de forçar a paragem |
| `-s` | `--signal` | Define o sinal enviado ao container |

### `docker rm`

**Para que serve:** remove um ou mais containers já criados. A remoção do container não equivale à remoção de volumes nomeados utilizados para persistência.

**Sintaxe**

```bash
docker rm [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-f` | `--force` | Força a remoção de um container em execução |
| `-v` | `--volumes` | Remove volumes anónimos associados ao container |

### `docker volume`

**Para que serve:** gere volumes Docker, utilizados para manter dados fora do ciclo de vida do container.

| Operação | Sintaxe | Para que serve |
|---|---|---|
| Criar | `docker volume create [OPTIONS] [VOLUME]` | Cria um volume |
| Listar | `docker volume ls [OPTIONS]` | Lista os volumes existentes |
| Inspecionar | `docker volume inspect [OPTIONS] VOLUME [VOLUME...]` | Mostra informação detalhada sobre um volume |
| Remover | `docker volume rm [OPTIONS] VOLUME [VOLUME...]` | Remove um ou mais volumes não utilizados |

Flags frequentes em `docker volume ls`:

| Flag | Forma longa | Utilização |
|---|---|---|
| `-q` | `--quiet` | Mostra apenas os nomes dos volumes |
| `-f` | `--filter` | Filtra a listagem |

---

## Podman

A sintaxe das operações básicas é semelhante à utilizada com Docker, mas deve ser consultada na documentação do Podman quando forem utilizadas opções específicas.

### `podman run`

**Para que serve:** cria e executa um novo container a partir de uma imagem utilizando Podman.

**Sintaxe**

```bash
podman run [OPTIONS] IMAGE [COMMAND [ARG...]]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-d` | `--detach` | Executa em segundo plano |
| `-i` | `--interactive` | Mantém a entrada standard aberta |
| `-t` | `--tty` | Aloca um terminal |
| `-p` | `--publish` | Publica portas |
| `-v` | `--volume` | Monta volumes |
| `-e` | `--env` | Define variáveis de ambiente |
| — | `--name` | Define o nome do container |
| — | `--network` | Define a rede utilizada |
| — | `--rm` | Remove o container quando termina |

### Operações básicas

| Comando | Sintaxe | Para que serve |
|---|---|---|
| `podman ps` | `podman ps [OPTIONS]` | Lista containers |
| `podman logs` | `podman logs [OPTIONS] CONTAINER` | Consulta os logs de um container |
| `podman stop` | `podman stop [OPTIONS] CONTAINER [CONTAINER...]` | Para um ou mais containers |
| `podman rm` | `podman rm [OPTIONS] CONTAINER [CONTAINER...]` | Remove um ou mais containers |

---

## `kubectl` — sintaxe geral

**Para que serve:** `kubectl` é a ferramenta de linha de comandos utilizada para comunicar com a API Kubernetes e consultar ou gerir recursos do cluster.

```bash
kubectl [COMMAND] [TYPE] [NAME] [FLAGS]
```

Exemplos de `TYPE`:

```text
pod
pods
namespace
namespaces
node
nodes
```

### Flags transversais frequentes

| Flag | Forma longa | Utilização |
|---|---|---|
| `-n` | `--namespace` | Executa a operação num Namespace específico |
| `-A` | `--all-namespaces` | Abrange todos os Namespaces, quando suportado pelo comando |
| `-o` | `--output` | Define o formato de saída (`wide`, `yaml`, `json`, etc.) |
| `-l` | `--selector` | Filtra recursos através de labels |

## `kubectl get`

**Para que serve:** consulta e apresenta um ou vários recursos existentes no cluster.

**Sintaxe**

```bash
kubectl get TYPE [NAME] [FLAGS]
```

Flags muito utilizadas:

| Flag | Utilização |
|---|---|
| `-n <namespace>` | Seleciona o Namespace |
| `-A` | Lista recursos em todos os Namespaces |
| `-o wide` | Mostra informação adicional |
| `-o yaml` | Mostra o recurso em YAML |
| `-o json` | Mostra o recurso em JSON |
| `-l <chave>=<valor>` | Filtra através de labels |
| `--show-labels` | Apresenta as labels dos recursos |
| `-w` / `--watch` | Mantém a consulta ativa e acompanha alterações |

Exemplos:

```bash
kubectl get pods -n formacao
kubectl get pods -n formacao -o wide
kubectl get pods -n formacao --show-labels
kubectl get pods -n formacao -l app=web
```

## `kubectl apply`

**Para que serve:** aplica uma configuração declarativa descrita num ficheiro ou entrada standard. Cria o recurso se este ainda não existir e aplica alterações quando já existe.

**Sintaxe**

```bash
kubectl apply -f <ficheiro|diretório|URL> [FLAGS]
```

Flags úteis:

| Flag | Utilização |
|---|---|
| `-f` / `--filename` | Indica o ficheiro, diretório ou URL com a configuração |
| `-n <namespace>` | Define o Namespace da operação quando aplicável |
| `--dry-run=client` | Processa localmente sem persistir a alteração no cluster |

Exemplo:

```bash
kubectl apply -f manifests/pod-demo.yaml
```

## `kubectl describe`

**Para que serve:** apresenta informação detalhada sobre um recurso, incluindo estado, configuração e, quando disponíveis, eventos e recursos relacionados.

**Sintaxe**

```bash
kubectl describe TYPE [NAME] [FLAGS]
```

Exemplos:

```bash
kubectl describe pod <pod> -n <namespace>
kubectl describe namespace <namespace>
```

## Namespaces

| Operação | Sintaxe | Para que serve |
|---|---|---|
| Criar | `kubectl create namespace <nome>` | Cria um novo Namespace |
| Listar | `kubectl get namespaces` | Lista os Namespaces existentes |
| Detalhar | `kubectl describe namespace <nome>` | Mostra informação detalhada do Namespace |
| Remover | `kubectl delete namespace <nome>` | Remove o Namespace e os recursos namespaced nele existentes |

## Cluster e contextos

| Comando | Sintaxe | Para que serve |
|---|---|---|
| `cluster-info` | `kubectl cluster-info` | Apresenta informação sobre o Control Plane e serviços principais do cluster |
| `get nodes` | `kubectl get nodes [FLAGS]` | Lista os nodes conhecidos pelo cluster |
| `current-context` | `kubectl config current-context` | Mostra o contexto atualmente selecionado |
| `get-contexts` | `kubectl config get-contexts [<nome>]` | Lista os contextos disponíveis ou apresenta um contexto específico |
| `use-context` | `kubectl config use-context <contexto>` | Altera o contexto ativo no kubeconfig |

---

## YAML — estrutura base de um recurso Kubernetes

```yaml
apiVersion: <versão-da-api>
kind: <tipo-do-recurso>
metadata:
  name: <nome>
  namespace: <namespace>
  labels:
    <chave>: <valor>
spec:
  # configuração pretendida do recurso
```

### Campos principais

| Campo | Para que serve |
|---|---|
| `apiVersion` | Indica a versão da API utilizada pelo recurso |
| `kind` | Identifica o tipo de recurso Kubernetes |
| `metadata` | Contém informação de identificação e metadados |
| `metadata.name` | Define o nome do recurso |
| `metadata.namespace` | Define o Namespace onde o recurso pertence, quando aplicável |
| `metadata.labels` | Associa pares chave/valor utilizados para organização e seleção |
| `spec` | Descreve o estado/configuração pretendida do recurso |

### Exemplo de Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
spec:
  containers:
    - name: web
      image: nginx
```

## Labels e selectors

Label num manifest:

```yaml
metadata:
  labels:
    app: web
    environment: formacao
```

Selector na linha de comandos:

```bash
kubectl get pods -l <chave>=<valor>
```

Exemplo:

```bash
kubectl get pods -n formacao -l app=web
```

---

## Verificações rápidas

### Docker

```bash
docker ps -a
docker logs --tail 50 <container>
docker logs -f <container>
```

### Kubernetes

```bash
kubectl get nodes -o wide
kubectl config current-context
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod> -n <namespace>
```

---

## Referências oficiais

- Docker CLI: https://docs.docker.com/reference/cli/docker/
- Docker `run`: https://docs.docker.com/reference/cli/docker/container/run/
- Podman `run`: https://docs.podman.io/en/latest/markdown/podman-run.1.html
- Referência `kubectl`: https://kubernetes.io/docs/reference/kubectl/
- Quick Reference oficial de `kubectl`: https://kubernetes.io/docs/reference/kubectl/quick-reference/
