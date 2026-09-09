# Manual do Formando
## Sessão 3 — Docker II: Build, Imagens, Otimização, Segurança, Registry e Deployment Single-host

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 3 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **N.º estimado de formandos** | Até 5 |
| **Foco pedagógico** | Construir, preparar, analisar, identificar e promover imagens |
| **Cenário transversal** | Symfony Demo v3.1.0 + PHP 8.4 + Apache + PostgreSQL 16 |

---

# 1. Enquadramento

Na Sessão 2 o foco foi **OPERAR** containers e aplicações multi-container. Nesta sessão o foco passa para o artefacto que será executado.

```text
Sessão 2
OPERAR
   ↓
Sessão 3
CONSTRUIR
PREPARAR
ANALISAR
IDENTIFICAR
PUBLICAR
PROMOVER
```

O percurso é:

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
Deployment single-host
  ↓
Update
  ↓
Falha
  ↓
Rollback
```

---

# 2. Regra pedagógica da sessão

Os scripts existem para demonstrar automação e para suportar o cenário operacional final. **Não substituem a aprendizagem manual.**

A progressão adotada é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Nos Labs 01–06, os principais passos são executados manualmente. Quando um script equivalente aparece, deverá primeiro:

1. identificar os passos já realizados;
2. abrir o script;
3. localizar esses passos no código;
4. só depois executar o script.

No Lab 07 a automação é intencional porque o objetivo já é integrar deploy, validação, update, falha e rollback.

---

# 3. Preparar uma VM nova

Os recursos da formação encontram-se no GitHub. Uma VM nova **não possui** automaticamente as pastas `formando/`, `comum/` ou os Dockerfiles.

## 3.1. Primeira utilização

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

## 3.2. Se o repositório já existir

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

## 3.3. Confirmar a diretoria de trabalho

Todos os comandos dos laboratórios assumem que está em:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
pwd
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

Se estes testes falharem, não avance para os scripts: primeiro corrija a diretoria ou obtenha o repositório.

---

# 4. Preparar o código da aplicação

O código da Symfony Demo não é duplicado permanentemente nos recursos da sessão.

Execute:

```bash
./comum/prepare-source.sh
```

O script:

1. remove uma eventual `app/` anterior;
2. obtém `symfony/demo` na tag `v3.1.0`;
3. adiciona o controller pedagógico;
4. adiciona as rotas de laboratório;
5. remove o `.git` interno da aplicação descarregada.

Confirme:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

A estrutura local passa a incluir:

```text
sessao-03/
├── app/
├── comum/
└── formando/
```

A pasta `app/` é material de trabalho local. Não deve ser confundida com os recursos pedagógicos versionados.

---

# 5. Objetivos da sessão

No final deverá ser capaz de:

- construir uma imagem através de Dockerfile;
- explicar o contexto de build e `.dockerignore`;
- interpretar layers e cache;
- utilizar multi-stage builds;
- distinguir build stage de runtime stage;
- compreender `ARG`, `ENV`, `CMD`, `ENTRYPOINT` e labels;
- avaliar a origem e adequação da imagem base;
- identificar riscos de secrets em Dockerfile, `ARG`, `ENV` e CLI;
- compreender BuildKit secrets e Compose secrets;
- configurar e interpretar Docker `HEALTHCHECK`;
- distinguir `/health` de `/ready`;
- aplicar controlos de CPU, memória, restart e logging;
- analisar vulnerabilidades com Trivy;
- distinguir tag de digest;
- fazer pull e, quando aplicável, push para GHCR;
- aplicar `build once, promote the same artifact`;
- executar deploy, update, falha controlada e rollback;
- confirmar persistência dos dados.

---

# 6. Dockerfile e contexto de build

Um Dockerfile descreve como construir uma imagem.

Instruções principais:

| Instrução | Papel |
|---|---|
| `FROM` | Define a imagem base |
| `WORKDIR` | Define a diretoria de trabalho |
| `COPY` | Copia ficheiros a partir do contexto de build |
| `RUN` | Executa uma operação durante o build |
| `ARG` | Define argumento de build |
| `ENV` | Define variável persistida no ambiente da imagem/container |
| `EXPOSE` | Documenta a porta esperada |
| `HEALTHCHECK` | Define o teste de saúde Docker |
| `CMD` | Define o comando por omissão |
| `ENTRYPOINT` | Define a entrada principal, quando utilizada |
| `LABEL` | Adiciona metadata |

Quando executa:

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

o último `.` representa o **contexto de build**.

```text
Diretoria atual
      ↓
contexto enviado ao builder
      ↓
