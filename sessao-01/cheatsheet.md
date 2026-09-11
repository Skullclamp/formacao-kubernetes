# Cheatsheet — Sessão 1

Referência rápida à **finalidade**, sintaxe, opções mais utilizadas, exemplos e estruturas trabalhadas na sessão.

> **Convenções:** valores entre `< >` devem ser substituídos. Elementos entre `[ ]` são opcionais. Termos em maiúsculas como `IMAGE`, `CONTAINER`, `COMMAND` ou `TYPE` representam argumentos que devem ser fornecidos ao comando.

## Docker

### `docker run`

**Para que serve:** cria um novo container a partir de uma imagem e inicia a sua execução. Se a imagem não existir localmente, Docker tenta obtê-la a partir de um registry.

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

**Exemplo combinado:**

```bash
docker run --name web-demo -d -p 8080:80 nginx
```

### `docker ps`

**Para que serve:** lista containers. Sem opções mostra apenas os containers em execução; com `-a` inclui também os containers parados.

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

**Para que serve:** consulta a saída de logs produzida por um container. É útil para observar o arranque de uma aplicação, acompanhar a execução e diagnosticar erros.

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

**Flags frequentes em `docker volume ls`:**

| Flag | Forma longa | Utilização | Exemplo |
|---|---|---|---|
| `-q` | `--quiet` | Mostra apenas os nomes dos volumes | `docker volume ls -q` |
| `-f` | `--filter` | Filtra a listagem | `docker volume ls -f dangling=true` |

---

## Podman

A sintaxe das operações básicas é semelhante à utilizada com Docker, mas as opções devem ser confirmadas na documentação do Podman quando forem utilizados comportamentos específicos.

### `podman run`

**Para que serve:** cria e executa um novo container a partir de uma imagem utilizando Podman. Se a imagem não estiver disponível localmente, Podman pode obtê-la de um registry antes da execução.

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
| `podman ps` | `podman ps [OPTIONS]` | Lista containers; por omissão apresenta os que estão em execução | `podman ps -a` |
| `podman logs` | `podman logs [OPTIONS] CONTAINER` | Consulta os logs de um container | `podman logs -f web-demo` |
| `podman stop` | `podman stop [OPTIONS] CONTAINER [CONTAINER...]` | Para um ou mais containers | `podman stop web-demo` |
| `podman rm` | `podman rm [OPTIONS] CONTAINER [CONTAINER...]` | Remove um ou mais containers | `podman rm web-demo` |

---

## `kubectl` — sintaxe geral

**Para que serve:** `kubectl` é a ferramenta de linha de comandos utilizada para comunicar com a API Kubernetes e consultar ou gerir recursos do cluster.

```bash
kubectl [COMMAND] [TYPE] [NAME] [FLAGS]
```

`TYPE` identifica o tipo de recurso Kubernetes sobre o qual o comando vai atuar. Pode ser utilizado no singular ou no plural.

| `TYPE` | O que representa |
|---|---|
| `pod` / `pods` | Unidade de execução |
| `namespace` / `namespaces` | Agrupamento lógico |
| `node` / `nodes` | Máquina do cluster |

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

**Flags muito utilizadas:**

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

**Para que serve:** aplica configuração declarativa a recursos a partir de ficheiros, diretórios ou entrada standard. Pode criar o recurso caso ainda não exista e aplicar alterações a recursos já existentes.

**Sintaxe**

```bash
kubectl apply (-f FILENAME | -k DIRECTORY)
```

**Opções úteis:**

| Flag | Utilização | Exemplo |
|---|---|---|
| `-f` / `--filename` | Indica um ficheiro, diretório, URL ou `-` para entrada standard | `kubectl apply -f pod-demo.yaml` |
| `-k` / `--kustomize` | Processa um diretório com `kustomization.yaml` | `kubectl apply -k ./overlays/dev` |
| `-n <namespace>` | Define o Namespace da operação quando aplicável | `kubectl apply -f pod-demo.yaml -n formacao` |
| `--dry-run=client` | Processa localmente sem persistir a alteração no cluster | `kubectl apply -f pod-demo.yaml --dry-run=client` |

## `kubectl describe`

**Para que serve:** apresenta informação detalhada sobre um recurso, incluindo estado, configuração e, quando disponíveis, eventos e recursos relacionados.

**Sintaxe simplificada**

```bash
kubectl describe TYPE [NAME] [FLAGS]
```

**Exemplos:**

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
| `metadata.namespace` | Define o Namespace do recurso, quando aplicável | `namespace: formacao` |
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

**Label num manifest:**

```yaml
metadata:
  labels:
    app: web
    environment: formacao
```

**Selector na linha de comandos:**

```bash
kubectl get pods -l <chave>=<valor>
```

**Exemplo:**

```bash
kubectl get pods -n formacao -l app=web
```

---

## Verificações rápidas

Esta secção reúne comandos úteis para confirmar rapidamente o estado do ambiente antes de avançar para diagnóstico mais detalhado.

### Docker

| Comando | O que verifica | O que procurar |
|---|---|---|
| `docker ps -a` | Estado de todos os containers, incluindo os que já terminaram | Nome do container, imagem utilizada e estado (`Up`, `Exited`, etc.) |
| `docker logs --tail 50 <container>` | Últimas 50 linhas de logs | Mensagens de erro, falhas de arranque ou informação recente da aplicação |
| `docker logs -f <container>` | Logs em tempo real | Novas mensagens produzidas enquanto a aplicação executa |
| `docker volume ls` | Volumes existentes no host Docker | Confirmar que o volume esperado foi criado e está disponível |

### Kubernetes

| Comando | O que verifica | O que procurar |
|---|---|---|
| `kubectl get nodes -o wide` | Estado e informação adicional dos nodes | Estado `Ready`, versão, IP e outras informações do node |
| `kubectl config current-context` | Contexto Kubernetes atualmente selecionado | Confirmar que está a trabalhar no cluster/contexto pretendido |
| `kubectl get pods -n <namespace> -o wide` | Estado dos Pods num Namespace | `STATUS`, número de reinícios, IP e node onde o Pod está executado |
| `kubectl describe pod <pod> -n <namespace>` | Informação detalhada de um Pod | Estado dos containers, condições e eventos relevantes |

---

## Referências oficiais

- Docker CLI: https://docs.docker.com/reference/cli/docker/
- Docker `run`: https://docs.docker.com/reference/cli/docker/container/run/
- Docker volumes: https://docs.docker.com/reference/cli/docker/volume/
- Podman `run`: https://docs.podman.io/en/latest/markdown/podman-run.1.html
- Referência `kubectl`: https://kubernetes.io/docs/reference/kubectl/
- `kubectl apply`: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/
- Quick Reference oficial de `kubectl`: https://kubernetes.io/docs/reference/kubectl/quick-reference/
