# Guia do Formando — Sessão 3

## Docker II — Build, Imagens, Segurança, Registry e Deployment Single-host

## 1. Objetivo

A Sessão 2 concentrou-se em **operar** containers. Nesta sessão o foco passa para **construir e preparar** o artefacto que será promovido entre ambientes.

```text
Código → Dockerfile → imagem → scan → registry → deploy → update → rollback
```

# 2. Ponto de partida — Ubuntu Server limpo

A VM parte de uma instalação limpa de Ubuntu Server. Antes de clonar os recursos da formação é necessário instalar Docker Engine, Buildx, Docker Compose, Git e `curl`.

## 2.1. Atualizar o sistema

```bash
sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  ca-certificates \
  curl \
  git
```

## 2.2. Remover eventuais pacotes em conflito

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

## 2.3. Adicionar a chave oficial Docker

```bash
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc
```

## 2.4. Adicionar o repositório oficial Docker

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

## 2.5. Instalar Docker Engine, containerd, Buildx e Compose

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

## 2.6. Validar a instalação

```bash
sudo systemctl status docker --no-pager
sudo docker run --rm hello-world
sudo docker version
sudo docker info
sudo docker compose version
sudo docker buildx version
```

Se necessário:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## 2.7. Executar Docker sem `sudo`

```bash
sudo usermod -aG docker "$USER"
exit
```

Volte a ligar por SSH e confirme:

```bash
groups
docker version
docker info
docker run --rm hello-world
docker compose version
```

> O grupo `docker` concede privilégios elevados sobre o host. Na formação é utilizado numa VM de laboratório para simplificar a execução dos exercícios.

# 3. Obter os recursos da formação

## Primeira utilização

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

## Se o repositório já estiver clonado

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Todos os comandos da sessão assumem que está em:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

# 4. Preparar a aplicação

```bash
./comum/prepare-source.sh
```

Confirmar:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

# 5. Pré-requisitos antes dos laboratórios

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

# 6. Regra de aprendizagem

Nos Labs 01–06, deverá primeiro executar o processo **manualmente**. Os scripts existem como exemplos de automação e atalhos depois de compreender os passos.

```text
FAZER
  ↓
OBSERVAR
  ↓
EXPLICAR
  ↓
AUTOMATIZAR
```

Não execute um script pela primeira vez sem saber que operações está a automatizar.

No Lab 07 os scripts são usados deliberadamente para integrar o ciclo operacional completo.

# 7. Cenário

A aplicação é a Symfony Demo `v3.1.0`, executada com PHP 8.4 + Apache e PostgreSQL 16.

Os endpoints adicionais são:

```text
/info
/health
/ready
```

`/health` responde à pergunta “o processo da aplicação está operacional?”. `/ready` acrescenta a dependência da base de dados.

# 8. Percurso dos laboratórios

| Lab | Tema | Forma de trabalho | Resultado esperado |
|---:|---|---|---|
| 01 | Dockerfile e build | manual | imagem funcional |
| 02 | Cache e multi-stage | manual; script apenas no fim | imagem otimizada e cache compreendida |
| 03 | Hardening e secrets | experiências manuais | riscos observados e alternativas compreendidas |
| 04 | Healthcheck e operação | Compose manual; wrapper depois | saúde e controlos operacionais validados |
| 05 | Scan, tags e digest | manual | vulnerabilidades interpretadas e identidade compreendida |
| 06 | Registry e promoção | `tag` e `push` manuais; script depois | promoção compreendida |
| 07 | Deploy/update/rollback | automação operacional transparente | ciclo completo validado |

# 9. Regras de trabalho

1. Não colocar tokens ou passwords reais nos ficheiros versionados.
2. Não usar `latest` nos exercícios em que se pretende rastreabilidade.
3. Validar sempre o estado depois de uma alteração.
4. Não confundir persistência com backup.
5. Não confundir Docker `HEALTHCHECK` com probes Kubernetes.
6. Um deployment Compose num único host não é Alta Disponibilidade.
7. Antes de executar um script, saber explicar os passos que ele automatiza.

# 10. Versões de referência

```text
1.0.0      → versão inicial
1.1.0      → atualização válida
1.2.0-rc1  → candidata com falha de healthcheck
```

Imagens públicas:

```text
ghcr.io/skullclamp/symfony-demo
```

# 11. Evidência final

No final deverá conseguir mostrar:

- Docker Engine, Compose e Buildx funcionais;
- repositório clonado na VM;
- source Symfony preparado;
- Dockerfile interpretado;
- imagem construída manualmente;
- cache observada e explicada;
- multi-stage compreendido;
- secret inadequado identificado experimentalmente;
- Compose executado manualmente;
- scan executado;
- tag e digest explicados;
- `docker tag` e `docker push` executados quando houver namespace próprio;
- deployment `1.0.0`;
- update `1.1.0`;
- falha `1.2.0-rc1` detetada;
- rollback `1.1.0`;
- dados preservados.
