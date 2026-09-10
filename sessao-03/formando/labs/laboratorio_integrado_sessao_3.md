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
Multi-stage
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

- `install -d` — cria uma diretoria;
- `-m 0755` — define as permissões da diretoria.

Obter a chave:

```bash
sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
```

| Flag | Função |
|---|---|
| `-f` | termina com erro perante HTTP 4xx/5xx |
| `-s` | modo silencioso |
| `-S` | mostra erros apesar de `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava a resposta no ficheiro indicado |

Tornar a chave legível pelo APT:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

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

- `--no-pager` — mostra a saída diretamente no terminal;
- `--rm` — remove o container quando o processo termina.

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

- `-a` — adiciona sem remover os grupos atuais;
- `-G docker` — adiciona ao grupo suplementar `docker`.

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

- `wget -qO -` — obtém conteúdo e envia-o para stdout;
- `|` — encadeia a saída de um comando com a entrada do seguinte;
- `gpg --dearmor` — converte a chave para o formato utilizado pelo APT;
- `> /dev/null` — descarta a cópia da saída produzida por `tee`.

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

### Porque também temos de preparar os assets?

A Symfony Demo atual utiliza **AssetMapper**, **ImportMap** e **Sass**. Uma aplicação web não é composta apenas pelo código PHP: o browser também necessita de CSS, JavaScript, fontes e outros recursos frontend.

Em desenvolvimento, o Symfony pode servir assets dinamicamente. Para uma imagem usada como artefacto de deployment, queremos que os assets versionados sejam compilados para `public/assets/` e servidos diretamente pelo servidor web.

A sequência relevante é:

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

No `Dockerfile.inicial` o bloco de instalação executa os auto-scripts do Composer e, de forma explícita, compila Sass antes de executar `asset-map:compile`. A imagem inicial continua a ser deliberadamente simples e single-stage; o objetivo aqui é ficar funcional, não ainda otimizada.

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

O contexto é o conjunto de ficheiros disponibilizado ao builder. Como o contexto é `sessao-03/`, o ficheiro efetivamente usado neste build é:

```text
sessao-03/.dockerignore
```

Consultar:

```bash
cat .dockerignore
```

O objetivo é excluir `.git`, caches, ficheiros locais e outros dados desnecessários do contexto de build.

Consultar imagem e layers:

```bash
docker image ls symfony-demo
docker history symfony-demo:naive
```

### Confirmar que os assets foram compilados

Antes de executar a imagem, pode confirmar diretamente no artefacto que `public/assets/` existe:

```bash
docker run --rm symfony-demo:naive \
  sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo "OK: assets compilados"'
```

O `manifest.json` é produzido pela compilação do AssetMapper e relaciona os nomes lógicos dos assets com os ficheiros versionados.

### Testar a imagem inicial isoladamente

Para manter o container disponível durante os testes no browser, nesta fase **não usamos `--rm`**:

```bash
docker run -d \
  --name symfony-naive \
  -p 8081:80 \
  symfony-demo:naive
```

- `-d` — executa em background;
- `--name` — atribui um nome ao container;
- `-p 8081:80` — publica a porta `80` do container na porta `8081` da VM;
- como não foi indicado um endereço específico antes de `8081`, o Docker publica normalmente a porta nas interfaces do host, permitindo acesso externo se a rede e a firewall o autorizarem.

Validar primeiro dentro da VM, sem depender da rede externa:

```bash
curl -i http://localhost:8081/health
```

Neste teste isolado não existe PostgreSQL. Por isso, `/health` é o endpoint mais adequado: permite confirmar que Apache e a aplicação arrancaram. O endpoint `/ready` poderá indicar indisponibilidade porque valida também a dependência da base de dados.

Confirmar também que os ficheiros frontend estão presentes dentro do container:

```bash
docker exec symfony-naive \
  find /var/www/html/public/assets -maxdepth 2 -type f | head -20
```

Deverá observar ficheiros CSS/JS versionados e os ficheiros de metadata do AssetMapper.

#### Ver a aplicação no navegador do PC do formando

Este é um bom momento para demonstrar o significado real de `-p 8081:80`: a porta da aplicação deixou de estar acessível apenas dentro do container e foi publicada na VM.

Obter o endereço IP da VM:

```bash
hostname -I
```

Se forem apresentados vários endereços, utilize o mesmo IP que o formando usa no PuTTY/SSH, desde que corresponda à interface de rede acessível a partir do PC.

Confirmar a publicação da porta:

```bash
docker ps --filter "name=symfony-naive" \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Deverá observar algo equivalente a:

```text
symfony-naive   Up ...   0.0.0.0:8081->80/tcp
```

No navegador do **PC do formando**, abrir:

```text
http://IP_DA_VM:8081/
```

