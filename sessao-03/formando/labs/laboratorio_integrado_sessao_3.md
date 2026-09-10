# Laboratório Integrado — Sessão 3
## Docker II: da VM Ubuntu Server limpa ao deployment, falha e rollback

**Sessão:** 3  
**Duração da sessão:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Cenário:** Symfony Demo v3.1.0 + Symfony 8.1 + PHP 8.4 + Apache + PostgreSQL 16

Este laboratório acompanha uma única história técnica. O objetivo não é copiar comandos: é compreender o conceito, executar, observar evidência e só depois automatizar.

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

> **Organização do tempo:** as secções 1 a 3 constituem a preparação técnica da VM e devem, sempre que possível, ser realizadas antes do bloco principal da sessão. Mantêm-se neste documento para que o formando consiga repetir todo o processo a partir de uma VM limpa. O núcleo pedagógico Docker II começa na secção 4.

> **Como interpretar os outputs deste laboratório:** os blocos identificados como **Output esperado (exemplo)** mostram apenas a evidência essencial observada durante a validação técnica do laboratório. IDs de containers, timestamps, tempos de execução, hashes locais e contagens de vulnerabilidades podem variar. O importante é reconhecer os estados e valores indicados como significativos.

---

# 0. Percurso do laboratório

```text
Ubuntu Server limpo
      ↓
Docker Engine + containerd + Buildx + Compose
      ↓
Trivy + Git
      ↓
Symfony Demo
      ↓
Dockerfile inicial
      ↓
Build / Layers / Cache
      ↓
Multi-stage + assets de produção
      ↓
Hardening / Secrets
      ↓
HEALTHCHECK / Recursos / Logging
      ↓
Scan
      ↓
Tag / Digest / Registry
      ↓
Compose single-host
      ↓
Deploy 1.0.0
      ↓
Ver aplicação no PC
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

# 1. Preparar a VM Ubuntu Server

## 1.1. Atualizar o catálogo de pacotes

```bash
sudo apt update
```

- `sudo` — executa com privilégios administrativos;
- `apt` — gestor de pacotes do Ubuntu;
- `update` — atualiza o catálogo dos repositórios configurados.

> `apt update` não atualiza os programas instalados; atualiza apenas a informação disponível para o APT.

A atualização global dos pacotes pode ser realizada na preparação da VM:

```bash
sudo apt upgrade -y
```

- `upgrade` — atualiza pacotes já instalados;
- `-y` — responde automaticamente `yes` às confirmações.

> **Nota de tempo:** `apt upgrade` não é um requisito específico da instalação Docker e pode demorar. Se a VM foi preparada imediatamente antes da sessão, esta operação deve preferencialmente ser concluída fora dos 240 minutos de formação.

Instalar ferramentas base:

```bash
sudo apt install -y ca-certificates curl git
```

- `ca-certificates` — permite validar certificados TLS/HTTPS;
- `curl` — cliente HTTP/HTTPS;
- `git` — obtém e atualiza os materiais da formação.

---

## 1.2. Remover pacotes que podem entrar em conflito

Seguir a abordagem indicada pela documentação Docker para Ubuntu:

```bash
sudo apt remove $(dpkg --get-selections \
  docker.io docker-compose docker-compose-v2 docker-doc \
  podman-docker containerd runc 2>/dev/null | cut -f1)
```

### O que acontece

- `dpkg --get-selections` — consulta pacotes conhecidos pelo sistema;
- `2>/dev/null` — descarta mensagens de erro não relevantes desta consulta;
- `|` — envia a saída para o comando seguinte;
- `cut -f1` — mantém apenas o nome de cada pacote;
- `apt remove` — remove os pacotes encontrados.

É normal o APT indicar que não existem pacotes conflituantes numa VM limpa.

---

## 1.3. Adicionar a chave oficial Docker

Criar a diretoria para chaves APT:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Obter a chave:

```bash
sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

