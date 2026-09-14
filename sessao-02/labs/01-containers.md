# Lab 1 — Imagens, Containers e Ciclo de Vida

**Sessão:** 2  
**Duração prevista:** 30 minutos  
**Nível:** intermédio  
**Objetivo:** operar imagens e containers, compreender o ciclo de vida e interpretar a publicação de portas.

Este laboratório segue o mesmo princípio pedagógico usado na Sessão 4: **não basta executar o comando**. Em cada etapa deve ser possível explicar o que está a ser feito, porquê, que flags são utilizadas, que resultado se espera e que evidência prova o resultado.

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
CHECKPOINT
   ↓
EVIDÊNCIA
```

> Não avance para a etapa seguinte enquanto não conseguir explicar o checkpoint atual.

---

# CP1 — Validar o ambiente Docker

## Objetivo

Confirmar que o Docker Client consegue comunicar com o Docker Engine e conhecer o estado inicial das imagens locais.

## O que estamos a fazer e porquê

Antes de criar containers precisamos de distinguir um problema do próprio ambiente Docker de um problema introduzido pelos exercícios seguintes.

```bash
docker version
docker info
docker images
```

### Explicação dos comandos

- `docker version` mostra as versões do **Client** e do **Server**. Se a secção Server não estiver disponível, o cliente não está a comunicar corretamente com o daemon;
- `docker info` apresenta informação operacional do Engine, incluindo runtime, storage driver, número de containers e imagens;
- `docker images` lista as imagens existentes localmente. É equivalente a `docker image ls`.

### O que observar

Responda:

1. Qual é a versão do Docker Client?
2. Qual é a versão do Docker Server?
3. Quantas imagens existem localmente?
4. Qual é a diferença entre uma imagem e um container?

### CHECKPOINT CP1

```text
Docker Client responde
Docker Server responde
inventário inicial de imagens conhecido
```

**Evidência:** guardar o output resumido de `docker version` e `docker images`.

---

# CP2 — Obter e identificar uma imagem

## Objetivo

Obter explicitamente uma imagem a partir de um registry e identificar os elementos que a referenciam.

## O que estamos a fazer e porquê

`docker run` pode descarregar automaticamente uma imagem que não exista localmente. Neste exercício usamos primeiro `docker pull` para separar pedagogicamente **obter a imagem** de **criar o container**.

```bash
docker pull nginx:alpine
docker images nginx
```

### Explicação

- `docker pull` obtém a imagem a partir do registry configurado; neste caso, por omissão, Docker Hub;
- `nginx` é o nome/repository da imagem;
- `alpine` é a tag utilizada para escolher uma variante da imagem;
- `docker images nginx` limita a listagem às imagens com esse nome.

### O que observar

Identifique:

```text
REPOSITORY
TAG
IMAGE ID
SIZE
```

A tag é uma referência legível. Não deve ser confundida com a identidade imutável do conteúdo da imagem, tema aprofundado na Sessão 3.

### CHECKPOINT CP2

```text
nginx:alpine existe localmente
repository e tag identificados
imagem ainda não implica container em execução
```

**Evidência:** guardar a linha de `docker images nginx` correspondente a `nginx:alpine`.

---

# CP3 — Criar um container e publicar uma porta

## Objetivo

Criar um container Nginx em background e disponibilizar o serviço HTTP através da porta `8080` do host.

## O que estamos a fazer e porquê

O processo Nginx escuta na porta `80` **dentro do container**. Para aceder a esse serviço a partir do host publicamos essa porta numa porta do host.

```bash
docker run -d \
  --name web-demo \
  -p 8080:80 \
  nginx:alpine
