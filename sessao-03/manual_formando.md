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

Na Sessão 2 o foco foi **OPERAR** containers e aplicações multi-container. Nesta sessão o foco muda para o artefacto que será executado.

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

O percurso completo é:

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

# 2. Objetivos da Sessão

No final deverá ser capaz de:

1. Construir uma imagem através de Dockerfile.
2. Compreender o contexto de build.
3. Utilizar `.dockerignore` corretamente.
4. Explicar layers e cache.
5. Organizar o Dockerfile para melhorar reutilização da cache.
6. Utilizar multi-stage builds.
7. Separar dependências de build e runtime.
8. Interpretar `ARG`, `ENV`, `CMD`, `ENTRYPOINT` e labels.
9. Avaliar a origem e adequação da imagem base.
10. Identificar riscos de secrets em Dockerfile, build args, ambiente e CLI.
11. Compreender BuildKit secrets e Compose secrets.
12. Configurar e interpretar Docker `HEALTHCHECK`.
13. Distinguir `/health` de `/ready`.
14. Aplicar limites de CPU/memória, restart policy e logging.
15. Executar scan de vulnerabilidades com Trivy.
16. Distinguir tag de digest.
17. Publicar ou consumir imagens no GHCR.
18. Aplicar `build once, promote the same artifact`.
19. Fazer deploy da versão `1.0.0`.
20. Atualizar para `1.1.0`.
21. Detetar a falha controlada de `1.2.0-rc1`.
22. Fazer rollback para `1.1.0`.
23. Confirmar persistência dos dados durante o ciclo.

---

# 3. Recursos da Sessão

A pasta pública no repositório é:

```text
sessao-03/
```

Estrutura principal:

```text
sessao-03/
├── README.md
├── plano_sessao_3.md
├── manual_formando.md
├── checklist.md
├── cheat_sheet.md
├── referencias.md
├── comum/
│   ├── prepare-source.sh
│   └── overlay/
└── formando/
    ├── guia_formando.md
    ├── docker/
    ├── compose/
    ├── labs/
    ├── scripts/
    └── exemplos/
```

Os materiais exclusivos do formador, soluções e preparação detalhada do incidente não fazem parte do repositório público.

---

# 4. Preparar a Aplicação

O código da Symfony Demo não é duplicado dentro dos recursos da sessão.

A preparação é efetuada por:

```bash
cd sessao-03
./comum/prepare-source.sh
```

O script:

1. remove uma eventual `app/` anterior;
2. obtém `symfony/demo` na tag `v3.1.0`;
3. adiciona o controller pedagógico;
4. adiciona as rotas de laboratório;
5. remove o `.git` interno da aplicação descarregada.

Resultado:

```text
sessao-03/
└── app/
    ├── composer.json
    ├── composer.lock
    ├── public/
    ├── src/
    └── ...
```

A diretoria `app/` é material de runtime/build e não deve ser tratada como parte permanente do pacote pedagógico.

---

# 5. Endpoints Pedagógicos

A aplicação disponibiliza:

```text
/info
/health
/ready
```

## 5.1. `/info`

Apresenta informação útil sobre a versão e ambiente.

Exemplo conceptual:

```json
{
  "application": "symfony-demo",
  "version": "1.1.0",
  "environment": "prod",
  "php": "8.4.x"
}
```

O endpoint permite confirmar qual o artefacto que está efetivamente em execução.

---

## 5.2. `/health`

Valida a saúde básica da aplicação.

```text
Aplicação HTTP funcional
       ↓
/health = OK
```

Foi escolhido para o Docker `HEALTHCHECK` da imagem.

---

## 5.3. `/ready`

Valida se a aplicação está preparada para servir pedidos considerando também a dependência de dados.

```text
Aplicação
  +
PostgreSQL acessível
  ↓
/ready = OK
```

Se a base de dados estiver indisponível, `/health` pode continuar a responder e `/ready` devolver erro.