| Flag | Função |
|---|---|
| `-f` | termina com erro perante HTTP 4xx/5xx |
| `-s` | modo silencioso |
| `-S` | mostra erros apesar de `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava a resposta no ficheiro indicado |

---

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

- `tee` — grava a entrada recebida num ficheiro;
- `<<EOF ... EOF` — *here-document*, permite fornecer várias linhas;
- `$(...)` — executa um comando e substitui pelo resultado;
- `dpkg --print-architecture` — devolve a arquitetura do sistema.

---

## 1.5. Instalar Docker Engine

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
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

- **Docker CLI** — o comando `docker` usado pelo operador;
- **Docker Engine** — gere imagens, containers, redes e volumes;
- **containerd** — gere o ciclo de vida dos containers;
- **runc** — runtime OCI de baixo nível;
- **Buildx/BuildKit** — funcionalidades modernas de build;
- **Docker Compose** — descreve aplicações multi-container.

---

## 1.6. Validar a instalação

```bash
sudo systemctl status docker --no-pager
sudo docker run --rm hello-world
sudo docker version
sudo docker compose version
sudo docker buildx version
```

Se o serviço não estiver ativo:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

---

## 1.7. Usar Docker sem `sudo` na VM de laboratório

```bash
sudo usermod -aG docker "$USER"
exit
```

Volte a ligar por PuTTY/SSH e confirme:

```bash
groups
docker run --rm hello-world
```

> **Segurança:** o grupo `docker` concede privilégios muito elevados sobre o host. É aceitável aqui como conveniência de uma VM isolada de laboratório, não como regra universal de hardening.

---

# 2. Instalar Trivy

Trivy será usado para analisar vulnerabilidades conhecidas na imagem.

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

> A primeira análise Trivy pode demorar mais devido à obtenção/atualização das bases de vulnerabilidades.

---

# 3. Obter os recursos e preparar a aplicação

Primeira utilização:

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

Se já existir uma cópia:

```bash
cd ~/formacao-kubernetes
git pull
cd sessao-03
```

> Não use `sudo git pull` numa cópia que pertence ao próprio utilizador; isso pode criar ficheiros com ownership incorreto.

Confirmar a diretoria:

```bash
pwd
test -f formando/docker/Dockerfile && echo "OK: Dockerfile disponível"
test -x comum/prepare-source.sh && echo "OK: prepare-source disponível"
```

Preparar a Symfony Demo:

```bash
./comum/prepare-source.sh
```

O script obtém a versão `v3.1.0` da Symfony Demo e aplica os endpoints pedagógicos:

```text
/info   → versão e ambiente
/health → saúde básica
/ready  → prontidão incluindo PostgreSQL
```

> **Atenção:** `prepare-source.sh` recria a diretoria `app/`. Não faça alterações que pretenda conservar dentro de `app/` antes de o voltar a executar.

Validar:

```bash
test -f app/composer.json && echo "OK: source preparado"
```

---

# 4. Construir a primeira imagem

Abrir o Dockerfile inicial:

```bash
less formando/docker/Dockerfile.inicial
```

> A imagem base `php:8.4-apache-bookworm` já contém PHP e Apache. O bloco `apt-get install` do Dockerfile instala ferramentas/bibliotecas adicionais e as dependências necessárias para compilar extensões PHP; não está a instalar o Apache de raiz.

## 4.1. Porque também temos de preparar os assets?

A Symfony Demo utiliza **AssetMapper**, **ImportMap** e **Sass**. Uma aplicação web não é composta apenas pelo código PHP: o browser também necessita de CSS, JavaScript, fontes e outros recursos frontend.

Para um artefacto de deployment, queremos que os assets versionados estejam preparados em `public/assets/` e possam ser servidos diretamente pelo Apache.

```text
Código Symfony
      ↓
composer install
      ↓
importmap / dependências frontend
      ↓
sass:build
      ↓
asset-map:compile
      ↓
public/assets/
      ↓
Apache serve CSS/JS ao browser
```

No `Dockerfile.inicial`, a imagem continua deliberadamente simples e single-stage; o objetivo é ficar funcional, não ainda otimizada.

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
| `.` | usa a diretoria atual como build context |

### Build context e `.dockerignore`

Como o contexto é `sessao-03/`, o ficheiro efetivamente usado neste build é:

```text
sessao-03/.dockerignore
```

Consultar:

```bash
cat .dockerignore
```

Consultar imagem e layers:

```bash
docker image ls symfony-demo
docker history symfony-demo:naive
```

## 4.2. Confirmar que os assets foram compilados

```bash
docker run --rm symfony-demo:naive \
  sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets compilados"'
```

**Output esperado (exemplo):**

```text
OK: assets compilados
```

O `manifest.json` é uma evidência simples de que o AssetMapper produziu o conjunto de assets para runtime.

## 4.3. Testar a imagem inicial isoladamente

Para manter o container disponível durante os testes no browser, nesta fase **não usamos `--rm`**:

```bash
docker run -d \
  --name symfony-naive \
  -p 8081:80 \
  symfony-demo:naive
