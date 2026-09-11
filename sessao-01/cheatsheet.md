# Cheatsheet — Sessão 1

Referência rápida à **sintaxe**, opções mais utilizadas e estruturas trabalhadas na sessão.

> Convenções: valores entre `< >` devem ser substituídos. Elementos entre `[ ]` são opcionais.

## Docker

### `docker run`

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

### `docker stop`

**Sintaxe**

```bash
docker stop [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-t` | `--timeout` | Define o tempo de espera antes de forçar a paragem |
| `-s` | `--signal` | Define o sinal enviado ao container |

### `docker rm`

**Sintaxe**

```bash
docker rm [OPTIONS] CONTAINER [CONTAINER...]
```

| Flag | Forma longa | Utilização |
|---|---|---|
| `-f` | `--force` | Força a remoção de um container em execução |
| `-v` | `--volumes` | Remove volumes anónimos associados ao container |

### Volumes

| Operação | Sintaxe |
|---|---|
| Criar volume | `docker volume create [OPTIONS] [VOLUME]` |
| Listar volumes | `docker volume ls [OPTIONS]` |
| Inspecionar volume | `docker volume inspect [OPTIONS] VOLUME [VOLUME...]` |
| Remover volume | `docker volume rm [OPTIONS] VOLUME [VOLUME...]` |

Flags frequentes em `docker volume ls`:

| Flag | Forma longa | Utilização |
|---|---|---|
| `-q` | `--quiet` | Mostra apenas os nomes/IDs |
| `-f` | `--filter` | Filtra a listagem |

---

## Podman

A sintaxe das operações básicas é semelhante à utilizada com Docker, mas deve ser consultada na documentação do Podman quando forem utilizadas opções específicas.

### `podman run`

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

| Operação | Sintaxe |
|---|---|
| Listar containers | `podman ps [OPTIONS]` |
| Consultar logs | `podman logs [OPTIONS] CONTAINER` |
| Parar container | `podman stop [OPTIONS] CONTAINER [CONTAINER...]` |
| Remover container | `podman rm [OPTIONS] CONTAINER [CONTAINER...]` |

---

## `kubectl` — sintaxe geral

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

**Sintaxe**

```bash
kubectl apply -f <ficheiro|diretório|URL> [FLAGS]
```

Flags úteis:

| Flag | Utilização |
|---|---|
| `-f` / `--filename` | Indica o ficheiro, diretório ou URL com a configuração |
| `-n <namespace>` | Define o Namespace da operação quando aplicável |
| `--dry-run=client` | Valida/processa localmente sem persistir a alteração no cluster |

Exemplo:

```bash
kubectl apply -f manifests/pod-demo.yaml
```

## `kubectl describe`

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

| Operação | Sintaxe |
|---|---|
| Criar | `kubectl create namespace <nome>` |
| Listar | `kubectl get namespaces` |
| Detalhar | `kubectl describe namespace <nome>` |
| Remover | `kubectl delete namespace <nome>` |

## Cluster e contextos

| Operação | Sintaxe |
|---|---|
| Informação do cluster | `kubectl cluster-info` |
| Listar nodes | `kubectl get nodes [FLAGS]` |
| Contexto atual | `kubectl config current-context` |
| Listar contextos | `kubectl config get-contexts [<nome>]` |
| Alterar contexto | `kubectl config use-context <contexto>` |

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
