# Manual do Formando
## Sessão 3 — Docker II: Build, Imagens, Otimização, Segurança, Registry e Deployment Single-host

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 3 de 10 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Foco pedagógico** | Construir, analisar, versionar, publicar e operar uma imagem de aplicação |
| **Cenário transversal** | Symfony Demo v3.1.0 + Symfony 8.1 + PHP 8.4 + Apache + PostgreSQL 16 |
| **Laboratório** | Um laboratório integrado e progressivo |

---

# 1. Como Utilizar este Manual

Este manual foi concebido para funcionar como **guia de acompanhamento, estudo autónomo e consulta futura**. Não é uma cópia da apresentação.

A sequência recomendada é:

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

A componente prática deixou de estar dividida em sete Labs independentes. A Sessão 3 utiliza agora um único laboratório:

```text
formando/labs/laboratorio_integrado_sessao_3.md
```

O laboratório acompanha uma única história técnica:

```text
Ubuntu Server limpo
      ↓
Instalar Docker
      ↓
Obter os recursos da formação
      ↓
Preparar a aplicação
      ↓
Construir uma imagem
      ↓
Compreender cache e multi-stage
      ↓
Aplicar hardening e gerir secrets
      ↓
Validar health e recursos
      ↓
Analisar vulnerabilidades
      ↓
Versionar e publicar num registry
      ↓
Deploy 1.0.0
      ↓
Dados + backup
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

# 2. Regra Pedagógica da Sessão

Os scripts existentes no repositório são exemplos de automação. **Não substituem a aprendizagem manual.**

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Sempre que um script for utilizado:

1. identifique os passos que já executou manualmente;
2. abra o script;
3. localize esses passos no código;
4. só depois execute a automação.

No final do laboratório integrado, os scripts são utilizados deliberadamente para o ciclo operacional de deploy, validação, update, falha e rollback.

---

# 3. Ponto de Partida — Ubuntu Server Limpo

A VM do formando parte apenas de uma instalação limpa de **Ubuntu Server**.

## 3.1. Atualizar o catálogo de pacotes

```bash
sudo apt update
```

### O que faz

Atualiza o índice local dos pacotes disponíveis nos repositórios configurados.

```text
apt update
   ↓
atualiza o catálogo

apt upgrade
   ↓
atualiza pacotes já instalados
```

## 3.2. Atualizar os pacotes instalados

```bash
sudo apt upgrade -y
```

### Flags

- `-y` — responde automaticamente `yes` às confirmações do `apt`.

## 3.3. Instalar ferramentas base

```bash
sudo apt install -y \
  ca-certificates \
  curl \
  git
```

### O que instala

- `ca-certificates` — certificados de autoridades de certificação usados para validar ligações HTTPS;
- `curl` — cliente para HTTP/HTTPS e transferências;
- `git` — sistema de controlo de versões usado para obter os recursos da formação.

---

# 4. Instalar Docker pelo Repositório Oficial

## 4.1. Remover eventuais pacotes incompatíveis

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

Numa VM limpa é normal que vários destes pacotes não estejam instalados.

## 4.2. Criar a diretoria de chaves

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

### Flags

- `-m 0755` — define as permissões da diretoria criada;
- `-d` — cria uma diretoria.

## 4.3. Obter a chave oficial Docker

```bash
sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
```

### Flags do `curl`

| Flag | Função |
|---|---|
| `-f` | termina com erro perante respostas HTTP 4xx/5xx |
| `-s` | modo silencioso |
| `-S` | mostra erros mesmo com `-s` |
| `-L` | segue redirecionamentos |
| `-o` | grava a resposta no ficheiro indicado |

A chave permite ao `apt` verificar a assinatura dos pacotes fornecidos pelo repositório Docker.

## 4.4. Tornar a chave legível pelo `apt`

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

## 4.5. Adicionar o repositório oficial

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

Atualizar novamente:

```bash
sudo apt update
```

## 4.6. Instalar Docker Engine, containerd, Buildx e Compose

```bash
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

### Componentes instalados

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
- **containerd** — runtime de alto nível responsável pelo ciclo de vida dos containers;
- **runc** — runtime OCI de baixo nível que cria o processo isolado;
- **Buildx** — frontend avançado para BuildKit;
- **Docker Compose** — ferramenta declarativa para aplicações multi-container.

### Ponte conceptual para Kubernetes