Isto ajuda a compreender:

```text
saúde do processo
      ≠
prontidão para servir
```

---

# 6. Dockerfile

Um Dockerfile descreve as instruções utilizadas para construir a imagem.

Elementos principais desta sessão:

| Instrução | Papel |
|---|---|
| `FROM` | Define a imagem base |
| `WORKDIR` | Define a diretoria de trabalho |
| `COPY` | Copia ficheiros para a imagem |
| `RUN` | Executa operações durante o build |
| `ARG` | Define argumento disponível durante o build |
| `ENV` | Define variável persistida no ambiente da imagem/container |
| `EXPOSE` | Documenta a porta esperada |
| `HEALTHCHECK` | Define o teste de saúde Docker |
| `CMD` | Define o comando por omissão |
| `ENTRYPOINT` | Define o processo/entrada principal, quando utilizado |
| `LABEL` | Adiciona metadata |

---

# 7. Contexto de Build

Quando executa:

```bash
docker build -t symfony-demo:1.0.0 .
```

o ponto final representa o **contexto de build**.

```text
Diretoria atual
      ↓
contexto enviado ao builder
      ↓
Dockerfile pode usar COPY apenas a partir desse contexto
```

Um contexto demasiado grande pode:

- tornar builds mais lentos;
- invalidar cache desnecessariamente;
- incluir ficheiros que não deveriam ser enviados ao builder;
- aumentar o risco de exposição acidental de informação.

---

# 8. .dockerignore

O `.dockerignore` serve para excluir ficheiros do contexto de build.

Na raiz da Sessão 3 são excluídos, entre outros:

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

> O `.dockerignore` relevante é o que corresponde ao contexto efetivamente utilizado no `docker build`.

Se o contexto é a raiz de `sessao-03`, o `.dockerignore` dessa raiz é o elemento principal.

---

# 9. Layers

As imagens são compostas por layers.

Simplificando:

```text
FROM php:...
   ↓ layer base
RUN apt-get ...
   ↓ nova layer
COPY ...
   ↓ nova layer
RUN composer ...
   ↓ nova layer
```

Pode observar o histórico:

```bash
docker history symfony-demo:1.0.0
```

A organização das layers influencia:

- reutilização da cache;
- tempo de build;
- tamanho;
- clareza do processo de construção.

---

# 10. Cache de Build

O Docker/BuildKit pode reutilizar resultados de instruções anteriores quando as entradas relevantes não mudaram.

Imagine:

```dockerfile
COPY app/ ./
RUN composer install
```

Se qualquer ficheiro da aplicação mudar antes de `composer install`, a cache dessa etapa pode ser invalidada.

Uma abordagem mais eficiente é separar os ficheiros de dependências:

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

---

# 11. Multi-stage Build

Um multi-stage build utiliza mais do que um `FROM`.

```text
Stage 1 — build
  ↓
compilação / Composer / ferramentas
  ↓
artefactos necessários
  ↓
Stage 2 — runtime
  ↓
apenas o necessário para executar
```

Exemplo conceptual:

```dockerfile
FROM php:8.4-apache-bookworm AS build
# ferramentas de build
# Composer
# dependências

FROM php:8.4-apache-bookworm AS runtime
COPY --from=build /var/www/html /var/www/html
```

Vantagens:

- separar responsabilidades;
- reduzir ferramentas presentes no runtime;
- tornar a imagem final mais controlada;
- melhorar segurança e manutenção.

O objetivo não é produzir a imagem mínima possível a qualquer custo; é produzir uma imagem adequada, compreensível e operacional.

---

# 12. ARG e ENV

## 12.1. ARG

`ARG` existe durante o build.

```dockerfile
ARG APP_VERSION=dev
```

Utilização:

```bash
docker build \
  --build-arg APP_VERSION=1.0.0 \
  ...
```

Não deve ser utilizado como mecanismo seguro para fornecer secrets.