```

- `-d` — executa em background;
- `--name` — atribui um nome ao container;
- `-p 8081:80` — publica a porta `80` do container na porta `8081` da VM.

Validar primeiro dentro da VM:

```bash
curl -i http://localhost:8081/health
```

**Output esperado (excerto):**

```text
HTTP/1.1 200 OK
...
{"status":"ok"}
```

Neste teste isolado não existe PostgreSQL. Por isso, `/health` é o endpoint mais adequado. O endpoint `/ready` poderá indicar indisponibilidade porque valida também a dependência da base de dados.

Confirmar também os assets no container:

```bash
docker exec symfony-naive \
  find /var/www/html/public/assets -maxdepth 2 -type f | head -20
```

### Ver a aplicação no navegador do PC do formando

Obter o endereço IP da VM:

```bash
hostname -I
```

Se forem apresentados vários endereços, utilize o mesmo IP que o formando usa no PuTTY/SSH, desde que corresponda à interface acessível a partir do PC.

Confirmar a publicação:

```bash
docker ps --filter "name=symfony-naive" \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Deverá observar algo equivalente a:

```text
symfony-naive   Up ...   0.0.0.0:8081->80/tcp
```

No PC:

```text
http://IP_DA_VM:8081/
http://IP_DA_VM:8081/health
```

A página principal deve surgir com a apresentação gráfica completa.

> **Diagnóstico aprendido no teste real:** se o HTML abrir mas a página aparecer sem estilos, não conclua imediatamente que existe um problema de rede. Primeiro confirme se `public/assets/` existe e se contém CSS/JS. Uma aplicação pode responder `200` em `/health` e, ainda assim, estar incompleta do ponto de vista do browser por falta de assets no artefacto.

```text
Browser no PC
      ↓ HTTP :8081
IP da VM
      ↓ porta publicada pelo Docker
8081 da VM
      ↓ -p 8081:80
80 do container
      ↓
Apache + Symfony + assets compilados
```

> O acesso por PuTTY confirma conectividade PC → VM, mas não garante por si só que a porta `8081` esteja permitida pela rede/firewall.

Depois da validação:

```bash
docker stop symfony-naive
docker rm symfony-naive
```

Esta separação permite observar a diferença entre parar e remover um container.

---

# 5. Cache, multi-stage e assets de produção

Construir a imagem otimizada `1.0.0`:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

- `--build-arg` — fornece um valor a uma instrução `ARG`;
- `ARG` é adequado a parametrização de build, **não a secrets**.

Construir `1.1.0`:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Procure `CACHED` na saída. A ordenação do Dockerfile permite reutilizar layers quando os ficheiros de dependências não mudam.

O Dockerfile multi-stage não tem apenas de instalar dependências PHP. O stage de build também prepara os assets antes de copiar a aplicação para o runtime:

```text
STAGE build
  ↓ Composer + dependências
  ↓ sass:build
  ↓ asset-map:compile
  ↓ public/assets/
  ↓
COPY --from=build
  ↓
STAGE runtime
  ↓ aplicação + assets já preparados
```

Consultar no Dockerfile:

```bash
grep -nE 'sass:build|asset-map:compile|manifest.json' \
  formando/docker/Dockerfile
```

O build deve falhar se `public/assets/manifest.json` não for criado. Isto evita publicar uma imagem que esteja saudável ao nível de `/health`, mas incompleta no browser.

## 5.1. Validar os assets das imagens otimizadas

```bash
for VERSION in 1.0.0 1.1.0; do
  echo "=== $VERSION ==="
  docker run --rm "symfony-demo:$VERSION" \
    sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets compilados"'
done
```

Resultado esperado:

```text
=== 1.0.0 ===
OK: assets compilados
=== 1.1.0 ===
OK: assets compilados
```

Pode observar alguns ficheiros:

```bash
docker run --rm symfony-demo:1.1.0 \
  sh -lc 'find /var/www/html/public/assets -maxdepth 2 -type f | head -20'
```

Comparar tamanhos e histórico:

```bash
docker image ls symfony-demo
docker history symfony-demo:1.1.0
```

Na validação técnica, a imagem `naive` ocupou cerca de `1.16 GB` de disk usage e a imagem multi-stage cerca de `916 MB`. Estes números são apenas ilustrativos e podem mudar com a imagem base e as versões das dependências.

Ver metadata:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format 'Version={{index .Config.Labels "org.opencontainers.image.version"}} Source={{index .Config.Labels "org.opencontainers.image.source"}}'
```

Só depois observe a automação:

```bash
sed -n '1,220p' formando/scripts/build.sh
```

---

# 6. Hardening e secrets

## 6.1. O que é hardening?

**Hardening** é o processo de reduzir a superfície de ataque de um sistema e limitar o impacto de uma eventual falha ou comprometimento. Não corresponde a uma única configuração: resulta da combinação de várias medidas.

```text
Mais componentes + mais privilégios + mais credenciais expostas
                        ↓
                 maior superfície de ataque

