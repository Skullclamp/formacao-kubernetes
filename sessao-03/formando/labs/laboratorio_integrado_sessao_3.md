# Laboratório Integrado — Sessão 3
## Docker II: da VM Ubuntu Server limpa ao deployment, falha e rollback

**Duração de referência:** 4 horas  
**Nível:** intermédio  
**Cenário:** Symfony Demo v3.1.0 + PHP 8.4 + Apache + PostgreSQL 16  
**Objetivo:** executar um único percurso técnico coerente desde uma VM Ubuntu Server limpa até à construção, análise, publicação, deployment, atualização, diagnóstico de falha e rollback de uma imagem Docker.

---

# Como utilizar este laboratório

Este laboratório não é uma lista de comandos para copiar sem compreender. Em cada etapa siga a mesma sequência:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

A regra pedagógica da sessão é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Os scripts existentes em `formando/scripts/` só são utilizados depois de o processo manual correspondente ter sido compreendido.

---

# 0. Percurso completo

```text
Ubuntu Server limpo
      ↓
Docker Engine + containerd + Buildx + Compose
      ↓
Git + recursos da formação
      ↓
Source Symfony
      ↓
Dockerfile inicial
      ↓
Build
      ↓
Layers / Cache / Multi-stage
      ↓
Hardening / Secrets
      ↓
HEALTHCHECK / Recursos / Logging
      ↓
Trivy
      ↓
Tag / Digest
      ↓
Registry / GHCR
      ↓
Compose produção single-host
      ↓
Deploy 1.0.0
      ↓
Dados + Backup
      ↓
Update 1.1.0
      ↓
Falha 1.2.0-rc1
      ↓
Diagnóstico
      ↓
Rollback 1.1.0
```

---

# 1. Preparar uma VM Ubuntu Server limpa

## 1.1. Atualizar o catálogo de pacotes

```bash
sudo apt update
```

### O que faz

Atualiza o índice local dos pacotes disponíveis nos repositórios configurados. **Não instala atualizações por si só.**

```text
apt update  → atualiza o catálogo
apt upgrade → atualiza pacotes já instalados
```

### Elementos do comando

- `sudo` — executa o comando com privilégios administrativos;
- `apt` — gestor de pacotes de alto nível do Ubuntu;
- `update` — atualiza a informação dos repositórios.

Depois:

```bash
sudo apt upgrade -y
```

- `upgrade` — atualiza os pacotes instalados para versões disponíveis;
- `-y` — responde automaticamente `yes` às confirmações.

---

## 1.2. Instalar ferramentas base

```bash
sudo apt install -y \
  ca-certificates \
  curl \
  git
```

### Para que serve cada pacote

| Pacote | Função |
|---|---|
| `ca-certificates` | permite validar certificados TLS/HTTPS |
| `curl` | efetua pedidos HTTP/HTTPS e downloads |
| `git` | obtém e atualiza os materiais da formação |

A barra `\` no final da linha indica ao shell que o comando continua na linha seguinte.

---

## 1.3. Remover eventuais pacotes incompatíveis

```bash
sudo apt remove -y \
  docker.io \
  docker-compose \
  docker-compose-v2 \
  docker-doc \
  docker-buildx \
  podman-docker \
  containerd \
  runc
```

Numa VM limpa é normal que vários destes pacotes não estejam instalados. O objetivo é evitar conflitos com pacotes que possam ter sido instalados a partir dos repositórios Ubuntu em vez do repositório oficial Docker.

---

## 1.4. Preparar o diretório de chaves APT

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

### Flags

- `install` — neste contexto cria/prepara um diretório com permissões definidas;
- `-m 0755` — define as permissões do diretório;
- `-d` — cria um diretório em vez de copiar um ficheiro.

---

## 1.5. Obter a chave pública oficial da Docker

```bash
sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
```

### Flags do `curl`

| Flag | Significado |
|---|---|
| `-f` | termina com erro quando existe erro HTTP |
| `-s` | modo silencioso |
| `-S` | mostra erros mesmo com `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava o resultado no ficheiro indicado |