---

## 12.2. ENV

`ENV` define variáveis que passam a fazer parte do ambiente da imagem/container.

```dockerfile
ENV APP_ENV=prod
```

Estas variáveis podem ser consultadas posteriormente. Não devem ser utilizadas para embutir segredos que não devam ficar expostos na configuração do container.

---

# 13. CMD e ENTRYPOINT

`CMD` e `ENTRYPOINT` estão relacionados com o processo iniciado quando o container arranca.

Na imagem PHP/Apache utilizada:

```dockerfile
CMD ["apache2-foreground"]
```

O objetivo é manter o processo principal do container em foreground.

Não é necessário decorar todas as combinações possíveis de `CMD` e `ENTRYPOINT`; deve compreender que definem o comportamento de arranque da imagem.

---

# 14. Imagem Base

A escolha de uma imagem base afeta:

- runtime disponível;
- bibliotecas;
- superfície de ataque;
- compatibilidade;
- manutenção;
- tamanho;
- comportamento do entrypoint.

Nesta sessão utilizamos:

```text
php:8.4-apache-bookworm
```

Uma boa análise da imagem base deve responder:

- Quem a mantém?
- É adequada ao runtime necessário?
- Inclui componentes desnecessários?
- Como são publicadas atualizações?
- Existem vulnerabilidades conhecidas?

---

# 15. Hardening

Hardening não significa aplicar mecanicamente uma lista de comandos. Significa reduzir riscos sem quebrar o funcionamento necessário.

Princípios:

- reduzir dependências desnecessárias;
- manter a imagem base atualizada;
- evitar secrets na imagem;
- limitar permissões de escrita;
- usar privilégios mínimos;
- não montar o Docker socket sem necessidade;
- evitar ferramentas de build no runtime quando não são necessárias.

## Nota sobre non-root

É comum recomendar containers non-root, mas isso deve ser aplicado tendo em conta a imagem base e o processo executado.

Na imagem Apache oficial, alterar simplesmente:

```dockerfile
USER www-data
```

pode exigir alterações adicionais de portas, permissões e comportamento de arranque.

A regra correta é:

> Menor privilégio, validado no contexto real da imagem.

---

# 16. Secrets

## 16.1. O que evitar

Exemplo inadequado:

```dockerfile
ARG API_TOKEN
ENV API_TOKEN=${API_TOKEN}
```

Um secret não deve ser transformado numa variável persistente da imagem apenas porque foi recebido durante o build.

---

## 16.2. BuildKit Secret Mount

BuildKit permite disponibilizar um secret temporariamente numa instrução `RUN`.

Exemplo:

```dockerfile
RUN --mount=type=secret,id=demo_secret \
    test -s /run/secrets/demo_secret
```

O ficheiro existe apenas no contexto daquela operação de build e não deve ser copiado para a imagem final.

---

## 16.3. Compose Secrets

Compose pode montar secrets como ficheiros.

```text
/run/secrets/demo_secret
```

Isto é diferente de transformar automaticamente o secret numa variável de ambiente.

---

## 16.4. `.env`

O ficheiro `.env.prod` é uma conveniência de configuração.

```text
.env
  ≠
secret manager
```

Mesmo que esteja excluído do Git, deve ser protegido no host e não deve conter credenciais de produção reais sem controlos adicionais.

---

# 17. Docker HEALTHCHECK

A imagem da sessão contém um healthcheck.

Conceptualmente:

```dockerfile
HEALTHCHECK ... \
  CMD curl -fsS http://localhost/health >/dev/null || exit 1
```

O Docker executa periodicamente o comando.

Estados possíveis incluem:

```text
starting
healthy
unhealthy
```

Consultar:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

---

# 18. HEALTHCHECK não é Probe Kubernetes

Um ponto fundamental:

```text
Docker HEALTHCHECK
        ≠
Kubernetes livenessProbe
        ≠
Kubernetes readinessProbe
```