```text
Docker:
CLI → Engine → containerd → runc

Kubernetes:
kubelet → CRI → containerd → runc
```

Nesta sessão não aprofundamos CRI nem kubelet; a comparação serve apenas para ligar Docker ao percurso de Kubernetes.

---

# 5. Validar a Instalação

Consultar o serviço:

```bash
sudo systemctl status docker --no-pager
```

- `--no-pager` — mostra a saída diretamente no terminal, sem abrir um paginador.

Se necessário:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

Primeiro container:

```bash
sudo docker run --rm hello-world
```

### `--rm`

Remove automaticamente o container quando termina. A imagem permanece disponível localmente.

Confirmar componentes:

```bash
sudo docker version
sudo docker info
sudo docker compose version
sudo docker buildx version
```

---

# 6. Executar Docker sem `sudo`

Adicionar o utilizador atual ao grupo `docker`:

```bash
sudo usermod -aG docker "$USER"
```

### Flags

- `-a` — adiciona sem remover os grupos já existentes;
- `-G docker` — adiciona o utilizador ao grupo suplementar `docker`.

Termine a sessão SSH:

```bash
exit
```

Volte a ligar e confirme:

```bash
groups
docker version
docker info
docker run --rm hello-world
docker compose version
```

> **Nota de segurança:** pertencer ao grupo `docker` concede privilégios muito elevados sobre o host. Nesta formação é utilizado numa VM de laboratório por conveniência operacional.

---

# 7. Obter os Recursos da Formação

Primeira utilização:

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

Se o repositório já existir:

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Confirmar a diretoria:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: Dockerfile disponível'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

### Elementos importantes

- `git clone` — cria uma cópia local do repositório;
- `git pull` — atualiza uma cópia já existente;
- `test -f` — verifica a existência de um ficheiro regular;
- `test -x` — verifica se o ficheiro é executável;
- `&&` — executa o comando seguinte apenas se o anterior terminar com sucesso.

Todos os comandos seguintes assumem:

```text
formacao-kubernetes/sessao-03
```

---

# 8. Preparar a Symfony Demo

```bash
./comum/prepare-source.sh
```

O script obtém a Symfony Demo `v3.1.0` e aplica os endpoints pedagógicos usados na formação.

Confirmar:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

A aplicação disponibiliza:

```text
/info
/health
/ready
```

- `/info` — identifica versão e ambiente;
- `/health` — saúde básica do processo/aplicação;
- `/ready` — prontidão da aplicação incluindo a dependência da base de dados.

---

# 9. Objetivos Técnicos da Sessão

No final deverá conseguir:

- construir uma imagem através de Dockerfile;
- explicar build context e `.dockerignore`;
- compreender layers e cache;
- utilizar multi-stage builds;
- distinguir build stage e runtime stage;
- interpretar `ARG`, `ENV`, `CMD`, `ENTRYPOINT` e `HEALTHCHECK`;
- aplicar princípios de hardening;
- explicar porque `ARG`, `ENV` e `.env` não são secret managers;
- utilizar BuildKit secrets e compreender Compose secrets;
- aplicar limites de recursos e restart policy;
- analisar vulnerabilidades com Trivy;
- distinguir tag de digest;
- explicar o que é um registry;
- fazer pull e, quando aplicável, push para GHCR;
- aplicar `build once, promote the same artifact`;
- executar deploy, update, diagnóstico e rollback;
- distinguir persistência de backup.

---

# 10. Dockerfile e Build Context

Um Dockerfile descreve como construir uma imagem.

| Instrução | Função |
|---|---|
| `FROM` | define a imagem base |
| `WORKDIR` | define a diretoria de trabalho |
| `COPY` | copia ficheiros a partir do build context |
| `RUN` | executa operações durante o build |
| `ARG` | define argumentos de build |
| `ENV` | define variáveis persistidas na imagem/container |
| `EXPOSE` | documenta a porta esperada |
| `HEALTHCHECK` | define o teste de saúde Docker |
| `CMD` | define o comando por omissão |
| `ENTRYPOINT` | define a entrada principal quando utilizada |
| `LABEL` | adiciona metadata |

Primeiro build:

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

### Flags e argumentos

- `-f` — indica o caminho do Dockerfile;
- `-t` — atribui nome e tag à imagem;
- `.` — define a diretoria atual como build context.

### O que é o build context?

É o conjunto de ficheiros disponibilizados ao builder durante o build.