A chave permite ao APT verificar a assinatura dos pacotes obtidos do repositório Docker.

Depois:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

- `chmod` — altera permissões;
- `a+r` — concede permissão de leitura a todos os utilizadores.

---

## 1.6. Adicionar o repositório oficial Docker

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

### Conceito — repositório de pacotes

Um repositório APT é uma origem de software que o Ubuntu conhece e na qual pode procurar pacotes.

```text
Ubuntu APT
   ↓
repositório configurado
   ↓
pacotes assinados
   ↓
instalação / atualização
```

### Elementos importantes

- `tee` — recebe texto pela entrada standard e grava-o num ficheiro;
- `<<EOF ... EOF` — *here document*: envia várias linhas ao comando;
- `$(...)` — substituição de comando; executa o conteúdo e insere o resultado;
- `dpkg --print-architecture` — obtém a arquitetura do sistema, por exemplo `amd64`.

Atualizar novamente:

```bash
sudo apt update
```

---

## 1.7. Instalar Docker Engine, CLI, containerd, Buildx e Compose

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

### O que estamos a instalar

```text
Docker CLI
    ↓
Docker Engine
    ↓
containerd
    ↓
runc
    ↓
Kernel Linux
```

- **Docker CLI** — comando `docker` utilizado pelo operador;
- **Docker Engine** — serviço que gere imagens, containers, redes e volumes;
- **containerd** — runtime de alto nível que gere o ciclo de vida dos containers;
- **runc** — runtime OCI de baixo nível que cria o processo isolado;
- **Buildx** — interface avançada de build baseada em BuildKit;
- **Docker Compose plugin** — comando `docker compose` para aplicações multi-container.

### Ponte conceptual para Kubernetes

```text
Docker:
CLI → Engine → containerd → runc → Kernel

Kubernetes:
kubelet → CRI → containerd → runc → Kernel
```

Nesta sessão não aprofundamos a CRI; a ponte serve apenas para perceber que Kubernetes pode usar `containerd` sem depender do Docker Engine.

---

## 1.8. Validar o serviço Docker

```bash
sudo systemctl status docker --no-pager
```

### Flags

- `systemctl` — gere serviços `systemd`;
- `status` — consulta o estado;
- `--no-pager` — apresenta a saída diretamente, sem abrir um paginador interativo.

Se necessário:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

- `start` — inicia o serviço agora;
- `enable` — configura o arranque automático no boot.

---

## 1.9. Executar o primeiro container

```bash
sudo docker run --rm hello-world
```

### Conceito — o que faz `docker run`?

De forma simplificada:

```text
imagem local?
  ↓ não
pull da imagem
  ↓
criar container
  ↓
iniciar processo
  ↓
apresentar output
```

### Flag

- `--rm` — remove automaticamente o container quando o processo termina.

Validar componentes:

```bash
sudo docker version
sudo docker info
sudo docker compose version
sudo docker buildx version
```

---

## 1.10. Permitir Docker sem `sudo`

```bash
sudo usermod -aG docker "$USER"
```

### Flags

- `usermod` — altera propriedades de uma conta local;
- `-a` — *append*, adiciona sem remover os grupos existentes;
- `-G docker` — adiciona aos grupos suplementares indicados;
- `$USER` — variável com o nome do utilizador atual.

Termine a sessão SSH:

```bash
exit
```

Volte a ligar à VM e confirme:

```bash
groups
docker version
docker run --rm hello-world
```

> **Segurança:** pertencer ao grupo `docker` concede privilégios muito elevados sobre o host. Nesta formação é utilizado numa VM de laboratório.

---

# 2. Instalar Trivy para o scan da imagem

Trivy será utilizado mais tarde para analisar vulnerabilidades conhecidas na imagem.

```bash
sudo apt-get install -y wget gnupg
```

Adicionar a chave do repositório Trivy:

```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
```

### Elementos importantes