Menos componentes + menor privilégio + secrets protegidos
                        ↓
                 menor superfície de ataque
```

Neste laboratório aplicamos apenas uma parte dessas medidas:

- reduzir componentes desnecessários na imagem final através de multi-stage;
- separar ferramentas de build do runtime;
- limitar os diretórios que necessitam de escrita;
- não colocar secrets diretamente na imagem;
- aplicar limites de recursos;
- analisar vulnerabilidades conhecidas com Trivy.

Hardening é uma prática contínua e não uma garantia de que a imagem ficou “segura”.

## 6.2. O que é um secret?

Um **secret** é informação sensível que não deve ser exposta no código, imagem, logs, histórico de comandos ou configuração partilhada sem necessidade.

```text
Configuração normal
APP_ENV=prod
APP_PORT=8080

Secret
DB_PASSWORD=...
API_TOKEN=...
PRIVATE_KEY=...
```

```text
Build secret
   ↓
necessário apenas durante o build
   ↓
não deve chegar à imagem final

Runtime secret
   ↓
necessário quando a aplicação está a correr
   ↓
deve ser entregue apenas ao serviço que dele precisa
```

## 6.3. Limites do hardening deste laboratório

O Dockerfile otimizado reduz componentes no runtime através de multi-stage e limita diretórios de escrita. Contudo, **não deve ser apresentado como uma imagem completamente non-root**.

```bash
docker image inspect symfony-demo:1.1.0 \
  --format 'User={{json .Config.User}}'
```

Um valor vazio significa que não existe uma instrução `USER` explícita na imagem final. A conversão deste cenário para um runtime integralmente non-root exige alterações adicionais e fica fora do laboratório principal.

---

## 6.4. Demonstrar o que NÃO fazer com secrets

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Observar a configuração final:

```bash
docker image inspect secret-demo:bad \
  --format '{{json .Config.Env}}'
```

**Output esperado (exemplo):**

```text
SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data ...

["PATH=...","API_TOKEN=segredo-falso-lab"]
```

O ponto importante não é a redação exata do warning: é confirmar que o valor sensível ficou persistido em `Config.Env`.

Também pode consultar:

```bash
docker history --no-trunc secret-demo:bad
```

```text
ARG / ENV no Dockerfile
        ≠
forma segura de transportar secrets
```

---

## 6.5. BuildKit secret com origem no ambiente do host

```bash
read -rsp 'API_TOKEN fictício: ' API_TOKEN
echo
export API_TOKEN
```

Construir:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=API_TOKEN,env=API_TOKEN \
  -t secret-demo:buildkit \
  formando/exemplos/secrets
```

Validar que não foi persistido como variável da imagem:

```bash
docker image inspect secret-demo:buildkit \
  --format '{{json .Config.Env}}'
```

Executar e limpar:

```bash
docker run --rm secret-demo:buildkit
unset API_TOKEN
```

**Output esperado (exemplo):**

```text
Config.Env:
["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]

Secret disponível apenas durante esta instrução RUN
```

Repare que `API_TOKEN` não aparece em `Config.Env`.

> BuildKit também suporta ficheiros como origem de secrets (`src=...`). O que não deve ser feito é criar e versionar ficheiros de texto com passwords/tokens dentro do projeto.

---

## 6.6. Compose secret com origem no ambiente do host

```bash
read -rsp 'DEMO_SECRET fictício: ' DEMO_SECRET
echo
export DEMO_SECRET
```

O exemplo Compose declara:

```yaml
secrets:
  demo_secret:
    environment: DEMO_SECRET
```

E concede o secret ao serviço:

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
  run --rm demo
```

No container, o secret é entregue em:

```text
/run/secrets/demo_secret
```

**Output esperado (exemplo):**

```text
total 4
-r--r--r-- ... demo_secret
21 /run/secrets/demo_secret
```

O tamanho pode variar com o valor introduzido. O que deve ser confirmado é a existência do ficheiro montado e não a impressão do seu conteúdo.

Limpar:

```bash
unset DEMO_SECRET
```

> Uma variável de ambiente no host também não é um secret manager. Aqui serve apenas como origem temporária para demonstrar o mecanismo.

---

# 7. HEALTHCHECK e controlos operacionais

Consultar o healthcheck da imagem:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format '{{json .Config.Healthcheck}}'
```

