# Laboratório 1 — Fundamentos de Containers

**Sessão:** 1  
**Módulo:** M1 — Fundamentos de Containers  
**Nível:** intermédio  
**Foco:** compreender imagem, container, ciclo de vida, logs e persistência básica

Este laboratório aplica o mesmo padrão pedagógico usado na Sessão 4. O objetivo não é copiar comandos: em cada checkpoint deve ser possível explicar **o que está a ser feito, porque é necessário, que conceitos estão envolvidos, o significado dos comandos e flags relevantes e que evidência prova o resultado**.

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
CONCEITOS ABORDADOS
   ↓
COMANDOS
   ↓
FLAGS / ARGUMENTOS IMPORTANTES
   ↓
OUTPUT / ESTADO ESPERADO
   ↓
O QUE OBSERVAR
   ↓
CHECKPOINT — NÃO AVANÇAR SEM VALIDAR
   ↓
EVIDÊNCIA
```

> Não avançar para o checkpoint seguinte enquanto o resultado atual não estiver compreendido e validado.

---

# CP1 — Validar o ambiente Docker

## Objetivo

Confirmar que o Docker Client consegue comunicar com o Docker Engine antes de criar recursos.

## O que estamos a fazer e porquê

Antes de executar o primeiro container estabelecemos uma baseline mínima. Se o Docker Engine não estiver acessível, qualquer falha posterior poderá ser atribuída incorretamente ao container ou à imagem.

## Conceitos abordados neste CP

- Docker Client;
- Docker Engine;
- imagem local;
- diferença entre ferramenta de gestão e objeto executado.

## Comandos

```bash
docker version
docker images
```

## Como interpretar os comandos e flags

- `docker version` mostra as versões do **Client** e do **Server**. A secção Server confirma comunicação com o Docker Engine;
- `docker images` lista as imagens disponíveis localmente. É equivalente a `docker image ls`.

## O que observar

Confirmar que:

```text
Docker Client responde
Docker Server responde
é possível consultar o inventário de imagens
```

### CHECKPOINT CP1

O ambiente Docker está operacional e é possível distinguir **Docker Engine**, **imagem** e **container**.

**Evidência:** guardar o output resumido de `docker version` e `docker images`.

---

# CP2 — Criar e executar um container

## Objetivo

Criar uma instância de container a partir de uma imagem e executá-la em background.

## O que estamos a fazer e porquê

Uma imagem é o artefacto utilizado como base para criar containers. `docker run` cria uma nova instância a partir da imagem indicada e inicia o respetivo processo principal.

## Conceitos abordados neste CP

- imagem vs. container;
- criação de uma instância;
- processo principal do container;
- execução em foreground vs. background;
- nome operacional do container.

## Comando

```bash
docker run --name web-demo -d nginx
```

## Como interpretar o comando e as flags

| Elemento | Significado |
|---|---|
| `docker run` | cria um novo container a partir de uma imagem e inicia-o |
| `--name web-demo` | atribui o nome estável `web-demo` ao container |
| `-d` | executa em *detached mode*, deixando o container em background |
| `nginx` | imagem utilizada para criar a instância |

Se a imagem `nginx` ainda não existir localmente, o Docker tentará obtê-la a partir do registry configurado antes de criar o container.

## Validar

```bash
docker ps
```

- `docker ps` apresenta, por omissão, apenas containers em execução.

## O que observar

Localizar `web-demo` e confirmar que o estado indica execução ativa.

### CHECKPOINT CP2

```text
imagem usada como origem
container web-demo criado
processo principal em execução
container visível em docker ps
```

**Evidência:** guardar a linha de `docker ps` correspondente a `web-demo`.

---

# CP3 — Consultar logs e relacioná-los com o processo

## Objetivo

Consultar a saída produzida pela aplicação executada dentro do container.

## O que estamos a fazer e porquê

Os logs são uma das primeiras fontes de evidência quando queremos perceber o comportamento de uma aplicação containerizada. Nesta fase interessa perceber que `docker logs` consulta a saída capturada do processo do container; não abre uma shell dentro dele.

## Conceitos abordados neste CP

- stdout e stderr;
- observabilidade básica;
- diferença entre consultar logs e executar comandos dentro do container.

## Comando

```bash
docker logs web-demo
```

## Como interpretar o comando

- `docker logs` consulta os logs capturados pelo Docker para o container indicado;
- `web-demo` identifica o objeto alvo.

Opcionalmente, para acompanhar novos registos em tempo real:

```bash
docker logs -f web-demo
```

- `-f` significa *follow*: mantém o terminal ligado ao fluxo de novos logs;
- `Ctrl+C` termina apenas o acompanhamento dos logs, não o container.

### CHECKPOINT CP3

O formando consegue explicar onde os logs observados têm origem e confirmar que consultar logs não altera o estado do container.

**Evidência:** guardar uma parte identificável do output de `docker logs web-demo`.

---

# CP4 — Observar o ciclo de vida do container

## Objetivo

Distinguir parar, listar e remover um container.

## O que estamos a fazer e porquê

Parar um container não é o mesmo que removê-lo. Um container parado continua a existir como objeto Docker e pode ser consultado através de `docker ps -a`.

## Conceitos abordados neste CP

- estado `running` vs. `stopped/exited`;
- ciclo de vida do container;
- diferença entre processo parado e objeto removido;
- independência entre imagem e container.

## Parar

```bash
docker stop web-demo
```

Consultar:

```bash
docker ps
docker ps -a
```

## Como interpretar os comandos e flags

- `docker stop web-demo` pede uma paragem controlada do processo principal;
- `docker ps` mostra containers em execução;
- `docker ps -a` usa `-a` de *all* e inclui também containers parados.

## Remover

```bash
docker rm web-demo
```

Validar:

```bash
docker ps -a
docker images nginx
```

## O que observar

```text
após stop → container continua a existir
após rm   → objeto container desaparece
a imagem  → continua disponível localmente
```

### CHECKPOINT CP4

O formando deve conseguir explicar:

```text
stop ≠ rm
container ≠ imagem
remover o container ≠ remover a imagem
```

**Evidência:** guardar a comparação de `docker ps -a` antes e depois de `docker rm`.

---

# CP5 — Criar um volume e provar persistência

## Objetivo

Separar o ciclo de vida dos dados do ciclo de vida do container.

## O que estamos a fazer e porquê

Os containers devem poder ser substituídos sem que dados importantes dependam exclusivamente da camada gravável da instância. Vamos criar um **named volume**, escrever um ficheiro através de um container temporário e lê-lo através de outro container.

## Conceitos abordados neste CP

- armazenamento efémero do container;
- named volume;
- mount;
- persistência além do ciclo de vida de uma instância;
- diferença entre persistência e o próprio container.

## Criar o volume

```bash
docker volume create dados-demo
docker volume ls
```

- `docker volume create dados-demo` cria um volume gerido pelo Docker;
- `docker volume ls` lista os volumes disponíveis.

## Escrever dados através de um container temporário

```bash
docker run --rm \
  -v dados-demo:/dados \
  alpine \
  sh -c 'echo "dados persistentes" > /dados/prova.txt'