Por exemplo, se o IP utilizado no PuTTY for `192.168.1.50`:

```text
http://192.168.1.50:8081/
```

Pode também validar diretamente o endpoint pedagógico:

```text
http://IP_DA_VM:8081/health
```

A página principal deve surgir com a apresentação gráfica completa. Se o HTML aparecer mas sem estilos, confirme primeiro se existem ficheiros em `/var/www/html/public/assets` e consulte os pedidos HTTP no browser/logs antes de atribuir o problema à rede.

O resultado desta experiência deve ser interpretado assim:

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

> O acesso por PuTTY confirma que existe conectividade entre o PC e a VM, mas não garante por si só que a porta `8081` esteja permitida. Se `curl http://localhost:8081/health` funcionar na VM mas o browser não conseguir aceder, o problema está provavelmente na conectividade/regras entre o PC e essa porta da VM, e não no build da imagem.

Depois da validação no browser, parar e remover o teste:

```bash
docker stop symfony-naive
docker rm symfony-naive
```

Esta separação permite observar a diferença entre parar um container e removê-lo explicitamente.

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

- `--build-arg` — fornece um valor a uma instrução `ARG`;
- `ARG` é adequado a parametrização de build, **não a secrets**.

Construir uma segunda versão:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Procure `CACHED` na saída. A ordenação do Dockerfile permite reutilizar layers quando os ficheiros de dependências não mudam.

```text
stage build
  ↓ ferramentas + Composer + dependências
COPY --from=build
  ↓
stage runtime
  ↓ apenas o necessário para executar
```

Comparar tamanhos e histórico:

```bash
docker image ls symfony-demo
docker history symfony-demo:1.1.0
```

Ver metadata criada no build:

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

O objetivo é perceber que hardening é uma prática contínua e não uma garantia de que a imagem ficou "segura".

## 6.2. O que é um secret?

Um **secret** é informação sensível que não deve ser exposta no código, imagem, logs, histórico de comandos ou configuração partilhada sem necessidade.

Exemplos:

```text
Configuração normal
APP_ENV=prod
APP_PORT=8080

Secret
DB_PASSWORD=...
API_TOKEN=...
PRIVATE_KEY=...
```

É útil distinguir dois momentos:

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

O Dockerfile otimizado reduz componentes no runtime através de multi-stage e limita os diretórios de escrita. Contudo, **não deve ser apresentado como uma imagem completamente non-root**.

Verificar:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format 'User={{json .Config.User}}'
```

Um valor vazio significa que não existe uma instrução `USER` explícita na imagem final. A imagem oficial Apache arranca com os privilégios necessários ao seu modelo de execução e os workers Apache usam o utilizador configurado pelo Apache. A conversão deste cenário para um runtime integralmente non-root exige alterações adicionais e fica fora do laboratório principal.

---

## 6.4. Demonstrar o que NÃO fazer com secrets

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Em vez de depender apenas de `docker history`, observe diretamente a configuração final da imagem:

```bash
docker image inspect secret-demo:bad \
  --format '{{json .Config.Env}}'
```

Também pode consultar:

```bash
docker history --no-trunc secret-demo:bad
```

> O detalhe apresentado pelo histórico pode variar com o builder. A evidência importante neste exemplo é que o valor passado para `ENV` fica na configuração final da imagem.

Conclusão:

```text
ARG / ENV no Dockerfile
        ≠
forma segura de transportar secrets
```

---

## 6.5. BuildKit secret com origem no ambiente do host

Para não escrever o valor do laboratório no histórico do shell, ler de forma silenciosa:

```bash
read -rsp 'API_TOKEN fictício: ' API_TOKEN
echo
export API_TOKEN
```

- `read` — lê input do utilizador;
- `-r` — não interpreta barras invertidas;
- `-s` — não mostra os caracteres introduzidos;
- `-p` — apresenta a mensagem de prompt;
- `export` — disponibiliza a variável aos processos filhos.

Construir:

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=API_TOKEN,env=API_TOKEN \
  -t secret-demo:buildkit \
  formando/exemplos/secrets
```

- `--secret` — fornece um secret ao BuildKit;
- `id=API_TOKEN` — identificador do secret;
- `env=API_TOKEN` — usa a variável de ambiente do host como origem;
- no Dockerfile, o secret é disponibilizado apenas na instrução `RUN` que o declara.

Validar que não foi persistido como variável da imagem:

```bash
docker image inspect secret-demo:buildkit \
  --format '{{json .Config.Env}}'
```

Executar o exemplo:

```bash
docker run --rm secret-demo:buildkit
```

Limpar a variável:

```bash
unset API_TOKEN
```