Dockerfile usa COPY a partir desse contexto
```

Um contexto demasiado grande pode aumentar tempos de build, invalidar cache desnecessariamente e incluir ficheiros que não deveriam chegar ao builder.

---

# 7. `.dockerignore`

O `.dockerignore` exclui ficheiros do contexto de build.

No cenário da sessão são excluídos, entre outros:

```text
app/.git/
app/vendor/
app/var/cache/
app/var/log/
.git/
app/.env.local
app/.env.*.local
backups/
*.zip
*.tar
*.sql
```

A regra importante é:

> O `.dockerignore` relevante é o que corresponde ao contexto realmente usado no `docker build`.

---

# 8. Layers e cache

As imagens são construídas em layers.

```text
FROM
 ↓
RUN
 ↓
COPY
 ↓
RUN
 ↓
imagem final
```

Consultar:

```bash
docker history symfony-demo:1.0.0
```

A cache permite reutilizar resultados de passos anteriores quando as entradas relevantes não mudam.

No Dockerfile otimizado, os ficheiros de dependências entram antes do restante código:

```dockerfile
COPY app/composer.json app/composer.lock ./
RUN composer install ...
COPY app/ ./
```

Assim:

```text
composer.json / composer.lock não mudaram
             ↓
layer de dependências pode ser reutilizada
             ↓
novo código não obriga a reinstalar tudo
```

## Build manual da versão 1.0.0

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

## Novo build para observar cache

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Procure `CACHED` na saída.

Só depois compare com a automação:

```bash
sed -n '1,220p' formando/scripts/build.sh
./formando/scripts/build.sh 1.1.0
```

Pergunta obrigatória:

> Que comando manual está `build.sh` a automatizar?

---

# 9. Multi-stage build

Um multi-stage build utiliza mais do que um `FROM`.

```text
Stage build
  ↓
ferramentas + Composer + dependências
  ↓
artefactos da aplicação
  ↓
Stage runtime
  ↓
apenas o necessário para executar
```

Vantagens:

- separar responsabilidades;
- reduzir ferramentas no runtime;
- controlar melhor o conteúdo final;
- facilitar manutenção e hardening.

O objetivo não é produzir a menor imagem possível a qualquer custo, mas uma imagem adequada, compreensível e operacional.

---

# 10. `ARG`, `ENV` e secrets

`ARG` existe durante o build:

```dockerfile
ARG APP_VERSION=dev
```

`ENV` persiste na configuração da imagem/container:

```dockerfile
ENV APP_ENV=prod
```

Nem `ARG` nem `ENV` devem ser tratados como mecanismos seguros para esconder secrets.

## Experiência de má prática

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

Utilize apenas valores fictícios.

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

O secret é disponibilizado apenas à instrução `RUN` que o utiliza.

## Compose secret

```bash
cp formando/exemplos/secrets/demo_secret.example.txt \
   formando/exemplos/secrets/demo_secret.txt

docker compose \
  -f formando/exemplos/secrets/compose.secret-demo.yaml \
  up --abort-on-container-exit

rm -f formando/exemplos/secrets/demo_secret.txt
```

No container, o secret é montado como ficheiro em `/run/secrets/<nome>`.

## `.env`

```text
.env
  ≠
secret manager
```

---

# 11. Hardening

Princípios aplicados:

- imagem base de origem conhecida;
- redução de dependências desnecessárias;
- ferramentas de build fora do runtime quando não são necessárias;
- ausência de secrets embutidos;
- privilégios mínimos compatíveis com o runtime;
- permissões de escrita apenas onde necessárias;
- não montar o Docker socket sem compreender o privilégio concedido.

## Nota sobre non-root

A recomendação “executar como non-root” deve ser validada no contexto da imagem. Na imagem Apache oficial, alterar mecanicamente `USER` pode exigir mudanças adicionais em portas, permissões e entrypoint.

---

# 12. Docker Compose — primeiro manual, depois wrapper

Preparar:

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

Validar manualmente a composição base + override:

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

Depois de compreender os argumentos repetidos, abra o wrapper:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
```

E compare:

```bash
./formando/scripts/compose-prod.sh ps
```

A finalidade do wrapper é reduzir repetição, não esconder o funcionamento do Compose.

---

# 13. Saúde e prontidão

A aplicação disponibiliza:

```text
/info
/health
/ready
```

- `/info` identifica versão e ambiente;
- `/health` valida a saúde básica da aplicação;
- `/ready` acrescenta a disponibilidade da base de dados.

```text
processo HTTP saudável
       ≠
aplicação pronta com todas as dependências
```

Consultar:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

## Docker HEALTHCHECK

Obter o container:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
```

Consultar:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Estados típicos:

```text
starting
healthy
unhealthy
```

Ponto fundamental:

```text
Docker HEALTHCHECK
        ≠