Kubernetes não transforma automaticamente a metadata `HEALTHCHECK` da imagem em probes.

As probes Kubernetes serão configuradas explicitamente nos manifests quando chegarmos a essa parte da formação.

---

# 19. Controlos de Runtime

No override de produção são aplicados controlos como:

```yaml
restart: unless-stopped
mem_limit: 512m
cpus: 1.0
logging:
  driver: local
```

## Memória

```text
mem_limit: 512m
```

limita a memória disponível ao container.

## CPU

```text
cpus: 1.0
```

limita a capacidade de CPU atribuída.

## Restart policy

```text
restart: unless-stopped
```

indica ao Docker quando deverá tentar voltar a iniciar o container.

Isto não equivale às capacidades de scheduling, resiliência e reconciliação de um orquestrador distribuído.

---

# 20. Trivy

Trivy é utilizado para analisar vulnerabilidades conhecidas.

## Scan informativo

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Os resultados mudam à medida que:

- novas CVEs são publicadas;
- severidades são atualizadas;
- pacotes são corrigidos;
- a base de dados do scanner evolui.

Por isso:

> Não memorize uma contagem de vulnerabilidades como resultado esperado permanente.

---

# 21. Quality Gate

É possível utilizar o exit code do Trivy para representar uma política.

Exemplo didático:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

A existência de uma vulnerabilidade deve ser interpretada considerando:

- severidade;
- pacote afetado;
- versão;
- disponibilidade de correção;
- explorabilidade;
- contexto real da aplicação;
- exposição do componente.

---

# 22. Tags

As tags são referências convenientes.

```text
1.0.0
1.1.0
1.2.0-rc1
```

Nesta sessão utilizamos SemVer de forma simples:

```text
1.0.0      versão inicial
1.1.0      atualização compatível
1.2.0-rc1  release candidate usada para falha controlada
```

Uma tag pode ser alterada no registry por quem tenha permissões.

Logo:

```text
Tag
 = referência útil
 ≠ identidade criptográfica imutável
```

---

# 23. Digest

Um digest identifica o conteúdo.

Exemplo conceptual:

```text
sha256:abc123...
```

Depois de pull/push:

```bash
docker image inspect "$IMAGE_REPO:1.1.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

Relação:

```text
Tag
  ↓ aponta para
Manifest / conteúdo
  ↓ identificado por
Digest
```

A tag pode mudar; o digest identifica o conteúdo específico.

---

# 24. Registry e GHCR

O registry de referência é:

```text
ghcr.io/skullclamp/symfony-demo
```

As imagens públicas podem ser consumidas sem login:

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

---

# 25. Push para Namespace Pessoal

Para fazer push para um namespace próprio precisa de autenticação e permissões de escrita.

Exemplo:

```bash
export CR_PAT='TOKEN_PESSOAL'

echo "$CR_PAT" | docker login ghcr.io \
  -u UTILIZADOR_GITHUB \
  --password-stdin
```

Definir o destino:

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
```

Publicar:

```bash
./formando/scripts/push.sh 1.0.0
```

Nunca:

- envie o token ao formador;
- coloque o token no Git;
- inclua o token em screenshots;
- guarde o token num ficheiro que vá ser versionado.

---

# 26. Build Once, Promote the Same Artifact

A prática pretendida é:

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

porque cada reconstrução pode produzir um artefacto diferente.

A ideia é promover o mesmo conteúdo entre etapas.

---

# 27. Docker Compose em Contexto de Produção

O cenário utiliza dois ficheiros:

```text
formando/compose/compose.yaml
formando/compose/compose.prod.yaml
```

O primeiro define a stack base.

O segundo acrescenta controlos de produção contextualizada:

- `restart`;
- limites de CPU e memória;
- logging `local`;
- ambiente `prod`.

Antes de utilizar:

```bash
cp formando/compose/.env.prod.example \
   formando/compose/.env.prod
```