- `wget -qO -` — obtém o conteúdo e envia-o para stdout;
- `|` — *pipe*: envia a saída do comando anterior para o seguinte;
- `gpg --dearmor` — converte a chave para formato binário compatível;
- `> /dev/null` — descarta a saída normal do `tee`.

Adicionar o repositório:

```bash
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
```

Instalar:

```bash
sudo apt-get update
sudo apt-get install -y trivy
```

Validar:

```bash
trivy --version
```

---

# 3. Obter os recursos da formação

## 3.1. Clonar o repositório

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
```

### Conceito — Git repository

Um repositório Git contém ficheiros versionados e o histórico das respetivas alterações.

```text
GitHub
  ↓ git clone
cópia local na VM
```

Entrar na sessão:

```bash
cd formacao-kubernetes/sessao-03
```

- `cd` — muda a diretoria de trabalho.

Se o repositório já existir:

```bash
cd ~/formacao-kubernetes
git pull
cd sessao-03
```

- `git pull` — obtém alterações remotas e integra-as na cópia local.

Confirmar:

```bash
pwd
ls
```

- `pwd` — mostra a diretoria atual;
- `ls` — lista ficheiros e diretórios.

---

# 4. Preparar o código da Symfony Demo

```bash
./comum/prepare-source.sh
```

### Porque existe este script?

O código da aplicação não é duplicado permanentemente no repositório pedagógico. O script obtém a Symfony Demo `v3.1.0` e aplica o overlay da formação com os endpoints:

```text
/info
/health
/ready
```

Confirmar:

```bash
test -f app/composer.json && echo "OK: source preparado"
```

### Elementos

- `test -f` — testa se existe um ficheiro regular;
- `&&` — só executa o comando seguinte se o anterior tiver sucesso;
- `echo` — escreve uma mensagem.

---

# 5. Construir uma imagem inicial

## 5.1. Conceito — imagem e container

```text
Dockerfile
   ↓ docker build
Imagem
   ↓ docker run
Container
```

- **Imagem** — artefacto reutilizável e versionável;
- **Container** — instância criada a partir de uma imagem.

Abrir o Dockerfile inicial:

```bash
less formando/docker/Dockerfile.inicial
```

- `less` — visualizador paginado de texto; sair com `q`.

Observe as instruções `FROM`, `RUN`, `COPY`, `WORKDIR`, `EXPOSE`, `HEALTHCHECK` e `CMD`.

---

## 5.2. Executar o build

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

### Flags / argumentos

| Elemento | Função |
|---|---|
| `docker build` | constrói uma imagem |
| `-f` | escolhe o Dockerfile |
| `-t` | atribui nome e tag |
| `.` | define a diretoria atual como build context |

### Conceito — build context

O contexto é o conjunto de ficheiros que fica disponível ao builder.

```text
sessao-03/
    ↓ contexto "."
Docker builder
    ↓
COPY pode aceder aos ficheiros desse contexto
```

É por isso que existe `.dockerignore`: para impedir que ficheiros desnecessários, caches, `.git`, logs ou informação local sejam enviados ao build.

Consultar a imagem:

```bash
docker image ls symfony-demo
```

Consultar layers:

```bash
docker history symfony-demo:naive
```

---

# 6. Layers, cache e multi-stage

## 6.1. Construir a versão otimizada

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

### Flag `--build-arg`

Passa um valor para uma instrução `ARG` do Dockerfile durante o build.

```text
--build-arg APP_VERSION=1.0.0
              ↓
ARG APP_VERSION
```

Não deve ser utilizado para transportar secrets.

---

## 6.2. Observar a cache

Faça um novo build:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Procure `CACHED` na saída.

### Porque funciona?

O Dockerfile copia primeiro os ficheiros que descrevem dependências e só depois o restante código. Se `composer.json` e `composer.lock` não mudarem, a instalação das dependências pode reutilizar cache.

```text
composer.json / composer.lock
        ↓
composer install
        ↓ cache reutilizável
código da aplicação
```

---

## 6.3. Conceito — multi-stage

```text
stage build
  ↓