```text
Diretoria atual
      ↓
build context
      ↓
Dockerfile pode usar COPY a partir daqui
```

---

# 11. `.dockerignore`

O `.dockerignore` exclui ficheiros do build context.

Exemplos do cenário:

```text
.git/
app/.git/
app/vendor/
app/var/cache/
app/var/log/
app/.env.local
app/.env.*.local
backups/
*.sql
*.zip
```

### Porque é importante?

- reduz o contexto enviado ao builder;
- evita invalidar cache desnecessariamente;
- reduz o risco de enviar ficheiros locais ou sensíveis;
- acelera builds.

---

# 12. Layers, Cache e Multi-stage

Consultar o histórico:

```bash
docker history symfony-demo:naive
```

Construir a versão otimizada:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

### `--build-arg`

Fornece um valor a uma instrução `ARG` do Dockerfile durante o build.

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

### Porque a ordem das instruções importa?

```text
COPY composer.json/composer.lock
      ↓
composer install
      ↓
COPY restante aplicação
```

Se apenas o código da aplicação mudar, a layer das dependências pode continuar válida.

### Multi-stage

```text
Stage build
   ↓
Composer + ferramentas + dependências
   ↓
Stage runtime
   ↓
apenas o necessário para executar
```

Depois de compreender o processo manual, compare com:

```bash
sed -n '1,220p' formando/scripts/build.sh
./formando/scripts/build.sh 1.1.0
```

---

# 13. Hardening e Secrets

Hardening significa reduzir riscos sem impedir o funcionamento necessário.

Princípios usados:

- imagem base de origem conhecida;
- componentes mínimos necessários;
- ferramentas de build fora do runtime sempre que possível;
- privilégios mínimos compatíveis com o processo;
- permissões de escrita apenas onde necessárias;
- secrets fora da imagem;
- não montar o Docker socket sem compreender as implicações.

## 13.1. Má prática com `ARG`/`ENV`

```bash
docker build \
  -f formando/exemplos/secrets/Dockerfile.bad \
  --build-arg API_TOKEN=segredo-falso-lab \
  -t secret-demo:bad \
  formando/exemplos/secrets
```

Investigar:

```bash
docker history --no-trunc secret-demo:bad
docker image inspect secret-demo:bad
```

- `--no-trunc` — impede que a saída seja abreviada.

Utilize apenas valores fictícios.

## 13.2. BuildKit secret

```bash
printf 'segredo-falso-lab\n' > /tmp/demo_secret.txt

docker build \
  -f formando/exemplos/secrets/Dockerfile.secret \
  --secret id=demo_secret,src=/tmp/demo_secret.txt \
  -t secret-demo:buildkit \
  formando/exemplos/secrets

rm -f /tmp/demo_secret.txt
```

### `--secret`

- `id=demo_secret` — identificador usado no Dockerfile;
- `src=...` — ficheiro local fornecido temporariamente ao build.

## 13.3. Compose secret

```bash
cp formando/exemplos/secrets/demo_secret.example.txt \
   formando/exemplos/secrets/demo_secret.txt

docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit

rm -f formando/exemplos/secrets/demo_secret.txt
```

Os secrets são disponibilizados como ficheiros, tipicamente em:

```text
/run/secrets/<nome>
```

```text
.env ≠ secret manager
```

---

# 14. Docker Compose para Produção Single-host

Preparar o ficheiro de ambiente:

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
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

- `--env-file` — define o ficheiro usado para interpolação de variáveis;
- `-f` — adiciona um ficheiro Compose;
- vários `-f` — fazem merge pela ordem indicada;
- `config` — mostra a configuração final resultante.

Depois de compreender o comando completo, pode usar:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
./formando/scripts/compose-prod.sh config
```

---

# 15. HEALTHCHECK, Health e Readiness

A imagem define um Docker `HEALTHCHECK`.

Conceptualmente:

```dockerfile
HEALTHCHECK ... \
  CMD curl -fsS http://localhost/health >/dev/null || exit 1
```

Estados possíveis:

```text
starting
healthy
unhealthy
```

Validar endpoints:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

### `curl -i`

Inclui os headers HTTP na saída.

### Diferença conceptual

```text
/health
   ↓
processo/aplicação viva

/ready
   ↓
aplicação pronta com dependências disponíveis
```

Consultar o health Docker:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)

docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

- `-q` — devolve apenas o ID do container;
- `--format` — seleciona/formata campos da resposta do Docker.

### Muito importante

```text
Docker HEALTHCHECK
        ≠