> BuildKit também suporta ficheiros como origem de secrets (`src=...`). Isso é apropriado quando a credencial já existe legitimamente como ficheiro, por exemplo uma configuração de cliente ou certificado. O que não deve ser feito é criar e versionar ficheiros de texto com passwords/tokens dentro do projeto.

---

## 6.6. Compose secret com origem no ambiente do host

Introduzir um valor fictício sem o escrever no histórico:

```bash
read -rsp 'DEMO_SECRET fictício: ' DEMO_SECRET
echo
export DEMO_SECRET
```

O exemplo Compose declara a origem:

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

- `run` — cria um container one-off para o serviço indicado;
- `--rm` — remove-o quando termina.

No container, o secret é entregue em:

```text
/run/secrets/demo_secret
```

A origem deste exemplo é uma variável no host; o conteúdo não é passado através do atributo `environment:` do serviço.

Limpar:

```bash
unset DEMO_SECRET
```

> Uma variável de ambiente no host também não é um secret manager. Aqui serve apenas como origem temporária para demonstrar o mecanismo Compose sem guardar o valor no repositório. Em produção, a origem normalmente seria integrada com mecanismos próprios de gestão de secrets.

---

# 7. HEALTHCHECK e controlos operacionais

Consultar o healthcheck da imagem:

```bash
docker image inspect symfony-demo:1.1.0 \
  --format '{{json .Config.Healthcheck}}'
```

Preparar o ficheiro de configuração do laboratório:

```bash
cp formando/compose/.env.prod.example \
   formando/compose/.env.prod
```

> `.env.prod` está ignorado pelo Git e contém **apenas valores fictícios do laboratório**. O facto de os usarmos aqui não transforma `.env` num secret manager e não deve ser reproduzido como modelo de gestão de credenciais reais.

Pode alterar a porta publicada se `8080` estiver ocupada:

```text
APP_PORT=8080
```

por exemplo:

```text
APP_PORT=8081
```

Validar a configuração final:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

> `docker compose config` apresenta a configuração resolvida. Com credenciais reais, evite copiar ou partilhar a saída sem rever informação sensível.

O override de produção do laboratório inclui:

```yaml
restart: unless-stopped
mem_limit: 512m
cpus: 1.0
logging:
  driver: local
```

- `restart: unless-stopped` — tenta voltar a iniciar o container, exceto depois de uma paragem manual explícita;
- `mem_limit` — limita memória;
- `cpus` — limita CPU;
- `logging.driver: local` — utiliza o driver local do Docker.

> Docker `HEALTHCHECK` não é convertido automaticamente em probes Kubernetes.

---

# 8. Scan com Trivy

Scan informativo:

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

- `image` — analisa uma imagem;
- `--scanners vuln` — procura vulnerabilidades;
- `--severity HIGH,CRITICAL` — filtra as severidades apresentadas;
- `--ignore-unfixed` — omite vulnerabilidades sem correção conhecida.

Os resultados dependem da data das bases de vulnerabilidades e da imagem analisada. Não existe uma contagem fixa esperada.

> Um scan não prova que uma imagem é segura. É uma das evidências do processo de segurança, juntamente com origem da imagem, minimização, configuração, patching e gestão de secrets.

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

## 9.2. Consumir uma imagem pública do GHCR

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

As imagens públicas da formação podem ser obtidas anonimamente.

---

## 9.3. Publicar opcionalmente no namespace do formando

Esta etapa é útil para praticar autenticação/tag/push, mas pode ser omitida se o tempo da sessão for insuficiente.

Definir variáveis próprias, sem reutilizar `IMAGE_REPO` da stack de produção:

```bash
export GITHUB_USER='UTILIZADOR_GITHUB'
export MY_IMAGE_REPO="ghcr.io/${GITHUB_USER}/symfony-demo"
```

> Usamos `MY_IMAGE_REPO` deliberadamente. O ciclo de deploy posterior utiliza `IMAGE_REPO` do ficheiro `.env.prod` e as imagens públicas da formação. Assim, um push pessoal incompleto não interfere com `1.1.0` ou `1.2.0-rc1`.

Para autenticar no GHCR, é necessário um Personal Access Token (classic) com permissões adequadas de packages. Para não escrever o token no histórico:

```bash
read -rsp 'GHCR token: ' CR_PAT
echo
printf '%s' "$CR_PAT" \
  | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
unset CR_PAT
```

- `--password-stdin` — recebe a credencial pela entrada standard em vez de a colocar como argumento da linha de comandos.

Criar a referência remota e publicar:

```bash
docker tag symfony-demo:1.0.0 "$MY_IMAGE_REPO:1.0.0"
docker push "$MY_IMAGE_REPO:1.0.0"
```

Consultar digest após publicação:

```bash
docker image inspect "$MY_IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

No final:

```bash
docker logout ghcr.io
unset GITHUB_USER MY_IMAGE_REPO
```

Princípio:

```text
BUILD ONCE
   ↓
