# Laboratório Integrado — Sessão 3
## Docker II: da VM Ubuntu Server limpa ao deployment, falha e rollback

**Duração de referência:** 4 horas  
**Nível:** intermédio  
**Cenário:** Symfony Demo v3.1.0 + PHP 8.4 + Apache + PostgreSQL 16

Este laboratório acompanha um único percurso técnico. Em cada etapa procure compreender o conceito, executar o comando, interpretar as flags e validar o resultado.

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

---

# 1. Preparar a VM Ubuntu Server

## 1.1. Atualizar o sistema

```bash
sudo apt update
sudo apt upgrade -y
```

- `sudo` — executa com privilégios administrativos;
- `apt update` — atualiza o catálogo de pacotes;
- `apt upgrade` — atualiza pacotes já instalados;
- `-y` — confirma automaticamente as perguntas do `apt`.

Instalar ferramentas base:

```bash
sudo apt install -y ca-certificates curl git
```

- `ca-certificates` — permite validar certificados TLS;
- `curl` — cliente HTTP/HTTPS;
- `git` — obtém os recursos da formação.

## 1.2. Remover possíveis conflitos

```bash
sudo apt remove -y \
  docker.io docker-compose docker-compose-v2 docker-doc \
  docker-buildx podman-docker containerd runc
```

Numa VM limpa é normal que vários destes pacotes não existam.

## 1.3. Adicionar a chave oficial Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Flags principais de `curl`:

| Flag | Função |
|---|---|
| `-f` | termina com erro em respostas HTTP 4xx/5xx |
| `-s` | modo silencioso |
| `-S` | mostra erros apesar de `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava a resposta no ficheiro indicado |

## 1.4. Adicionar o repositório Docker

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

- `tee` — grava a entrada recebida num ficheiro;
- `<<EOF ... EOF` — here-document;
- `$(...)` — executa um comando e substitui pelo respetivo resultado.

## 1.5. Instalar Docker

```bash
sudo apt install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Arquitetura simplificada:

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

## 1.6. Validar

```bash
sudo systemctl status docker --no-pager
sudo docker run --rm hello-world
sudo docker version
sudo docker compose version
sudo docker buildx version
```

- `--no-pager` — mostra a saída diretamente;
- `--rm` — remove o container quando termina.

Para usar Docker sem `sudo` no laboratório:

```bash
sudo usermod -aG docker "$USER"
exit
```

Volte a ligar por SSH e valide:

```bash
groups
docker run --rm hello-world
```

> O grupo `docker` concede privilégios muito elevados sobre o host. É usado aqui apenas numa VM de laboratório.

---

# 2. Instalar Trivy

```bash
sudo apt-get install -y wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list

sudo apt-get update
sudo apt-get install -y trivy
trivy --version
```

- `|` — envia a saída do comando anterior para o seguinte;
- `gpg --dearmor` — converte a chave para o formato usado pelo APT;
- `> /dev/null` — descarta a saída normal.

---

# 3. Obter e preparar a aplicação

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

Se o repositório já existir:

```bash
cd ~/formacao-kubernetes
git pull
cd sessao-03
```

> Não é necessário usar `sudo git pull` se o repositório pertence ao utilizador da sessão.

Preparar a Symfony Demo:

```bash
./comum/prepare-source.sh
```

Validar:

```bash
test -f app/composer.json && echo "OK: source preparado"
```

Os endpoints pedagógicos são:

```text
/info   → versão e ambiente
/health → saúde básica
/ready  → prontidão incluindo PostgreSQL
```

---

# 4. Construir a primeira imagem

Abrir o Dockerfile inicial:

```bash
less formando/docker/Dockerfile.inicial
```

Construir:

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

| Elemento | Significado |
|---|---|
| `docker build` | constrói uma imagem |
| `-f` | indica o Dockerfile |
| `-t` | atribui nome e tag |
| `.` | define a diretoria atual como build context |

Consultar:

```bash
docker image ls symfony-demo
docker history symfony-demo:naive
```

O build context é o conjunto de ficheiros disponibilizado ao builder. O `.dockerignore` evita enviar conteúdo desnecessário ou sensível.

---

# 5. Cache e multi-stage

Construir a imagem otimizada:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

- `--build-arg` — fornece um valor a uma instrução `ARG` do Dockerfile;
- `ARG` é adequado a parametrização de build, **não a secrets**.

Novo build:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Procure `CACHED` na saída.

```text
stage build
  ↓ ferramentas + Composer + dependências
COPY --from=build
  ↓
stage runtime
  ↓ apenas o necessário para executar
```

Só depois observe a automação:

```bash
sed -n '1,220p' formando/scripts/build.sh
```

---

# 6. Hardening e secrets

## 6.1. Primeiro: o que NÃO fazer

Construir o exemplo didático incorreto:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Inspecionar:

```bash
docker history --no-trunc secret-demo:bad
docker image inspect secret-demo:bad
```

Conclusão:

```text
ARG / ENV no Dockerfile
        ≠
forma segura de transportar secrets
```

## 6.2. Build secret a partir de variável de ambiente

Para o laboratório usamos uma variável de ambiente no **host** como origem do secret. Assim não criamos um ficheiro `.txt` com a credencial na pasta do projeto.

Definir um valor fictício:

```bash
export API_TOKEN='segredo-falso-lab'
```

Construir:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=API_TOKEN,env=API_TOKEN \
  -t secret-demo:buildkit \
  formando/exemplos/secrets
```

Explicação:

- `--secret` — fornece um secret ao BuildKit;
- `id=API_TOKEN` — identificador usado no Dockerfile;
- `env=API_TOKEN` — obtém o valor da variável de ambiente do host;
- no Dockerfile, `RUN --mount=type=secret,id=API_TOKEN,env=API_TOKEN` disponibiliza esse valor **apenas durante essa instrução `RUN`**;
- o valor não é persistido na imagem final.

Confirmar que a imagem funciona sem expor o secret:

```bash
docker run --rm secret-demo:buildkit
```

Remover a variável do shell quando terminar:

```bash
unset API_TOKEN
```

> O Docker também suporta um ficheiro como origem de um build secret (`src=...`). Isso é suportado oficialmente e é útil, por exemplo, para credenciais já existentes em ficheiros. Contudo, não significa que se deva guardar passwords ou tokens em ficheiros versionados no projeto.

## 6.3. Compose secret a partir de variável de ambiente

Definir um valor fictício no host:

```bash
export DEMO_SECRET='valor-apenas-para-demonstracao'
```

O ficheiro `compose.secret-demo.yaml` declara:

```yaml
secrets:
  demo_secret:
    environment: DEMO_SECRET
```

E concede o secret apenas ao serviço que necessita dele:

```yaml
services:
  demo:
    secrets:
      - demo_secret
```

Executar:

```bash
docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit
```

Dentro do container o Compose disponibiliza o secret em:

```text
/run/secrets/demo_secret
```

O facto de o secret aparecer como ficheiro **dentro do container** é o comportamento normal do Compose para a sintaxe curta de `secrets`. A origem, neste laboratório, é uma variável de ambiente do host; não um `.txt` guardado no projeto.

Limpar:

```bash
docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  down
unset DEMO_SECRET
```

Mensagem a reter:

```text
Dockerfile ARG/ENV ≠ secret manager
.env de projeto ≠ secret manager
secret source no host → acesso explícito → /run/secrets/<nome> no container
```

---

# 7. HEALTHCHECK e controlos operacionais

Consultar o healthcheck da imagem:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format '{{json .Config.Healthcheck}}'
```

Preparar o Compose:

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

Validar a configuração:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

O override de produção inclui:

```yaml
restart: unless-stopped
mem_limit: 512m
cpus: 1.0
logging:
  driver: local
```

