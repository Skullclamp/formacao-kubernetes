# Sessão 3 — Docker II

## Build, Imagens, Segurança, Registry e Deployment Single-host

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

Nesta sessão evoluímos da operação de containers para a construção e preparação de imagens destinadas a ambientes de execução controlados.

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
Healthcheck
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

# 1. Ponto de partida — Ubuntu Server limpo

A VM do formando parte de uma instalação limpa de **Ubuntu Server**. Antes dos laboratórios é necessário instalar Docker Engine, Buildx, Docker Compose, Git e `curl`.

O percurso completo é:

```text
Ubuntu Server limpo
      ↓
Atualizar o sistema
      ↓
Instalar pré-requisitos
      ↓
Adicionar repositório oficial Docker
      ↓
Docker Engine + containerd + Buildx + Compose
      ↓
Validar com hello-world
      ↓
Adicionar utilizador ao grupo docker
      ↓
Nova sessão SSH
      ↓
Clonar repositório da formação
      ↓
Entrar em sessao-03
      ↓
Preparar source Symfony
      ↓
Labs 01–07
```

## 1.1. Atualizar o sistema e instalar ferramentas base

```bash
sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  ca-certificates \
  curl \
  git
```

## 1.2. Remover eventuais pacotes em conflito

Numa VM limpa estes pacotes poderão não existir. O comando é mantido para evitar conflitos com versões fornecidas por outros repositórios.

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

## 1.3. Adicionar a chave oficial da Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc
```

## 1.4. Adicionar o repositório oficial Docker

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

## 1.5. Instalar Docker Engine, containerd, Buildx e Compose

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

## 1.6. Confirmar o serviço Docker

```bash
sudo systemctl status docker --no-pager
```

Se necessário:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## 1.7. Primeiro teste

```bash
sudo docker run --rm hello-world
```

Confirmar versões e componentes:

```bash
sudo docker version
sudo docker info
sudo docker compose version
sudo docker buildx version
```

## 1.8. Utilizar Docker sem `sudo` durante os laboratórios

```bash
sudo usermod -aG docker "$USER"
```

Termine a sessão SSH:

```bash
exit
```

Volte a ligar à VM e confirme:

```bash
groups
docker version
docker info
docker run --rm hello-world
docker compose version
```

> O grupo `docker` concede privilégios elevados sobre o host. Nesta formação é utilizado numa VM de laboratório para evitar `sudo` em todos os comandos Docker.

# 2. Obter os recursos da formação

Os recursos da sessão estão no GitHub. Só depois de Docker, Git e `curl` estarem funcionais deverá obter o repositório.

## 2.1. Primeira utilização

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

## 2.2. Se o repositório já existir

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Confirme a diretoria de trabalho:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

Todos os comandos dos Labs 01–07 assumem como diretoria de trabalho:

```text
formacao-kubernetes/sessao-03
```

# 3. Preparar o código da aplicação

O laboratório utiliza:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16;
- Docker Compose.

O código da aplicação não é armazenado permanentemente na pasta da sessão. Depois do clone, execute:

```bash
./comum/prepare-source.sh
```

O script descarrega a versão de referência e aplica os endpoints pedagógicos `/info`, `/health` e `/ready`.

Confirme:

```bash
test -f app/composer.json && echo 'OK: aplicação preparada'
```

# 4. Pré-requisitos finais

Antes do Lab 01:

```bash
docker version
docker info
docker compose version
docker buildx version
git --version
curl --version
```

Para o Lab 05:

```bash
trivy --version
```

# 5. Regra pedagógica dos scripts

Os scripts existem para demonstrar automação e para suportar o cenário operacional final. **Não substituem a aprendizagem manual.**

A progressão da sessão é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Nos Labs 01–06, os comandos principais são executados manualmente antes de usar qualquer script equivalente. No Lab 07, os scripts são utilizados deliberadamente porque o objetivo já é integrar deploy, validação, update, falha e rollback.

Sempre que um script for introduzido:

1. identifique os passos que já executou manualmente;
2. abra o script;
3. localize esses passos no código;
4. só depois execute o script.

# Documentação da sessão

- [Plano da Sessão 3](plano_sessao_3.md)
- [Manual do formando](manual_formando.md)
- [Guia do formando](formando/guia_formando.md)
- [Cheat sheet](cheat_sheet.md)
- [Checklist final](checklist.md)
- [Referências](referencias.md)

# Laboratórios

1. [Dockerfile e build](formando/labs/01_dockerfile_build.md)
2. [Layers, cache e multi-stage](formando/labs/02_layers_cache_multistage.md)
3. [Hardening e secrets](formando/labs/03_hardening_secrets.md)
4. [Healthcheck e operação](formando/labs/04_healthcheck_operacao.md)
5. [Scan, tags e digest](formando/labs/05_scan_tags_digest.md)
6. [Registry e promoção](formando/labs/06_registry_promocao.md)
7. [Deploy, update, falha e rollback](formando/labs/07_deploy_update_rollback.md)

# Imagens públicas da formação

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

| Versão | Utilização |
|---|---|
| `1.0.0` | Deployment inicial |
| `1.1.0` | Atualização válida |
| `1.2.0-rc1` | Falha controlada de healthcheck |

# Conceitos finais

```text
/health → saúde básica da aplicação
/ready  → disponibilidade da aplicação, incluindo a base de dados
/info   → versão e ambiente
```

```text
Persistência ≠ Backup
```

```text
BUILD ONCE
    ↓
Imagem / Digest
    ↓
DEV → TEST → PROD
```

```text
Docker Compose single-host
           ≠
     Alta Disponibilidade
           ≠
        Kubernetes
```

> O Docker `HEALTHCHECK` da imagem não é convertido automaticamente numa probe Kubernetes.