Imagem identificada
   ↓
Scan
   ↓
Registry
   ↓
promover o mesmo artefacto
```

---

# 10. Primeiro deployment manual da stack

Para manter a regra **manual → observar → automatizar**, vamos executar manualmente as fases essenciais do primeiro deployment.

Definir uma forma curta de invocar o Compose não é necessário; execute o comando completo para perceber quais os ficheiros envolvidos.

Validar:

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

Iniciar apenas PostgreSQL:

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

### Inicializar o schema apenas numa base de dados vazia

Verificar se a tabela principal da aplicação já existe:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  exec -T db \
  psql -U symfony -d symfony -tAc \
  "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='symfony_demo_post';"
```

Se não devolver `1`, e apenas porque se trata de uma base vazia de laboratório:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  run --rm app \
  php bin/console doctrine:schema:create --no-interaction
```

> **Produção real:** alterações de schema devem ser tratadas através de migrações versionadas, compatíveis e controladas. `doctrine:schema:create` é usado aqui apenas para inicializar uma base de dados vazia do laboratório.

Iniciar a aplicação:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d app
```

Agora observe o wrapper que evita repetir todas estas flags nos comandos seguintes:

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

### Acesso pelo browser do PC

Obter o IP da VM:

```bash
hostname -I
```

Confirmar publicação:

```bash
docker ps --filter "id=$CID" --format 'table {{.Names}}\t{{.Ports}}'
```

Deverá existir uma publicação equivalente a:

```text
0.0.0.0:8080->80/tcp
```

No PC do formando:

```text
http://IP_DA_VM:8080
http://IP_DA_VM:8080/info
http://IP_DA_VM:8080/health
http://IP_DA_VM:8080/ready
```

> Como o formando já acede à VM por PuTTY/SSH, existe conectividade PC → VM. Contudo, a porta publicada também tem de ser permitida pela rede e pelas políticas do ambiente.

> **Nota de firewall Docker:** não assuma que `ufw allow 8080/tcp` controla uma porta publicada pelo Docker. A documentação Docker alerta que portas publicadas podem contornar regras UFW/firewalld devido à forma como o Docker gere regras de packet filtering. Se o acesso externo falhar, valide primeiro `docker ps`, o IP/rota da VM e as regras de rede/firewall do ambiente.

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

- `exec` — executa um comando num serviço já iniciado;
- `-T` — desativa pseudo-TTY;
- `psql -U` — define o utilizador PostgreSQL;
- `-d` — define a base de dados;
- `-c` — executa o SQL indicado.

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

Abrir o script:

```bash
sed -n '1,300p' formando/scripts/deploy-prod.sh
```

Identifique os blocos comentados: configuração, validação da porta, pull, PostgreSQL, health, schema, aplicação e validação.

Executar novamente a versão inicial através da automação:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

Validar:

```bash
./formando/scripts/validate.sh
```

---

## 13.1. Update para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar a versão:

```bash
curl -fsS http://localhost:8080/info
```

- `-f` — trata HTTP 4xx/5xx como erro;
- `-s` — modo silencioso;
- `-S` — mostra erro mesmo com `-s`.

Confirmar os dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

A substituição do container da aplicação não deve eliminar o conteúdo do volume PostgreSQL.

---

## 13.2. Introduzir a falha controlada 1.2.0-rc1

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e
echo "EXIT_CODE=$RC"
```

A imagem `1.2.0-rc1` está preparada deliberadamente com um caminho incorreto no Docker `HEALTHCHECK`.

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

Evidência esperada:

```text
/health  → válido
/healthz → 404
      ↓
HEALTHCHECK da 1.2.0-rc1 usa /healthz
      ↓
container unhealthy
```

Não faça rollback antes de conseguir explicar a causa.

---

## 13.4. Rollback para 1.1.0

Abrir o script:

```bash
sed -n '1,220p' formando/scripts/rollback.sh
```

Executar:

```bash
./formando/scripts/rollback.sh 1.1.0
./formando/scripts/validate.sh
```

Confirmar novamente os dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Resultado:

```text
1.0.0
   ↓ deployment
1.1.0
   ↓ update válido
1.2.0-rc1
   ↓ unhealthy
Diagnóstico
   ↓
Rollback 1.1.0
   ↓
healthy + dados preservados
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
ARG/ENV ≠ Secret Manager
.env de projeto ≠ Secret Manager
BuildKit secret é temporário durante o build
Docker HEALTHCHECK ≠ Kubernetes Probe
Tag ≠ Digest
Persistência ≠ Backup
Build Once → Promote the Same Artifact
Compose Single-host ≠ Alta Disponibilidade
Diagnosticar → só depois corrigir/rollback
```
