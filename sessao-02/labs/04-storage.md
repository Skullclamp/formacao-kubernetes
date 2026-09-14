# Lab 4 — Storage Docker

**Sessão:** 2  
**Duração prevista:** 30 minutos  
**Nível:** intermédio  
**Objetivo:** distinguir filesystem gravável do container, bind mounts e named volumes, e provar a persistência sem criar falsos positivos.

A mensagem central é:

```text
Ciclo de vida do container
        ≠
Ciclo de vida dos dados
```

---

# CP1 — Provar que o filesystem do container acompanha o container

## Objetivo

Criar um ficheiro apenas na camada gravável de um container e observar o que acontece quando esse container é removido.

## O que estamos a fazer e porquê

Antes de introduzir persistência, precisamos de observar o comportamento que queremos evitar para dados importantes: guardar informação exclusivamente no filesystem de uma instância descartável.

```bash
docker run -it \
  --name fs-demo \
  busybox:stable \
  sh
```

### Flags e argumentos

- `-i` mantém stdin aberto;
- `-t` cria um terminal interativo;
- `--name fs-demo` atribui um nome ao container;
- `busybox:stable` é a imagem usada para o exercício;
- `sh` é o processo iniciado dentro do container.

Dentro do container:

```sh
echo "dados dentro do container" > /dados.txt
cat /dados.txt
exit
```

### O que observar

O ficheiro existe enquanto o objeto `fs-demo` existe. Sair da shell não remove automaticamente o container.

Confirmar:

```bash
docker ps -a --filter 'name=fs-demo'
```

Remover a instância:

```bash
docker rm fs-demo
```

Criar **outro** container a partir da mesma imagem e tentar ler o ficheiro:

```bash
docker run --rm \
  busybox:stable \
  sh -c 'test -f /dados.txt && cat /dados.txt || echo "dados.txt não existe neste novo container"'
```

### Porque usamos `--rm`?

O segundo container existe apenas para a verificação. `--rm` pede ao Docker que o elimine automaticamente quando o comando terminar.

### CHECKPOINT CP1

```text
ficheiro existiu em fs-demo
fs-demo foi removido
novo container não herdou /dados.txt
imagem busybox continua disponível
```

**Evidência:** guardar a mensagem que confirma a ausência de `/dados.txt` no novo container.

---

# CP2 — Bind mount: usar diretamente uma diretoria do host

## Objetivo

Disponibilizar ao Nginx conteúdo que permanece no host e observar que uma alteração no host é imediatamente visível no container.

## O que estamos a fazer e porquê

Um bind mount liga um caminho concreto do host a um caminho dentro do container. É útil quando queremos expor diretamente ficheiros do host, por exemplo código em desenvolvimento ou configuração controlada externamente.

Preparar o host:

```bash
mkdir -p "$HOME/lab-bind"
echo "Conteúdo vindo do HOST" > "$HOME/lab-bind/index.html"
```

Executar Nginx:

```bash
docker run -d \
  --name bind-web \
  -p 8080:80 \
  -v "$HOME/lab-bind:/usr/share/nginx/html:ro" \
  nginx:alpine
```

### Flags e sintaxe

| Elemento | Significado |
|---|---|
| `-d` | executa em background |
| `--name bind-web` | nome do container |
| `-p 8080:80` | publica `HOST:CONTAINER` |
| `-v HOST:CONTAINER:ro` | monta o caminho do host no caminho indicado dentro do container |
| `:ro` | monta em modo *read-only* para o container |

Neste caso:

```text
$HOME/lab-bind
       ↓ bind mount
/usr/share/nginx/html
       ↓
Nginx serve index.html
```

Validar:

```bash
curl http://localhost:8080/
```

Alterar **no host**:

```bash
echo "Alteração efetuada no HOST" > "$HOME/lab-bind/index.html"
curl http://localhost:8080/
```

### O que observar

Não reconstruímos imagem nem recriámos container. O conteúdo mudou porque Nginx está a ler diretamente a diretoria montada do host.

Confirmar o mount:

```bash
docker inspect bind-web \
  --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}} RW={{.RW}}{{"\n"}}{{end}}'
```

Esperado: tipo `bind` e `RW=false`, devido a `:ro`.

Remover apenas o container:

```bash
docker rm -f bind-web
cat "$HOME/lab-bind/index.html"
```

O ficheiro permanece porque pertence ao host, não ao container.

### CHECKPOINT CP2

```text
bind mount confirmado
conteúdo alterado no host ficou visível no container
container removido
ficheiro do host permaneceu
```

---

# CP3 — Named volume: dados geridos pelo Docker

## Objetivo

Criar um volume Docker, escrever dados através de um container temporário e lê-los através de outro container.

## O que estamos a fazer e porquê

Num named volume, o operador referencia o armazenamento por um **nome lógico**. O Docker gere a localização física no host. Isto desacopla os dados da identidade de um container concreto.

Criar e inspecionar:

```bash
docker volume create dados-lab
docker volume inspect dados-lab
```

### Explicação

- `docker volume create dados-lab` cria um volume gerido pelo Docker;
- `docker volume inspect` mostra driver, mountpoint e metadata;
- saber o `Mountpoint` é útil para compreender onde os dados existem, mas a aplicação deve usar o nome lógico `dados-lab` em vez de depender diretamente desse caminho interno do Docker.

Escrever dados:

```bash
docker run --rm \
  -v dados-lab:/dados \
  busybox:stable \
  sh -c 'echo "persistente" > /dados/teste.txt'
```

### Flags e sintaxe

- `--rm` elimina o container de escrita quando termina;
- `-v dados-lab:/dados` monta o **named volume** no caminho `/dados` do container;
- `sh -c '...'` permite executar a expressão de shell indicada.

Confirmar que o container temporário já desapareceu:

```bash
docker ps -a --filter 'ancestor=busybox:stable'
```

Ler com **outra instância**:

```bash
docker run --rm \
  -v dados-lab:/dados \
  busybox:stable \
  cat /dados/teste.txt
```

Esperado:

```text
persistente
```

### Porque esta prova é importante?

O segundo container não recria o ficheiro. Apenas o lê. Assim evitamos um falso positivo e demonstramos que a informação está realmente no volume.

### CHECKPOINT CP3

```text
container que escreveu já não existe
dados-lab continua a existir
novo container lê o mesmo ficheiro
```

**Evidência:** guardar `docker volume inspect dados-lab` e o valor lido por outro container.

---

# CP4 — Comparar os três mecanismos

Preencha primeiro sem consultar as respostas e depois valide:

| Tipo | Gerido principalmente por | Ciclo de vida | Caso típico |
|---|---|---|---|
| Filesystem do container | Docker, associado à instância | acompanha o container | dados temporários/cache descartável |
| Bind mount | operador/sistema de ficheiros do host | independente do container | código/configuração/ficheiros que devem estar num caminho explícito do host |
| Named volume | Docker | independente do container | dados persistentes de serviços como bases de dados em cenários Docker |

### Relação a reter

```text
Container removido
    ├── filesystem próprio → desaparece com a instância
    ├── bind mount         → ficheiros continuam no host
    └── named volume       → volume continua enquanto não for removido
```

> Persistência não é sinónimo de backup. Um volume pode sobreviver à recriação do container e ainda assim ser perdido por eliminação do volume, avaria do host ou corrupção dos dados.

---

# CP5 — Limpeza consciente

Antes de remover, confirme o que existe:

```bash
docker volume ls
test -f "$HOME/lab-bind/index.html" && echo 'OK: ficheiro bind ainda existe'
```

Remover explicitamente os dados de laboratório:

```bash
docker volume rm dados-lab
rm -rf "$HOME/lab-bind"
```

### O que estamos a fazer

Ao contrário de remover containers, aqui estamos deliberadamente a eliminar os objetos que **mantinham os dados**.

Confirmar:

```bash
docker volume inspect dados-lab 2>&1 || true
test ! -e "$HOME/lab-bind" && echo 'OK: diretoria de bind removida'
```

### Regra de evidência deste laboratório

O laboratório fica concluído quando o formando consegue apresentar e explicar:

```text
filesystem efémero demonstrado
+
bind mount read-only observado
+
alteração no host refletida no container
+
named volume escrito por um container e lido por outro
+
container removido ≠ dados necessariamente removidos
+
persistência ≠ backup
```

Na etapa Compose da sessão, PostgreSQL utilizará um named volume para preservar a base de dados quando o container for recriado.