Kubernetes livenessProbe
        ≠
Kubernetes readinessProbe
```

Kubernetes não transforma automaticamente o `HEALTHCHECK` da imagem em probes.

---

# 16. Recursos, Restart e Logging

O override de produção inclui:

```yaml
restart: unless-stopped
mem_limit: 512m
cpus: 1.0
logging:
  driver: local
```

Consultar:

```bash
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'

docker stats --no-stream "$CID"
```

- `--no-stream` — apresenta uma fotografia instantânea em vez de atualização contínua.

Políticas de restart principais:

| Política | Comportamento |
|---|---|
| `no` | não reinicia automaticamente |
| `on-failure` | reinicia após saída com erro |
| `always` | tenta manter o container iniciado |
| `unless-stopped` | semelhante a `always`, mas respeita uma paragem manual explícita |

---

# 17. Scan com Trivy

Trivy é utilizado nesta formação como scanner de vulnerabilidades de imagens.

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

### Flags

- `image` — analisa uma imagem;
- `--scanners vuln` — executa o scanner de vulnerabilidades;
- `--severity HIGH,CRITICAL` — filtra as severidades apresentadas;
- `--ignore-unfixed` — ignora vulnerabilidades para as quais ainda não existe correção conhecida.

Um scan não substitui hardening, patching ou gestão de secrets.

Exemplo de quality gate didático:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

- `--exit-code 1` — devolve código 1 quando a política definida é violada.

Os resultados são dependentes do momento da análise. Não existe uma contagem fixa de vulnerabilidades esperada.

---

# 18. O que é um Registry?

Um **container registry** é um serviço utilizado para armazenar e distribuir imagens.

```text
Git repository
    ↓
guarda código-fonte

Container registry
    ↓
guarda imagens de containers
```

Exemplos incluem Docker Hub, GitHub Container Registry, GitLab Container Registry, Harbor, Amazon ECR, Azure Container Registry e Google Artifact Registry.

Nesta formação usamos GHCR:

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
```

Decomposição:

```text
ghcr.io
   ↓
registry

skullclamp
   ↓
namespace / proprietário

symfony-demo
   ↓
repositório da imagem

1.0.0
   ↓
tag
```

Obter uma imagem pública:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

`docker pull` copia para o host local o conteúdo necessário para utilizar a imagem.

---

# 19. Tag e Digest

Uma **tag** é uma referência legível e conveniente:

```text
symfony-demo:1.1.0
```

Criar uma segunda tag:

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable
```

Comparar IDs locais:

```bash
docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

Uma tag pode ser reatribuída.

Um **digest** identifica o conteúdo publicado no registry:

```text
sha256:...
```

```text
Tag
  ↓
referência humana
  ↓
pode mudar

Digest
  ↓
identidade do conteúdo
  ↓
imutável para esse conteúdo
```

---

# 20. Push para um Namespace Pessoal

Definir o destino:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
```

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

O push exige autenticação com permissões adequadas. Nunca coloque tokens no repositório ou em capturas de ecrã.

Consultar RepoDigests:

```bash
docker image inspect \
  "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

Depois de compreender `tag` e `push`, compare com:

```bash
sed -n '1,220p' formando/scripts/push.sh
./formando/scripts/push.sh 1.0.0
```

---

# 21. Build Once, Promote the Same Artifact

O princípio pretendido é:

```text
Código
  ↓
Build
  ↓
Imagem
  ↓
Scan
  ↓
Registry
  ↓
DEV → TEST → PROD
```

Não reconstruímos a imagem para cada ambiente.

```text
Build DEV
Build TEST
Build PROD
```

pode produzir artefactos diferentes.

A promoção correta reutiliza o mesmo conteúdo validado.

---

# 22. Deploy Inicial — 1.0.0

Antes do ciclo operacional, abra o script:

```bash
sed -n '1,260p' formando/scripts/deploy-prod.sh
```

Identifique conceptualmente:

```text
config
  ↓
preflight da porta
  ↓
pull
  ↓
PostgreSQL
  ↓
health DB
  ↓
inicialização do schema quando necessário
  ↓
aplicação
  ↓
validação
```

Executar:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

Validar:

```bash
./formando/scripts/validate.sh
```

---

# 23. Persistência e Backup

O PostgreSQL utiliza um named volume.