> Docker `HEALTHCHECK` não é convertido automaticamente em probes Kubernetes.

---

# 8. Scan com Trivy

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

- `--scanners vuln` — procura vulnerabilidades;
- `--severity HIGH,CRITICAL` — filtra severidades;
- `--ignore-unfixed` — omite vulnerabilidades sem correção conhecida.

Os resultados variam ao longo do tempo; não existe uma contagem fixa esperada.

---

# 9. Tag, digest e registry

Um **registry** armazena e distribui imagens.

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
│       │          │            │
registry namespace repositório   tag
```

Criar uma tag adicional:

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable
```

Comparar IDs:

```bash
docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

```text
Tag    → referência legível e potencialmente mutável
Digest → identidade do conteúdo publicado
```

Obter uma imagem pública:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

Para um namespace pessoal, quando aplicável:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
docker tag symfony-demo:1.0.0 "$IMAGE_REPO:1.0.0"
docker push "$IMAGE_REPO:1.0.0"
```

Princípio:

```text
BUILD ONCE
   ↓
Imagem / Digest
   ↓
DEV → TEST → PROD
```

---

# 10. Deployment single-host

Primeiro arranque manual:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

Consultar:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Validar endpoints:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

Obter o container da aplicação:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar health e recursos:

```bash
docker inspect "$CID" --format '{{json .State.Health}}'
docker stats --no-stream "$CID"
```

---

# 11. Ver a aplicação no PC do formando

Como o formando já se liga por PuTTY à VM, existe conectividade PC → VM. Obter o IP:

```bash
hostname -I
```

Confirmar a publicação da porta:

```bash
docker ps
```

Deverá aparecer algo semelhante a:

```text
0.0.0.0:8080->80/tcp
```

No navegador do PC do formando:

```text
http://IP_DA_VM:8080
http://IP_DA_VM:8080/info
http://IP_DA_VM:8080/health
http://IP_DA_VM:8080/ready
```

Se a VM usar UFW e estiver ativo:

```bash
sudo ufw status
```

Quando necessário e autorizado no laboratório:

```bash
sudo ufw allow 8080/tcp
```

---

# 12. Persistência e backup

Criar marcador:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "CREATE TABLE IF NOT EXISTS lab_marker(id serial primary key, note text);"
```

Inserir registo:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "INSERT INTO lab_marker(note) VALUES ('antes-update');"
```

Backup lógico:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  pg_dump -U symfony -d symfony > backup.sql
```

```text
Persistência ≠ Backup
```

---

# 13. Deploy, update, falha e rollback

Abrir primeiro o script:

```bash
sed -n '1,260p' formando/scripts/deploy-prod.sh
```

Deploy inicial:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
./formando/scripts/validate.sh
```

Atualizar:

```bash
./formando/scripts/deploy-prod.sh 1.1.0
curl -fsS http://localhost:8080/info
```

Confirmar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Introduzir a versão com falha controlada:

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e
echo "EXIT_CODE=$RC"
```

Diagnosticar:

```bash
./formando/scripts/compose-prod.sh ps
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" --format '{{json .State.Health}}'
./formando/scripts/compose-prod.sh logs --tail 100 app
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

A causa esperada é:

```text
/health válido
/healthz inválido
      ↓
HEALTHCHECK da 1.2.0-rc1 usa /healthz
      ↓
unhealthy
```

Só depois fazer rollback:

```bash
./formando/scripts/rollback.sh 1.1.0
./formando/scripts/validate.sh
```

Confirmar novamente os dados.

---

# 14. Mensagens a reter

```text
Imagem ≠ Container
ARG/ENV ≠ Secret Manager
.env de projeto ≠ Secret Manager
Docker HEALTHCHECK ≠ Kubernetes Probe
Tag ≠ Digest
Persistência ≠ Backup
Build Once → Promote the Same Artifact
Compose Single-host ≠ Alta Disponibilidade
```