Preparar o ficheiro de configuração:

```bash
cp formando/compose/.env.prod.example \
   formando/compose/.env.prod
```

> `.env.prod` está ignorado pelo Git e contém apenas valores fictícios do laboratório. `.env` não é um secret manager.

Pode alterar a porta publicada se `8080` estiver ocupada:

```text
APP_PORT=8080
```

Validar a configuração final:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

O override de produção do laboratório inclui:

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

Os resultados dependem da data das bases de vulnerabilidades e da imagem analisada. Não existe uma contagem fixa esperada.

**Output esperado (exemplo observado na validação de 2026-09-10):**

```text
Report Summary

symfony-demo:1.1.0 (debian 12.15)        66 vulnerabilidades
composer-vendor                           8 vulnerabilidades

Debian:   HIGH: 66, CRITICAL: 0
Composer: HIGH: 8,  CRITICAL: 0
```

> Estes números **não são um critério de sucesso** e irão mudar. O objetivo é conseguir identificar o alvo analisado, a severidade, a versão instalada e, quando indicada, a versão que contém a correção.

> Um scan não prova que uma imagem é segura. É uma das evidências do processo de segurança.

---

# 9. Tag, digest e registry

## 9.1. O que é um registry?

Um container registry armazena e distribui imagens.

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
│       │          │            │
registry namespace repositório   tag
```

Criar uma segunda tag local:

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
Digest → identidade imutável daquele conteúdo publicado
```

---

## 9.2. Consumir imagens públicas do GHCR

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

As imagens públicas da formação podem ser obtidas anonimamente.

Confirmar que o artefacto público inclui assets:

```bash
docker run --rm ghcr.io/skullclamp/symfony-demo:1.0.0 \
  sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets presentes no artefacto do registry"'
```

---

## 9.3. Publicar opcionalmente no namespace do formando

Esta etapa é útil para praticar autenticação/tag/push, mas pode ser omitida se o tempo for insuficiente.

```bash
export GITHUB_USER='UTILIZADOR_GITHUB'
export MY_IMAGE_REPO="ghcr.io/${GITHUB_USER}/symfony-demo"
```

> Usamos `MY_IMAGE_REPO` deliberadamente para não interferir com `IMAGE_REPO` da stack de produção.

Autenticar sem colocar o token na linha de comandos:

```bash
read -rsp 'GHCR token: ' CR_PAT
echo
printf '%s' "$CR_PAT" \
  | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
unset CR_PAT
```

Publicar:

```bash
docker tag symfony-demo:1.0.0 "$MY_IMAGE_REPO:1.0.0"
docker push "$MY_IMAGE_REPO:1.0.0"
```

Consultar digest:

```bash
docker image inspect "$MY_IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

No final:

```bash
docker logout ghcr.io
unset GITHUB_USER MY_IMAGE_REPO
```

```text
BUILD ONCE
   ↓
Imagem identificada
   ↓
Validar assets + health
   ↓
Scan
   ↓
Registry
   ↓
promover o mesmo artefacto
```

## 9.4. Validação técnica das três imagens do cenário

> **Nota:** esta validação completa é especialmente útil ao formador na preparação do laboratório. Os formandos podem executá-la se houver tempo. O objetivo é impedir que uma falha acidental do artefacto seja confundida com a falha controlada da `1.2.0-rc1`.

Construir através da automação já observada:

```bash
./formando/scripts/build.sh 1.0.0
./formando/scripts/build.sh 1.1.0
./formando/scripts/build.sh 1.2.0-rc1 /healthz
```

Validar assets nas três imagens:

```bash
for VERSION in 1.0.0 1.1.0 1.2.0-rc1; do
  echo "=== $VERSION ==="
  docker run --rm "symfony-demo:$VERSION" \
    sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets compilados"'
done
```

Confirmar a variável usada pelo healthcheck:

```bash
for VERSION in 1.0.0 1.1.0 1.2.0-rc1; do
  echo "=== $VERSION ==="
  docker image inspect "symfony-demo:$VERSION" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep HEALTH_PATH
done
```

Esperado:

```text
1.0.0       → HEALTH_PATH=/health
1.1.0       → HEALTH_PATH=/health
1.2.0-rc1   → HEALTH_PATH=/healthz
```

Se pretender observar isoladamente os três estados, utilize portas temporárias livres:

```bash
docker rm -f test-100 test-110 test-120 2>/dev/null || true