```text
Container DB
    ↓
pode ser recriado

Named volume
    ↓
permanece
```

Mas:

```text
Persistência ≠ Backup
```

Criar um marcador pedagógico:

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

### Flags do `psql`

- `-U symfony` — utilizador PostgreSQL;
- `-d symfony` — base de dados;
- `-c` — executa diretamente o SQL fornecido;
- `-T` do Compose — desativa pseudo-TTY, útil em automação e redirecionamentos.

Backup lógico manual:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  pg_dump -U symfony -d symfony \
  > backup.sql
```

- `>` — redireciona a saída standard para um ficheiro.

Confirmar:

```bash
ls -lh backup.sql
```

- `-l` — formato detalhado;
- `-h` — tamanhos legíveis.

Depois compare com:

```bash
sed -n '1,220p' formando/scripts/backup-postgres.sh
```

---

# 24. Update para 1.1.0

Executar:

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar versão:

```bash
curl -fsS http://localhost:8080/info
```

### Flags

- `-f` — considera respostas HTTP 4xx/5xx como erro;
- `-s` — modo silencioso;
- `-S` — mostra erros apesar do modo silencioso.

Confirmar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

A atualização da imagem da aplicação não deve eliminar dados armazenados no volume PostgreSQL.

---

# 25. Falha Controlada — 1.2.0-rc1

Executar:

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

A imagem candidata possui um `HEALTHCHECK` deliberadamente incorreto, que testa `/healthz` em vez de `/health`.

O resultado pretendido é:

```text
Apache ativo
   ↓
/health responde
   ↓
Docker testa /healthz
   ↓
404
   ↓
container unhealthy
```

---

# 26. Diagnóstico Antes do Rollback

Consultar estado:

```bash
./formando/scripts/compose-prod.sh ps
```

Obter o ID:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar health:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Consultar logs:

```bash
./formando/scripts/compose-prod.sh logs --tail 100 app
```

Comparar manualmente:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

Regra operacional:

```text
Sintoma
   ↓
Evidência
   ↓
Hipótese
   ↓
Teste
   ↓
Correção
   ↓
Validação
```

Não faça rollback antes de compreender a causa da falha.

---

# 27. Rollback para 1.1.0

Abra primeiro:

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

Confirmar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Resultado final:

```text
1.0.0
  ↓
deploy
  ↓
dados
  ↓
backup
  ↓
1.1.0
  ↓
update válido
  ↓
1.2.0-rc1
  ↓
unhealthy
  ↓
diagnóstico
  ↓
rollback 1.1.0
  ↓
dados preservados
```

---

# 28. Docker Compose Single-host não é Alta Disponibilidade

O cenário desta sessão utiliza um único host Docker.

```text
Host Docker
   ↓
Compose
   ↓
app + db
```

Se o host falhar, os serviços ficam indisponíveis.

```text
restart policy
      ≠
Alta Disponibilidade
```

```text
Docker Compose single-host
      ≠