ferramentas + Composer + dependências
  ↓
COPY --from=build
  ↓
stage runtime
  ↓
apenas o necessário para executar
```

O objetivo é reduzir componentes desnecessários no runtime e separar construção de execução.

---

## 6.4. Só agora observar a automação

```bash
sed -n '1,220p' formando/scripts/build.sh
```

- `sed -n` — não imprime automaticamente todas as linhas;
- `'1,220p'` — imprime da linha 1 à 220.

Depois:

```bash
./formando/scripts/build.sh 1.1.0
```

Pergunta obrigatória:

> Que comando manual executado anteriormente está este script a automatizar?

---

# 7. Hardening e secrets

## 7.1. Conceito — hardening

Hardening significa reduzir risco sem destruir funcionalidade necessária. Nesta sessão:

- escolher uma imagem base adequada e de origem conhecida;
- separar ferramentas de build do runtime;
- evitar componentes desnecessários;
- não embutir secrets;
- aplicar privilégios mínimos compatíveis com o runtime;
- limitar recursos;
- não montar o Docker socket sem compreender o privilégio concedido.

---

## 7.2. Demonstrar uma má prática com secret

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Use apenas valores fictícios.

Investigar:

```bash
docker history --no-trunc secret-demo:bad
```

- `--no-trunc` — impede que os campos longos sejam abreviados.

E:

```bash
docker image inspect secret-demo:bad
```

### Conclusão

```text
ARG / ENV
   ≠
mecanismo seguro para esconder secrets
```

---

## 7.3. BuildKit secret

Criar um secret fictício temporário:

```bash
printf 'segredo-falso-lab\n' > /tmp/demo_secret.txt
```

- `printf` — escreve texto formatado;
- `>` — redireciona stdout para um ficheiro.

Build:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=demo_secret,src=/tmp/demo_secret.txt \
  -t secret-demo:buildkit \
  formando/exemplos/secrets
```

### Flag `--secret`

- `id=demo_secret` — identificador usado no Dockerfile;
- `src=/tmp/demo_secret.txt` — ficheiro local disponibilizado temporariamente ao build.

Limpar:

```bash
rm -f /tmp/demo_secret.txt
```

- `rm` — remove;
- `-f` — não pergunta e não falha se o ficheiro já não existir.

---

## 7.4. Compose secret

```bash
cp formando/exemplos/secrets/demo_secret.example.txt \
   formando/exemplos/secrets/demo_secret.txt
```

- `cp` — copia um ficheiro.

Executar:

```bash
docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit
```

- `-f` — escolhe o ficheiro Compose;
- `up` — cria/inicia os serviços;
- `--abort-on-container-exit` — termina o conjunto quando um dos containers termina.

O secret é montado como ficheiro em:

```text
/run/secrets/demo_secret
```

Remover o ficheiro temporário:

```bash
rm -f formando/exemplos/secrets/demo_secret.txt
```

Mensagem a reter:

```text
.env ≠ secret manager
```

---

# 8. Saúde, recursos, restart e logging

## 8.1. Docker HEALTHCHECK

Consultar a definição na imagem:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format '{{json .Config.Healthcheck}}'
```

### Flag `--format`

Permite selecionar e formatar campos do objeto devolvido pelo Docker.

### Conceito

```text
processo iniciado
      ≠
serviço saudável
```

Nesta aplicação:

```text
/health → saúde básica da aplicação
/ready  → prontidão incluindo a dependência da DB
/info   → versão e ambiente
```

> Docker `HEALTHCHECK` não é convertido automaticamente em `livenessProbe` ou `readinessProbe` de Kubernetes.

---

## 8.2. Preparar o Compose de produção

```bash
cp formando/compose/.env.prod.example \
   formando/compose/.env.prod