Validar:

```bash
./formando/scripts/compose-prod.sh config
```

---

# 28. PostgreSQL 16 e Persistência

O serviço de base de dados utiliza:

```yaml
volumes:
  - db-data:/var/lib/postgresql/data
```

Não é necessário publicar `5432` no host para que a aplicação comunique com a base de dados dentro da rede Compose.

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

Isto reduz exposição desnecessária.

---

# 29. Inicialização do Schema

No laboratório, `deploy-prod.sh` verifica se uma tabela conhecida da aplicação já existe.

Se o schema ainda não existir, numa base vazia, executa:

```bash
php bin/console doctrine:schema:create --no-interaction
```

Esta é uma conveniência pedagógica para inicialização do laboratório.

Em produção real:

> A evolução do schema deve ser realizada através de migrações explícitas, versionadas, testadas e compatíveis com a estratégia de deployment.

Não se deve utilizar indiscriminadamente um comando destrutivo de sincronização automática do schema.

---

# 30. Deployment Inicial — 1.0.0

Preparar:

```bash
cp formando/compose/.env.prod.example \
   formando/compose/.env.prod
```

Executar:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

O script:

```text
valida Compose
      ↓
verifica porta
      ↓
pull
      ↓
inicia PostgreSQL
      ↓
aguarda DB healthy
      ↓
verifica/inicializa schema
      ↓
inicia aplicação
      ↓
valida endpoints
      ↓
valida Docker health
```

---

# 31. Validação

O script:

```bash
./formando/scripts/validate.sh
```

valida:

```text
/health
/ready
/info
Docker HEALTHCHECK
```

Também apresenta informação de configuração operacional.

---

# 32. Persistência com Evidência

No laboratório é criada uma tabela pedagógica:

```text
lab_marker
```

Exemplo:

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

Esta tabela existe apenas para demonstrar que os dados sobrevivem a alterações nos containers da aplicação.

---

# 33. Backup Lógico

Executar:

```bash
./formando/scripts/backup-postgres.sh
```

O script utiliza `pg_dump` e guarda o resultado em:

```text
formando/compose/backups/
```

O diretório de backups é excluído do Git.

Mensagem fundamental:

```text
Named volume
     ≠
Backup SQL
```

---

# 34. Update para 1.1.0

Executar:

```bash
./formando/scripts/deploy-prod.sh 1.1.0
```

Validar:

```bash
curl -fsS http://localhost:8080/info
```

Confirmar o marcador:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

Resultado esperado:

```text
versão da app mudou
      ↓
container da app mudou
      ↓
volume PostgreSQL permaneceu
      ↓
lab_marker permaneceu
```

---

# 35. Falha Controlada — 1.2.0-rc1

A imagem `1.2.0-rc1` foi preparada com um health path incorreto:

```text
/healthz
```

O endpoint real continua a ser:

```text
/health
```

Isto cria uma situação pedagogicamente útil:

```text
processo Apache ativo
      ↓
/health responde
      ↓
/ready pode responder
      ↓
mas Docker testa /healthz
      ↓
404
      ↓
container = unhealthy
```

Executar:

```bash
set +e
./formando/scripts/deploy-prod.sh 1.2.0-rc1
RC=$?
set -e

echo "EXIT_CODE=$RC"
```

O deployment deve ser considerado falhado porque a validação operacional não passou.

---

# 36. Diagnóstico da Falha

Consultar estado:

```bash
./formando/scripts/compose-prod.sh ps
```

Obter container:

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
./formando/scripts/compose-prod.sh logs \
  --tail 100 app
```

Validar manualmente:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

A diferença entre os dois caminhos evidencia a causa.

---

# 37. Rollback

A versão conhecida como boa é `1.1.0`.

```bash
./formando/scripts/rollback.sh 1.1.0
```

Depois:

```bash
./formando/scripts/validate.sh
```

Confirmar dados:

```bash
./formando/scripts/compose-prod.sh exec -T db \
  psql -U symfony -d symfony \
  -c 'SELECT * FROM lab_marker;'
