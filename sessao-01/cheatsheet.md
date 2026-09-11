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

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-d` | `--detach` | Executa o container em segundo plano | `docker run -d nginx` |
| `-i` | `--interactive` | Mantém a entrada standard aberta | `docker run -i ubuntu` |
| `-t` | `--tty` | Aloca um terminal | `docker run -it ubuntu bash` |
| `-p` | `--publish` | Publica uma porta no formato `<host>:<container>` | `docker run -p 8080:80 nginx` |
| `-v` | `--volume` | Monta um volume ou caminho | `docker run -v dados:/data nginx` |
| `-e` | `--env` | Define uma variável de ambiente | `docker run -e APP_ENV=dev <imagem>` |
| — | `--env-file` | Lê variáveis de ambiente de um ficheiro | `docker run --env-file .env <imagem>` |
| — | `--name` | Define o nome do container | `docker run --name web nginx` |
| — | `--network` | Liga o container a uma rede | `docker run --network app-net nginx` |
| — | `--rm` | Remove automaticamente o container quando termina | `docker run --rm hello-world` |

Exemplo combinado:

```bash
docker run --name web-demo -d -p 8080:80 nginx
```

### `docker ps`

**Para que serve:** lista os containers. Sem opções mostra apenas os containers em execução; com `-a` inclui também os containers parados.

**Sintaxe**

```bash
docker ps [OPTIONS]
```

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-a` | `--all` | Mostra também containers parados | `docker ps -a` |
| `-q` | `--quiet` | Mostra apenas os IDs | `docker ps -q` |
| `-f` | `--filter` | Filtra os resultados | `docker ps -f status=running` |
| — | `--format` | Formata a saída | `docker ps --format '{{.Names}}'` |
| — | `--no-trunc` | Não trunca a informação apresentada | `docker ps --no-trunc` |

### `docker logs`

**Para que serve:** consulta a saída de logs produzida por um container. É particularmente útil para observar o arranque de uma aplicação e diagnosticar erros.

**Sintaxe**