```

Validar a configuração efetiva:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

### Flags

| Flag | Função |
|---|---|
| `--env-file` | define o ficheiro usado para substituição de variáveis |
| `-f` | adiciona um ficheiro Compose |
| segundo `-f` | adiciona o override posterior |
| `config` | mostra a configuração final resultante |

Os ficheiros posteriores podem complementar/sobrepor configuração dos anteriores.

---

## 8.3. Conceitos de runtime

No override de produção surgem:

```yaml
restart: unless-stopped
mem_limit: 512m
cpus: 1.0
logging:
  driver: local
```

- `restart: unless-stopped` — reinicia automaticamente, exceto após paragem manual explícita;
- `mem_limit` — limita memória;
- `cpus` — limita capacidade de CPU;
- `logging.driver: local` — usa o driver local com gestão de retenção do Docker.

---

# 9. Analisar vulnerabilidades com Trivy

## 9.1. Conceito — vulnerabilidade e scan

Trivy compara componentes conhecidos da imagem com bases de vulnerabilidades publicadas.

Um scan pode encontrar:

- CVEs em pacotes do sistema;
- bibliotecas vulneráveis;
- componentes desatualizados.

Um scan não substitui hardening, atualização, gestão de secrets ou configuração segura.

---

## 9.2. Scan informativo

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

### Flags

- `image` — analisa uma imagem;
- `--scanners vuln` — ativa o scanner de vulnerabilidades;
- `--severity HIGH,CRITICAL` — filtra severidades;
- `--ignore-unfixed` — omite vulnerabilidades para as quais não existe correção conhecida.

> As contagens variam ao longo do tempo. Não existe um número fixo de vulnerabilidades esperado.

Exemplo de quality gate didático:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

- `--exit-code 1` — faz o comando terminar com código 1 quando encontra resultados que correspondem aos filtros.

---

# 10. Tags, digest e registry

## 10.1. Conceito — o que é um registry?

Um **container registry** é um serviço utilizado para armazenar e distribuir imagens de containers.

```text
Git repository
   ↓
guarda código-fonte

Container registry
   ↓
guarda imagens de containers
```

Exemplos: Docker Hub, GitHub Container Registry (GHCR), GitLab Container Registry, Harbor, Amazon ECR, Azure Container Registry e Google Artifact Registry.

Na formação usamos GHCR.

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
│       │          │            │
registry namespace  repositório   tag
```

---

## 10.2. Tag versus digest

Criar uma segunda tag local:

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable
```

`docker tag` não reconstrói a imagem; cria outra referência para o mesmo conteúdo local.

Comparar:

```bash
docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

```text
Tag
  ↓
referência legível e potencialmente mutável

Digest
  ↓
identidade do conteúdo publicado no registry
```

---

## 10.3. Consumir uma imagem pública

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

- `pull` — obtém a imagem do registry para o armazenamento local do Docker.

As versões de referência são:

```text
1.0.0      → deployment inicial
1.1.0      → atualização válida
1.2.0-rc1  → candidata com falha de HEALTHCHECK
```

---

## 10.4. Publicar num namespace pessoal

Definir o destino:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
```

- `export` — cria uma variável de ambiente disponível aos processos filhos.

Autentique-se no GHCR com um método/credencial autorizado para a sua conta. **Nunca coloque tokens no repositório, comandos partilhados, screenshots ou materiais da formação.**

Criar a tag remota:

```bash
docker tag \
  symfony-demo:1.0.0 \
  "$IMAGE_REPO:1.0.0"
```

Publicar:

```bash
docker push "$IMAGE_REPO:1.0.0"
```

- `push` — envia as layers/manifest necessários para o registry.

Consultar RepoDigests:

```bash
docker image inspect "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

### Princípio

```text
BUILD ONCE
   ↓
Imagem / Digest
   ↓
DEV → TEST → PROD
```

Não reconstruímos o artefacto em cada ambiente.

Só agora pode analisar a automação:

```bash
sed -n '1,220p' formando/scripts/push.sh
```

---

# 11. Deployment single-host

## 11.1. Conceito

Docker Compose permite descrever uma aplicação multi-container declarativamente.

```text
compose.yaml
    ↓
app + db + rede + volume
```