Kubernetes
```

Esta limitação prepara a transição para a administração de Kubernetes na sessão seguinte.

---

# 29. Resumo dos Pontos-Chave

- Dockerfile descreve a construção da imagem.
- O build context determina os ficheiros disponibilizados ao builder.
- `.dockerignore` reduz contexto e risco.
- A ordem das layers influencia a cache.
- Multi-stage separa build e runtime.
- `ARG`, `ENV` e `.env` não são secret managers.
- Docker `HEALTHCHECK` não equivale a probes Kubernetes.
- Trivy ajuda a identificar vulnerabilidades conhecidas.
- Uma tag é conveniente; um digest identifica conteúdo.
- Um registry armazena e distribui imagens.
- O mesmo artefacto deve ser promovido entre ambientes.
- Persistência não substitui backup.
- Antes de corrigir uma falha, recolha evidência.
- Compose single-host não fornece Alta Disponibilidade.

---

# 30. Autoavaliação

Tente responder antes de consultar o manual:

1. Qual é a diferença entre Docker CLI, Engine, containerd e runc?
2. O que representa o último `.` em `docker build ... .`?
3. Para que serve `.dockerignore`?
4. Porque deve copiar `composer.json`/`composer.lock` antes do restante código quando pretende aproveitar a cache?
5. O que separa um multi-stage build?
6. Porque `ARG` não é um mecanismo seguro para secrets?
7. Onde são disponibilizados Compose secrets no container?
8. Qual é a diferença entre `/health` e `/ready`?
9. Docker `HEALTHCHECK` é automaticamente transformado numa probe Kubernetes?
10. O que faz `--severity HIGH,CRITICAL` no Trivy?
11. O que é um container registry?
12. Qual é a diferença entre tag e digest?
13. O que significa `build once, promote the same artifact`?
14. Porque um named volume não é um backup?
15. Que evidência demonstra a causa da falha da versão `1.2.0-rc1`?
16. Qual a versão conhecida como válida para rollback?
17. Porque Docker Compose single-host não é Alta Disponibilidade?

---

# 31. Glossário

| Termo | Significado |
|---|---|
| **Docker Engine** | Serviço que gere objetos Docker |
| **containerd** | Runtime de alto nível para gestão de containers |
| **runc** | Runtime OCI de baixo nível |
| **Dockerfile** | Ficheiro declarativo de construção de imagens |
| **Build context** | Ficheiros disponibilizados ao builder |
| **Layer** | Camada que compõe uma imagem |
| **Build cache** | Reutilização de resultados de etapas anteriores |
| **Multi-stage build** | Build com vários stages para separar construção e runtime |
| **Hardening** | Redução controlada da superfície de ataque |
| **Secret** | Informação sensível a proteger |
| **HEALTHCHECK** | Teste de saúde executado pelo Docker |
| **Readiness** | Capacidade de servir pedidos com dependências disponíveis |
| **Registry** | Serviço de armazenamento e distribuição de imagens |
| **Tag** | Referência legível associada a uma imagem |
| **Digest** | Identidade do conteúdo publicado |
| **GHCR** | GitHub Container Registry |
| **Promotion** | Passagem do mesmo artefacto entre ambientes |
| **Rollback** | Regresso a uma versão conhecida como válida |
| **Named volume** | Armazenamento gerido pelo Docker |
| **Backup** | Cópia independente destinada a recuperação |

---

# 32. Coerência com a Apresentação e Laboratório

A apresentação e o laboratório integrado seguem a mesma sequência conceptual:

| Tema | Apresentação | Manual | Laboratório integrado |
|---|---|---|---|
| Build once / promoção | Enquadramento inicial | 21 | promoção do artefacto |
| Dockerfile / build context | Bloco Dockerfile | 10–11 | construção inicial |
| Layers / cache / multi-stage | Bloco otimização | 12 | builds comparativos |
| Hardening / secrets | Bloco segurança | 13 | experiências com secrets |
| Recursos / restart / health / logging | Controlos operacionais | 15–16 | validação da stack |
| Trivy / tag / digest | Scan e identidade | 17–19 | scan e identificação |
| GHCR / registry | Registry e promoção | 18–20 | pull / tag / push |
| Compose de produção | Ficheiros Compose | 14 | configuração efetiva |
| Deploy / update / falha / rollback | Laboratório single-host | 22–27 | ciclo integrado |
| Persistência / backup | Volume ≠ backup | 23 | marcador + `pg_dump` |
| Limites single-host | Síntese | 28 | conclusão |

**Critério de coerência:** nenhum conceito avaliado no laboratório deve surgir sem explicação prévia no manual e enquadramento na apresentação.

---

# 33. Recursos de Consulta

- Docker Documentation — https://docs.docker.com/
- Docker Engine on Ubuntu — https://docs.docker.com/engine/install/ubuntu/
- Docker Build — https://docs.docker.com/build/
- Dockerfile reference — https://docs.docker.com/reference/dockerfile/
- Docker Compose — https://docs.docker.com/compose/
- Open Container Initiative — https://opencontainers.org/
- Trivy — https://trivy.dev/
- GitHub Container Registry — https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- Symfony Documentation — https://symfony.com/doc/
- PostgreSQL Documentation — https://www.postgresql.org/docs/
- Kubernetes Documentation — https://kubernetes.io/docs/

---

# 34. Transição para a Sessão 4

A Sessão 3 termina com um artefacto preparado, validado, versionado e publicável, e com um ciclo operacional completo num único host.

```text
Sessão 2
OPERAR
   ↓
Sessão 3
CONSTRUIR / PRODUZIR
   ↓
Sessão 4
ORQUESTRAR / ADMINISTRAR KUBERNETES
```

A limitação que fica por resolver é precisamente a dependência de um único host, sem redundância de nós, scheduling distribuído ou failover de infraestrutura.