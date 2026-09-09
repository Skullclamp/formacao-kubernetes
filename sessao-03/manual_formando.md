# Manual do Formando
## Sessão 3 — Docker II: Build, Imagens, Otimização, Segurança, Registry e Deployment Single-host

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 3 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Foco pedagógico** | Construir, preparar, analisar, identificar e promover imagens |
| **Cenário transversal** | Symfony Demo v3.1.0 + PHP 8.4 + Apache + PostgreSQL 16 |

---

# 1. Enquadramento

Na Sessão 2 o foco foi **OPERAR** containers. Nesta sessão passamos a construir e preparar o artefacto que será executado e promovido entre ambientes.

```text
Código
  ↓
Dockerfile
  ↓
Build
  ↓
Layers / Cache
  ↓
Multi-stage
  ↓
Hardening
  ↓
HEALTHCHECK
  ↓
Scan
  ↓
Tag / Digest
  ↓
Registry
  ↓
Deployment
  ↓
Update
  ↓
Falha
  ↓
Rollback
```

---

# 2. Regra pedagógica

Os scripts são exemplos de automação. Não substituem a aprendizagem manual.

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Nos Labs 01–06 deverá executar manualmente os passos principais antes de usar um script equivalente. No Lab 07 a automação é intencional, porque o objetivo já é integrar deployment, validação, update, falha e rollback.

---

# 3. Ponto de partida — Ubuntu Server limpo

A VM parte apenas de uma instalação limpa de **Ubuntu Server**.

O percurso inicial é:

```text
Ubuntu Server
      ↓
Docker Engine
      ↓
containerd
      ↓
Buildx
      ↓
Docker Compose
      ↓
hello-world
      ↓
Git clone
      ↓
Sessão 3
```

## 3.1. Atualizar o sistema e instalar ferramentas base

```bash
sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  ca-certificates \
  curl \
  git
```

## 3.2. Remover eventuais pacotes em conflito

Numa VM nova é normal que vários destes pacotes não estejam instalados.

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

## 3.3. Adicionar a chave oficial da Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc
```

## 3.4. Adicionar o repositório oficial Docker

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

## 3.5. Instalar Docker Engine, containerd, Buildx e Compose

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

Componentes instalados:

```text
Docker Engine
Docker CLI
containerd
Docker Buildx
Docker Compose plugin
```

## 3.6. Validar o serviço

```bash
sudo systemctl status docker --no-pager
```

Se necessário:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## 3.7. Primeiro container

```bash
sudo docker run --rm hello-world
```

Confirmar:

```bash
sudo docker version
sudo docker info
sudo docker compose version
sudo docker buildx version
```

## 3.8. Docker sem `sudo`

Para simplificar os laboratórios:

```bash
sudo usermod -aG docker "$USER"
```

Termine a sessão SSH:

```bash
exit
```

Volte a ligar e valide:

```bash
groups
docker version
docker info
docker run --rm hello-world
docker compose version
```

> O grupo `docker` concede privilégios elevados sobre o host. Nesta formação é utilizado numa VM de laboratório para evitar a repetição de `sudo` em todos os comandos.

---

# 4. Obter os recursos da formação

## Primeira utilização

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

## Se já tiver o repositório

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Confirme:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

Todos os comandos da sessão assumem que está em:

```text
formacao-kubernetes/sessao-03
```

---

# 5. Preparar o source Symfony

```bash
./comum/prepare-source.sh
```

Este script obtém a Symfony Demo `v3.1.0` e aplica os endpoints pedagógicos.

Confirme:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

A aplicação passa a disponibilizar:

```text
/info
/health
/ready
```

---

# 6. Objetivos da sessão

No final deverá conseguir:

- construir uma imagem através de Dockerfile;
- explicar contexto de build e `.dockerignore`;
- compreender layers e cache;
- utilizar multi-stage builds;
- distinguir build stage e runtime stage;
- interpretar `ARG`, `ENV`, `CMD`, `ENTRYPOINT` e labels;
- avaliar a imagem base;
- identificar riscos de secrets;
- utilizar BuildKit secrets e compreender Compose secrets;
- interpretar Docker `HEALTHCHECK`;
- distinguir `/health` de `/ready`;
- aplicar limites de CPU/memória, restart e logging;
- analisar uma imagem com Trivy;
- distinguir tag de digest;
- trabalhar com GHCR;
- aplicar `build once, promote the same artifact`;
- executar deploy, update, falha e rollback;
- confirmar persistência dos dados.

---

# 7. Dockerfile e contexto de build

Um Dockerfile descreve as instruções usadas para construir uma imagem.

| Instrução | Função |
|---|---|
| `FROM` | imagem base |
| `WORKDIR` | diretoria de trabalho |
| `COPY` | copiar ficheiros do contexto |
| `RUN` | executar operações durante o build |
| `ARG` | argumento de build |
| `ENV` | variável persistida no ambiente |
| `EXPOSE` | documentar porta |
| `HEALTHCHECK` | teste de saúde Docker |
| `CMD` | comando por omissão |
| `ENTRYPOINT` | entrada principal |
| `LABEL` | metadata |

Primeiro build:

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

O último `.` é o **contexto de build**.

```text
Diretoria atual
      ↓
contexto enviado ao builder
      ↓
COPY só acede ao contexto
```

---

# 8. `.dockerignore`

O `.dockerignore` evita que ficheiros desnecessários ou sensíveis sejam enviados para o builder.

Exemplos no laboratório:

```text
app/.git/
app/vendor/
app/var/cache/
app/var/log/
.git/
app/.env.local
app/.env.*.local
backups/
*.sql
*.zip
```

---

# 9. Layers, cache e multi-stage

Consultar o histórico:

```bash
docker history symfony-demo:naive
```

Build manual da versão otimizada:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

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

O multi-stage separa:

```text
Stage build
  ↓