docker run -d --name test-100 -p 8083:80 symfony-demo:1.0.0
docker run -d --name test-110 -p 8084:80 symfony-demo:1.1.0
docker run -d --name test-120 -p 8085:80 symfony-demo:1.2.0-rc1
```

Após o tempo necessário para os healthchecks:

```bash
docker ps --filter "name=test-" \
  --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Esperado:

```text
test-100   symfony-demo:1.0.0       healthy
test-110   symfony-demo:1.1.0       healthy
test-120   symfony-demo:1.2.0-rc1   unhealthy
```

Confirmar a causa da RC:

```bash
curl -i http://localhost:8085/health
curl -i http://localhost:8085/healthz

docker inspect test-120 \
  --format '{{json .State.Health}}'
```

Evidência esperada:

```text
/health  → 200 OK
/healthz → 404 Not Found
Docker HEALTHCHECK → ExitCode 1 → unhealthy
```

Isto demonstra uma distinção importante:

```text
Aplicação responde corretamente em /health
                  ≠
HEALTHCHECK corretamente configurado
```

A `1.2.0-rc1` continua capaz de responder à aplicação; é a configuração do healthcheck que está deliberadamente errada.

Limpar os containers temporários:

```bash
docker rm -f test-100 test-110 test-120
```

### Digests dos artefactos oficiais validados em 2026-09-10

| Tag | Digest publicado e validado |
|---|---|
| `1.0.0` | `sha256:4dd023c33ce80368410a322a507461aabe19425e9e61ed13b404ef1083071924` |
| `1.1.0` | `sha256:e45279848fa5adc50beaa0dbfdc632beeaea6d6a1e9a651ae38fc5c30f7778f5` |
| `1.2.0-rc1` | `sha256:41b684658cca6907fd3111cf2b4cd85eaf3426fded719f02265d8d531cb24bef` |

> Estes valores identificam os artefactos publicados e testados nesta preparação. Uma tag pode ser movida/republicada e, nesse caso, passar a apontar para outro digest. O digest identifica imutavelmente aquele conteúdo concreto.

---

# 10. Primeiro deployment manual da stack

Para manter a regra **manual → observar → automatizar**, execute manualmente as fases essenciais do primeiro deployment.

## 10.1. Garantir que o ponto inicial é 1.0.0

Se a VM já tiver sido usada em testes anteriores, confirme:

```bash
grep '^APP_VERSION=' formando/compose/.env.prod
```

Para o início deste exercício deverá ser:

```text
APP_VERSION=1.0.0
```

Se necessário:

```bash
sed -i 's/^APP_VERSION=.*/APP_VERSION=1.0.0/' \
  formando/compose/.env.prod
```

> Esta reposição é importante numa VM reutilizada: o laboratório deve começar em `1.0.0` para que a progressão `1.0.0 → 1.1.0 → 1.2.0-rc1 → rollback 1.1.0` seja observável.

Validar configuração:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config >/dev/null
```

Obter as imagens:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  pull db app
```

Iniciar PostgreSQL:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d db
```

Consultar estado:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

Aguarde até `db` ficar `healthy`.

**Output esperado (exemplo):**

```text
NAME           IMAGE         SERVICE   STATUS
compose-db-1   postgres:16   db        Up ... (healthy)
```

## 10.2. Inicializar o schema apenas numa base de dados vazia

Verificar se a tabela principal já existe:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec -T db \
  psql -U symfony -d symfony -tAc \
  "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='symfony_demo_post';"
```

Se não devolver `1`, e apenas por se tratar de uma base vazia de laboratório:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  run --rm app \
  php bin/console doctrine:schema:create --no-interaction
```

> **Produção real:** alterações de schema devem ser tratadas através de migrações versionadas, compatíveis e controladas. `doctrine:schema:create` é usado apenas para inicializar uma base vazia do laboratório.

Iniciar a aplicação:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Agora observe o wrapper:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
```

---

# 11. Validar e ver a aplicação no PC do formando

Na VM:

```bash
./formando/scripts/compose-prod.sh ps
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

Se alterou `APP_PORT`, substitua `8080` pela porta escolhida.

No ponto inicial, a evidência esperada é equivalente a:

```text
/health → 200 {"status":"ok"}
/ready  → 200 {"status":"ready","database":"ok"}
/info   → 200 ... "version":"1.0.0" ... "environment":"prod"
```

Para uma validação mais rigorosa pode usar:

```bash
./formando/scripts/validate.sh 1.0.0
```

**Output esperado (exemplo):**

```text
==> GET /health
{"status":"ok"}
==> GET /ready
{"status":"ready","database":"ok"}
==> GET /info
{"application":"symfony-demo","version":"1.0.0","environment":"prod",...}
Versão da aplicação confirmada: 1.0.0
Imagem em execução: ghcr.io/skullclamp/symfony-demo:1.0.0
health=healthy
Image=ghcr.io/skullclamp/symfony-demo:1.0.0 Memory=536870912 NanoCpus=1000000000 Restart=unless-stopped
```

Obter o container da aplicação:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar health e recursos:

```bash
docker inspect "$CID" --format '{{json .State.Health}}'
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
docker stats --no-stream "$CID"
```

Confirmar ainda que os assets existem no próprio container recebido do registry:

```bash
docker exec "$CID" \
  sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets no container em execução"'
```

**Output esperado:**

```text
OK: assets no container em execução
```

## 11.1. Acesso pelo browser do PC

```bash
hostname -I
```

Confirmar publicação:

```bash
docker ps --filter "id=$CID" \
  --format 'table {{.Names}}\t{{.Ports}}'
```

Deverá existir uma publicação equivalente a:

```text
0.0.0.0:8080->80/tcp
```

No PC:

```text
http://IP_DA_VM:8080
http://IP_DA_VM:8080/info
http://IP_DA_VM:8080/health
http://IP_DA_VM:8080/ready
```

A página principal deve aparecer com CSS/JS carregados. Se o HTML surgir sem estilos, execute primeiro a validação de `public/assets/manifest.json` e consulte os logs/pedidos dos assets. Não confunda uma falha de preparação do artefacto com uma falha de conectividade.

> Como o formando já acede à VM por PuTTY/SSH, existe conectividade PC → VM. Contudo, a porta publicada também tem de ser permitida pela rede e pelas políticas do ambiente.

> **Nota de firewall Docker:** não assuma que `ufw allow 8080/tcp` controla uma porta publicada pelo Docker. Valide primeiro `docker ps`, o IP/rota da VM e as regras de rede/firewall do ambiente.

---

# 12. Persistência e backup

Criar um marcador:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "CREATE TABLE IF NOT EXISTS lab_marker(id serial primary key, note text);"
```

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

**Output esperado (exemplo):**

```text
 id |     note
----+--------------
  1 | antes-update
```

Backup lógico manual:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  pg_dump -U symfony -d symfony \
  > backup.sql
```

Validar:

```bash
ls -lh backup.sql
test -s backup.sql && echo "OK: backup não vazio"
```

**Output esperado:**

```text
... backup.sql
OK: backup não vazio
```

O tamanho exato do ficheiro depende do conteúdo atual da base de dados.

```text
Persistência ≠ Backup
```

Só depois observe a automação:

```bash
sed -n '1,220p' formando/scripts/backup-postgres.sh
```

---

# 13. Automatizar deployment, update, falha e rollback

Agora já foram executadas manualmente as fases fundamentais. Pode analisar e usar a automação.

```bash
sed -n '1,300p' formando/scripts/deploy-prod.sh
```

Executar novamente a versão inicial através da automação:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
./formando/scripts/validate.sh 1.0.0
```

---

## 13.1. Update para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar explicitamente a versão pretendida:

```bash
./formando/scripts/validate.sh 1.1.0
curl -fsS http://localhost:8080/info
./formando/scripts/compose-prod.sh ps
```

**Output esperado (exemplo):**

```text
==> GET /info
{"application":"symfony-demo","version":"1.1.0","environment":"prod",...}
Versão da aplicação confirmada: 1.1.0
Imagem em execução: ghcr.io/skullclamp/symfony-demo:1.1.0
health=healthy
Image=ghcr.io/skullclamp/symfony-demo:1.1.0 Memory=536870912 NanoCpus=1000000000 Restart=unless-stopped
```

O objetivo é confirmar simultaneamente **versão lógica da aplicação**, **imagem do container** e **estado do healthcheck**. Um endpoint `200` isolado não prova que o update foi realmente aplicado.

Confirmar que o artefacto atualizado continua a conter assets:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker exec "$CID" \
  sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets preservados no update"'
```

Confirmar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

A substituição do container da aplicação não deve eliminar o conteúdo do volume PostgreSQL.

No browser, atualize `http://IP_DA_VM:8080/`. A aplicação deve continuar graficamente completa.

---