No cenário de produção usamos:

```text
compose.yaml
      +
compose.prod.yaml
      +
.env.prod
```

> Compose num único host **não é Alta Disponibilidade** e não substitui Kubernetes.

---

## 11.2. Primeiro arranque manual

Validar novamente:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

Iniciar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

- `up` — cria/inicia os serviços necessários;
- `-d` — *detached mode*, executa em background.

Consultar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

- `ps` — apresenta o estado dos serviços.

Agora abra o wrapper:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
```

A partir deste ponto pode utilizar:

```bash
./formando/scripts/compose-prod.sh ps
```

---

# 12. Validar a aplicação

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

### Flag `-i`

Inclui os headers HTTP na resposta, permitindo observar o status code e metadata HTTP.

Obter o ID do container da aplicação:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

### Elementos

- `$(...)` — executa um comando e guarda o resultado;
- `ps -q app` — devolve apenas o ID do container do serviço `app`;
- `CID=...` — guarda o valor numa variável shell.

Consultar health:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Consultar limites:

```bash
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
```

Observar consumo atual:

```bash
docker stats --no-stream "$CID"
```

- `--no-stream` — recolhe uma amostra e termina em vez de atualizar continuamente.

---

# 13. Dados persistentes e backup

## 13.1. Conceito

```text
Container removido
      ↓
Named volume permanece
      ↓
Dados permanecem
```

Mas:

```text
Persistência ≠ Backup
```

Um volume não protege, por si só, contra corrupção, eliminação do volume ou perda do disco do host.

---

## 13.2. Criar uma evidência de persistência

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "CREATE TABLE IF NOT EXISTS lab_marker(id serial primary key, note text);"
```

### Flags

- `exec` — executa um comando num serviço em execução;
- `-T` — desativa pseudo-TTY, adequado a execução não interativa;
- `psql -U symfony` — usa o utilizador PostgreSQL `symfony`;
- `-d symfony` — seleciona a base de dados `symfony`;
- `-c` — executa a instrução SQL indicada.

Inserir um registo:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "INSERT INTO lab_marker(note) VALUES ('antes-update');"
```

Confirmar:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

---

## 13.3. Backup lógico manual

```bash
./formando/scripts/compose-prod.sh exec -T db \
  pg_dump -U symfony -d symfony \
  > backup.sql
```

- `pg_dump` — gera um backup lógico PostgreSQL;
- `-U` — utilizador;
- `-d` — base de dados;
- `>` — grava stdout em `backup.sql`.

Confirmar:

```bash
ls -lh backup.sql
```

- `-l` — formato detalhado;
- `-h` — tamanho legível.

Depois observe a automação:

```bash
sed -n '1,220p' formando/scripts/backup-postgres.sh
```

---

# 14. Deployment controlado da versão 1.0.0

Antes de utilizar o script, abra-o:

```bash
sed -n '1,260p' formando/scripts/deploy-prod.sh
```

Identifique as fases:

```text
config
→ preflight da porta
→ pull
→ DB
→ health DB
→ inicialização do schema se necessária
→ app
→ validação
```

Executar:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

Validar:

```bash
./formando/scripts/validate.sh
```

O script de validação confirma endpoints e Docker HEALTHCHECK.

---

# 15. Atualizar para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar a versão:

```bash
curl -fsS http://localhost:8080/info
```

### Flags do `curl`

- `-f` — falha em respostas HTTP 4xx/5xx;
- `-s` — modo silencioso;
- `-S` — mostra a mensagem de erro apesar de `-s`.

Confirmar os dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Resultado pretendido:

```text
container da app substituído
      +
volume PostgreSQL preservado
      ↓