ferramentas + Composer + dependências
  ↓
Stage runtime
  ↓
apenas o necessário para executar
```

Só depois compare com o script:

```bash
sed -n '1,220p' formando/scripts/build.sh
./formando/scripts/build.sh 1.1.0
```

Pergunta-chave:

> Que comando manual está o script a automatizar?

---

# 10. Hardening e secrets

Princípios:

- imagem base de origem conhecida;
- reduzir componentes desnecessários;
- evitar ferramentas de build no runtime;
- não embutir secrets;
- menor privilégio;
- permissões de escrita apenas onde necessárias;
- não montar o Docker socket sem compreender as implicações.

## Má prática com `ARG` e `ENV`

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Investigue:

```bash
docker history --no-trunc secret-demo:bad
docker image inspect secret-demo:bad
```

## BuildKit secret

```bash
printf 'segredo-falso-lab\n' > /tmp/demo_secret.txt

DOCKER_BUILDKIT=1 docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=demo_secret,src=/tmp/demo_secret.txt \
  -t secret-demo:buildkit \
  formando/exemplos/secrets

rm -f /tmp/demo_secret.txt
```

## Compose secret

```bash
cp formando/exemplos/secrets/demo_secret.example.txt \
   formando/exemplos/secrets/demo_secret.txt

docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit

rm -f formando/exemplos/secrets/demo_secret.txt
```

```text
.env ≠ secret manager
```

---

# 11. Docker Compose — manual antes do wrapper

Preparar:

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

Validar manualmente:

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

Depois abra o wrapper:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
```

E compare:

```bash
./formando/scripts/compose-prod.sh ps
```

---

# 12. Saúde, prontidão e recursos

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

```text
/health → saúde básica
/ready  → saúde + dependência da DB
/info   → versão e ambiente
```

Obter o container:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar health:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Consultar limites:

```bash
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'

docker stats --no-stream "$CID"
```

Ponto fundamental:

```text
Docker HEALTHCHECK
        ≠
Kubernetes livenessProbe
        ≠
Kubernetes readinessProbe
```

---

# 13. Scan com Trivy

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Os resultados variam ao longo do tempo. Não existe uma contagem fixa de vulnerabilidades esperada.

Exemplo de quality gate:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

---

# 14. Tags e digest

Criar uma segunda tag para o mesmo conteúdo:

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable
```

Comparar IDs:

```bash
docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

```text
Tag    = referência conveniente
Digest = identidade imutável do conteúdo no registry
```

---

# 15. Registry e promoção

Imagens públicas:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

Para um namespace pessoal:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo

docker tag \
  symfony-demo:1.0.0 \
  "$IMAGE_REPO:1.0.0"

docker push "$IMAGE_REPO:1.0.0"
```

Só depois analise a automação:

```bash
sed -n '1,220p' formando/scripts/push.sh
./formando/scripts/push.sh 1.0.0
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

# 16. Deployment integrado

No Lab 07 passa a usar scripts deliberadamente, porque já compreendeu os passos individuais.

Antes de executar:

```bash
sed -n '1,260p' formando/scripts/deploy-prod.sh
sed -n '1,220p' formando/scripts/validate.sh
sed -n '1,220p' formando/scripts/rollback.sh
```

Deployment inicial:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

Atualização:

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Falha controlada:

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

Diagnosticar antes do rollback:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)

docker inspect "$CID" --format '{{json .State.Health}}'
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

Rollback:

```bash
./formando/scripts/rollback.sh 1.1.0
```

---

# 17. Persistência e backup

PostgreSQL utiliza um named volume.

```text
Container da aplicação muda
        ↓
Dados PostgreSQL permanecem
```

Mas:

```text
Persistência ≠ Backup
```

Backup lógico:

```bash
./formando/scripts/backup-postgres.sh
```

---

# 18. Compose single-host não é Alta Disponibilidade

```text
Docker Compose single-host
           ≠
     Alta Disponibilidade
           ≠
        Kubernetes
```

Uma restart policy pode reiniciar um container no mesmo host; não oferece scheduling ou recuperação noutro node se o host falhar.

---

# 19. Resumo

```text
Ubuntu Server limpo
      ↓
Docker instalado pelo repositório oficial
      ↓
hello-world
      ↓
Git clone
      ↓
prepare-source
      ↓
Dockerfile
      ↓
Build manual
      ↓
Cache / Multi-stage
      ↓
Hardening / Secrets
      ↓
Compose manual
      ↓
HEALTHCHECK
      ↓
Trivy
      ↓
Tag / Digest
      ↓
Push manual
      ↓
Automação
      ↓
Deploy → Update → Falha → Rollback
```

---

# 20. Checklist de validação inicial

Antes de iniciar o Lab 01 deverá conseguir confirmar:

```text
[ ] Ubuntu Server funcional
[ ] docker version funciona
[ ] docker info funciona
[ ] docker run --rm hello-world funciona
[ ] docker compose version funciona
[ ] docker buildx version funciona
[ ] git --version funciona
[ ] curl --version funciona
[ ] repositório formacao-kubernetes clonado
[ ] diretoria sessao-03 disponível
[ ] app/composer.json criado por prepare-source.sh
```

A partir daqui inicia-se a aprendizagem de construção de imagens propriamente dita.