```

### Flags e argumentos

| Elemento | Significado |
|---|---|
| `docker run` | cria um novo container a partir de uma imagem e inicia-o |
| `-d` | executa em *detached mode*, deixando o container em background |
| `--name web-demo` | atribui um nome estável ao container para facilitar comandos posteriores |
| `-p 8080:80` | publica a porta `80` do container na porta `8080` do host |
| `nginx:alpine` | imagem usada para criar o container |

A leitura correta de `-p` é:

```text
HOST:CONTAINER
8080:80
```

Validar:

```bash
docker ps
curl http://localhost:8080
```

### O que observar

Em `docker ps`, a coluna `PORTS` deve apresentar uma publicação equivalente a:

```text
0.0.0.0:8080->80/tcp
```

O `curl` deve devolver conteúdo HTML do Nginx.

Se o container estiver `Up` mas o pedido falhar, não recrie de imediato. Confirme primeiro:

```bash
docker port web-demo
docker logs web-demo
```

### CHECKPOINT CP3

```text
container web-demo em execução
porta interna 80 publicada no host em 8080
pedido HTTP devolve resposta
```

**Evidência:** guardar `docker ps` e o resultado do `curl`.

---

# CP4 — Observar o ciclo de vida

## Objetivo

Distinguir parar, iniciar, reiniciar e remover um container.

## O que estamos a fazer e porquê

Um container parado continua a existir. Remover um container é uma operação diferente de o parar. Esta distinção será importante quando trabalharmos persistência e troubleshooting.

Parar:

```bash
docker stop web-demo
docker ps
docker ps -a
```

### Explicação

- `docker stop web-demo` pede ao processo principal do container para terminar de forma controlada;
- `docker ps` mostra apenas containers em execução;
- `docker ps -a` inclui também containers parados.

Voltar a iniciar o **mesmo** container:

```bash
docker start web-demo
curl http://localhost:8080
```

Reiniciar:

```bash
docker restart web-demo
```

`restart` efetua, de forma encadeada, uma paragem e novo arranque do mesmo container.

Parar e remover:

```bash
docker stop web-demo
docker rm web-demo
docker ps -a
docker images nginx
```

### O que observar

- depois de `stop`, o container continua visível em `docker ps -a`;
- depois de `start`, o mesmo nome volta ao estado `Up`;
- depois de `rm`, o container deixa de existir;
- a imagem `nginx:alpine` continua disponível.

### CHECKPOINT CP4

O formando deve conseguir explicar:

```text
stop    = parar o processo do container, mantendo o objeto
start   = iniciar um container já existente
restart = parar e iniciar novamente o mesmo container
rm      = remover o objeto container
```

**Evidência:** guardar a comparação entre `docker ps -a` antes e depois de `docker rm`.

---

# CP5 — Dois containers a partir da mesma imagem

## Objetivo

Provar que a mesma imagem pode originar várias instâncias independentes e que cada publicação necessita de uma porta do host disponível.

Criar:

```bash
docker run -d --name web-a -p 8081:80 nginx:alpine
docker run -d --name web-b -p 8082:80 nginx:alpine
```

Validar:

```bash
docker ps --filter 'name=web-' \
curl http://localhost:8081
curl http://localhost:8082
```

### Teste negativo — conflito de porta

Tente criar um terceiro container usando uma porta do host já ocupada:

```bash
docker run -d --name web-conflito -p 8081:80 nginx:alpine
```

### O que observar

O Docker não consegue publicar `8081` novamente enquanto essa porta já estiver associada a outro container. A falha não está na porta `80` interna do Nginx; está na tentativa de reutilizar a mesma porta do **host**.

Confirmar o estado:

```bash
docker ps -a --filter 'name=web-conflito'
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Limpar:

```bash
docker rm -f web-a web-b web-conflito 2>/dev/null || true
```

- `-f` força a remoção de containers ainda em execução;
- `2>/dev/null` oculta apenas mensagens de erro enviadas para stderr durante a limpeza;
- `|| true` permite que a limpeza continue mesmo se algum dos nomes já não existir.

### CHECKPOINT CP5 — conclusão

```text
uma imagem pode criar múltiplos containers
cada container tem o seu próprio ciclo de vida
porta interna ≠ porta publicada no host
duas publicações não podem ocupar simultaneamente a mesma porta/IP do host
```

**Evidência:** guardar a listagem dos dois containers com `8081->80` e `8082->80`, e explicar a causa do conflito controlado.