```

## Como interpretar o comando e as flags

| Elemento | Significado |
|---|---|
| `--rm` | remove automaticamente o container quando o processo termina |
| `-v dados-demo:/dados` | monta o volume `dados-demo` em `/dados` dentro do container |
| `alpine` | imagem leve utilizada para executar o teste |
| `sh -c '...'` | pede à shell que execute a instrução indicada |

O container termina e é removido por causa de `--rm`, mas o volume continua a existir.

## Ler os mesmos dados através de outro container

```bash
docker run --rm \
  -v dados-demo:/dados \
  alpine \
  cat /dados/prova.txt
```

## O que observar

O segundo container deve apresentar:

```text
dados persistentes
```

Isto demonstra que o ficheiro está no volume e não depende da existência do primeiro container temporário.

Consultar também:

```bash
docker volume inspect dados-demo
```

- `inspect` apresenta a configuração detalhada do volume em formato JSON.

### CHECKPOINT CP5

```text
container temporário A terminou e foi removido
volume dados-demo permaneceu
container temporário B leu o mesmo ficheiro
ciclo de vida dos dados ≠ ciclo de vida do container
```

**Evidência:** guardar o output `dados persistentes` e a identificação do volume através de `docker volume ls`.

---

# CP6 — Limpeza e síntese

## Objetivo

Remover os recursos criados para que o ambiente fique previsível para o laboratório seguinte.

## Comando

```bash
docker volume rm dados-demo
```

Validar:

```bash
docker volume ls
```

## Conceitos abordados neste CP

- limpeza controlada de recursos;
- confirmação pós-operação;
- diferença entre executar um comando e provar o resultado.

### CHECKPOINT CP6

O volume `dados-demo` já não aparece na listagem.

**Evidência:** guardar a listagem final ou registar que o volume foi removido com sucesso.

---

# Questões de consolidação

1. Qual é a diferença entre a imagem `nginx` e o container `web-demo`?
2. Porque é que `docker stop` e `docker rm` representam operações diferentes?
3. O que acrescenta `-a` a `docker ps`?
4. O que significa `--rm` em `docker run`?
5. Na expressão `-v dados-demo:/dados`, o que representa cada lado de `:`?
6. Que evidência prova que os dados sobreviveram à remoção do primeiro container temporário?

# Regra de evidência da Sessão 1 — Módulo 1

```text
Docker operacional
+
container criado e observado
+
logs consultados
+
ciclo de vida compreendido
+
volume criado
+
persistência comprovada com duas instâncias diferentes
+
limpeza validada
```