## 13.2. Introduzir a falha controlada 1.2.0-rc1

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e
echo "EXIT_CODE=$RC"
```

A `1.2.0-rc1` foi preparada deliberadamente com:

```text
HEALTH_PATH=/healthz
```

A aplicação continua a disponibilizar `/health`; a falha está no caminho escolhido pelo Docker `HEALTHCHECK`.

**Output esperado (excerto):**

```text
==> Aplicação 1.2.0-rc1
...
==> GET /info
{"application":"symfony-demo","version":"1.2.0-rc1","environment":"prod",...}
Versão da aplicação confirmada: 1.2.0-rc1
Imagem em execução: ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
==> A aguardar Docker HEALTHCHECK
health=starting
...
health=unhealthy
ERRO: aplicação sem estado healthy.
EXIT_CODE=1
```

> Aqui `EXIT_CODE=1` é **esperado**, mas só é considerado a falha correta depois de confirmar a causa na secção seguinte. Um comando falhar por outro motivo — por exemplo conflito de porta ou erro de pull — não valida o cenário pedagógico.

---

## 13.3. Diagnosticar antes do rollback

```bash
./formando/scripts/compose-prod.sh ps
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" --format '{{json .State.Health}}'
./formando/scripts/compose-prod.sh logs --tail 100 app
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

Confirmar também a configuração:

```bash
docker inspect "$CID" \
  --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep HEALTH_PATH
```

**Output esperado (exemplo validado):**

```text
Imagem:        ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
/info:         ... "version":"1.2.0-rc1" ...
/health:       200
/healthz:      404
Docker health: unhealthy
```

No detalhe do healthcheck deverá observar algo equivalente a:

```text
"Status":"unhealthy"
"ExitCode":1
curl: (22) The requested URL returned error: 404
```

A evidência completa deve permitir concluir:

```text
HEALTH_PATH=/healthz
/health  → 200 OK
/healthz → 404 Not Found
healthcheck → ExitCode 1
container → unhealthy
```

A conclusão correta é:

```text
A aplicação não deixou de responder.
O healthcheck é que está configurado para um endpoint inexistente.
```

Não faça rollback antes de conseguir explicar esta evidência.

---

## 13.4. Rollback para 1.1.0

Abrir o script:

```bash
sed -n '1,220p' formando/scripts/rollback.sh
```

Executar:

```bash
./formando/scripts/rollback.sh 1.1.0
./formando/scripts/validate.sh 1.1.0
```

Confirmar versão, saúde e dados:

```bash
curl -fsS http://localhost:8080/info
./formando/scripts/compose-prod.sh ps
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

**Output esperado (exemplo):**

```text
Rollback para versão conhecida como boa: 1.1.0
...
==> GET /info
{"application":"symfony-demo","version":"1.1.0","environment":"prod",...}
Versão da aplicação confirmada: 1.1.0
Imagem em execução: ghcr.io/skullclamp/symfony-demo:1.1.0
health=healthy
```

A consulta a `lab_marker` deve continuar a devolver o registo criado antes do update. Isto demonstra que o rollback da aplicação não elimina os dados persistentes no volume PostgreSQL.

No browser, `http://IP_DA_VM:8080/` deve voltar a apresentar a aplicação completa a partir da `1.1.0`.

Resultado:

```text
1.0.0
   ↓ deployment válido
1.1.0
   ↓ update válido
1.2.0-rc1
   ↓ aplicação responde em /health
   ↓ HEALTHCHECK usa /healthz → 404
   ↓ unhealthy
Diagnóstico
   ↓
Rollback 1.1.0
   ↓
healthy + assets OK + dados preservados
```

---

# 14. Limites do cenário

Este é um deployment **single-host**:

```text
Host Docker
   ↓
Docker Compose
   ↓
app + db
```

Se o host falhar, os serviços ficam indisponíveis.

```text
restart policy ≠ Alta Disponibilidade
Compose single-host ≠ Kubernetes
```

A sessão seguinte introduz precisamente a necessidade de orquestração distribuída.

---

# 15. Mensagens a reter

```text
Imagem ≠ Container
Build context ≠ diretoria do Dockerfile
Aplicação HTTP healthy ≠ artefacto web completo
HTML sem CSS/JS → verificar public/assets antes de culpar a rede
Multi-stage deve transportar também os assets preparados para o runtime
ARG/ENV ≠ Secret Manager
.env de projeto ≠ Secret Manager
BuildKit secret é temporário durante o build
Docker HEALTHCHECK ≠ Kubernetes Probe
Aplicação a responder ≠ HEALTHCHECK corretamente configurado
Tag ≠ Digest
Persistência ≠ Backup
Build Once → Validate → Promote the Same Artifact
Compose Single-host ≠ Alta Disponibilidade
Diagnosticar → só depois corrigir/rollback
```