lab_marker continua presente
```

---

# 16. Introduzir a falha controlada 1.2.0-rc1

Executar:

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

### Elementos shell

- `set +e` — permite continuar mesmo que um comando devolva erro;
- `$?` — exit code do último comando;
- `RC=$?` — guarda o exit code;
- `set -e` — volta a ativar terminação automática em erro no contexto onde esta opção é usada.

A versão `1.2.0-rc1` utiliza deliberadamente um caminho incorreto no Docker HEALTHCHECK.

---

# 17. Diagnosticar antes de fazer rollback

## 17.1. Estado dos serviços

```bash
./formando/scripts/compose-prod.sh ps
```

## 17.2. Obter o container

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

## 17.3. Inspecionar o health

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

## 17.4. Consultar logs

```bash
./formando/scripts/compose-prod.sh logs --tail 100 app
```

- `--tail 100` — limita a saída às últimas 100 linhas.

## 17.5. Comparar endpoints

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

A evidência deverá permitir concluir:

```text
/health  → válido
/healthz → inválido
      ↓
HEALTHCHECK testa o caminho incorreto
      ↓
container unhealthy
```

**Não faça rollback antes de conseguir explicar a causa da falha.**

---

# 18. Rollback para a versão conhecida como boa

Abra primeiro o script:

```bash
sed -n '1,220p' formando/scripts/rollback.sh
```

Executar:

```bash
./formando/scripts/rollback.sh 1.1.0
```

Validar:

```bash
./formando/scripts/validate.sh
```

Confirmar os dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Resultado final:

```text
1.2.0-rc1
   ↓ falha operacional detetada
1.1.0
   ↓ rollback
healthy
   +
dados preservados
```

---

# 19. Síntese técnica

No final do laboratório deverá conseguir explicar, sem consultar o documento:

1. diferença entre imagem e container;
2. função de Docker Engine, containerd e runc;
3. o que é um build context;
4. para que serve `.dockerignore`;
5. como a ordem das instruções afeta a cache;
6. porque usamos multi-stage;
7. porque `ARG`/`ENV` não são secret managers;
8. o que é Docker HEALTHCHECK;
9. diferença entre `/health` e `/ready`;
10. o que um scan Trivy faz e não faz;
11. diferença entre tag e digest;
12. o que é um container registry;
13. diferença entre `pull` e `push`;
14. significado de `build once, promote the same artifact`;
15. diferença entre persistência e backup;
16. porque se diagnostica antes de fazer rollback;
17. porque Docker Compose single-host não representa Alta Disponibilidade.

---

# 20. Checklist de conclusão

- [ ] Docker Engine instalado e validado numa VM Ubuntu Server limpa.
- [ ] Docker Compose e Buildx funcionais.
- [ ] Trivy instalado e funcional.
- [ ] Repositório da formação clonado.
- [ ] Source Symfony preparado.
- [ ] Dockerfile inicial interpretado.
- [ ] Imagem inicial construída manualmente.
- [ ] Build multi-stage executado.
- [ ] Cache observada.
- [ ] Risco de secrets em `ARG/ENV` demonstrado.
- [ ] BuildKit secret utilizado.
- [ ] Compose secret observado.
- [ ] HEALTHCHECK interpretado.
- [ ] Limites de recursos e restart policy identificados.
- [ ] Scan Trivy executado.
- [ ] Tag e digest distinguidos.
- [ ] Conceito de registry explicado.
- [ ] Pull executado.
- [ ] Push pessoal executado quando aplicável.
- [ ] Compose de produção validado.
- [ ] Deploy `1.0.0` validado.
- [ ] Dados persistentes criados.
- [ ] Backup lógico criado.
- [ ] Update `1.1.0` validado.
- [ ] Falha `1.2.0-rc1` diagnosticada.
- [ ] Rollback `1.1.0` executado.
- [ ] Dados confirmados depois do rollback.

---

# 21. Mensagens a reter

```text
Imagem ≠ Container
```

```text
.env ≠ Secret Manager
```

```text
Docker HEALTHCHECK ≠ Kubernetes Probe
```

```text
Tag ≠ Digest
```

```text
Persistência ≠ Backup
```

```text
Build Once → Promote the Same Artifact
```

```text
Compose Single-host ≠ Alta Disponibilidade ≠ Kubernetes
```