```bash
docker logs [OPTIONS] CONTAINER
```

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-f` | `--follow` | Continua a acompanhar novos logs | `docker logs -f web-demo` |
| `-n` | `--tail` | Mostra apenas as últimas linhas | `docker logs --tail 50 web-demo` |
| `-t` | `--timestamps` | Apresenta timestamps | `docker logs -t web-demo` |
| — | `--since` | Mostra logs posteriores ao instante indicado | `docker logs --since 10m web-demo` |
| — | `--until` | Mostra logs anteriores ao instante indicado | `docker logs --until 2026-09-11T12:00:00 web-demo` |

### `docker stop`

**Para que serve:** solicita a paragem de um ou mais containers em execução, permitindo uma terminação controlada antes de recorrer a uma paragem forçada.

**Sintaxe**

```bash
docker stop [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-t` | `--timeout` | Define o tempo de espera antes de forçar a paragem | `docker stop -t 20 web-demo` |
| `-s` | `--signal` | Define o sinal enviado ao container | `docker stop --signal SIGTERM web-demo` |

### `docker rm`

**Para que serve:** remove um ou mais containers já criados. A remoção do container não equivale à remoção de volumes nomeados utilizados para persistência.

**Sintaxe**

```bash
docker rm [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-f` | `--force` | Força a remoção de um container em execução | `docker rm -f web-demo` |
| `-v` | `--volumes` | Remove volumes anónimos associados ao container | `docker rm -v web-demo` |

### `docker volume`

**Para que serve:** gere volumes Docker, utilizados para manter dados fora do ciclo de vida do container.

| Operação | Sintaxe | Para que serve | Exemplo |
|---|---|---|---|
| Criar | `docker volume create [OPTIONS] [VOLUME]` | Cria um volume | `docker volume create dados-demo` |
| Listar | `docker volume ls [OPTIONS]` | Lista os volumes existentes | `docker volume ls` |
| Inspecionar | `docker volume inspect [OPTIONS] VOLUME [VOLUME...]` | Mostra informação detalhada sobre um volume | `docker volume inspect dados-demo` |
| Remover | `docker volume rm [OPTIONS] VOLUME [VOLUME...]` | Remove um ou mais volumes não utilizados | `docker volume rm dados-demo` |

Flags frequentes em `docker volume ls`:

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-q` | `--quiet` | Mostra apenas os nomes dos volumes | `docker volume ls -q` |
| `-f` | `--filter` | Filtra a listagem | `docker volume ls -f dangling=true` |

---

## Podman

A sintaxe das operações básicas é semelhante à utilizada com Docker, mas deve ser consultada na documentação do Podman quando forem utilizadas opções específicas.

### `podman run`

**Para que serve:** cria e executa um novo container a partir de uma imagem utilizando Podman.

**Sintaxe**

```bash
podman run [OPTIONS] IMAGE [COMMAND [ARG...]]
```

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-d` | `--detach` | Executa em segundo plano | `podman run -d nginx` |
| `-i` | `--interactive` | Mantém a entrada standard aberta | `podman run -i ubuntu` |
| `-t` | `--tty` | Aloca um terminal | `podman run -it ubuntu bash` |
| `-p` | `--publish` | Publica portas | `podman run -p 8080:80 nginx` |
| `-v` | `--volume` | Monta volumes | `podman run -v dados:/data nginx` |
| `-e` | `--env` | Define variáveis de ambiente | `podman run -e APP_ENV=dev <imagem>` |
| — | `--name` | Define o nome do container | `podman run --name web nginx` |
| — | `--network` | Define a rede utilizada | `podman run --network app-net nginx` |
| — | `--rm` | Remove o container quando termina | `podman run --rm hello-world` |

### Operações básicas

| Comando | Sintaxe | Para que serve | Exemplo |
|---|---|---|---|
| `podman ps` | `podman ps [OPTIONS]` | Lista containers | `podman ps -a` |
| `podman logs` | `podman logs [OPTIONS] CONTAINER` | Consulta os logs de um container | `podman logs -f web-demo` |
| `podman stop` | `podman stop [OPTIONS] CONTAINER [CONTAINER...]` | Para um ou mais containers | `podman stop web-demo` |
| `podman rm` | `podman rm [OPTIONS] CONTAINER [CONTAINER...]` | Remove um ou mais containers | `podman rm web-demo` |

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

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-n` | `--namespace` | Executa a operação num Namespace específico | `kubectl get pods -n formacao` |
| `-A` | `--all-namespaces` | Abrange todos os Namespaces, quando suportado pelo comando | `kubectl get pods -A` |
| `-o` | `--output` | Define o formato de saída (`wide`, `yaml`, `json`, etc.) | `kubectl get pods -o wide` |
| `-l` | `--selector` | Filtra recursos através de labels | `kubectl get pods -l app=web` |

## `kubectl get`

**Para que serve:** consulta e apresenta um ou vários recursos existentes no cluster.

**Sintaxe**

```bash
kubectl get TYPE [NAME] [FLAGS]
```

Flags muito utilizadas:

| Flag | Utilização | Exemplo |
|---|---|---|
| `-n <namespace>` | Seleciona o Namespace | `kubectl get pods -n formacao` |
| `-A` | Lista recursos em todos os Namespaces | `kubectl get pods -A` |
| `-o wide` | Mostra informação adicional | `kubectl get pods -o wide` |
| `-o yaml` | Mostra o recurso em YAML | `kubectl get pod web-demo -o yaml` |
| `-o json` | Mostra o recurso em JSON | `kubectl get pod web-demo -o json` |
| `-l <chave>=<valor>` | Filtra através de labels | `kubectl get pods -l app=web` |
| `--show-labels` | Apresenta as labels dos recursos | `kubectl get pods --show-labels` |
| `-w` / `--watch` | Mantém a consulta ativa e acompanha alterações | `kubectl get pods -w` |

## `kubectl apply`

**Para que serve:** aplica uma configuração declarativa descrita num ficheiro ou entrada standard. Cria o recurso se este ainda não existir e aplica alterações quando já existe.

**Sintaxe**

```bash
kubectl apply -f <ficheiro|diretório|URL> [FLAGS]
```

Flags úteis:

| Flag | Utilização | Exemplo |
|---|---|---|
| `-f` / `--filename` | Indica o ficheiro, diretório ou URL com a configuração | `kubectl apply -f pod-demo.yaml` |
| `-n <namespace>` | Define o Namespace da operação quando aplicável | `kubectl apply -f pod-demo.yaml -n formacao` |
| `--dry-run=client` | Processa localmente sem persistir a alteração no cluster | `kubectl apply -f pod-demo.yaml --dry-run=client` |

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

| Operação | Sintaxe | Para que serve | Exemplo |
|---|---|---|---|
| Criar | `kubectl create namespace <nome>` | Cria um novo Namespace | `kubectl create namespace formacao` |
| Listar | `kubectl get namespaces` | Lista os Namespaces existentes | `kubectl get namespaces` |
| Detalhar | `kubectl describe namespace <nome>` | Mostra informação detalhada do Namespace | `kubectl describe namespace formacao` |
| Remover | `kubectl delete namespace <nome>` | Remove o Namespace e os recursos namespaced nele existentes | `kubectl delete namespace formacao` |

## Cluster e contextos

| Comando | Sintaxe | Para que serve | Exemplo |
|---|---|---|---|
| `cluster-info` | `kubectl cluster-info` | Apresenta informação sobre o Control Plane e serviços principais do cluster | `kubectl cluster-info` |
| `get nodes` | `kubectl get nodes [FLAGS]` | Lista os nodes conhecidos pelo cluster | `kubectl get nodes -o wide` |
| `current-context` | `kubectl config current-context` | Mostra o contexto atualmente selecionado | `kubectl config current-context` |
| `get-contexts` | `kubectl config get-contexts [<nome>]` | Lista os contextos disponíveis ou apresenta um contexto específico | `kubectl config get-contexts` |
| `use-context` | `kubectl config use-context <contexto>` | Altera o contexto ativo no kubeconfig | `kubectl config use-context minikube` |

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

| Campo | Para que serve | Exemplo |
|---|---|---|
| `apiVersion` | Indica a versão da API utilizada pelo recurso | `apiVersion: v1` |
| `kind` | Identifica o tipo de recurso Kubernetes | `kind: Pod` |
| `metadata` | Contém informação de identificação e metadados | `metadata:` |
| `metadata.name` | Define o nome do recurso | `name: web-demo` |
| `metadata.namespace` | Define o Namespace onde o recurso pertence, quando aplicável | `namespace: formacao` |
| `metadata.labels` | Associa pares chave/valor utilizados para organização e seleção | `app: web` |
| `spec` | Descreve o estado/configuração pretendida do recurso | `spec:` |

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