```

Resultado esperado:

```text
1.2.0-rc1
   ↓ falha
1.1.0
   ↓ rollback
healthy
   +
dados preservados
```

---

# 38. Docker Compose Single-host não é HA

Este laboratório aproxima-se de preocupações reais de produção, mas deve ser interpretado corretamente.

```text
1 host Docker
      ↓
Compose
      ↓
app + db
```

Se o host falhar, os containers nesse host deixam de estar disponíveis.

Logo:

```text
restart policy
      ≠
Alta Disponibilidade
```

e:

```text
Docker Compose single-host
      ≠
Kubernetes
```

Kubernetes acrescentará mecanismos de scheduling, reconciliação, gestão distribuída de workloads e outras capacidades que serão estudadas posteriormente.

---

# 39. Supply Chain — Enquadramento

A Sessão 3 introduz a ideia de cadeia do artefacto:

```text
Código
 ↓
Build
 ↓
Imagem
 ↓
Scan
 ↓
Tag / Digest
 ↓
Registry
 ↓
Promoção
 ↓
Deployment
```

Assuntos como assinatura de imagens, SBOM e provenance são importantes, mas nesta sessão ficam apenas como enquadramento conceptual.

---

# 40. Boas Práticas

- Utilize imagens base de origem conhecida.
- Evite componentes de build no runtime quando não são necessários.
- Utilize `.dockerignore` no contexto correto.
- Organize o Dockerfile para beneficiar da cache.
- Não coloque secrets em Dockerfile, `ARG` ou `ENV` de forma insegura.
- Não trate `.env` como secret manager.
- Não monte `/var/run/docker.sock` sem compreender o privilégio que isso concede.
- Utilize tags explícitas.
- Utilize digest quando precisar de identidade imutável do artefacto.
- Analise vulnerabilidades antes da promoção.
- Promova o mesmo artefacto entre ambientes.
- Valide saúde depois de um deployment.
- Faça rollback para uma versão conhecida como boa quando a atualização falhar.
- Separe persistência de backup.

---

# 41. Resumo da Sessão

```text
Código
  ↓
Dockerfile
  ↓
Contexto + .dockerignore
  ↓
Layers + Cache
  ↓
Multi-stage
  ↓
Hardening + Secrets
  ↓
HEALTHCHECK
  ↓
Trivy
  ↓
Tag + Digest
  ↓
GHCR
  ↓
Build once / Promote
  ↓
Compose single-host
  ↓
1.0.0
  ↓
1.1.0
  ↓
1.2.0-rc1 = unhealthy
  ↓
Rollback 1.1.0
  ↓