Kubernetes livenessProbe
        ≠
Kubernetes readinessProbe
```

Kubernetes não transforma automaticamente a metadata `HEALTHCHECK` da imagem em probes.

---

# 14. Controlos de runtime

No override de produção são aplicados controlos como:

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

Estes controlos são úteis num host Docker, mas não equivalem a scheduling, reconciliação ou Alta Disponibilidade distribuída.

---

# 15. Trivy

Scan informativo:

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Os resultados mudam com a evolução da base de vulnerabilidades. Não memorize contagens fixas.

Quality gate didático:

```bash
set +e
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

A severidade deve ser interpretada com contexto, versão afetada, correção disponível e exposição real.

---

# 16. Tags e digest

Uma tag é uma referência:

```text
symfony-demo:1.1.0
symfony-demo:stable
```

Criar uma segunda tag:

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable
```

Comparar IDs:

```bash
docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

Pode haver duas tags para o mesmo conteúdo local.

Um digest identifica o conteúdo publicado no registry:

```bash
docker image inspect "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

```text
Tag = referência conveniente
Digest = identidade imutável do conteúdo publicado
```

---

# 17. GHCR — executar push manualmente antes do script

As imagens públicas podem ser obtidas sem login:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

Para publicar num namespace próprio:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
```

Depois de autenticar com credencial própria e sem a partilhar, faça primeiro:

```bash
docker tag \
  symfony-demo:1.0.0 \
  "$IMAGE_REPO:1.0.0"

docker push "$IMAGE_REPO:1.0.0"
```

Só depois abra:

```bash
sed -n '1,240p' formando/scripts/push.sh
```

E compare com:

```bash
./formando/scripts/push.sh 1.0.0
```

Pergunta:

> Que passos manuais está `push.sh` a automatizar?

---

# 18. Build once, promote the same artifact

O modelo pretendido é:

```text
Build
  ↓
Imagem
  ↓
Digest
  ├── DEV
  ├── TEST
  └── PROD
```

Não:

```text
Build DEV
Build TEST
Build PROD
```

Cada reconstrução pode produzir um artefacto diferente. A promoção pretende mover o mesmo conteúdo entre etapas.

---

# 19. PostgreSQL e persistência

O serviço de base de dados utiliza um named volume:

```text
app
 │
 │ db:5432
 ▼
db
 │
 ▼
db-data
```

A porta `5432` não precisa de ser publicada no host para a aplicação comunicar com PostgreSQL dentro da rede Compose.

Mensagem fundamental:

```text
Persistência
     ≠
Backup
```

---

# 20. Lab 07 — automação operacional transparente

Nesta fase já executou manualmente build, Compose, tags, scan e operações de registry. Os scripts do Lab 07 são agora utilizados de forma intencional.

Antes do primeiro deploy:

```bash
sed -n '1,320p' formando/scripts/deploy-prod.sh
sed -n '1,260p' formando/scripts/validate.sh
```

Não é necessário dominar toda a sintaxe Bash. Identifique o algoritmo:

```text
validar Compose
      ↓
verificar porta
      ↓
pull
      ↓
iniciar PostgreSQL
      ↓
aguardar DB healthy
      ↓
verificar/inicializar schema
      ↓
iniciar aplicação
      ↓
validar endpoints
      ↓
validar Docker health
```

## Deployment inicial

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

## Criar evidência persistente

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony <<'SQL'
CREATE TABLE IF NOT EXISTS lab_marker (
  id bigserial PRIMARY KEY,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO lab_marker(note) VALUES ('sessao-3');
SELECT * FROM lab_marker;
SQL
```

## Backup lógico

Antes de executar:

```bash
sed -n '1,220p' formando/scripts/backup-postgres.sh
```

Depois:

```bash
./formando/scripts/backup-postgres.sh
```

---

# 21. Update para 1.1.0

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar versão:

```bash
curl -fsS http://localhost:8080/info
```

Validar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

Resultado esperado:

```text
imagem/container da aplicação mudou
           ↓
volume PostgreSQL permaneceu
           ↓
dados permaneceram
```

---

# 22. Falha controlada — 1.2.0-rc1

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

A imagem de falha aponta o Docker HEALTHCHECK para `/healthz`, mas o endpoint real é `/health`.

Antes do rollback, diagnostique:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)

docker inspect "$CID" \
  --format '{{json .State.Health}}'

./formando/scripts/compose-prod.sh logs --tail 100 app

curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

É possível obter:

```text
/health responde
     +
processo Apache ativo
     +
Docker testa /healthz
     ↓
404
     ↓
unhealthy
```

---

# 23. Rollback

Antes de executar:

```bash
sed -n '1,240p' formando/scripts/rollback.sh
```

Identifique a alteração de versão, pull, atualização e validação.

Executar:

```bash
./formando/scripts/rollback.sh 1.1.0
```

Confirmar:

```bash
./formando/scripts/validate.sh
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

Resultado esperado:

```text
1.0.0
  ↓ deploy
1.1.0
  ↓ update
1.2.0-rc1
  ↓ diagnóstico: unhealthy
1.1.0
  ↓ rollback
healthy + dados preservados
```

---

# 24. Docker Compose single-host não é HA

Este laboratório aproxima-se de preocupações reais de operação, mas existe apenas um host Docker.

```text
1 host
  ↓
Compose
  ↓
app + db
```

Se o host falhar, os serviços deixam de estar disponíveis.

Logo:

```text
restart policy
      ≠
Alta Disponibilidade
```

E:

```text
Docker Compose single-host
      ≠
Kubernetes
```

---

# 25. Resumo

```text
GitHub
  ↓
git clone / git pull
  ↓
cd formacao-kubernetes/sessao-03
  ↓
prepare-source.sh
  ↓
Dockerfile
  ↓
docker build manual
  ↓
layers / cache / multi-stage
  ↓
hardening / secrets
  ↓
Compose manual
  ↓
health / ready
  ↓
Trivy
  ↓
tag / digest
  ↓
docker tag + docker push manual
  ↓
automação compreendida
  ↓
deploy / update / falha / rollback
```

Ideias-chave:

```text
Primeiro compreender, depois automatizar
Tag ≠ Digest
Health ≠ Readiness
Persistência ≠ Backup
Compose single-host ≠ HA
Docker HEALTHCHECK ≠ Kubernetes probes
```

---

# 26. Exercícios de consolidação

## Exercício 1 — Diretoria de trabalho

Porque não funciona `./formando/scripts/build.sh` numa VM que ainda não tem o repositório clonado?

Resposta:

____________________________________________________________________

## Exercício 2 — Build

Explique o significado de cada parte:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  -t symfony-demo:1.0.0 \
  .
```

Resposta:

____________________________________________________________________

## Exercício 3 — Cache

Porque copiar `composer.json` e `composer.lock` antes do restante código pode melhorar a reutilização da cache?

Resposta:

____________________________________________________________________

## Exercício 4 — Secrets

Porque este padrão é inadequado para secrets?

```dockerfile
ARG API_TOKEN
ENV API_TOKEN=${API_TOKEN}
```

Resposta:

____________________________________________________________________

## Exercício 5 — Automação

Indique três passos que `push.sh` automatiza depois de já os ter executado manualmente.

1. __________________________________________
2. __________________________________________
3. __________________________________________

## Exercício 6 — Health

Se `/health` responde 200 mas `/healthz` responde 404 e o Docker HEALTHCHECK testa `/healthz`, qual será a tendência do estado Docker?

Resposta:

____________________________________________________________________

## Exercício 7 — Persistência

Porque atualizar o container da aplicação não deve apagar `lab_marker`?

Resposta:

____________________________________________________________________

---

# 27. Checklist final de competências

Ao terminar, deverá conseguir afirmar:

- [ ] Sei preparar uma VM nova a partir do repositório GitHub.
- [ ] Sei identificar a raiz correta da Sessão 3.
- [ ] Construí a imagem manualmente antes de usar `build.sh`.
- [ ] Consigo explicar contexto, layers e cache.
- [ ] Consigo explicar a separação build/runtime de um multi-stage.
- [ ] Experimentei um exemplo inseguro de secret com valor fictício.
- [ ] Experimentei BuildKit secret e Compose secret.
- [ ] Executei Compose manualmente antes do wrapper.
- [ ] Consigo distinguir `/health` de `/ready`.
- [ ] Executei Trivy e interpretei o resultado.
- [ ] Criei tags e distingui tag de digest.
- [ ] Quando aplicável, executei `docker tag` e `docker push` manualmente.
- [ ] Consigo explicar o princípio build once/promote.
- [ ] Abri e compreendi o algoritmo de `deploy-prod.sh` antes de o executar.
- [ ] Fiz deploy `1.0.0`, update `1.1.0`, diagnóstico `1.2.0-rc1` e rollback `1.1.0`.
- [ ] Confirmei que os dados persistiram.

---

# 28. Transição para a Sessão 4

A Sessão 3 termina com:

```text
artefacto construído
      +
artefacto analisado
      +
artefacto versionado
      +
registry
      +
deployment controlado
```

A questão seguinte é:

> Como instalamos e administramos o cluster Kubernetes que irá orquestrar estes workloads?

```text
Sessão 3
Artefacto pronto
      ↓
Sessão 4
Cluster Kubernetes
```