Dados preservados
```

---

# 42. Exercícios de Consolidação

## Exercício 1 — Contexto de Build

Explique o que representa o último argumento do comando:

```bash
docker build -f formando/docker/Dockerfile -t symfony-demo:1.0.0 .
```

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 2 — `.dockerignore`

Indique três tipos de ficheiros que não deverão ser enviados para o build neste laboratório.

1. __________________________________________
2. __________________________________________
3. __________________________________________

## Exercício 3 — Cache

Porque é vantajoso copiar `composer.json` e `composer.lock` antes do restante código?

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 4 — Multi-stage

Associe:

| Elemento | Stage mais provável |
|---|---|
| Git | __________________ |
| Composer | __________________ |
| Código final | __________________ |
| Apache | __________________ |
| Ferramentas de compilação | __________________ |

## Exercício 5 — Secrets

Explique por que razão este padrão é inadequado:

```dockerfile
ARG TOKEN
ENV TOKEN=${TOKEN}
```

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 6 — Health vs Ready

Considere:

```text
Apache ativo
PostgreSQL indisponível
```

Qual deverá ser o comportamento esperado?

```text
/health → __________________
/ready  → __________________
```

Justificação:

____________________________________________________________________

## Exercício 7 — Tag vs Digest

Complete:

```text
Tag    → ______________________________________________
Digest → ______________________________________________
```

## Exercício 8 — Promoção

Qual é o modelo preferido?

```text
A) build DEV → build TEST → build PROD
B) build uma vez → promover o mesmo artefacto
```

Resposta: ______

Justificação:

____________________________________________________________________

## Exercício 9 — Persistência

Depois de atualizar `1.0.0` para `1.1.0`, que evidência confirma que os dados da DB não seguiram o ciclo de vida do container da aplicação?

Resposta:

____________________________________________________________________

## Exercício 10 — Falha Controlada

A aplicação responde em `/health`, mas o Docker apresenta `unhealthy`. Qual é a primeira evidência que deve consultar?

Resposta:

____________________________________________________________________

---

# 43. Questões de Revisão

1. O que é o contexto de build?
2. Para que serve `.dockerignore`?
3. O que é uma layer?
4. Como a ordem do Dockerfile afeta a cache?
5. Qual é a finalidade de um multi-stage build?
6. Qual é a diferença entre build stage e runtime stage?
7. Qual é a diferença entre `ARG` e `ENV`?
8. Porque não deve usar `ARG` como mecanismo seguro de secrets?
9. O que é um BuildKit secret mount?
10. Onde são montados Compose secrets por omissão no container?
11. Porque `.env` não é um secret manager?
12. Para que serve Docker `HEALTHCHECK`?
13. Qual é a diferença entre `/health` e `/ready` no laboratório?
14. Docker `HEALTHCHECK` é automaticamente utilizado por Kubernetes?
15. Para que servem `mem_limit` e `cpus`?
16. Porque os resultados do Trivy mudam ao longo do tempo?
17. O que é uma tag?
18. O que é um digest?
19. Qual dos dois identifica imutavelmente o conteúdo?
20. O que significa build once / promote?
21. Porque não devemos reconstruir a imagem para cada ambiente?
22. Qual é o papel do GHCR nesta sessão?
23. Porque PostgreSQL não publica necessariamente `5432` no host?
24. Porque persistência não é backup?
25. Qual é a versão conhecida como boa depois da falha `1.2.0-rc1`?
26. Porque Docker Compose single-host não é Alta Disponibilidade?

---

# 44. Checklist de Competências

| Competência | Evidência esperada |
|---|---|
| Preparar source | `app/` criada com overlay |
| Construir imagem | `symfony-demo:1.0.0` disponível |
| Explicar cache | Identifica layers reutilizadas |
| Multi-stage | Distingue build/runtime |
| Hardening | Identifica componentes e privilégios |
| Secrets | Distingue ARG/ENV, BuildKit e runtime |
| Health | Interpreta `healthy/unhealthy` |
| Readiness | Distingue `/health` de `/ready` |
| Scan | Executa Trivy e interpreta exit code |
| Versionamento | Distingue `1.0.0`, `1.1.0`, `1.2.0-rc1` |
| Identidade | Distingue tag de digest |
| Registry | Faz pull e compreende push autenticado |
| Promoção | Explica build once/promote |
| Deploy | Executa `1.0.0` |
| Update | Executa `1.1.0` |
| Falha | Deteta `1.2.0-rc1` unhealthy |
| Rollback | Repõe `1.1.0` |
| Persistência | Confirma `lab_marker` |
| Backup | Executa backup lógico |

---

# 45. Transição para a Sessão 4

A Sessão 3 termina com:

```text
imagem preparada
      +
registry
      +
deployment controlado
      +
rollback validado
```

A questão seguinte passa a ser:

> Como instalamos e administramos o cluster Kubernetes que irá orquestrar estes workloads?

```text
Sessão 3
Artefacto pronto
      ↓
Sessão 4
Cluster Kubernetes
```
